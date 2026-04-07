-- Safe fix for casting users.role text -> enum user_role with value normalization
-- Idempotent: only runs if column is still text
DO $$
DECLARE
  v_data_type text;
BEGIN
  SELECT data_type INTO v_data_type
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'role';

  IF v_data_type = 'text' THEN
    -- Ensure enum exists (no-op if already there)
    BEGIN
      EXECUTE 'CREATE TYPE public.user_role AS ENUM (''admin'',''gestor'',''cliente'')';
    EXCEPTION WHEN duplicate_object THEN NULL; END;

    -- Normalize legacy role values
    UPDATE public.users SET role = CASE lower(role)
        WHEN 'admin' THEN 'admin'
        WHEN 'super_admin' THEN 'admin'
        WHEN 'dpo' THEN 'gestor'
        WHEN 'agent' THEN 'gestor'
        WHEN 'gestor' THEN 'gestor'
        WHEN 'client' THEN 'cliente'
        WHEN 'cliente' THEN 'cliente'
        WHEN 'user' THEN 'cliente'
        ELSE 'cliente' END
    WHERE role NOT IN ('admin','gestor','cliente');

    -- Cast column
    ALTER TABLE public.users
      ALTER COLUMN role DROP DEFAULT,
      ALTER COLUMN role TYPE public.user_role USING (role::public.user_role),
      ALTER COLUMN role SET DEFAULT 'cliente'::public.user_role;
  END IF;
END $$;

-- Optional: ensure not null constraint remains
ALTER TABLE public.users ALTER COLUMN role SET NOT NULL;