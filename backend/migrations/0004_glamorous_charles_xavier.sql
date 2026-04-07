CREATE TABLE "data_inventory" (
	"id" serial PRIMARY KEY NOT NULL,
	"scan_result_id" integer NOT NULL,
	"organization_id" integer NOT NULL,
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
CREATE TABLE "data_scan_configs" (
	"id" serial PRIMARY KEY NOT NULL,
	"organization_id" integer NOT NULL,
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
	"config_id" integer NOT NULL,
	"organization_id" integer NOT NULL,
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
	"job_id" integer NOT NULL,
	"organization_id" integer NOT NULL,
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
ALTER TABLE "data_inventory" ADD CONSTRAINT "data_inventory_scan_result_id_data_scan_results_id_fk" FOREIGN KEY ("scan_result_id") REFERENCES "public"."data_scan_results"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_inventory" ADD CONSTRAINT "data_inventory_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_scan_configs" ADD CONSTRAINT "data_scan_configs_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_scan_jobs" ADD CONSTRAINT "data_scan_jobs_config_id_data_scan_configs_id_fk" FOREIGN KEY ("config_id") REFERENCES "public"."data_scan_configs"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_scan_jobs" ADD CONSTRAINT "data_scan_jobs_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_scan_results" ADD CONSTRAINT "data_scan_results_job_id_data_scan_jobs_id_fk" FOREIGN KEY ("job_id") REFERENCES "public"."data_scan_jobs"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_scan_results" ADD CONSTRAINT "data_scan_results_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;