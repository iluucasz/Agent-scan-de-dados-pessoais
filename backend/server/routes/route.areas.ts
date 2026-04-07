import { Router } from 'express';
import { AreasController } from '../controllers/areas.controller';
import { AreasService } from '../services/areas.service';
import { isAuthenticated } from '../access-control';
import { resolveOrgScope, orgScoped } from '../middlewares/org-scope.middleware';

const router = Router();
const service = new AreasService();
const controller = new AreasController(service);

// Listar todas as áreas (admin) ou da organização do usuário
router.get('/api/areas', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.list(req, res)
);

// ========================================
// ROTAS DE HIERARQUIA (devem vir antes das rotas genéricas)
// ========================================

// Buscar árvore hierárquica de áreas (qualquer usuário pode ver da sua org)
router.get('/api/organizations/:organizationId(\\d+)/areas/tree', 
  isAuthenticated,
  resolveOrgScope,
  orgScoped({ source: 'params', key: 'organizationId', mode: 'view' }),
  (req, res) => controller.getTree(req, res)
);

// Buscar apenas áreas raiz (qualquer usuário pode ver da sua org)
router.get('/api/organizations/:organizationId(\\d+)/areas/roots', 
  isAuthenticated,
  resolveOrgScope,
  orgScoped({ source: 'params', key: 'organizationId', mode: 'view' }),
  (req, res) => controller.getRoots(req, res)
);

// Buscar áreas com seus processos (qualquer usuário pode ver da sua org)
router.get('/api/organizations/:organizationId(\\d+)/areas-with-processes', 
  isAuthenticated,
  resolveOrgScope,
  orgScoped({ source: 'params', key: 'organizationId', mode: 'view' }),
  (req, res) => controller.getAreasWithProcessos(req, res)
);

// Listar áreas por organização (qualquer usuário pode ver áreas da sua org)
router.get('/api/organizations/:organizationId(\\d+)/areas', 
  isAuthenticated,
  resolveOrgScope,
  orgScoped({ source: 'params', key: 'organizationId', mode: 'view' }),
  (req, res) => controller.listByOrganization(req, res)
);

// Criar nova área (apenas admin e gestor)
router.post('/api/organizations/:organizationId(\\d+)/areas', 
  isAuthenticated,
  resolveOrgScope,
  orgScoped({ source: 'params', key: 'organizationId', mode: 'write' }),
  (req, res) => controller.create(req, res)
);

// Buscar área por ID
router.get('/api/areas/:id(\\d+)', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.getById(req, res)
);

// Buscar caminho/breadcrumb de uma área específica
router.get('/api/areas/:id(\\d+)/path', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.getPath(req, res)
);

// Buscar filhas diretas de uma área
router.get('/api/areas/:id(\\d+)/children', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.getChildren(req, res)
);

// Buscar todos os descendentes de uma área
router.get('/api/areas/:id(\\d+)/descendants', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.getDescendants(req, res)
);

// Atualizar área (apenas admin e gestor)
router.patch('/api/areas/:id(\\d+)', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.update(req, res)
);

// Compatibilidade PUT (apenas admin e gestor)
router.put('/api/areas/:id(\\d+)', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.update(req, res)
);

// Deletar área (soft delete) - apenas admin e gestor
router.delete('/api/areas/:id(\\d+)', 
  isAuthenticated,
  resolveOrgScope,
  (req, res) => controller.delete(req, res)
);

export default router;
