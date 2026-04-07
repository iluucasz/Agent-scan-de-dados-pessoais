-- Add missing user columns safely (idempotent)
DO $$
BEGIN
  -- email_verified_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='users' AND column_name='email_verified_at'
  ) THEN
    ALTER TABLE public.users ADD COLUMN email_verified_at timestamp;
  END IF;

  -- current_organization_id (in case not added yet)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='users' AND column_name='current_organization_id'
  ) THEN
    ALTER TABLE public.users ADD COLUMN current_organization_id integer;
  END IF;
END $$;

-- Optional future-proof index (fast lookups by email)
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
