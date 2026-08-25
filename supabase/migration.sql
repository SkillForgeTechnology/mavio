-- =========================================================================
-- MAVIO Self-Service Stop & OneSignal Push Notification Alerts Migration
-- Run this SQL in your Supabase SQL Editor (https://supabase.com)
-- =========================================================================

-- 1. ADD SELF-SERVICE STOP AND ONESIGNAL COLUMNS TO PROFILES
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS alert_latitude double precision,
ADD COLUMN IF NOT EXISTS alert_longitude double precision,
ADD COLUMN IF NOT EXISTS alert_radius_meters integer DEFAULT 500,
ADD COLUMN IF NOT EXISTS onesignal_id text;

-- 2. CREATE TRIP ALERTS REGISTRY TABLE TO PREVENT SPAM (ONLY ALERTS ONCE PER TRIP)
CREATE TABLE IF NOT EXISTS public.trip_alerts (
  trip_id UUID NOT NULL,
  student_id UUID NOT NULL,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (trip_id, student_id)
);

-- 3. CREATE PROXIMITY CHECKING & ONESIGNAL NOTIFICATION TRIGGER
-- Enable the HTTP extension in Supabase to make outgoing API requests
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.check_bus_proximity_and_notify()
RETURNS TRIGGER AS $$
DECLARE
  matching_profile RECORD;
  bus_name TEXT;
  onesignal_app_id TEXT := '2633169a-2c5f-4856-bfd3-12361105dc17';
  onesignal_rest_api_key TEXT := 'YOUR_ONESIGNAL_REST_API_KEY'; -- Replace with actual REST API Key from OneSignal Settings -> Keys & IDs
  payload JSONB;
BEGIN
  -- Get vehicle name for the notification message
  SELECT v.name 
  INTO bus_name
  FROM public.trips t
  JOIN public.vehicles v ON t.vehicle_id = v.id
  WHERE t.id = NEW.trip_id AND t.status = 'ACTIVE';

  IF bus_name IS NULL THEN
    bus_name := 'Your Bus';
  END IF;

  -- Find all students in this organization whose alert stop is within their configured radius
  FOR matching_profile IN 
    SELECT p.id, p.onesignal_id, p.alert_radius_meters,
           -- Distance in meters using spherical law of cosines (Haversine approximation)
           (6371000 * acos(
             least(1.0, greatest(-1.0, 
               cos(radians(NEW.latitude)) * cos(radians(p.alert_latitude)) * 
               cos(radians(p.alert_longitude) - radians(NEW.longitude)) + 
               sin(radians(NEW.latitude)) * sin(radians(p.alert_latitude))
             ))
           )) AS distance
    FROM public.profiles p
    JOIN public.trips t ON t.id = NEW.trip_id
    WHERE p.role = 'student' 
      AND p.org_id = t.org_id
      AND p.alert_latitude IS NOT NULL 
      AND p.alert_longitude IS NOT NULL
      AND p.onesignal_id IS NOT NULL
  LOOP
    -- Check if the bus has entered the student's alert radius threshold
    IF matching_profile.distance <= matching_profile.alert_radius_meters THEN
      
      -- Check if we already sent a notification to this student for this trip to avoid spamming
      IF NOT EXISTS (
        SELECT 1 FROM public.trip_alerts 
        WHERE trip_id = NEW.trip_id AND student_id = matching_profile.id
      ) THEN
        
        -- Lock this student/trip combination immediately to prevent concurrent triggers
        INSERT INTO public.trip_alerts (trip_id, student_id)
        VALUES (NEW.trip_id, matching_profile.id)
        ON CONFLICT DO NOTHING;

        -- Construct the JSON payload for OneSignal API
        payload := jsonb_build_object(
          'app_id', onesignal_app_id,
          'include_subscription_ids', jsonb_build_array(matching_profile.onesignal_id),
          'contents', jsonb_build_object('en', 'Bus ' || bus_name || ' is nearing your stop! Current distance is ' || round(matching_profile.distance::numeric) || ' meters.'),
          'headings', jsonb_build_object('en', 'MAVIO Proximity Alert')
        );

        -- Send HTTP POST to OneSignal API (silently catches errors to avoid breaking telemetry logs)
        BEGIN
          PERFORM extensions.http((
            'POST',
            'https://onesignal.com/api/v1/notifications',
            ARRAY[
              ('Content-Type', 'application/json')::extensions.http_header,
              ('Authorization', 'Basic ' || onesignal_rest_api_key)::extensions.http_header
            ],
            'application/json',
            payload::text
          )::extensions.http_request);
        EXCEPTION WHEN OTHERS THEN
          RAISE WARNING 'OneSignal post failed: %', SQLERRM;
        END;

      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if it already exists to avoid duplicate errors
DROP TRIGGER IF EXISTS tr_check_bus_proximity_and_notify ON public.location_updates;

-- Attach the trigger to location_updates table
CREATE TRIGGER tr_check_bus_proximity_and_notify
AFTER INSERT ON public.location_updates
FOR EACH ROW
EXECUTE FUNCTION public.check_bus_proximity_and_notify();

-- =========================================================================
-- 4. AUTOMATIC VEHICLE LIMIT ADJUSTMENT ON PLAN STATUS CHANGES
-- =========================================================================
CREATE OR REPLACE FUNCTION public.set_default_vehicle_limit_on_plan_change()
RETURNS TRIGGER AS $$
BEGIN
  -- If free trial: set max vehicles to 15
  IF NEW.subscription_status = 'free_trial' AND (OLD.subscription_status IS NULL OR OLD.subscription_status != 'free_trial') THEN
    NEW.max_vehicles := 15;
  -- If active plan: set max vehicles to 25
  ELSIF NEW.subscription_status = 'active' AND (OLD.subscription_status IS NULL OR OLD.subscription_status != 'active') THEN
    NEW.max_vehicles := 25;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if it already exists to avoid duplicates
DROP TRIGGER IF EXISTS tr_set_default_vehicle_limit_on_plan_change ON public.organizations;

-- Attach trigger BEFORE INSERT or UPDATE to automatically adjust max_vehicles field
CREATE TRIGGER tr_set_default_vehicle_limit_on_plan_change
BEFORE INSERT OR UPDATE OF subscription_status ON public.organizations
FOR EACH ROW
EXECUTE FUNCTION public.set_default_vehicle_limit_on_plan_change();

-- =========================================================================
-- 5. ODOMETER TRAVEL DISTANCE & MAINTENANCE COLUMNS + TELEMETRY TRIGGER
-- =========================================================================

-- Add odometer and service columns to vehicles table
ALTER TABLE public.vehicles
ADD COLUMN IF NOT EXISTS total_distance_km DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS service_due_km INTEGER DEFAULT 5000;

-- Trigger function to calculate distance using Haversine formula and update odometer
CREATE OR REPLACE FUNCTION public.track_vehicle_distance()
RETURNS TRIGGER AS $$
DECLARE
  prev_lat DOUBLE PRECISION;
  prev_lon DOUBLE PRECISION;
  dist_meters DOUBLE PRECISION := 0;
  v_id UUID;
BEGIN
  -- Get the vehicle ID from the trip
  SELECT vehicle_id INTO v_id 
  FROM public.trips 
  WHERE id = NEW.trip_id;

  IF v_id IS NOT NULL THEN
    -- Get the previous location update for this trip
    SELECT latitude, longitude INTO prev_lat, prev_lon
    FROM public.location_updates
    WHERE trip_id = NEW.trip_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF prev_lat IS NOT NULL AND prev_lon IS NOT NULL THEN
      -- Calculate distance in meters using Haversine
      dist_meters := (6371000 * acos(
        least(1.0, greatest(-1.0, 
          cos(radians(NEW.latitude)) * cos(radians(prev_lat)) * 
          cos(radians(prev_lon) - radians(NEW.longitude)) + 
          sin(radians(NEW.latitude)) * sin(radians(prev_lat))
        ))
      ));
      
      -- Update vehicle's total distance in kilometers
      UPDATE public.vehicles
      SET total_distance_km = COALESCE(total_distance_km, 0) + (dist_meters / 1000.0)
      WHERE id = v_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if it already exists
DROP TRIGGER IF EXISTS tr_track_vehicle_distance ON public.location_updates;

-- Attach trigger BEFORE INSERT on location_updates
CREATE TRIGGER tr_track_vehicle_distance
BEFORE INSERT ON public.location_updates
FOR EACH ROW
EXECUTE FUNCTION public.track_vehicle_distance();
