import { Request, Response, NextFunction } from 'express';

// Middleware temporário para debugar campos do FormData
export const debugFields = (req: Request, res: Response, next: NextFunction) => {
  console.log('🔍 [DEBUG] === ANÁLISE DE CAMPOS MULTIPART ===');
  console.log('🔍 [DEBUG] Content-Type:', req.headers['content-type']);
  console.log('🔍 [DEBUG] Method:', req.method);
  console.log('🔍 [DEBUG] URL:', req.url);
  
  // Interceptar o processamento do multipart para ver quais campos chegam
  const originalPush = req.push;
  if (originalPush) {
    req.push = function(chunk: any) {
      if (chunk && chunk.toString) {
        const chunkStr = chunk.toString();
        if (chunkStr.includes('Content-Disposition: form-data')) {
          console.log('🔍 [DEBUG] Campo detectado:', chunkStr.substring(0, 200));
        }
      }
      return originalPush.call(this, chunk);
    };
  }
  
  next();
};
