// Carrega variáveis .env sobrescrevendo as que já existirem (ex: se shell tiver placeholders USER:PASS)
// Early bootstrap for environment variables (ensures DB credentials before any other module).
import './bootstrap-env';
if (process.env.NODE_ENV !== 'production') {
  try { const dbg = new URL(process.env.DATABASE_URL || ''); console.log('[env:db-user]', dbg.username); } catch {}
}
// Removido: não forçar NODE_TLS_REJECT_UNAUTHORIZED=0 globalmente.
// A lógica de fallback controlado está em server/db.ts via DB_SSL_AUTO_RELAX.
import express, { type Request, Response, NextFunction } from "express";
import cors from 'cors';
import apiExternalRouter from "./routes/api-external-routes";
import riskManagementRouter from "./routes/risk-management";
import riskStandardsRouter from "./routes/risk-standards";
import usersRouter from "./routes/route.users";
import personalDataRouter from "./routes/route.personal-data-module";
import organizationRouter from "./routes/route.organization";
import scanDataModuleRouter from "./routes/route.scan-data-module";
import dataLineageRouter from "./routes/data-lineage-routes";
import accessControlRouter from "./routes/access-control-routes";
import agentCenterRouter from "./routes/agent-center-routes";
import agentRouter from "./routes/agent.routes";
import areasRouter from "./routes/route.areas";
import processosRouter from "./routes/route.processos";
import metricsRoutes from "./routes/metrics.routes";
import authRoutes from "./routes/auth.routes";
import { pool } from './db';
// import riskStatsPublicRouter from "./routes/risk-stats-public-routes";


const app = express();
// Debug mínimo: mostrar usuário efetivo da DATABASE_URL (somente em dev)
if (process.env.NODE_ENV !== 'production' && process.env.DATABASE_URL) {
  try {
    const u = new URL(process.env.DATABASE_URL);
    console.log('[env:db-user]', u.username || '(none)');
  } catch {}
}
// Aumentando limite de tamanho para 10MB para permitir envio de resultados de escaneamento grandes
// IMPORTANTE: Não aplicar em rotas multipart/form-data para evitar conflito com Multer
app.use((req, res, next) => {
  // Pular middlewares JSON/URL-encoded para rotas multipart
  const isMultipart = req.headers['content-type']?.includes('multipart/form-data');
  if (isMultipart) {
    return next();
  }
  
  // Aplicar middlewares apenas para content-types compatíveis
  if (req.headers['content-type']?.includes('application/json')) {
    return express.json({ limit: "10mb" })(req, res, next);
  }
  
  if (req.headers['content-type']?.includes('application/x-www-form-urlencoded')) {
    return express.urlencoded({ extended: false, limit: "10mb" })(req, res, next);
  }
  
  next();
});

// Desabilitar ETag para evitar 304 Not Modified em JSON APIs
app.disable('etag');
// Garantir que não haja cache das respostas de API
app.use((_, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
});

app.use((req, res, next) => {
  const start = Date.now();
  const path = req.path;
  let capturedJsonResponse: Record<string, any> | undefined = undefined;

  const originalResJson = res.json;
  res.json = function (bodyJson, ...args) {
    capturedJsonResponse = bodyJson;
    return originalResJson.apply(res, [bodyJson, ...args]);
  };

  res.on("finish", () => {
    const duration = Date.now() - start;
    if (path.startsWith("/api")) {
      let logLine = `${req.method} ${path} ${res.statusCode} in ${duration}ms`;
      if (capturedJsonResponse) {
        logLine += ` :: ${JSON.stringify(capturedJsonResponse)}`;
      }

      if (logLine.length > 80) {
        logLine = logLine.slice(0, 79) + "…";
      }

      // Log apenas em desenvolvimento
      if (process.env.NODE_ENV === 'development') {
        console.log(logLine);
      }
    }
  });

  next();
});

// ---------- CORS multi-origem ----------
const raw = process.env.CORS_ORIGINS ?? '';
const sanitize = (url?: string) => url?.trim().replace(/\/+$/, '');
const whitelist = raw.split(',').map(sanitize).filter(Boolean);

app.use(cors({
  origin: (origin: string | undefined, cb: (err: Error | null, allow?: boolean) => void) => {
    if (!origin) return cb(null, true);  // curl, health-check
    if (whitelist.includes(sanitize(origin))) {
      return cb(null, true);
    }
    return cb(new Error(`CORS bloqueado para origem: ${origin}`));
  },
  credentials: true,
  methods: 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
  allowedHeaders: 'Content-Type,Authorization',
  maxAge: 86400,
}));
// ---------- Fim CORS ----------

(async () => {
  // Registrar rotas de API externa
  app.use("/api/external", apiExternalRouter);

  // Registrar rotas públicas para normas ABNT ISO
  app.use("/api/standards", riskStandardsRouter);

  // Registrar rotas de gerenciamento de riscos
  app.use("/api/risk-management", riskManagementRouter);

  // Registrar rotas públicas para estatísticas de risco
  // app.use("/api/public/risk-stats", riskStatsPublicRouter);

  // Registrar rotas de usuários e autenticação
  app.use(usersRouter);
  app.use(authRoutes);

  // Registrar rotas de dados pessoais
  app.use(personalDataRouter);

  // Registrar rotas de organizações
  app.use(organizationRouter);

  // Registrar rotas de módulo de escaneamento de dados
  app.use(scanDataModuleRouter);

  // Registrar rotas de métricas e estatísticas do sistema
  app.use("/api/metrics", metricsRoutes);

  // Registrar rotas de lineage de dados
  app.use("/api/data-lineage", dataLineageRouter);

  // Registrar rotas de controle de acesso
  app.use("/api/access-control", accessControlRouter);

  // Registrar rotas de agente
  app.use("/api/agent-center", agentCenterRouter);

  // Registrar rotas de gerenciamento de Agents (usuários com role=agent)
  app.use(agentRouter);

  // Registrar rotas de áreas
  app.use(areasRouter);

  // Registrar rotas de processos
  app.use(processosRouter);

  // Endpoints de health/readiness simples (antes do 404)
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });
  app.get('/ready', async (_req, res) => {
    try {
      // teste rápido de conexão; timeout simples de 2s
      const ctrl = new AbortController();
      const to = setTimeout(() => ctrl.abort(), 2000);
      await pool.query('SELECT 1');
      clearTimeout(to);
      res.json({ status: 'ready' });
    } catch (e: any) {
      res.status(503).json({ status: 'degraded', error: e?.message || 'db check failed' });
    }
  });

  // Middleware 404 para rotas não declaradas
  app.use((req, res) => {
    res.status(404).json({ message: 'Rota não encontrada' });
  });

  // Error handler
  app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
    const status = err.status || err.statusCode || 500;
    const message = err.message || "Internal Server Error";
    // log mínimo em produção
    if (process.env.NODE_ENV !== 'test') {
      console.error('[error]', status, message);
    }
    if (!res.headersSent) {
      res.status(status).json({ message });
    }
    // Não relançar para evitar derrubar o processo
  });

  const port = process.env.PORT ? parseInt(process.env.PORT) : 3001;
  app.listen(port, () => {
    console.log(`API rodando em http://localhost:${port}/ (PID ${process.pid})`);
  });

  return;
})();

// Captura global para não derrubar processo em exceções não tratadas
process.on('unhandledRejection', (reason) => {
  console.error('[unhandledRejection]', reason);
});
process.on('uncaughtException', (err) => {
  console.error('[uncaughtException]', err);
});
