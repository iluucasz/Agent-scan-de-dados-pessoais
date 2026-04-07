import { Request, Response } from 'express';
import { ZodError } from 'zod';
import { AreasService } from '../services/areas.service';
import { insertAreaSchema, updateAreaSchema } from '../../schemas/areas.schema';

export class AreasController {
  constructor(private areasService: AreasService) {}

  async list(req: Request, res: Response): Promise<Response> {
    try {
      const session = req.user as any;
      if (session?.role === 'admin') {
        const areas = await this.areasService.list();
        return res.json(areas);
      }
      // Gestor e demais perfis: listar somente da própria organização
  const orgId = (req as any).orgScope?.currentOrganizationId ?? session?.organizationId;
      const areas = await this.areasService.findByOrganization(orgId);
      return res.json(areas);
    } catch (error) {
      console.error('[Areas] Erro ao listar áreas:', error);
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async create(req: Request, res: Response): Promise<Response> {
    try {
      // Verificar se é admin ou gestor
      const session = req.user as any;
      if (session?.role !== 'admin' && session?.role !== 'gestor') {
        return res.status(403).json({ message: 'Apenas administradores e gestores podem criar áreas' });
      }

      const { organizationId } = req.params;
      const areaData = insertAreaSchema.parse({
        ...req.body,
        organizationId: parseInt(organizationId),
        createdBy: req.user?.id
      });

      const area = await this.areasService.create(areaData);
      return res.status(201).json(area);
    } catch (error) {
      console.error('[Areas] Erro ao criar área:', error);
      if (error instanceof ZodError) {
        return res.status(400).json({
          message: 'Erro de validação',
          errors: error.errors.map(e => ({ path: e.path.join('.'), message: e.message }))
        });
      }
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async listByOrganization(req: Request, res: Response): Promise<Response> {
    try {
      const { organizationId } = req.params;
      const orgId = parseInt(organizationId);
      
      if (isNaN(orgId) || orgId <= 0) {
        return res.status(400).json({ message: 'ID de organização inválido' });
      }
  const session = req.user as any;
  const currentOrgId = (req as any).orgScope?.currentOrganizationId ?? session?.organizationId;
  if (session?.role !== 'admin' && currentOrgId !== orgId) {
        return res.status(403).json({ message: 'Proibido: acesso a outra organização' });
      }

      const areas = await this.areasService.findByOrganization(orgId);
      return res.json(areas);
    } catch (error) {
      console.error('[Areas] Erro ao listar áreas por organização:', error);
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async getById(req: Request, res: Response): Promise<Response> {
    try {
      const { id } = req.params;
      const areaId = parseInt(id);
      
      if (isNaN(areaId) || areaId <= 0) {
        return res.status(400).json({ message: 'ID de área inválido' });
      }

      const area = await this.areasService.getById(areaId);
      return res.json(area);
    } catch (error) {
      console.error('[Areas] Erro ao buscar área:', error);
      if ((error as Error).message.includes('Área não encontrada')) {
        return res.status(404).json({ message: (error as Error).message });
      }
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async update(req: Request, res: Response): Promise<Response> {
    try {
      // Verificar se é admin ou gestor
      const session = req.user as any;
      if (session?.role !== 'admin' && session?.role !== 'gestor') {
        return res.status(403).json({ message: 'Apenas administradores e gestores podem atualizar áreas' });
      }

      const { id } = req.params;
      const areaId = parseInt(id);
      const areaData = updateAreaSchema.parse(req.body);

      const area = await this.areasService.update(areaId, areaData);
      return res.json(area);
    } catch (error) {
      console.error('[Areas] Erro ao atualizar área:', error);
      if (error instanceof ZodError) {
        return res.status(400).json({
          message: 'Erro de validação',
          errors: error.errors.map(e => ({ path: e.path.join('.'), message: e.message }))
        });
      }
      if ((error as Error).message.includes('Área não encontrada')) {
        return res.status(404).json({ message: (error as Error).message });
      }
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async delete(req: Request, res: Response): Promise<Response> {
    try {
      // Verificar se é admin ou gestor
      const session = req.user as any;
      if (session?.role !== 'admin' && session?.role !== 'gestor') {
        return res.status(403).json({ message: 'Apenas administradores e gestores podem deletar áreas' });
      }

      const { id } = req.params;
      const areaId = parseInt(id);
      const cascade = req.query.cascade === 'true';
      
      if (isNaN(areaId) || areaId <= 0) {
        return res.status(400).json({ message: 'ID de área inválido' });
      }

      await this.areasService.delete(areaId, cascade);
      return res.status(204).send();
    } catch (error) {
      console.error('[Areas] Erro ao deletar área:', error);
      if ((error as Error).message.includes('sub-área')) {
        return res.status(409).json({ message: (error as Error).message });
      }
      if ((error as Error).message.includes('Área não encontrada')) {
        return res.status(404).json({ message: (error as Error).message });
      }
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async getAreasWithProcessos(req: Request, res: Response): Promise<Response> {
    try {
      const { organizationId } = req.params;
      const orgId = parseInt(organizationId);
      const session = req.user as any;
  const currentOrgId = (req as any).orgScope?.currentOrganizationId ?? session?.organizationId;
  if (session?.role !== 'admin' && currentOrgId !== orgId) {
        return res.status(403).json({ message: 'Proibido: acesso a outra organização' });
      }
      
      const data = await this.areasService.getAreasWithProcessos(orgId);
      return res.json(data);
    } catch (error) {
      console.error('[Areas] Erro ao buscar áreas com processos:', error);
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  // ========================================
  // NOVOS MÉTODOS (hierarquia)
  // ========================================

  /**
   * GET /api/organizations/:organizationId/areas/tree
   * Retorna árvore hierárquica de áreas
   */
  async getTree(req: Request, res: Response): Promise<Response> {
    try {
      const { organizationId } = req.params;
      const orgId = parseInt(organizationId);
      
      if (isNaN(orgId) || orgId <= 0) {
        return res.status(400).json({ message: 'ID de organização inválido' });
      }

      const tree = await this.areasService.getAreaTree(orgId);
      return res.json(tree);
    } catch (error) {
      console.error('[Areas] Erro ao buscar árvore:', error);
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  /**
   * GET /api/organizations/:organizationId/areas/roots
   * Retorna apenas áreas raiz (sem pai)
   */
  async getRoots(req: Request, res: Response): Promise<Response> {
    try {
      const { organizationId } = req.params;
      const orgId = parseInt(organizationId);
      
      if (isNaN(orgId) || orgId <= 0) {
        return res.status(400).json({ message: 'ID de organização inválido' });
      }

      const roots = await this.areasService.getRootAreas(orgId);
      return res.json(roots);
    } catch (error) {
      console.error('[Areas] Erro ao buscar áreas raiz:', error);
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  /**
   * GET /api/areas/:id/path
   * Retorna caminho completo (breadcrumb) de uma área
   */
  async getPath(req: Request, res: Response): Promise<Response> {
    try {
      const { id } = req.params;
      const areaId = parseInt(id);
      
      if (isNaN(areaId) || areaId <= 0) {
        return res.status(400).json({ message: 'ID de área inválido' });
      }

      const path = await this.areasService.getAreaPath(areaId);
      return res.json(path);
    } catch (error) {
      console.error('[Areas] Erro ao buscar caminho:', error);
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  /**
   * GET /api/areas/:id/children
   * Retorna áreas filhas diretas
   */
  async getChildren(req: Request, res: Response): Promise<Response> {
    try {
      const { id } = req.params;
      const areaId = parseInt(id);
      
      if (isNaN(areaId) || areaId <= 0) {
        return res.status(400).json({ message: 'ID de área inválido' });
      }

      const children = await this.areasService.getDirectChildren(areaId);
      return res.json(children);
    } catch (error) {
      console.error('[Areas] Erro ao buscar filhas:', error);
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  /**
   * GET /api/areas/:id/descendants
   * Retorna todos os descendentes (recursivo)
   */
  async getDescendants(req: Request, res: Response): Promise<Response> {
    try {
      const { id } = req.params;
      const areaId = parseInt(id);
      
      if (isNaN(areaId) || areaId <= 0) {
        return res.status(400).json({ message: 'ID de área inválido' });
      }

      const descendants = await this.areasService.getDescendants(areaId);
      return res.json(descendants);
    } catch (error) {
      console.error('[Areas] Erro ao buscar descendentes:', error);
      return res.status(500).json({ message: (error as Error).message });
    }
  }
}
