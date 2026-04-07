import { and, asc, desc, eq } from "drizzle-orm";
import { Router } from "express";
import { z } from "zod";
import {
  insertRiskMitigationControlSchema,
  insertRiskSchema,
  insertRiskStandardControlSchema,
  insertRiskStandardSchema,
  insertRiskTypeSchema,
  riskMitigationControls,
  risks,
  riskStandardControls,
  riskStandards,
  riskTypes
} from "../../schemas/schema";
import { db } from "../db";

// Extend o Express.Request para incluir a propriedade user
declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string; // UUID
        organizationId: number;
        role: string;
      };
    }
  }
}

const router = Router();

// Rota para obter todos os tipos de riscos
router.get("/types", async (req, res) => {
  try {
    const orgId = 1;

    const types = await db.select()
      .from(riskTypes)
      .where(eq(riskTypes.organizationId, orgId))
      .orderBy(asc(riskTypes.name));
    
    return res.json(types);
  } catch (error) {
    console.error("Erro ao buscar tipos de riscos:", error);
    return res.status(500).json({ error: "Erro ao buscar tipos de riscos" });
  }
});

// Rota para criar um novo tipo de risco
router.post("/types", async (req, res) => {
  try {
    const orgId = req.user?.organizationId;
    const userId = req.user?.id;
    if (!orgId || !userId) return res.status(403).json({ error: "Acesso negado" });

    const validatedData = insertRiskTypeSchema.parse({
      ...req.body,
      organizationId: orgId,
      createdBy: userId
    });

    const [result] = await db.insert(riskTypes)
      .values(validatedData)
      .returning();
    
    return res.status(201).json(result);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: error.errors });
    }
    console.error("Erro ao criar tipo de risco:", error);
    return res.status(500).json({ error: "Erro ao criar tipo de risco" });
  }
});

// Rota para obter todos os riscos
router.get("/", async (req, res) => {
  try {
    const orgId = req.user?.organizationId;
    if (!orgId) return res.status(403).json({ error: "Acesso negado" });

    // Suporta filtragem por status e categoria
    const { status, category } = req.query;
    
    // Usamos condições para construir a consulta de forma segura
    // Construímos a condição base
    let conditions = eq(risks.organizationId, orgId!);
    
    // Adicionamos filtros condicionalmente
    if (status && typeof status === 'string') {
      conditions = and(conditions, eq(risks.status, status as any))!;
    }
    
    if (category && typeof category === 'string') {
      conditions = and(conditions, eq(risks.category, category as any))!;
    }
    
    // Executamos a query com todas as condições
    const query = db.select()
      .from(risks)
      .where(conditions)
    
    // Executamos a consulta com ordenação
    const results = await query.orderBy(desc(risks.createdAt));
    
    return res.json(results);
  } catch (error) {
    console.error("Erro ao buscar riscos:", error);
    return res.status(500).json({ error: "Erro ao buscar riscos" });
  }
});

// Rota para criar um novo risco
router.post("/", async (req, res) => {
  try {
    const orgId = req.user?.organizationId;
    const userId = req.user?.id;
    if (!orgId || !userId) return res.status(403).json({ error: "Acesso negado" });

    const validatedData = insertRiskSchema.parse({
      ...req.body,
      organizationId: orgId,
      createdBy: userId
    });

    const [result] = await db.insert(risks)
      .values(validatedData)
      .returning();
    
    return res.status(201).json(result);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: error.errors });
    }
    console.error("Erro ao criar risco:", error);
    return res.status(500).json({ error: "Erro ao criar risco" });
  }
});

// Rota para obter um risco específico
router.get("/:id", async (req, res) => {
  try {
    const orgId = req.user?.organizationId;
    if (!orgId) return res.status(403).json({ error: "Acesso negado" });

    const riskId = parseInt(req.params.id);
    
    const [risk] = await db.select()
      .from(risks)
      .where(and(
        eq(risks.id, riskId),
        eq(risks.organizationId, orgId!)
      ));
    
    if (!risk) {
      return res.status(404).json({ error: "Risco não encontrado" });
    }
    
    // Busca controles associados
    const controls = await db.select()
      .from(riskMitigationControls)
      .where(eq(riskMitigationControls.riskId, riskId));
    
    return res.json({ risk, controls });
  } catch (error) {
    console.error("Erro ao buscar risco:", error);
    return res.status(500).json({ error: "Erro ao buscar risco" });
  }
});

// Rota para atualizar um risco
router.patch("/:id", async (req, res) => {
  try {
    const orgId = req.user?.organizationId;
    if (!orgId) return res.status(403).json({ error: "Acesso negado" });

    const riskId = parseInt(req.params.id);
    
    // Verifica se o risco existe e pertence à organização
    const [existingRisk] = await db.select()
      .from(risks)
      .where(and(
        eq(risks.id, riskId),
        eq(risks.organizationId, orgId!)
      ));
    
    if (!existingRisk) {
      return res.status(404).json({ error: "Risco não encontrado" });
    }
    
    // Remove campos que não devem ser atualizados
    const { id, organizationId, createdBy, createdAt, ...updateData } = req.body;
    
    // Atualiza o risco
    const [updatedRisk] = await db.update(risks)
      .set({ ...updateData, updatedAt: new Date() })
      .where(eq(risks.id, riskId))
      .returning();
    
    return res.json(updatedRisk);
  } catch (error) {
    console.error("Erro ao atualizar risco:", error);
    return res.status(500).json({ error: "Erro ao atualizar risco" });
  }
});

// Rota para obter controles de mitigação de um risco
router.get("/:id/controls", async (req, res) => {
  try {
    const orgId = req.user?.organizationId;
    if (!orgId) return res.status(403).json({ error: "Acesso negado" });

    const riskId = parseInt(req.params.id);
    
    const controls = await db.select()
      .from(riskMitigationControls)
      .where(and(
        eq(riskMitigationControls.riskId, riskId),
        eq(riskMitigationControls.organizationId, orgId!)
      ));
    
    return res.json(controls);
  } catch (error) {
    console.error("Erro ao buscar controles:", error);
    return res.status(500).json({ error: "Erro ao buscar controles" });
  }
});

// Rota para adicionar um controle de mitigação
router.post("/:id/controls", async (req, res) => {
  try {
    const orgId = req.user?.organizationId;
    const userId = req.user?.id;
    if (!orgId || !userId) return res.status(403).json({ error: "Acesso negado" });

    const riskId = parseInt(req.params.id);
    
    // Verifica se o risco existe e pertence à organização
    const [existingRisk] = await db.select()
      .from(risks)
      .where(and(
        eq(risks.id, riskId),
        eq(risks.organizationId, orgId!)
      ));
    
    if (!existingRisk) {
      return res.status(404).json({ error: "Risco não encontrado" });
    }
    
    const validatedData = insertRiskMitigationControlSchema.parse({
      ...req.body,
      riskId,
      organizationId: orgId,
      createdBy: userId
    });

    const [result] = await db.insert(riskMitigationControls)
      .values(validatedData)
      .returning();
    
    return res.status(201).json(result);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: error.errors });
    }
    console.error("Erro ao criar controle:", error);
    return res.status(500).json({ error: "Erro ao criar controle" });
  }
});

// Rotas para normas ABNT ISO

// Obter todas as normas (públicas, sem autenticação)
router.get("/standards", async (req, res) => {
  try {
    const standards = await db.select().from(riskStandards).orderBy(asc(riskStandards.code));
    return res.json(standards);
  } catch (error) {
    console.error("Erro ao buscar normas:", error);
    return res.status(500).json({ error: "Erro ao buscar normas" });
  }
});

// Obter controles de uma norma específica (públicos, sem autenticação)
router.get("/standards/:id/controls", async (req, res) => {
  try {
    const standardId = parseInt(req.params.id);
    
    const controls = await db.select()
      .from(riskStandardControls)
      .where(eq(riskStandardControls.standardId, standardId))
      .orderBy(asc(riskStandardControls.controlId));
    
    return res.json(controls);
  } catch (error) {
    console.error("Erro ao buscar controles da norma:", error);
    return res.status(500).json({ error: "Erro ao buscar controles da norma" });
  }
});

// Adicionar uma nova norma
router.post("/standards", async (req, res) => {
  try {
    const validatedData = insertRiskStandardSchema.parse(req.body);

    const [result] = await db.insert(riskStandards)
      .values(validatedData)
      .returning();
    
    return res.status(201).json(result);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: error.errors });
    }
    console.error("Erro ao criar norma:", error);
    return res.status(500).json({ error: "Erro ao criar norma" });
  }
});

// Adicionar um controle a uma norma
router.post("/standards/:id/controls", async (req, res) => {
  try {
    const standardId = parseInt(req.params.id);
    
    // Verifica se a norma existe
    const [existingStandard] = await db.select()
      .from(riskStandards)
      .where(eq(riskStandards.id, standardId));
    
    if (!existingStandard) {
      return res.status(404).json({ error: "Norma não encontrada" });
    }
    
    const validatedData = insertRiskStandardControlSchema.parse({
      ...req.body,
      standardId
    });

    const [result] = await db.insert(riskStandardControls)
      .values(validatedData)
      .returning();
    
    return res.status(201).json(result);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: error.errors });
    }
    console.error("Erro ao criar controle da norma:", error);
    return res.status(500).json({ error: "Erro ao criar controle da norma" });
  }
});

// Rota para obter estatísticas de riscos
router.get("/stats", async (req, res) => {
  try {
    const orgId = 1; 

    const stats = {
      totalRisks: 0,
      byRiskLevel: {
        high: 0,
        medium: 0,
        low: 0,
        critical: 0
      },
      byCategory: {
        financial: 0,
        security: 0,
        compliance: 0,
        operational: 0,
        reputation: 0
      },
      byStatus: {
        'em_avaliacao': 0,
        'mitigado': 0,
        'aceito': 0,
        'evitado': 0,
        'transferido': 0,
        'pendente': 0
      },
      byLikelihood: {
        rare: 0,
        unlikely: 0,
        possible: 0,
        likely: 0,
        almost_certain: 0
      },
      byImpact: {
        negligible: 0,
        minor: 0,
        moderate: 0,
        significant: 0,
        severe: 0
      },
      riskScoreDistribution: {
        'baixo': 0,
        'médio': 0, 
        'alto': 0,
        'crítico': 0
      },
      trendsOverTime: []
    };

    return res.json(stats);
    
  } catch (error) {
    console.error("[RiskStats] Erro geral:", error);
    return res.status(500).json({ 
      error: "Erro ao obter estatísticas de riscos",
      details: error.message
    });
  }
});

// Função auxiliar para determinar o nível de risco baseado em likelihood e impact
function getRiskScore(likelihood: string, impact: string) {
  // Converte strings para valores numéricos
  const likelihoodMap: Record<string, number> = {
    rare: 1,
    unlikely: 2,
    possible: 3,
    likely: 4,
    almost_certain: 5
  };
  
  const impactMap: Record<string, number> = {
    negligible: 1,
    minor: 2,
    moderate: 3,
    major: 4,
    severe: 5
  };
  
  const likelihoodValue = likelihoodMap[likelihood] || 1;
  const impactValue = impactMap[impact] || 1;
  
  // Calcula a pontuação
  const score = likelihoodValue * impactValue;
  
  // Determina o nível baseado na pontuação
  if (score >= 15) {
    return { level: 'high', text: 'Alto', color: 'bg-red-100 text-red-800' };
  } else if (score >= 5) {
    return { level: 'medium', text: 'Médio', color: 'bg-amber-100 text-amber-800' };
  } else {
    return { level: 'low', text: 'Baixo', color: 'bg-green-100 text-green-800' };
  }
}

export default router;