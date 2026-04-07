import { Request, Response } from 'express';
import { insertDataScanConfigSchema } from '../../schemas/scan-data-module.schema';
import { ScanDataModuleService } from '../services/scan-data-module.service';
import { getUploadStats, getUploadWarnings } from '../middlewares/upload-stats.middleware';

export class ScanDataModuleController {
  private service = new ScanDataModuleService();

  async listConfigs(req: Request, res: Response) {
    try {
      const session = req.user as any;
  const orgScope = (req as any).orgScope;
  const orgId = session.role === 'admin' ? undefined : (orgScope?.currentOrganizationId ?? session.organizationId);
      const role = session.role;
      let configs;
  configs = await this.service.getDataScanConfigs(orgId);
      res.json(configs);
    } catch (error) {
      console.error('Error listing scan configs:', error);
      res.status(500).json({ message: (error as Error).message });
    }
  }

  async getConfig(req: Request, res: Response) {
    try {
      const id = Number(req.params.id);
      const config = await this.service.getDataScanConfig(id);
      if (!config) {
        return res.status(404).json({ message: 'Configuração de escaneamento de dados não encontrada' });
      }
  const session = req.user as any;
  const currentOrgId = (req as any).orgScope?.currentOrganizationId ?? session.organizationId;
  if (session.role !== 'admin' && config.organizationId !== currentOrgId) {
        return res.status(403).json({ message: 'Proibido: não é possível acessar a configuração de outra organização' });
      }
      res.json(config);
    } catch (error) {
      console.error('Error getting scan config:', error);
      res.status(500).json({ message: (error as Error).message });
    }
  }

  async createConfig(req: Request, res: Response) {
    try {
      const data = insertDataScanConfigSchema.parse(req.body);
      const session = req.user as any;
      // Override organizationId and createdBy with authenticated user's values
      data.organizationId = session.organizationId;
      data.createdBy = session.id;
      const config = await this.service.createDataScanConfig(data);
      res.status(201).json(config);
    } catch (error) {
      console.error('Error creating scan config:', error);
      res.status(400).json({ message: (error as Error).message });
    }
  }

  async updateConfig(req: Request, res: Response) {
    try {
      const id = Number(req.params.id);
      const data = insertDataScanConfigSchema.partial().parse(req.body);
  const existing = await this.service.getDataScanConfig(id);
      if (!existing) return res.status(404).json({ message: 'Data scan configuration not found' });
  const session = req.user as any;
  const currentOrgId = (req as any).orgScope?.currentOrganizationId ?? session.organizationId;
  if (session.role !== 'admin' && existing.organizationId !== currentOrgId) {
        return res.status(403).json({ message: 'Forbidden: Cannot update configuration from another organization' });
      }
      const updated = await this.service.updateDataScanConfig(id, data);
      res.json(updated);
    } catch (error) {
      console.error('Error updating scan config:', error);
      res.status(400).json({ message: (error as Error).message });
    }
  }

  async deleteConfig(req: Request, res: Response) {
    try {
      const id = Number(req.params.id);
  const existing = await this.service.getDataScanConfig(id);
      if (!existing) return res.status(404).json({ message: 'Configuração de escaneamento de dados não encontrada' });
  const session = req.user as any;
  const currentOrgId = (req as any).orgScope?.currentOrganizationId ?? session.organizationId;
  if (session.role !== 'admin' && existing.organizationId !== currentOrgId) {
        return res.status(403).json({ message: 'Proibido: não é possível excluir a configuração de outra organização' });
      }
      const success = await this.service.deleteDataScanConfig(id);
      if (!success) return res.status(404).json({ message: 'Configuração de escaneamento de dados não encontrada' });
      return res.status(204).send();
    } catch (error) {
      console.error('Error deleting scan config:', error);
      res.status(500).json({ message: (error as Error).message });
    }
  }

  async listJobs(req: Request, res: Response) {
    try {
  const session = req.user as any;
  const orgId = session.role === 'admin' ? undefined : ((req as any).orgScope?.currentOrganizationId ?? session.organizationId);
      const configId = req.query.configId ? Number(req.query.configId) : undefined;
      const jobs = await this.service.getDataScanJobs(orgId, configId);
      res.json(jobs);
    } catch (error) {
      console.error('Error listing scan jobs:', error);
      res.status(500).json({ message: (error as Error).message });
    }
  }

  async getJob(req: Request, res: Response) {
    try {
      const id = Number(req.params.id);
  const job = await this.service.getDataScanJob(id);
      if (!job) return res.status(404).json({ message: 'Registro de escaneamento não encontrado' });
  const session = req.user as any;
  const currentOrgId = (req as any).orgScope?.currentOrganizationId ?? session.organizationId;
  if (session.role !== 'admin' && job.organizationId !== currentOrgId) {
        return res.status(403).json({ message: 'Proibido: não é possível acessar o registro de outra organização' });
      }
      res.json(job);
    } catch (error) {
      console.error('Error getting scan job:', error);
      res.status(500).json({ message: (error as Error).message });
    }
  }

  async deleteJob(req: Request, res: Response) {
    try {
      const id = Number(req.params.id);
  const job = await this.service.getDataScanJob(id);
      if (!job) return res.status(404).json({ message: 'Registro de escaneamento não encontrado' });
  const session = req.user as any;
  const currentOrgId = (req as any).orgScope?.currentOrganizationId ?? session.organizationId;
  if (session.role !== 'admin' && job.organizationId !== currentOrgId) {
        return res.status(403).json({ message: 'Proibido: não é possível excluir o registro de outra organização' });
      }
      const success = await this.service.deleteDataScanJob(id);
      if (!success) return res.status(500).json({ message: 'Erro ao excluir registro de escaneamento' });
      return res.status(204).send();
    } catch (error) {
      console.error('Error deleting scan job:', error);
      res.status(500).json({ message: (error as Error).message });
    }
  }

  async runScan(req: Request, res: Response) {
    try {
      const configId = Number(req.params.id);
  const session = req.user as any;
  const orgId = (req as any).orgScope?.currentOrganizationId ?? session.organizationId;
      
      console.log('🚀 [SCAN] Iniciando processamento de upload');
      
      // Verificar se houve warnings do Multer
      const multerWarning = (req as any).multerWarning;
      if (multerWarning) {
        console.log('⚠️ [SCAN] Warning do Multer detectado:', multerWarning);
      }
      
      // Obter arquivos enviados com tratamento flexível para diferentes estruturas
      let files: Express.Multer.File[] = [];
      
      if (req.files) {
        if (Array.isArray(req.files)) {
          // Caso .any() - arquivos vêm como array
          files = req.files;
        } else {
          // Caso .fields() - arquivos vêm como objeto
          const filesObj = req.files as { [fieldname: string]: Express.Multer.File[] };
          
          // Tentar diferentes nomes de campos comuns
          const possibleFieldNames = ['files', 'file', 'uploads', 'documents'];
          
          for (const fieldName of possibleFieldNames) {
            if (filesObj[fieldName]) {
              files = filesObj[fieldName];
              break;
            }
          }
          
          // Se não encontrou, pegar todos os arquivos de qualquer campo
          if (files.length === 0) {
            files = Object.values(filesObj).flat();
          }
        }
      }
      
      // Obter scanName com tratamento flexível
      let scanName = req.body.scanName || req.body.scan_name || req.body.name || req.body.scanTitle;
      
      // Validar se a configuração existe e pertence à organização
      const config = await this.service.getDataScanConfig(configId);
      if (!config) {
        return res.status(404).json({ message: 'Configuração de escaneamento não encontrada' });
      }
      
  if (session.role !== 'admin' && config.organizationId !== orgId) {
        return res.status(403).json({ message: 'Proibido: não é possível executar escaneamento de outra organização' });
      }
      
      // Validar scanName se arquivos foram fornecidos
      if (files.length > 0 && (!scanName || scanName.trim().length === 0)) {
        return res.status(400).json({ 
          message: 'scanName é obrigatório quando arquivos são fornecidos',
          example: 'scanName: "escaneamento TI 11/07/2025"'
        });
      }
      
      // Extrair campos opcionais enviados pelo Agent (quando presentes) e tentar parsear JSON
      const parseMaybeJson = (val: any) => {
        if (val === undefined || val === null) return undefined;
        if (typeof val !== 'string') return val;
        try { return JSON.parse(val); } catch { return val; }
      };

      const clientPayload = {
        metadata: parseMaybeJson((req.body as any).metadata),
        personalData: parseMaybeJson((req.body as any).personalData),
        itAssets: parseMaybeJson((req.body as any).itAssets),
        summary: parseMaybeJson((req.body as any).summary),
        performance: parseMaybeJson((req.body as any).performance)
      };

      // Executar escaneamento com arquivos e scanName; incluir payload extra para registrar em stats
      const job = await this.service.runDataScan(configId, orgId, scanName, files, clientPayload);
      
      // Determinar qual provider foi realmente usado
      const actualProvider = this.service.getActualStorageProvider();
      
      // Obter estatísticas de upload
  const uploadStats = { ...getUploadStats(req), requestId: (req as any).requestId };
      const uploadWarnings = getUploadWarnings(req);
      
      // Preparar resposta com informações sobre warnings (se houver)
      const response: any = {
        message: 'Escaneamento iniciado com sucesso',
        job,
        jobId: job.id,                    // ✅ Adicionar jobId explicitamente
        id: job.id,                       // ✅ Compatibilidade adicional
        scanName,
        filesProcessed: files.length,
        fileNames: files.map(f => f.originalname),
        storageProvider: actualProvider,
        uploadStats                       // ✅ Estatísticas de upload
      };
      
      // Adicionar warnings se houver
      if (uploadWarnings) {
        response.warnings = uploadWarnings;
      }
      
      // Adicionar informações sobre warnings do Multer (se houver)
      if (multerWarning) {
        response.warning = {
          type: multerWarning.type,
          message: multerWarning.message,
          note: 'Alguns arquivos podem não ter sido processados devido a limites, mas o escaneamento continua com os arquivos válidos'
        };
      }
      
      res.status(201).json(response);
    } catch (error) {
      console.error('❌ [SCAN] Error running scan:', error);
      console.error('❌ [SCAN] Error stack:', error instanceof Error ? error.stack : 'No stack trace');
      
      res.status(400).json({ 
        message: (error as Error).message,
        details: error instanceof Error ? error.stack : undefined,
        errorType: 'scan_execution_error'
      });
    }
  }

  async scheduleScan(req: Request, res: Response) {
    try {
      const configId = Number(req.params.id);
      const schedule = req.body.schedule;
      const config = await this.service.scheduleDataScan(configId, schedule);
      res.json({ message: 'Escaneamento agendado com sucesso', configId, schedule });
    } catch (error) {
      console.error('Error scheduling scan:', error);
      res.status(500).json({ message: (error as Error).message });
    }
  }

  async cancelSchedule(req: Request, res: Response) {
    try {
      const configId = Number(req.params.id);
      const config = await this.service.cancelScheduledScan(configId);
      res.json({ message: 'Agendamento de escaneamento cancelado com sucesso' });
    } catch (error) {
      console.error('Error cancelling scheduled scan:', error);
      res.status(500).json({ message: (error as Error).message });
    }
  }

  async externalResults(req: Request, res: Response) {
    try {

      // Extrair dados do payload do SeusDADOS Client
      const { 
        scanId, 
        scanName, 
        timestamp, 
        config, 
        user, 
        systemInfo, 
        stats, 
        results 
      } = req.body;

      // Validar campos obrigatórios
      if (!scanId || !scanName || !user?.organizationId || !results) {
        return res.status(422).json({
          success: false,
          error: "Campos obrigatórios ausentes",
          code: "MISSING_REQUIRED_FIELDS",
          details: {
            required: ["scanId", "scanName", "user.organizationId", "results"]
          }
        });
      }

      // Extrair headers do client
      const clientVersion = req.headers['x-client-version'] as string;
      const scanIdHeader = req.headers['x-scan-id'] as string;

      // Validar se scanId do header confere com o do body
      if (scanIdHeader && scanIdHeader !== scanId) {
        return res.status(400).json({
          success: false,
          error: "ScanId do header não confere com o do payload",
          code: "SCAN_ID_MISMATCH",
          details: { headerScanId: scanIdHeader, bodyScanId: scanId }
        });
      }

      // Criar configuração de scan
      const configData = {
        name: scanName,
        description: `Scan externo - ${user.department || 'N/A'} - ${systemInfo?.hostname || 'Unknown'}`,
        sourceType: 'api' as 'api', // Explicitly type as 'api'
        organizationId: user.organizationId,
        connectionConfig: {
          directory: config?.directory,
          clientVersion: clientVersion,
          systemInfo: systemInfo,
          clientType: 'seusDADOS_client' // Identificador do tipo de client
        } as any, // Cast as any/Json if needed
        scanPattern: {
          fileTypes: config?.fileTypes || 'all',
          selectedPatterns: config?.selectedPatterns || [],
          maxDepth: config?.maxDepth,
          maxFileSize: config?.maxFileSize
        } as any, // Cast as any/Json if needed
        createdBy: user.email // Usar email do usuário do payload
      };

      const scanConfig = await this.service.createDataScanConfig(configData);

      // Criar job de scan
      const jobData = {
        configId: scanConfig.id,
        organizationId: user.organizationId,
        status: 'completed' as const,
        startedAt: timestamp ? new Date(timestamp) : new Date(),
        completedAt: new Date(),
        foundItems: results || [],
        stats: {
          totalFiles: stats?.totalFiles || 0,
          filesWithData: stats?.processedFiles || 0,
          totalDataItems: stats?.totalFindings || (results?.length || 0),
          executionTime: stats?.executionTime || 0,
          errors: stats?.errors || 0,
          clientVersion: clientVersion,
          systemInfo: systemInfo,
          // Persist full external payload metadata for lookup by scanId later
          external: {
            scanId,
            scanName,
            timestamp: timestamp || new Date().toISOString(),
            config,
            user,
            systemInfo,
            stats,
            clientVersion: clientVersion
          }
        }
      };

      const job = await this.service.createDataScanJob(jobData);

      // Resposta de sucesso conforme especificação
      res.status(200).json({
        success: true,
        scanId: scanId,
        receivedAt: new Date().toISOString(),
        processedItems: results?.length || 0,
        message: "Dados de escaneamento recebidos e processados com sucesso",
        jobId: job.id,
        configId: scanConfig.id
      });

    } catch (error) {
      console.error('Error processing external scan results:', error);
      
      // Resposta de erro conforme especificação
      res.status(500).json({
        success: false,
        error: "Erro interno do servidor ao processar dados de escaneamento",
        code: "INTERNAL_SERVER_ERROR",
        details: {
          message: (error as Error).message,
          timestamp: new Date().toISOString()
        }
      });
    }
  }

  /**
   * Buscar resultados de scan externo por scanId
   * GET /api/external-scan-results/{scanId}
   */
  async getExternalScanResult(req: Request, res: Response) {
    try {
      const { scanId } = req.params;
      const session = req.user as any;

      // Validar scanId
      if (!scanId) {
        return res.status(400).json({
          success: false,
          error: "scanId é obrigatório",
          code: "MISSING_SCAN_ID"
        });
      }

      // Buscar dados do scan
  const currentOrgId = (req as any).orgScope?.currentOrganizationId ?? session.organizationId;
  const result = await this.service.getExternalScanByScanId(scanId, currentOrgId, session.role);

      if (!result) {
        return res.status(404).json({
          success: false,
          error: "Scan não encontrado",
          code: "SCAN_NOT_FOUND",
          scanId: scanId
        });
      }

      // Retornar dados completos conforme especificação
      res.status(200).json(result);

    } catch (error) {
      console.error('⚠️ [Get External Scan] Erro:', error);
      res.status(500).json({
        success: false,
        error: "Erro interno ao buscar resultados do scan",
        code: "INTERNAL_ERROR",
        message: error instanceof Error ? error.message : 'Erro desconhecido'
      });
    }
  }

  /**
   * Deletar TODOS os jobs
   * DELETE /api/data-scan-jobs
   */
  async deleteAllJobs(req: Request, res: Response) {
    try {
  const session = req.user as any;
  const orgId = (req as any).orgScope?.currentOrganizationId ?? session.organizationId;
      const role = session.role;
      
      let deletedCount;
      if (role === 'admin') {
        // Admin pode deletar todos os jobs do sistema
        deletedCount = await this.service.deleteAllJobs();
      } else {
        // Usuário comum só pode deletar jobs da sua organização
  deletedCount = await this.service.deleteJobsByOrganization(orgId);
      }
      
      res.json({ 
        message: `${deletedCount} job(s) deletado(s) com sucesso`,
        deletedCount 
      });
    } catch (error) {
      console.error('Error deleting all jobs:', error);
      res.status(500).json({ message: (error as Error).message });
    }
  }

  /**
   * Deletar um item específico dentro de foundItems
   * DELETE /api/data-scan-jobs/:jobId/found-items/:itemId
   */
  async deleteFoundItem(req: Request, res: Response) {
    try {
      const jobId = Number(req.params.jobId);
      const itemId = req.params.itemId;

      if (!jobId || isNaN(jobId)) {
        return res.status(400).json({ message: 'ID do job inválido' });
      }

      if (!itemId) {
        return res.status(400).json({ message: 'ID do item é obrigatório' });
      }

      // Verificar se o job existe e pertence à organização do usuário
      const job = await this.service.getDataScanJob(jobId);
      if (!job) {
        return res.status(404).json({ message: 'Job não encontrado' });
      }

      const session = req.user as any;
      const currentOrgId = (req as any).orgScope?.currentOrganizationId ?? session.organizationId;
      
      // Verificar permissão
      if (session.role !== 'admin' && job.organizationId !== currentOrgId) {
        return res.status(403).json({ message: 'Sem permissão para deletar itens deste job' });
      }

      // Deletar o item
      const result = await this.service.deleteFoundItem(jobId, itemId);

      if (!result.success) {
        return res.status(404).json({ message: result.message });
      }

      res.json(result);

    } catch (error) {
      console.error('Error deleting found item:', error);
      res.status(500).json({ message: (error as Error).message });
    }
  }
}
