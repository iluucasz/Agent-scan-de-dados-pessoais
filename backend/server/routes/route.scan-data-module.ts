import { Router, Request, Response } from 'express';
import { isAuthenticated, isAdmin } from '../access-control';
import { ScanDataModuleController } from '../controllers/scan-data-module.controller';
import { uploadScanData } from '../middlewares/scan-upload.middleware';
import { logFieldNames } from '../middlewares/log-fields.middleware';
import { handleMulterErrors } from '../middlewares/multer-error-handler.middleware';
import { collectUploadStats } from '../middlewares/upload-stats.middleware';
import { resolveOrgScope } from '../middlewares/org-scope.middleware';

const router = Router();
const controller = new ScanDataModuleController();

// Data Scan Configs
router.get('/api/data-scan-configs', isAuthenticated, resolveOrgScope, controller.listConfigs.bind(controller));
router.get('/api/data-scan-configs/:id', isAuthenticated, resolveOrgScope, controller.getConfig.bind(controller));
router.post('/api/data-scan-configs', isAuthenticated, resolveOrgScope, controller.createConfig.bind(controller));
router.put('/api/data-scan-configs/:id', isAuthenticated, resolveOrgScope, controller.updateConfig.bind(controller));
router.patch('/api/data-scan-configs/:id', isAuthenticated, resolveOrgScope, controller.updateConfig.bind(controller));
router.delete('/api/data-scan-configs/:id', isAuthenticated, resolveOrgScope, controller.deleteConfig.bind(controller));

// Data Scan Jobs
router.get('/api/data-scan-jobs', isAuthenticated, resolveOrgScope, controller.listJobs.bind(controller));
router.get('/api/data-scan-jobs/:id', isAuthenticated, resolveOrgScope, controller.getJob.bind(controller));
router.delete('/api/data-scan-jobs/:id', isAuthenticated, resolveOrgScope, controller.deleteJob.bind(controller));
router.delete('/api/data-scan-jobs', isAuthenticated, resolveOrgScope, controller.deleteAllJobs.bind(controller));

// Deletar item específico dentro de foundItems
router.delete('/api/data-scan-jobs/:jobId/found-items/:itemId', isAuthenticated, resolveOrgScope, controller.deleteFoundItem.bind(controller));

// Execution and Scheduling
router.post('/api/data-scan-configs/:id/run', 
  isAuthenticated,
  resolveOrgScope,
  collectUploadStats,    // ✅ Coleta estatísticas de upload  
  logFieldNames,
  // Usar .any() em vez de .fields() para aceitar qualquer estrutura de campos
  // Isso evita o "Unexpected field" e permite flexibilidade total
  uploadScanData.any(),
  handleMulterErrors, // Middleware para tratar erros do Multer sem parar o processamento
  controller.runScan.bind(controller)
);
router.post('/api/data-scan-configs/:id/schedule', isAuthenticated, controller.scheduleScan.bind(controller));
router.delete('/api/data-scan-configs/:id/schedule', isAuthenticated, controller.cancelSchedule.bind(controller));

// External scan results (client apps) - REQUIRES AUTHENTICATION
router.post('/api/external-scan-results', isAuthenticated, controller.externalResults.bind(controller));
router.get('/api/external-scan-results/:scanId', isAuthenticated, controller.getExternalScanResult.bind(controller));

// Health check endpoint (sem autenticação para monitoramento)
router.get('/api/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'Privacy Pulse Backend',
    version: '1.0.0',
    uptime: process.uptime()
  });
});

export default router; 