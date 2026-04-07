import { Router } from "express";
import { isAuthenticated, isAdmin } from "../access-control";
import { resolveOrgScope, orgScoped } from "../middlewares/org-scope.middleware";
import { OrganizationService } from "../services/organization.service";
import { OrganizationController } from "../controllers/organization.controller";

const router = Router();
const service = new OrganizationService();
const controller = new OrganizationController(service);

// Listar todas as organizações (somente autenticado)
router.get('/api/organizations', isAuthenticated, resolveOrgScope, (req, res) => controller.list(req, res));

// Trocar organização ativa
router.post('/api/organizations/switch', isAuthenticated, resolveOrgScope, (req, res) => controller.switchActive(req, res));

// Buscar organização por ID (qualquer usuário pode ver sua própria org)
router.get(
  '/api/organizations/:id(\\d+)',
  isAuthenticated,
  resolveOrgScope,
  orgScoped({ source: 'params', key: 'id', mode: 'view' }),
  (req, res) => controller.getById(req, res)
);

// Criar nova organização (somente admin)
router.post(
  '/api/organizations',
  isAuthenticated,
  isAdmin,
  (req, res) => controller.create(req, res)
);

// Atualizar organização (admin ou com confirmação)
router.patch(
  '/api/organizations/:id(\\d+)',
  isAuthenticated,
  isAdmin,
  (req, res) => controller.update(req, res)
);

// Atualização via PUT (compatibilidade)
router.put(
  '/api/organizations/:id(\\d+)',
  isAuthenticated,
  (req, res) => controller.update(req, res)
);

// Remover organização (somente admin)
router.delete(
  '/api/organizations/:id(\\d+)',
  isAuthenticated,
  isAdmin,
  (req, res) => controller.delete(req, res)
);

export default router; 