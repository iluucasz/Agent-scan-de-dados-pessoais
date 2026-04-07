/**
 * Middleware para processar resultados de upload com arquivos rejeitados
 * Coleta informações sobre arquivos aceitos e rejeitados para relatório
 */

import { Request, Response, NextFunction } from 'express';

// Interface para estatísticas de upload
interface UploadStats {
  totalFiles: number;
  acceptedFiles: number;
  rejectedFiles: number;
  rejectedDetails: Array<{
    filename: string;
    mimetype: string;
    reason: string;
  }>;
}

// Armazenar estatísticas temporariamente
const uploadStatsMap = new Map<string, UploadStats>();

/**
 * Middleware para coletar estatísticas de upload
 */
export function collectUploadStats(req: Request, res: Response, next: NextFunction) {
  const requestId = `${Date.now()}-${Math.random()}`;
  
  // Inicializar estatísticas
  const stats: UploadStats = {
    totalFiles: 0,
    acceptedFiles: 0,
    rejectedFiles: 0,
    rejectedDetails: []
  };
  
  // Anexar estatísticas ao request
  (req as any).uploadStats = stats;
  (req as any).requestId = requestId;
  uploadStatsMap.set(requestId, stats);
  
  // Não interceptar res.end() para evitar problemas de serialização
  // As estatísticas serão adicionadas diretamente no controller
  
  next();
}

/**
 * Função para obter estatísticas de upload do request
 */
export function getUploadStats(req: Request): any {
  const stats = (req as any).uploadStats as UploadStats;
  const files = req.files as Express.Multer.File[];
  
  if (files && Array.isArray(files)) {
    stats.acceptedFiles = files.length;
    stats.totalFiles = stats.acceptedFiles + stats.rejectedFiles;
  }
  
  return {
    totalAttempted: stats.totalFiles,
    successfulUploads: stats.acceptedFiles,
    rejectedUploads: stats.rejectedFiles,
    successRate: stats.totalFiles > 0 ? `${((stats.acceptedFiles / stats.totalFiles) * 100).toFixed(1)}%` : '0%',
    rejectedFiles: stats.rejectedDetails
  };
}

/**
 * Função para obter warnings se houver arquivos rejeitados
 */
export function getUploadWarnings(req: Request): string[] | undefined {
  const stats = (req as any).uploadStats as UploadStats;
  
  if (stats.rejectedFiles > 0) {
    return [
      `${stats.rejectedFiles} arquivo(s) foram ignorados por formato não suportado.`,
      'Verifique a documentação para formatos aceitos.',
      'Arquivos válidos foram processados normalmente.'
    ];
  }
  
  return undefined;
}

/**
 * Função para registrar arquivo rejeitado
 */
export function logRejectedFile(filename: string, mimetype: string, reason: string, requestId?: string) {
  // Prefer exact requestId match
  if (requestId && uploadStatsMap.has(requestId)) {
    const stats = uploadStatsMap.get(requestId)!;
    stats.rejectedFiles++;
    stats.rejectedDetails.push({ filename, mimetype, reason });
    console.log(`📊 [UPLOAD-STATS] Arquivo rejeitado registrado: ${filename} (${stats.rejectedFiles} total)`);
    return;
  }

  // Fallback: update the most recent stats entry
  const lastEntry = Array.from(uploadStatsMap.values()).pop();
  if (lastEntry) {
    lastEntry.rejectedFiles++;
    lastEntry.rejectedDetails.push({ filename, mimetype, reason });
    console.log(`📊 [UPLOAD-STATS] Arquivo rejeitado registrado (fallback): ${filename} (${lastEntry.rejectedFiles} total)`);
  }
}
