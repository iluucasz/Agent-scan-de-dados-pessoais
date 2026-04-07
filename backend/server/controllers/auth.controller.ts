import { Request, Response } from 'express';
import { TokenService } from '../services/token.service';
import { MailService } from '../services/mail.service';
import { AgentService } from '../services/agent.service';
import { db } from '../db';
import { users as usersTable } from '../../schemas/users.schema';
import { eq } from 'drizzle-orm';
import { signToken } from '../utils/jwt';
import { comparePasswords } from '../utils';
import { hashPassword } from '../utils';

export class AuthController {
  constructor(
    private tokens = new TokenService(),
    private mail = new MailService(),
    private agents = new AgentService(),
  ) {}

  // 1) Email+Senha -> cria desafio OTP (LOGIN_OTP) e retorna challenge_id (aqui usaremos o próprio email como correlator)
  loginStart = async (req: Request, res: Response) => {
    const { email, password } = req.body || {};
    if (!email || typeof email !== 'string' || !password || typeof password !== 'string') {
      return res.status(400).json({ message: 'Credenciais inválidas' });
    }
    const [user] = await db.select().from(usersTable).where(eq(usersTable.email, email.toLowerCase()));
    if (!user || !user.isActive) {
      return res.status(401).json({ message: 'Email ou senha inválidos' });
    }
    const ok = await comparePasswords(password, user.password);
    if (!ok) {
      return res.status(401).json({ message: 'Email ou senha inválidos' });
    }
    const ttl = Number(process.env.LOGIN_OTP_TTL || 600);
    const meta = { userId: user.id, ip: req.ip, userAgent: req.headers['user-agent'] as string|undefined };
    const { code } = await this.tokens.issueOtp(user.email.toLowerCase(), ttl, meta);
    await this.mail.sendLoginOtp(user.email, code);
    // We can return a signed "challenge_id" if needed; for now, the email itself is anchor through OTP table
    return res.status(200).json({ challenge_id: 'otp', next: 'verify' });
  };

  // 2) Verifica OTP -> retorna access_token + user e (opcional) refresh cookie
  loginVerify = async (req: Request, res: Response) => {
    const { email, code } = req.body || {};
    if (!email || typeof email !== 'string' || !code || typeof code !== 'string') {
      return res.status(400).json({ message: 'Dados inválidos' });
    }
    const token = await this.tokens.consumeOtp(code);
    if (!token) {
      return res.status(400).json({ message: 'Código inválido ou expirado' });
    }
    if (token.email.toLowerCase() !== email.toLowerCase()) {
      return res.status(400).json({ message: 'Código inválido ou expirado' });
    }
    const [user] = await db.select().from(usersTable).where(eq(usersTable.email, email.toLowerCase()));
    if (!user || !user.isActive) {
      return res.status(400).json({ message: 'Conta indisponível' });
    }
    
    // ✅ Detectar primeiro login (se lastLogin é null, é primeiro acesso)
    const isFirstLogin = !user.lastLogin;
    
    const orgId = typeof user.organizationId === 'number' ? user.organizationId : 1;
    const accessToken = signToken({ id: user.id, role: user.role, organizationId: orgId });
    
    // Se currentOrganizationId é null, inicializar com organizationId
    let currentOrgId = user.currentOrganizationId;
    if (!currentOrgId) {
      currentOrgId = orgId;
    }
    
    // Optional: set refresh cookie (placeholder simple random; implement proper refresh store/rotation if needed)
    const refreshEnabled = String(process.env.REFRESH_COOKIE || 'false').toLowerCase() === 'true';
    if (refreshEnabled) {
      const opaque = Math.random().toString(36).slice(2);
      res.cookie('refresh_token', opaque, {
        httpOnly: true,
        secure: String(process.env.COOKIE_SECURE || 'false').toLowerCase() === 'true',
        sameSite: 'strict',
        path: '/api/auth',
        maxAge: 1000 * 60 * 60 * 24 * 30,
      } as any);
    }
    
    // persist accessToken, lastLogin e currentOrganizationId (se necessário)
    const [updated] = await db.update(usersTable)
      .set({ 
        accessToken, 
        lastLogin: new Date(),
        currentOrganizationId: currentOrgId
      })
      .where(eq(usersTable.id, user.id))
      .returning();
    
    const { password: _pwd, ...userWithoutPassword } = updated as any;
    
    // Incluir orgScope na resposta para o frontend
    const orgScope = {
      currentOrganizationId: currentOrgId,
      allowedOrgIds: user.role === 'admin' ? null : [currentOrgId]
    };
    
    return res.status(200).json({
      user: userWithoutPassword,
      orgScope,
      isFirstLogin  // ✅ Flag para frontend saber se é primeiro acesso
    });
  };

  requestMagicLink = async (req: Request, res: Response) => {
    const { email } = req.body || {};
    if (!email || typeof email !== 'string') return res.status(400).json({ message: 'Email inválido' });
    // Optional: enforce that the user exists (and optionally is verified) before issuing a magic link
    const requireExisting = String(
      process.env.MAGIC_LINK_REQUIRE_EXISTING ?? (process.env.NODE_ENV === 'test' ? 'false' : 'true')
    ).toLowerCase() === 'true';
  const requireVerified = String(process.env.MAGIC_LINK_REQUIRE_VERIFIED || 'false').toLowerCase() === 'true';
  if (requireExisting) {
      const [existing] = await db.select().from(usersTable).where(eq(usersTable.email, email.toLowerCase()));
      if (!existing) {
    return res.status(404).json({ message: 'E-mail não encontrado. Verifique o endereço digitado ou entre em contato com a administração.' });
      }
      if (requireVerified && !existing.emailVerifiedAt) {
    return res.status(400).json({ message: 'E-mail não verificado. Verifique sua caixa de entrada ou solicite um novo link.' });
      }
    }
    const ttl = Number(process.env.MAGIC_LINK_TTL || 900);
    const meta = { ip: req.ip, userAgent: req.headers['user-agent'] as string|undefined };
    const { raw } = await this.tokens.issueToken(email.toLowerCase(), 'MAGIC_LOGIN', ttl, meta);
    await this.mail.sendMagicLink(email, raw);
  return res.status(200).json({ message: 'Enviaremos um link para acessar a plataforma.' });
  };

  verifyMagicLink = async (req: Request, res: Response) => {
    const token = (req.query.token as string) || (req.body && req.body.token);
    if (!token || typeof token !== 'string') return res.status(400).json({ message: 'Token ausente' });
    const consumed = await this.tokens.consumeToken(token, 'MAGIC_LOGIN');
    if (!consumed) return res.status(400).json({ message: 'Token inválido ou expirado' });

    const email = consumed.email;
    let [user] = await db.select().from(usersTable).where(eq(usersTable.email, email));
    const requireExisting = String(
      process.env.MAGIC_LINK_REQUIRE_EXISTING ?? (process.env.NODE_ENV === 'test' ? 'false' : 'true')
    ).toLowerCase() === 'true';
    if (!user) {
      if (requireExisting) {
        return res.status(404).json({ message: 'E-mail não encontrado. Solicite acesso à administração.' });
      }
      // auto-provision opcional (somente quando não exigir existente)
      const defaults = {
        organizationId: Number(process.env.DEFAULT_ORGANIZATION_ID) || 1,
        role: (process.env.DEFAULT_USER_ROLE as any) || 'cliente',
        name: email.split('@')[0],
        email,
        password: 'placeholder',
        isActive: true,
      } as any;
      const inserted = await db.insert(usersTable).values(defaults).returning();
      user = inserted[0];
    }

  const orgId = typeof user.organizationId === 'number' ? user.organizationId : 1;
  const jwt = signToken({ id: user.id, role: user.role, organizationId: orgId });
  const appUrl = process.env.APP_URL || 'http://localhost:5173';
  const redirect = `${appUrl}/login/callback?token=${encodeURIComponent(jwt)}`;
  return res.redirect(302, redirect);
  };

  inviteUser = async (req: Request, res: Response) => {
    const { email, organizationId, role } = req.body || {};
    if (!email || typeof email !== 'string') return res.status(400).json({ message: 'Email inválido' });
    const ttl = Number(process.env.INVITE_TTL || 60 * 60 * 24 * 7);
    const meta = { userId: req.user?.id, ip: req.ip, userAgent: req.headers['user-agent'] as string|undefined };
    const { raw } = await this.tokens.issueToken(email.toLowerCase(), 'INVITE', ttl, meta);
    // For now include org/role hints in token consumption step only (no PII in link)
    await this.mail.sendInvite(email, raw);
    return res.status(200).json({ message: 'Se existir, um convite foi enviado.' });
  };

  acceptInvite = async (req: Request, res: Response) => {
    const token = (req.query.token as string) || (req.body && req.body.token);
    if (!token || typeof token !== 'string') return res.status(400).json({ message: 'Token ausente' });
    const consumed = await this.tokens.consumeToken(token, 'INVITE');
    if (!consumed) return res.status(400).json({ message: 'Token inválido ou expirado' });
    const email = consumed.email;
    // Ensure user exists, minimal record; do not require password
    let [user] = await db.select().from(usersTable).where(eq(usersTable.email, email));
    if (!user) {
      const defaults: any = {
        organizationId: Number(process.env.DEFAULT_ORGANIZATION_ID) || 1,
        role: (process.env.DEFAULT_USER_ROLE as any) || 'cliente',
        name: email.split('@')[0],
        email,
        password: 'placeholder',
        isActive: true,
      };
      const inserted = await db.insert(usersTable).values(defaults).returning();
      user = inserted[0];
    }
  const orgId = typeof user.organizationId === 'number' ? user.organizationId : 1;
  const jwt = signToken({ id: user.id, role: user.role, organizationId: orgId });
  const appUrl = process.env.APP_URL || 'http://localhost:5173';
  return res.redirect(302, `${appUrl}/invite/callback?token=${encodeURIComponent(jwt)}`);
  };

  requestVerifyEmail = async (req: Request, res: Response) => {
    let email: string | undefined;
    if (req.user?.id) {
      const rows = await db.select().from(usersTable).where(eq(usersTable.id, req.user!.id));
      email = rows[0]?.email as string | undefined;
    } else if (req.body && typeof req.body.email === 'string') {
      email = req.body.email;
    }
    if (!email || typeof email !== 'string') return res.status(400).json({ message: 'Email inválido' });
    const ttl = Number(process.env.VERIFY_EMAIL_TTL || 60 * 60 * 24);
    const meta = { userId: req.user?.id, ip: req.ip, userAgent: req.headers['user-agent'] as string|undefined };
    const { raw } = await this.tokens.issueToken(email.toLowerCase(), 'VERIFY_EMAIL', ttl, meta);
    await this.mail.sendVerifyEmail(email, raw);
    return res.status(200).json({ message: 'Se existir, enviamos um link de verificação.' });
  };

  verifyEmail = async (req: Request, res: Response) => {
    const token = (req.query.token as string) || (req.body && req.body.token);
    if (!token || typeof token !== 'string') return res.status(400).json({ message: 'Token ausente' });
    const consumed = await this.tokens.consumeToken(token, 'VERIFY_EMAIL');
    if (!consumed) return res.status(400).json({ message: 'Token inválido ou expirado' });
    const email = consumed.email;
    const [user] = await db.select().from(usersTable).where(eq(usersTable.email, email));
    if (user) {
      await db.update(usersTable).set({ emailVerifiedAt: new Date() }).where(eq(usersTable.id, user.id));
    }
  const appUrl = process.env.APP_URL || 'http://localhost:5173';
  return res.redirect(302, `${appUrl}/verify-email/success`);
  };

  // Solicitar redefinição de senha (apenas e-mail). Resposta neutra.
  requestPasswordReset = async (req: Request, res: Response) => {
    const { email, redirectBase } = req.body || {};
    if (!email || typeof email !== 'string') return res.status(400).json({ message: 'Email inválido' });
    // Sanitizar redirectBase opcional (não vazar host arbitrário). Aceita somente http/https e sem fragmentos.
    let sanitizedRedirect: string | undefined;
    if (redirectBase && typeof redirectBase === 'string') {
      try {
        const u = new URL(redirectBase);
        // Em produção exigir https, em dev aceitar http
        const isProd = process.env.NODE_ENV === 'production';
        if ((!isProd || u.protocol === 'https:') && (u.protocol === 'https:' || u.protocol === 'http:')) {
          // Normalizar sem trailing slash
            sanitizedRedirect = u.origin + (u.pathname.replace(/\/$/, ''));
        }
      } catch { /* ignore invalid redirectBase */ }
    }
    const [user] = await db.select().from(usersTable).where(eq(usersTable.email, email.toLowerCase()));
    if (user) {
      const ttl = Number(process.env.RESET_PASSWORD_TTL || 60 * 30);
      const meta = { userId: user.id, ip: req.ip, userAgent: req.headers['user-agent'] as string|undefined };
      const { raw } = await this.tokens.issueResetToken(user.email.toLowerCase(), ttl, meta);
      await this.mail.sendResetPassword(user.email, raw, { redirectBase: sanitizedRedirect });
    }
    return res.status(200).json({ message: 'Se existir, enviaremos instruções para redefinição de senha.' });
  };

  // Confirmar redefinição (token + nova senha)
  confirmPasswordReset = async (req: Request, res: Response) => {
    const { token, password } = req.body || {};
    if (!token || typeof token !== 'string' || !password || typeof password !== 'string' || password.length < 6) {
      return res.status(400).json({ message: 'Dados inválidos' });
    }
    const consumed = await this.tokens.consumeResetToken(token);
    if (!consumed) return res.status(400).json({ message: 'Token inválido ou expirado' });
    const [user] = await db.select().from(usersTable).where(eq(usersTable.email, consumed.email));
    if (!user) return res.status(400).json({ message: 'Conta não encontrada' });
    const hashed = await hashPassword(password);
    const [updated] = await db.update(usersTable).set({ password: hashed }).where(eq(usersTable.id, user.id)).returning();
    const { password: _p, ...userWithoutPassword } = updated as any;
    return res.status(200).json({ message: 'Senha alterada com sucesso', user: userWithoutPassword });
  };

  // Fluxo de autenticação específico para Agents
  // 1) Recebe o token permanente do Agent, valida e dispara OTP por e-mail
  agentVerifyToken = async (req: Request, res: Response) => {
    const { token } = req.body || {};
    if (!token || typeof token !== 'string') {
      return res.status(400).json({ message: 'Token inválido' });
    }

    const validated = await this.agents.validateAgentToken(token);
    if (!validated) {
      return res.status(401).json({ message: 'Token de agent inválido' });
    }

    const [user] = await db.select().from(usersTable).where(eq(usersTable.id, validated.userId));
    if (!user || !user.isActive || user.role !== 'agent') {
      return res.status(400).json({ message: 'Agent indisponível' });
    }

    const ttl = Number(process.env.LOGIN_OTP_TTL || 600);
    const meta = { userId: user.id, ip: req.ip, userAgent: req.headers['user-agent'] as string | undefined };
    const { code } = await this.tokens.issueOtp(user.email.toLowerCase(), ttl, meta);
    await this.mail.sendAgentOtp(user.email, code);

    await this.agents.markTokenUsed(token);

    return res.status(200).json({ challenge_id: 'agent_otp', next: 'verify', email: user.email });
  };

  // 2) Recebe o email + código OTP e retorna o mesmo payload de loginVerify
  agentVerifyOtp = async (req: Request, res: Response) => {
    const { email, code } = req.body || {};
    if (!email || typeof email !== 'string' || !code || typeof code !== 'string') {
      return res.status(400).json({ message: 'Dados inválidos' });
    }

    const token = await this.tokens.consumeOtp(code);
    if (!token) {
      return res.status(400).json({ message: 'Código inválido ou expirado' });
    }
    if (token.email.toLowerCase() !== email.toLowerCase()) {
      return res.status(400).json({ message: 'Código inválido ou expirado' });
    }

    const [user] = await db.select().from(usersTable).where(eq(usersTable.email, email.toLowerCase()));
    if (!user || !user.isActive || user.role !== 'agent') {
      return res.status(400).json({ message: 'Agent indisponível' });
    }

    const orgId = typeof user.organizationId === 'number' ? user.organizationId : 1;
    const accessToken = signToken({ id: user.id, role: user.role, organizationId: orgId });

    let currentOrgId = user.currentOrganizationId;
    if (!currentOrgId) {
      currentOrgId = orgId;
    }

    const [updated] = await db
      .update(usersTable)
      .set({ accessToken, lastLogin: new Date(), currentOrganizationId: currentOrgId })
      .where(eq(usersTable.id, user.id))
      .returning();

    const { password: _pwd, ...userWithoutPassword } = updated as any;

    const orgScope = {
      currentOrganizationId: currentOrgId,
      allowedOrgIds: null,
    };

    return res.status(200).json({
      user: userWithoutPassword,
      orgScope,
    });
  };
}
