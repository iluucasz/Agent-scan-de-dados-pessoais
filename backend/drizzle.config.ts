/// <reference types="node" />
// @ts-nocheck
import 'dotenv/config';
import { defineConfig } from "drizzle-kit";
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

// ✅ CONFIGURAÇÃO SSL PARA PRODUÇÃO / Remoto DO (CA opcional se usar CA pública)
if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL precisa estar definida');
}
// Fail-fast se variável global sobrescreveu .env com credenciais placeholder
try {
  const testUrl = new URL(process.env.DATABASE_URL);
  if (/^user$/i.test(testUrl.username) || testUrl.username === 'USER') {
    console.error('[drizzle.config:placeholder-user] DATABASE_URL usa usuário placeholder "USER" e bloqueia operações drizzle. Remova variável de ambiente persistente e reabra o terminal.');
    throw new Error('DATABASE_URL placeholder USER bloqueado');
  }
} catch (e) {
  // Se URL inválida deixamos erro padrão seguir
}
// DB_SSL_MODE controla estratégia:
// strict (default): usa CA se fornecida, rejectUnauthorized=true
// system: ignora CA mesmo se existir, rejectUnauthorized=true
// system-allow-self-signed: ignora CA, rejectUnauthorized=false
// insecure-allow-self-signed: usa CA se houver mas rejectUnauthorized=false
const dbSslMode = (process.env.DB_SSL_MODE || 'strict').toLowerCase();

let ca: string | undefined;
let caFingerprint: string | undefined;
const haveEnvCA = !!(process.env.CA_CERT && process.env.CA_CERT.trim());
const ignoreCA = dbSslMode.startsWith('system');
if (haveEnvCA && !ignoreCA) {
  try {
    let rawCA = process.env.CA_CERT!;
    rawCA = rawCA.trim().replace(/^"+|"+$/g, '');
    rawCA = rawCA.replace(/\\n/g, '\n').replace(/\r/g, '');
    if (/BEGIN CERTIFICATE/.test(rawCA) && /\n/.test(rawCA) === false) {
      // Single-line with spaces; rebuild PEM blocks
      const rebuilt: string[] = [];
      const certRegex = /-----BEGIN CERTIFICATE-----([^-]+)-----END CERTIFICATE-----/g;
      let m: RegExpExecArray | null;
      while ((m = certRegex.exec(rawCA.replace(/\s+/g, ' ')))) {
        const body = m[1].replace(/\s+/g, '');
        const lines = body.match(/.{1,64}/g) || [];
        rebuilt.push(['-----BEGIN CERTIFICATE-----', ...lines, '-----END CERTIFICATE-----'].join('\n'));
      }
      if (rebuilt.length) rawCA = rebuilt.join('\n');
    }
    ca = rawCA.trim();
    const lastBlockMatch = ca.match(/-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g);
    const rootBlock = lastBlockMatch ? lastBlockMatch[lastBlockMatch.length - 1] : ca;
    const b64 = rootBlock
      .replace(/-----BEGIN CERTIFICATE-----/g, '')
      .replace(/-----END CERTIFICATE-----/g, '')
      .replace(/\s+/g, '');
    const der = Buffer.from(b64, 'base64');
    caFingerprint = crypto.createHash('sha256').update(der).digest('hex');
    try {
      const caFile = path.join(process.cwd(), '.drizzle-ca.pem');
      fs.writeFileSync(caFile, ca, { encoding: 'utf8' });
      process.env.PGSSLROOTCERT = caFile;
      process.env.NODE_EXTRA_CA_CERTS = caFile;
      if (!process.env.PGSSLMODE) process.env.PGSSLMODE = 'require';
      console.log('[drizzle.config:ca:file]', { caFile });
    } catch (w) {
      console.warn('[drizzle.config:ca:file:err]', (w as Error).message);
    }
  } catch (e) {
    console.error('[drizzle.config:fingerprint:error]', (e as Error).message);
  }
} else if (!haveEnvCA) {
  console.log('[drizzle.config] CA_CERT ausente: usando cadeias confiáveis padrão do sistema');
} else if (ignoreCA) {
  console.log('[drizzle.config] DB_SSL_MODE exige ignorar CA custom (usando trust store do sistema)');
}

let rejectUnauthorized = !/allow-self-signed/.test(dbSslMode);

// drizzle-kit apparently does not honor dbCredentials.ssl in some phases when introspecting; as a workaround
// we also set process.env.NODE_TLS_REJECT_UNAUTHORIZED conditionally for the CLI ONLY (not at runtime server).
if (process.env.DRIZZLE_ALLOW_SELF_SIGNED === 'true') {
  if (rejectUnauthorized) {
    console.warn('[drizzle.config] DRIZZLE_ALLOW_SELF_SIGNED=true -> forcing rejectUnauthorized=false for CLI');
  }
  rejectUnauthorized = false;
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
}

export default defineConfig({
  out: './migrations',
  schema: [
    './schemas/schema.ts',
    './schemas/users.schema.ts',
    './schemas/auth.schema.ts',
    './schemas/scan-data-module.schema.ts',
    './schemas/areas.schema.ts',
    './schemas/processos.schema.ts',
    './schemas/organization-membership.schema.ts',
  ],
  dialect: 'postgresql',
  dbCredentials: {
    // ✅ CONFIGURAÇÃO SSL PARA PRODUÇÃO
  url: `${process.env.DATABASE_URL}${/sslmode=/.test(process.env.DATABASE_URL) ? '' : '?sslmode=require'}`,
  // For drizzle-kit operations we pass explicit ssl so that pg uses our CA (or system) consistently.
  ssl: (() => {
    const base: any = { rejectUnauthorized };
    if (ca && !ignoreCA) base.ca = ca; // provide CA only when we are not ignoring it
    return base;
  })(),
  },
  // ✅ CONFIGURAÇÃO SSL PARA PRODUÇÃO - Hooks SSL habilitados
  hooks: {
    beforeConnect: (ctx) => {
      const startedAt = Date.now();
      if (ca) ctx.connection.ssl = { ca, rejectUnauthorized };
      else ctx.connection.ssl = { rejectUnauthorized };
      console.log('[drizzle.config:beforeConnect]', {
        mode: dbSslMode,
        rejectUnauthorized,
        hasCA: !!ca,
        ignoredEnvCA: haveEnvCA && ignoreCA,
        caLength: ca?.length,
        lines: ca ? ca.split(/\n/).length : undefined,
        fingerprint: caFingerprint,
        NODE_TLS_REJECT_UNAUTHORIZED: process.env.NODE_TLS_REJECT_UNAUTHORIZED,
        PGSSLMODE: process.env.PGSSLMODE,
      });
      // Marcar tempo de conexão (pg irá conectar depois que drizzle iniciar)
      setTimeout(() => {
        console.log('[drizzle.config:beforeConnect:post]', { elapsedMs: Date.now() - startedAt });
      }, 1000);
    },
  },
});