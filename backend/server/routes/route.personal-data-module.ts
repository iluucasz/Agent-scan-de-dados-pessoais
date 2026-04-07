import { Router } from 'express';
import { authToken } from '../middlewares/authToken';
import { isDataMappingAllowed } from '../middlewares/data-mapping.middleware';
import { PersonalDataModuleService } from '../services/personal-data-module.service';
import { PersonalDataModuleController } from '../controllers/personal-data-module.controller';
import { resolveOrgScope } from '../middlewares/org-scope.middleware';

const service = new PersonalDataModuleService();
const controller = new PersonalDataModuleController(service);
const router = Router();

// Data Items CRUD
router.get('/api/data-items', authToken, resolveOrgScope, isDataMappingAllowed, (req, res) => controller.getAll(req, res));
router.get('/api/data-items/stats', authToken, resolveOrgScope, isDataMappingAllowed, (req, res) => controller.getStats(req, res));
router.get('/api/data-items/:id(\\d+)', authToken, resolveOrgScope, isDataMappingAllowed, (req, res) => controller.getById(req, res));
router.post('/api/data-items', authToken, resolveOrgScope, isDataMappingAllowed, (req, res) => controller.create(req, res));
router.put('/api/data-items/:id(\\d+)', authToken, resolveOrgScope, isDataMappingAllowed, (req, res) => controller.update(req, res));
router.patch('/api/data-items/:id(\\d+)', authToken, resolveOrgScope, isDataMappingAllowed, (req, res) => controller.update(req, res));
router.delete('/api/data-items/:id(\\d+)', authToken, resolveOrgScope, isDataMappingAllowed, (req, res) => controller.delete(req, res));

export default router; 