import { Router } from 'express';
import { AuthController } from '../controllers/auth.controller';
import { rateLimit } from '../middlewares/rate-limit';
import { authToken } from '../middlewares/authToken';
import { resolveOrgScope, orgScoped } from '../middlewares/org-scope.middleware';

const router = Router();
const controller = new AuthController();

// Login com senha + OTP (2FA via e-mail)
router.post('/api/auth/login/start', rateLimit(), controller.loginStart);
router.post('/api/auth/login/verify', rateLimit(), controller.loginVerify);

router.post('/api/auth/magic-link', rateLimit(), controller.requestMagicLink);
router.get('/api/auth/magic-link/verify', controller.verifyMagicLink);

// Login + OTP
router.post('/api/auth/login', rateLimit(), controller.loginStart);
router.post('/api/auth/login/verify', rateLimit(), controller.loginVerify);

// Login Agent (token permanente + OTP)
router.post('/api/auth/agent/verify-token', rateLimit(), controller.agentVerifyToken);
router.post('/api/auth/agent/verify-otp', rateLimit(), controller.agentVerifyOtp);

// Convites (passwordless)
router.post(
	'/api/users/invite',
	authToken,
	resolveOrgScope,
	orgScoped({ source: 'body', key: 'organizationId' }),
	rateLimit(),
	controller.inviteUser
);
router.get('/api/auth/invite/accept', controller.acceptInvite);

// Verificação de e-mail
router.post('/api/auth/verify-email/request', authToken, rateLimit(), controller.requestVerifyEmail);
router.get('/api/auth/verify-email', controller.verifyEmail);

// Redefinição de senha
router.post('/api/auth/password/reset', rateLimit(), controller.requestPasswordReset);
router.post('/api/auth/password/confirm', rateLimit(), controller.confirmPasswordReset);

export default router;
