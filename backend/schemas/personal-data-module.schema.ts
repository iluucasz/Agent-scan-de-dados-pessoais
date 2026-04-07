import { z } from "zod";
import { createInsertSchema } from "drizzle-zod";
import { boolean, integer, json, pgEnum, pgTable, serial, text, timestamp, uuid } from "drizzle-orm/pg-core";

// Enums para categorização de dados pessoais
export const dataCategoryEnum = pgEnum('data_category', ['personal_data', 'sensitive_data', 'anonymous_data', 'pseudonymized_data']);
export const dataSubcategoryEnum = pgEnum('data_subcategory', ['identification', 'financial', 'health', 'biometric', 'location', 'professional', 'behavioral']);
export const dataCriticalityEnum = pgEnum('data_criticality', ['high', 'medium', 'low']);
export const dataSourceEnum = pgEnum('data_source', ['internal', 'external_direct', 'external_third_party']);
export const legalBasisEnum = pgEnum('legal_basis', ['consent', 'legal_obligation', 'contract_execution', 'legitimate_interest', 'credit_protection', 'life_protection', 'research', 'public_policy']);

// Tabela dataItems
export const dataItems = pgTable('data_items', {
  id: serial('id').primaryKey(),
  userUuid: uuid('user_uuid').notNull(),
  organizationId: integer('organization_id'),
  identifier: text('identifier').notNull(),
  description: text('description').notNull(),
  type: text('type').notNull(), // structured ou unstructured
  category: dataCategoryEnum('category').notNull(),
  subcategory: dataSubcategoryEnum('subcategory'),
  criticality: dataCriticalityEnum('criticality').notNull(),
  source: dataSourceEnum('source').notNull(),
  collectionChannel: text('collection_channel'),
  storageLocation: text('storage_location'),
  storageIpAddress: text('storage_ip_address'),
  processingPurpose: text('processing_purpose').notNull(),
  associatedProcesses: text('associated_processes'),
  processingOperation: text('processing_operation'),
  consent: boolean('consent'),
  legalBasis: legalBasisEnum('legal_basis').notNull(),
  securityLevel: text('security_level'),
  protectionMeasures: text('protection_measures'),
  internalAccess: text('internal_access'),
  thirdPartySharing: text('third_party_sharing'),
  accessHistory: text('access_history'),
  retentionPeriod: integer('retention_period'), // meses
  deletionPolicy: text('deletion_policy'),
  collectionDate: timestamp('collection_date'),
  lastUpdated: timestamp('last_updated').defaultNow(),
  responsibleParty: text('responsible_party'),
  changeLog: json('change_log'),
  riskAssessment: json('risk_assessment'),
  mitigationMeasures: text('mitigation_measures'),
  potentialImpact: text('potential_impact'),
  additionalNotes: text('additional_notes'),
  references: text('references'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Schema para inserção de DataItem (item de dados pessoais)
export const insertDataItemSchema = createInsertSchema(dataItems).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

// Schema para atualização de DataItem
export const updateDataItemSchema = insertDataItemSchema.partial();

// Tipo para DataItem selecionado
export type DataItem = typeof dataItems.$inferSelect;

// Tipo para InsertDataItem
export type InsertDataItem = z.infer<typeof insertDataItemSchema>; 