import { z } from "zod";
import { createInsertSchema } from "drizzle-zod";
import { pgTable, serial, text, integer, boolean, timestamp } from 'drizzle-orm/pg-core';
import { areas } from './areas.schema';
import { organizations } from './schema';
import { relations } from 'drizzle-orm';

export const processos = pgTable('processos', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  description: text('description'),
  purpose: text('purpose'), // Para compliance LGPD
  areaId: integer('area_id').notNull().references(() => areas.id, { onDelete: 'cascade' }),
  organizationId: integer('organization_id').notNull().references(() => organizations.id, { onDelete: 'cascade' }),
  createdBy: text('created_by'), // Usar text como no sistema atual
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

export const processosRelations = relations(processos, ({ one }) => ({
  area: one(areas, {
    fields: [processos.areaId],
    references: [areas.id]
  }),
  organization: one(organizations, {
    fields: [processos.organizationId],
    references: [organizations.id]
  })
}));

// Schema para inserção
export const insertProcessoSchema = createInsertSchema(processos).omit({
  id: true,
  createdAt: true,
  updatedAt: true
});

// Schema para atualização
export const updateProcessoSchema = insertProcessoSchema.partial();

// Tipos
export type Processo = typeof processos.$inferSelect;
export type InsertProcesso = z.infer<typeof insertProcessoSchema>;
export type UpdateProcesso = z.infer<typeof updateProcessoSchema>;
