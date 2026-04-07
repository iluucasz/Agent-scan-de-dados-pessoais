import { z } from "zod";
import { createInsertSchema } from "drizzle-zod";
import { serial, integer, text, json, timestamp, pgTable } from "drizzle-orm/pg-core";
import { organizations, scanStatusEnum, dataSourceTypeEnum, dataCategoryEnum, dataSubcategoryEnum, dataCriticalityEnum } from "./schema";

// Configurações de Escaneamento de Dados
export const dataScanConfigs = pgTable('data_scan_configs', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id).notNull(),
  name: text('name').notNull(),
  description: text('description'),
  sourceType: dataSourceTypeEnum('source_type').notNull(),
  connectionConfig: json('connection_config').notNull(),
  scanPattern: json('scan_pattern'),
  scanSchedule: text('scan_schedule'),
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Jobs de Escaneamento
export const dataScanJobs = pgTable('data_scan_jobs', {
  id: serial('id').primaryKey(),
  configId: integer('config_id').references(() => dataScanConfigs.id).notNull(),
  organizationId: integer('organization_id').references(() => organizations.id).notNull(),
  status: scanStatusEnum('status').notNull(),
  startedAt: timestamp('started_at'),
  completedAt: timestamp('completed_at'),
  foundItems: json('found_items'),
  stats: json('stats'),
  error: text('error'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Resultados detalhados de Escaneamento
export const dataScanResults = pgTable('data_scan_results', {
  id: serial('id').primaryKey(),
  jobId: integer('job_id').references(() => dataScanJobs.id).notNull(),
  organizationId: integer('organization_id').references(() => organizations.id).notNull(),
  name: text('name').notNull(),
  description: text('description'),
  source: text('source'),
  scanType: text('scan_type'),
  itemCount: integer('item_count').default(0),
  completedAt: timestamp('completed_at'),
  riskAnalysis: json('risk_analysis'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Inventário de dados coletados pelos escaneamentos
export const dataInventory = pgTable('data_inventory', {
  id: serial('id').primaryKey(),
  scanResultId: integer('scan_result_id').references(() => dataScanResults.id).notNull(),
  organizationId: integer('organization_id').references(() => organizations.id).notNull(),
  dataType: text('data_type').notNull(),
  displayName: text('display_name'),
  value: text('value'),
  category: dataCategoryEnum('category').default('personal_data'),
  subcategory: dataSubcategoryEnum('subcategory').default('identification'),
  criticality: dataCriticalityEnum('criticality').default('medium'),
  context: text('context'),
  source: text('source'),
  fileName: text('file_name'),
  filePath: text('file_path'),
  line: integer('line'),
  confidence: text('confidence'),
  lastScanned: timestamp('last_scanned').defaultNow(),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Schemas de inserção
export const insertDataScanConfigSchema = createInsertSchema(dataScanConfigs)
  .omit({ id: true, createdAt: true, updatedAt: true })
  .partial({ organizationId: true, createdBy: true });
export const insertDataScanJobSchema = createInsertSchema(dataScanJobs).omit({ id: true, createdAt: true, updatedAt: true });
export const insertDataScanResultSchema = createInsertSchema(dataScanResults).omit({ id: true, createdAt: true, updatedAt: true });
export const insertDataInventorySchema = createInsertSchema(dataInventory).omit({ id: true, createdAt: true, updatedAt: true });

// Tipos inferidos
export type DataScanConfig = typeof dataScanConfigs.$inferSelect;
export type DataScanJob = typeof dataScanJobs.$inferSelect;
export type DataScanResult = typeof dataScanResults.$inferSelect;
export type InsertDataScanConfig = z.infer<typeof insertDataScanConfigSchema>;
export type InsertDataScanJob = z.infer<typeof insertDataScanJobSchema>;
export type InsertDataScanResult = z.infer<typeof insertDataScanResultSchema>;
export type DataInventory = typeof dataInventory.$inferSelect;
export type InsertDataInventory = z.infer<typeof insertDataInventorySchema>; 