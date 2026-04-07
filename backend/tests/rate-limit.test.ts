import assert from 'node:assert';
import { rateLimit } from '../server/middlewares/rate-limit';

function fakeReq(ip: string, email?: string): any {
  return {
    ip,
    body: email ? { email } : {},
    headers: {}
  };
}

function fakeRes() {
  const res: any = { statusCode: 200, headers: {}, body: null };
  res.status = (c: number) => { res.statusCode = c; return res; };
  res.json = (b: any) => { res.body = b; return res; };
  res.setHeader = (k: string, v: string) => { res.headers[k] = v; };
  return res;
}

export async function testRateLimit() {
  const rl = rateLimit({ windowSec: 1, max: 2 });
  const req1 = fakeReq('1.1.1.1', 'a@x');
  const req2 = fakeReq('1.1.1.1', 'a@x');
  const req3 = fakeReq('1.1.1.1', 'a@x');
  const res = fakeRes();
  let nextCount = 0; const next = () => { nextCount++; };
  rl(req1 as any, res as any, next);
  rl(req2 as any, res as any, next);
  rl(req3 as any, res as any, next);
  assert.strictEqual(nextCount, 2, 'only first two should pass');
  assert.strictEqual(res.statusCode, 429, 'third should be rate-limited');
}
