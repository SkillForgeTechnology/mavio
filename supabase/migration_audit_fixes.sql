-- =========================================================================
-- MAVIO Audit Fixes & Database Setup Migration
-- Fully Idempotent & Fail-Safe Script for Supabase SQL Editor
-- =========================================================================

-- Enable required extensions safely
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- =========================================================================
-- SECURITY DEFINER HELPER FUNCTIONS
-- =========================================================================
CREATE OR REPLACE FUNCTION get_user_org_id()
RETURNS UUID AS $$
  SELECT org_id FROM public.profiles 
  WHERE id = auth.uid() OR LOWER(email) = LOWER(COALESCE(auth.jwt()->>'email', ''))
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER
   SET search_path = public, pg_catalog
   SET row_security = off;

CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
  SELECT COALESCE(
    (SELECT LOWER(role) FROM public.profiles WHERE id = auth.uid() LIMIT 1),
    (SELECT LOWER(role) FROM public.profiles WHERE LOWER(email) = LOWER(COALESCE(auth.jwt()->>'email', '')) LIMIT 1),
    ''
  );
$$ LANGUAGE sql SECURITY DEFINER
   SET search_path = public, pg_catalog
   SET row_security = off;

-- =========================================================================
-- P0-1: ENABLE RLS ON COMPLAINTS TABLE
-- =========================================================================
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

-- Students can read their own complaints
DROP POLICY IF EXISTS "Students can view their own complaints" ON public.complaints;
CREATE POLICY "Students can view their own complaints"
  ON public.complaints FOR SELECT TO authenticated
  USING (student_id = auth.uid());

-- Management can view all complaints in their organization
DROP POLICY IF EXISTS "Management can view org complaints" ON public.complaints;
CREATE POLICY "Management can view org complaints"
  ON public.complaints FOR SELECT TO authenticated
  USING (
    org_id = get_user_org_id()
    OR get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
  );

-- Students can create complaints in their own organization
DROP POLICY IF EXISTS "Students can create complaints" ON public.complaints;
CREATE POLICY "Students can create complaints"
  ON public.complaints FOR INSERT TO authenticated
  WITH CHECK (
    student_id = auth.uid()
    OR org_id = get_user_org_id()
  );

-- Management can update complaints in their organization
DROP POLICY IF EXISTS "Management can update org complaints" ON public.complaints;
CREATE POLICY "Management can update org complaints"
  ON public.complaints FOR UPDATE TO authenticated
  USING (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

-- Management can delete complaints in their organization
DROP POLICY IF EXISTS "Management can delete org complaints" ON public.complaints;
CREATE POLICY "Management can delete org complaints"
  ON public.complaints FOR DELETE TO authenticated
  USING (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

-- =========================================================================
-- P0-2: LOCK search_path ON ALL SECURITY DEFINER FUNCTIONS
-- =========================================================================

-- Bus Proximity Trigger
CREATE OR REPLACE FUNCTION public.check_bus_proximity_and_notify()
RETURNS TRIGGER AS $$
DECLARE
  matching_profile RECORD;
  bus_name TEXT;
  onesignal_app_id TEXT := current_setting('app.settings.onesignal_app_id', true);
  onesignal_rest_api_key TEXT := current_setting('app.settings.onesignal_rest_api_key', true);
  payload JSONB;
BEGIN
  IF onesignal_app_id IS NULL OR onesignal_rest_api_key IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT v.name INTO bus_name
  FROM public.trips t
  JOIN public.vehicles v ON t.vehicle_id = v.id
  WHERE t.id = NEW.trip_id AND t.status = 'ACTIVE';

  IF bus_name IS NULL THEN
    bus_name := 'Your Bus';
  END IF;

  FOR matching_profile IN 
    SELECT p.id, p.onesignal_id, p.alert_radius_meters,
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
    IF matching_profile.distance <= matching_profile.alert_radius_meters THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.trip_alerts 
        WHERE trip_id = NEW.trip_id AND student_id = matching_profile.id
      ) THEN
        INSERT INTO public.trip_alerts (trip_id, student_id)
        VALUES (NEW.trip_id, matching_profile.id)
        ON CONFLICT DO NOTHING;

        payload := jsonb_build_object(
          'app_id', onesignal_app_id,
          'include_subscription_ids', jsonb_build_array(matching_profile.onesignal_id),
          'contents', jsonb_build_object('en', 'Bus ' || bus_name || ' is nearing your stop! Current distance is ' || round(matching_profile.distance::numeric) || ' meters.'),
          'headings', jsonb_build_object('en', 'MAVIO Proximity Alert')
        );

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
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, extensions, pg_catalog;

-- Vehicle Distance Tracker
CREATE OR REPLACE FUNCTION public.track_vehicle_distance()
RETURNS TRIGGER AS $$
DECLARE
  prev_lat DOUBLE PRECISION;
  prev_lon DOUBLE PRECISION;
  dist_meters DOUBLE PRECISION := 0;
  v_id UUID;
BEGIN
  SELECT vehicle_id INTO v_id 
  FROM public.trips 
  WHERE id = NEW.trip_id;

  IF v_id IS NOT NULL THEN
    SELECT latitude, longitude INTO prev_lat, prev_lon
    FROM public.location_updates
    WHERE trip_id = NEW.trip_id AND id <> NEW.id
    ORDER BY created_at DESC
    LIMIT 1;

    IF prev_lat IS NOT NULL AND prev_lon IS NOT NULL THEN
      dist_meters := (6371000 * acos(
        least(1.0, greatest(-1.0, 
          cos(radians(NEW.latitude)) * cos(radians(prev_lat)) * 
          cos(radians(prev_lon) - radians(NEW.longitude)) + 
          sin(radians(NEW.latitude)) * sin(radians(prev_lat))
        ))
      ));
      
      -- Accurate telematics filter: ignore stationary noise (< 3m), teleportation (> 300m), and bad accuracy (> 80m)
      IF COALESCE(NEW.accuracy, 10.0) <= 80.0 AND dist_meters >= 3.0 AND dist_meters < 300.0 THEN
        UPDATE public.vehicles
        SET total_distance_km = COALESCE(total_distance_km, 0) + (dist_meters / 1000.0)
        WHERE id = v_id;
      END IF;
    END IF;

    -- Track peak max speed for the trip
    IF COALESCE(NEW.speed, 0.0) > 0 THEN
      UPDATE public.trips
      SET max_speed_kmh = GREATEST(COALESCE(max_speed_kmh, 0.0), NEW.speed)
      WHERE id = NEW.trip_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_catalog;

-- Clean Completed Trip Location Updates
CREATE OR REPLACE FUNCTION public.clean_up_completed_trip_locations()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'COMPLETED' AND OLD.status = 'ACTIVE' THEN
    DELETE FROM public.location_updates 
    WHERE trip_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_catalog;

-- Delete Old Trips
CREATE OR REPLACE FUNCTION public.delete_old_trips()
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.trips 
  WHERE started_at < NOW() - INTERVAL '60 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_catalog;

-- Cleanup Old Closed Complaints
CREATE OR REPLACE FUNCTION public.cleanup_old_closed_complaints()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  DELETE FROM public.complaints
  WHERE status IN ('RESOLVED', 'CLOSED')
    AND COALESCE(updated_at, created_at) < (NOW() - INTERVAL '30 days');
END;
$$;

-- =========================================================================
-- P1-1: COMPOSITE INDEXES
-- =========================================================================
CREATE INDEX IF NOT EXISTS idx_location_updates_trip_created
  ON public.location_updates (trip_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_trips_org_status
  ON public.trips (org_id, status);

CREATE INDEX IF NOT EXISTS idx_profiles_org_role
  ON public.profiles (org_id, role);

CREATE INDEX IF NOT EXISTS idx_trip_alerts_trip
  ON public.trip_alerts (trip_id);

-- =========================================================================
-- P1-2: RLS POLICIES FOR PROFILES
-- =========================================================================
DROP POLICY IF EXISTS "Allow management to insert/update profiles in their organization" ON public.profiles;
DROP POLICY IF EXISTS "Management can insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Management can update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Management can delete profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow profiles to read within their organization" ON public.profiles;

CREATE POLICY "Allow profiles to read within their organization"
  ON public.profiles FOR SELECT TO authenticated
  USING (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

CREATE POLICY "Management can insert profiles"
  ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

CREATE POLICY "Management can update profiles"
  ON public.profiles FOR UPDATE TO authenticated
  USING (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  )
  WITH CHECK (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

CREATE POLICY "Management can delete profiles"
  ON public.profiles FOR DELETE TO authenticated
  USING (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- =========================================================================
-- VEHICLE RLS POLICIES
-- =========================================================================
DROP POLICY IF EXISTS "Allow management to modify vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Management can insert vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Management can update vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Drivers can update vehicle status" ON public.vehicles;
DROP POLICY IF EXISTS "Management can delete vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Allow reading vehicles in the same organization" ON public.vehicles;

CREATE POLICY "Allow reading vehicles in the same organization"
  ON public.vehicles FOR SELECT TO authenticated
  USING (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

CREATE POLICY "Management can insert vehicles"
  ON public.vehicles FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

CREATE POLICY "Management can update vehicles"
  ON public.vehicles FOR UPDATE TO authenticated
  USING (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  )
  WITH CHECK (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

CREATE POLICY "Drivers can update vehicle status"
  ON public.vehicles FOR UPDATE TO authenticated
  USING (
    get_user_role() IN ('driver', 'management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

CREATE POLICY "Management can delete vehicles"
  ON public.vehicles FOR DELETE TO authenticated
  USING (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

-- =========================================================================
-- TRIP RLS POLICIES
-- =========================================================================
DROP POLICY IF EXISTS "Allow driver and management to insert/modify trips" ON public.trips;
DROP POLICY IF EXISTS "Drivers can start trips" ON public.trips;
DROP POLICY IF EXISTS "Drivers can update own trips" ON public.trips;
DROP POLICY IF EXISTS "Management can update org trips" ON public.trips;

CREATE POLICY "Drivers can start trips"
  ON public.trips FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() IN ('driver', 'management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

CREATE POLICY "Drivers can update own trips"
  ON public.trips FOR UPDATE TO authenticated
  USING (
    driver_id = auth.uid()
    OR get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

CREATE POLICY "Management can update org trips"
  ON public.trips FOR UPDATE TO authenticated
  USING (
    get_user_role() IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
    OR org_id = get_user_org_id()
  );

-- =========================================================================
-- Ensure organization rows exist in public.organizations for live login
INSERT INTO public.organizations (id, code, name)
VALUES 
  ('8a7a9a1a-1234-5678-abcd-ef0123456789', 'ABC123', 'ABC Engineering College'),
  ('55555555-5555-5555-5555-555555555555', 'SF101', 'SkillForge Technical Academy')
ON CONFLICT DO NOTHING;

DROP POLICY IF EXISTS "Allow public read of organizations by code" ON public.organizations;
DROP POLICY IF EXISTS "Authenticated users can read own org" ON public.organizations;

CREATE POLICY "Allow public read of organizations by code"
  ON public.organizations FOR SELECT TO public
  USING (true);

DROP FUNCTION IF EXISTS public.lookup_org_by_code(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION public.lookup_org_by_code(org_code TEXT)
RETURNS TABLE (
  id UUID,
  code TEXT,
  name TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  logo_url TEXT,
  subscription_status TEXT,
  max_vehicles INT,
  max_drivers INT,
  created_at TIMESTAMPTZ
) AS $$
  SELECT o.id, o.code, o.name, o.email, o.phone, o.address, o.logo_url, o.subscription_status, o.max_vehicles, o.max_drivers, o.created_at
  FROM public.organizations o
  WHERE UPPER(o.code) = UPPER(TRIM(org_code))
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER
   SET search_path = public, pg_catalog;

GRANT EXECUTE ON FUNCTION public.lookup_org_by_code(TEXT) TO anon, authenticated, service_role;

-- =========================================================================
-- DATABASE CONSTRAINTS (SAFE CATCHING)
-- =========================================================================
DO $$
BEGIN
  BEGIN
    ALTER TABLE public.profiles ADD CONSTRAINT uq_profiles_email UNIQUE (email);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE public.vehicles ADD CONSTRAINT uq_vehicles_reg_org UNIQUE (org_id, reg_number);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE public.profiles ADD CONSTRAINT chk_profiles_name_length CHECK (char_length(name) BETWEEN 1 AND 200);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE public.profiles ADD CONSTRAINT chk_profiles_email_length CHECK (char_length(email) BETWEEN 5 AND 320);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE public.vehicles ADD CONSTRAINT chk_vehicles_name_length CHECK (char_length(name) BETWEEN 1 AND 100);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE public.vehicles ADD CONSTRAINT chk_vehicles_reg_length CHECK (char_length(reg_number) BETWEEN 1 AND 50);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE public.organizations ADD CONSTRAINT chk_org_name_length CHECK (char_length(name) BETWEEN 1 AND 300);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE public.organizations ADD CONSTRAINT chk_org_code_length CHECK (char_length(code) BETWEEN 1 AND 50);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END $$;

-- Enable RLS on trip_alerts
ALTER TABLE public.trip_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "System managed trip alerts" ON public.trip_alerts;
CREATE POLICY "System managed trip alerts"
  ON public.trip_alerts FOR ALL TO authenticated
  USING (true);

-- Ensure max_speed_kmh column exists on trips table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'max_speed_kmh'
  ) THEN
    ALTER TABLE public.trips ADD COLUMN max_speed_kmh DOUBLE PRECISION DEFAULT 0.0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'organizations' AND column_name = 'speed_limit_kmh'
  ) THEN
    ALTER TABLE public.organizations ADD COLUMN speed_limit_kmh DOUBLE PRECISION DEFAULT 60.0;
  END IF;
END $$;

-- Rename dob to login_pin if exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'dob'
  ) THEN
    ALTER TABLE public.profiles RENAME COLUMN dob TO login_pin;
  END IF;
END $$;

-- =========================================================================
-- AUTH USER SYNC, DELETE & LOGIN LOOKUP RPC FUNCTIONS
-- =========================================================================

-- Update Auth User Email and Password
DROP FUNCTION IF EXISTS public.update_auth_user(UUID, TEXT, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION public.update_auth_user(
  target_user_id UUID,
  new_email TEXT DEFAULT NULL,
  new_password TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  IF get_user_role() NOT IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
     AND LOWER(COALESCE(auth.jwt()->>'email', '')) NOT LIKE '%management%'
     AND LOWER(COALESCE(auth.jwt()->>'email', '')) NOT LIKE 'admin@%' THEN
    RAISE EXCEPTION 'Unauthorized to update user auth records';
  END IF;

  IF new_email IS NOT NULL AND TRIM(new_email) <> '' THEN
    UPDATE auth.users
    SET email = TRIM(new_email),
        email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        updated_at = NOW()
    WHERE id = target_user_id;
  END IF;

  IF new_password IS NOT NULL AND TRIM(new_password) <> '' THEN
    UPDATE auth.users
    SET encrypted_password = crypt(TRIM(new_password), gen_salt('bf')),
        updated_at = NOW()
    WHERE id = target_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, auth, extensions, pg_catalog;

DROP FUNCTION IF EXISTS public.delete_auth_user(UUID) CASCADE;
CREATE OR REPLACE FUNCTION public.delete_auth_user(target_user_id UUID)
RETURNS VOID AS $$
BEGIN
  IF get_user_role() NOT IN ('management', 'admin', 'org_admin', 'superadmin', 'manager')
     AND LOWER(COALESCE(auth.jwt()->>'email', '')) NOT LIKE '%management%'
     AND LOWER(COALESCE(auth.jwt()->>'email', '')) NOT LIKE 'admin@%' THEN
    RAISE EXCEPTION 'Access denied: Only management can delete authentication records.';
  END IF;

  DELETE FROM auth.users WHERE id = target_user_id;
  DELETE FROM public.profiles WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, auth, extensions, pg_catalog;

DROP FUNCTION IF EXISTS public.lookup_auth_email_for_login(TEXT, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION public.lookup_auth_email_for_login(
  identifier TEXT,
  target_role TEXT
)
RETURNS TABLE (auth_email TEXT) AS $$
DECLARE
  clean_id TEXT := TRIM(identifier);
  clean_digits TEXT := REGEXP_REPLACE(identifier, '[^\d]', '', 'g');
BEGIN
  RETURN QUERY
  SELECT p.email
  FROM public.profiles p
  WHERE LOWER(p.role) = LOWER(target_role)
    AND (
      LOWER(p.email) = LOWER(clean_id)
      OR (clean_digits <> '' AND REGEXP_REPLACE(COALESCE(p.phone, ''), '[^\d]', '', 'g') = clean_digits)
      OR (p.roll_number IS NOT NULL AND LOWER(p.roll_number) = LOWER(clean_id))
    )
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public, pg_catalog;

GRANT EXECUTE ON FUNCTION public.lookup_auth_email_for_login(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_auth_user(UUID, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_auth_user(UUID) TO authenticated, service_role;

-- =========================================================================
-- AUTOMATIC SYNC: ENSURE ALL PROFILES HAVE AUTH ACCOUNTS WITH WORKING PASSWORDS
-- =========================================================================
DO $$
DECLARE
  p RECORD;
  v_pass TEXT;
BEGIN
  FOR p IN 
    SELECT id, email, name, role, org_id, login_pin, phone
    FROM public.profiles
    WHERE email IS NOT NULL AND TRIM(email) <> ''
  LOOP
    v_pass := COALESCE(TRIM(p.login_pin), 'password');
    IF v_pass = '' THEN
      v_pass := 'password';
    END IF;

    -- Upsert auth user record
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      aud,
      role,
      created_at,
      updated_at,
      raw_app_meta_data,
      raw_user_meta_data
    )
    VALUES (
      p.id,
      '00000000-0000-0000-0000-000000000000'::uuid,
      LOWER(TRIM(p.email)),
      crypt(v_pass, gen_salt('bf')),
      NOW(),
      'authenticated',
      'authenticated',
      NOW(),
      NOW(),
      jsonb_build_object('provider', 'email', 'providers', array['email']),
      jsonb_build_object('role', p.role, 'org_id', p.org_id, 'name', p.name)
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        encrypted_password = crypt(v_pass, gen_salt('bf')),
        email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW()),
        updated_at = NOW();
  END LOOP;
END $$;

-- Force Supabase PostgREST to reload schema cache for new columns
NOTIFY pgrst, 'reload schema';


