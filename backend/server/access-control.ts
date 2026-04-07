// @ts-nocheck
import { Request, Response, NextFunction } from 'express';
import { eq, and } from 'drizzle-orm';
// Removido import estático de db para evitar inicialização precoce antes de dotenv.
// Função helper para obter db dinamicamente quando necessário.
async function getDb() {
  const { db } = await import('./db');
  return db as any;
}
import { users } from '../schemas/users.schema';
import { accessProfiles, permissions, userProfiles } from '../schemas/schema';

// Cache de permissões de usuário para melhorar desempenho
const permissionsCache = new Map<number, string[]>();

/**
 * Middleware para verificar se o usuário está autenticado
 */
export async function isAuthenticated(req: Request, res: Response, next: NextFunction) {
  // Verificar token Bearer
  const authHeader = req.headers.authorization;
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    // Buscar usuário pelo accessToken
  const _db = await getDb();
  const [dbUser] = await _db
      .select()
      .from(users)
      .where(eq(users.accessToken, token))
      .limit(1);
    if (dbUser) {
      req.user = {
        id: dbUser.id,
        organizationId: dbUser.organizationId || 1,
        role: dbUser.role
      };
      return next();
    }
  }

  // Sem autenticação válida, negar acesso
  res.status(401).json({ message: 'Não autorizado - faça login para acessar este recurso' });
}

/**
 * Middleware para verificar se o usuário é admin
 */
export function isAdmin(req: Request, res: Response, next: NextFunction) {
  // Verificar se o usuário está autenticado (via middleware isAuthenticated ou bypass)
  if (!req.user) {
    return res.status(401).json({ message: 'Não autorizado - faça login para acessar este recurso' });
  }

  // Verificar se o usuário é admin
  if (req.user && req.user.role === 'admin') {
    return next();
  }

  res.status(403).json({ message: 'Acesso negado - você não tem permissão para acessar este recurso' });
}

/**
 * Middleware para verificar se o usuário é admin ou agente
 */
export function isAdminOrAgent(req: Request, res: Response, next: NextFunction) {
  // Primeiro verificar se está autenticado
  if (!req.isAuthenticated || !req.isAuthenticated()) {
    return res.status(401).json({ message: 'Não autorizado - faça login para acessar este recurso' });
  }

  // Verificar se o usuário é admin ou gestor (substituiu DPO)
  if (req.user && (req.user.role === 'admin' || req.user.role === 'gestor')) {
    return next();
  }

  res.status(403).json({ message: 'Acesso negado - você não tem permissão para acessar este recurso' });
}

/**
 * Middleware para verificar se o usuário é admin ou gestor
 */
export function isAdminOrDPO(req: Request, res: Response, next: NextFunction) {
  // Primeiro verificar se está autenticado
  if (!req.isAuthenticated || !req.isAuthenticated()) {
    return res.status(401).json({ message: 'Não autorizado - faça login para acessar este recurso' });
  }

  // Verificar se o usuário é admin ou gestor (substituiu DPO)
  if (req.user && (req.user.role === 'admin' || req.user.role === 'gestor')) {
    return next();
  }

  res.status(403).json({ message: 'Acesso negado - você não tem permissão para acessar este recurso' });
}

/**
 * Middleware para verificar se o usuário tem uma permissão específica
 * @param permission Código da permissão requerida
 */
export function checkPermission(permission: string) {
  return async (req: Request, res: Response, next: NextFunction) => {
    // Verificar autenticação
    if (!req.isAuthenticated || !req.isAuthenticated()) {
      return res.status(401).json({ message: 'Não autorizado - faça login para acessar este recurso' });
    }

    if (!req.user) {
      return res.status(401).json({ message: 'Usuário não encontrado na sessão' });
    }

    try {
      // Administradores têm todas as permissões automaticamente
      if (req.user.role === 'admin' || req.user.role === 'super_admin') {
        return next();
      }

      // Verificar permissões do usuário
      const userId = req.user.id;
  const userPermissions = await getUserPermissions(userId);

      if (userPermissions.includes(permission)) {
        return next();
      }

      return res.status(403).json({
        message: 'Acesso negado - você não tem permissão para acessar este recurso',
        requiredPermission: permission
      });
    } catch (error) {
      console.error(`[Auth] Erro ao verificar permissão '${permission}':`, error);
      return res.status(500).json({ message: 'Erro ao verificar permissões' });
    }
  };
}

/**
 * Cria um perfil de acesso padrão para o tipo de usuário
 * @param profileName Nome do perfil a ser criado
 * @param initialPermissions Lista de permissões iniciais
 */
export async function createDefaultAccessProfile(profileName: string, initialPermissions: string[]) {
  try {
    // Verificar se já existe um perfil com esse nome
  const _db = await getDb();
  const existingProfile = await _db.query.accessProfiles.findFirst({
      where: eq(accessProfiles.name, profileName)
    });

    if (existingProfile) {
      return existingProfile;
    }

    // Criar o perfil de acesso
  const [newProfile] = await _db.insert(accessProfiles)
      .values({
        name: profileName,
        description: `Perfil de acesso padrão para ${profileName}`,
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date()
      })
      .returning();

    // Adicionar permissões iniciais
    for (const permissionCode of initialPermissions) {
  await _db.insert(permissions)
        .values({
          accessProfileId: newProfile.id,
          permissionCode: permissionCode,
          isActive: true,
          createdAt: new Date(),
          updatedAt: new Date()
        });
    }

    return newProfile;
  } catch (error) {
    console.error(`[Auth] Erro ao criar perfil de acesso '${profileName}':`, error);
    throw new Error(`Falha ao criar perfil de acesso: ${(error as Error).message}`);
  }
}

/**
 * Atribui um perfil de acesso a um usuário
 * @param userId ID do usuário
 * @param profileId ID do perfil de acesso
 * @param assignedBy ID do usuário que está atribuindo o perfil (opcional)
 */
export async function assignAccessProfileToUser(userId: number, profileId: number, assignedBy?: number) {
  try {
    // Verificar se a atribuição já existe
  const _db = await getDb();
  const existingAssignment = await _db.query.userProfiles.findFirst({
      where: and(
        eq(userProfiles.userId, userId),
        eq(userProfiles.accessProfileId, profileId)
      )
    });

    if (existingAssignment) {
      return existingAssignment;
    }

    // Criar a atribuição
  const [assignment] = await _db.insert(userProfiles)
      .values({
        userId,
        accessProfileId: profileId,
        assignedBy: assignedBy || null,
        assignedAt: new Date(),
        isPrimary: false // Por padrão, não é o perfil primário
      })
      .returning();

    // Limpar o cache de permissões do usuário
    clearUserPermissionsCache(userId);

    return assignment;
  } catch (error) {
    console.error(`[Auth] Erro ao atribuir perfil de acesso ao usuário ${userId}:`, error);
    throw new Error(`Falha ao atribuir perfil de acesso: ${(error as Error).message}`);
  }
}

/**
 * Remove um perfil de acesso de um usuário
 * @param userId ID do usuário
 * @param profileId ID do perfil de acesso
 */
export async function removeAccessProfileFromUser(userId: number, profileId: number) {
  try {
  const _db = await getDb();
  await _db.delete(userProfiles)
      .where(
        and(
          eq(userProfiles.userId, userId),
          eq(userProfiles.accessProfileId, profileId)
        )
      );

    // Limpar o cache de permissões do usuário
    clearUserPermissionsCache(userId);

    return true;
  } catch (error) {
    console.error(`[Auth] Erro ao remover perfil de acesso do usuário ${userId}:`, error);
    throw new Error(`Falha ao remover perfil de acesso: ${(error as Error).message}`);
  }
}

/**
 * Obtém todos os perfis de acesso de um usuário
 * @param userId ID do usuário
 */
export async function getUserAccessProfiles(userId: number) {
  try {
    // Buscar todas as relações userProfile do usuário
  const _db = await getDb();
  const userProfileRelations = await _db.query.userProfiles.findMany({
      where: eq(userProfiles.userId, userId),
      with: {
        accessProfile: true
      }
    });

    // Extrair os perfis de acesso
    return userProfileRelations.map(relation => relation.accessProfile);
  } catch (error) {
    console.error(`[Auth] Erro ao buscar perfis de acesso do usuário ${userId}:`, error);
    throw new Error(`Falha ao buscar perfis de acesso: ${(error as Error).message}`);
  }
}

/**
 * Obtém todas as permissões de um usuário
 * @param userId ID do usuário
 */
export async function getUserPermissions(userId: number): Promise<string[]> {
  try {
    // Verificar cache primeiro
    if (permissionsCache.has(userId)) {
      return permissionsCache.get(userId) || [];
    }

    // Buscar o usuário para verificar o papel
  const _db = await getDb();
  const user = await _db.query.users.findFirst({
      where: eq(users.id, userId)
    });

    if (!user) {
      throw new Error(`Usuário com ID ${userId} não encontrado`);
    }

    // Administradores têm todas as permissões
    if (user.role === 'admin' || user.role === 'super_admin') {
      // Buscar todas as permissões existentes
  const allPermissions = await _db.query.permissions.findMany();
      const permissionCodes = allPermissions.map(p => p.permissionCode);

      // Armazenar no cache
      permissionsCache.set(userId, permissionCodes);
      return permissionCodes;
    }

    // Para outros usuários, buscar permissões dos perfis atribuídos
  const userPermissions = await _db
      .select({ permissionCode: permissions.permissionCode })
      .from(userProfiles)
      .innerJoin(accessProfiles, eq(userProfiles.accessProfileId, accessProfiles.id))
      .innerJoin(permissions, eq(accessProfiles.id, permissions.accessProfileId))
      .where(
        and(
          eq(userProfiles.userId, userId),
          eq(permissions.isActive, true),
          eq(accessProfiles.isActive, true)
        )
      );

    const permissionCodes = userPermissions.map(p => p.permissionCode);

    // Armazenar no cache
    permissionsCache.set(userId, permissionCodes);
    return permissionCodes;
  } catch (error) {
    console.error(`[Auth] Erro ao buscar permissões do usuário ${userId}:`, error);
    return [];
  }
}

/**
 * Limpa o cache de permissões de um usuário
 * @param userId ID do usuário
 */
export function clearUserPermissionsCache(userId: number) {
  permissionsCache.delete(userId);
}