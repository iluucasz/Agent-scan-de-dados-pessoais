# Levantamento - Validacao de CPF e Dados Estruturados

Data: 2026-04-06

## Objetivo da demanda

- Implementar validacao de digito verificador para documentos estruturados, com foco imediato em CPF e CNPJ.
- Evitar falsos positivos para sequencias numericas que apenas parecem documentos validos.
- Definir a melhor abordagem para uma biblioteca de validacao dentro do contexto atual do app.

## Resumo executivo

- O scanner principal em uso e `FileScannerServiceImpl`; existe um `FileScannerService` mais simples, mas ele nao e o fluxo principal.
- O catalogo atual de deteccao em `lib/constants/data_patterns.dart` e baseado em regex de formato.
- O projeto ja detecta `CPF`, mas ainda nao possui `CNPJ` no catalogo de padroes.
- O sistema ja trata `cnpj` como criticidade alta em mapeamentos de serializacao, o que indica uma lacuna entre regra de negocio e catalogo.
- O modelo de resultado ja suporta `confidence`, `displayName`, `description`, `criticality`, `context` e `evidence`; nao e necessario remodelar o payload para viabilizar a melhoria.
- A UI de configuracao e listagem consome `DataPatterns.allPatterns`; portanto, adicionar um novo padrao no catalogo ja o propaga para a tela.
- Nao ha suite de testes automatizados no diretorio `test/`, o que aumenta o risco de regressao ao ajustar validacao documental.

## Arquivos relevantes analisados

- `pubspec.yaml`
- `lib/constants/data_patterns.dart`
- `lib/services/file_scanner_service.dart`
- `lib/services/file_scanner_service_impl.dart`
- `lib/services/scan_flow_service.dart`
- `lib/providers/scan_provider.dart`
- `lib/models/personal_data.dart`
- `lib/models/scan_config.dart`
- `lib/screens/scan_config_screen.dart`
- `lib/screens/patterns_list_screen.dart`
- `lib/screens/scan_results_screen.dart`

## Estado atual do projeto

### 1. Fluxo de scan efetivamente usado

- `ScanProvider` instancia `FileScannerServiceImpl` tanto no scan local quanto no fluxo com integracao de API.
- O arquivo `lib/services/file_scanner_service.dart` aparenta ser uma versao anterior ou simplificada do scanner.
- O caminho de menor risco para implementar a demanda e mexer em `FileScannerServiceImpl`, porque e ele que gera os `PersonalData` usados na UI e no envio externo.

### 2. Como a deteccao funciona hoje

- O scanner prepara os padroes a partir de `DataPatterns.allPatterns`.
- Cada padrao contem `id`, `name`, `description`, `category`, `regex` e `enabled`.
- O metodo `_scanFile` faz `regex.allMatches(line)` e gera um item `PersonalData` por match encontrado.
- A confianca atual e calculada por `_calculateConfidence` usando heuristicas genericas por categoria e tamanho do valor, sem qualquer validacao estrutural real.

### 3. Catalogo atual de padroes

- `CPF` existe com regex permissivo de formato: `\d{3}\.?\d{3}\.?\d{3}-?\d{2}`.
- `CNPJ` nao existe hoje em `DataPatterns.allPatterns`.
- A tela de configuracao usa `pattern.name` como identificador selecionado, nao `pattern.id`.
- Isso funciona no estado atual, mas torna a persistencia mais fragil se o nome de exibicao mudar no futuro.

### 4. Resultado e exibicao

- `PersonalData` ja suporta campos suficientes para enriquecer validacoes estruturadas.
- `scan_results_screen.dart` ja exibe a confianca do achado com rotulos como `Alta`, `Media` e `Baixa`.
- `ScanFlowService` ja normaliza e serializa metadados como `displayName`, `description` e `criticality`.
- Ou seja: a camada de resultado ja esta pronta para diferenciar melhor um documento estruturado validado de um match meramente textual.

## Gaps em relacao a demanda

### Gap 1. Regex sozinho nao garante validade

- Hoje qualquer sequencia que respeite a mascara de CPF passa pelo filtro.
- Isso inclui numeros com digito verificador incorreto e sequencias repetidas como `00000000000` ou `11111111111`.
- O resultado pratico e ruido alto e falso positivo em scans grandes.

### Gap 2. CNPJ faz parte do requisito, mas nao do catalogo

- A demanda menciona explicitamente `CPF, CNPJ, etc`.
- O projeto ja faz referencia a `cnpj` em mapeamentos de criticidade, mas o catalogo ainda nao expoe esse padrao.
- Sem adicionar `CNPJ` em `DataPatterns`, a funcionalidade nao aparece naturalmente na selecao de padroes nem na biblioteca exibida ao usuario.

### Gap 3. Nao existe biblioteca interna de validacao

- Hoje a regra de identificacao documental esta embutida no proprio catalogo via regex.
- Nao ha um modulo dedicado a normalizacao e validacao de documentos brasileiros.
- Isso dificulta testar, reaproveitar e expandir a solucao para outros documentos.

### Gap 4. Nao ha testes automatizados cobrindo essa regra

- O projeto nao possui arquivos em `test/`.
- Sem testes, um ajuste em regex, normalizacao ou confianca pode gerar regressao silenciosa.

## Possibilidades de implementacao

### Opcao A. Validacao estruturada acoplada ao scanner atual

Descricao:
Usar o fluxo atual de regex apenas como etapa de extracao de candidatos. Depois do match, normalizar o valor e validar o documento antes de criar `PersonalData`.

Como seria:

- Manter regex permissivo para capturar CPF/CNPJ com ou sem mascara.
- Remover pontuacao e espacos do valor encontrado.
- Rodar um validador especifico por `pattern.id`.
- Descartar o match quando o documento falhar na validacao estrutural.
- Elevar a confianca quando o documento passar na verificacao de digito.

Vantagens:

- Menor delta de codigo.
- Resolve diretamente o requisito de reduzir falso positivo.
- Reaproveita o pipeline atual sem alterar UI, provider ou payload.

Desvantagens:

- Se feito sem uma camada propria, a regra pode ficar espalhada no scanner.
- Escalabilidade pior quando entrar `PIS/PASEP`, `CNS`, `Titulo de Eleitor` e afins.

### Opcao B. Criar uma biblioteca interna de validacao documental

Descricao:
Criar um modulo proprio, por exemplo `lib/validators/structured_data_validators.dart`, com APIs puras para normalizacao e validacao de documentos estruturados.

Como seria:

- Expor metodos como `normalizeDigits`, `isRepeatedDigits`, `isValidCpf`, `isValidCnpj`.
- Opcionalmente expor um `StructuredValidationResult` contendo `normalizedValue`, `isValid`, `reason` e `confidenceBoost`.
- Fazer o scanner consumir esse modulo apos o match regex.

Vantagens:

- Atende literalmente ao item de `biblioteca de validacao`.
- Mantem a regra de negocio isolada, testavel e reutilizavel.
- Facilita crescimento para outros documentos brasileiros.
- Evita lock-in em pacote externo.

Desvantagens:

- Pequeno esforco inicial maior que apenas chamar um pacote.

### Opcao C. Usar biblioteca externa compativel

Levantamento rapido de pacotes:

- `brasil_fields`:
  - Metadata consultada pela API publica do pub.dev aponta versao `1.19.0`.
  - Compatibilidade declarada: `sdk >=3.0.0 <4.0.0`.
  - O README exposto no repositorio mostra APIs `UtilBrasilFields.isCPFValido` e `UtilBrasilFields.isCNPJValido`.
- `cpf_cnpj_validator`:
  - Metadata consultada pela API publica do pub.dev aponta versao `2.0.0`.
  - Compatibilidade declarada: `sdk >=2.12.0 <3.0.0`.
  - Portanto, nao e uma opcao segura para este projeto com SDK `^3.5.3`.

Vantagens:

- Reduz tempo de implementacao.
- Aproveita regra pronta do ecossistema.

Desvantagens:

- `brasil_fields` e um pacote Flutter mais amplo, nao uma lib enxuta focada apenas em validacao.
- Adiciona dependencia externa para uma regra que e pequena e estavel.
- Se usado diretamente em varios pontos, aumenta acoplamento do dominio com pacote de terceiros.

### Opcao D. Evoluir a arquitetura para matchers estruturados

Descricao:
Criar uma abstracao para padroes que precisam de algo alem de regex, como `PatternMatcher` ou `StructuredPatternMatcher`.

Como seria:

- Alguns padroes continuam apenas com regex.
- CPF/CNPJ passam a usar regex + normalizacao + validacao + politica de confianca.
- O scanner delega a decisao final do match ao matcher.

Vantagens:

- Arquitetura mais limpa para um catalogo que deve crescer.
- Facilita incorporar heuristicas por tipo de dado.

Desvantagens:

- Mais design do que o necessario para o escopo imediato.
- Pode ser excesso de estrutura para um MVP da historia.

## Recomendacao tecnica

Recomendo uma combinacao de `Opcao B + Opcao A`:

1. Criar uma biblioteca interna pura de validacao documental.
2. Integrar essa biblioteca ao `FileScannerServiceImpl` como pos-validacao do match regex.
3. Adicionar `CNPJ` ao catalogo de `DataPatterns`.
4. Ajustar a confianca de CPF/CNPJ validados para faixa alta.
5. Cobrir tudo com testes unitarios e pelo menos um teste de integracao do scanner.

Essa abordagem atende o requisito funcional, reduz ruido, nao depende de pacote desatualizado e deixa a base pronta para crescer com outros documentos estruturados.

## Impacto tecnico por area

### `lib/constants/data_patterns.dart`

- Adicionar `DataPattern` de `CNPJ`.
- Opcionalmente evoluir `DataPattern` para aceitar metadados de validacao, como um `validatorKey` ou um `structuredType`.
- Manter regex como extrator, nao como prova de validade.

### `lib/services/file_scanner_service_impl.dart`

- Inserir a etapa de pos-validacao antes de criar `PersonalData`.
- Ajustar `_calculateConfidence` para usar resultado estrutural real, em vez de apenas categoria.
- Possivelmente centralizar normalizacao do valor capturado antes de montar `evidence` e `context`.

### `lib/services/scan_flow_service.dart`

- Nao exige mudanca obrigatoria para iniciar.
- Ja existe compatibilidade conceitual com `cnpj` nos mapeamentos de criticidade, o que reduz impacto nessa camada.

### `lib/screens/scan_config_screen.dart`

- Ao adicionar `CNPJ` ao catalogo, ele passa a aparecer automaticamente para selecao.
- Pode ser interessante reavaliar os padroes selecionados por padrao se a historia pedir foco maior em documentos estruturados.

### `lib/screens/patterns_list_screen.dart`

- Passa a listar `CNPJ` automaticamente, sem alteracao estrutural na UI.

### `lib/models/scan_config.dart`

- Sem obrigatoriedade de mudanca para o MVP.
- Ponto de atencao: `selectedPatterns` usa nomes de exibicao. Em algum momento vale migrar para `id` para evitar fragilidade de persistencia.

## Regras minimas esperadas para CPF e CNPJ

- Remover mascara e qualquer caractere nao numerico antes de validar.
- Garantir comprimento exato do documento.
- Rejeitar sequencias com todos os digitos iguais.
- Recalcular os digitos verificadores e comparar com a entrada.
- Apenas gerar achado se o documento passar na validacao.

## Sugestao de desenho da biblioteca interna

Exemplo de estrutura:

- `lib/validators/structured_data_validators.dart`
- `lib/validators/br_documents/cpf_validator.dart`
- `lib/validators/br_documents/cnpj_validator.dart`

API minima sugerida:

```dart
abstract final class StructuredDataValidators {
  static String digitsOnly(String value);
  static bool isValidCpf(String value);
  static bool isValidCnpj(String value);
}
```

Opcionalmente:

```dart
class StructuredValidationResult {
  final bool isValid;
  final String normalizedValue;
  final String? reason;
  final double? confidence;

  const StructuredValidationResult({
    required this.isValid,
    required this.normalizedValue,
    this.reason,
    this.confidence,
  });
}
```

## Estrategia de testes recomendada

### Testes unitarios da biblioteca

- CPF valido com mascara.
- CPF valido sem mascara.
- CPF invalido com digito verificador incorreto.
- CPF invalido com digitos repetidos.
- CNPJ valido com mascara.
- CNPJ valido sem mascara.
- CNPJ invalido com digito verificador incorreto.
- CNPJ invalido com digitos repetidos.

### Testes do scanner

- Linha com CPF valido gera achado.
- Linha com sequencia numerica no formato de CPF, mas invalida, nao gera achado.
- Linha com CNPJ valido gera achado.
- Linha com CNPJ invalido nao gera achado.
- Confianca de documentos validados sobe para faixa alta.

## Riscos e atencoes

### Risco 1. Implementar no scanner errado

- Existe mais de um servico de scan no projeto.
- Se a alteracao for feita apenas em `FileScannerService`, a funcionalidade pode parecer pronta no codigo, mas nao entrar no fluxo real do app.

### Risco 2. Depender de nome exibido em vez de identificador tecnico

- Como `selectedPatterns` usa `pattern.name`, uma futura mudanca de rotulo pode quebrar configuracoes salvas.
- Nao e bloqueador para esta historia, mas merece entrar no backlog tecnico.

### Risco 3. Regex restritivo demais

- O ideal e manter regex suficientemente permissivo para capturar documentos com ou sem mascara.
- A validacao real deve acontecer na biblioteca de documentos, nao na regex.

### Risco 4. Falta de testes

- Como a demanda e exatamente sobre reduzir ruido, nao faz sentido entregar sem regressao automatizada minima.

## Caminho sugerido para implementacao

### Fase 1. MVP da historia

- Criar biblioteca interna com validacao de CPF e CNPJ.
- Adicionar `CNPJ` ao catalogo.
- Integrar pos-validacao no `FileScannerServiceImpl`.
- Ajustar confianca para matches validados.
- Criar testes unitarios e um teste do scanner.

### Fase 2. Expansao natural

- Estender a biblioteca para `PIS/PASEP`, `Cartao SUS`, `Titulo de Eleitor` e outros documentos com regra estrutural conhecida.
- Migrar `selectedPatterns` de `name` para `id`.
- Introduzir um mecanismo mais formal de `validatorKey` por padrao.

## Conclusao

O projeto ja possui a maior parte da infraestrutura necessaria para essa historia: catalogo centralizado de padroes, scanner com contexto por linha, modelo de resultado rico e UI pronta para refletir novos padroes. O problema central esta no fato de que a deteccao documental hoje para em regex de formato. A melhor saida para este codigo-base e adicionar uma biblioteca interna de validacao de documentos brasileiros e acopla-la ao scanner principal como etapa de confirmacao do match. Isso reduz falsos positivos, cobre CPF/CNPJ de forma correta e prepara o app para evoluir a deteccao de outros dados estruturados.