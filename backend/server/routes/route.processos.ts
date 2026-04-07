import { Router } from 'express';
import { ProcessosController } from '../controllers/processos.controller';
import { ProcessosService } from '../services/processos.service';
import { isAuthenticated } from '../access-control';
import { resolveOrgScope, orgScoped } from '../middlewares/org-scope.middleware';

const router = Router();
const service = new ProcessosService();
const controller = new ProcessosController(service);

// Listar todos os processos
router.get('/api/processos', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.list(req, res)
);

// Criar processo em uma área (apenas admin e gestor)
router.post('/api/areas/:areaId(\\d+)/processos', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.create(req, res)
);

// Listar processos por área (qualquer usuário pode ver da sua org)
router.get('/api/areas/:areaId(\\d+)/processos', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.listByArea(req, res)
);

// Listar processos por organização (qualquer usuário pode ver da sua org)
router.get('/api/organizations/:organizationId(\\d+)/processos', 
  isAuthenticated,
  resolveOrgScope,
  orgScoped({ source: 'params', key: 'organizationId', mode: 'view' }),
  (req, res) => controller.listByOrganization(req, res)
);

// Buscar processo por ID
router.get('/api/processos/:id(\\d+)', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.getById(req, res)
);

// Atualizar processo (apenas admin e gestor)
router.patch('/api/processos/:id(\\d+)', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.update(req, res)
);

// Compatibilidade PUT (apenas admin e gestor)
router.put('/api/processos/:id(\\d+)', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.update(req, res)
);

// Deletar processo (soft delete) - apenas admin e gestor
router.delete('/api/processos/:id(\\d+)', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.delete(req, res)
);

export default router;
