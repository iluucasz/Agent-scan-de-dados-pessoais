import { AuthController } from '../server/controllers/auth.controller';
import { db } from '../server/db';

class FakeTokens2 {
  private store = new Map<string, { email: string; purpose: string }>();
  async issueToken(email: string, purpose: any, _ttl: number, _meta?: any) { const raw = `${purpose}-token-for-${email}`; this.store.set(raw, { email, purpose }); return { raw }; }
  async consumeToken(token: string, purpose: any) { const v = this.store.get(token); if (!v || v.purpose !== purpose) return null as any; this.store.delete(token); return { email: v.email } as any; }
}

class FakeMail2 { async sendInvite() {}; async sendVerifyEmail() {} }

function makeRes() {
  const res: any = { statusCode: 200, payload: undefined, redirected: undefined as undefined | { status: number; url: string } };
  res.status = function(code: number) { this.statusCode = code; return this; };
  res.json = function(payload: any) { this.payload = payload; return this; };
  res.redirect = function(status: number, url: string) { this.redirected = { status, url }; return this; };
  return res;
}

export async function testAuth_InviteAndVerify_Flows() {
  const tokens = new FakeTokens2() as any;
  const mail = new FakeMail2() as any;
  const controller = new AuthController(tokens, mail);
  const savedEnv = process.env.APP_URL;
  process.env.APP_URL = 'http://app.local';

  const original = { select: (db as any).select, insert: (db as any).insert, update: (db as any).update };
  try {
    // DB stubs: no user → create, update for email verify
    (db as any).select = () => ({ from: () => ({ where: async () => ([] as any[]) }) });
    (db as any).insert = () => ({ values: () => ({ returning: async () => ([{ id: 'u1', email: 'bar@example.com', role: 'cliente', organizationId: 1 }]) }) });
    (db as any).update = () => ({ set: () => ({ where: async () => ([]) }) });

    // Invite accept
    const acceptReq: any = { query: { token: 'INVITE-token-for-bar@example.com' } };
    const acceptRes = makeRes();
    // pre-issue token then accept
    await tokens.issueToken('bar@example.com', 'INVITE', 600);
    await controller.acceptInvite(acceptReq as any, acceptRes as any);
    if (!acceptRes.redirected || acceptRes.redirected.status !== 302 || !String(acceptRes.redirected.url).includes('/invite/callback?token=')) {
      throw new Error('acceptInvite should redirect with JWT');
    }

    // Verify email
    await tokens.issueToken('baz@example.com', 'VERIFY_EMAIL', 600);
    const verifyReq: any = { query: { token: 'VERIFY_EMAIL-token-for-baz@example.com' } };
    const verifyRes = makeRes();
    // DB select returns a user for baz
    (db as any).select = () => ({ from: () => ({ where: async () => ([{ id: 'u2', email: 'baz@example.com' }]) }) });
    await controller.verifyEmail(verifyReq as any, verifyRes as any);
    if (!verifyRes.redirected || verifyRes.redirected.status !== 302 || !String(verifyRes.redirected.url).includes('/verify-email/success')) {
      throw new Error('verifyEmail should redirect to success');
    }
  } finally {
    (db as any).select = original.select;
    (db as any).insert = original.insert;
    (db as any).update = original.update;
    process.env.APP_URL = savedEnv;
  }
}
