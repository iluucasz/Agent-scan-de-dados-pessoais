-- Add 'agent' value to user_role enum if not exists
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_enum e ON t.oid = e.enumtypid
    WHERE t.typname = 'user_role' AND e.enumlabel = 'agent'
  ) THEN
    ALTER TYPE "public"."user_role" ADD VALUE 'agent';
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create agent_tokens table
CREATE TABLE IF NOT EXISTS "public"."agent_tokens" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES "public"."users"(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  is_active BOOLEAN DEFAULT true,
  last_used_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  reset_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_agent_tokens_user_id ON "public"."agent_tokens"(user_id);
CREATE INDEX IF NOT EXISTS idx_agent_tokens_token_hash ON "public"."agent_tokens"(token_hash);
