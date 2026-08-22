-- =========================================================================
-- MAVIO Database Optimization Rules
-- Run this SQL in your Supabase SQL Editor (https://supabase.com)
-- =========================================================================

-- 1. CLEAN UP COORDINATES WHEN TRIP ENDS
-- Automatically deletes coordinates from location_updates when trip status = 'COMPLETED'
CREATE OR REPLACE FUNCTION public.clean_up_completed_trip_locations()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'COMPLETED' AND OLD.status = 'ACTIVE' THEN
    -- Deletes all raw coordinates recorded during the trip to free up database space
    DELETE FROM public.location_updates 
    WHERE trip_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if it already exists to prevent duplicate execution errors
DROP TRIGGER IF EXISTS tr_clean_up_completed_trip_locations ON public.trips;

-- Create trigger on public.trips table
CREATE TRIGGER tr_clean_up_completed_trip_locations
AFTER UPDATE ON public.trips
FOR EACH ROW
EXECUTE FUNCTION public.clean_up_completed_trip_locations();


-- 2. AUTO-DELETE OLD TRIPS AFTER 60 DAYS
-- Automatically deletes trip records older than 60 days
CREATE OR REPLACE FUNCTION public.delete_old_trips()
RETURNS VOID AS $$
BEGIN
  -- Deleting from public.trips automatically deletes any remaining cascading data due to ON DELETE CASCADE
  DELETE FROM public.trips 
  WHERE started_at < NOW() - INTERVAL '60 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable pg_cron extension if supported in your Supabase instance to run it daily automatically
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the delete function to run every day at midnight (00:00)
SELECT cron.schedule(
  'delete-old-trips-job',
  '0 0 * * *',
  $$ SELECT public.delete_old_trips(); $$
);
