-- Create tables for MAVIO Real-Time Transportation Visibility Platform

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Drop existing tables to allow resetting/re-running the schema cleanly
DROP TABLE IF EXISTS public.location_updates CASCADE;
DROP TABLE IF EXISTS public.trips CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.vehicles CASCADE;

DROP TABLE IF EXISTS public.organizations CASCADE;

-- 1. Organizations (Tenants)
CREATE TABLE public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Profiles (Extends auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('student', 'driver', 'management')),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE RESTRICT,
    assigned_vehicle_id UUID,
    phone TEXT,
    roll_number TEXT,
    dob TEXT,

    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Vehicles
CREATE TABLE public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL, -- e.g. "BUS 03"
    reg_number TEXT NOT NULL, -- e.g. "TN 38 AB 1234"
    status TEXT NOT NULL DEFAULT 'OFFLINE' CHECK (status IN ('LIVE', 'STOPPED', 'OFFLINE')),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now()
);



-- 6. Trips (Active tracking sessions)
CREATE TABLE public.trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'COMPLETED')),
    started_at TIMESTAMPTZ DEFAULT now(),
    ended_at TIMESTAMPTZ,
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE
);

-- 7. Location Updates (Streamed GPS records)
CREATE TABLE public.location_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    speed DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    heading DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    accuracy DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Add Foreign Keys to Profiles now that other tables exist
ALTER TABLE public.profiles ADD CONSTRAINT fk_profiles_vehicle FOREIGN KEY (assigned_vehicle_id) REFERENCES public.vehicles(id) ON DELETE SET NULL;


-- Enable Row Level Security (RLS) on all public tables
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.location_updates ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies (Isolate data by user's Organization ID)

-- Helper: Get user's org_id
CREATE OR REPLACE FUNCTION get_user_org_id()
RETURNS UUID AS $$
  SELECT org_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER SET row_security = off;

-- Helper: Update authentication email and/or password (restricted to management)
CREATE OR REPLACE FUNCTION public.update_auth_user(
  target_user_id UUID,
  new_email TEXT DEFAULT NULL,
  new_password TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  caller_role TEXT;
BEGIN
  -- Get the role of the caller
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  
  -- Only allow if caller is management
  IF caller_role != 'management' THEN
    RAISE EXCEPTION 'Access denied: Only management can update authentication records.';
  END IF;

  -- 1. Update email if provided
  IF new_email IS NOT NULL AND new_email != '' THEN
    UPDATE auth.users
    SET email = new_email,
        email_change = ''
    WHERE id = target_user_id;

    -- Also update the identity associated with this user to sync login email
    UPDATE auth.identities
    SET identity_data = jsonb_set(identity_data, '{email}', to_jsonb(new_email)),
        provider_id = new_email
    WHERE user_id = target_user_id;
  END IF;

  -- 2. Update password if provided
  IF new_password IS NOT NULL AND new_password != '' THEN
    UPDATE auth.users
    SET encrypted_password = crypt(new_password, gen_salt('bf'))
    WHERE id = target_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog, extensions, auth;

-- Helper: Delete user authentication and profile (restricted to management)
CREATE OR REPLACE FUNCTION public.delete_auth_user(target_user_id UUID)
RETURNS VOID AS $$
DECLARE
  caller_role TEXT;
BEGIN
  -- Get the role of the caller
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  
  -- Only allow if caller is management
  IF caller_role != 'management' THEN
    RAISE EXCEPTION 'Access denied: Only management can delete authentication records.';
  END IF;

  -- Delete from auth.users (cascades to public.profiles)
  DELETE FROM auth.users WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog, extensions, auth;



-- Organization Policies
CREATE POLICY "Allow public read of organizations by code"
    ON public.organizations FOR SELECT TO public USING (true);

-- Profile Policies
CREATE POLICY "Allow profiles to read within their organization"
    ON public.profiles FOR SELECT TO authenticated
    USING (org_id = get_user_org_id());

CREATE POLICY "Allow management to insert/update profiles in their organization"
    ON public.profiles FOR ALL TO authenticated
    USING (org_id = get_user_org_id())
    WITH CHECK (org_id = get_user_org_id());

-- Vehicle Policies
CREATE POLICY "Allow reading vehicles in the same organization"
    ON public.vehicles FOR SELECT TO authenticated
    USING (org_id = get_user_org_id());

CREATE POLICY "Allow management to modify vehicles"
    ON public.vehicles FOR ALL TO authenticated
    USING (org_id = get_user_org_id())
    WITH CHECK (org_id = get_user_org_id());



-- Trip Policies
CREATE POLICY "Allow reading trips in same organization"
    ON public.trips FOR SELECT TO authenticated
    USING (org_id = get_user_org_id());

CREATE POLICY "Allow driver and management to insert/modify trips"
    ON public.trips FOR ALL TO authenticated
    USING (org_id = get_user_org_id())
    WITH CHECK (org_id = get_user_org_id());

-- Location Update Policies
CREATE POLICY "Allow reading location updates if trip belongs to organization"
    ON public.location_updates FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.trips t 
            WHERE t.id = trip_id AND t.org_id = get_user_org_id()
        )
    );

CREATE POLICY "Allow drivers to insert location updates"
    ON public.location_updates FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.trips t 
            WHERE t.id = trip_id AND t.driver_id = auth.uid() AND t.status = 'ACTIVE'
        )
    );

-- Enable Supabase Realtime for Location Updates, Trips and Vehicles
ALTER PUBLICATION supabase_realtime ADD TABLE public.location_updates;
ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicles;

-- =========================================================================
-- SEED DATA has been moved to supabase/seed_dev.sql
-- DO NOT include seed data in the production schema.
-- To seed a dev/staging environment, run: seed_dev.sql
-- =========================================================================
