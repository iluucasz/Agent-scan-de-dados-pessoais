import { db } from '../db';
import { and, eq } from 'drizzle-orm';
import { dataScanConfigs, dataScanJobs, InsertDataScanConfig, InsertDataScanJob } from '../../schemas/scan-data-module.schema';
import { DigitalOceanUploadService } from './digitalocean-upload.service';

export class ScanDataModuleService {
  private uploadService: DigitalOceanUploadService | null = null;

  constructor() {
    const useDigitalOcean = process.env.STORAGE_PROVIDER === 'digitalocean' || process.env.STORAGE_PROVIDER === 'hybrid';
    
    if (useDigitalOcean) {
      try {
        this.uploadService = new DigitalOceanUploadService();
      } catch (error) {
        this.uploadService = null;
      }
    }
  }
  
  /**
   * Retorna qual provider de storage está sendo usado atualmente
   */
  getActualStorageProvider(): string {
    if (this.uploadService) {
      return 'digitalocean';
    }
    return 'local';
  }

  async getDataScanConfigs(orgId?: number) {
    if (orgId) {
      return db.select().from(dataScanConfigs).where(eq(dataScanConfigs.organizationId, orgId));
    }
    return db.select().from(dataScanConfigs);
  }

  async getDataScanConfig(id: number) {
    const [config] = await db.select().from(dataScanConfigs).where(eq(dataScanConfigs.id, id));
    return config;
  }

  async createDataScanConfig(data: InsertDataScanConfig) {
    if (typeof data.organizationId === 'undefined') {
      throw new Error('organizationId is required to create a DataScanConfig');
    }
    const [config] = await db.insert(dataScanConfigs).values(data as Required<InsertDataScanConfig>).returning();
    return config;
  }

  async updateDataScanConfig(id: number, data: Partial<InsertDataScanConfig>) {
    const [config] = await db.update(dataScanConfigs).set(data).where(eq(dataScanConfigs.id, id)).returning();
    return config;
  }

  async deleteDataScanConfig(id: number): Promise<boolean> {
    const { rowCount } = await db.delete(dataScanConfigs).where(eq(dataScanConfigs.id, id));
    return (rowCount ?? 0) > 0;
  }

  async getDataScanJobs(orgId?: number, configId?: number): Promise<any[]> {
    // Combine filters correctly; calling .where twice overrides previous conditions in Drizzle
    const conditions = [
      ...(orgId ? [eq(dataScanJobs.organizationId, orgId)] : []),
      ...(configId ? [eq(dataScanJobs.configId, configId)] : [])
    ];

    const whereClause = conditions.length > 1 ? and(...conditions) : conditions[0];
    const builder = whereClause
      ? db.select().from(dataScanJobs).where(whereClause)
      : db.select().from(dataScanJobs);

    const jobs = await builder;
    return jobs;
  }

  async getDataScanJob(id: number) {
    const [job] = await db.select().from(dataScanJobs).where(eq(dataScanJobs.id, id));
    return job;
  }

  async createDataScanJob(data: InsertDataScanJob) {
    const [job] = await db.insert(dataScanJobs).values(data).returning();
    return job;
  }

  async deleteDataScanJob(id: number): Promise<boolean> {
    const { rowCount } = await db.delete(dataScanJobs).where(eq(dataScanJobs.id, id));
    return (rowCount ?? 0) > 0;
  }

  /**
   * Executa scan com upload para DigitalOcean
   */
  async runDataScan(
    configId: number,
    orgId: number,
    scanName?: string,
    files?: Express.Multer.File[],
    clientPayload?: {
      metadata?: any;
      personalData?: any;
      itAssets?: any;
      summary?: any;
      performance?: any;
    }
  ) {
    try {
      const config = await this.getDataScanConfig(configId);
      if (!config) {
        throw new Error('Configuração de escaneamento não encontrada');
      }

      if (files && files.length > 0 && (!scanName || scanName.trim().length === 0)) {
        throw new Error('scanName é obrigatório quando arquivos são fornecidos');
      }

      const jobData: InsertDataScanJob = {
        configId,
        organizationId: orgId,
        status: 'in_progress',
        startedAt: new Date(),
        completedAt: null,
        foundItems: [],
        stats: {
          totalFiles: files?.length || 0,
          filesWithData: 0,
          totalDataItems: 0,
          ...(clientPayload && {
            agent: {
              metadata: clientPayload.metadata,
              personalData: clientPayload.personalData,
              itAssets: clientPayload.itAssets,
              summary: clientPayload.summary,
              performance: clientPayload.performance
            }
          })
        }
      };

  const job = await this.createDataScanJob(jobData);

      if (files && files.length > 0) {
        await this.processUploadedFiles(job.id, files, scanName!);
      } else {
        await this.executeConfigBasedScan(job.id, config);
      }

      // Fetch and return the updated job record (includes foundItems/stats/status)
      const updated = await this.getDataScanJob(job.id);
      return updated ?? job;
    } catch (error) {
      throw error;
    }
  }

  private async processUploadedFiles(jobId: number, files: Express.Multer.File[], scanName: string) {
    const foundItems: any[] = [];
    let filesWithData = 0;
    let uploadResults: any = null;

    try {
      if (this.uploadService) {
        uploadResults = await this.uploadService.uploadScanFiles(files, scanName);
      }

      for (const file of files) {
        try {
          const fileData = await this.analyzeFile(file);
          
          if (fileData.length > 0) {
            filesWithData++;
            
            if (uploadResults) {
              const uploadResult = uploadResults.results.find((r: any) => r.originalName === file.originalname);
              if (uploadResult && uploadResult.status === 'success') {
                fileData.forEach((item: any) => {
                  item.cdnUrl = uploadResult.cdnUrl;
                  item.uploadUrl = uploadResult.uploadUrl;
                });
              }
            }
            
            // ✅ Adicionar UUID único para cada item encontrado
            const itemsWithId = fileData.map((item: any) => ({
              ...item,
              id: crypto.randomUUID()
            }));
            
            foundItems.push(...itemsWithId);
          }
        } catch (error) {
          // Log error silently but continue processing other files
        }
      }

      // Preserve existing stats (agent/external) and merge with new metrics
      const current = await this.getDataScanJob(jobId);
      const existingStats = (current as any)?.stats || {};

      await db.update(dataScanJobs)
        .set({
          status: 'completed',
          completedAt: new Date(),
          foundItems,
          stats: {
            ...existingStats,
            totalFiles: files.length,
            filesWithData,
            totalDataItems: foundItems.length,
            uploadResults: uploadResults
              ? {
                  scanName: uploadResults.scanName,
                  folderName: uploadResults.folderName,
                  successfulUploads: uploadResults.successfulUploads,
                  failedUploads: uploadResults.failedUploads,
                  duration: uploadResults.duration
                }
              : existingStats?.uploadResults || null
          }
        })
        .where(eq(dataScanJobs.id, jobId));

    } catch (error) {
      const current = await this.getDataScanJob(jobId);
      const existingStats = (current as any)?.stats || {};

      await db.update(dataScanJobs)
        .set({
          status: 'failed',
          completedAt: new Date(),
          foundItems: [],
          stats: {
            ...existingStats,
            totalFiles: files.length,
            filesWithData: 0,
            totalDataItems: 0,
            error: error instanceof Error ? error.message : 'Erro desconhecido'
          }
        })
        .where(eq(dataScanJobs.id, jobId));
      
      throw error;
    }
  }

  private async executeConfigBasedScan(jobId: number, config: any) {
    const current = await this.getDataScanJob(jobId);
    const existingStats = (current as any)?.stats || {};

    await db.update(dataScanJobs)
      .set({
        status: 'completed',
        completedAt: new Date(),
        foundItems: [],
        stats: {
          ...existingStats,
          totalFiles: 0,
          filesWithData: 0,
          totalDataItems: 0
        }
      })
      .where(eq(dataScanJobs.id, jobId));
  }

  /**
   * Detecta o tipo original do arquivo baseado no MIME type e extensão
   */
  private detectOriginalFileType(file: Express.Multer.File): string {
    const mimeToExtension: { [key: string]: string } = {
      'application/pdf': '.pdf',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
      'application/msword': '.doc',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
      'application/vnd.ms-excel': '.xls',
      'text/plain': '.txt',
      'text/csv': '.csv',
      'application/json': '.json',
      'application/xml': '.xml',
      'text/xml': '.xml',
      'text/html': '.html',
      'application/javascript': '.js',
      'text/javascript': '.js',
      'application/x-javascript': '.js',
      'application/x-php': '.php',
      'text/x-php': '.php',
      'text/x-log': '.log',
      'application/zip': '.zip',
      'application/x-zip-compressed': '.zip'
    };

    // Prioridade 1: MIME type
    if (file.mimetype && mimeToExtension[file.mimetype]) {
      return mimeToExtension[file.mimetype];
    }

    // Prioridade 2: Extensão original
    let cleanFileName = file.originalname;
    if (cleanFileName.includes('_extracted.txt')) {
      cleanFileName = cleanFileName.replace('_extracted.txt', '');
    }
    
    const originalExtension = cleanFileName.split('.').pop()?.toLowerCase();
    const supportedExtensions = [
      'txt', 'csv', 'log', 'html', 'xml', 'json', 'js', 'php', 
      'doc', 'docx', 'pdf', 'xls', 'xlsx', 'zip'
    ];
    
    if (originalExtension && supportedExtensions.includes(originalExtension)) {
      return `.${originalExtension}`;
    }

    // Prioridade 3: Fallback para PDF se MIME indica
    if (file.mimetype === 'application/pdf') {
      return '.pdf';
    }

    return '.txt';
  }

  /**
   * Faz preprocessing do conteúdo baseado no tipo de arquivo
   */
  private preprocessFileContent(file: Express.Multer.File, fileType: string): string {
    if (fileType === '.pdf') {
      let content: string;
      
      try {
        content = file.buffer.toString('utf-8');
      } catch {
        try {
          content = file.buffer.toString('latin1');
        } catch {
          content = file.buffer.toString('binary');
        }
      }
      
      return content
        .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    }
    
    const content = file.buffer.toString('utf-8');
    
    // Processamento específico por tipo
    switch (fileType) {
      case '.csv':
      case '.log':
      case '.xml':
      case '.js':
      case '.php':
      case '.xls':
      case '.xlsx':
        return content;
        
      case '.html':
        return content
          .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
          .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
          .replace(/<[^>]+>/g, ' ')
          .replace(/\s+/g, ' ')
          .trim();
          
      case '.json':
        try {
          const parsed = JSON.parse(content);
          return JSON.stringify(parsed, null, 2);
        } catch {
          return content;
        }
        
      case '.doc':
      case '.docx':
        return content
          .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]/g, ' ')
          .replace(/\s+/g, ' ')
          .trim();
          
      case '.txt':
        return content
          .replace(/\r\n/g, '\n')
          .replace(/\r/g, '\n')
          .trim();
          
      default:
        return content;
    }
  }

  /**
   * Analisa arquivo usando DataAnalyzer
   */
  private async analyzeFile(file: Express.Multer.File): Promise<any[]> {
    try {
      const originalFileType = this.detectOriginalFileType(file);
      const fileContent = this.preprocessFileContent(file, originalFileType);
      
      const { DataAnalyzer } = await import('../scanUtils');
      
      // Limpa nome do arquivo
      let cleanFileName = file.originalname;
      if (cleanFileName.includes('_extracted.txt')) {
        cleanFileName = cleanFileName.replace('_extracted.txt', '');
      }
      
      const originalNameWithoutExt = cleanFileName.replace(/\.[^/.]+$/, '');
      const preservedFileName = originalNameWithoutExt + originalFileType;
      
      const analysisResults = DataAnalyzer.analyzeText(fileContent, undefined, {
        file: preservedFileName,
        directory: 'uploads'
      });
      
      const formattedResults: any[] = [];
      
      analysisResults.forEach(result => {
        result.matches.forEach((match, index) => {
          let cleanContext = result.matchLocations?.[index]?.context || 'Detectado no arquivo';
          
          // Remove marcações de destaque
          cleanContext = cleanContext.replace(/\*\*(.*?)\*\*/g, '$1');
          
          // Busca contexto mais direto nas linhas do arquivo
          const lines = fileContent.split('\n');
          let directContext = cleanContext;
          
          for (const line of lines) {
            if (line.includes(match)) {
              const patterns = [
                new RegExp(`\\(([^)]*${match.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}[^)]*)\\)`, 'i'),
                new RegExp(`([A-ZÀÁÂÃÇÉÊËÍÎÓÔÕÚÜ]+:\\s*[^\\s]*${match.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}[^\\s]*)`, 'i'),
                new RegExp(`([^\\n]*${match.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}[^\\n]*)`, 'i')
              ];
              
              for (const pattern of patterns) {
                const matchResult = line.match(pattern);
                if (matchResult) {
                  directContext = matchResult[1] || matchResult[0];
                  
                  // Limita tamanho do contexto
                  if (directContext.length > 80) {
                    const matchIndex = directContext.indexOf(match);
                    const start = Math.max(0, matchIndex - 30);
                    const end = Math.min(directContext.length, matchIndex + match.length + 30);
                    directContext = directContext.substring(start, end);
                    if (start > 0) directContext = '...' + directContext;
                    if (end < directContext.length) directContext = directContext + '...';
                  }
                  break;
                }
              }
              break;
            }
          }
          
          formattedResults.push({
            dataType: result.pattern,
            category: result.category,
            subcategory: result.subcategory,
            criticality: this.getCriticalityLevel(result.pattern),
            value: match,
            file: preservedFileName,
            fileName: preservedFileName,
            location: directContext,
            matches: 1,
            line: result.matchLocations?.[index]?.line
          });
        });
      });
      
      return formattedResults;
    } catch (error) {
      return [];
    }
  }

  /**
   * Determina o nível de criticidade baseado no tipo de dado
   */
  private getCriticalityLevel(dataType: string): string {
    const criticalityMap: { [key: string]: string } = {
      'cpf': 'high',
      'rg': 'high',
      'cnpj': 'high',
      'passport': 'high',
      'credit_card': 'critical',
      'bank_account': 'critical',
      'health_card': 'critical',
      'medical_record': 'critical',
      'email': 'medium',
      'phone_br': 'medium',
      'phone_intl': 'medium',
      'names': 'low',
      'date_of_birth': 'high',
      'cep': 'low',
      'coordinates': 'medium'
    };
    
    return criticalityMap[dataType] || 'medium';
  }

  async scheduleDataScan(configId: number, schedule: string) {
    const [config] = await db.update(dataScanConfigs).set({ scanSchedule: schedule }).where(eq(dataScanConfigs.id, configId)).returning();
    return config;
  }

  async cancelScheduledScan(configId: number) {
    const [config] = await db.update(dataScanConfigs).set({ scanSchedule: null }).where(eq(dataScanConfigs.id, configId)).returning();
    return config;
  }

  /**
   * Buscar dados de scan externo por scanId
   */
  async getExternalScanByScanId(scanId: string, userOrgId: number, userRole: string) {
    try {
      const jobs = await this.getDataScanJobs(userRole === 'admin' ? undefined : userOrgId);

      let targetJob: any = null;
      let meta: any = null;

      for (const job of jobs) {
        const stats = (job as any).stats || {};
        const external = (stats as any).external;
        const agentMeta = (stats as any).agent?.metadata;
        const foundItems = job.foundItems as any[] | undefined;

        if (external?.scanId === scanId) {
          targetJob = job;
          meta = external;
          break;
        }
        if (agentMeta?.scanId === scanId) {
          targetJob = job;
          meta = {
            scanId: agentMeta.scanId,
            scanName: agentMeta.scanName || job.name,
            config: agentMeta.config,
            user: agentMeta.user,
            systemInfo: agentMeta.systemInfo,
            clientVersion: agentMeta.clientVersion
          };
          break;
        }
        if (foundItems && foundItems.some((it: any) => it.scanId === scanId)) {
          targetJob = job;
          // Minimal meta from job/config
          meta = { scanId, scanName: job.name };
          break;
        }
      }

      if (!targetJob || !meta) {
        return null;
      }

      const config = await this.getDataScanConfig(targetJob.configId);
      if (!config) return null;

      const response = {
        scanId: meta.scanId,
        scanName: meta.scanName || config.name,
        timestamp: (targetJob.startedAt as Date) ?? new Date(),
        config: {
          directory: (meta.config as any)?.directory || (config.connectionConfig as any)?.directory,
          maxDepth: (meta.config as any)?.maxDepth || (config.scanPattern as any)?.maxDepth || 5,
          maxFileSize: (meta.config as any)?.maxFileSize || (config.scanPattern as any)?.maxFileSize || 104857600,
          fileTypes: (meta.config as any)?.fileTypes || (config.scanPattern as any)?.fileTypes || 'all',
          selectedPatterns: (meta.config as any)?.selectedPatterns || (config.scanPattern as any)?.selectedPatterns || []
        },
        user: {
          name: (meta.user as any)?.name || 'N/A',
          email: (meta.user as any)?.email || config.createdBy || 'N/A',
          department: (meta.user as any)?.department || 'N/A',
          organizationId: (meta.user as any)?.organizationId || targetJob.organizationId
        },
        systemInfo: {
          os: (meta.systemInfo as any)?.os || (config.connectionConfig as any)?.systemInfo?.os || 'N/A',
          hostname: (meta.systemInfo as any)?.hostname || (config.connectionConfig as any)?.systemInfo?.hostname || 'N/A',
          version: (meta.systemInfo as any)?.version || (config.connectionConfig as any)?.clientVersion || 'N/A'
        },
        stats: {
          totalFiles: (targetJob.stats as any)?.totalFiles || 0,
          processedFiles: (targetJob.stats as any)?.filesWithData || 0,
          totalFindings: (targetJob.stats as any)?.totalDataItems || (Array.isArray(targetJob.foundItems) ? targetJob.foundItems.length : 0),
          executionTime: (targetJob.stats as any)?.executionTime || 0,
          errors: (targetJob.stats as any)?.errors || 0
        },
        results: Array.isArray(targetJob.foundItems) ? targetJob.foundItems : []
      };

      return response;

    } catch (error) {
      throw error;
    }
  }

  // === MÉTODOS PARA GERENCIAMENTO DE JOBS ===

  /**
   * Deletar TODOS os jobs (apenas para admin)
   */
  async deleteAllJobs(): Promise<number> {
    const result = await db.delete(dataScanJobs);
    return result.rowCount || 0;
  }

  /**
   * Deletar todos os jobs de uma organização específica
   */
  async deleteJobsByOrganization(orgId: number): Promise<number> {
    const result = await db.delete(dataScanJobs).where(eq(dataScanJobs.organizationId, orgId));
    return result.rowCount || 0;
  }

  /**
   * Deletar um item específico dentro de foundItems
   */
  async deleteFoundItem(jobId: number, itemId: string): Promise<{ success: boolean; message: string }> {
    try {
      // Buscar o job
      const job = await this.getDataScanJob(jobId);
      if (!job) {
        return { success: false, message: 'Job não encontrado' };
      }

      // Verificar se foundItems existe e é array
      const foundItems = job.foundItems as any[] | undefined;
      if (!foundItems || !Array.isArray(foundItems)) {
        return { success: false, message: 'Nenhum item encontrado neste job' };
      }

      // Procurar o item pelo ID
      const itemIndex = foundItems.findIndex((item: any) => item.id === itemId);
      if (itemIndex === -1) {
        return { success: false, message: 'Item não encontrado' };
      }

      // Remover o item
      const updatedFoundItems = foundItems.filter((item: any) => item.id !== itemId);

      // Atualizar stats
      const currentStats = (job.stats as any) || {};
      const updatedStats = {
        ...currentStats,
        totalDataItems: updatedFoundItems.length
      };

      // Atualizar o job no banco
      await db.update(dataScanJobs)
        .set({
          foundItems: updatedFoundItems,
          stats: updatedStats,
          updatedAt: new Date()
        })
        .where(eq(dataScanJobs.id, jobId));

      return {
        success: true,
        message: `Item deletado com sucesso. ${updatedFoundItems.length} itens restantes.`
      };

    } catch (error) {
      console.error('[ScanDataModuleService] Erro ao deletar found item:', error);
      return {
        success: false,
        message: (error as Error).message || 'Erro ao deletar item'
      };
    }
  }
}
