import { Request, Response } from 'express';
import { ZodError } from 'zod';
import { ProcessosService } from '../services/processos.service';
import { insertProcessoSchema, updateProcessoSchema } from '../../schemas/processos.schema';

export class ProcessosController {
  constructor(private processosService: ProcessosService) {}

  async list(req: Request, res: Response): Promise<Response> {
    try {
  const session = req.user as any;
  const orgScope = (req as any).orgScope;
  if (session?.role === 'admin') {
        const processos = await this.processosService.list();
        return res.json(processos);
      }
      // Gestor e demais perfis: listar somente da própria organização
  const orgId = orgScope?.currentOrganizationId ?? session?.organizationId;
      const processos = await this.processosService.findByOrganization(orgId);
      return res.json(processos);
    } catch (error) {
      console.error('[Processos] Erro ao listar processos:', error);
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async create(req: Request, res: Response): Promise<Response> {
    try {
      // Verificar se é admin ou gestor
      const session = req.user as any;
      if (session?.role !== 'admin' && session?.role !== 'gestor') {
        return res.status(403).json({ message: 'Apenas administradores e gestores podem criar processos' });
      }

      const { areaId } = req.params;
      const orgScope = (req as any).orgScope;
      const currentOrgId = orgScope?.currentOrganizationId ?? session?.organizationId ?? null;

      // Validar/forçar organização conforme escopo
      let targetOrgId: number | null = null;
      if (session?.role === 'admin') {
        targetOrgId = typeof req.body.organizationId === 'number' ? req.body.organizationId : (currentOrgId ?? null);
      } else {
        targetOrgId = currentOrgId;
      }
      if (!targetOrgId) {
        return res.status(400).json({ message: 'Organização ativa não definida' });
      }

      // Verificar se a área pertence à organização alvo
      const { AreasService } = await import('../services/areas.service');
      const areasService = new AreasService();
      const area = await areasService.getById(parseInt(areaId));
      if (!area) return res.status(404).json({ message: 'Área não encontrada' });
      if (session?.role !== 'admin' && area.organizationId !== targetOrgId) {
        return res.status(403).json({ message: 'Proibido: área não pertence à organização ativa' });
      }

      const processoData = insertProcessoSchema.parse({
        ...req.body,
        organizationId: targetOrgId,
        areaId: parseInt(areaId),
        createdBy: req.user?.id
      });

      const processo = await this.processosService.create(processoData);
      return res.status(201).json(processo);
    } catch (error) {
      console.error('[Processos] Erro ao criar processo:', error);
      if (error instanceof ZodError) {
        return res.status(400).json({
          message: 'Erro de validação',
          errors: error.errors.map(e => ({ path: e.path.join('.'), message: e.message }))
        });
      }
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async listByArea(req: Request, res: Response): Promise<Response> {
    try {
      const { areaId } = req.params;
      const area_Id = parseInt(areaId);
      
      if (isNaN(area_Id) || area_Id <= 0) {
        return res.status(400).json({ message: 'ID de área inválido' });
      }
      // Validar escopo para não-admins: área deve pertencer à org atual
      const session = req.user as any;
      if (session?.role !== 'admin') {
        const { AreasService } = await import('../services/areas.service');
        const areasService = new AreasService();
        const area = await areasService.getById(area_Id);
        const currentOrgId = (req as any).orgScope?.currentOrganizationId ?? session?.organizationId;
        if (area.organizationId !== currentOrgId) {
          return res.status(403).json({ message: 'Proibido: área não pertence à organização ativa' });
        }
      }
      const processos = await this.processosService.findByArea(area_Id);
      return res.json(processos);
    } catch (error) {
      console.error('[Processos] Erro ao listar processos por área:', error);
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
  // orgScoped na rota já valida o acesso para não-admins

      const processos = await this.processosService.findByOrganization(orgId);
      return res.json(processos);
    } catch (error) {
      console.error('[Processos] Erro ao listar processos por organização:', error);
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async getById(req: Request, res: Response): Promise<Response> {
    try {
      const { id } = req.params;
      const processoId = parseInt(id);
      
      if (isNaN(processoId) || processoId <= 0) {
        return res.status(400).json({ message: 'ID de processo inválido' });
      }

      const processo = await this.processosService.getById(processoId);
      const session = req.user as any;
      if (session?.role !== 'admin') {
        const allowed = (req as any).orgScope?.allowedOrgIds as number[] | null | undefined;
        if (allowed && !allowed.includes(processo.organizationId)) {
          return res.status(403).json({ message: 'Proibido: acesso a outra organização' });
        }
      }
      return res.json(processo);
    } catch (error) {
      console.error('[Processos] Erro ao buscar processo:', error);
      if ((error as Error).message.includes('Processo não encontrado')) {
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
        return res.status(403).json({ message: 'Apenas administradores e gestores podem atualizar processos' });
      }

      const { id } = req.params;
      const processoId = parseInt(id);
      const processoData = updateProcessoSchema.parse(req.body);
      // validar escopo antes de atualizar
      const existing = await this.processosService.getById(processoId);
      if (session?.role !== 'admin') {
        const allowed = (req as any).orgScope?.allowedOrgIds as number[] | null | undefined;
        if (allowed && !allowed.includes(existing.organizationId)) {
          return res.status(403).json({ message: 'Proibido: acesso a outra organização' });
        }
      }

      const processo = await this.processosService.update(processoId, processoData);
      return res.json(processo);
    } catch (error) {
      console.error('[Processos] Erro ao atualizar processo:', error);
      if (error instanceof ZodError) {
        return res.status(400).json({
          message: 'Erro de validação',
          errors: error.errors.map(e => ({ path: e.path.join('.'), message: e.message }))
        });
      }
      if ((error as Error).message.includes('Processo não encontrado')) {
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
        return res.status(403).json({ message: 'Apenas administradores e gestores podem deletar processos' });
      }

      const { id } = req.params;
      const processoId = parseInt(id);
      
      // validar escopo antes de deletar
      const existing = await this.processosService.getById(processoId);
      if (session?.role !== 'admin') {
        const allowed = (req as any).orgScope?.allowedOrgIds as number[] | null | undefined;
        if (allowed && !allowed.includes(existing.organizationId)) {
          return res.status(403).json({ message: 'Proibido: acesso a outra organização' });
        }
      }

      await this.processosService.delete(processoId);
      return res.status(204).send();
    } catch (error) {
      console.error('[Processos] Erro ao deletar processo:', error);
      if ((error as Error).message.includes('Processo não encontrado')) {
        return res.status(404).json({ message: (error as Error).message });
      }
      return res.status(500).json({ message: (error as Error).message });
    }
  }
}
