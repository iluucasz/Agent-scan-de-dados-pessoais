# Plano: Aba "Deploy Corporativo" na Sidebar

## Objetivo

Adicionar uma aba dedicada na sidebar do Agent Desktop para clientes corporativos que precisam
distribuir o agent em massa via GPO, Intune, SCCM, PDQ ou PowerShell remoto — sem depender
de interação do usuário final.

A aba deve aparecer **somente para organizações com perfil corporativo** (ex.: role `admin`
ou flag `enterprise_deployment` no plano/contrato da organização).

---

## 1. Visão Geral da Aba

**Label na sidebar:** `Deploy Corporativo`
**Ícone sugerido:** `Icons.corporate_fare` ou `Icons.dns`
**Posição:** Entre `Padrões de Dados` e `Configurações`
**Acesso condicional:** Visível apenas para admins/enterprise

---

## 2. Seções internas da tela

### 2.1 — Gerador de Pacote MSI / Instalador Silencioso

- Botão para baixar o instalador (.exe com suporte a `/silent`) ou gerar link de download interno.
- Exibe a versão atual do Agent.
- Exibe hash SHA-256 do instalador (para validação pela TI).
- Parâmetros suportados documentados em tela:
  ```
  MeuAgentSetup.exe /silent /token=TOKEN_ORG /server=https://api.seusdados.com
  msiexec /i MeuAgent.msi /qn TOKEN=TOKEN_ORG SERVER_URL=https://api.seusdados.com
  ```

### 2.2 — Token de Provisionamento da Organização

- Exibe o `org_token` (token de autenticação pré-configurado para deploy em massa).
- Botão "Gerar novo token" (invalida o anterior).
- Botão "Copiar token".
- Aviso de segurança: o token autentica a organização, não o usuário individual.
- O Agent instalado via GPO usa esse token para se registrar automaticamente no backend
  sem que o colaborador precise fazer login.

### 2.3 — Guias de Deploy (Documentação embutida)

Tabs ou accordion com guias rápidos:

#### GPO via Active Directory
```
1. Copie o .msi para um compartilhamento de rede acessível aos endpoints
   \\\\servidor\pacotes\MeuAgent.msi

2. No AD, crie um GPO em: Configuração do Computador > Políticas >
   Configurações de Software > Instalação de Software

3. Aponte para o caminho UNC do .msi
4. Aplique ao grupo/OU desejado
5. Os endpoints instalam automaticamente no próximo logon/reboot
```

#### PowerShell Remoto
```powershell
$computers = @("PC1", "PC2", "PC3")
Invoke-Command -ComputerName $computers -ScriptBlock {
    Start-Process "\\\\servidor\pacotes\MeuAgentSetup.exe" `
        -ArgumentList "/silent /token=SEU_TOKEN" -Wait
}
```

#### Intune (Modern Management)
```
1. Converta o .exe para .intunewin usando a ferramenta Microsoft Win32 Content Prep Tool
2. No Intune Portal > Apps > Windows > Add App (Win32)
3. Install command: MeuAgentSetup.exe /silent /token=TOKEN
4. Uninstall command: MeuAgentSetup.exe /uninstall /silent
5. Detection rule: verificar existência de chave de registro ou arquivo
6. Atribua ao grupo de dispositivos/usuários desejado
```

#### SCCM / MECM
```
1. Crie um Package or Application apontando para o instalador
2. Install Program: MeuAgentSetup.exe /silent /token=TOKEN
3. Crie um Deployment para a Collection desejada
4. Defina janela de manutenção se necessário
```

#### PDQ Deploy
```
1. Crie um Package no PDQ Deploy
2. Step 1: Install — MeuAgentSetup.exe /silent /token=TOKEN
3. Selecione os targets (computadores/grupos)
4. Deploy Now ou agende para janela de manutenção
```

### 2.4 — Status de Endpoints (Futuro / Fase 2)

> Esta seção pode ficar como placeholder na Fase 1 com label "Em breve".

- Lista de endpoints que já têm o Agent instalado e ativo.
- Status: `Ativo`, `Sem heartbeat`, `Desatualizado`.
- Coluna: versão instalada, última sincronização, hostname.
- Botão: "Exportar CSV".

Requer: backend implementar tabela `agent_endpoints` com heartbeat periódico do Agent.

---

## 3. Mudanças no Flutter

### 3.1 — `dashboard_layout.dart`

Adicionar item na lista `_navItems` e tela na lista `_screens`, condicionalmente por role:

```dart
// Em _navItems (condicional):
if (authProvider.user?.role == 'admin')
  _NavItem(
    icon: Icons.corporate_fare,
    label: 'Deploy Corporativo',
    route: '/corporate-deploy',
  ),

// Em _screens (na mesma posição):
if (authProvider.user?.role == 'admin')
  const CorporateDeployScreen(),
```

> Atenção: como `_navItems` e `_screens` são listas paralelas por índice, o ideal é
> refatorar para um modelo `_NavItem` que carregue também a `screen` widget associada,
> evitando desalinhamento de índices.

### 3.2 — Nova tela `lib/screens/corporate_deploy_screen.dart`

Estrutura de widgets sugerida:

```
CorporateDeployScreen
├── Header (título + descrição)
├── PackageDownloadCard
│   ├── versão atual
│   ├── hash SHA-256
│   └── botão download / link interno
├── OrgTokenCard
│   ├── exibe token (obscurecido por padrão)
│   ├── botão mostrar/ocultar
│   ├── botão copiar
│   └── botão regenerar
└── DeployGuidesSection
    └── TabBar: GPO | PowerShell | Intune | SCCM | PDQ
        └── cada tab exibe bloco de código copiável + passos em texto
```

---

## 4. Mudanças no Backend

### 4.1 — Endpoint: token de provisionamento

```
GET  /api/organizations/:id/deploy-token   → retorna token atual
POST /api/organizations/:id/deploy-token/regenerate → gera novo token
```

O token é salvo na tabela `organizations` (nova coluna `deploy_token` + `deploy_token_created_at`).

### 4.2 — Autenticação por token de organização (Agent instalado via GPO)

O Agent recém-instalado, sem usuário logado, deve conseguir se autenticar usando o `deploy_token`:

```
POST /api/agent/activate
Body: { "deploy_token": "...", "hostname": "...", "machine_id": "..." }
Response: { "agent_session_token": "...", "org_id": "..." }
```

O `agent_session_token` gerado é usado para todas as chamadas subsequentes do Agent
(scans, heartbeat, etc.) sem exigir login do colaborador.

### 4.3 — Tabela `agent_endpoints` (Fase 2)

```sql
CREATE TABLE agent_endpoints (
  id            SERIAL PRIMARY KEY,
  org_id        INTEGER REFERENCES organizations(id),
  hostname      TEXT NOT NULL,
  machine_id    TEXT UNIQUE NOT NULL,
  agent_version TEXT,
  last_seen_at  TIMESTAMP,
  status        TEXT DEFAULT 'active',
  created_at    TIMESTAMP DEFAULT NOW()
);
```

---

## 5. Mudanças no Instalador / Empacotamento

| Item | Detalhe |
|------|---------|
| Formato | `.exe` com NSIS ou Inno Setup + `.msi` via WiX Toolset |
| Silent install | `/silent /token=TOKEN /server=URL` |
| Silent uninstall | `/uninstall /silent` |
| Config inicial | Grava `%ProgramData%\SeusDados\config.json` com token + server URL |
| Registro Windows | Chave `HKLM\Software\SeusDados\AgentVersion` para detection rule do Intune/SCCM |
| Serviço Windows | Opcional: registrar como serviço para rodar sem usuário logado |

---

## 6. Controle de Acesso (Quem vê a aba)

| Condição | Vê a aba? |
|----------|-----------|
| Role `admin` + plano enterprise | Sim |
| Role `admin` + plano básico | Não (ou readonly com upsell) |
| Role `user` qualquer plano | Não |

A validação deve ser dupla: no Flutter (esconde o item da sidebar) e no backend
(retorna 403 nos endpoints de deploy se a organização não tiver o plano habilitado).

---

## 7. Fases de Entrega

### Fase 1 — MVP (sidebar funcional)
- [ ] Tela com guias de deploy (GPO, PowerShell, Intune, SCCM, PDQ) — conteúdo estático
- [ ] Card de download do instalador (link fixo para versão atual)
- [ ] Card de token de provisionamento (get + regenerate)
- [ ] Controle de visibilidade por role no Flutter
- [ ] Endpoints de token no backend

### Fase 2 — Endpoints com heartbeat
- [ ] Agent envia heartbeat periódico ao backend
- [ ] Tabela `agent_endpoints` no banco
- [ ] Tela de status de endpoints na aba

### Fase 3 — Instalador corporativo completo
- [ ] Build pipeline gerando `.msi` via WiX
- [ ] Suporte a parâmetros de instalação silenciosa
- [ ] Detection rule documentada para Intune/SCCM
- [ ] Documentação oficial para TI da empresa cliente

---

## 8. Resumo de Arquivos a Criar/Alterar

| Arquivo | Ação |
|---------|------|
| `lib/screens/dashboard_layout.dart` | Adicionar item condicional na sidebar |
| `lib/screens/corporate_deploy_screen.dart` | Criar tela nova |
| `lib/widgets/deploy_guide_tabs.dart` | Widget de guias copiáveis |
| `lib/widgets/org_token_card.dart` | Widget de token |
| `backend/server/routes/deploy.ts` | Endpoints de token |
| `backend/migrations/XXXX_add_deploy_token.sql` | Coluna deploy_token na organização |
