import { boolean, integer, json, pgEnum, pgTable, serial, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";
import { users } from "./users.schema";
// Usar require para importar dataScanResults somente na hora da referência e evitar import circular

// Enums for categorizing data
export const roleEnum = pgEnum('role', ['admin', 'agent', 'client', 'dpo']);
export const organizationTypeEnum = pgEnum('organization_type', [
  'consultoria', // Consultoria/DPO as a Service (como SeusDados)
  'empresa', // Empresa que contrata a plataforma diretamente
  'filial', // Filial/unidade de uma empresa maior
  'departamento' // Departamento específico dentro de uma organização
]);
export const subscriptionPlanEnum = pgEnum('subscription_plan', [
  'free', // Plano gratuito com recursos limitados
  'basic', // Plano básico
  'professional', // Plano profissional
  'enterprise', // Plano empresarial
  'custom' // Plano personalizado
]);
export const moduleAccessEnum = pgEnum('module_access', [
  'data_mapping', // Mapeamento de dados
  'risk_management', // Gestão de riscos
  'data_scanning', // Escaneamento de dados
  'reports', // Relatórios e dashboards
  'documentation', // Documentação
  'admin' // Administração do sistema
]);
export const dataCategoryEnum = pgEnum('data_category', [
  'personal_data',
  'sensitive_data',
  'anonymous_data',
  'pseudonymized_data'
]);

export const dataSubcategoryEnum = pgEnum('data_subcategory', [
  'identification',
  'financial',
  'health',
  'biometric',
  'location',
  'professional',
  'behavioral'
]);

export const dataCriticalityEnum = pgEnum('data_criticality', ['high', 'medium', 'low']);
export const dataSourceEnum = pgEnum('data_source', ['internal', 'external_direct', 'external_third_party']);
export const legalBasisEnum = pgEnum('legal_basis', [
  'consent',
  'legal_obligation',
  'contract_execution',
  'legitimate_interest',
  'credit_protection',
  'life_protection',
  'research',
  'public_policy'
]);

// Risk Management Enums
export const riskLikelihoodEnum = pgEnum('risk_likelihood', [
  'rare', // Muito improvável de ocorrer
  'unlikely', // Improvável, mas possível
  'possible', // Possível de ocorrer
  'likely', // Provável de ocorrer
  'almost_certain' // Quase certo de ocorrer
]);

export const riskImpactEnum = pgEnum('risk_impact', [
  'negligible', // Impacto desprezível
  'minor', // Impacto pequeno
  'moderate', // Impacto moderado
  'major', // Impacto significativo
  'severe' // Impacto severo/crítico
]);

export const riskStatusEnum = pgEnum('risk_status', [
  'identified', // Risco identificado
  'assessed', // Risco avaliado
  'mitigated', // Risco com mitigação implementada
  'accepted', // Risco aceito (sem mitigação)
  'transferred', // Risco transferido (ex: seguro)
  'resolved' // Risco resolvido
]);

export const riskCategoryEnum = pgEnum('risk_category', [
  'security', // Risco de segurança da informação
  'compliance', // Risco de conformidade legal/regulatória
  'operational', // Risco operacional
  'financial', // Risco financeiro (multas, etc)
  'reputation', // Risco reputacional
  'strategic' // Risco estratégico
]);

// Data Scanning Enums
export const scanStatusEnum = pgEnum('scan_status', ['pending', 'in_progress', 'completed', 'failed']);
export const dataSourceTypeEnum = pgEnum('data_source_type', ['database', 'file', 'api', 'directory']);
export const policyTypeEnum = pgEnum('policy_type', [
  'data_protection',
  'information_security',
  'data_retention',
  'data_sharing',
  'data_breach', 
  'cookie_policy', 
  'access_control',
  'privacy_policy',
  'other'
]);
export const policyStatusEnum = pgEnum('policy_status', ['active', 'inactive', 'draft', 'archived']);

// Platform documentation and versioning enums
export const documentTypeEnum = pgEnum('document_type', [
  'specification', 
  'user_guide', 
  'technical_doc', 
  'release_note', 
  'best_practice',
  'tutorial',
  'api_doc',
  'security_guideline',
  'compliance_guideline'
]);

export const platformComponentEnum = pgEnum('platform_component', [
  'frontend', 
  'backend', 
  'database', 
  'api', 
  'electron_client',
  'authentication',
  'data_scanner',
  'data_mapping',
  'reporting',
  'compliance_module',
  'full_platform'
]);

// Scanning Agent Enums
export const agentPlatformEnum = pgEnum('agent_platform', [
  'windows', 
  'macos', 
  'linux', 
  'android', 
  'ios'
]);

export const agentArchitectureEnum = pgEnum('agent_architecture', [
  'x86', 
  'x64', 
  'arm64', 
  'arm32'
]);

export const agentStatusEnum = pgEnum('agent_status', [
  'pending', 
  'active', 
  'inactive', 
  'error'
]);

export const agentActivityTypeEnum = pgEnum('agent_activity_type', [
  'scan_started', 
  'scan_completed', 
  'scan_failed',
  'update_available',
  'update_installed',
  'configuration_changed',
  'error'
]);

// Organizations (tenants)
export const organizations: any = pgTable('organizations', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  description: text('description'),
  logoUrl: text('logo_url'),
  type: organizationTypeEnum('type').notNull().default('empresa'),
  parentId: integer('parent_id').references((): any => organizations.id), // Organização principal/pai
  cnpj: text('cnpj'), // Identificação oficial da empresa (BR)
  address: text('address'),
  city: text('city'),
  state: text('state'),
  country: text('country').default('Brasil'),
  postalCode: text('postal_code'),
  phone: text('phone'),
  website: text('website'),
  
  // Campos para licenciamento/comercialização
  subscriptionPlan: subscriptionPlanEnum('subscription_plan').default('free'),
  subscriptionStart: timestamp('subscription_start'),
  subscriptionEnd: timestamp('subscription_end'),
  paymentStatus: text('payment_status').default('pending'), // pending, active, overdue, canceled
  
  // Controle de módulos disponíveis (baseado no plano)
  enabledModules: json('enabled_modules'), // Array com moduleAccessEnum values
  
  // Limites baseados no plano
  maxUsers: integer('max_users'),
  maxStorage: integer('max_storage'), // em MB
  
  createdBy: text('created_by'), // Usuário que criou (referência indireta para evitar circular)
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Access Profiles (Permission Groups)
export const accessProfiles = pgTable('access_profiles', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id),
  name: text('name').notNull(),
  description: text('description'),
  isDefault: boolean('is_default').default(false),
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Permissions within access profiles
export const permissions = pgTable('permissions', {
  id: serial('id').primaryKey(),
  profileId: integer('profile_id').references(() => accessProfiles.id),
  resourceType: text('resource_type').notNull(), // Ex: 'data_items', 'users', 'reports'
  action: text('action').notNull(), // Ex: 'create', 'read', 'update', 'delete', 'export'
  constraints: json('constraints'), // Optional JSON with constraints like { own: true } or { departments: ['IT', 'Legal'] }
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// User-Profile assignments (many-to-many)
export const userProfiles = pgTable('user_profiles', {
  id: serial('id').primaryKey(),
  userId: uuid('user_id').references(() => users.id).notNull(),
  profileId: integer('profile_id').references(() => accessProfiles.id).notNull(),
  assignedBy: text('assigned_by'),
  assignedAt: timestamp('assigned_at').defaultNow(),
});

// Departamentos dentro de organizações
export const departments: any = pgTable('departments', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id).notNull(),
  name: text('name').notNull(),
  description: text('description'),
  headUserId: text('head_user_id'), // Gestor responsável pelo departamento
  parentDepartmentId: integer('parent_department_id').references((): any => departments.id), // Para estrutura hierárquica
  isActive: boolean('is_active').default(true),
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Relação entre usuários e departamentos (muitos-para-muitos)
export const userDepartments = pgTable('user_departments', {
  id: serial('id').primaryKey(),
  userId: uuid('user_id').references(() => users.id).notNull(),
  departmentId: integer('department_id').references(() => departments.id).notNull(),
  isPrimary: boolean('is_primary').default(false), // Departamento principal do usuário
  assignedBy: text('assigned_by'),
  assignedAt: timestamp('assigned_at').defaultNow(),
});

// Relações entre organizações e consultores/DPOs (organization-to-organization)
export const organizationRelationships = pgTable('organization_relationships', {
  id: serial('id').primaryKey(),
  primaryOrganizationId: integer('primary_organization_id').references(() => organizations.id).notNull(), // DPO as a Service
  secondaryOrganizationId: integer('secondary_organization_id').references(() => organizations.id).notNull(), // Cliente
  relationshipType: text('relationship_type').notNull().default('client'), // client, partner, subsidiary
  startDate: timestamp('start_date').notNull().defaultNow(),
  endDate: timestamp('end_date'), // Para contratos com prazo definido
  contractDetails: json('contract_details'), // Detalhes do contrato/relacionamento
  createdBy: text('created_by'),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Data Processor Agents (can be assigned to multiple clients)
export const dataProcessingAgents = pgTable('data_processing_agents', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id),
  name: text('name').notNull(),
  description: text('description'),
  contact: text('contact'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Data mapping (personal data inventory)
export const dataItems = pgTable('data_items', {
  id: serial('id').primaryKey(),
  userUuid: uuid('user_uuid').references(() => users.id).notNull(),
  organizationId: integer('organization_id').references(() => organizations.id),
  identifier: text('identifier').notNull(),
  description: text('description').notNull(),
  type: text('type').notNull(), // structured or unstructured
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
  retentionPeriod: integer('retention_period'), // in months
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

// IT Assets
export const itAssets = pgTable('it_assets', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id),
  name: text('name').notNull(),
  type: text('type').notNull(), // server, database, application, device
  description: text('description'),
  location: text('location'),
  owner: text('owner'),
  dataClassifications: json('data_classifications'),
  securityMeasures: text('security_measures'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Reports
// Policies and regulations
export const policies = pgTable('policies', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id),
  name: text('name').notNull(),
  description: text('description'),
  type: policyTypeEnum('type').notNull(),
  status: policyStatusEnum('status').notNull().default('active'),
  content: text('content').notNull(), // Full policy text
  version: text('version').notNull(),
  effectiveDate: timestamp('effective_date').notNull(),
  expirationDate: timestamp('expiration_date'),
  approvedBy: text('approved_by'),
  createdBy: text('created_by'),
  tags: json('tags'), // Array of tags for categorization
  attachments: json('attachments'), // URLs to attached files
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Policy sections/rules
export const policyRules = pgTable('policy_rules', {
  id: serial('id').primaryKey(),
  policyId: integer('policy_id').references(() => policies.id).notNull(),
  organizationId: integer('organization_id').references(() => organizations.id),
  section: text('section').notNull(), // e.g., "Article 1, Section 2"
  title: text('title').notNull(),
  description: text('description').notNull(),
  detectionRules: json('detection_rules').notNull(), // Rules to detect violations
  recommendedAction: text('recommended_action'), // Recommended action to fix violation
  severity: text('severity').notNull(), // high, medium, low
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Policy violations detected in data mapping
export const policyViolations = pgTable('policy_violations', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id),
  dataItemId: integer('data_item_id').references(() => dataItems.id).notNull(),
  policyRuleId: integer('policy_rule_id').references(() => policyRules.id).notNull(),
  detectedAt: timestamp('detected_at').defaultNow(),
  status: text('status').notNull().default('active'), // active, fixed, ignored
  fixedAt: timestamp('fixed_at'),
  fixedBy: text('fixed_by'),
  notes: text('notes'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

export const reports = pgTable('reports', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id),
  name: text('name').notNull(),
  type: text('type').notNull(), // PDF, CSV, etc.
  createdBy: text('created_by'),
  generatedAt: timestamp('generated_at').defaultNow(),
  parameters: json('parameters'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Platform documentation repository
export const platformVersions = pgTable('platform_versions', {
  id: serial('id').primaryKey(),
  versionNumber: text('version_number').notNull().unique(), // E.g., 1.0.0, 2.1.3
  name: text('name').notNull(), // E.g., "Spring Update 2025"
  description: text('description'),
  releaseDate: timestamp('release_date').notNull(),
  isStable: boolean('is_stable').default(true),
  isMaintained: boolean('is_maintained').default(true),
  endOfSupportDate: timestamp('end_of_support_date'),
  releaseNotes: text('release_notes'),
  changelog: json('changelog').notNull(), // Structured changelog
  tags: json('tags'), // Array of tag strings
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

export const platformFeatures = pgTable('platform_features', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  description: text('description').notNull(),
  component: platformComponentEnum('component').notNull(),
  introducedInVersion: text('introduced_in_version').notNull(), // Version where feature was first introduced
  currentStatus: text('current_status').notNull().default('active'), // active, deprecated, planned
  screenshots: json('screenshots'), // Array of screenshot URLs
  demoUrl: text('demo_url'), // Link to demo/example
  technicalDetails: text('technical_details'),
  securityImplications: text('security_implications'),
  bestPractices: text('best_practices'),
  apiEndpoints: json('api_endpoints'), // Related API endpoints
  tags: json('tags'), // Array of tag strings
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

export const platformDocuments = pgTable('platform_documents', {
  id: serial('id').primaryKey(),
  title: text('title').notNull(),
  documentType: documentTypeEnum('document_type').notNull(),
  component: platformComponentEnum('component').notNull(),
  version: text('version'), // Specific version this document applies to, if any
  content: text('content').notNull(), // Full document content
  summary: text('summary'),
  relatedFeatures: json('related_features'), // Array of feature IDs
  attachments: json('attachments'), // URLs to attached files
  tags: json('tags'), // Array of tag strings
  isPublic: boolean('is_public').default(false), // Whether this document is available to all users
  publishedAt: timestamp('published_at'),
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

export const platformRoadmap = pgTable('platform_roadmap', {
  id: serial('id').primaryKey(),
  title: text('title').notNull(),
  description: text('description').notNull(),
  component: platformComponentEnum('component'),
  plannedVersion: text('planned_version'),
  status: text('status').notNull().default('planned'), // planned, in-progress, completed, cancelled
  priority: text('priority').notNull().default('medium'), // high, medium, low
  startDate: timestamp('start_date'), 
  targetCompletionDate: timestamp('target_completion_date'),
  actualCompletionDate: timestamp('actual_completion_date'),
  justification: text('justification'), // Business justification
  businessImpact: text('business_impact'),
  technicalImpact: text('technical_impact'),
  dependencies: json('dependencies'), // Other roadmap items this depends on
  tags: json('tags'), // Array of tag strings
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

// Integração com pagamentos e gestão de assinaturas
export const subscriptionPlans = pgTable('subscription_plans', {
  id: serial('id').primaryKey(),
  name: text('name').notNull(),
  code: text('code').notNull().unique(), // Código interno do plano
  displayName: text('display_name').notNull(), // Nome de exibição
  description: text('description'),
  type: subscriptionPlanEnum('type').notNull(),
  price: integer('price').notNull(), // Preço em centavos
  billingCycle: text('billing_cycle').notNull().default('monthly'), // monthly, quarterly, annual
  features: json('features').notNull(), // Lista de recursos incluídos
  enabledModules: json('enabled_modules').notNull(), // Módulos habilitados neste plano
  maxUsers: integer('max_users').notNull(),
  maxStorage: integer('max_storage').notNull(), // em MB
  maxOrganizations: integer('max_organizations').notNull(), // Número máximo de organizações que pode gerenciar (para consultorias)
  isActive: boolean('is_active').default(true),
  isHidden: boolean('is_hidden').default(false), // Planos especiais não exibidos publicamente
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

export const organizationSubscriptions = pgTable('organization_subscriptions', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id).notNull(),
  planId: integer('plan_id').references(() => subscriptionPlans.id).notNull(),
  status: text('status').notNull().default('pending'), // pending, active, canceled, overdue
  startDate: timestamp('start_date'),
  endDate: timestamp('end_date'),
  renewalDate: timestamp('renewal_date'),
  canceledDate: timestamp('canceled_date'),
  cancelReason: text('cancel_reason'),
  isAutorenewal: boolean('is_autorenewal').default(true),
  customPrice: integer('custom_price'), // Preço personalizado (se diferente do padrão)
  customFeatures: json('custom_features'), // Recursos personalizados
  paymentGateway: text('payment_gateway'), // stripe, paypal, etc.
  paymentGatewayCustomerId: text('payment_gateway_customer_id'), 
  paymentGatewaySubscriptionId: text('payment_gateway_subscription_id'),
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

export const subscriptionInvoices = pgTable('subscription_invoices', {
  id: serial('id').primaryKey(),
  subscriptionId: integer('subscription_id').references(() => organizationSubscriptions.id).notNull(),
  organizationId: integer('organization_id').references(() => organizations.id).notNull(),
  invoiceNumber: text('invoice_number').notNull(),
  amount: integer('amount').notNull(), // Valor em centavos
  status: text('status').notNull().default('pending'), // pending, paid, overdue, canceled
  dueDate: timestamp('due_date').notNull(),
  paidDate: timestamp('paid_date'),
  paymentMethod: text('payment_method'), // credit_card, boleto, pix, etc.
  paymentGatewayInvoiceId: text('payment_gateway_invoice_id'),
  invoiceUrl: text('invoice_url'), // URL para visualização/download
  periodStart: timestamp('period_start').notNull(),
  periodEnd: timestamp('period_end').notNull(),
  issuedAt: timestamp('issued_at').defaultNow(),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Módulos disponíveis no sistema (para controle de acesso baseado no plano)
export const platformModules = pgTable('platform_modules', {
  id: serial('id').primaryKey(),
  code: text('code').notNull().unique(), // Código interno do módulo
  name: text('name').notNull(),
  description: text('description'),
  isCore: boolean('is_core').default(false), // Módulo principal (sempre disponível)
  dependencies: json('dependencies'), // Outros módulos necessários
  minPlanLevel: text('min_plan_level'), // Nível mínimo de plano para ter este módulo
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Risk Management (Baseado nas normas ABNT ISO)
export const riskStandards = pgTable('risk_standards', {
  id: serial('id').primaryKey(),
  code: text('code').notNull(), // Ex: "ISO 27001:2022", "ISO 31000:2018", etc.
  name: text('name').notNull(),
  description: text('description'),
  version: text('version').notNull(),
  category: text('category').notNull(), // Segurança da Informação, Privacidade, Gestão de Riscos, etc.
  scope: text('scope').notNull(), // Escopo de aplicação da norma
  publishedAt: timestamp('published_at'),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

export const riskStandardControls = pgTable('risk_standard_controls', {
  id: serial('id').primaryKey(),
  standardId: integer('standard_id').references(() => riskStandards.id).notNull(),
  controlId: text('control_id').notNull(), // Ex: "A.5.1", "4.3.1", etc.
  name: text('name').notNull(),
  description: text('description').notNull(),
  category: text('category').notNull(), // Ex: "Política de Segurança", "Gestão de Acesso", etc.
  implementationGuidance: text('implementation_guidance'),
  verificationCriteria: text('verification_criteria'),
  relatedControls: json('related_controls'), // Controles relacionados de outras normas
  isRequired: boolean('is_required').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

export const riskTypes = pgTable('risk_types', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id),
  name: text('name').notNull(),
  description: text('description'),
  category: riskCategoryEnum('category').notNull(),
  defaultLikelihood: riskLikelihoodEnum('default_likelihood'),
  defaultImpact: riskImpactEnum('default_impact'),
  isCustom: boolean('is_custom').default(false),
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

export const risks = pgTable('risks', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id),
  typeId: integer('type_id').references(() => riskTypes.id),
  title: text('title').notNull(),
  description: text('description').notNull(),
  likelihood: riskLikelihoodEnum('likelihood').notNull(),
  impact: riskImpactEnum('impact').notNull(),
  category: riskCategoryEnum('category').notNull(),
  status: riskStatusEnum('status').notNull().default('identified'),
  identifiedDate: timestamp('identified_date').defaultNow(),
  assessedDate: timestamp('assessed_date'),
  resolvedDate: timestamp('resolved_date'),
  dueDate: timestamp('due_date'),
  owner: text('owner'),
  dataItems: json('data_items'), // Array de IDs de itens de dados relacionados
  itAssets: json('it_assets'), // Array de IDs de ativos de TI relacionados
  standardControls: json('standard_controls'), // Array de controles ABNT ISO relevantes para este risco
  threatSources: text('threat_sources'), // Fontes de ameaça (internas, externas, etc.)
  vulnerabilities: text('vulnerabilities'), // Vulnerabilidades exploradas pelo risco
  potentialImpact: text('potential_impact'), // Impacto potencial detalhado
  riskScore: integer('risk_score'), // Calculo de score (1-25 ou 1-100)
  inherentRiskScore: integer('inherent_risk_score'), // Score antes de controles
  residualRiskScore: integer('residual_risk_score'), // Score após controles
  acceptanceJustification: text('acceptance_justification'), // Justificativa para aceitação
  aiAnalysis: json('ai_analysis'), // Análise de IA para este risco (integração OpenAI)
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

export const riskMitigationControls = pgTable('risk_mitigation_controls', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id),
  riskId: integer('risk_id').references(() => risks.id).notNull(),
  standardControlId: integer('standard_control_id').references(() => riskStandardControls.id),
  name: text('name').notNull(),
  description: text('description').notNull(),
  controlType: text('control_type').notNull(), // preventativo, detectivo, corretivo, etc.
  implementationStatus: text('implementation_status').notNull(), // implementado, parcial, planejado, etc.
  effectiveness: text('effectiveness'), // Alto, médio, baixo
  costBenefit: text('cost_benefit'), // Análise de custo benefício
  implementationDate: timestamp('implementation_date'),
  verificationDate: timestamp('verification_date'),
  responsibleParty: text('responsible_party'),
  evidences: json('evidences'), // Provas de implementação (URLs, docs)
  notes: text('notes'),
  aiRecommendations: text('ai_recommendations'), // Recomendações geradas pela IA
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

export const riskAssessments = pgTable('risk_assessments', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id),
  name: text('name').notNull(),
  description: text('description'),
  assessmentDate: timestamp('assessment_date').defaultNow(),
  assessmentType: text('assessment_type').notNull(), // individual, batch, anual, etc.
  methodology: text('methodology'), // metodologia usada
  scope: text('scope').notNull(), // escopo da avaliação
  conductor: text('conductor'),
  reviewers: json('reviewers'), // Quem revisou o assessment
  conclusion: text('conclusion'),
  recommendations: text('recommendations'),
  attachments: json('attachments'), // URLs para documentos
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

export const riskAssessmentItems = pgTable('risk_assessment_items', {
  id: serial('id').primaryKey(),
  organizationId: integer('organization_id').references(() => organizations.id),
  assessmentId: integer('assessment_id').references(() => riskAssessments.id).notNull(),
  riskId: integer('risk_id').references(() => risks.id).notNull(),
  priorLikelihood: riskLikelihoodEnum('prior_likelihood'),
  priorImpact: riskImpactEnum('prior_impact'),
  newLikelihood: riskLikelihoodEnum('new_likelihood').notNull(),
  newImpact: riskImpactEnum('new_impact').notNull(),
  justification: text('justification'),
  mitigationRecommendations: text('mitigation_recommendations'),
  notes: text('notes'),
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

// Insert and select schemas for each table
export const insertOrganizationSchema = createInsertSchema(organizations).omit({ 
  id: true, createdAt: true, updatedAt: true 
});

// Schemas para departamentos
export const insertDepartmentSchema = createInsertSchema(departments).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertUserDepartmentSchema = createInsertSchema(userDepartments).omit({
  id: true, assignedAt: true
});

// Schemas para relacionamentos entre organizações 
export const insertOrganizationRelationshipSchema = createInsertSchema(organizationRelationships).omit({
  id: true, createdAt: true, updatedAt: true
});

// Schemas para assinaturas e planos
export const insertSubscriptionPlanSchema = createInsertSchema(subscriptionPlans).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertOrganizationSubscriptionSchema = createInsertSchema(organizationSubscriptions).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertSubscriptionInvoiceSchema = createInsertSchema(subscriptionInvoices).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertPlatformModuleSchema = createInsertSchema(platformModules).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertDataProcessingAgentSchema = createInsertSchema(dataProcessingAgents).omit({ 
  id: true, createdAt: true, updatedAt: true 
});

export const insertDataItemSchema = createInsertSchema(dataItems).omit({ 
  id: true, createdAt: true, updatedAt: true 
});

export const insertITAssetSchema = createInsertSchema(itAssets).omit({ 
  id: true, createdAt: true, updatedAt: true 
});

export const insertReportSchema = createInsertSchema(reports).omit({ 
  id: true, createdAt: true, updatedAt: true 
});

export const insertPolicySchema = createInsertSchema(policies).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertPolicyRuleSchema = createInsertSchema(policyRules).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertPolicyViolationSchema = createInsertSchema(policyViolations).omit({
  id: true, createdAt: true, updatedAt: true
});

// Platform documentation schemas
export const insertPlatformVersionSchema = createInsertSchema(platformVersions).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertPlatformFeatureSchema = createInsertSchema(platformFeatures).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertPlatformDocumentSchema = createInsertSchema(platformDocuments).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertPlatformRoadmapSchema = createInsertSchema(platformRoadmap).omit({
  id: true, createdAt: true, updatedAt: true
});

// Access control schemas
export const insertAccessProfileSchema = createInsertSchema(accessProfiles).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertPermissionSchema = createInsertSchema(permissions).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertUserProfileSchema = createInsertSchema(userProfiles).omit({
  id: true, assignedAt: true
});

// Risk management schemas
export const insertRiskStandardSchema = createInsertSchema(riskStandards).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertRiskStandardControlSchema = createInsertSchema(riskStandardControls).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertRiskTypeSchema = createInsertSchema(riskTypes).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertRiskSchema = createInsertSchema(risks).omit({
  id: true, createdAt: true, updatedAt: true, identifiedDate: true
});

export const insertRiskMitigationControlSchema = createInsertSchema(riskMitigationControls).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertRiskAssessmentSchema = createInsertSchema(riskAssessments).omit({
  id: true, createdAt: true, updatedAt: true, assessmentDate: true
});

export const insertRiskAssessmentItemSchema = createInsertSchema(riskAssessmentItems).omit({
  id: true, createdAt: true, updatedAt: true
});

// Central de Agentes - Versões disponíveis
export const agentVersions = pgTable('agent_versions', {
  id: serial('id').primaryKey(),
  version: text('version').notNull(),
  platform: agentPlatformEnum('platform').notNull(),
  architecture: agentArchitectureEnum('architecture').notNull(),
  fileUrl: text('file_url').notNull(),
  checksum: text('checksum').notNull(),
  releaseNotes: text('release_notes'),
  releaseDate: timestamp('release_date').notNull(),
  isActive: boolean('is_active').default(true),
  minSystemRequirements: json('min_system_requirements'),
  fileSize: integer('file_size').notNull(), // em bytes
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Agentes instalados e registrados
export const installedAgents = pgTable('installed_agents', {
  id: serial('id').primaryKey(),
  agentId: text('agent_id').notNull().unique(), // ID único do agente gerado na instalação
  organizationId: integer('organization_id').references(() => organizations.id),
  agentVersionId: integer('agent_version_id').references(() => agentVersions.id),
  deviceName: text('device_name').notNull(),
  deviceType: text('device_type').notNull(), // workstation, server, mobile
  platform: agentPlatformEnum('platform').notNull(),
  architecture: agentArchitectureEnum('architecture').notNull(),
  ipAddress: text('ip_address'),
  macAddress: text('mac_address'),
  lastCheckIn: timestamp('last_check_in'),
  status: agentStatusEnum('status').default('pending'),
  errorMessage: text('error_message'),
  configuration: json('configuration'), // Configurações específicas do agente
  activationCode: text('activation_code'), // Código usado para ativar o agente
  isActivated: boolean('is_activated').default(false),
  activatedAt: timestamp('activated_at'),
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

// Atividades dos agentes
export const agentActivities = pgTable('agent_activities', {
  id: serial('id').primaryKey(),
  agentId: text('agent_id').references(() => installedAgents.agentId),
  activityType: agentActivityTypeEnum('activity_type').notNull(),
  details: json('details'), // Detalhes específicos da atividade
  status: text('status').notNull().default('success'), // success, warning, error
  timestamp: timestamp('timestamp').defaultNow(),
});

// Comandos pendentes para agentes
export const agentCommands = pgTable('agent_commands', {
  id: serial('id').primaryKey(),
  agentId: text('agent_id').references(() => installedAgents.agentId),
  command: text('command').notNull(), // scan, update, configure, restart, etc.
  parameters: json('parameters'),
  status: text('status').notNull().default('pending'), // pending, delivered, executed, failed
  createdBy: text('created_by'),
  createdAt: timestamp('created_at').defaultNow(),
  deliveredAt: timestamp('delivered_at'),
  executedAt: timestamp('executed_at'),
  result: json('result'), // Resultado da execução
});

// Esquemas e tipos para Central de Agentes
export const insertAgentVersionSchema = createInsertSchema(agentVersions).omit({
  id: true, createdAt: true, updatedAt: true
});

export const insertInstalledAgentSchema = createInsertSchema(installedAgents).omit({
  id: true, createdAt: true, updatedAt: true, lastCheckIn: true, activatedAt: true
});

export const insertAgentActivitySchema = createInsertSchema(agentActivities).omit({
  id: true, timestamp: true
});

export const insertAgentCommandSchema = createInsertSchema(agentCommands).omit({
  id: true, createdAt: true, deliveredAt: true, executedAt: true, result: true
});

// Type definitions for the schemas
export type Organization = typeof organizations.$inferSelect;
export type InsertOrganization = z.infer<typeof insertOrganizationSchema>;

// Novos tipos para departamentos e hierarquia
export type Department = typeof departments.$inferSelect;
export type InsertDepartment = z.infer<typeof insertDepartmentSchema>;

export type UserDepartment = typeof userDepartments.$inferSelect;
export type InsertUserDepartment = z.infer<typeof insertUserDepartmentSchema>;

export type OrganizationRelationship = typeof organizationRelationships.$inferSelect;
export type InsertOrganizationRelationship = z.infer<typeof insertOrganizationRelationshipSchema>;

// Tipos para assinaturas e planos
export type SubscriptionPlan = typeof subscriptionPlans.$inferSelect;
export type InsertSubscriptionPlan = z.infer<typeof insertSubscriptionPlanSchema>;

export type OrganizationSubscription = typeof organizationSubscriptions.$inferSelect;
export type InsertOrganizationSubscription = z.infer<typeof insertOrganizationSubscriptionSchema>;

export type SubscriptionInvoice = typeof subscriptionInvoices.$inferSelect;
export type InsertSubscriptionInvoice = z.infer<typeof insertSubscriptionInvoiceSchema>;

export type PlatformModule = typeof platformModules.$inferSelect;
export type InsertPlatformModule = z.infer<typeof insertPlatformModuleSchema>;

export type DataProcessingAgent = typeof dataProcessingAgents.$inferSelect;
export type InsertDataProcessingAgent = z.infer<typeof insertDataProcessingAgentSchema>;

export type DataItem = typeof dataItems.$inferSelect;
export type InsertDataItem = z.infer<typeof insertDataItemSchema>;

export type ITAsset = typeof itAssets.$inferSelect;
export type InsertITAsset = z.infer<typeof insertITAssetSchema>;

export type Report = typeof reports.$inferSelect;
export type InsertReport = z.infer<typeof insertReportSchema>;

export type Policy = typeof policies.$inferSelect;
export type InsertPolicy = z.infer<typeof insertPolicySchema>;

export type PolicyRule = typeof policyRules.$inferSelect;
export type InsertPolicyRule = z.infer<typeof insertPolicyRuleSchema>;

export type PolicyViolation = typeof policyViolations.$inferSelect;
export type InsertPolicyViolation = z.infer<typeof insertPolicyViolationSchema>;

// Platform documentation types
export type PlatformVersion = typeof platformVersions.$inferSelect;
export type InsertPlatformVersion = z.infer<typeof insertPlatformVersionSchema>;

export type PlatformFeature = typeof platformFeatures.$inferSelect;
export type InsertPlatformFeature = z.infer<typeof insertPlatformFeatureSchema>;

export type PlatformDocument = typeof platformDocuments.$inferSelect;
export type InsertPlatformDocument = z.infer<typeof insertPlatformDocumentSchema>;

export type PlatformRoadmap = typeof platformRoadmap.$inferSelect;
export type InsertPlatformRoadmap = z.infer<typeof insertPlatformRoadmapSchema>;

// Access control types
export type AccessProfile = typeof accessProfiles.$inferSelect;
export type InsertAccessProfile = z.infer<typeof insertAccessProfileSchema>;

export type Permission = typeof permissions.$inferSelect;
export type InsertPermission = z.infer<typeof insertPermissionSchema>;

export type UserProfile = typeof userProfiles.$inferSelect;
export type InsertUserProfile = z.infer<typeof insertUserProfileSchema>;

// Risk management types
export type RiskStandard = typeof riskStandards.$inferSelect;
export type InsertRiskStandard = z.infer<typeof insertRiskStandardSchema>;

export type RiskStandardControl = typeof riskStandardControls.$inferSelect;
export type InsertRiskStandardControl = z.infer<typeof insertRiskStandardControlSchema>;

export type RiskType = typeof riskTypes.$inferSelect;
export type InsertRiskType = z.infer<typeof insertRiskTypeSchema>;

export type Risk = typeof risks.$inferSelect;
export type InsertRisk = z.infer<typeof insertRiskSchema>;

export type RiskMitigationControl = typeof riskMitigationControls.$inferSelect;
export type InsertRiskMitigationControl = z.infer<typeof insertRiskMitigationControlSchema>;

export type RiskAssessment = typeof riskAssessments.$inferSelect;
export type InsertRiskAssessment = z.infer<typeof insertRiskAssessmentSchema>;

export type RiskAssessmentItem = typeof riskAssessmentItems.$inferSelect;
export type InsertRiskAssessmentItem = z.infer<typeof insertRiskAssessmentItemSchema>;

// Central de Agentes types
export type AgentVersion = typeof agentVersions.$inferSelect;
export type InsertAgentVersion = z.infer<typeof insertAgentVersionSchema>;

export type InstalledAgent = typeof installedAgents.$inferSelect;
export type InsertInstalledAgent = z.infer<typeof insertInstalledAgentSchema>;

export type AgentActivity = typeof agentActivities.$inferSelect;
export type InsertAgentActivity = z.infer<typeof insertAgentActivitySchema>;

export type AgentCommand = typeof agentCommands.$inferSelect;
export type InsertAgentCommand = z.infer<typeof insertAgentCommandSchema>;
