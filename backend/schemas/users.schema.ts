import { z } from "zod";
import { pgEnum, pgTable, text, uuid, integer, boolean, timestamp } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";

// Enum específico para papéis de usuário (evita conflito com outros enums existentes)
export const userRoleEnum = pgEnum('user_role', ['admin', 'gestor', 'cliente', 'agent']);

// Tabela users
export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  organizationId: integer('organization_id'),
  currentOrganizationId: integer('current_organization_id'),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  password: text('password').notNull(),
  role: userRoleEnum('role').notNull().default('cliente'),
  isActive: boolean('is_active').default(true),
  lastLogin: timestamp('last_login'),
  jobTitle: text('job_title'),
  department: text('department'),
  phone: text('phone'),
  accessToken: text('access_token'),
  emailVerifiedAt: timestamp('email_verified_at'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Schema para inserção de usuário
const baseInsertUserSchema = createInsertSchema(users).omit({ 
  id: true, createdAt: true, updatedAt: true, lastLogin: true
});

export const insertUserSchema = baseInsertUserSchema.extend({
  role: z.enum(['admin', 'gestor', 'cliente', 'agent']).default('cliente')
});

export type InsertUser = z.infer<typeof insertUserSchema> & { id?: string };

// Schema para atualização de usuário
export const updateUserSchema = insertUserSchema.partial();

// Schema de login
export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

export type LoginCredentials = z.infer<typeof loginSchema>;

// Tipo User
export type User = typeof users.$inferSelect & { id: string };
