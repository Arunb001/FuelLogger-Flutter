-- ================================================================
-- Fuel Logger v3.1.0 — Milestone 6 Migration (DEV First, Idempotent)
-- Feature F9: Fuel Cards & Monthly Auto-Reset + Fill-Up Card Link
-- ================================================================

CREATE TABLE IF NOT EXISTS public.fuel_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    card_name TEXT NOT NULL,
    card_limit NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (card_limit >= 0),
    limit_used NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (limit_used >= 0),
    is_primary BOOLEAN NOT NULL DEFAULT false,
    reset_day_of_month INT NOT NULL DEFAULT 1
        CHECK (reset_day_of_month >= 1 AND reset_day_of_month <= 31),
    last_reset_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- At most one primary fuel card per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_primary_card_per_user
    ON public.fuel_cards(user_id)
    WHERE is_primary = true;

CREATE INDEX IF NOT EXISTS idx_fuel_cards_user
    ON public.fuel_cards(user_id);

ALTER TABLE public.fuel_cards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fuel_cards_own" ON public.fuel_cards;
CREATE POLICY "fuel_cards_own"
    ON public.fuel_cards FOR ALL
    TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.fuel_cards TO authenticated;

-- Atomic RPC to switch primary card without partial unique index conflict
CREATE OR REPLACE FUNCTION public.set_primary_fuel_card(p_card_id UUID)
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
        FROM public.fuel_cards
        WHERE id = p_card_id
          AND user_id = v_uid
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN FALSE;
    END IF;

    UPDATE public.fuel_cards
       SET is_primary = false,
           updated_at = now()
     WHERE user_id = v_uid
       AND is_primary = true
       AND id <> p_card_id;

    UPDATE public.fuel_cards
       SET is_primary = true,
           updated_at = now()
     WHERE id = p_card_id
       AND user_id = v_uid;

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.set_primary_fuel_card(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_primary_fuel_card(UUID) TO authenticated;

-- Link fill-up logs to an optional fuel card (preserve log if card deleted)
ALTER TABLE public.fuel_logs
    ADD COLUMN IF NOT EXISTS fuel_card_id UUID REFERENCES public.fuel_cards(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_fuel_logs_fuel_card
    ON public.fuel_logs(fuel_card_id)
    WHERE fuel_card_id IS NOT NULL;
