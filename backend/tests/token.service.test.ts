import 'dotenv/config';
import assert from 'node:assert';
import { TokenService } from '../server/services/token.service';

export async function testTokenService() {
  const svc = new TokenService();
  const email = `test+token_${Date.now()}@local`; 
  const { raw } = await svc.issueToken(email, 'MAGIC_LOGIN', 60, {});
  assert.ok(raw && raw.length > 10, 'raw token should be generated');
  const t1 = await svc.consumeToken(raw, 'MAGIC_LOGIN');
  assert.ok(t1 && t1.email === email, 'token should be consumable once');
  const t2 = await svc.consumeToken(raw, 'MAGIC_LOGIN');
  assert.strictEqual(t2, null, 'token reuse should fail');
}
