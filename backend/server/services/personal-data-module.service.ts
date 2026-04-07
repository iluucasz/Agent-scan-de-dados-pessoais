import { db } from "../db";
import { eq } from "drizzle-orm";
import { dataItems } from "../../schemas/personal-data-module.schema";
import { calculateDataStats } from '../scanStatsUtils';
import type { DataItem, InsertDataItem } from '../../schemas/personal-data-module.schema';

export class PersonalDataModuleService {
  async getAll(organizationId?: number): Promise<DataItem[]> {
    if (organizationId) {
      return (await db.select().from(dataItems).where(eq(dataItems.organizationId, organizationId))) as any as DataItem[];
    }
    return (await db.select().from(dataItems)) as any as DataItem[];
  }

  async getStats(organizationId?: number): Promise<any> {
    const dataItemsList = await this.getAll(organizationId);
    
    // Mapear DataItem[] para ValidatedPersonalData[] para compatibilidade
    const mappedData = dataItemsList.map(item => ({
      name: item.description || 'Sem descrição',
      category: item.category || 'personal_data',
      sensitivityLevel: item.criticality || 'medium',
      dataType: item.type || 'unknown',
      source: item.source || 'internal',
      status: 'active', // Valor padrão, pois não existe no schema
      retentionPolicy: item.deletionPolicy || undefined,
      protectionMethod: item.protectionMeasures || undefined,
      storageLocation: item.storageLocation || undefined,
      consentStatus: item.consent ? 'granted' : 'not_granted',
      sizeBytes: 0 // Valor padrão
    }));
    
    const stats = calculateDataStats(mappedData);
    // Você pode buscar a organização via ORM se necessário
    return {
      ...stats,
      organizationId
    };
  }

  async getById(id: number): Promise<DataItem | undefined> {
    const result = await db.select().from(dataItems).where(eq(dataItems.id, id));
    return (result[0] as any) as DataItem;
  }

  async create(data: InsertDataItem & { organizationId?: number }): Promise<DataItem> {
    const inserted = await db.insert(dataItems).values(data).returning();
    return (inserted[0] as any) as DataItem;
  }

  async update(id: number, data: Partial<InsertDataItem>): Promise<DataItem | undefined> {
    const updated = await db.update(dataItems).set(data).where(eq(dataItems.id, id)).returning();
    return (updated[0] as any) as DataItem;
  }

  async delete(id: number): Promise<boolean> {
    const deleted = await db.delete(dataItems).where(eq(dataItems.id, id)).returning();
    return deleted.length > 0;
  }
} 