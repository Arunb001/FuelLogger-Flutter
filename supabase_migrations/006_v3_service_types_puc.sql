-- ================================================================
-- Fuel Logger v3.2.0 — Milestone 7 Migration (DEV First, Idempotent)
-- Features:
--   1. public.service_types table (single default 'General Repair', RLS + GRANTs)
--   2. public.vehicles PUC columns (puc_expiry_date, puc_renewal_months)
--   3. Updated handle_new_user() trigger + app_config (3.2.0 Build 26)
-- ================================================================

-- ── 1. Custom Service Types Table (mirrors public.fuel_types) ──

CREATE TABLE IF NOT EXISTS public.service_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_service_types_user_lower_name
    ON public.service_types(user_id, lower(trim(name)));

CREATE INDEX IF NOT EXISTS idx_service_types_user
    ON public.service_types(user_id);

ALTER TABLE public.service_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_types_own" ON public.service_types;
CREATE POLICY "service_types_own"
    ON public.service_types FOR ALL
    TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.service_types TO authenticated;

-- Preserve any distinct service types already recorded in historical service_logs
DO $$
BEGIN
    IF to_regclass('public.service_logs') IS NOT NULL THEN
        INSERT INTO public.service_types (user_id, name)
        SELECT DISTINCT sl.user_id, trim(sl.service_type)
        FROM public.service_logs sl
        WHERE trim(sl.service_type) <> ''
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- Seed single default 'General Repair' for users with no service types yet
INSERT INTO public.service_types (user_id, name)
SELECT u.id, 'General Repair'
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.service_types st WHERE st.user_id = u.id
)
ON CONFLICT DO NOTHING;

-- Update signup trigger so new accounts start cleanly with single defaults
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.vehicles (user_id, name, is_active)
    VALUES (NEW.id, 'My Vehicle', true);

    INSERT INTO public.fuel_types (user_id, name, color)
    VALUES (NEW.id, 'Standard petrol', '#FF5252');

    INSERT INTO public.service_types (user_id, name)
    VALUES (NEW.id, 'General Repair')
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 2. Per-Vehicle Pollution Certificate (PUC) Columns (F10) ──

ALTER TABLE public.vehicles
    ADD COLUMN IF NOT EXISTS puc_expiry_date DATE,
    ADD COLUMN IF NOT EXISTS puc_renewal_months INT DEFAULT 6;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'vehicles_puc_renewal_months_check'
    ) THEN
        ALTER TABLE public.vehicles
            ADD CONSTRAINT vehicles_puc_renewal_months_check
            CHECK (puc_renewal_months IS NULL OR (puc_renewal_months >= 1 AND puc_renewal_months <= 60));
    END IF;
END $$;

UPDATE public.vehicles
   SET puc_renewal_months = 6
 WHERE puc_renewal_months IS NULL;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.vehicles TO authenticated;

-- ── 3. Remote App Config Version Metadata (3.2.0 Build 26) ──

DO $$
BEGIN
    IF to_regclass('public.app_config') IS NOT NULL THEN
        UPDATE public.app_config
           SET latest_version = '3.2.0',
               latest_build = 26,
               min_supported_build = 24,
               is_critical = false,
               update_title = 'Fuel Logger 3.2 Available',
               update_notes = 'Pollution Certificate (PUC) tracker, streamlined Service Types, consolidated Settings, and UI polish.',
               updated_at = now()
         WHERE platform = 'android';
    END IF;
END $$;
