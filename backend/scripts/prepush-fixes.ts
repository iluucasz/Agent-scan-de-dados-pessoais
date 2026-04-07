import 'dotenv/config';
import { Pool } from 'pg';

// In production or when explicitly skipped, exit successfully without doing anything.
// This script is intended only for local/dev data normalization.
if (
  process.env.SKIP_PREPUSH_FIXES === '1' ||
  process.env.SKIP_PREPUSH_FIXES === 'true' ||
  process.env.NODE_ENV === 'production'
) {
  console.log('[prepush-fixes] skipped (production or SKIP_PREPUSH_FIXES set)');
  process.exit(0);
}

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.log('[prepush-fixes] DATABASE_URL not set; skipping.');
    return;
  }
  const pool = new Pool({ connectionString: url });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Ensure enum exists
    await client.query(`DO $$ BEGIN
      CREATE TYPE "public"."user_role" AS ENUM('admin','gestor','cliente');
    EXCEPTION WHEN duplicate_object THEN NULL; END $$;`);

    // Check current column type
    const { rows } = await client.query(
      `SELECT data_type, udt_name FROM information_schema.columns
       WHERE table_schema='public' AND table_name='users' AND column_name='role'`
    );
    const row = rows[0];
    const isEnum = row && row.data_type === 'USER-DEFINED' && row.udt_name === 'user_role';
    if (!isEnum) {
      // Normalize legacy values
      await client.query(`UPDATE "public"."users" SET "role" = CASE lower("role")
        WHEN 'admin' THEN 'admin'
        WHEN 'super_admin' THEN 'admin'
        WHEN 'dpo' THEN 'gestor'
        WHEN 'agent' THEN 'gestor'
        WHEN 'client' THEN 'cliente'
        WHEN 'user' THEN 'cliente'
        ELSE 'cliente' END`);
      // Alter to enum using cast
      await client.query(`ALTER TABLE "public"."users"
        ALTER COLUMN "role" DROP DEFAULT`);
      await client.query(`ALTER TABLE "public"."users"
        ALTER COLUMN "role" TYPE "public"."user_role" USING ("role"::"public"."user_role")`);
      await client.query(`ALTER TABLE "public"."users"
        ALTER COLUMN "role" SET DEFAULT 'cliente'::"public"."user_role"`);
      console.log('[prepush-fixes] users.role converted to enum user_role');
    } else {
      console.log('[prepush-fixes] users.role already enum; nothing to do');
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[prepush-fixes] Error:', err);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch(() => process.exit(1));
