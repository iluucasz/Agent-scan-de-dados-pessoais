import crypto from 'crypto';
import { TelemetryService } from './telemetry.service';
import { db } from '../db';
import { authTokens } from '../../schemas/auth.schema';
import { and, eq, isNull, gt } from 'drizzle-orm';

export type TokenPurpose = 'MAGIC_LOGIN' | 'INVITE' | 'VERIFY_EMAIL' | 'LOGIN_OTP' | 'RESET_PASSWORD';

const base64url = (buf: Buffer) => buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const sha256b64 = (s: string) => crypto.createHash('sha256').update(s).digest('base64');

export class TokenService {
  private telemetry = new TelemetryService();
  generateRawToken(bytes = 32) {
    return base64url(crypto.randomBytes(bytes));
  }

  hashToken(raw: string) {
    return sha256b64(raw);
  }

  async issueToken(email: string, purpose: TokenPurpose, ttlSeconds: number, meta?: { userId?: string; ip?: string; userAgent?: string; }) {
    const raw = this.generateRawToken();
    const tokenHash = this.hashToken(raw);
    const expiresAt = new Date(Date.now() + ttlSeconds * 1000);
    await db.insert(authTokens).values({
      email,
      purpose,
      tokenHash,
      expiresAt,
      userId: meta?.userId,
      ip: meta?.ip,
      userAgent: meta?.userAgent,
    });
  this.telemetry.track('token.issued', { purpose, email });
    return { raw, expiresAt };
  }

  async consumeToken(raw: string, purpose: TokenPurpose) {
    const tokenHash = this.hashToken(raw);
    const now = new Date();
    const rows = await db.select().from(authTokens).where(and(
      eq(authTokens.tokenHash, tokenHash),
      eq(authTokens.purpose, purpose),
      isNull(authTokens.usedAt),
      gt(authTokens.expiresAt, now),
    ));
    const token = rows[0];
    if (!token) return null;
    await db.update(authTokens).set({ usedAt: now }).where(eq(authTokens.id, token.id));
  this.telemetry.track('token.consumed', { purpose, email: token.email });
    return token;
  }

  // OTP helpers (6-digit numeric). We still hash and store, similar to other tokens
  generateNumericCode(length = 6) {
    // Generates a zero-padded numeric code of given length
    const max = Math.pow(10, length);
    const n = crypto.randomInt(0, max);
    return n.toString().padStart(length, '0');
  }

  async issueOtp(email: string, ttlSeconds: number, meta?: { userId?: string; ip?: string; userAgent?: string; }) {
    const code = this.generateNumericCode(6);
    const tokenHash = this.hashToken(code);
    const expiresAt = new Date(Date.now() + ttlSeconds * 1000);
    await db.insert(authTokens).values({
      email,
      purpose: 'LOGIN_OTP',
      tokenHash,
      expiresAt,
      userId: meta?.userId,
      ip: meta?.ip,
      userAgent: meta?.userAgent,
    });
    this.telemetry.track('token.issued', { purpose: 'LOGIN_OTP', email });
    return { code, expiresAt };
  }

  async consumeOtp(code: string) {
    const tokenHash = this.hashToken(code);
    const now = new Date();
    const rows = await db.select().from(authTokens).where(and(
      eq(authTokens.tokenHash, tokenHash),
      eq(authTokens.purpose, 'LOGIN_OTP'),
      isNull(authTokens.usedAt),
      gt(authTokens.expiresAt, now),
    ));
    const token = rows[0];
    if (!token) return null;
    await db.update(authTokens).set({ usedAt: now }).where(eq(authTokens.id, token.id));
    this.telemetry.track('token.consumed', { purpose: 'LOGIN_OTP', email: token.email });
    return token;
  }

  async issueResetToken(email: string, ttlSeconds: number, meta?: { userId?: string; ip?: string; userAgent?: string; }) {
    const raw = this.generateRawToken(32);
    const tokenHash = this.hashToken(raw);
    const expiresAt = new Date(Date.now() + ttlSeconds * 1000);
    await db.insert(authTokens).values({
      email,
      purpose: 'RESET_PASSWORD',
      tokenHash,
      expiresAt,
      userId: meta?.userId,
      ip: meta?.ip,
      userAgent: meta?.userAgent,
    });
    this.telemetry.track('token.issued', { purpose: 'RESET_PASSWORD', email });
    return { raw, expiresAt };
  }

  async consumeResetToken(raw: string) {
    return this.consumeToken(raw, 'RESET_PASSWORD');
  }
}
