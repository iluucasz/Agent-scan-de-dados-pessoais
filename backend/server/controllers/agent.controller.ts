import { Request, Response } from 'express';
import { UsersService } from '../services/users.service';
import { AgentService } from '../services/agent.service';
import { MailService } from '../services/mail.service';
import { db } from '../db';
import { users as usersTable } from '../../schemas/users.schema';
import { eq } from 'drizzle-orm';

export class AgentController {
  constructor(
    private usersService = new UsersService(),
    private agentsService = new AgentService(),
    private mailService = new MailService(),
  ) {}

  // Cria um usuário com role 'agent' e dispara e-mail com token permanente
  createAgent = async (req: Request, res: Response) => {
    try {
      const body = req.body || {};

      if (!body.email || typeof body.email !== 'string') {
        return res.status(400).json({ message: 'Email é obrigatório' });
      }

      const payload = {
        name: body.name || body.email.split('@')[0],
        email: body.email.toLowerCase(),
        role: 'agent' as const,
        organizationId: body.organizationId ?? (req.user?.organizationId || Number(process.env.DEFAULT_ORGANIZATION_ID) || 1),
        currentOrganizationId: body.currentOrganizationId,
        password: body.password || 'placeholder',
        isActive: body.isActive ?? true,
        jobTitle: body.jobTitle,
        department: body.department,
        phone: body.phone,
      } as any;

      const createdUser = await this.usersService.register(payload);

      // usersService.register já envia o e-mail com token para agents.

      return res.status(201).json(createdUser);
    } catch (error: any) {
      console.error('[AgentController.createAgent] error:', error);
      const msg = error?.message || 'Erro ao criar agent';
      const code = (error as any)?.code;
      if (code === '23505') {
        return res.status(409).json({ message: 'Já existe um usuário com este e-mail.' });
      }
      return res.status(400).json({ message: msg });
    }
  };

  // Lista todos usuários com role 'agent' para a organização do admin
  listAgents = async (req: Request, res: Response) => {
    try {
      const organizationId = req.query.organizationId
        ? Number(req.query.organizationId)
        : req.user?.organizationId || Number(process.env.DEFAULT_ORGANIZATION_ID) || 1;

      const rows = await db
        .select()
        .from(usersTable)
        .where(eq(usersTable.organizationId, organizationId));

      const agents = rows
        .filter((u) => u.role === 'agent')
        .map((u: any) => {
          const { password, ...rest } = u;
          return rest;
        });

      return res.json(agents);
    } catch (error: any) {
      console.error('[AgentController.listAgents] error:', error);
      return res.status(500).json({ message: error?.message || 'Erro ao listar agents' });
    }
  };

  // Reseta o token do agent e envia um novo por e-mail
  resetAgentToken = async (req: Request, res: Response) => {
    try {
      const { id } = req.params; // UUID do usuário agent
      if (!id) {
        return res.status(400).json({ message: 'ID do agent é obrigatório' });
      }

      const [user] = await db.select().from(usersTable).where(eq(usersTable.id, id));
      if (!user || user.role !== 'agent') {
        return res.status(404).json({ message: 'Agent não encontrado' });
      }

      const newToken = await this.agentsService.resetAgentToken(user.id);

      await this.mailService.sendAgentToken(user.email, user.name || 'Agent', newToken);

      return res.status(200).json({ message: 'Token do agent resetado com sucesso' });
    } catch (error: any) {
      console.error('[AgentController.resetAgentToken] error:', error);
      return res.status(500).json({ message: error?.message || 'Erro ao resetar token do agent' });
    }
  };
}
