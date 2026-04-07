CREATE TYPE "public"."agent_activity_type" AS ENUM('scan_started', 'scan_completed', 'scan_failed', 'update_available', 'update_installed', 'configuration_changed', 'error');--> statement-breakpoint
CREATE TYPE "public"."agent_architecture" AS ENUM('x86', 'x64', 'arm64', 'arm32');--> statement-breakpoint
CREATE TYPE "public"."agent_platform" AS ENUM('windows', 'macos', 'linux', 'android', 'ios');--> statement-breakpoint
CREATE TYPE "public"."agent_status" AS ENUM('pending', 'active', 'inactive', 'error');--> statement-breakpoint
CREATE TYPE "public"."data_category" AS ENUM('personal_data', 'sensitive_data', 'anonymous_data', 'pseudonymized_data');--> statement-breakpoint
CREATE TYPE "public"."data_criticality" AS ENUM('high', 'medium', 'low');--> statement-breakpoint
CREATE TYPE "public"."data_source" AS ENUM('internal', 'external_direct', 'external_third_party');--> statement-breakpoint
CREATE TYPE "public"."data_source_type" AS ENUM('database', 'file', 'api', 'directory');--> statement-breakpoint
CREATE TYPE "public"."data_subcategory" AS ENUM('identification', 'financial', 'health', 'biometric', 'location', 'professional', 'behavioral');--> statement-breakpoint
CREATE TYPE "public"."document_type" AS ENUM('specification', 'user_guide', 'technical_doc', 'release_note', 'best_practice', 'tutorial', 'api_doc', 'security_guideline', 'compliance_guideline');--> statement-breakpoint
CREATE TYPE "public"."legal_basis" AS ENUM('consent', 'legal_obligation', 'contract_execution', 'legitimate_interest', 'credit_protection', 'life_protection', 'research', 'public_policy');--> statement-breakpoint
CREATE TYPE "public"."module_access" AS ENUM('data_mapping', 'risk_management', 'data_scanning', 'reports', 'documentation', 'admin');--> statement-breakpoint
CREATE TYPE "public"."organization_type" AS ENUM('consultoria', 'empresa', 'filial', 'departamento');--> statement-breakpoint
CREATE TYPE "public"."platform_component" AS ENUM('frontend', 'backend', 'database', 'api', 'electron_client', 'authentication', 'data_scanner', 'data_mapping', 'reporting', 'compliance_module', 'full_platform');--> statement-breakpoint
CREATE TYPE "public"."policy_status" AS ENUM('active', 'inactive', 'draft', 'archived');--> statement-breakpoint
CREATE TYPE "public"."policy_type" AS ENUM('data_protection', 'information_security', 'data_retention', 'data_sharing', 'data_breach', 'cookie_policy', 'access_control', 'privacy_policy', 'other');--> statement-breakpoint
CREATE TYPE "public"."risk_category" AS ENUM('security', 'compliance', 'operational', 'financial', 'reputation', 'strategic');--> statement-breakpoint
CREATE TYPE "public"."risk_impact" AS ENUM('negligible', 'minor', 'moderate', 'major', 'severe');--> statement-breakpoint
CREATE TYPE "public"."risk_likelihood" AS ENUM('rare', 'unlikely', 'possible', 'likely', 'almost_certain');--> statement-breakpoint
CREATE TYPE "public"."risk_status" AS ENUM('identified', 'assessed', 'mitigated', 'accepted', 'transferred', 'resolved');--> statement-breakpoint
CREATE TYPE "public"."role" AS ENUM('admin', 'agent', 'client', 'dpo');--> statement-breakpoint
CREATE TYPE "public"."scan_status" AS ENUM('pending', 'in_progress', 'completed', 'failed');--> statement-breakpoint
CREATE TYPE "public"."subscription_plan" AS ENUM('free', 'basic', 'professional', 'enterprise', 'custom');--> statement-breakpoint
CREATE TABLE "access_profiles" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"name" text NOT NULL,
	"description" text,
	"is_default" boolean DEFAULT false,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "agent_activities" (
	"id" serial PRIMARY KEY NOT NULL,
	"agent_id" text,
	"activity_type" "agent_activity_type" NOT NULL,
	"details" json,
	"status" text DEFAULT 'success' NOT NULL,
	"timestamp" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "agent_commands" (
	"id" serial PRIMARY KEY NOT NULL,
	"agent_id" text,
	"command" text NOT NULL,
	"parameters" json,
	"status" text DEFAULT 'pending' NOT NULL,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"delivered_at" timestamp,
	"executed_at" timestamp,
	"result" json
);
--> statement-breakpoint
CREATE TABLE "agent_versions" (
	"id" serial PRIMARY KEY NOT NULL,
	"version" text NOT NULL,
	"platform" "agent_platform" NOT NULL,
	"architecture" "agent_architecture" NOT NULL,
	"file_url" text NOT NULL,
	"checksum" text NOT NULL,
	"release_notes" text,
	"release_date" timestamp NOT NULL,
	"is_active" boolean DEFAULT true,
	"min_system_requirements" json,
	"file_size" integer NOT NULL,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "data_inventory" (
	"id" serial PRIMARY KEY NOT NULL,
	"scan_result_id" integer,
	"organization_id" integer,
	"data_type" text NOT NULL,
	"display_name" text,
	"value" text,
	"category" "data_category" DEFAULT 'personal_data',
	"subcategory" "data_subcategory" DEFAULT 'identification',
	"criticality" "data_criticality" DEFAULT 'medium',
	"context" text,
	"source" text,
	"file_name" text,
	"file_path" text,
	"line" integer,
	"confidence" text,
	"last_scanned" timestamp DEFAULT now(),
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "data_items" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"identifier" text NOT NULL,
	"description" text NOT NULL,
	"type" text NOT NULL,
	"category" "data_category" NOT NULL,
	"subcategory" "data_subcategory",
	"criticality" "data_criticality" NOT NULL,
	"source" "data_source" NOT NULL,
	"collection_channel" text,
	"storage_location" text,
	"storage_ip_address" text,
	"processing_purpose" text NOT NULL,
	"associated_processes" text,
	"processing_operation" text,
	"consent" boolean,
	"legal_basis" "legal_basis" NOT NULL,
	"security_level" text,
	"protection_measures" text,
	"internal_access" text,
	"third_party_sharing" text,
	"access_history" text,
	"retention_period" integer,
	"deletion_policy" text,
	"collection_date" timestamp,
	"last_updated" timestamp DEFAULT now(),
	"responsible_party" text,
	"change_log" json,
	"risk_assessment" json,
	"mitigation_measures" text,
	"potential_impact" text,
	"additional_notes" text,
	"references" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "data_processing_agents" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"name" text NOT NULL,
	"description" text,
	"contact" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "data_scan_configs" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"name" text NOT NULL,
	"description" text,
	"source_type" "data_source_type" NOT NULL,
	"connection_config" json NOT NULL,
	"scan_pattern" json,
	"scan_schedule" text,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "data_scan_jobs" (
	"id" serial PRIMARY KEY NOT NULL,
	"config_id" integer,
	"organization_id" integer,
	"status" "scan_status" NOT NULL,
	"started_at" timestamp,
	"completed_at" timestamp,
	"found_items" json,
	"stats" json,
	"error" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "data_scan_results" (
	"id" serial PRIMARY KEY NOT NULL,
	"job_id" integer,
	"organization_id" integer,
	"name" text NOT NULL,
	"description" text,
	"source" text,
	"scan_type" text,
	"item_count" integer DEFAULT 0,
	"completed_at" timestamp,
	"risk_analysis" json,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "departments" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"head_user_id" text,
	"parent_department_id" integer,
	"is_active" boolean DEFAULT true,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "installed_agents" (
	"id" serial PRIMARY KEY NOT NULL,
	"agent_id" text NOT NULL,
	"organization_id" integer,
	"agent_version_id" integer,
	"device_name" text NOT NULL,
	"device_type" text NOT NULL,
	"platform" "agent_platform" NOT NULL,
	"architecture" "agent_architecture" NOT NULL,
	"ip_address" text,
	"mac_address" text,
	"last_check_in" timestamp,
	"status" "agent_status" DEFAULT 'pending',
	"error_message" text,
	"configuration" json,
	"activation_code" text,
	"is_activated" boolean DEFAULT false,
	"activated_at" timestamp,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now(),
	CONSTRAINT "installed_agents_agent_id_unique" UNIQUE("agent_id")
);
--> statement-breakpoint
CREATE TABLE "it_assets" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"name" text NOT NULL,
	"type" text NOT NULL,
	"description" text,
	"location" text,
	"owner" text,
	"data_classifications" json,
	"security_measures" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "organization_relationships" (
	"id" serial PRIMARY KEY NOT NULL,
	"primary_organization_id" integer NOT NULL,
	"secondary_organization_id" integer NOT NULL,
	"relationship_type" text DEFAULT 'client' NOT NULL,
	"start_date" timestamp DEFAULT now() NOT NULL,
	"end_date" timestamp,
	"contract_details" json,
	"created_by" text,
	"is_active" boolean DEFAULT true,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "organization_subscriptions" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer NOT NULL,
	"plan_id" integer NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"start_date" timestamp,
	"end_date" timestamp,
	"renewal_date" timestamp,
	"canceled_date" timestamp,
	"cancel_reason" text,
	"is_autorenewal" boolean DEFAULT true,
	"custom_price" integer,
	"custom_features" json,
	"payment_gateway" text,
	"payment_gateway_customer_id" text,
	"payment_gateway_subscription_id" text,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "organizations" (
	"id" serial PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"logo_url" text,
	"type" "organization_type" DEFAULT 'empresa' NOT NULL,
	"parent_id" integer,
	"cnpj" text,
	"address" text,
	"city" text,
	"state" text,
	"country" text DEFAULT 'Brasil',
	"postal_code" text,
	"phone" text,
	"website" text,
	"subscription_plan" "subscription_plan" DEFAULT 'free',
	"subscription_start" timestamp,
	"subscription_end" timestamp,
	"payment_status" text DEFAULT 'pending',
	"enabled_modules" json,
	"max_users" integer,
	"max_storage" integer,
	"created_by" text,
	"is_active" boolean DEFAULT true,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "permissions" (
	"id" serial PRIMARY KEY NOT NULL,
	"profile_id" integer,
	"resource_type" text NOT NULL,
	"action" text NOT NULL,
	"constraints" json,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "platform_documents" (
	"id" serial PRIMARY KEY NOT NULL,
	"title" text NOT NULL,
	"document_type" "document_type" NOT NULL,
	"component" "platform_component" NOT NULL,
	"version" text,
	"content" text NOT NULL,
	"summary" text,
	"related_features" json,
	"attachments" json,
	"tags" json,
	"is_public" boolean DEFAULT false,
	"published_at" timestamp,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "platform_features" (
	"id" serial PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"description" text NOT NULL,
	"component" "platform_component" NOT NULL,
	"introduced_in_version" text NOT NULL,
	"current_status" text DEFAULT 'active' NOT NULL,
	"screenshots" json,
	"demo_url" text,
	"technical_details" text,
	"security_implications" text,
	"best_practices" text,
	"api_endpoints" json,
	"tags" json,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "platform_modules" (
	"id" serial PRIMARY KEY NOT NULL,
	"code" text NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"is_core" boolean DEFAULT false,
	"dependencies" json,
	"min_plan_level" text,
	"is_active" boolean DEFAULT true,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now(),
	CONSTRAINT "platform_modules_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE "platform_roadmap" (
	"id" serial PRIMARY KEY NOT NULL,
	"title" text NOT NULL,
	"description" text NOT NULL,
	"component" "platform_component",
	"planned_version" text,
	"status" text DEFAULT 'planned' NOT NULL,
	"priority" text DEFAULT 'medium' NOT NULL,
	"start_date" timestamp,
	"target_completion_date" timestamp,
	"actual_completion_date" timestamp,
	"justification" text,
	"business_impact" text,
	"technical_impact" text,
	"dependencies" json,
	"tags" json,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "platform_versions" (
	"id" serial PRIMARY KEY NOT NULL,
	"version_number" text NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"release_date" timestamp NOT NULL,
	"is_stable" boolean DEFAULT true,
	"is_maintained" boolean DEFAULT true,
	"end_of_support_date" timestamp,
	"release_notes" text,
	"changelog" json NOT NULL,
	"tags" json,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now(),
	CONSTRAINT "platform_versions_version_number_unique" UNIQUE("version_number")
);
--> statement-breakpoint
CREATE TABLE "policies" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"name" text NOT NULL,
	"description" text,
	"type" "policy_type" NOT NULL,
	"status" "policy_status" DEFAULT 'active' NOT NULL,
	"content" text NOT NULL,
	"version" text NOT NULL,
	"effective_date" timestamp NOT NULL,
	"expiration_date" timestamp,
	"approved_by" text,
	"created_by" text,
	"tags" json,
	"attachments" json,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "policy_rules" (
	"id" serial PRIMARY KEY NOT NULL,
	"policy_id" integer NOT NULL,
	"organization_id" integer,
	"section" text NOT NULL,
	"title" text NOT NULL,
	"description" text NOT NULL,
	"detection_rules" json NOT NULL,
	"recommended_action" text,
	"severity" text NOT NULL,
	"is_active" boolean DEFAULT true,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "policy_violations" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"data_item_id" integer NOT NULL,
	"policy_rule_id" integer NOT NULL,
	"detected_at" timestamp DEFAULT now(),
	"status" text DEFAULT 'active' NOT NULL,
	"fixed_at" timestamp,
	"fixed_by" text,
	"notes" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "reports" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"name" text NOT NULL,
	"type" text NOT NULL,
	"created_by" text,
	"generated_at" timestamp DEFAULT now(),
	"parameters" json,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "risk_assessment_items" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"assessment_id" integer NOT NULL,
	"risk_id" integer NOT NULL,
	"prior_likelihood" "risk_likelihood",
	"prior_impact" "risk_impact",
	"new_likelihood" "risk_likelihood" NOT NULL,
	"new_impact" "risk_impact" NOT NULL,
	"justification" text,
	"mitigation_recommendations" text,
	"notes" text,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "risk_assessments" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"name" text NOT NULL,
	"description" text,
	"assessment_date" timestamp DEFAULT now(),
	"assessment_type" text NOT NULL,
	"methodology" text,
	"scope" text NOT NULL,
	"conductor" text,
	"reviewers" json,
	"conclusion" text,
	"recommendations" text,
	"attachments" json,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "risk_mitigation_controls" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"risk_id" integer NOT NULL,
	"standard_control_id" integer,
	"name" text NOT NULL,
	"description" text NOT NULL,
	"control_type" text NOT NULL,
	"implementation_status" text NOT NULL,
	"effectiveness" text,
	"cost_benefit" text,
	"implementation_date" timestamp,
	"verification_date" timestamp,
	"responsible_party" text,
	"evidences" json,
	"notes" text,
	"ai_recommendations" text,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "risk_standard_controls" (
	"id" serial PRIMARY KEY NOT NULL,
	"standard_id" integer NOT NULL,
	"control_id" text NOT NULL,
	"name" text NOT NULL,
	"description" text NOT NULL,
	"category" text NOT NULL,
	"implementation_guidance" text,
	"verification_criteria" text,
	"related_controls" json,
	"is_required" boolean DEFAULT true,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "risk_standards" (
	"id" serial PRIMARY KEY NOT NULL,
	"code" text NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"version" text NOT NULL,
	"category" text NOT NULL,
	"scope" text NOT NULL,
	"published_at" timestamp,
	"is_active" boolean DEFAULT true,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "risk_types" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"name" text NOT NULL,
	"description" text,
	"category" "risk_category" NOT NULL,
	"default_likelihood" "risk_likelihood",
	"default_impact" "risk_impact",
	"is_custom" boolean DEFAULT false,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "risks" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer,
	"type_id" integer,
	"title" text NOT NULL,
	"description" text NOT NULL,
	"likelihood" "risk_likelihood" NOT NULL,
	"impact" "risk_impact" NOT NULL,
	"category" "risk_category" NOT NULL,
	"status" "risk_status" DEFAULT 'identified' NOT NULL,
	"identified_date" timestamp DEFAULT now(),
	"assessed_date" timestamp,
	"resolved_date" timestamp,
	"due_date" timestamp,
	"owner" text,
	"data_items" json,
	"it_assets" json,
	"standard_controls" json,
	"threat_sources" text,
	"vulnerabilities" text,
	"potential_impact" text,
	"risk_score" integer,
	"inherent_risk_score" integer,
	"residual_risk_score" integer,
	"acceptance_justification" text,
	"ai_analysis" json,
	"created_by" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "subscription_invoices" (
	"id" serial PRIMARY KEY NOT NULL,
	"subscription_id" integer NOT NULL,
	"organization_id" integer NOT NULL,
	"invoice_number" text NOT NULL,
	"amount" integer NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"due_date" timestamp NOT NULL,
	"paid_date" timestamp,
	"payment_method" text,
	"payment_gateway_invoice_id" text,
	"invoice_url" text,
	"period_start" timestamp NOT NULL,
	"period_end" timestamp NOT NULL,
	"issued_at" timestamp DEFAULT now(),
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "subscription_plans" (
	"id" serial PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"code" text NOT NULL,
	"display_name" text NOT NULL,
	"description" text,
	"type" "subscription_plan" NOT NULL,
	"price" integer NOT NULL,
	"billing_cycle" text DEFAULT 'monthly' NOT NULL,
	"features" json NOT NULL,
	"enabled_modules" json NOT NULL,
	"max_users" integer NOT NULL,
	"max_storage" integer NOT NULL,
	"max_organizations" integer NOT NULL,
	"is_active" boolean DEFAULT true,
	"is_hidden" boolean DEFAULT false,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now(),
	CONSTRAINT "subscription_plans_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE "user_departments" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"department_id" integer NOT NULL,
	"is_primary" boolean DEFAULT false,
	"assigned_by" text,
	"assigned_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "user_profiles" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"profile_id" integer NOT NULL,
	"assigned_by" text,
	"assigned_at" timestamp DEFAULT now()
);
--> statement-breakpoint
ALTER TABLE "access_profiles" ADD CONSTRAINT "access_profiles_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "agent_activities" ADD CONSTRAINT "agent_activities_agent_id_installed_agents_agent_id_fk" FOREIGN KEY ("agent_id") REFERENCES "public"."installed_agents"("agent_id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "agent_commands" ADD CONSTRAINT "agent_commands_agent_id_installed_agents_agent_id_fk" FOREIGN KEY ("agent_id") REFERENCES "public"."installed_agents"("agent_id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_inventory" ADD CONSTRAINT "data_inventory_scan_result_id_data_scan_results_id_fk" FOREIGN KEY ("scan_result_id") REFERENCES "public"."data_scan_results"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_inventory" ADD CONSTRAINT "data_inventory_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_items" ADD CONSTRAINT "data_items_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_processing_agents" ADD CONSTRAINT "data_processing_agents_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_scan_configs" ADD CONSTRAINT "data_scan_configs_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_scan_jobs" ADD CONSTRAINT "data_scan_jobs_config_id_data_scan_configs_id_fk" FOREIGN KEY ("config_id") REFERENCES "public"."data_scan_configs"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_scan_jobs" ADD CONSTRAINT "data_scan_jobs_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_scan_results" ADD CONSTRAINT "data_scan_results_job_id_data_scan_jobs_id_fk" FOREIGN KEY ("job_id") REFERENCES "public"."data_scan_jobs"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_scan_results" ADD CONSTRAINT "data_scan_results_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "departments" ADD CONSTRAINT "departments_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "departments" ADD CONSTRAINT "departments_parent_department_id_departments_id_fk" FOREIGN KEY ("parent_department_id") REFERENCES "public"."departments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "installed_agents" ADD CONSTRAINT "installed_agents_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "installed_agents" ADD CONSTRAINT "installed_agents_agent_version_id_agent_versions_id_fk" FOREIGN KEY ("agent_version_id") REFERENCES "public"."agent_versions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "it_assets" ADD CONSTRAINT "it_assets_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "organization_relationships" ADD CONSTRAINT "organization_relationships_primary_organization_id_organizations_id_fk" FOREIGN KEY ("primary_organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "organization_relationships" ADD CONSTRAINT "organization_relationships_secondary_organization_id_organizations_id_fk" FOREIGN KEY ("secondary_organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "organization_subscriptions" ADD CONSTRAINT "organization_subscriptions_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "organization_subscriptions" ADD CONSTRAINT "organization_subscriptions_plan_id_subscription_plans_id_fk" FOREIGN KEY ("plan_id") REFERENCES "public"."subscription_plans"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "organizations" ADD CONSTRAINT "organizations_parent_id_organizations_id_fk" FOREIGN KEY ("parent_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "permissions" ADD CONSTRAINT "permissions_profile_id_access_profiles_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."access_profiles"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "policies" ADD CONSTRAINT "policies_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "policy_rules" ADD CONSTRAINT "policy_rules_policy_id_policies_id_fk" FOREIGN KEY ("policy_id") REFERENCES "public"."policies"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "policy_rules" ADD CONSTRAINT "policy_rules_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "policy_violations" ADD CONSTRAINT "policy_violations_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "policy_violations" ADD CONSTRAINT "policy_violations_data_item_id_data_items_id_fk" FOREIGN KEY ("data_item_id") REFERENCES "public"."data_items"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "policy_violations" ADD CONSTRAINT "policy_violations_policy_rule_id_policy_rules_id_fk" FOREIGN KEY ("policy_rule_id") REFERENCES "public"."policy_rules"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "reports" ADD CONSTRAINT "reports_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "risk_assessment_items" ADD CONSTRAINT "risk_assessment_items_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "risk_assessment_items" ADD CONSTRAINT "risk_assessment_items_assessment_id_risk_assessments_id_fk" FOREIGN KEY ("assessment_id") REFERENCES "public"."risk_assessments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "risk_assessment_items" ADD CONSTRAINT "risk_assessment_items_risk_id_risks_id_fk" FOREIGN KEY ("risk_id") REFERENCES "public"."risks"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "risk_assessments" ADD CONSTRAINT "risk_assessments_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "risk_mitigation_controls" ADD CONSTRAINT "risk_mitigation_controls_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "risk_mitigation_controls" ADD CONSTRAINT "risk_mitigation_controls_risk_id_risks_id_fk" FOREIGN KEY ("risk_id") REFERENCES "public"."risks"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "risk_mitigation_controls" ADD CONSTRAINT "risk_mitigation_controls_standard_control_id_risk_standard_controls_id_fk" FOREIGN KEY ("standard_control_id") REFERENCES "public"."risk_standard_controls"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "risk_standard_controls" ADD CONSTRAINT "risk_standard_controls_standard_id_risk_standards_id_fk" FOREIGN KEY ("standard_id") REFERENCES "public"."risk_standards"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "risk_types" ADD CONSTRAINT "risk_types_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "risks" ADD CONSTRAINT "risks_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "risks" ADD CONSTRAINT "risks_type_id_risk_types_id_fk" FOREIGN KEY ("type_id") REFERENCES "public"."risk_types"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "subscription_invoices" ADD CONSTRAINT "subscription_invoices_subscription_id_organization_subscriptions_id_fk" FOREIGN KEY ("subscription_id") REFERENCES "public"."organization_subscriptions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "subscription_invoices" ADD CONSTRAINT "subscription_invoices_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_departments" ADD CONSTRAINT "user_departments_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_departments" ADD CONSTRAINT "user_departments_department_id_departments_id_fk" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_profile_id_access_profiles_id_fk" FOREIGN KEY ("profile_id") REFERENCES "public"."access_profiles"("id") ON DELETE no action ON UPDATE no action;