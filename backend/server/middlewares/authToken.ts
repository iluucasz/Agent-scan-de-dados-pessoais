import { NextFunction, Request, Response } from 'express';
import { verifyToken } from '../utils/jwt';

export function authToken(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Token de autenticação ausente' });
  }
  const token = authHeader.slice(7);
  try {
    const payload = verifyToken(token);
    req.user = {
      id: payload.id,
      organizationId: payload.organizationId,
      role: payload.role
    };
    next();
  } catch (err) {
    return res.status(401).json({ message: 'Token inválido ou expirado' });
  }
} 