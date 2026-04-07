-- Create new enum user_role
DO $$ BEGIN
  CREATE TYPE "public"."user_role" AS ENUM('admin', 'gestor', 'cliente');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Ensure column exists and convert values from legacy roles
-- 1) Add temporary column if needed
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'role'
  ) THEN
    ALTER TABLE "public"."users" ADD COLUMN "role" text NOT NULL DEFAULT 'cliente';
  END IF;
END $$;

-- 2) Normalize legacy roles into new set
UPDATE "public"."users" SET "role" = CASE lower("role")
  WHEN 'admin' THEN 'admin'
  WHEN 'super_admin' THEN 'admin'
  WHEN 'dpo' THEN 'gestor'
  WHEN 'agent' THEN 'gestor'
  WHEN 'client' THEN 'cliente'
  WHEN 'user' THEN 'cliente'
  ELSE 'cliente'
END;

-- 3) Alter column type to user_role enum with using cast
ALTER TABLE "public"."users"
  ALTER COLUMN "role" DROP DEFAULT,
  ALTER COLUMN "role" TYPE "public"."user_role" USING ("role"::"public"."user_role"),
  ALTER COLUMN "role" SET DEFAULT 'cliente'::"public"."user_role";
