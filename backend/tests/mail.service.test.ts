import assert from 'node:assert';
import { MailService } from '../server/services/mail.service';

export async function testMailServiceFallback() {
  const svc = new MailService();
  // Ensure no API key for this test path
  process.env.MAILERSEND_API_KEY = '';
  const res = await svc.send({ to: 'nobody@local', subject: 't', html: '<b>t</b>' });
  assert.ok(res.ok, 'mail send should succeed via console fallback');
}
