import { pgTable, uuid, integer, boolean, timestamp } from 'drizzle-orm/pg-core';
import { users } from './users.schema';
import { organizations } from './organization.schema';

export const userManagedOrganizations = pgTable('user_managed_organizations', {
  userId: uuid('user_id').references(() => users.id).notNull(),
  organizationId: integer('organization_id').references(() => organizations.id).notNull(),
  isPrimary: boolean('is_primary').default(false),
  assignedAt: timestamp('assigned_at').defaultNow(),
});
