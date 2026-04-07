import { pgEnum, pgTable, uuid, text, timestamp } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";
import { users } from "./users.schema";

export const authTokenPurposeEnum = pgEnum('auth_token_purpose', [
  'MAGIC_LOGIN',
  'INVITE',
  'VERIFY_EMAIL',
  'LOGIN_OTP',
  'RESET_PASSWORD',
]);

export const authTokens = pgTable('auth_tokens', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').references(() => users.id),
  email: text('email').notNull(),
  purpose: authTokenPurposeEnum('purpose').notNull(),
  tokenHash: text('token_hash').notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  usedAt: timestamp('used_at', { withTimezone: true }),
  ip: text('ip'),
  userAgent: text('user_agent'),
  createdAt: timestamp('created_at').defaultNow(),
});

export const insertAuthTokenSchema = createInsertSchema(authTokens).omit({ id: true, createdAt: true });
export type InsertAuthToken = z.infer<typeof insertAuthTokenSchema>;
