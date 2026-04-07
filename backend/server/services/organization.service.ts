import { db } from "../db";
import { eq } from "drizzle-orm";
import { organizations } from "../../schemas/organization.schema";
import { users } from "../../schemas/users.schema";
import type { InsertOrganization, UpdateOrganization, Organization } from "../../schemas/organization.schema";

export class OrganizationService {
  async list(): Promise<any[]> {
    const orgs = await db.select().from(organizations);
    return orgs as any as Organization[];
  }

  async getById(id: number): Promise<any> {
    const resultRaw: any = await db.select().from(organizations).where(eq(organizations.id, id));
    const org = (resultRaw[0] as any) as Organization;
    if (!org) {
      throw new Error("Organização não encontrada");
    }
    return org;
  }

  async create(data: InsertOrganization): Promise<any> {
    const insertedRaw: any = await db.insert(organizations).values(data).returning();
    return (insertedRaw[0] as any) as Organization;
  }

  async update(
    id: number,
    data: UpdateOrganization
  ): Promise<any> {
    const updatedRaw: any = await db.update(organizations).set(data).where(eq(organizations.id, id)).returning();
    const org = (updatedRaw[0] as any) as Organization;
    if (!org) {
      throw new Error("Organização não encontrada");
    }
    return org;
  }

  async delete(id: number): Promise<void> {
    const result = await db.delete(organizations).where(eq(organizations.id, id)).execute();
    if (result.rowCount === 0) {
      throw new Error("Organização não encontrada");
    }
  }

  async setCurrentOrganization(userId: string, organizationId: number): Promise<{ currentOrganizationId: number }> {
    const [updated] = await db
      .update(users)
      .set({ currentOrganizationId: organizationId })
      .where(eq(users.id, userId))
      .returning({ currentOrganizationId: users.currentOrganizationId });

    if (!updated) {
      throw new Error('Usuário não encontrado');
    }
    return { currentOrganizationId: updated.currentOrganizationId! };
  }
} 