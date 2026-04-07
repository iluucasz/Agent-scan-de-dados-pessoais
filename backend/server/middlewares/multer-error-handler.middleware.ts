import { Request, Response, NextFunction } from 'express';
import { MulterError } from 'multer';

/**
 * Middleware para tratar erros do Multer de forma mais tolerante
 * Em vez de parar o processamento, continua com os arquivos que foram processados
 */
export const handleMulterErrors = (err: any, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof MulterError) {
    console.log('⚠️ [MULTER WARNING] Erro do Multer capturado:', err.code);
    console.log('📁 [MULTER WARNING] Arquivos processados até agora:', req.files ? Object.keys(req.files).length : 0);
    
    switch (err.code) {
      case 'LIMIT_FILE_COUNT':
        console.log('📊 [MULTER WARNING] Limite de arquivos atingido, mas continuando com os arquivos processados');
        // Adicionar informação sobre o warning na request
        (req as any).multerWarning = {
          type: 'LIMIT_FILE_COUNT',
          message: 'Limite de arquivos atingido, alguns arquivos podem não ter sido processados',
          filesProcessed: req.files ? (Array.isArray(req.files) ? req.files.length : Object.keys(req.files).length) : 0
        };
        break;
      
      case 'LIMIT_FILE_SIZE':
        console.log('📊 [MULTER WARNING] Arquivo muito grande encontrado, mas continuando');
        (req as any).multerWarning = {
          type: 'LIMIT_FILE_SIZE',
          message: 'Alguns arquivos foram rejeitados por serem muito grandes',
          filesProcessed: req.files ? (Array.isArray(req.files) ? req.files.length : Object.keys(req.files).length) : 0
        };
        break;
      
      case 'LIMIT_UNEXPECTED_FILE':
        console.log('📊 [MULTER WARNING] Campo inesperado encontrado, mas continuando');
        (req as any).multerWarning = {
          type: 'LIMIT_UNEXPECTED_FILE',
          message: 'Campo de arquivo inesperado encontrado',
          filesProcessed: req.files ? (Array.isArray(req.files) ? req.files.length : Object.keys(req.files).length) : 0
        };
        break;
      
      default:
        console.log('📊 [MULTER WARNING] Erro do Multer:', err.message);
        (req as any).multerWarning = {
          type: err.code || 'UNKNOWN',
          message: err.message,
          filesProcessed: req.files ? (Array.isArray(req.files) ? req.files.length : Object.keys(req.files).length) : 0
        };
    }
    
    // Continuar o processamento em vez de retornar erro
    return next();
  }
  
  // Para outros tipos de erro, continuar normalmente
  next(err);
};
