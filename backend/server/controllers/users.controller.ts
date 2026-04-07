import { Request, Response } from "express";
import { ZodError } from "zod";
import { UsersService } from "../services/users.service";

export class UsersController {
  constructor(private usersService: UsersService) {}

  async register(req: Request, res: Response): Promise<Response> {
    try {
      const user = await this.usersService.register(req.body);
      return res.status(201).json(user);
    } catch (error) {
      console.error('[User Register] Erro ao registrar usuário:', error);
      if (error instanceof ZodError) {
        return res.status(400).json({
          message: "Erro de validação",
          errors: error.errors.map(e => ({
            path: e.path.join('.'),
            message: e.message
          }))
        });
      }
      // Erro de e-mail duplicado (Postgres: code 23505)
      if (error && typeof error === 'object' && 'code' in error && error.code === '23505') {
        return res.status(409).json({
          message: "Já existe um usuário cadastrado com este e-mail.",
          code: "EMAIL_DUPLICADO"
        });
      }
      return res.status(400).json({
        message: (error as Error).message || JSON.stringify(error) || "Erro desconhecido ao registrar usuário"
      });
    }
  }

  async login(req: Request, res: Response): Promise<Response> {
    try {
      const result = await this.usersService.login(req.body);
      return res.json({ user: result });
    } catch (error) {
      const message = (error as Error).message || 'Email ou senha inválidos';
      return res.status(401).json({ message });
    }
  }

  async getUsers(req: Request, res: Response): Promise<Response> {
    try {
      // Filtragem de usuários baseada no perfil e escopo org
      const session = req.user! as any;
      const orgScope = (req as any).orgScope;
      // Admin pode listar por organizationId?=X (ou todos se não informado)
      let allUsers;
      if (session.role === 'admin') {
        const orgIdQuery = req.query.organizationId ? parseInt(req.query.organizationId as string, 10) : undefined;
        if (orgIdQuery && !Number.isNaN(orgIdQuery)) {
          allUsers = await this.usersService.getUsers(orgIdQuery);
        } else {
          // fallback: se não fornecer org, usar currentOrganizationId quando houver
          const orgId = orgScope?.currentOrganizationId ?? session.organizationId;
          allUsers = await this.usersService.getUsers(orgId);
        }
      } else {
        const orgId = orgScope?.currentOrganizationId ?? session.organizationId!;
        allUsers = await this.usersService.getUsers(orgId);
      }
      let filteredUsers;
      if (session.role === 'admin') {
        // Admin vê todos os usuários
        filteredUsers = allUsers;
      } else if (session.role === 'gestor') {
        // Gestor vê todos os usuários da própria organização
        filteredUsers = allUsers;
      } else {
        // Usuário comum vê somente a si mesmo
        filteredUsers = allUsers.filter(u => u.id === session.id.toString());
      }
      return res.json(filteredUsers);
    } catch (error) {
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async me(req: Request, res: Response): Promise<Response> {
    try {
      const id = req.user?.id;
      if (!id) {
        return res.status(401).json({ message: 'Não autenticado' });
      }
      const user = await this.usersService.getUserById(id.toString());
      const orgScope = (req as any).orgScope;
      let organization: any = undefined;
      try {
        // Lazy import para evitar acoplamento circular
        const { OrganizationService } = await import('../services/organization.service');
        const svc = new OrganizationService();
        const orgId = orgScope?.currentOrganizationId ?? user.organizationId ?? null;
        if (orgId) organization = await svc.getById(orgId);
      } catch {}
      return res.json({
        user,
        orgScope: orgScope ?? undefined,
        organization
      });
    } catch (error) {
      return res.status(500).json({ message: (error as Error).message });
    }
  }

  async updateUser(req: Request, res: Response): Promise<Response> {
    try {
      const id = req.params.id;
      const user = await this.usersService.updateUser(id, req.body);
      return res.json(user);
    } catch (error) {
      if (error instanceof ZodError) {
        return res.status(400).json({
          message: "Erro de validação",
          errors: error.errors.map(e => ({
            path: e.path.join('.'),
            message: e.message
          }))
        });
      }
      return res.status(400).json({
        message: (error as Error).message || JSON.stringify(error) || "Erro desconhecido ao atualizar usuário"
      });
    }
  }

  async deleteUser(req: Request, res: Response): Promise<Response> {
    try {
      const id = req.params.id;
      await this.usersService.deleteUser(id);
      return res.status(204).send();
    } catch (error) {
      if ((error as Error).message === 'Usuário não encontrado') {
        return res.status(404).send();
      }
      return res.status(400).json({
        message: (error as Error).message || JSON.stringify(error) || "Erro desconhecido ao remover usuário"
      });
    }
  }
} 