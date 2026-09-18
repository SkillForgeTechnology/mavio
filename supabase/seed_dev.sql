-- =========================================================================
-- MAVIO SEED DATA — DEVELOPMENT / STAGING ONLY
-- DO NOT RUN IN PRODUCTION!
-- =========================================================================

-- Safety guard: Abort if this is running in a production-like environment.
-- Uncomment and set your production project ref to prevent accidental execution:
-- DO $$
-- BEGIN
--   IF current_setting('app.settings.project_ref', true) = 'YOUR_PROD_PROJECT_REF' THEN
--     RAISE EXCEPTION 'ABORT: Seed data must not be run in production!';
--   END IF;
-- END $$;

-- 0. Clean up existing test users from auth.users to ensure fresh metadata is inserted
DELETE FROM auth.users WHERE id IN (
  'd1b11111-1111-1111-1111-111111111111',
  'd2b22222-2222-2222-2222-222222222222',
  'd3b33333-3333-3333-3333-333333333333'
);

-- 1. Insert Default Organization
INSERT INTO public.organizations (id, code, name)
VALUES ('8a7a9a1a-1234-5678-abcd-ef0123456789', 'ABC123', 'ABC Engineering College')
ON CONFLICT (id) DO NOTHING;

-- 2. Insert Test Users in auth.users (encrypted password hash for 'password')
-- WARNING: These use trivial passwords and must NEVER be used in production.
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, role, aud, confirmation_token,
  raw_app_meta_data, raw_user_meta_data, is_super_admin,
  email_change, email_change_token_new, recovery_token,
  email_change_token_current, phone_change_token,
  reauthentication_token, phone_change, is_sso_user
)
VALUES 
  ('d1b11111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'student@mavio.com', crypt('password', gen_salt('bf')), now(), now(), now(), 'authenticated', 'authenticated', '', '{"provider": "email", "providers": ["email"]}', '{}', false, '', '', '', '', '', '', '', false),
  ('d2b22222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'driver@mavio.com', crypt('password', gen_salt('bf')), now(), now(), now(), 'authenticated', 'authenticated', '', '{"provider": "email", "providers": ["email"]}', '{}', false, '', '', '', '', '', '', '', false),
  ('d3b33333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'admin@mavio.com', crypt('password', gen_salt('bf')), now(), now(), now(), 'authenticated', 'authenticated', '', '{"provider": "email", "providers": ["email"]}', '{}', false, '', '', '', '', '', '', '', false)
ON CONFLICT (id) DO NOTHING;

-- 2.5. Insert Test User Identities (Required by GoTrue Auth)
INSERT INTO auth.identities (id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, provider_id)
VALUES 
  ('d1b11111-1111-1111-1111-111111111111', 'd1b11111-1111-1111-1111-111111111111', jsonb_build_object('sub', 'd1b11111-1111-1111-1111-111111111111', 'email', 'student@mavio.com', 'email_verified', true, 'phone_verified', false), 'email', now(), now(), now(), 'student@mavio.com'),
  ('d2b22222-2222-2222-2222-222222222222', 'd2b22222-2222-2222-2222-222222222222', jsonb_build_object('sub', 'd2b22222-2222-2222-2222-222222222222', 'email', 'driver@mavio.com', 'email_verified', true, 'phone_verified', false), 'email', now(), now(), now(), 'driver@mavio.com'),
  ('d3b33333-3333-3333-3333-333333333333', 'd3b33333-3333-3333-3333-333333333333', jsonb_build_object('sub', 'd3b33333-3333-3333-3333-333333333333', 'email', 'admin@mavio.com', 'email_verified', true, 'phone_verified', false), 'email', now(), now(), now(), 'admin@mavio.com')
ON CONFLICT (id) DO NOTHING;

-- 3. Insert Matching Public Profiles
INSERT INTO public.profiles (id, email, name, role, org_id)
VALUES 
  ('d1b11111-1111-1111-1111-111111111111', 'student@mavio.com', 'Mathan S', 'student', '8a7a9a1a-1234-5678-abcd-ef0123456789'),
  ('d2b22222-2222-2222-2222-222222222222', 'driver@mavio.com', 'Ravi Kumar', 'driver', '8a7a9a1a-1234-5678-abcd-ef0123456789'),
  ('d3b33333-3333-3333-3333-333333333333', 'admin@mavio.com', 'Admin User', 'management', '8a7a9a1a-1234-5678-abcd-ef0123456789')
ON CONFLICT (id) DO NOTHING;

-- 4. Seed Vehicles
INSERT INTO public.vehicles (id, name, reg_number, status, org_id)
VALUES 
  ('e1a11111-1111-1111-1111-111111111111', 'BUS 03', 'TN 38 AB 1234', 'OFFLINE', '8a7a9a1a-1234-5678-abcd-ef0123456789'),
  ('e2a22222-2222-2222-2222-222222222222', 'BUS 01', 'TN 38 AB 5678', 'OFFLINE', '8a7a9a1a-1234-5678-abcd-ef0123456789'),
  ('e3a33333-3333-3333-3333-333333333333', 'BUS 02', 'TN 38 AB 9012', 'OFFLINE', '8a7a9a1a-1234-5678-abcd-ef0123456789')
ON CONFLICT (id) DO NOTHING;

-- 5. Assign Driver to Bus and Student to Route/Bus
UPDATE public.profiles 
SET assigned_vehicle_id = 'e1a11111-1111-1111-1111-111111111111'
WHERE id = 'd2b22222-2222-2222-2222-222222222222'; -- Ravi Kumar -> BUS 03

UPDATE public.profiles 
SET assigned_vehicle_id = 'e1a11111-1111-1111-1111-111111111111'
WHERE id = 'd1b11111-1111-1111-1111-111111111111'; -- Mathan S -> BUS 03
