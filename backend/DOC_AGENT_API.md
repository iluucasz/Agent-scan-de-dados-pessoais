# Documentação de API - Usuário Agent

Este documento descreve como o **frontend** deve usar as rotas do backend para:

- Criar um usuário com `role: "agent"`.
- Listar Agents.
- Resetar (gerar um novo) token de Agent.
- Visão geral dos endpoints de autenticação do Agent (para uso futuro pelo BOT).

---

## 1. Criar usuário Agent

Endpoint dedicado para criação de usuários do tipo **Agent**.

- **URL:** `POST /api/agents`
- **Auth:** `Bearer <JWT de um usuário admin>`
- **Headers:**
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`

### Body mínimo recomendado

```json
{
  "name": "Meu Agent",
  "email": "agent@example.com",
  "role": "agent",
  "organizationId": 2,
  "currentOrganizationId": 2
}
```

### Campos aceitos

- `name` *(opcional)*  
  - Se não for enviado, o backend usa a parte antes do `@` do email.
- `email` **(obrigatório)**  
  - Usado para envio do email com o token permanente.
- `role` **(obrigatório)**  
  - **Deve ser** exatamente `"agent"`.
- `organizationId` *(opcional, mas recomendado)*  
  - Se não for enviado, o backend usa `req.user.organizationId` ou `DEFAULT_ORGANIZATION_ID`.
- `currentOrganizationId` *(opcional)*  
  - Se não vier, será ajustado depois com base na organização.
- `password` *(opcional)*  
  - Não é usado para login do Agent (o Agent autentica com token permanente + OTP), mas hoje o fluxo ainda aceita um valor placeholder.
- `jobTitle`, `department`, `phone`, `isActive` *(opcionais)*.

### Comportamento do backend ao criar um Agent

Ao receber um `POST /api/agents` com `role: "agent"`:

1. Cria o usuário na tabela `users` com `role = 'agent'`.
2. Gera um **token permanente** para esse usuário na tabela `agent_tokens`.
3. Envia um **email** para o `email` informado contendo:
   - Saudação: `Olá, {name}!`
   - Mensagem: conta criada com sucesso no Privacy Pulse.
   - Bloco: **"Token de Acesso: {TOKEN}"** (sem texto de "definir senha" e sem botão de reset de senha).

### Exemplo de resposta

```json
{
  "id": "f3f5a6b6-8fb3-475e-bb22-b4708463bf11",
  "organizationId": 2,
  "currentOrganizationId": 2,
  "name": "Meu Agent",
  "email": "agent@example.com",
  "role": "agent",
  "isActive": true,
  "lastLogin": null,
  "jobTitle": null,
  "department": null,
  "phone": null,
  "accessToken": null,
  "emailVerifiedAt": null,
  "createdAt": "2025-11-16T12:00:00.000Z",
  "updatedAt": "2025-11-16T12:00:00.000Z"
}
```

Uso típico no frontend: tela de criação de Agents, com formulário que envia os campos acima.

---

## 2. Listar Agents

Endpoint para listar todos os usuários com `role = 'agent'` de uma organização.

- **URL:** `GET /api/agents`
- **Auth:** `Bearer <JWT admin>`
- **Query params opcionais:**
  - `organizationId` – se não enviado, o backend usa `req.user.organizationId` ou `DEFAULT_ORGANIZATION_ID`.

### Exemplo de request

```http
GET /api/agents?organizationId=2
Authorization: Bearer <JWT_ADMIN>
```

### Exemplo de resposta

```json
[
  {
    "id": "f3f5a6b6-8fb3-475e-bb22-b4708463bf11",
    "organizationId": 2,
    "currentOrganizationId": 2,
    "name": "Meu Agent",
    "email": "agent@example.com",
    "role": "agent",
    "isActive": true,
    "lastLogin": null,
    "jobTitle": null,
    "department": null,
    "phone": null,
    "accessToken": null,
    "emailVerifiedAt": null,
    "createdAt": "2025-11-16T12:00:00.000Z",
    "updatedAt": "2025-11-16T12:00:00.000Z"
  }
]
```

Uso no frontend: tela de listagem/gerenciamento de Agents da organização.

---

## 3. Resetar token de um Agent (gerar novo token)

Permite que um admin invalide o token permanente atual de um Agent e gere um novo.

- **URL:** `POST /api/agents/:id/reset-token`
  - `:id` = `id` do usuário Agent (UUID retornado pelo backend).
- **Auth:** `Bearer <JWT admin>`

### Exemplo de request

```http
POST /api/agents/f3f5a6b6-8fb3-475e-bb22-b4708463bf11/reset-token
Authorization: Bearer <JWT_ADMIN>
```

### Comportamento do backend

1. Verifica se existe um usuário com o `id` informado e se `role === 'agent'`.
2. Marca todos os tokens antigos desse Agent em `agent_tokens` como inativos.
3. Gera um **novo token permanente** e salva como ativo.
4. Envia um **novo email** para o `email` do Agent com o **novo Token de Acesso**.
5. O token antigo deixa de funcionar.

### Exemplo de resposta

```json
{
  "message": "Token do agent resetado com sucesso"
}
```

Uso no frontend: botão de "Resetar token" / "Gerar novo token" na tela de detalhes do Agent.

---

## 4. Visão geral do login do Agent (para o BOT)

> **Obs.:** Esta seção é apenas um overview para você saber o que já existe. A implementação detalhada do BOT pode ser documentada depois.

O login do Agent é diferente do usuário normal:

1. O Agent possui um **token permanente**, que ele recebe por email.
2. Para logar, primeiro ele envia esse token para a API.
3. A API envia um **código OTP** para o email do Agent.
4. Somente após informar o OTP correto o Agent recebe um JWT para acesso à API.

### 4.1. Verificar token permanente e enviar OTP

- **URL:** `POST /api/auth/agent/verify-token`
- **Body:**

```json
{
  "token": "TOKEN_PERMANENTE_DO_EMAIL"
}
```

- **Comportamento:**
  - Valida o token permanente em `agent_tokens`.
  - Verifica se o usuário tem `role = 'agent'` e está ativo.
  - Gera um OTP (6 dígitos, com expiração curta).
  - Envia email ao Agent com o código OTP.

- **Resposta (exemplo):**

```json
{
  "challenge_id": "agent_otp",
  "next": "verify",
  "email": "agent@example.com"
}
```

### 4.2. Validar OTP e concluir login do Agent

- **URL:** `POST /api/auth/agent/verify-otp`
- **Body:**

```json
{
  "email": "agent@example.com",
  "code": "123456"
}
```

- **Comportamento:**
  - Consome o OTP (se for válido e não expirado).
  - Verifica se o email corresponde ao token OTP.
  - Confirma que o usuário é `role = 'agent'` e ativo.
  - Gera um JWT (igual aos demais usuários), atualiza `accessToken`, `lastLogin` e `currentOrganizationId`.

- **Resposta (exemplo):**

```json
{
  "user": {
    "id": "f3f5a6b6-8fb3-475e-bb22-b4708463bf11",
    "organizationId": 2,
    "currentOrganizationId": 2,
    "name": "Meu Agent",
    "email": "agent@example.com",
    "role": "agent",
    "isActive": true,
    "lastLogin": "2025-11-16T13:00:00.000Z",
    "jobTitle": null,
    "department": null,
    "phone": null,
    "accessToken": "<JWT_AQUI>",
    "emailVerifiedAt": null,
    "createdAt": "2025-11-16T12:00:00.000Z",
    "updatedAt": "2025-11-16T12:00:00.000Z"
  },
  "orgScope": {
    "currentOrganizationId": 2,
    "allowedOrgIds": null
  }
}
```

Esse `accessToken` (JWT) é o que o BOT poderá usar como `Bearer <token>` para acessar endpoints protegidos normalmente (incluindo `/api/auth/me`).

---

## 5. Resumo rápido para o frontend

- **Criar Agent:**
  - `POST /api/agents` com body contendo `role: "agent"` e `organizationId`.
  - Backend cria usuário, gera token permanente e envia email com **Token de Acesso**.

- **Listar Agents:**
  - `GET /api/agents?organizationId=<id>` para povoar listagens.

- **Resetar token de Agent:**
  - `POST /api/agents/:id/reset-token` para invalidar o token antigo e enviar um novo email com token.

- **Futuro login do BOT:**
  - `POST /api/auth/agent/verify-token` → envia OTP por email.
  - `POST /api/auth/agent/verify-otp` → retorna `user` + `orgScope` + JWT.
