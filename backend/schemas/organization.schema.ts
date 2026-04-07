import { z } from "zod";
import { createInsertSchema } from "drizzle-zod";
import {
  pgTable,
  serial,
  text,
  integer,
  boolean,
  timestamp,
  json,
  pgEnum
} from "drizzle-orm/pg-core";

// Enums para organizações
export const organizationTypeEnum = pgEnum('organization_type', [
  'consultoria', // Consultoria/DPO as a Service
  'empresa',     // Empresa direta
  'filial',      // Filial/unidade
  'departamento' // Departamento interno
]);

export const subscriptionPlanEnum = pgEnum('subscription_plan', [
  'free',
  'basic',
  'professional',
  'enterprise',
  'custom'
]);

// Tabela organizations
export const organizations: any = pgTable('organizations', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  description: text('description'),
  logoUrl: text('logo_url'),
  type: organizationTypeEnum('type').notNull().default('empresa'),
  parentId: integer('parent_id').references((): any => organizations.id),
  cnpj: text('cnpj'),
  address: text('address'),
  city: text('city'),
  state: text('state'),
  country: text('country').default('Brasil'),
  postalCode: text('postal_code'),
  phone: text('phone'),
  website: text('website'),
  subscriptionPlan: subscriptionPlanEnum('subscription_plan').default('free'),
  subscriptionStart: timestamp('subscription_start'),
  subscriptionEnd: timestamp('subscription_end'),
  paymentStatus: text('payment_status').default('pending'),
  enabledModules: json('enabled_modules'),
  maxUsers: integer('max_users'),
  maxStorage: integer('max_storage'),
  createdBy: integer('created_by'),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Schema para inserção de Organization
export const insertOrganizationSchema = createInsertSchema(organizations).omit({
  id: true,
  createdAt: true,
  updatedAt: true
}).extend({
  subscriptionStart: z.preprocess(
    (val) => val ? new Date(val as string) : null,
    z.date().nullable()
  ),
  subscriptionEnd: z.preprocess(
    (val) => val ? new Date(val as string) : null,
    z.date().nullable()
  ),
});

// Schema para atualização de Organization
export const updateOrganizationSchema = insertOrganizationSchema.partial().extend({
  subscriptionStart: z.preprocess(
    (val) => val ? new Date(val as string) : null,
    z.date().nullable()
  ),
  subscriptionEnd: z.preprocess(
    (val) => val ? new Date(val as string) : null,
    z.date().nullable()
  ),
});

// Tipos
export type Organization = typeof organizations.$inferSelect;
export type InsertOrganization = z.infer<typeof insertOrganizationSchema>;
export type UpdateOrganization = z.infer<typeof updateOrganizationSchema>;