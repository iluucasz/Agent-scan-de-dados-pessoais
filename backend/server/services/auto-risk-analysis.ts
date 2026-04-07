import { dataInventory, dataScanResults } from "../../schemas/scan-data-module.schema";
import {
  InsertRisk,
  organizations,
  risks,
  riskStandardControls,
  riskStandards,
  riskTypes
} from "../../schemas/schema";
import { and, eq } from "drizzle-orm";
import OpenAI from "openai";
import { db } from "../db";

// Instancia o cliente OpenAI com a API key do ambiente
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// Interface para resposta estruturada da OpenAI na análise de dados
interface DataRiskAnalysisResponse {
  riskLevel: 'high' | 'medium' | 'low';
  riskScore: number; // 1-100
  potentialThreats: string[];
  vulnerabilities: string[];
  impacts: string[];
  relevantStandards: string[]; // IDs dos padrões relevantes
  recommendedControls: {
    controlId: string;
    relevance: number; // 0-100
    justification: string;
  }[];
  complianceGap: string;
  recommendedMitigations: string[];
}

/**
 * Analisa automaticamente os dados pessoais encontrados em um escaneamento
 * e gera uma análise de risco em tempo real utilizando IA
 * 
 * @param scanResultId ID do resultado de escaneamento
 * @returns Objeto com a análise detalhada e recomendações
 */
export async function analyzeDataScanResultRisk(scanResultId: number) {
  try {
    // Busca informações do resultado do escaneamento
    const [scanResult] = await db.select()
      .from(dataScanResults)
      .where(eq(dataScanResults.id, scanResultId));
    
    if (!scanResult) {
      throw new Error("Resultado de escaneamento não encontrado");
    }

    // Busca dados relacionados ao escaneamento (inventário)
    const inventoryItems = await db.select()
      .from(dataInventory)
      .where(eq(dataInventory.scanResultId, scanResultId));
    
    // Busca normas e controles disponíveis
    const standards = await db.select().from(riskStandards);
    const controls = await db.select().from(riskStandardControls);
    
    // Busca a organização
    const [organization] = await db.select()
      .from(organizations)
      .where(eq(organizations.id, scanResult.organizationId || 1));

    // Prepara as informações para análise de IA
    const normalizados = inventoryItems.map(item => ({
      tipo: item.dataType,
      valor: item.value && typeof item.value === 'string' 
        ? item.value.substring(0, 20) + (item.value.length > 20 ? '...' : '') 
        : 'N/A',
      categoria: item.category,
      subcategoria: item.subcategory,
      criticidade: item.criticality,
      fonte: item.source || 'Escaneamento',
      contexto: item.context || '',
    }));

    // Prepara informações das normas para enviar ao prompt
    const standardsInfo = standards.map(std => ({
      code: std.code,
      name: std.name,
      category: std.category,
      controls: controls
        .filter(control => control.standardId === std.id)
        .map(control => ({
          controlId: control.controlId,
          name: control.name,
          description: control.description,
          category: control.category
        }))
    }));

    // Cria um prompt detalhado para a análise de risco
    const response = await openai.chat.completions.create({
      model: "gpt-4o", // o modelo mais recente da OpenAI é "gpt-4o", lançado em 13 de maio de 2024
      messages: [
        {
          role: "system",
          content: `Você é um especialista em LGPD (Lei Geral de Proteção de Dados) e análise de riscos de segurança da informação.
          Você deve analisar os dados pessoais encontrados em um escaneamento e identificar os riscos potenciais, ameaças e vulnerabilidades.
          Com base nas normas ABNT ISO disponíveis, sugira controles relevantes para mitigar esses riscos.
          Forneça uma análise detalhada e estruturada em formato JSON.`
        },
        {
          role: "user",
          content: `Analise os seguintes dados pessoais encontrados em um escaneamento:
          
          Organização: ${organization?.name || "Não informada"}
          Fonte do escaneamento: ${scanResult.source || "Não informada"}
          Tipo de escaneamento: ${scanResult.scanType || "Não informado"}
          
          Dados encontrados:
          ${JSON.stringify(normalizados, null, 2)}
          
          Com base nas seguintes normas e seus controles:
          ${JSON.stringify(standardsInfo, null, 2)}
          
          Por favor, identifique:
          1. Nível de risco (alto, médio, baixo) e pontuação (1-100)
          2. Ameaças potenciais relacionadas a esses dados
          3. Vulnerabilidades que podem ser exploradas
          4. Possíveis impactos em caso de incidente
          5. Normas relevantes para esses tipos de dados
          6. Controles recomendados para mitigar os riscos (com ID, relevância e justificativa)
          7. Lacunas de conformidade com a LGPD
          8. Recomendações práticas de mitigação
          
          Responda em português do Brasil e em formato JSON com os campos: riskLevel, riskScore, potentialThreats, vulnerabilities, impacts, relevantStandards, recommendedControls, complianceGap, recommendedMitigations.`
        }
      ],
      response_format: { type: "json_object" }
    });

    const content = response.choices[0].message.content || "{}";
    const analysisResult = JSON.parse(content) as DataRiskAnalysisResponse;
    
    // Busca tipo de risco para associar
    let [riskType] = await db.select()
      .from(riskTypes)
      .where(and(
        eq(riskTypes.organizationId, scanResult.organizationId || 1),
        eq(riskTypes.name, "Proteção de Dados")
      ));
    
    // Se não existir o tipo, cria um novo
    if (!riskType) {
      const [newRiskType] = await db.insert(riskTypes)
        .values({
          name: "Proteção de Dados",
          description: "Riscos relacionados à proteção de dados pessoais e conformidade com a LGPD",
          category: "compliance",
          defaultLikelihood: "possible",
          defaultImpact: "moderate",
          organizationId: scanResult.organizationId || 1,
          createdBy: "1" // Admin
        })
        .returning();
      
      riskType = newRiskType;
    }
    
    // Mapeia o nível de risco para o formato do banco de dados
    const riskLikelihood = mapRiskLevel(analysisResult.riskLevel);
    const riskImpact = mapRiskImpact(analysisResult.riskLevel);
    
    // Cria um novo risco com base na análise
    const riskData: InsertRisk = {
      title: `Risco de proteção de dados - ${scanResult.name || 'Escaneamento'}`,
      description: `Risco identificado automaticamente a partir do escaneamento "${scanResult.name || 'Não informado'}"`,
      organizationId: scanResult.organizationId || 1,
      typeId: riskType.id,
      likelihood: riskLikelihood,
      impact: riskImpact,
      category: "compliance", // Risco de conformidade legal/regulatória
      status: "identified",
      dataItems: inventoryItems.map(item => item.id), // IDs dos dados identificados
      standardControls: analysisResult.recommendedControls.map(control => control.controlId),
      threatSources: analysisResult.potentialThreats.join("\n"),
      vulnerabilities: analysisResult.vulnerabilities.join("\n"),
      potentialImpact: analysisResult.impacts.join("\n"),
      riskScore: analysisResult.riskScore,
      inherentRiskScore: analysisResult.riskScore,
      residualRiskScore: Math.round(analysisResult.riskScore * 0.7), // Estimativa de redução de 30% com controles
      aiAnalysis: analysisResult,
      createdBy: "1" // Admin
    };
    
    // Insere o novo risco no banco de dados
    const [newRisk] = await db.insert(risks).values(riskData).returning();
    
    // Atualiza o resultado do escaneamento com referência ao risco criado
    await db.update(dataScanResults)
      .set({ 
        riskAnalysis: {
          riskId: newRisk.id,
          riskLevel: analysisResult.riskLevel,
          riskScore: analysisResult.riskScore,
          analysis: analysisResult
        },
        updatedAt: new Date()
      })
      .where(eq(dataScanResults.id, scanResultId));
    
    return {
      success: true,
      risk: newRisk,
      analysis: analysisResult
    };
  } catch (error: any) {
    console.error("Erro na análise automática de risco:", error);
    return {
      success: false,
      error: error.message || "Erro desconhecido na análise automática de risco"
    };
  }
}

/**
 * Mapeia o nível de risco para o formato do schema (likelihood)
 */
function mapRiskLevel(level: string): "rare" | "unlikely" | "possible" | "likely" | "almost_certain" {
  switch (level.toLowerCase()) {
    case "high":
      return "almost_certain";
    case "medium":
      return "possible";
    case "low":
      return "unlikely";
    default:
      return "possible";
  }
}

/**
 * Mapeia o nível de risco para o formato do schema (impact)
 */
function mapRiskImpact(level: string): "negligible" | "minor" | "moderate" | "major" | "severe" {
  switch (level.toLowerCase()) {
    case "high":
      return "severe";
    case "medium":
      return "moderate";
    case "low":
      return "minor";
    default:
      return "moderate";
  }
}

/**
 * Analisa automaticamente todos os dados em um inventário de dados
 * e gera uma análise de risco consolidada
 * 
 * @param organizationId ID da organização
 * @returns Objeto com a análise consolidada
 */
export async function analyzeDataInventoryRisk(organizationId: number) {
  try {
    // Busca todos os itens do inventário de dados da organização
    const inventoryItems = await db.select()
      .from(dataInventory)
      .where(eq(dataInventory.organizationId, organizationId));
    
    if (inventoryItems.length === 0) {
      throw new Error("Nenhum dado encontrado no inventário");
    }
    
    // Agrupa dados por categoria para análise consolidada
    const dadosPorCategoria: Record<string, any[]> = {};
    inventoryItems.forEach(item => {
      const categoria = item.category || "não_categorizado";
      if (!dadosPorCategoria[categoria]) {
        dadosPorCategoria[categoria] = [];
      }
      dadosPorCategoria[categoria].push({
        id: item.id,
        tipo: item.dataType,
        valor: item.value && typeof item.value === 'string' 
          ? item.value.substring(0, 20) + (item.value.length > 20 ? '...' : '') 
          : 'N/A',
        subcategoria: item.subcategory,
        criticidade: item.criticality,
        fonte: item.source || 'Desconhecida',
      });
    });
    
    // Busca normas e controles disponíveis
    const standards = await db.select().from(riskStandards);
    const controls = await db.select().from(riskStandardControls);
    
    // Prepara informações das normas para enviar ao prompt
    const standardsInfo = standards.map(std => ({
      code: std.code,
      name: std.name,
      category: std.category,
      controls: controls
        .filter(control => control.standardId === std.id)
        .map(control => ({
          controlId: control.controlId,
          name: control.name,
          description: control.description,
          category: control.category
        }))
    }));
    
    // Cria um prompt para análise consolidada
    const response = await openai.chat.completions.create({
      model: "gpt-4o", // o modelo mais recente da OpenAI é "gpt-4o", lançado em 13 de maio de 2024
      messages: [
        {
          role: "system",
          content: `Você é um especialista em LGPD (Lei Geral de Proteção de Dados) e análise de riscos de segurança da informação.
          Você deve analisar um inventário de dados pessoais completo e identificar os riscos potenciais, ameaças e vulnerabilidades.
          Com base nas normas ABNT ISO disponíveis, sugira controles relevantes para mitigar esses riscos.
          Forneça uma análise detalhada e estruturada em formato JSON.`
        },
        {
          role: "user",
          content: `Analise o seguinte inventário de dados pessoais agrupados por categoria:
          
          ${JSON.stringify(dadosPorCategoria, null, 2)}
          
          Com base nas seguintes normas e seus controles:
          ${JSON.stringify(standardsInfo, null, 2)}
          
          Por favor, identifique:
          1. Nível de risco (alto, médio, baixo) e pontuação (1-100) para cada categoria de dados
          2. Ameaças potenciais relacionadas a cada categoria de dados
          3. Vulnerabilidades que podem ser exploradas
          4. Possíveis impactos em caso de incidente
          5. Normas relevantes para cada categoria de dados
          6. Controles recomendados para mitigar os riscos (com ID, relevância e justificativa)
          7. Lacunas de conformidade com a LGPD
          8. Recomendações práticas de mitigação
          
          Responda em português do Brasil e em formato JSON com os campos principais: categorias (lista com análise por categoria), ameacasGerais, vulnerabilidadesGerais, impactosGerais, controlesGerais, lacunasConformidade, recomendacoesGerais.`
        }
      ],
      response_format: { type: "json_object" }
    });

    const content = response.choices[0].message.content || "{}";
    const analysisResult = JSON.parse(content);
    
    // Para cada categoria, criar um risco específico
    for (const categoria of Object.keys(dadosPorCategoria)) {
      const categoriaInfo = analysisResult.categorias?.find((c: any) => 
        c.categoria.toLowerCase() === categoria.toLowerCase()
      );
      
      if (!categoriaInfo) continue;
      
      // Busca tipo de risco para associar
      let [riskType] = await db.select()
        .from(riskTypes)
        .where(and(
          eq(riskTypes.organizationId, organizationId),
          eq(riskTypes.name, "Proteção de Dados")
        ));
      
      // Se não existir o tipo, cria um novo
      if (!riskType) {
        const [newRiskType] = await db.insert(riskTypes)
          .values({
            name: "Proteção de Dados",
            description: "Riscos relacionados à proteção de dados pessoais e conformidade com a LGPD",
            category: "compliance",
            defaultLikelihood: "possible",
            defaultImpact: "moderate",
            organizationId: organizationId,
            createdBy: "1" // Admin
          })
          .returning();
        
        riskType = newRiskType;
      }
      
      // Mapeia o nível de risco para o formato do banco de dados
      const riskLikelihood = mapRiskLevel(categoriaInfo.nivelRisco || "medium");
      const riskImpact = mapRiskImpact(categoriaInfo.nivelRisco || "medium");
      
      // Cria um novo risco com base na análise
      const riskData: InsertRisk = {
        title: `Risco de dados - ${categoria}`,
        description: `Risco identificado automaticamente para dados da categoria: ${categoria}`,
        organizationId: organizationId,
        typeId: riskType.id,
        likelihood: riskLikelihood,
        impact: riskImpact,
        category: "compliance", // Risco de conformidade legal/regulatória
        status: "identified",
        dataItems: dadosPorCategoria[categoria].map(item => item.id), // IDs dos dados identificados
        standardControls: categoriaInfo.controlesRecomendados?.map((control: any) => control.controlId) || [],
        threatSources: categoriaInfo.ameacas?.join("\n") || "",
        vulnerabilities: categoriaInfo.vulnerabilidades?.join("\n") || "",
        potentialImpact: categoriaInfo.impactos?.join("\n") || "",
        riskScore: categoriaInfo.pontuacaoRisco || 50,
        inherentRiskScore: categoriaInfo.pontuacaoRisco || 50,
        residualRiskScore: Math.round((categoriaInfo.pontuacaoRisco || 50) * 0.7), // Estimativa de redução de 30% com controles
        aiAnalysis: categoriaInfo,
        createdBy: "1" // Admin
      };
      
      // Insere o novo risco no banco de dados
      await db.insert(risks).values(riskData);
    }
    
    return {
      success: true,
      analysis: analysisResult
    };
  } catch (error: any) {
    console.error("Erro na análise consolidada de riscos:", error);
    return {
      success: false,
      error: error.message || "Erro desconhecido na análise consolidada de riscos"
    };
  }
}