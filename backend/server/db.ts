import pkg from 'pg';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
const { Pool } = pkg;
import { drizzle } from 'drizzle-orm/node-postgres';
import * as schema from '../schemas/schema';

if (!process.env.DATABASE_URL)
  throw new Error('DATABASE_URL não definida');

// Estratégia unificada via DB_SSL_MODE
// strict (default): usa CA se fornecida, rejectUnauthorized=true
// system: ignora CA, rejectUnauthorized=true
// system-allow-self-signed: ignora CA, rejectUnauthorized=false
// insecure-allow-self-signed: usa CA se houver, rejectUnauthorized=false
const dbSslMode = (process.env.DB_SSL_MODE || 'strict').toLowerCase();
// Detect if CA_CERT provided and perform normalization (supports single-line, quoted, or \n escaped)
const haveEnvCA = !!(process.env.CA_CERT && process.env.CA_CERT.trim());
const ignoreCA = dbSslMode.startsWith('system');
let ca: string | undefined;
let caSource: 'env' | 'file' | undefined;
let caCerts: string[] = [];
if (haveEnvCA && !ignoreCA) {
  let raw = process.env.CA_CERT!;
  // Remove surrounding quotes produced by some dashboard UIs
  raw = raw.trim().replace(/^"+|"+$/g, '');
  // Replace literal \n (two chars) with real newline, keep existing newlines
  raw = raw.replace(/\\n/g, '\n');
  raw = raw.replace(/\r/g, '');
  // If it's a single long line (or very few lines) with BEGIN/END and spaces, reflow into proper PEM format
  if (/BEGIN CERTIFICATE/.test(raw)) {
    // Extract all certificate bodies and rebuild
    const pemBlocks: string[] = [];
    const certRegex = /-----BEGIN CERTIFICATE-----([^-]+)-----END CERTIFICATE-----/g;
    let m: RegExpExecArray | null;
    while ((m = certRegex.exec(raw.replace(/\s+/g, ' ')))) {
      const body = m[1].replace(/\s+/g, '');
      // Split into 64 char lines per RFC
      const lines = body.match(/.{1,64}/g) || [];
      pemBlocks.push(['-----BEGIN CERTIFICATE-----', ...lines, '-----END CERTIFICATE-----'].join('\n'));
    }
    if (pemBlocks.length) raw = pemBlocks.join('\n');
  }
  ca = raw.trim();
  caSource = 'env';
  const blocks = ca.split(/(?=-----BEGIN CERTIFICATE-----)/g).map(b => b.trim()).filter(b => /BEGIN CERTIFICATE/.test(b));
  if (blocks.length > 0) caCerts = blocks; else if (ca) caCerts = [ca];
}
// Carregar CA local automática (apenas se não ignorada e não veio via env)
if (!ca && !ignoreCA) {
  const filePath = path.join(__dirname, 'ca-certificate.crt');
  try {
    if (fs.existsSync(filePath)) {
      const filePem = fs.readFileSync(filePath, 'utf8').trim();
      if (/-----BEGIN CERTIFICATE-----/.test(filePem)) {
        ca = filePem;
        caSource = 'file';
  const blocks = ca.split(/(?=-----BEGIN CERTIFICATE-----)/g).map(b => b.trim()).filter(b => b.includes('BEGIN CERTIFICATE'));
  if (blocks.length > 1) caCerts = blocks; else if (ca) caCerts = [ca];
      }
    }
  } catch (e) {
    console.warn('[server/db:ca-file:err]', (e as Error).message);
  }
}
const verify = !/allow-self-signed/.test(dbSslMode) && process.env.DB_SSL_VERIFY !== 'false';

let caFingerprint: string | undefined;
if (caCerts.length) {
  try {
    // Usar SEMPRE o último certificado (assumido root) para fingerprint primário
    const rootPem = caCerts[caCerts.length - 1];
    const b64 = rootPem.replace(/-----BEGIN CERTIFICATE-----/g, '').replace(/-----END CERTIFICATE-----/g, '').replace(/\s+/g, '');
    const der = Buffer.from(b64, 'base64');
    caFingerprint = crypto.createHash('sha256').update(der).digest('hex');
  } catch (e) {
    console.error('[server/db:fingerprint:error]', (e as Error).message);
  }
}

// Construção da connection string: só força sslmode=require quando vamos realmente verificar
const originalUrl = process.env.DATABASE_URL;
let urlObj: URL;
try { urlObj = new URL(originalUrl); } catch { throw new Error('DATABASE_URL inválida'); }
// Remover sslmode para evitar comportamento divergente do driver; confiaremos em ssl object
urlObj.searchParams.delete('sslmode');
// Fail fast se ainda estiver usando placeholder USER:PASS (variável exportada no shell sobrepõe .env)
if (/^user$/i.test(urlObj.username) || urlObj.username === 'USER') {
  console.error('[server/db:placeholder-user] DATABASE_URL ainda usa usuário placeholder "USER". Limpe variáveis do shell: Remove-Item Env:DATABASE_URL ; depois reinicie o processo.');
  console.error('[server/db:placeholder-user] Valor atual:', originalUrl.replace(/:(?:[^:@/]+)@/, ':***@'));
  process.exit(1);
}
const connectionString = urlObj.toString().replace(/\/$/, '');
const baseConnectionString = connectionString; // manter nome legado para reuso
const DB_LOG_VERBOSE = process.env.DB_LOG_VERBOSE === 'true';
if (DB_LOG_VERBOSE) {
  console.log('[server/db:init]', {
    connectionStringHasSslMode: /sslmode=/.test(connectionString),
    mode: dbSslMode,
    hasCA: !!ca,
    ignoredEnvCA: haveEnvCA && ignoreCA,
    caSource,
    caLength: ca?.length,
    caLines: ca ? ca.split(/\n/).length : undefined,
    caChain: caCerts.length,
    fingerprint: caFingerprint,
    verify,
    dbUser: urlObj.username,
    NODE_TLS_REJECT_UNAUTHORIZED: process.env.NODE_TLS_REJECT_UNAUTHORIZED,
    PGSSLMODE: process.env.PGSSLMODE,
  });
} else {
  console.log(`[server/db:init] mode=${dbSslMode} ca=${ca ? 'yes' : 'no'} verify=${verify} user=${urlObj.username}`);
}

const poolStartedAt = Date.now();
// Montar objeto SSL com servername explícito para garantir SNI correto
const parsedHost = (() => { try { return new URL(connectionString.replace(/\?sslmode=require/, '')).hostname; } catch { return undefined; } })();
// For TLS verification we pass the full chain (Node will pick root) but fingerprint we track last (assumed root)
const rootOnly = caCerts.length ? caCerts[caCerts.length - 1] : ca;
let currentSsl: any;
if (caCerts.length > 0) {
  currentSsl = { ca: caCerts, rejectUnauthorized: verify, servername: parsedHost };
} else if (rootOnly) {
  currentSsl = { ca: rootOnly, rejectUnauthorized: verify, servername: parsedHost };
} else {
  currentSsl = { rejectUnauthorized: verify, servername: parsedHost };
}
let pool = new Pool({ connectionString, ssl: currentSsl });
let db = drizzle(pool, { schema });
export { pool, db };

// --- Automatic migrations (optional) ---
// Controls:
//   DB_RUN_MIGRATIONS=on-start        -> run once at process start
//   DB_MIGRATIONS_STRICT=true         -> exit(1) if any migration fails
//   DB_MIGRATIONS_DIR (default: migrations)
// Notes: simple file execution order by name; only .sql files; ignores meta/.
async function runMigrationsIfRequested() {
  if (process.env.DB_RUN_MIGRATIONS !== 'on-start') return;
  const dir = process.env.DB_MIGRATIONS_DIR || path.join(process.cwd(), 'migrations');
  let files: string[] = [];
  try {
    files = fs.readdirSync(dir)
      .filter(f => f.endsWith('.sql') && !f.startsWith('meta') && !f.includes('snapshot'))
      .sort();
  } catch (e: any) {
    console.error('[db:migrations:list-error]', e.message);
    if (process.env.DB_MIGRATIONS_STRICT === 'true') process.exit(1);
    return;
  }
  console.log('[db:migrations:start]', { count: files.length, dir });
  for (const f of files) {
    const full = path.join(dir, f);
    let sql: string;
    try { sql = fs.readFileSync(full, 'utf8'); } catch (e:any) {
      console.error('[db:migrations:read-error]', { file: f, error: e.message });
      if (process.env.DB_MIGRATIONS_STRICT === 'true') process.exit(1); else continue;
    }
    // Split naive on ; but keep inside DO $$ ... $$ blocks: we just run raw file as is.
    try {
      const t0 = Date.now();
      await pool.query(sql);
      console.log('[db:migrations:applied]', { file: f, ms: Date.now() - t0 });
    } catch (e:any) {
      // If already applied (duplicate_object etc) just log as skipped
      const msg = e.message || '';
      if (/duplicate|already exists|exists/.test(msg)) {
        console.log('[db:migrations:skip]', { file: f, reason: 'already-applied' });
      } else {
        console.error('[db:migrations:error]', { file: f, error: msg });
        if (process.env.DB_MIGRATIONS_STRICT === 'true') process.exit(1); else continue;
      }
    }
  }
  console.log('[db:migrations:done]');
}

// Helper para recriar pool (fallback)
async function recreatePoolWithoutSSL() {
  try { await pool.end(); } catch {}
  currentSsl = undefined; // sem ssl
  pool = new Pool({ connectionString });
  db = drizzle(pool, { schema });
  console.warn('[server/db:fallback] Pool recriado SEM SSL (canal não verificado)');
}

async function recreatePoolRelaxedSSL() {
  try { await pool.end(); } catch {}
  currentSsl = ca ? { ca: caCerts.length ? caCerts : ca, rejectUnauthorized: false, servername: parsedHost } : { rejectUnauthorized: false, servername: parsedHost };
  // Usar baseConnectionString sem sslmode=require para evitar override interno
  pool = new Pool({ connectionString: baseConnectionString, ssl: currentSsl });
  db = drizzle(pool, { schema });
  console.warn('[server/db:relax] Pool recriado com rejectUnauthorized=false (auto-relax DEV)');
}

// --- Post init schema checks (drift detection) ---
let postInitDone = false;
async function postInitChecks() {
  if (postInitDone) return; postInitDone = true;
  try {
    if (process.env.DB_SKIP_SCHEMA_DRIFT_CHECK === 'true') {
      console.log('[db:schema-drift] Skipping schema drift checks (DB_SKIP_SCHEMA_DRIFT_CHECK=true)');
      return;
    }
    const missingCol = await pool.query("SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name='current_organization_id'");
    if (missingCol.rowCount === 0) {
      console.error('[db:schema-drift] Missing column users.current_organization_id');
      const autoPatch = process.env.DB_AUTO_PATCH_USERS_CURRENT_ORG === 'true' || (process.env.NODE_ENV !== 'production' && process.env.DB_AUTO_PATCH_USERS_CURRENT_ORG !== 'false');
      console.log('[db:schema-drift:autoPatch-eval]', { nodeEnv: process.env.NODE_ENV, flag: process.env.DB_AUTO_PATCH_USERS_CURRENT_ORG, autoPatch });
      if (autoPatch) {
        try {
          const alterResult = await pool.query('ALTER TABLE "public"."users" ADD COLUMN IF NOT EXISTS "current_organization_id" integer');
          console.log('[db:schema-drift:patched] Added users.current_organization_id', { command: alterResult.command });
          const verify = await pool.query("SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name='current_organization_id'");
          if (verify.rowCount === 0) {
            console.error('[db:schema-drift:verify-failed] Column still missing after ALTER TABLE');
            if (process.env.DB_SCHEMA_DRIFT_STRICT === 'true') {
              console.error('[db:schema-drift:fatal] Exiting because DB_SCHEMA_DRIFT_STRICT=true');
              process.exit(1);
            }
          }
        } catch (e:any) {
          console.error('[db:schema-drift:patch-error]', e.message);
          if (process.env.DB_SCHEMA_DRIFT_STRICT === 'true') {
            console.error('[db:schema-drift:fatal] Exiting because patch failed and DB_SCHEMA_DRIFT_STRICT=true');
            process.exit(1);
          }
        }
      } else {
        console.warn('[db:schema-drift] Set DB_AUTO_PATCH_USERS_CURRENT_ORG=true to auto-add column (non-destructive)');
      }
      // Always list current columns to aid debugging
      try {
        const cols = await pool.query("SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='users' ORDER BY 1");
        console.log('[db:schema-drift:columns]', cols.rows.map(r => r.column_name));
      } catch {}
    }
    else {
      // Optional: log success once
      console.log('[db:schema-drift] Column users.current_organization_id present');
    }
  } catch (e:any) {
    console.error('[db:schema-drift:check-error]', e.message);
  }
}

// Log extra de host/port para verificar alvo real
try {
  const u = new URL(connectionString.replace(/\?sslmode=require/, ''));
  const targetInfo = { host: u.hostname, port: u.port, database: u.pathname.replace('/', '') };
  if (DB_LOG_VERBOSE) console.log('[server/db:target]', targetInfo);
  const expectHost = process.env.DB_EXPECT_HOST?.trim();
  const expectPort = process.env.DB_EXPECT_PORT?.trim();
  if (expectHost && expectHost !== targetInfo.host) {
    console.error('[server/db:target:mismatch:host]', { expected: expectHost, got: targetInfo.host });
    process.exit(1);
  }
  if (expectPort && expectPort !== targetInfo.port) {
    console.error('[server/db:target:mismatch:port]', { expected: expectPort, got: targetInfo.port });
    process.exit(1);
  }
} catch {}

// Teste inicial + fallback condicional
// Pré-handshake em strict para evitar primeiro erro ruidoso
async function preflightStrictIfNeeded() {
  if (dbSslMode !== 'strict' || !ca) return;
  const { host, port } = (() => { const u = new URL(connectionString.replace(/\?sslmode=require/, '')); return { host: u.hostname, port: +(u.port || '5432') }; })();
  const tls = require('tls');
  return new Promise<void>((resolve) => {
    // Primeiro teste sem verificação para capturar cadeia
    const sock = tls.connect({ host, port, servername: host, ca: caCerts.length ? caCerts : ca, rejectUnauthorized: false }, () => {
      try {
        const chain: string[] = [];
        let cert: any = sock.getPeerCertificate(true);
        const seen = new Set<string>();
        while (cert && cert.raw) {
          const fp = crypto.createHash('sha256').update(cert.raw).digest('hex');
            if (seen.has(fp)) break;
            seen.add(fp);
            chain.push(fp);
            if (!cert.issuerCertificate || cert.issuerCertificate === cert) break;
            cert = cert.issuerCertificate;
        }
        if (DB_LOG_VERBOSE) {
          if (caFingerprint && chain.includes(caFingerprint)) {
            console.log('[server/db:preflight:strict-chain-ok]', { root: chain[chain.length - 1] });
          } else {
            console.warn('[server/db:preflight:strict-chain-warn]', { chain });
          }
        }
      } catch {}
      sock.end();
      sock.end();
      // Segundo teste com verificação real para capturar authorizationError antes do pg usar
      const sock2 = tls.connect({ host, port, servername: host, ca: caCerts.length ? caCerts : ca, rejectUnauthorized: true }, () => {
        if (DB_LOG_VERBOSE) console.log('[server/db:preflight:strict-auth]', { authorized: sock2.authorized, error: sock2.authorizationError });
        sock2.end();
        resolve();
      });
      sock2.on('error', (err: any) => {
        console.warn('[server/db:preflight:strict-auth-error]', err.message);
        resolve();
      });
    });
    sock.on('error', () => resolve());
  });
}

(async () => {
  await preflightStrictIfNeeded();
  await runMigrationsIfRequested();
  try {
    const t0 = Date.now();
    const r = await pool.query('select 1 as ok');
    console.log('[server/db:startup-query:ok]', { rowCount: r.rowCount, elapsedMs: Date.now() - t0, sincePoolMs: Date.now() - poolStartedAt });
  await postInitChecks();

    // Se estamos em strict e temos CA, validamos que fingerprint do root apresentado bate com nossa CA.
    if (dbSslMode === 'strict' && ca && caFingerprint) {
      try {
        // Abre conexão TLS independente para inspecionar cadeia (rejectUnauthorized:false somente para leitura da cadeia).
        const { host, port } = (() => { const u = new URL(connectionString.replace(/\?sslmode=require/, '')); return { host: u.hostname, port: +(u.port || '5432') }; })();
        await new Promise<void>((resolve, reject) => {
          const tls = require('tls');
            const sock = tls.connect({ host, port, servername: host, rejectUnauthorized: false }, () => {
              try {
                const peer = sock.getPeerCertificate(true);
                let current: any = peer;
                let rootFingerprint: string | undefined;
                const seen = new Set<string>();
                while (current && current.raw) {
                  const fp = crypto.createHash('sha256').update(current.raw).digest('hex');
                  if (seen.has(fp)) break;
                  seen.add(fp);
                  if (!current.issuerCertificate || current.issuerCertificate === current) {
                    rootFingerprint = fp;
                    break;
                  }
                  current = current.issuerCertificate;
                }
                if (rootFingerprint !== caFingerprint) {
                  console.error('[server/db:strict-root-mismatch]', { expected: caFingerprint, got: rootFingerprint });
                  process.exit(1);
                } else {
                  if (DB_LOG_VERBOSE) console.log('[server/db:strict-root-match]', { fingerprint: rootFingerprint });
                }
              } catch (err) {
                console.error('[server/db:strict-root-verify-error]', (err as Error).message);
              } finally {
                sock.end();
                resolve();
              }
            });
            sock.on('error', (err: any) => reject(err));
        });
      } catch (err) {
        console.error('[server/db:strict-verify-failed]', (err as Error).message);
      }
    }
  } catch (e) {
    const msg = (e as Error).message;
  const willAutoRelax = /self-signed certificate in certificate chain/i.test(msg) && process.env.DB_SSL_AUTO_RELAX === 'true' && verify;
    if (willAutoRelax) {
      console.warn('[server/db:startup-query:self-signed]', 'primeira tentativa falhou por self-signed; tentando relax em dev');
    } else {
      console.error('[server/db:startup-query:err]', msg);
    }
  const autoRelax = process.env.DB_SSL_AUTO_RELAX === 'true';
    if (/self-signed certificate in certificate chain/i.test(msg) && ca && dbSslMode === 'strict') {
  if (DB_LOG_VERBOSE) console.warn('[server/db:strict-debug] Falha self-signed mesmo com CA; tentando handshake manual para depuração');
      try {
        const { host, port } = (() => { const u = new URL(connectionString.replace(/\?sslmode=require/, '')); return { host: u.hostname, port: +(u.port || '5432') }; })();
        const tls = require('tls');
        let debugChain: string[] = [];
        await new Promise<void>((resolve) => {
          const sock = tls.connect({ host, port, servername: host, ca: caCerts.length ? caCerts : ca, rejectUnauthorized: false }, () => {
            try {
              const chain: string[] = [];
              let cert: any = sock.getPeerCertificate(true);
              const seen = new Set<string>();
              while (cert && cert.raw) {
                const fp = crypto.createHash('sha256').update(cert.raw).digest('hex');
                if (seen.has(fp)) break;
                seen.add(fp);
                chain.push(fp);
                if (!cert.issuerCertificate || cert.issuerCertificate === cert) break;
                cert = cert.issuerCertificate;
              }
              if (DB_LOG_VERBOSE) console.warn('[server/db:strict-debug:chain]', chain);
              debugChain = chain;
            } catch {}
            sock.end();
            resolve();
          });
          sock.on('error', () => resolve());
        });
          if (process.env.NODE_ENV !== 'development') {
            console.error('[server/db:strict-fail] Produção: falha de verificação SSL com CA fornecida. Abortando.');
            process.exit(1);
          } else if (caFingerprint && debugChain.includes(caFingerprint)) {
            console.warn('[server/db:strict-dev-relax] Dev: root fingerprint confere; relaxando verificação para continuar.');
            try { await pool.end(); } catch {}
            currentSsl = { ca: caCerts.length ? caCerts : ca, rejectUnauthorized: false, servername: host };
            pool = new Pool({ connectionString: connectionString.replace(/\?sslmode=require/, ''), ssl: currentSsl });
            db = drizzle(pool, { schema });
            try {
              const r3 = await pool.query('select 1 as ok');
              console.log('[server/db:strict-dev-relax:ok]', { rowCount: r3.rowCount });
              return;
            } catch (e3) {
              console.error('[server/db:strict-dev-relax:err]', (e3 as Error).message);
            }
          }
      } catch {}
    }
    if (/self-signed certificate in certificate chain/i.test(msg) && caSource === 'file' && dbSslMode === 'system' && verify) {
      console.warn('[server/db:retry-with-ca] Tentando novamente usando CA local encontrada');
      try {
        await pool.end();
      } catch {}
      currentSsl = { ca, rejectUnauthorized: true };
      pool = new Pool({ connectionString, ssl: currentSsl });
      db = drizzle(pool, { schema });
      try {
        const r2 = await pool.query('select 1 as ok');
        console.log('[server/db:retry-with-ca:ok]', { rowCount: r2.rowCount });
  await postInitChecks();
        return;
      } catch (e2) {
        console.error('[server/db:retry-with-ca:err]', (e2 as Error).message);
      }
    }
    if (/self-signed certificate in certificate chain/i.test(msg) && autoRelax && verify) {
      console.warn('[server/db:relax] Detectado self-signed chain; aplicando relax (rejectUnauthorized=false) para ambiente de desenvolvimento');
      await recreatePoolRelaxedSSL();
      try {
        const r2 = await pool.query('select 1 as ok');
        console.log('[server/db:relax:startup-query:ok]', { rowCount: r2.rowCount });
        // Não retornar (deixa seguir para manter processo vivo)
  await postInitChecks();
        return;
      } catch (e2) {
        console.error('[server/db:relax:startup-query:err]', (e2 as Error).message);
      }
    }
    if (/does not support SSL/i.test(msg) && process.env.DB_SSL_FALLBACK_ALLOW === 'true') {
      console.warn('[server/db:fallback] Servidor não suporta SSL; aplicando fallback não criptografado (apenas porque DB_SSL_FALLBACK_ALLOW=true)');
      await recreatePoolWithoutSSL();
      try {
        const r2 = await pool.query('select 1 as ok');
        console.log('[server/db:fallback:startup-query:ok]', { rowCount: r2.rowCount });
            await postInitChecks();
      } catch (e2) {
        console.error('[server/db:fallback:startup-query:err]', (e2 as Error).message);
      }
    } else if (/does not support SSL/i.test(msg)) {
      console.error('[server/db:suggestion] Se este for um Postgres local sem SSL, defina DB_SSL_FALLBACK_ALLOW=true para permitir fallback ou remova ?sslmode=require do DATABASE_URL temporariamente.');
    }
  }
})();