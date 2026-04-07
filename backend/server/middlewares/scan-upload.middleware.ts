import multer from 'multer';
import { FileSanitizer } from '../utils/file-sanitizer.util';
import { logRejectedFile } from './upload-stats.middleware';

// Configuração otimizada do Multer para upload DIRETO
// Usando memoryStorage para manter arquivos em buffer e fazer upload direto para DigitalOcean
// Sem armazenamento em disco - evita sobrecarga do servidor
// SEM LIMITE de quantidade de arquivos (limitado apenas pelo cliente)
const scanDataStorage = multer.memoryStorage();

export const uploadScanData = multer({
  storage: scanDataStorage,
  limits: {
    fileSize: 100 * 1024 * 1024, // 100MB por arquivo
    fields: 50, // Permitir até 50 campos de texto (para campos extras)
    files: 1000, // Limite muito alto para evitar erro "Too many files"
    fieldSize: 10 * 1024 * 1024, // 10MB por campo
    parts: 1050 // Limite alto de partes para suportar muitos arquivos
  },
  fileFilter: (req, file, cb) => {

    // Sanitiza o nome do arquivo para DigitalOcean
    const sanitized = FileSanitizer.sanitizeFileName(file.originalname);
    if (sanitized.wasModified) {
      console.log('🔧 [SANITIZER] Nome do arquivo modificado:', {
        original: sanitized.originalName,
        sanitized: sanitized.sanitizedName
      });
      // Atualiza o nome do arquivo no objeto file
      file.originalname = sanitized.sanitizedName;
    }

    // Analisa problemas potenciais no nome do arquivo
    const analysis = FileSanitizer.analyzeFileName(sanitized.originalName);
    if (analysis.issues.length > 0) {
      console.log('⚠️ [SANITIZER] Problemas detectados no arquivo:', {
        filename: sanitized.originalName,
        issues: analysis.issues
      });
    }

    // IMPORTANTE: Aceitar qualquer fieldname que contenha "file" para flexibilidade
    const isFileField = file.fieldname.toLowerCase().includes('file') || 
                       file.fieldname === 'files' || 
                       file.fieldname === 'file';

    if (!isFileField) {
      // Em vez de rejeitar, aceitar mas logar
      return cb(null, true);
    }

    // Aceitar tipos de arquivo para escaneamento de dados
    const allowedTypes = [
      'text/plain',
      'text/csv', 
      'application/json',
      'application/xml',
      'text/xml',
      'application/pdf',
      'application/vnd.ms-excel',                           // Excel antigo (.xls)
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',  // Excel novo (.xlsx)
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',  // Word novo (.docx)
      'application/msword',                                 // Word antigo (.doc)
      'application/vnd.ms-word',                           // Word alternativo
      'application/zip',
      'application/x-zip-compressed',
      'application/octet-stream'                           // Fallback genérico
    ];
    
    const fileExtension = file.originalname.toLowerCase().match(/\.(txt|csv|json|xml|pdf|xls|xlsx|docx|doc|zip)$/);
    
    if (allowedTypes.includes(file.mimetype) || fileExtension) {
      cb(null, true);
    } else {
      // Registrar arquivo rejeitado para estatísticas (associado ao requestId)
      logRejectedFile(
        file.originalname,
        file.mimetype,
        `Formato não suportado. Tipos aceitos: PDF, Excel, Word (.doc/.docx), CSV, TXT, JSON, XML, ZIP`,
        (req as any).requestId
      );

      // ✅ IGNORAR arquivo inválido ao invés de gerar erro
      // Isso permite que outros arquivos válidos continuem sendo processados
      return cb(null, false);
    }
  }
});
