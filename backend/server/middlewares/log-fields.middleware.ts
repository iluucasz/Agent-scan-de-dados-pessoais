import { Request, Response, NextFunction } from 'express';

// Middleware simples para logar campos recebidos
export const logFieldNames = (req: Request, res: Response, next: NextFunction) => {
  // Interceptar req.files e req.body após o processamento do Multer
  const originalSend = res.send;
  res.send = function(body) {
    return originalSend.call(this, body);
  };
  
  next();
};
