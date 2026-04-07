import { db } from '../db';
import { processos } from '../../schemas/processos.schema';
import { eq, and } from 'drizzle-orm';
import { InsertProcesso, UpdateProcesso, Processo } from '../../schemas/processos.schema';

export class ProcessosService {
  async list(): Promise<Processo[]> {
    return await db
      .select()
      .from(processos)
      .where(eq(processos.isActive, true))
      .orderBy(processos.name);
  }

  async create(data: InsertProcesso): Promise<Processo> {
    const [processo] = await db.insert(processos).values(data).returning();
    if (!processo) {
      throw new Error("Erro ao criar processo");
    }
    return processo;
  }

  async getById(id: number): Promise<Processo> {
    const [processo] = await db
      .select()
      .from(processos)
      .where(eq(processos.id, id));
    if (!processo) {
      throw new Error("Processo não encontrado");
    }
    return processo;
  }

  async findByArea(areaId: number): Promise<Processo[]> {
    return await db
      .select()
      .from(processos)
      .where(and(eq(processos.areaId, areaId), eq(processos.isActive, true)))
      .orderBy(processos.name);
  }

  async findByOrganization(organizationId: number): Promise<Processo[]> {
    return await db
      .select()
      .from(processos)
      .where(and(eq(processos.organizationId, organizationId), eq(processos.isActive, true)))
      .orderBy(processos.name);
  }

  async update(id: number, data: UpdateProcesso): Promise<Processo> {
    const [processo] = await db
      .update(processos)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(processos.id, id))
      .returning();
    if (!processo) {
      throw new Error("Processo não encontrado");
    }
    return processo;
  }

  async delete(id: number): Promise<void> {
    // Soft delete
    const result = await db
      .update(processos)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(processos.id, id))
      .execute();
    if (result.rowCount === 0) {
      throw new Error("Processo não encontrado");
    }
  }
}
