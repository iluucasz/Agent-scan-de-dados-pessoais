# Privacy Pulse – Backend API

API em Node.js + Express + TypeScript, usando Drizzle ORM com PostgreSQL. Multi-tenant por organização, com autenticação JWT e RBAC (admin, gestor, cliente).

## Pré-requisitos
- Node.js LTS (18+ recomendado)
- npm (ou pnpm/yarn)
- PostgreSQL acessível (sem SSL no ambiente local – ver nota abaixo)

## Instalação
1. Clone o repositório:
   ```bash
   git clone <url-do-repositório>
   ```
2. Acesse o diretório do projeto:
   ```bash
   cd backend
   ```
3. Instale as dependências:
   ```bash
   npm install
   ```

## Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto. Exemplo (ajuste valores reais):

```env
# Core DB
DATABASE_URL=postgres://usuario_real:senha_real@host:porta/dbname
DB_SSL_MODE=strict
CA_CERT="-----BEGIN CERTIFICATE-----\n...PEM ROOT...\n-----END CERTIFICATE-----"

# JWT
JWT_SECRET=sua_chave_secreta_longa
JWT_EXPIRES_IN=7d

# Frontend
APP_URL=https://pulse.seusdados.com
# Defaults
DEFAULT_ORGANIZATION_ID=1
DEFAULT_USER_ROLE=cliente
PORT=3001

# Execução automática de migrations (opcional em dev)
# DB_RUN_MIGRATIONS=on-start
# DB_MIGRATIONS_STRICT=true

# Drift (dev)
# DB_AUTO_PATCH_USERS_CURRENT_ORG=true
# DB_SCHEMA_DRIFT_STRICT=true

# Storage (opcional)
# STORAGE_PROVIDER=local|digitalocean|hybrid
# DO_ENDPOINT=https://<space>.<region>.digitaloceanspaces.com
# DO_BUCKET=<bucket>
# DO_ACCESS_KEY=<key>
# DO_SECRET_KEY=<secret>
```

Observações:
- Não deixe `DATABASE_URL` global do sistema (evita sobrescrever .env).
- Em produção evite variáveis como `DB_AUTO_PATCH_USERS_CURRENT_ORG`.
- Não use `NODE_TLS_REJECT_UNAUTHORIZED=0` nem `DRIZZLE_ALLOW_SELF_SIGNED` em produção.
  
SSL:
- `DB_SSL_MODE=strict` valida a cadeia usando CA fornecida.
- Ferramentas (drizzle-kit) podem precisar da mesma CA; já suportado via `drizzle.config.ts`.

Links e redirecionamentos:
- Fluxos de autenticação usam `APP_URL` como base para montar URLs (login callback, invite, verify email, reset password). Ajuste conforme seu domínio público.

## Migrations

Fluxo recomendado:
1. Alterar schemas em `schemas/*.ts`
2. Gerar migrations: `npm run db:generate`
3. Revisar arquivos em `migrations/`
4. Aplicar: `npm run db:push` (staging / dev) ou em pipeline CI antes de subir

Scripts úteis:
- `npm run db` (gera + aplica) – uso rápido local
- `npm run db:generate`
- `npm run db:push`
- `npm run db:studio` (visualização)

Evite usar o script de relax SSL (`db:push:allow-self-signed`) fora de ambiente local.

## Execução

### Modo de desenvolvimento

```bash
npm run dev
```

Este comando inicia o servidor diretamente a partir do código TypeScript usando `tsx`.

### Modo de produção

```bash
npm start
```

O comando `start` já executa `npm run build` seguido de `node dist/server/index.js`.

## Scripts disponíveis

- `npm run dev` – desenvolvimento
- `npm run build` – build TypeScript
- `npm start` – build + iniciar (pode ajustar para não gerar migrations automaticamente)
- `npm run db` – gerar e aplicar (combo local)
- `npm run db:generate` – gerar migrations
- `npm run db:push` – aplicar migrations
- `npm run db:studio` – UI drizzle

## Estrutura de pastas

- `server/` — Código da API (rotas, middlewares, controllers, services, utils)
- `schemas/` — Schemas do Drizzle (tabelas e tipos)
- `migrations/` — SQL das migrations (Drizzle)

### Mapa rápido de pastas

```
server/
├─ index.ts, db.ts, access-control.ts, systemInfo.ts
├─ routes/ (route.users.ts, route.organization.ts, route.areas.ts, route.processos.ts, route.scan-data-module.ts, ...)
├─ controllers/ (users.controller.ts, organization.controller.ts, ...)
├─ services/ (users.service.ts, organization.service.ts, scan-data-module.service.ts, ...)
├─ middlewares/ (authToken.ts, access-control.middleware.ts, scan-upload.middleware.ts, ...)
└─ utils/ (jwt.ts, file-sanitizer.util.ts)

schemas/ (users.schema.ts, organization.schema.ts, areas.schema.ts, processos.schema.ts, personal-data-module.schema.ts, scan-data-module.schema.ts)
migrations/ (0000_init.sql ... 0006_rbac_user_role_enum.sql)
docs/ (ARQUITETURA.md, PLANO-RBAC.md, SCAN-CAPABILITIES.md, CHECKLIST-DEPLOY.md)
```

Mais detalhes: veja `docs/ARQUITETURA.md`.

## RBAC e perfis
- admin: acesso global a todos os tenants/organizações.
- gestor: acesso a todos os dados da própria organização.
- cliente: acesso limitado à própria organização.


## Visão geral das rotas

Autenticação e usuários
- POST /api/users — registro
- POST /api/auth/login — login (JWT)
- GET /api/auth/me — perfil do usuário autenticado
- GET /api/users — listar usuários (escopo por papel)
- PUT/PATCH/DELETE /api/users/:id — atualizar/remover

Organizações
- GET /api/organizations — listar
- GET /api/organizations/:id — detalhes
- POST /api/organizations — criar (admin)
- PUT/PATCH /api/organizations/:id — atualizar (admin)
- DELETE /api/organizations/:id — remover (admin)

Áreas
- GET /api/areas — listar (admin: todas; demais: própria organização)
- GET /api/organizations/:organizationId/areas — listar por organização
- POST /api/organizations/:organizationId/areas — criar
- GET /api/areas/:id — detalhes
- PATCH/PUT /api/areas/:id — atualizar
- DELETE /api/areas/:id — remover
- GET /api/organizations/:organizationId/areas-with-processes — áreas + processos

Processos
- GET /api/processos — listar (admin: todos; demais: própria organização)
- POST /api/areas/:areaId/processos — criar
- GET /api/areas/:areaId/processos — listar por área
- GET /api/organizations/:organizationId/processos — listar por organização
- GET /api/processos/:id — detalhes
- PATCH/PUT /api/processos/:id — atualizar
- DELETE /api/processos/:id — remover

Scan de dados
- GET /api/data-scan-configs — listar configs (admin/tenant)
- GET /api/data-scan-configs/:id — detalhes
- POST /api/data-scan-configs — criar
- PATCH/PUT /api/data-scan-configs/:id — atualizar
- DELETE /api/data-scan-configs/:id — remover
- POST /api/data-scan-configs/:id/run — executar (multipart; aceita metadata/personalData/itAssets/summary/performance)
- GET /api/data-scan-jobs — listar jobs (admin vê todos; demais por organização)
- GET /api/data-scan-jobs/:id — detalhes de job
- DELETE /api/data-scan-jobs/:id — remover job
- POST /api/external-scan-results — envio consolidado do Agent
- GET /api/external-scan-results/:scanId — consultar resultado consolidado

Observações
- Todas as rotas (exceto registro/login/health) exigem JWT via Authorization: Bearer.
- Escopo por papel aplicado no backend (admin global; gestor/cliente por organização).
- Health check: GET /api/health (sem autenticação).

## Arquitetura do projeto

Camadas principais:
- Rotas → Middlewares → Controllers → Services → Drizzle (db) → PostgreSQL
- RBAC e escopo por organização aplicados no middleware e verificados nos services/controllers.

Highlights:
- Analisador de scan com catálogo LGPD em `server/scanUtils.ts` e estatísticas em `server/scanStatsUtils.ts`.
- Ingestão externa de resultados via `server/routes/api-external-routes.ts`.
- Upload opcional para DigitalOcean Spaces em `server/services/digitalocean-upload.service.ts`.

Documento completo: `docs/ARQUITETURA.md`.