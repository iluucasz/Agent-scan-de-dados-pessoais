import { db } from "../db";
import { users as usersTable } from "../../schemas/users.schema";
import { eq } from "drizzle-orm";
import { hashPassword, comparePasswords } from "../utils";
import { signToken } from "../utils/jwt";
import { loginSchema, insertUserSchema, updateUserSchema, type InsertUser, type LoginCredentials } from "../../schemas/users.schema";
import { MailService } from "./mail.service";
import { TokenService } from "./token.service";

export class UsersService {
  private mailService = new MailService();
  private tokenService = new TokenService();

  async register(body: InsertUser) {
    // Definir valores padrão para organização e role
    const defaults = {
      organizationId: Number(process.env.DEFAULT_ORGANIZATION_ID) || 1,
      role: (process.env.DEFAULT_USER_ROLE as 'admin'|'gestor'|'cliente') || 'cliente'
    };
    // Mesclar defaults com os valores vindos do body
    const dataWithDefaults = { 
      ...defaults, 
      ...body,
      // Garantir que currentOrganizationId seja setado com o valor de organizationId se não informado
      currentOrganizationId: body.currentOrganizationId || body.organizationId || defaults.organizationId
    };
    // Validar e construir dados de usuário
    const userData = insertUserSchema.parse(dataWithDefaults);
    
    if (userData.password) {
      userData.password = await hashPassword(userData.password);
    }
    // Inserir usuário no banco; o DB gerará o UUID automaticamente
    const [createdUser] = await db.insert(usersTable).values(userData).returning();

    // Fluxo de comunicação inicial varia conforme o tipo de usuário
    try {
      if (createdUser.role === 'agent') {
        // Para Agent: enviar apenas o token de acesso permanente
        const { AgentService } = await import('./agent.service');
        const agentService = new AgentService();
        const agentToken = await agentService.generateAgentToken(createdUser.id);

        await this.mailService.sendAgentToken(
          createdUser.email,
          createdUser.name || 'Agent',
          agentToken
        );

        console.log(`✅ Agent criado e token enviado para: ${createdUser.email}`);
      } else {
        // Para demais usuários: gerar token de reset para primeiro acesso
        const ttl = Number(process.env.RESET_PASSWORD_TTL || 60 * 30); // 30 minutos ou configurado
        const meta = { userId: createdUser.id, reason: 'first_access' } as any;
        const { raw: resetToken } = await this.tokenService.issueResetToken(
          createdUser.email.toLowerCase(),
          ttl,
          meta
        );

        await this.mailService.sendWelcomeWithResetToken(
          createdUser.email,
          createdUser.name || 'Usuário',
          resetToken
        );

        console.log(`✅ Email de boas-vindas enviado para: ${createdUser.email} com token de reset`);
      }
    } catch (emailError) {
      console.error(`❌ Erro ao enviar email para ${createdUser.email}:`, emailError);
      // Não bloquear criação do usuário se email falhar
    }
    
    // Gerar token JWT para o novo usuário
    const token = signToken({ id: createdUser.id, role: createdUser.role, organizationId: createdUser.organizationId! });
    
    // ✅ IMPORTANTE: NÃO ATUALIZAR lastLogin NA CRIAÇÃO (para detectar primeiro login)
    const [updatedUser] = await db.update(usersTable)
      .set({ accessToken: token })
      .where(eq(usersTable.id, createdUser.id))
      .returning();
    
    const { password, ...userWithoutPassword } = updatedUser!;
    return userWithoutPassword;
  }

  async login(body: LoginCredentials) {
    const credentials = loginSchema.parse(body);
    const [user] = await db.select().from(usersTable).where(eq(usersTable.email, credentials.email));
    if (!user) {
      throw new Error("Email ou senha inválidos");
    }
    const passwordMatch = await comparePasswords(credentials.password, user.password);
    if (!passwordMatch) {
      throw new Error("Email ou senha inválidos");
    }
    // Gerar token JWT
    const organizationId = typeof user.organizationId === 'number' ? user.organizationId : 1;
    const token = signToken({ id: user.id, role: user.role, organizationId });

    // Atualizar accessToken e lastLogin no banco
    const [updatedUser] = await db.update(usersTable)
      .set({ accessToken: token, lastLogin: new Date() })
      .where(eq(usersTable.id, user.id))
      .returning();

    const { password, ...userWithoutPassword } = updatedUser!;
    return userWithoutPassword;
  }

  async getUsers(organizationId: number) {
    const users = await db.select().from(usersTable).where(eq(usersTable.organizationId, organizationId));
    return users.map(user => {
      const { password, ...userWithoutPassword } = user;
      return userWithoutPassword;
    });
  }

  async updateUser(id: string, body: Partial<InsertUser>) {
    const userData = updateUserSchema.parse(body);
    if (userData.password) {
      userData.password = await hashPassword(userData.password);
    }
    const [user] = await db.update(usersTable).set(userData).where(eq(usersTable.id, id)).returning();
    if (!user) {
      throw new Error("Usuário não encontrado");
    }
    const { password, ...userWithoutPassword } = user;
    return userWithoutPassword;
  }

  async deleteUser(id: string) {
    const result = await db.delete(usersTable).where(eq(usersTable.id, id));
    if ((result.rowCount ?? 0) === 0) {
      throw new Error("Usuário não encontrado");
    }
    return { message: "Usuário removido com sucesso" };
  }

  async getUserById(id: string) {
    const [user] = await db.select().from(usersTable).where(eq(usersTable.id, id));
    if (!user) throw new Error("Usuário não encontrado");
    const { password, ...userWithoutPassword } = user;
    return userWithoutPassword;
  }
}