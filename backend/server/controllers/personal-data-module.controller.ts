import { Request, Response } from 'express';
import { PersonalDataModuleService } from '../services/personal-data-module.service';

export class PersonalDataModuleController {
  constructor(private service: PersonalDataModuleService) {}

  async getAll(req: Request, res: Response) {
    try {
  const orgId = (req as any).orgScope?.currentOrganizationId ?? req.user?.organizationId;
      const items = await this.service.getAll(orgId);
      res.json(items);
    } catch (error) {
      res.status(500).json({ message: (error as Error).message });
    }
  }

  async getStats(req: Request, res: Response) {
    try {
  const orgId = (req as any).orgScope?.currentOrganizationId ?? req.user?.organizationId;
      const stats = await this.service.getStats(orgId);
      res.json(stats);
    } catch (error) {
      res.status(500).json({ message: (error as Error).message });
    }
  }

  async getById(req: Request, res: Response) {
    try {
      const id = parseInt(req.params.id);
      const item = await this.service.getById(id);
      if (!item) {
        return res.status(404).json({ message: 'Data item not found' });
      }
  const sessionUserRole = req.user?.role;
  const currentOrgId = (req as any).orgScope?.currentOrganizationId ?? req.user?.organizationId;
  if (sessionUserRole !== 'admin' && item.organizationId !== currentOrgId) {
        return res.status(403).json({ message: 'Forbidden: Cannot access data item from another organization' });
      }
      res.json(item);
    } catch (error) {
      res.status(500).json({ message: (error as Error).message });
    }
  }

  async create(req: Request, res: Response) {
    try {
      const data = {
        ...req.body,
  organizationId: req.body.organizationId || (req as any).orgScope?.currentOrganizationId || req.user?.organizationId,
        userUuid: req.user?.id
      };
      const created = await this.service.create(data);
      res.status(201).json(created);
    } catch (error) {
      res.status(400).json({ message: (error as Error).message });
    }
  }

  async update(req: Request, res: Response) {
    try {
      const id = parseInt(req.params.id);
      const updated = await this.service.update(id, req.body);
      if (!updated) {
        return res.status(404).json({ message: 'Data item not found' });
      }
      res.json(updated);
    } catch (error) {
      res.status(400).json({ message: (error as Error).message });
    }
  }

  async delete(req: Request, res: Response) {
    try {
      const id = parseInt(req.params.id);
      const success = await this.service.delete(id);
      if (!success) {
        return res.status(404).json({ message: 'Data item not found' });
      }
      return res.status(204).send();
    } catch (error) {
      res.status(500).json({ message: (error as Error).message });
    }
  }
} 