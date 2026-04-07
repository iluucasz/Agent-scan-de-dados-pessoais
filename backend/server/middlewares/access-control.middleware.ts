import { Request, Response, NextFunction } from 'express';

type Role = 'admin' | 'gestor' | 'cliente';

export function requireRole(...allowed: Role[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const role = (req.user as any)?.role as Role | undefined;
    if (!role) return res.status(401).json({ message: 'Não autenticado' });
    if (!allowed.includes(role)) return res.status(403).json({ message: 'Acesso negado' });
    return next();
  };
}

export function requireAdmin() {
  return requireRole('admin');
}

export function requireOrgScope() {
  return (req: Request, res: Response, next: NextFunction) => {
    const user = (req.user as any) || {};
    if (!user?.role) return res.status(401).json({ message: 'Não autenticado' });
    if (user.role === 'admin') return next();
    const reqOrgId = Number(req.params.organizationId || req.body.organizationId || req.query.organizationId);
    if (!reqOrgId || user.organizationId !== reqOrgId) {
      return res.status(403).json({ message: 'Fora do escopo da organização' });
    }
    return next();
  };
}
