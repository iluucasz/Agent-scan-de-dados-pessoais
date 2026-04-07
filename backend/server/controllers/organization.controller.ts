import { Request, Response } from "express";
import { ZodError } from "zod";
import { insertOrganizationSchema, updateOrganizationSchema } from "../../schemas/organization.schema";
import { OrganizationService } from "../services/organization.service";

export class OrganizationController {
  constructor(private organizationService: OrganizationService) {}

  async list(req: Request, res: Response): Promise<Response> {
    try {
      const orgs = await this.organizationService.list();
      const role = req.user?.role;
      const baseOrgId = req.user?.organizationId;
      const scope = (req as any).orgScope as { allowedOrgIds: number[] | null } | undefined;

      if (role === 'admin' || scope?.allowedOrgIds === null) {
        return res.json(orgs);
      }

      // allowedOrgIds pode vir do middleware para gestor/cliente
      const allowed = new Set<number>(scope?.allowedOrgIds ?? (baseOrgId ? [baseOrgId] : []));
      if (allowed.size === 0) {
        return res.status(403).json({ message: 'Usuário sem organização atribuída' });
      }
      return res.json(orgs.filter(o => allowed.has(o.id)));
    } catch (error) {
      console.error('[Organization] Erro ao listar organizações:', error);
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async getById(req: Request, res: Response): Promise<Response> {
    try {
      const id = parseInt(req.params.id);
      if (isNaN(id) || id <= 0) {
        return res.status(400).json({ message: 'ID de organização inválido', code: 'INVALID_ORG_ID' });
      }
      const org = await this.organizationService.getById(id);
      return res.json(org);
    } catch (error) {
      console.error('[Organization] Erro ao buscar organização:', error);
      return res.status(404).json({ message: (error as Error).message });
    }
  }

  async create(req: Request, res: Response): Promise<Response> {
    try {
      const data = insertOrganizationSchema.parse(req.body);
      const org = await this.organizationService.create(data);
      return res.status(201).json(org);
    } catch (error) {
      console.error('[Organization] Erro ao criar organização:', error);
      if (error instanceof ZodError) {
        return res.status(400).json({
          message: 'Erro de validação',
          errors: error.errors.map(e => ({ path: e.path.join('.'), message: e.message }))
        });
      }
      return res.status(400).json({ message: (error as Error).message });
    }
  }

  async update(req: Request, res: Response): Promise<Response> {
    try {
      const id = parseInt(req.params.id);
      const data = updateOrganizationSchema.parse(req.body);
      const org = await this.organizationService.update(id, data);
      return res.json(org);
    } catch (error) {
      console.error('[Organization] Erro ao atualizar organização:', error);
      if (error instanceof ZodError) {
        return res.status(400).json({
          message: 'Erro de validação',
          errors: error.errors.map(e => ({ path: e.path.join('.'), message: e.message }))
        });
      }
      if ((error as Error).message.includes('Organização não encontrada')) {
        return res.status(404).json({ message: (error as Error).message });
      }
      return res.status(400).json({ message: (error as Error).message });
    }
  }

  async delete(req: Request, res: Response): Promise<Response> {
    try {
      const id = parseInt(req.params.id);
      await this.organizationService.delete(id);
      return res.status(204).send();
    } catch (error) {
      console.error('[Organization] Erro ao remover organização:', error);
      if ((error as Error).message.includes('Organização não encontrada')) {
        return res.status(404).send();
      }
      return res.status(400).json({ message: (error as Error).message });
    }
  }

  async switchActive(req: Request, res: Response): Promise<Response> {
    try {
      const session = req.user!;
  const scope = (req as any).orgScope as { allowedOrgIds: number[] | null } | undefined;
      const { organizationId } = req.body || {};
      const orgId = parseInt(String(organizationId), 10);
      if (!orgId || Number.isNaN(orgId)) {
        return res.status(400).json({ message: 'organizationId inválido' });
      }

      // admin allowedOrgIds=null → sem restrição, senão precisa conter
      if (scope && scope.allowedOrgIds !== null) {
        if (!scope.allowedOrgIds?.includes(orgId)) {
          return res.status(403).json({ message: 'Você não tem acesso a esta organização' });
        }
      }

  // garantir que a org existe
  const organization = await this.organizationService.getById(orgId);

      // persistir no usuário
  const updated = await this.organizationService.setCurrentOrganization(session.id, orgId);

  // Montar snapshot de escopo atualizado (allowed mantém a mesma regra do middleware)
      const role = (session as any).role as string | undefined;
      let allowedForSnapshot: number[] | null = null;
      if (role === 'admin') {
        allowedForSnapshot = null;
      } else if (role === 'gestor') {
        // gestor mantém o conjunto gerenciado (do middleware)
        allowedForSnapshot = scope?.allowedOrgIds ?? [];
      } else {
        // cliente restrito à org atual
        allowedForSnapshot = [updated.currentOrganizationId];
      }

      const updatedScope = {
        currentOrganizationId: updated.currentOrganizationId,
        allowedOrgIds: allowedForSnapshot,
      };

  return res.json({
    success: true,
    // backward-compat fields
    currentOrganizationId: updated.currentOrganizationId,
    // new snapshot payload
    orgScope: updatedScope,
    organization,
  });
    } catch (error) {
      console.error('[Organization] Erro no switch de organização:', error);
      if ((error as Error).message.includes('Organização não encontrada')) {
        return res.status(404).json({ message: 'Organização não encontrada' });
      }
      return res.status(400).json({ message: (error as Error).message });
    }
  }
} 