/**
 * Rotas para gerenciamento de controle de acesso e permissões
 */

import { and, eq } from 'drizzle-orm';
import { Request, Router } from 'express';
import { db } from '../db';

import {
  assignAccessProfileToUser,
  clearUserPermissionsCache,
  createDefaultAccessProfile,
  getUserAccessProfiles,
  getUserPermissions,
  isAdmin,
  isAdminOrAgent,
  isAuthenticated,
  removeAccessProfileFromUser
} from '../access-control';

// Importar tabelas e schemas do Drizzle
import {
  accessProfiles,
  insertAccessProfileSchema,
  insertPermissionSchema,
  permissions,
  userProfiles
} from '../../schemas/schema';
import { users } from '../../schemas/users.schema';

// Helper para extrair dados do usuário autenticado
function getAuth(req: Request) {
  const { id, organizationId, role } = req.user as any;
  return { userId: id, organizationId, userRole: role };
}

const router = Router();

// Obter todos os perfis de acesso (apenas admin e agente)
router.get('/profiles', isAuthenticated, isAdminOrAgent, async (req, res) => {
  try {
    const { organizationId } = getAuth(req);
    
    if (!organizationId) {
      return res.status(400).json({ message: 'ID da organização não encontrado na sessão' });
    }
    
    const profiles = await db.select()
      .from(accessProfiles)
      .where(eq(accessProfiles.organizationId, organizationId));
      
    return res.json(profiles);
  } catch (error) {
    console.error('Erro ao obter perfis de acesso:', error);
    return res.status(500).json({ message: 'Erro ao obter perfis de acesso' });
  }
});

// Criar novo perfil de acesso
router.post('/profiles', isAuthenticated, isAdmin, async (req, res) => {
  try {
    const { organizationId, userId } = getAuth(req);
    
    if (!organizationId || !userId) {
      return res.status(400).json({ message: 'Dados da sessão incompletos' });
    }
    
    // Validar dados de entrada
    const validatedData = insertAccessProfileSchema.parse({
      ...req.body,
      organizationId,
      createdBy: userId
    });
    
    // Criar perfil
    const [profile] = await db.insert(accessProfiles)
      .values(validatedData)
      .returning();
      
    return res.status(201).json(profile);
  } catch (error) {
    console.error('Erro ao criar perfil de acesso:', error);
    return res.status(500).json({ message: 'Erro ao criar perfil de acesso' });
  }
});

// Obter perfil específico
router.get('/profiles/:id', isAuthenticated, isAdminOrAgent, async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { organizationId, userId } = getAuth(req);
    
    if (!organizationId) {
      return res.status(400).json({ message: 'ID da organização não encontrado na sessão' });
    }
    
    // Buscar perfil
    const [profile] = await db.select()
      .from(accessProfiles)
      .where(
        and(
          eq(accessProfiles.id, profileId),
          eq(accessProfiles.organizationId, organizationId)
        )
      );
      
    if (!profile) {
      return res.status(404).json({ message: 'Perfil de acesso não encontrado' });
    }
    
    // Buscar permissões do perfil
    const permissionsList = await db.select()
      .from(permissions)
      .where(eq(permissions.profileId, profileId));
      
    return res.json({
      ...profile,
      permissions: permissionsList
    });
  } catch (error) {
    console.error('Erro ao obter perfil de acesso:', error);
    return res.status(500).json({ message: 'Erro ao obter perfil de acesso' });
  }
});

// Atualizar perfil
router.put('/profiles/:id', isAuthenticated, isAdmin, async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { organizationId } = getAuth(req);
    
    if (!organizationId) {
      return res.status(400).json({ message: 'ID da organização não encontrado na sessão' });
    }
    
    // Verificar se perfil existe
    const [existingProfile] = await db.select()
      .from(accessProfiles)
      .where(
        and(
          eq(accessProfiles.id, profileId),
          eq(accessProfiles.organizationId, organizationId)
        )
      );
      
    if (!existingProfile) {
      return res.status(404).json({ message: 'Perfil de acesso não encontrado' });
    }
    
    // Atualizar perfil
    const [updatedProfile] = await db.update(accessProfiles)
      .set({
        name: req.body.name || existingProfile.name,
        description: req.body.description || existingProfile.description,
        isDefault: req.body.isDefault !== undefined ? req.body.isDefault : existingProfile.isDefault,
      })
      .where(eq(accessProfiles.id, profileId))
      .returning();
      
    return res.json(updatedProfile);
  } catch (error) {
    console.error('Erro ao atualizar perfil de acesso:', error);
    return res.status(500).json({ message: 'Erro ao atualizar perfil de acesso' });
  }
});

// Excluir perfil
router.delete('/profiles/:id', isAuthenticated, isAdmin, async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { organizationId } = getAuth(req);
    
    if (!organizationId) {
      return res.status(400).json({ message: 'ID da organização não encontrado na sessão' });
    }
    
    // Verificar se perfil existe
    const [existingProfile] = await db.select()
      .from(accessProfiles)
      .where(
        and(
          eq(accessProfiles.id, profileId),
          eq(accessProfiles.organizationId, organizationId)
        )
      );
      
    if (!existingProfile) {
      return res.status(404).json({ message: 'Perfil de acesso não encontrado' });
    }
    
    // Verificar se é um perfil padrão, que não pode ser excluído
    if (existingProfile.isDefault) {
      return res.status(400).json({ message: 'Perfis padrão não podem ser excluídos' });
    }
    
    // Remover permissões do perfil
    await db.delete(permissions)
      .where(eq(permissions.profileId, profileId));
      
    // Remover atribuições do perfil a usuários
    await db.delete(userProfiles)
      .where(eq(userProfiles.profileId, profileId));
      
    // Excluir perfil
    await db.delete(accessProfiles)
      .where(eq(accessProfiles.id, profileId));
      
    // Limpar cache de permissões de todos os usuários
    clearUserPermissionsCache(0);
      
    return res.status(204).send();
  } catch (error) {
    console.error('Erro ao excluir perfil de acesso:', error);
    return res.status(500).json({ message: 'Erro ao excluir perfil de acesso' });
  }
});

// Adicionar permissão a um perfil
router.post('/profiles/:id/permissions', isAuthenticated, isAdmin, async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { organizationId } = getAuth(req);
    
    if (!organizationId) {
      return res.status(400).json({ message: 'ID da organização não encontrado na sessão' });
    }
    
    // Verificar se perfil existe
    const [existingProfile] = await db.select()
      .from(accessProfiles)
      .where(
        and(
          eq(accessProfiles.id, profileId),
          eq(accessProfiles.organizationId, organizationId)
        )
      );
      
    if (!existingProfile) {
      return res.status(404).json({ message: 'Perfil de acesso não encontrado' });
    }
    
    // Validar dados de entrada
    const validatedData = insertPermissionSchema.parse({
      ...req.body,
      profileId
    });
    
    // Verificar se permissão já existe
    const [existingPermission] = await db.select()
      .from(permissions)
      .where(
        and(
          eq(permissions.profileId, profileId),
          eq(permissions.resourceType, validatedData.resourceType),
          eq(permissions.action, validatedData.action)
        )
      );
      
    if (existingPermission) {
      return res.status(400).json({ message: 'Esta permissão já existe para este perfil' });
    }
    
    // Criar permissão
    const [permission] = await db.insert(permissions)
      .values(validatedData)
      .returning();
      
    // Limpar cache de permissões
    clearUserPermissionsCache(0);
      
    return res.status(201).json(permission);
  } catch (error) {
    console.error('Erro ao adicionar permissão:', error);
    return res.status(500).json({ message: 'Erro ao adicionar permissão' });
  }
});

// Remover permissão de um perfil
router.delete('/profiles/:profileId/permissions/:permissionId', isAuthenticated, isAdmin, async (req, res) => {
  try {
    const profileId = parseInt(req.params.profileId);
    const permissionId = parseInt(req.params.permissionId);
    const { organizationId } = getAuth(req);
    
    if (!organizationId) {
      return res.status(400).json({ message: 'ID da organização não encontrado na sessão' });
    }
    
    // Verificar se perfil existe
    const [existingProfile] = await db.select()
      .from(accessProfiles)
      .where(
        and(
          eq(accessProfiles.id, profileId),
          eq(accessProfiles.organizationId, organizationId)
        )
      );
      
    if (!existingProfile) {
      return res.status(404).json({ message: 'Perfil de acesso não encontrado' });
    }
    
    // Verificar se permissão existe
    const [existingPermission] = await db.select()
      .from(permissions)
      .where(
        and(
          eq(permissions.id, permissionId),
          eq(permissions.profileId, profileId)
        )
      );
      
    if (!existingPermission) {
      return res.status(404).json({ message: 'Permissão não encontrada' });
    }
    
    // Remover permissão
    await db.delete(permissions)
      .where(eq(permissions.id, permissionId));
      
    // Limpar cache de permissões
    clearUserPermissionsCache(0);
      
    return res.status(204).send();
  } catch (error) {
    console.error('Erro ao remover permissão:', error);
    return res.status(500).json({ message: 'Erro ao remover permissão' });
  }
});

// Obter perfis de acesso de um usuário
router.get('/users/:userId/profiles', isAuthenticated, isAdminOrAgent, async (req, res) => {
  try {
    const userId = req.params.userId;
    const { organizationId, userId: currentUserId, userRole } = getAuth(req);
    
    if (!organizationId || !currentUserId) {
      return res.status(400).json({ message: 'Dados da sessão incompletos' });
    }
    
    // Verificar se é o próprio usuário ou um admin/agente
    if (userId !== currentUserId && userRole !== 'admin' && userRole !== 'agent') {
      return res.status(403).json({ message: 'Acesso negado' });
    }
    
    // Verificar se usuário existe
    const [user] = await db.select()
      .from(users)
      .where(
        and(
          eq(users.id, userId),
          eq(users.organizationId, organizationId)
        )
      );
      
    if (!user) {
      return res.status(404).json({ message: 'Usuário não encontrado' });
    }
    
    // Obter perfis do usuário
    const profiles = await getUserAccessProfiles(parseInt(userId));
    
    return res.json(profiles);
  } catch (error) {
    console.error('Erro ao obter perfis do usuário:', error);
    return res.status(500).json({ message: 'Erro ao obter perfis do usuário' });
  }
});

// Atribuir perfil a um usuário
router.post('/users/:userId/profiles', isAuthenticated, isAdmin, async (req, res) => {
  try {
    const userId = req.params.userId;
    const { organizationId, userId: currentUserId, userRole } = getAuth(req);
    
    if (!organizationId || !currentUserId) {
      return res.status(400).json({ message: 'Dados da sessão incompletos' });
    }
    
    // Verificar se usuário existe
    const [user] = await db.select()
      .from(users)
      .where(
        and(
          eq(users.id, userId),
          eq(users.organizationId, organizationId)
        )
      );
      
    if (!user) {
      return res.status(404).json({ message: 'Usuário não encontrado' });
    }
    
    // Validar dados de entrada
    const { profileId } = req.body;
    
    if (!profileId) {
      return res.status(400).json({ message: 'ID do perfil é obrigatório' });
    }
    
    // Verificar se perfil existe
    const [profile] = await db.select()
      .from(accessProfiles)
      .where(
        and(
          eq(accessProfiles.id, profileId),
          eq(accessProfiles.organizationId, organizationId)
        )
      );
      
    if (!profile) {
      return res.status(404).json({ message: 'Perfil de acesso não encontrado' });
    }
    
    // Verificar se usuário já tem esse perfil
    const [existingAssignment] = await db.select()
      .from(userProfiles)
      .where(
        and(
          eq(userProfiles.userId, userId),
          eq(userProfiles.profileId, profileId)
        )
      );
      
    if (existingAssignment) {
      return res.status(400).json({ message: 'Usuário já possui este perfil' });
    }
    
    // Atribuir perfil ao usuário
    await assignAccessProfileToUser(parseInt(userId), profileId, currentUserId);
    
    return res.status(201).json({ message: 'Perfil atribuído com sucesso' });
  } catch (error) {
    console.error('Erro ao atribuir perfil ao usuário:', error);
    return res.status(500).json({ message: 'Erro ao atribuir perfil ao usuário' });
  }
});

// Remover perfil de um usuário
router.delete('/users/:userId/profiles/:profileId', isAuthenticated, isAdmin, async (req, res) => {
  try {
    const userId = req.params.userId;
    const profileId = parseInt(req.params.profileId);
    const { organizationId, userId: currentUserId, userRole } = getAuth(req);
    
    if (!organizationId) {
      return res.status(400).json({ message: 'ID da organização não encontrado na sessão' });
    }
    
    // Verificar se usuário existe
    const [user] = await db.select()
      .from(users)
      .where(
        and(
          eq(users.id, userId),
          eq(users.organizationId, organizationId)
        )
      );
      
    if (!user) {
      return res.status(404).json({ message: 'Usuário não encontrado' });
    }
    
    // Verificar se perfil existe
    const [profile] = await db.select()
      .from(accessProfiles)
      .where(
        and(
          eq(accessProfiles.id, profileId),
          eq(accessProfiles.organizationId, organizationId)
        )
      );
      
    if (!profile) {
      return res.status(404).json({ message: 'Perfil de acesso não encontrado' });
    }
    
    // Verificar se atribuição existe
    const [assignment] = await db.select()
      .from(userProfiles)
      .where(
        and(
          eq(userProfiles.userId, userId),
          eq(userProfiles.profileId, profileId)
        )
      );
      
    if (!assignment) {
      return res.status(404).json({ message: 'Usuário não possui este perfil' });
    }
    
    // Remover perfil do usuário
    await removeAccessProfileFromUser(parseInt(userId), profileId);
    
    return res.status(204).send();
  } catch (error) {
    console.error('Erro ao remover perfil do usuário:', error);
    return res.status(500).json({ message: 'Erro ao remover perfil do usuário' });
  }
});

// Obter permissões do usuário atual
router.get('/my-permissions', isAuthenticated, async (req, res) => {
  try {
    const { organizationId, userId } = getAuth(req);
    
    if (!userId) {
      return res.status(400).json({ message: 'ID do usuário não encontrado na sessão' });
    }
    
    // Obter permissões do usuário
    const permissions = await getUserPermissions(userId);
    
    return res.json(permissions);
  } catch (error) {
    console.error('Erro ao obter permissões do usuário:', error);
    return res.status(500).json({ message: 'Erro ao obter permissões do usuário' });
  }
});

// Criar perfil padrão com base no papel (role)
router.post('/default-profile', isAuthenticated, isAdmin, async (req, res) => {
  try {
    const { role } = req.body;
    const { organizationId, userId } = getAuth(req);
    
    if (!organizationId || !userId) {
      return res.status(400).json({ message: 'Dados da sessão incompletos' });
    }
    
    if (!role || !['admin', 'agent', 'client', 'dpo'].includes(role)) {
      return res.status(400).json({ message: 'Papel (role) inválido' });
    }
    
    // Criar perfil padrão e obter o ID
    const createdProfile = await createDefaultAccessProfile(
      organizationId,
      [role] as ('admin' | 'agent' | 'client' | 'dpo')[]
    );
    const profileId = createdProfile.id;
    
    // Buscar perfil completo
    const profile = await db.select()
      .from(accessProfiles)
      .where(eq(accessProfiles.id, profileId))
      .limit(1)
      .then(rows => rows[0]);
    
    if (!profile) {
      return res.status(404).json({ message: 'Perfil não encontrado' });
    }
      
    return res.status(201).json(profile);
  } catch (error) {
    console.error('Erro ao criar perfil padrão:', error);
    return res.status(500).json({ message: 'Erro ao criar perfil padrão' });
  }
});

export default router;