// @ts-nocheck
import { Router, Request, Response } from "express";
import { ScanDataModuleService } from "../services/scan-data-module.service";
import { PersonalDataModuleService } from "../services/personal-data-module.service";
import { v4 as uuidv4 } from "uuid";
import fs from "fs";
import path from "path";

const router = Router();
const scanService = new ScanDataModuleService();
const dataService = new PersonalDataModuleService();

// Função para criar logs de auditoria
async function logAuditEvent(action: string, details: any, userId: number = 1) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    action: action,
    userId: userId,
    details: typeof details === "string" ? details : JSON.stringify(details),
  };

  // Garantir que o diretório de logs exista
  const logDir = path.join(__dirname, "../../logs");
  if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
  }

  // Escrever em arquivo de log
  const logFile = path.join(
    logDir,
    `audit_log_${new Date().toISOString().split("T")[0]}.log`,
  );
  fs.appendFileSync(logFile, JSON.stringify(logEntry) + "\n");

  return logEntry;
}

// Health check endpoint
router.post("/test", async (req: Request, res: Response) => {
  return res
    .status(200)
    .json({ success: true, message: "API funcionando corretamente" });
});

// Rota para obter exemplo de formato de dados
router.get("/sample-format", async (req: Request, res: Response) => {
  const sampleData = {
    scanName: "Escaneamento de Exemplo",
    scanId: "SAMPLE-SCAN-001",
    directory: "/caminho/exemplo",
    results: [
      {
        dataType: "cpf",
        displayName: "CPF",
        category: "personal_data",
        subcategory: "identification",
        criticality: "high",
        value: "123.456.789-00", // valor de exemplo apenas para demonstração
        context: "Encontrado em formulário de cadastro",
        evidence: "Nome: João Silva, CPF: 123.456.789-00",
        fileName: "formulario.txt",
        filePath: "/caminho/exemplo/formulario.txt",
        line: 15
      },
      {
        dataType: "email",
        displayName: "E-mail",
        category: "personal_data",
        subcategory: "identification",
        criticality: "medium",
        value: "exemplo@email.com", // valor de exemplo apenas para demonstração
        context: "Encontrado em lista de contatos",
        evidence: "Contato: exemplo@email.com",
        fileName: "contatos.csv",
        filePath: "/caminho/exemplo/contatos.csv",
        line: 8
      }
    ],
    stats: {
      totalFiles: 25,
      scannedDirectories: 3,
      processingTimeMs: 1250
    }
  };

  await logAuditEvent("sample_format_requested", {
    source: req.headers["user-agent"] || "unknown",
    ip: req.ip
  });

  // Para evitar a interceptação do Vite e garantir que o JSON seja retornado corretamente,
  // vamos criar um arquivo temporário e servir como download
  const tempDir = path.join(__dirname, "../../temp_storage");
  if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir, { recursive: true });
  }

  const tempFile = path.join(tempDir, `sample_format_${Date.now()}.json`);
  fs.writeFileSync(tempFile, JSON.stringify(sampleData, null, 2));

  // Responder com o arquivo para download
  res.download(tempFile, "sample_format.json", (err) => {
    if (err) {
      console.error("Erro ao enviar arquivo:", err);
    }
    // Remover arquivo temporário após servir
    setTimeout(() => {
      try {
        if (fs.existsSync(tempFile)) {
          fs.unlinkSync(tempFile);
        }
      } catch (e) {
        console.error("Erro ao remover arquivo temporário:", e);
      }
    }, 5000); // Esperar 5 segundos para garantir que o download foi concluído
  });
});

// Rota para receber resultados de escaneamento consolidados
router.post("/external-scan-results", async (req: Request, res: Response) => {
  try {
    await logAuditEvent("external_scan_received", {
      source: req.headers["user-agent"] || "unknown",
      scanId: req.body.scanId || "unknown",
      resultsCount: req.body.results?.length || 0,
    });

    // Validar solicitação
    if (!req.body || !req.body.results || !Array.isArray(req.body.results)) {
      await logAuditEvent("external_scan_error", "Formato de dados inválido");
      return res.status(400).json({ error: "Formato de dados inválido" });
    }

    // Criação da configuração de escaneamento
    const scanConfig = await scanService.createDataScanConfig({
      name:
        req.body.scanName ||
        req.body.configName ||
        `Escaneamento Externo ${new Date().toISOString()}`,
      description: `Resultados de escaneamento do diretório: ${req.body.directory || "Não especificado"}`,
      sourceType: "directory",
      organizationId: 1, // Organização padrão
      createdBy: 1, // Usuário padrão (admin)
      connectionConfig: {
        baseDirectory: req.body.directory || "Cliente local",
        includeExtensions: [".txt", ".csv", ".html", ".pdf", ".docx"],
        recursive: true,
      },
      scanPattern: {
        contentPatterns: Array.from(new Set(req.body.results.map((r: any) => r.dataType))),
      },
    });

    // Criar job de escaneamento para rastrear os resultados
    const scanJob = await scanService.createDataScanJob({
      configId: scanConfig.id,
      organizationId: 1, // Organização padrão
      status: "completed",
      startedAt: new Date(),
      completedAt: new Date(),
      // Importante: aqui incluímos os resultados completos com valores reais
      foundItems: req.body.results.map((item: any) => ({
        dataType: item.dataType,
        displayName: item.displayName || item.dataType,
        category: item.category || "personal_data",
        subcategory: item.subcategory || "identification",
        criticality: item.criticality || "medium",
        // IMPORTANTE: aqui estão os valores reais
        value: item.value,
        context: item.context || "",
        evidence: item.evidence || "",
        fileName: item.fileName || "Desconhecido",
        filePath: item.filePath || "Desconhecido",
        line: item.line || 0,
        confidence: 0.9,
      })),
      stats: {
        totalScanned: req.body.stats?.totalFiles || req.body.results.length,
        matchesFound: req.body.results.length,
        processingTimeMs: 0,
        scanDirectory: req.body.directory || "Desconhecido",
      },
    });

    await logAuditEvent("scan_job_created", {
      jobId: scanJob.id,
      configId: scanConfig.id,
      itemCount: req.body.results.length,
    });

    // Criar registro de dados para cada item encontrado
    const processedItems = [];

    for (const result of req.body.results) {
      try {
        // Criar identificador único
        const identifier = `DATA-${Date.now()}-${uuidv4().substring(0, 8)}`;

        // Validar e converter categoria
        let category: "personal_data" | "sensitive_data" | "anonymous_data" | "pseudonymized_data" = "personal_data";
        if (result.category === "personal_data" || 
            result.category === "sensitive_data" || 
            result.category === "anonymous_data" || 
            result.category === "pseudonymized_data") {
          category = result.category as "personal_data" | "sensitive_data" | "anonymous_data" | "pseudonymized_data";
        }
        
        // Validar e converter criticidade
        let criticality: "high" | "medium" | "low" = "medium";
        if (result.criticality === "high" || 
            result.criticality === "medium" || 
            result.criticality === "low") {
          criticality = result.criticality as "high" | "medium" | "low";
        }
        
        // Criar objeto de inserção com tipos corretos
        const dataItem = await dataService.create({
          identifier: identifier,
          description: `${result.displayName || result.dataType}: ${result.value} (Escaneamento ID: ${scanJob.id})`,
          type: String(result.dataType),
          category: category,
          subcategory: (result.subcategory === "identification" || 
                            result.subcategory === "financial" || 
                            result.subcategory === "health" || 
                            result.subcategory === "biometric" || 
                            result.subcategory === "location" || 
                            result.subcategory === "professional" || 
                            result.subcategory === "behavioral") 
                          ? result.subcategory as "identification" | "financial" | "health" | "biometric" | "location" | "professional" | "behavioral"
                          : "identification" as "identification",
          criticality: criticality,
          source: "internal",
          processingPurpose: "Identificado por escaneamento automático",
          legalBasis: "legitimate_interest",
          collectionChannel: result.fileName
            ? path.dirname(result.filePath || "")
            : "escaneamento_externo",
          storageLocation: result.filePath || "desconhecido",
          organizationId: 1,
          // IMPORTANTE: Aqui incluímos o valor real e contexto nas notas
          additionalNotes: `Valor encontrado: ${result.value}\nContexto: ${result.context || "Não disponível"}\nEvidence: ${result.evidence || "Não disponível"}\nID Scan: ${scanJob.id}`,
        });
        
        processedItems.push(dataItem);
      } catch (itemError) {
        // Log apenas erros críticos
      }
    }

    await logAuditEvent("external_scan_processed", {
      jobId: scanJob.id,
      processedCount: processedItems.length,
      totalReceived: req.body.results.length,
    });

    // Responder com sucesso
    return res.status(201).json({
      success: true,
      message: `Escaneamento recebido com sucesso. Processados ${processedItems.length} itens.`,
      scanJobId: scanJob.id,
      configId: scanConfig.id,
    });
  } catch (error: any) {
    console.error("Erro ao processar resultados externos:", error);

    await logAuditEvent("external_scan_critical_error", {
      error: error.message,
      stack: error.stack,
    });

    return res.status(500).json({
      error: "Erro interno ao processar dados de escaneamento",
      message: error.message,
    });
  }
});

export default router;