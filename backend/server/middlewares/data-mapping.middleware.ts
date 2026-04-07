import { NextFunction, Request, Response } from 'express';

export function isDataMappingAllowed(req: Request, res: Response, next: NextFunction) {
  const role = req.user?.role;
  if (role === 'admin' || role === 'gestor') {
    return next();
  }
  return res.status(403).json({ message: 'Acesso negado - sem permissão para acessar o módulo de Dados Pessoais' });
} 