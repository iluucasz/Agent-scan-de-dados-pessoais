import { Router } from 'express';
import { AgentController } from '../controllers/agent.controller';
import { authToken } from '../middlewares/authToken';
import { isAdmin } from '../access-control';

const router = Router();
const controller = new AgentController();

// Todas as rotas de Agent são restritas a admin autenticado
const adminAuth = [authToken as any, isAdmin as any];

// Criar novo Agent (usuário com role=agent)
router.post('/api/agents', ...adminAuth, (req, res) => controller.createAgent(req, res));

// Listar Agents da organização
router.get('/api/agents', ...adminAuth, (req, res) => controller.listAgents(req, res));

// Resetar token do Agent
router.post('/api/agents/:id([0-9a-fA-F\-]{36})/reset-token', ...adminAuth, (req, res) => controller.resetAgentToken(req, res));

export default router;
