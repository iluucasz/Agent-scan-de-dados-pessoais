import { db } from '../db';
import { areas, areaHierarchy } from '../../schemas/areas.schema';
import { processos } from '../../schemas/processos.schema';
import { eq, and, sql, inArray, isNull } from 'drizzle-orm';
import { InsertArea, UpdateArea, Area, AreaWithChildren } from '../../schemas/areas.schema';

export class AreasService {
  async list(): Promise<Area[]> {
    return await db
      .select()
      .from(areas)
      .where(eq(areas.isActive, true))
      .orderBy(areas.level, areas.name);
  }

  async create(data: InsertArea): Promise<Area> {
    // Validar se parentId pertence à mesma organização
    if (data.parentId) {
      const parent = await this.getById(data.parentId);
      if (parent.organizationId !== data.organizationId) {
        throw new Error('Área pai deve pertencer à mesma organização');
      }
      // Validação: não permitir mais de 5 níveis
      if (parent.level >= 4) {
        throw new Error('Profundidade máxima de hierarquia atingida (5 níveis)');
      }
    }

    const [area] = await db.insert(areas).values(data).returning();
    if (!area) {
      throw new Error("Erro ao criar área");
    }
    return area;
  }

  async getById(id: number): Promise<Area> {
    const [area] = await db
      .select()
      .from(areas)
      .where(eq(areas.id, id));
    if (!area) {
      throw new Error("Área não encontrada");
    }
    return area;
  }

  async findByOrganization(organizationId: number): Promise<Area[]> {
    return await db
      .select()
      .from(areas)
      .where(and(eq(areas.organizationId, organizationId), eq(areas.isActive, true)))
      .orderBy(areas.level, areas.name);
  }

  async update(id: number, data: UpdateArea): Promise<Area> {
    // Validar se não está tentando se tornar filho de si mesmo
    if (data.parentId === id) {
      throw new Error('Uma área não pode ser filha de si mesma');
    }

    // Validar se não está criando ciclo
    if (data.parentId) {
      const descendants = await this.getDescendantIds(id);
      if (descendants.includes(data.parentId)) {
        throw new Error('Não é possível mover uma área para dentro de suas próprias filhas (ciclo detectado)');
      }

      // Validar organização
      const parent = await this.getById(data.parentId);
      const current = await this.getById(id);
      if (parent.organizationId !== current.organizationId) {
        throw new Error('Área pai deve pertencer à mesma organização');
      }
    }

    const [area] = await db
      .update(areas)
      .set({ ...data, updatedAt: new Date() })
      .where(eq(areas.id, id))
      .returning();
    if (!area) {
      throw new Error("Área não encontrada");
    }
    return area;
  }

  async delete(id: number, cascade: boolean = false): Promise<void> {
    const children = await this.getDirectChildren(id);
    
    if (children.length > 0 && !cascade) {
      throw new Error(
        `Área possui ${children.length} sub-área(s). ` +
        `Delete as sub-áreas primeiro ou use cascade=true`
      );
    }

    // Soft delete da área principal
    await db
      .update(areas)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(areas.id, id));

    // Se cascade, deletar TODOS os descendentes (recursivo)
    if (cascade && children.length > 0) {
      const descendants = await this.getDescendants(id);
      if (descendants.length > 0) {
        const descendantIds = descendants.map(d => d.id);
        await db
          .update(areas)
          .set({ isActive: false, updatedAt: new Date() })
          .where(inArray(areas.id, descendantIds));
      }
    }
  }

  async getAreasWithProcessos(organizationId: number) {
    return await db
      .select({
        area: areas,
        processo: processos
      })
      .from(areas)
      .leftJoin(processos, and(
        eq(areas.id, processos.areaId),
        eq(processos.isActive, true)
      ))
      .where(and(
        eq(areas.organizationId, organizationId),
        eq(areas.isActive, true)
      ))
      .orderBy(areas.level, areas.name, processos.name);
  }

  // ========================================
  // NOVOS MÉTODOS (hierarquia)
  // ========================================

  /**
   * Listar apenas áreas raiz (sem pai) de uma organização
   */
  async getRootAreas(organizationId: number): Promise<Area[]> {
    return await db
      .select()
      .from(areas)
      .where(and(
        eq(areas.organizationId, organizationId),
        eq(areas.isActive, true),
        isNull(areas.parentId)
      ))
      .orderBy(areas.name);
  }

  /**
   * Listar áreas filhas diretas de uma área
   */
  async getDirectChildren(parentId: number): Promise<Area[]> {
    return await db
      .select()
      .from(areas)
      .where(and(
        eq(areas.parentId, parentId),
        eq(areas.isActive, true)
      ))
      .orderBy(areas.name);
  }

  /**
   * Buscar todas as áreas descendentes (filhas, netas, bisnetas...)
   */
  async getDescendants(areaId: number): Promise<Area[]> {
    const result = await db
      .select({
        area: areas,
        depth: areaHierarchy.depth
      })
      .from(areaHierarchy)
      .innerJoin(areas, eq(areaHierarchy.descendantId, areas.id))
      .where(and(
        eq(areaHierarchy.ancestorId, areaId),
        sql`${areaHierarchy.depth} > 0`,
        eq(areas.isActive, true)
      ))
      .orderBy(areaHierarchy.depth, areas.name);

    return result.map(r => r.area);
  }

  /**
   * Buscar apenas IDs dos descendentes (útil para validações)
   */
  async getDescendantIds(areaId: number): Promise<number[]> {
    const descendants = await db
      .select({ id: areas.id })
      .from(areaHierarchy)
      .innerJoin(areas, eq(areaHierarchy.descendantId, areas.id))
      .where(and(
        eq(areaHierarchy.ancestorId, areaId),
        sql`${areaHierarchy.depth} > 0`
      ));

    return descendants.map(d => d.id);
  }

  /**
   * Buscar caminho completo de uma área (breadcrumb)
   */
  async getAreaPath(areaId: number): Promise<Area[]> {
    const result = await db
      .select({
        area: areas,
        depth: areaHierarchy.depth
      })
      .from(areaHierarchy)
      .innerJoin(areas, eq(areaHierarchy.ancestorId, areas.id))
      .where(and(
        eq(areaHierarchy.descendantId, areaId),
        eq(areas.isActive, true)
      ))
      .orderBy(areaHierarchy.depth);

    return result.map(r => r.area);
  }

  /**
   * Buscar árvore hierárquica completa de uma organização
   */
  async getAreaTree(organizationId: number): Promise<AreaWithChildren[]> {
    // Buscar todas as áreas da organização
    const allAreas = await db
      .select()
      .from(areas)
      .where(and(
        eq(areas.organizationId, organizationId),
        eq(areas.isActive, true)
      ))
      .orderBy(areas.level, areas.name);

    // Construir mapa de áreas
    const areaMap = new Map<number, AreaWithChildren>();
    const rootAreas: AreaWithChildren[] = [];

    // Inicializar mapa
    allAreas.forEach(area => {
      areaMap.set(area.id, { 
        ...area, 
        children: [],
        childCount: 0
      });
    });

    // Construir hierarquia
    allAreas.forEach(area => {
      const areaWithChildren = areaMap.get(area.id)!;
      
      if (area.parentId === null) {
        rootAreas.push(areaWithChildren);
      } else {
        const parent = areaMap.get(area.parentId);
        if (parent) {
          parent.children.push(areaWithChildren);
          parent.childCount = (parent.childCount || 0) + 1;
        }
      }
    });

    return rootAreas;
  }

  /**
   * Contar áreas filhas diretas
   */
  async countChildren(areaId: number): Promise<number> {
    const result = await db
      .select({ count: sql<number>`count(*)` })
      .from(areas)
      .where(and(
        eq(areas.parentId, areaId),
        eq(areas.isActive, true)
      ));

    return Number(result[0]?.count || 0);
  }

  /**
   * Verificar se área é folha (não tem filhas)
   */
  async isLeafArea(areaId: number): Promise<boolean> {
    const count = await this.countChildren(areaId);
    return count === 0;
  }
}
