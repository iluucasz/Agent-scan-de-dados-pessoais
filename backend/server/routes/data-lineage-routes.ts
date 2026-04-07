import express from "express";
import { isAuthenticated } from "../access-control";
import { 
  getDataLineageStats, 
  getDataItemLineage, 
  getOrganizationLineage 
} from "../controllers/dataLineageController";

const router = express.Router();

// Verificar que o usuário está autenticado para todas as rotas deste módulo
router.use(isAuthenticated);

// Rotas para estatísticas de linhagem de dados
router.get('/stats', getDataLineageStats);
router.get('/stats/:organizationId', getDataLineageStats);

// Rotas para linhagem específica de itens de dados
router.get('/:dataItemId', getDataItemLineage);

// Rotas para linhagem de uma organização inteira
router.get('/organization/:organizationId', getOrganizationLineage);

export default router;