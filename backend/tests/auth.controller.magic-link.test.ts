import { AuthController } from '../server/controllers/auth.controller';
import { db } from '../server/db';

class FakeTokens {
  private store = new Map<string, { email: string; purpose: string }>();
  async issueToken(email: string, purpose: any, _ttl: number, _meta?: any) {
    const raw = `${purpose}-token-for-${email}`;
    this.store.set(raw, { email, purpose });
    return { raw };
  }
  async consumeToken(token: string, purpose: any) {
    const v = this.store.get(token);
    if (!v || v.purpose !== purpose) return null as any;
    this.store.delete(token);
    return { email: v.email } as any;
  }
}

class FakeMail {
  last: any;
  async sendMagicLink(email: string, token: string) { this.last = { type: 'magic', email, token }; }
  async sendInvite(email: string, token: string) { this.last = { type: 'invite', email, token }; }
  async sendVerifyEmail(email: string, token: string) { this.last = { type: 'verify', email, token }; }
}

function makeRes() {
  const res: any = { statusCode: 200, payload: undefined, redirected: undefined as undefined | { status: number; url: string } };
  res.status = function(code: number) { this.statusCode = code; return this; };
  res.json = function(payload: any) { this.payload = payload; return this; };
  res.redirect = function(status: number, url: string) { this.redirected = { status, url }; return this; };
  return res;
}

export async function testAuth_MagicLink_Flow() {
  const fakeTokens = new FakeTokens() as any;
  const fakeMail = new FakeMail() as any;
  const controller = new AuthController(fakeTokens, fakeMail);

  const savedEnv = process.env.APP_URL;
  process.env.APP_URL = 'http://app.local';

  // stub DB for user lookup/creation
  const original = { select: (db as any).select, insert: (db as any).insert };
  try {
    (db as any).select = () => ({
      from: () => ({
        where: async () => ([])
      })
    });
    (db as any).insert = () => ({
      values: () => ({ returning: async () => ([{ id: 'u1', email: 'foo@example.com', role: 'cliente', organizationId: 1 }]) })
    });

    // request magic link
    const req1: any = { body: { email: 'foo@example.com' }, ip: '1.1.1.1', headers: {} };
    const res1 = makeRes();
    await controller.requestMagicLink(req1 as any, res1 as any);
    if (res1.statusCode !== 200) throw new Error('requestMagicLink should return 200');

    // verify
    const req2: any = { query: { token: 'MAGIC_LOGIN-token-for-foo@example.com' } };
    const res2 = makeRes();
    await controller.verifyMagicLink(req2 as any, res2 as any);
    if (!res2.redirected || res2.redirected.status !== 302) throw new Error('verifyMagicLink should redirect 302');
    if (!String(res2.redirected.url).includes('/login/callback?token=')) throw new Error('callback token missing in redirect');
  } finally {
    (db as any).select = original.select;
    (db as any).insert = original.insert;
    process.env.APP_URL = savedEnv;
  }
}
