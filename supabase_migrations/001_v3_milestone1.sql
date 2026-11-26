-- ================================================================
-- Fuel Logger v3.0.0 — Milestone 1 Migration (DEV First, Backward-Compatible)
-- Run in Supabase Dashboard -> SQL Editor (qjwuajdcyrdlnjplvtsr first, then PROD later)
-- Includes: BUG-01 (vehicles.is_active), F7 (2-vehicle limit + Option B grandfathering), F8 (app_config)
-- ================================================================

-- ── 1. BUG-01: Single Active Vehicle Constraint & Atomic RPC ──

UPDATE public.vehicles
SET is_active = false
WHERE is_active IS NULL;

-- Pre-heal any user with multiple active vehicles (keep newest active row)
WITH ranked_active AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST, id) AS rn
    FROM public.vehicles
    WHERE is_active = true
)
UPDATE public.vehicles v
SET is_active = false
FROM ranked_active r
WHERE v.id = r.id
  AND r.rn > 1;

-- Pre-heal any user who owns vehicles but currently has 0 active rows (promote earliest vehicle)
WITH users_without_active AS (
    SELECT user_id
    FROM public.vehicles
    GROUP BY user_id
    HAVING NOT COALESCE(BOOL_OR(is_active), false)
),
first_vehicle AS (
    SELECT DISTINCT ON (v.user_id) v.id
    FROM public.vehicles v
    JOIN users_without_active u ON u.user_id = v.user_id
    ORDER BY v.user_id, v.created_at ASC NULLS LAST, v.id
)
UPDATE public.vehicles v
SET is_active = true
FROM first_vehicle fv
WHERE v.id = fv.id;

-- Enforce at most 1 active vehicle per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_active_vehicle_per_user
    ON public.vehicles(user_id)
    WHERE is_active = true;

-- Atomic RPC called by Flutter app on vehicle add, switch, load, or delete promotion
CREATE OR REPLACE FUNCTION public.set_active_vehicle(p_vehicle_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_exists BOOLEAN;
BEGIN
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.vehicles
        WHERE id = p_vehicle_id
          AND user_id = v_uid
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN FALSE;
    END IF;

    -- Deactivate previous active vehicle first so partial unique index never conflicts
    UPDATE public.vehicles
       SET is_active = false,
           updated_at = now()
     WHERE user_id = v_uid
       AND is_active = true
       AND id <> p_vehicle_id;

    UPDATE public.vehicles
       SET is_active = true,
           updated_at = now()
     WHERE id = p_vehicle_id
       AND user_id = v_uid;

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.set_active_vehicle(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_active_vehicle(UUID) TO authenticated;

-- ── 2. F7: User Entitlements (2-Vehicle Free Cap + Option B Grandfathering) ──

CREATE TABLE IF NOT EXISTS public.user_entitlements (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    is_pro BOOLEAN NOT NULL DEFAULT false,
    is_grandfathered BOOLEAN NOT NULL DEFAULT false,
    max_free_vehicles INT NOT NULL DEFAULT 2,
    plan_name TEXT NOT NULL DEFAULT 'free',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.user_entitlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own entitlements" ON public.user_entitlements;
CREATE POLICY "Users can view their own entitlements"
    ON public.user_entitlements FOR SELECT
    TO authenticated
    USING ((SELECT auth.uid()) = user_id);

-- Option B Approved: Grandfather ALL existing registered users prior to v3.0.0 rollout
INSERT INTO public.user_entitlements (user_id, is_pro, is_grandfathered, max_free_vehicles, plan_name)
SELECT u.id, false, true, 2, 'free'
FROM auth.users u
ON CONFLICT (user_id) DO UPDATE
    SET is_grandfathered = true,
        updated_at = now();

-- Update signup trigger so new users after rollout start with 1 active vehicle,
-- strictly 1 default fuel type ('Standard petrol'), and free 2-vehicle entitlement
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.vehicles (user_id, name, is_active)
    VALUES (NEW.id, 'My Vehicle', true);

    INSERT INTO public.fuel_types (user_id, name, color)
    VALUES (NEW.id, 'Standard petrol', '#FF5252');

    INSERT INTO public.user_entitlements (user_id, is_pro, is_grandfathered, max_free_vehicles, plan_name)
    VALUES (NEW.id, false, false, 2, 'free')
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 3. F8: Remote App Version & 2-Backward-Version Force Update Config ──

CREATE TABLE IF NOT EXISTS public.app_config (
    platform TEXT PRIMARY KEY,
    latest_version TEXT NOT NULL,
    latest_build INT NOT NULL,
    min_supported_build INT NOT NULL,
    is_critical BOOLEAN NOT NULL DEFAULT false,
    update_title TEXT DEFAULT 'Update Available',
    update_notes TEXT DEFAULT '',
    play_store_url TEXT DEFAULT 'https://play.google.com/store/apps/details?id=com.fuellogger.app',
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read access for app_config" ON public.app_config;
CREATE POLICY "Public read access for app_config"
    ON public.app_config FOR SELECT
    TO anon, authenticated
    USING (true);

INSERT INTO public.app_config (
    platform,
    latest_version,
    latest_build,
    min_supported_build,
    is_critical,
    update_title,
    update_notes,
    play_store_url
)
VALUES (
    'android',
    '3.0.0',
    24,
    22,
    false,
    'Fuel Logger Update Available',
    'New themes, station tracking, service logs, and performance improvements are ready.',
    'https://play.google.com/store/apps/details?id=com.fuellogger.app'
)
ON CONFLICT (platform) DO NOTHING;

GRANT SELECT ON public.user_entitlements TO authenticated;
GRANT SELECT ON public.app_config TO anon, authenticated;
