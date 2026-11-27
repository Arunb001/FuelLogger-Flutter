-- ================================================================
-- Fuel Logger v3.1.0 — Milestone 6 Trigger, Permissions & Fuel Type Fix
-- Fixes:
-- 1. handle_new_user() inserts ONLY 'Standard petrol' & 'My Vehicle' (no limits / no legacy 4 fuels)
-- 2. Cleans legacy trigger fuel types (XP95, XP100, Unleaded, Power) for users with 0 fuel logs
-- 3. Ensures Data API table GRANTs are applied on DEV/PROD for authenticated & anon roles
-- 4. Updates remote app_config version metadata to 3.1.0 (Build 25)
-- ================================================================

-- ── 1. Fix Signup Trigger ──

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.vehicles (user_id, name, is_active)
    VALUES (NEW.id, 'My Vehicle', true);

    INSERT INTO public.fuel_types (user_id, name, color)
    VALUES (NEW.id, 'Standard petrol', '#FF5252');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 2. Clean Up Legacy Default Fuel Types for Zero-Log Users ──

WITH zero_log_users AS (
    SELECT u.id AS user_id
    FROM auth.users u
    WHERE NOT EXISTS (
        SELECT 1 FROM public.fuel_logs fl WHERE fl.user_id = u.id
    )
)
DELETE FROM public.fuel_types ft
USING zero_log_users z
WHERE ft.user_id = z.user_id
  AND lower(trim(ft.name)) IN ('xp95', 'xp100', 'unleaded', 'power', 'standard / unleaded');

-- Ensure every user with 0 remaining fuel types gets 'Standard petrol'
INSERT INTO public.fuel_types (user_id, name, color)
SELECT u.id, 'Standard petrol', '#FF5252'
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.fuel_types ft WHERE ft.user_id = u.id
);

-- ── 3. Ensure Core Table Grants for Supabase Data API ──

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.vehicles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fuel_types TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fuel_logs TO authenticated;

DO $$
BEGIN
    IF to_regclass('public.service_logs') IS NOT NULL THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON public.service_logs TO authenticated;
    END IF;
    IF to_regclass('public.fuel_cards') IS NOT NULL THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON public.fuel_cards TO authenticated;
    END IF;
    IF to_regclass('public.app_config') IS NOT NULL THEN
        GRANT SELECT ON public.app_config TO anon, authenticated;
        UPDATE public.app_config
           SET latest_version = '3.1.0',
               latest_build = 25,
               min_supported_build = 23,
               is_critical = false,
               update_title = 'Fuel Logger 3.1 Available',
               update_notes = 'Fuel cards with monthly auto-reset, reorganized Fuel/Service views, and improved Home dashboard.',
               updated_at = now()
         WHERE platform = 'android';
    END IF;
    IF to_regclass('public.app_announcements') IS NOT NULL THEN
        GRANT SELECT ON public.app_announcements TO anon, authenticated;
    END IF;
END $$;
