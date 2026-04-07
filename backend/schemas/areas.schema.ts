import { z } from "zod";
import { createInsertSchema } from "drizzle-zod";
import { pgTable, serial, text, integer, boolean, timestamp, primaryKey } from 'drizzle-orm/pg-core';
import { organizations } from './schema';
import { relations } from 'drizzle-orm';

export const areas = pgTable('areas', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  description: text('description'),
  organizationId: integer('organization_id').notNull().references(() => organizations.id, { onDelete: 'cascade' }),
  parentId: integer('parent_id').references((): any => areas.id, { onDelete: 'set null' }),
  level: integer('level').default(0).notNull(),
  createdBy: text('created_by'),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

// Tabela de hierarquia (closure table)
export const areaHierarchy = pgTable('area_hierarchy', {
  ancestorId: integer('ancestor_id').notNull().references(() => areas.id, { onDelete: 'cascade' }),
  descendantId: integer('descendant_id').notNull().references(() => areas.id, { onDelete: 'cascade' }),
  depth: integer('depth').notNull().default(0)
}, (table) => ({
  pk: primaryKey({ columns: [table.ancestorId, table.descendantId] })
}));

export const areasRelations = relations(areas, ({ one, many }) => ({
  organization: one(organizations, {
    fields: [areas.organizationId],
    references: [organizations.id]
  }),
  parent: one(areas, {
    fields: [areas.parentId],
    references: [areas.id],
    relationName: 'areaParentChild'
  }),
  children: many(areas, {
    relationName: 'areaParentChild'
  })
}));

// Schema para inserção
export const insertAreaSchema = createInsertSchema(areas).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
  level: true // Calculado automaticamente pelo trigger
});

// Schema para atualização
export const updateAreaSchema = insertAreaSchema.partial();

// Tipos
export type Area = typeof areas.$inferSelect;
export type InsertArea = z.infer<typeof insertAreaSchema>;
export type UpdateArea = z.infer<typeof updateAreaSchema>;

// Tipo estendido com filhas (para árvore)
export type AreaWithChildren = Area & { 
  children: AreaWithChildren[];
  childCount?: number;
};

// Tipo para resposta de hierarquia
export type AreaPath = Area[];
