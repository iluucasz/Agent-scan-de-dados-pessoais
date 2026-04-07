CREATE TYPE "public"."user_role" AS ENUM('admin', 'gestor', 'cliente');--> statement-breakpoint
CREATE TYPE "public"."auth_token_purpose" AS ENUM('MAGIC_LOGIN', 'INVITE', 'VERIFY_EMAIL');--> statement-breakpoint
CREATE TABLE "auth_tokens" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid,
	"email" text NOT NULL,
	"purpose" "auth_token_purpose" NOT NULL,
	"token_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"used_at" timestamp with time zone,
	"ip" text,
	"user_agent" text,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "user_managed_organizations" (
	"user_id" uuid NOT NULL,
	"organization_id" integer NOT NULL,
	"is_primary" boolean DEFAULT false,
	"assigned_at" timestamp DEFAULT now()
);
--> statement-breakpoint
-- Safe rework: only attempt cast if column still text; normalize legacy values first
DO $$
DECLARE v_data_type text; BEGIN
	SELECT data_type INTO v_data_type FROM information_schema.columns
		WHERE table_schema='public' AND table_name='users' AND column_name='role';
	IF v_data_type = 'text' THEN
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
		ALTER TABLE public.users ALTER COLUMN role TYPE user_role USING (role::user_role);
	END IF;
END $$;--> statement-breakpoint
ALTER TABLE "users" ALTER COLUMN "role" SET DEFAULT 'cliente';--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "current_organization_id" integer;--> statement-breakpoint
ALTER TABLE "auth_tokens" ADD CONSTRAINT "auth_tokens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_managed_organizations" ADD CONSTRAINT "user_managed_organizations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_managed_organizations" ADD CONSTRAINT "user_managed_organizations_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;