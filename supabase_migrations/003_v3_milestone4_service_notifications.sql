-- ================================================================
-- Fuel Logger v3.0.0 — Milestone 4 Migration (DEV First, Backward-Compatible)
-- Features: F5 (public.service_logs) + F6 (public.app_announcements)
-- ================================================================

-- ── 1. F5: Service Logs Table ──

CREATE TABLE IF NOT EXISTS public.service_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    service_date DATE NOT NULL,
    odometer NUMERIC(10, 1) NOT NULL,
    service_type TEXT NOT NULL,
    service_center TEXT,
    total_cost NUMERIC(10, 2) NOT NULL,
    next_due_km NUMERIC(10, 1),
    next_due_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_service_logs_vehicle_date
    ON public.service_logs(vehicle_id, service_date DESC);

ALTER TABLE public.service_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own service logs" ON public.service_logs;
CREATE POLICY "Users can manage their own service logs"
    ON public.service_logs FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ── 2. F6: Phase 1.5 DB-Scheduled Announcements & Festival Wishes ──

CREATE TABLE IF NOT EXISTS public.app_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'announcement', -- 'wish', 'tip', 'update', 'announcement'
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    target_route TEXT, -- e.g. 'home', 'service', 'logs', 'upload'
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_announcements_active_schedule
    ON public.app_announcements(is_active, scheduled_at DESC);

ALTER TABLE public.app_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read active announcements" ON public.app_announcements;
CREATE POLICY "Authenticated users can read active announcements"
    ON public.app_announcements FOR SELECT
    TO authenticated
    USING (is_active = true);
