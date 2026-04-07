import { Request, Response, NextFunction } from 'express';
import { db } from '../db';
import { userManagedOrganizations } from '../../schemas/organization-membership.schema';
import { users } from '../../schemas/users.schema';
import { eq } from 'drizzle-orm';

declare global {
  namespace Express {
    interface UserOrgScope {
      currentOrganizationId?: number | null;
      managedOrganizationIds?: number[];
      allowedOrgIds?: number[] | null; // null = sem restrição (admin)
    }
    interface Request {
      orgScope?: UserOrgScope;
    }
  }
}

export async function resolveOrgScope(req: Request, res: Response, next: NextFunction) {
  try {
    const session = req.user as any;
    if (!session) return res.status(401).json({ message: 'Não autenticado' });
    const role = session.role as string;

    // Source of truth: DB current_organization_id
    let currentOrgId: number | null = null;
    try {
      if (session.id) {
        const [row] = await db
          .select({ currentOrganizationId: users.currentOrganizationId, organizationId: users.organizationId })
          .from(users)
          .where(eq(users.id, session.id));
        currentOrgId = (row?.currentOrganizationId as number | null) ?? null;
        // Back-compat fallback precedence: session.currentOrganizationId → row.organizationId → session.organizationId
        if (!currentOrgId && session.currentOrganizationId) {
          currentOrgId = session.currentOrganizationId as number;
        } else if (!currentOrgId && row?.organizationId) {
          currentOrgId = row.organizationId as number;
        } else if (!currentOrgId && session.organizationId) {
          currentOrgId = session.organizationId as number;
        }
      }
    } catch (e) {
      // If DB lookup fails, keep going with session fallback
      currentOrgId = session.currentOrganizationId || session.organizationId || null;
    }

    // managed orgs for gestor
    let managed: number[] = [];
    if (role === 'gestor' && session.id) {
      const rels = await db.select().from(userManagedOrganizations).where(eq(userManagedOrganizations.userId, session.id));
      managed = rels.map(r => r.organizationId!).filter(Boolean);
      // If user has no current org, pick the first managed as a non-persistent runtime default
      if (!currentOrgId && managed.length > 0) currentOrgId = managed[0];
    }

    let allowed: number[] | null;
    if (role === 'admin') {
      allowed = null; // sem restrição
    } else if (role === 'gestor') {
      allowed = managed;
    } else {
      allowed = currentOrgId ? [currentOrgId] : [];
    }

    req.orgScope = {
      currentOrganizationId: currentOrgId,
      managedOrganizationIds: managed,
      allowedOrgIds: allowed,
    };
    next();
  } catch (err) {
    next(err);
  }
}

export function orgScoped(options?: { source?: 'path'|'query'|'body'|'params'; key?: string; mode?: 'view'|'write' }) {
  const source = options?.source || 'query';
  const key = options?.key || 'organizationId';
  const mode = options?.mode || 'write'; // padrão: write (requer permissão)
  
  return (req: Request, res: Response, next: NextFunction) => {
    const scoped = req.orgScope;
    if (!scoped) return res.status(500).json({ message: 'Escopo organizacional não resolvido' });

    // Express armazena params em req.params; nossos usos anteriores passaram source:'path'
    const resolvedSource = source === 'path' ? 'params' : source;
    const container = (req as any)[resolvedSource];
    const value = container ? container[key] : undefined;
    const orgId = typeof value === 'string' ? parseInt(value, 10) : value;
    if (!orgId || Number.isNaN(orgId)) return res.status(400).json({ message: 'organizationId inválido' });

    const session = req.user as any;
    const role = session?.role as string;
    
    // Admin sempre tem acesso total
    if (scoped.allowedOrgIds === null) return next();
    
    // Modo VIEW: Qualquer usuário pode visualizar sua própria organização
    if (mode === 'view') {
      // Verificar se é a organização do usuário
      if (session.organizationId === orgId || session.currentOrganizationId === orgId) {
        return next();
      }
      // Se for gestor, verificar se tem acesso às orgs gerenciadas
      if (role === 'gestor' && scoped.allowedOrgIds?.includes(orgId)) {
        return next();
      }
      // Admin já passou acima, então aqui só resta negar
      return res.status(403).json({ message: 'Acesso negado para a organização alvo' });
    }
    
    // Modo WRITE: Apenas admin e gestor podem criar/editar
    if (mode === 'write') {
      // Admin já passou acima
      
      // Cliente nunca pode criar/editar
      if (role === 'cliente') {
        return res.status(403).json({ message: 'Você não tem permissão para modificar recursos desta organização' });
      }
      
      // Gestor pode editar:
      // 1. Sua própria organização (organizationId ou currentOrganizationId)
      // 2. Organizações que gerencia (managedOrganizationIds)
      if (role === 'gestor') {
        const isOwnOrg = session.organizationId === orgId || session.currentOrganizationId === orgId;
        const isManagedOrg = scoped.allowedOrgIds?.includes(orgId);
        
        if (isOwnOrg || isManagedOrg) {
          return next();
        }
        return res.status(403).json({ message: 'Acesso negado para a organização alvo' });
      }
      
      // Qualquer outro caso: negar
      return res.status(403).json({ message: 'Acesso negado para a organização alvo' });
    }
    
    next();
  };
}
