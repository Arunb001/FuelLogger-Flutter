-- ================================================================
-- Fuel Logger v3.0.0 — Milestone 3 Migration (DEV First, Backward-Compatible)
-- Feature F3: Optional Fuel Station Name & Remark on public.fuel_logs
-- ================================================================

ALTER TABLE public.fuel_logs
    ADD COLUMN IF NOT EXISTS station_name TEXT;

ALTER TABLE public.fuel_logs
    ADD COLUMN IF NOT EXISTS remark TEXT;

CREATE INDEX IF NOT EXISTS idx_fuel_logs_station
    ON public.fuel_logs(user_id, station_name)
    WHERE station_name IS NOT NULL;
