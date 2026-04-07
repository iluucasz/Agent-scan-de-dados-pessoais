import { Router } from "express";
import { db } from "../db";
import { eq, asc } from "drizzle-orm";
import { z } from "zod";
import {
  riskStandards,
  riskStandardControls,
  insertRiskStandardSchema,
  insertRiskStandardControlSchema
} from "../../schemas/schema";

const router = Router();

// Rotas públicas para normas ABNT ISO (sem autenticação)

// Obter todas as normas
router.get("/", async (req, res) => {
  try {
    const standards = await db.select().from(riskStandards).orderBy(asc(riskStandards.code));
    return res.json(standards);
  } catch (error) {
    console.error("Erro ao buscar normas:", error);
    return res.status(500).json({ error: "Erro ao buscar normas" });
  }
});

// Obter controles de uma norma específica
router.get("/:id/controls", async (req, res) => {
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

// Adicionar uma nova norma (requer autenticação via middleware)
router.post("/", async (req, res) => {
  try {
    // Requer autenticação verificada pelo middleware que registra esta rota
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

// Adicionar um controle a uma norma (requer autenticação via middleware)
router.post("/:id/controls", async (req, res) => {
  try {
    // Requer autenticação verificada pelo middleware que registra esta rota
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

export default router;