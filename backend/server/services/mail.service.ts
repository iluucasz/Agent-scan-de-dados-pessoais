import 'dotenv/config';
// Usamos fetch nativo (Node 18+) ou carregamos dinamicamente 'node-fetch' se necessário.
type RequestInitLike = any;
import { TelemetryService } from './telemetry.service';

type SendOptions = {
  to: string;
  subject: string;
  html: string;
};

export class MailService {
  private apiKey = process.env.MAILERSEND_API_KEY;
  private from = process.env.MAIL_FROM || 'no-reply@seusdados.com';
  private telemetry = new TelemetryService();

  private async sendViaMailerSend(opts: SendOptions) {
    // Minimal MailerSend API call (https://developers.mailersend.com/api/v1/email.html)
    const body = {
      from: { email: this.from },
      to: [{ email: opts.to }],
      subject: opts.subject,
      html: opts.html,
    };
  const init: RequestInitLike = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiKey}`
      },
      body: JSON.stringify(body)
    } as any;
    let fetchFn: any = (global as any).fetch;
    if (!fetchFn) {
      try {
        fetchFn = (await import('node-fetch')).default;
      } catch {
        throw new Error('fetch indisponível e node-fetch não instalado');
      }
    }
    const resp = await fetchFn('https://api.mailersend.com/v1/email', init);
    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`MailerSend error ${resp.status}: ${text}`);
    }
    // Some providers return 202 with empty body; parse JSON only when present
    let data: any = null;
    try {
      const ct = resp.headers.get('content-type') || '';
      if (ct.includes('application/json')) {
        data = await resp.json();
      } else {
        const t = await resp.text();
        if (t && t.trim().length > 0) {
          try { data = JSON.parse(t); } catch { /* ignore non-JSON */ }
        }
      }
    } catch { /* ignore parse errors; treat as success */ }
  const idHeader = resp.headers.get('x-message-id');
  const msgId = data?.message_id ?? idHeader ?? 'mailerSend';
  this.telemetry.track('mail.sent', { provider: 'mailersend', to: opts.to, id: msgId });
  return { id: msgId, ok: true };
  }

  async send(opts: SendOptions) {
    if (!this.apiKey) {
  console.log(`[mail:console] to=${opts.to} subject="${opts.subject}" html=${opts.html.slice(0, 200)}...`);
  this.telemetry.track('mail.sent', { provider: 'console', to: opts.to });
      return { id: 'console-mail', ok: true };
    }
    try {
  return await this.sendViaMailerSend(opts);
    } catch (err) {
      console.error('[mail] MailerSend send failed; falling back to console:', err);
  this.telemetry.track('mail.error', { provider: 'mailersend', error: (err as Error).message });
      console.log(`[mail:fallback] to=${opts.to} subject="${opts.subject}" html=${opts.html.slice(0, 200)}...`);
  this.telemetry.track('mail.sent', { provider: 'fallback-console', to: opts.to });
      return { id: 'fallback-mail', ok: true };
    }
  }

  async sendMagicLink(to: string, token: string) {
    const verifyUrl = `${process.env.API_URL || 'http://localhost:3001'}/api/auth/magic-link/verify?token=${encodeURIComponent(token)}`;
    const subject = 'Seu acesso por link mágico';
    const html = `
      <p>Use o botão abaixo para acessar sua conta. O link expira em poucos minutos.</p>
      <p><a href="${verifyUrl}" style="padding:10px 16px;background:#0ea5e9;color:#fff;text-decoration:none;border-radius:6px">Acessar agora</a></p>
      <p>Se o botão não funcionar, copie e cole esta URL no navegador:<br/>${verifyUrl}</p>
    `;
    if (process.env.NODE_ENV === 'development') {
      console.log(`[dev] Magic link URL: ${verifyUrl}`);
    }
    return this.send({ to, subject, html });
  }

  async sendInvite(to: string, token: string) {
    const acceptUrl = `${process.env.API_URL || 'http://localhost:3001'}/api/auth/invite/accept?token=${encodeURIComponent(token)}`;
    const subject = 'Convite para acessar a plataforma';
    const html = `
      <p>Você foi convidado a acessar a plataforma. Clique no botão abaixo para aceitar o convite.</p>
      <p><a href="${acceptUrl}" style="padding:10px 16px;background:#16a34a;color:#fff;text-decoration:none;border-radius:6px">Aceitar convite</a></p>
      <p>Ou use esta URL:<br/>${acceptUrl}</p>
    `;
    if (process.env.NODE_ENV === 'development') {
      console.log(`[dev] Invite URL: ${acceptUrl}`);
    }
    return this.send({ to, subject, html });
  }

  async sendVerifyEmail(to: string, token: string) {
    const verifyUrl = `${process.env.API_URL || 'http://localhost:3001'}/api/auth/verify-email?token=${encodeURIComponent(token)}`;
    const subject = 'Verifique seu e-mail';
    const html = `
      <p>Confirme seu endereço de e-mail clicando no botão abaixo.</p>
      <p><a href="${verifyUrl}" style="padding:10px 16px;background:#0ea5e9;color:#fff;text-decoration:none;border-radius:6px">Verificar e-mail</a></p>
      <p>Ou use esta URL:<br/>${verifyUrl}</p>
    `;
    if (process.env.NODE_ENV === 'development') {
      console.log(`[dev] Verify email URL: ${verifyUrl}`);
    }
    return this.send({ to, subject, html });
  }

  async sendLoginOtp(to: string, code: string) {
    const subject = 'Seu código de verificação (Login)';
    const html = `
      <p>Use o código abaixo para concluir seu login. Ele expira em poucos minutos.</p>
      <p style="font-size: 24px; font-weight: bold; letter-spacing: 4px;">${code}</p>
      <p>Se você não solicitou este código, ignore este e-mail.</p>
    `;
    if (process.env.NODE_ENV === 'development') {
      console.log(`[dev] Login OTP code for ${to}: ${code}`);
    }
    return this.send({ to, subject, html });
  }

  async sendResetPassword(to: string, rawToken: string, opts?: { redirectBase?: string }) {
    const base = (opts?.redirectBase && typeof opts.redirectBase === 'string' && opts.redirectBase) || process.env.APP_PUBLIC_URL || process.env.APP_URL || 'http://localhost:5173';
    const normalized = base.replace(/\/$/, '');
    const resetUrl = `${normalized}/reset-password?token=${encodeURIComponent(rawToken)}`;
    const subject = 'Redefinição de senha';
    const html = `
      <p>Recebemos uma solicitação para redefinir sua senha. Clique no botão abaixo para continuar.</p>
      <p><a href="${resetUrl}" style="padding:10px 16px;background:#0ea5e9;color:#fff;text-decoration:none;border-radius:6px">Redefinir senha</a></p>
      <p>Se você não solicitou, ignore este e-mail.</p>
      <p>Link direto: ${resetUrl}</p>
    `;
    const wantLog = process.env.MAIL_LOG_LINKS === 'true' || process.env.MAIL_DEBUG === 'true' || process.env.NODE_ENV === 'development';
    if (wantLog) {
      console.log(`[mail:reset-link] to=${to} url=${resetUrl}`);
    }
    return this.send({ to, subject, html });
  }

  async sendWelcomeWithResetToken(to: string, name: string, resetToken: string) {
    const baseUrl = (process.env.APP_PUBLIC_URL || process.env.APP_URL || 'http://localhost:5173').replace(/\/$/, '');
    const resetPasswordUrl = `${baseUrl}/reset-password?token=${encodeURIComponent(resetToken)}`;
    const subject = 'Bem-vindo ao Privacy Pulse - Defina sua Senha';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #1f2937;">Olá, ${name}!</h2>
        <p style="color: #4b5563; line-height: 1.6;">Sua conta foi criada com sucesso no Privacy Pulse.</p>
        
        <div style="background-color: #f3f4f6; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #0ea5e9;">
          <h3 style="margin-top: 0; color: #1f2937;">🔐 Acesso à Plataforma</h3>
          <p style="margin: 8px 0;"><strong>Email de acesso:</strong> ${to}</p>
          <p style="margin: 8px 0; color: #6b7280; font-size: 14px;">
            Para sua segurança, você precisa definir sua própria senha antes de acessar a plataforma.
          </p>
        </div>
        
        <p style="text-align: center; margin: 30px 0;">
          <a href="${resetPasswordUrl}" 
             style="display: inline-block; padding: 14px 28px; background-color: #0ea5e9; color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px;">
            Definir Minha Senha
          </a>
        </p>
        
        <p style="color: #6b7280; font-size: 14px; line-height: 1.6; text-align: center;">
          Clique no botão acima para criar sua senha de acesso.<br>
          Este link é válido por 30 minutos.
        </p>
        
        <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 30px 0;">
        
        <p style="color: #9ca3af; font-size: 12px; text-align: center;">
          Se você não solicitou esta conta, entre em contato com o administrador do sistema.<br>
          Link direto: <a href="${resetPasswordUrl}" style="color: #0ea5e9;">${resetPasswordUrl}</a>
        </p>
      </div>
    `;
    
    if (process.env.NODE_ENV === 'development') {
      console.log(`[dev] 📧 Welcome email sent to: ${to}`);
      console.log(`[dev] � Reset password URL: ${resetPasswordUrl}`);
      console.log(`[dev] � Reset token: ${resetToken}`);
    }
    
    return this.send({ to, subject, html });
  }

  async sendAgentToken(to: string, name: string, token: string) {
    const subject = 'Bem-vindo ao Privacy Pulse - Seu Token de Acesso';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #1f2937;">Olá, ${name}!</h2>
        <p style="color: #4b5563; line-height: 1.6;">Sua conta foi criada com sucesso no Privacy Pulse.</p>
        
        <div style="background-color: #f3f4f6; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #0ea5e9;">
          <h3 style="margin-top: 0; color: #1f2937;">🔐 Acesso à Plataforma</h3>
          <p style="margin: 8px 0;"><strong>Token de Acesso:</strong></p>
          <p style="margin: 8px 0; font-family: 'SFMono-Regular', Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace; background:#e5e7eb; padding: 10px; border-radius: 6px; word-break: break-all;">${token}</p>
        </div>
        
        <p style="color: #6b7280; font-size: 14px; line-height: 1.6;">
          Use este token para autenticar seu bot/agente na API.
        </p>
      </div>
    `;

    if (process.env.NODE_ENV === 'development') {
      console.log(`[dev] 📧 Agent token email sent to: ${to}`);
      console.log(`[dev] 🔑 Agent token: ${token}`);
    }

    return this.send({ to, subject, html });
  }

  async sendAgentOtp(to: string, code: string) {
    const subject = 'Código de Segurança - Agent Login';
    const html = `
      <p>Use o código abaixo para concluir seu login. Ele expira em poucos minutos.</p>
      <p style="font-size: 24px; font-weight: bold; letter-spacing: 4px;">${code}</p>
      <p>Se você não solicitou este código, ignore este e-mail.</p>
    `;
    if (process.env.NODE_ENV === 'development') {
      console.log(`[dev] Agent OTP code for ${to}: ${code}`);
    }
    return this.send({ to, subject, html });
  }
}
