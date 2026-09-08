-- ============================================================================
-- MAVIO SUPABASE SERVER-SIDE PROXIMITY ALERT TRIGGER (V4 - ULTRA SAFE & NON-BLOCKING)
-- ============================================================================

-- 1. Enable pg_net extension
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Create table to prevent duplicate proximity alerts per trip
CREATE TABLE IF NOT EXISTS public.trip_proximity_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id TEXT NOT NULL,
    student_id TEXT NOT NULL,
    distance_meters DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_trip_student_alert UNIQUE (trip_id, student_id)
);

-- Enable RLS
ALTER TABLE public.trip_proximity_alerts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow service_role read/write trip_proximity_alerts" ON public.trip_proximity_alerts;
CREATE POLICY "Allow service_role read/write trip_proximity_alerts"
    ON public.trip_proximity_alerts
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 3. Create Haversine Distance Function
CREATE OR REPLACE FUNCTION public.calculate_distance_meters(
    lat1 DOUBLE PRECISION,
    lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lon2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION AS $$
DECLARE
    r CONSTANT DOUBLE PRECISION := 6371000; -- Earth radius in meters
    dlat DOUBLE PRECISION;
    dlon DOUBLE PRECISION;
    a DOUBLE PRECISION;
    c DOUBLE PRECISION;
BEGIN
    dlat := radians(lat2 - lat1);
    dlon := radians(lon2 - lon1);
    a := sin(dlat / 2)^2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2)^2;
    c := 2 * atan2(sqrt(a), sqrt(1 - a));
    RETURN r * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 4. Trigger Function: Evaluates proximity on every location_updates INSERT and dispatches OneSignal Push
CREATE OR REPLACE FUNCTION public.handle_bus_proximity_alert()
RETURNS TRIGGER AS $$
DECLARE
    v_vehicle_id TEXT;
    v_vehicle_name TEXT;
    v_onesignal_app_id CONSTANT TEXT := '2633169a-2c5f-4856-bfd3-12361105dc17';
    -- Replace with your OneSignal REST API Key if configuring server-side
    v_onesignal_api_key CONSTANT TEXT := 'YOUR_ONESIGNAL_REST_API_KEY';
    student_record RECORD;
    v_distance DOUBLE PRECISION;
    v_radius INT;
    v_dist_text TEXT;
    v_sub_tokens JSONB;
    v_payload JSONB;
    v_http_schema TEXT := NULL;
BEGIN
    -- Wrap in exception handler so location_updates INSERT is NEVER blocked
    BEGIN
        -- Look up the vehicle for this trip (type-safe text match)
        SELECT t.vehicle_id::TEXT, COALESCE(v.name, 'Mavio Bus')
        INTO v_vehicle_id, v_vehicle_name
        FROM public.trips t
        LEFT JOIN public.vehicles v ON v.id::TEXT = t.vehicle_id::TEXT
        WHERE t.id::TEXT = NEW.trip_id::TEXT;

        IF v_vehicle_id IS NOT NULL THEN
            -- Iterate through all students assigned to this bus who have alert coordinates set
            FOR student_record IN
                SELECT 
                    p.id::TEXT AS student_id, 
                    p.name, 
                    p.onesignal_id,
                    p.alert_latitude, 
                    p.alert_longitude, 
                    COALESCE(p.alert_radius_meters, 500) AS alert_radius
                FROM public.profiles p
                WHERE p.assigned_vehicle_id::TEXT = v_vehicle_id
                  AND LOWER(p.role) = 'student'
                  AND p.alert_latitude IS NOT NULL
                  AND p.alert_longitude IS NOT NULL
                  -- Exclude students already alerted for this trip
                  AND NOT EXISTS (
                      SELECT 1 FROM public.trip_proximity_alerts a
                      WHERE a.trip_id::TEXT = NEW.trip_id::TEXT AND a.student_id::TEXT = p.id::TEXT
                  )
            LOOP
                v_distance := public.calculate_distance_meters(
                    NEW.latitude,
                    NEW.longitude,
                    student_record.alert_latitude,
                    student_record.alert_longitude
                );

                v_radius := student_record.alert_radius;

                -- If the bus is within student's radius, dispatch OneSignal push
                IF v_distance <= v_radius THEN
                    -- Record alert immediately to prevent concurrent duplicates
                    INSERT INTO public.trip_proximity_alerts (trip_id, student_id, distance_meters)
                    VALUES (NEW.trip_id::TEXT, student_record.student_id, v_distance)
                    ON CONFLICT (trip_id, student_id) DO NOTHING;

                    IF v_distance < 1000 THEN
                        v_dist_text := round(v_distance)::TEXT || 'm';
                    ELSE
                        v_dist_text := to_char(v_distance / 1000, 'FM999990.0') || 'km';
                    END IF;

                    -- Build subscription token array from onesignal_id column
                    IF student_record.onesignal_id IS NOT NULL AND trim(student_record.onesignal_id) <> '' THEN
                        SELECT jsonb_agg(trim(token))
                        INTO v_sub_tokens
                        FROM unnest(string_to_array(student_record.onesignal_id, ',')) AS token
                        WHERE trim(token) <> '';
                    ELSE
                        v_sub_tokens := NULL;
                    END IF;

                    -- Build OneSignal REST API Payload (Direct Hardware Token prioritized)
                    IF v_sub_tokens IS NOT NULL AND jsonb_array_length(v_sub_tokens) > 0 THEN
                        v_payload := jsonb_build_object(
                            'app_id', v_onesignal_app_id,
                            'include_subscription_ids', v_sub_tokens,
                            'target_channel', 'push',
                            'headings', jsonb_build_object('en', '🚌 Bus Approaching!'),
                            'contents', jsonb_build_object('en', v_vehicle_name || ' is approaching your stop (' || v_dist_text || ' away). Please be ready!'),
                            'data', jsonb_build_object('tripId', NEW.trip_id::TEXT, 'type', 'proximity_alert'),
                            'collapse_id', 'prox_' || student_record.student_id,
                            'priority', 10,
                            'android_visibility', 1,
                            'android_accent_color', 'FF1E3A8A'
                        );
                    ELSE
                        v_payload := jsonb_build_object(
                            'app_id', v_onesignal_app_id,
                            'include_aliases', jsonb_build_object('external_id', jsonb_build_array(student_record.student_id)),
                            'target_channel', 'push',
                            'headings', jsonb_build_object('en', '🚌 Bus Approaching!'),
                            'contents', jsonb_build_object('en', v_vehicle_name || ' is approaching your stop (' || v_dist_text || ' away). Please be ready!'),
                            'data', jsonb_build_object('tripId', NEW.trip_id::TEXT, 'type', 'proximity_alert'),
                            'collapse_id', 'prox_' || student_record.student_id,
                            'priority', 10,
                            'android_visibility', 1,
                            'android_accent_color', 'FF1E3A8A'
                        );
                    END IF;

                    -- Send HTTP Post to OneSignal using Supabase pg_net extension (dynamically resolved)
                    BEGIN
                        SELECT n.nspname INTO v_http_schema
                        FROM pg_proc p
                        JOIN pg_namespace n ON p.pronamespace = n.oid
                        WHERE p.proname = 'http_post' AND n.nspname IN ('net', 'extensions', 'public')
                        LIMIT 1;

                        IF v_http_schema IS NOT NULL THEN
                            EXECUTE format(
                                'SELECT %I.http_post(url := $1, headers := $2, body := $3)',
                                v_http_schema
                            )
                            USING 
                                'https://api.onesignal.com/notifications',
                                jsonb_build_object(
                                    'Content-Type', 'application/json; charset=utf-8',
                                    'Authorization', 'Key ' || v_onesignal_api_key
                                ),
                                v_payload;
                        END IF;
                    EXCEPTION WHEN OTHERS THEN
                        RAISE WARNING 'OneSignal push dispatch error: %', SQLERRM;
                    END;
                END IF;
            END LOOP;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Proximity trigger error: %', SQLERRM;
    END;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Attach Trigger to location_updates table
DROP TRIGGER IF EXISTS trigger_bus_proximity_alert ON public.location_updates;
CREATE TRIGGER trigger_bus_proximity_alert
    AFTER INSERT ON public.location_updates
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_bus_proximity_alert();
