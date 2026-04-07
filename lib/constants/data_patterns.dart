enum PatternCategory {
  id('ID', 'Documentos de Identificação'),
  personal('PERSONAL', 'Dados Pessoais'),
  contact('CONTACT', 'Dados de Contato'),
  financial('FINANCIAL', 'Dados Financeiros'),
  sensitive('SENSITIVE', 'Dados Sensíveis'),
  health('HEALTH', 'Dados de Saúde'),
  biometric('BIOMETRIC', 'Dados Biométricos'),
  location('LOCATION', 'Dados de Localização');

  final String code;
  final String label;
  const PatternCategory(this.code, this.label);
}

enum StructuredDataValidatorType {
  cpf,
  cnpj,
  creditCard,
}

class DataPattern {
  final String id;
  final String name;
  final String description;
  final PatternCategory category;
  final String regex;
  final bool enabled;
  final StructuredDataValidatorType? structuredValidator;

  const DataPattern({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.regex,
    this.enabled = true,
    this.structuredValidator,
  });
}

// Catálogo completo de padrões de dados pessoais (baseado no projeto React)
class DataPatterns {
  // ========== DOCUMENTOS DE IDENTIFICAÇÃO ==========

  static const cpf = DataPattern(
    id: 'cpf',
    name: 'CPF',
    description: 'Cadastro de Pessoa Física',
    category: PatternCategory.id,
    regex: r'(?<!\d)\d{3}\.?\d{3}\.?\d{3}-?\d{2}(?!\d)',
    structuredValidator: StructuredDataValidatorType.cpf,
  );

  static const cnpj = DataPattern(
    id: 'cnpj',
    name: 'CNPJ',
    description: 'Cadastro Nacional da Pessoa Jurídica',
    category: PatternCategory.id,
    regex: r'(?<!\d)\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}(?!\d)',
    structuredValidator: StructuredDataValidatorType.cnpj,
  );

  static const rg = DataPattern(
    id: 'rg',
    name: 'RG',
    description: 'Registro Geral',
    category: PatternCategory.id,
    regex: r'\d{1,2}\.?\d{3}\.?\d{3}-?[0-9xX]',
  );

  static const cnh = DataPattern(
    id: 'cnh',
    name: 'CNH',
    description: 'Carteira Nacional de Habilitação',
    category: PatternCategory.id,
    regex: r'\d{11}',
  );

  static const passaporte = DataPattern(
    id: 'passaporte',
    name: 'Passaporte',
    description: 'Número de Passaporte Brasileiro',
    category: PatternCategory.id,
    regex: r'[A-Z]{2}\d{6}',
  );

  static const tituloEleitor = DataPattern(
    id: 'titulo_eleitor',
    name: 'Título de Eleitor',
    description: 'Título de Eleitor',
    category: PatternCategory.id,
    regex: r'(?<!\d)\d{4}\s?\d{4}\s?\d{4}(?!\d)',
  );

  static const pisPasep = DataPattern(
    id: 'pis_pasep',
    name: 'PIS/PASEP',
    description: 'Programa de Integração Social',
    category: PatternCategory.id,
    regex: r'\d{3}\.?\d{5}\.?\d{2}-?\d',
  );

  static const ctps = DataPattern(
    id: 'ctps',
    name: 'CTPS',
    description: 'Carteira de Trabalho',
    category: PatternCategory.id,
    regex: r'\d{7}\s?série\s?\d{4}',
  );

  static const certidaoNascimento = DataPattern(
    id: 'certidao_nascimento',
    name: 'Certidão de Nascimento',
    description: 'Número da Certidão de Nascimento',
    category: PatternCategory.id,
    regex: r'\d{6}\s?\d{2}\s?\d{2}\s?\d{4}\s?\d\s?\d{5}\s?\d{3}\s?\d{7}-?\d{2}',
  );

  // ========== DADOS PESSOAIS ==========

  static const nomeCompleto = DataPattern(
    id: 'nome_completo',
    name: 'Nome Completo',
    description: 'Nome completo de pessoa',
    category: PatternCategory.personal,
    regex:
        r'[A-ZÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÇ][a-zàáâãèéêìíòóôõùúç]+\s+[A-ZÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÇ][a-zàáâãèéêìíòóôõùúç]+',
  );

  static const dataNascimento = DataPattern(
    id: 'data_nascimento',
    name: 'Data de Nascimento',
    description: 'Data de nascimento no formato DD/MM/AAAA',
    category: PatternCategory.personal,
    regex: r'\d{2}/\d{2}/\d{4}',
  );

  static const nomeMae = DataPattern(
    id: 'nome_mae',
    name: 'Nome da Mãe',
    description: 'Nome completo da mãe',
    category: PatternCategory.personal,
    regex:
        r'(?:mãe|mae|mother):\s*[A-ZÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÇ][a-zàáâãèéêìíòóôõùúç\s]+',
  );

  static const nomePai = DataPattern(
    id: 'nome_pai',
    name: 'Nome do Pai',
    description: 'Nome completo do pai',
    category: PatternCategory.personal,
    regex: r'(?:pai|father):\s*[A-ZÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÇ][a-zàáâãèéêìíòóôõùúç\s]+',
  );

  // ========== DADOS DE CONTATO ==========

  static const email = DataPattern(
    id: 'email',
    name: 'Email',
    description: 'Endereço de e-mail',
    category: PatternCategory.contact,
    regex: r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  static const telefone = DataPattern(
    id: 'telefone',
    name: 'Telefone',
    description: 'Telefone fixo ou celular',
    category: PatternCategory.contact,
    regex: r'\(?\d{2}\)?\s?\d{4,5}-?\d{4}',
  );

  static const celular = DataPattern(
    id: 'celular',
    name: 'Celular',
    description: 'Número de celular',
    category: PatternCategory.contact,
    regex: r'\(?\d{2}\)?\s?9\d{4}-?\d{4}',
  );

  static const cep = DataPattern(
    id: 'cep',
    name: 'CEP',
    description: 'Código de Endereçamento Postal',
    category: PatternCategory.contact,
    regex: r'\d{5}-?\d{3}',
  );

  static const endereco = DataPattern(
    id: 'endereco',
    name: 'Endereço',
    description: 'Endereço completo',
    category: PatternCategory.contact,
    regex: r'(?:rua|av|avenida|alameda|travessa)\s+[A-Za-zÀ-ÿ\s]+,?\s*\d+',
  );

  // ========== DADOS FINANCEIROS ==========

  static const cartaoCredito = DataPattern(
    id: 'cartao_credito',
    name: 'Cartão de Crédito',
    description: 'Número de cartão de crédito',
    category: PatternCategory.financial,
    regex: r'(?<!\d)\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}(?!\d)',
    structuredValidator: StructuredDataValidatorType.creditCard,
  );

  static const cvv = DataPattern(
    id: 'cvv',
    name: 'CVV',
    description: 'Código de segurança do cartão',
    category: PatternCategory.financial,
    regex: r'(?:cvv|cvc|código de segurança):\s?\d{3,4}',
  );

  static const contaBancaria = DataPattern(
    id: 'conta_bancaria',
    name: 'Conta Bancária',
    description: 'Número de conta bancária',
    category: PatternCategory.financial,
    regex: r'(?:conta|cc|c\/c):\s?\d{4,12}-?\d',
  );

  static const agenciaBancaria = DataPattern(
    id: 'agencia_bancaria',
    name: 'Agência Bancária',
    description: 'Número de agência bancária',
    category: PatternCategory.financial,
    regex: r'(?:agência|ag):\s?\d{4}-?\d?',
  );

  static const pix = DataPattern(
    id: 'pix',
    name: 'Chave PIX',
    description: 'Chave PIX (CPF, email, telefone ou aleatória)',
    category: PatternCategory.financial,
    regex: r'(?:pix|chave pix):\s?[a-zA-Z0-9._%+-@\-]+',
  );

  static const salario = DataPattern(
    id: 'salario',
    name: 'Salário',
    description: 'Valor de salário',
    category: PatternCategory.financial,
    regex: r'(?:salário|salario|remuneração):\s?R\$\s?\d+\.?\d*,\d{2}',
  );

  // ========== DADOS SENSÍVEIS ==========

  static const senhaTexto = DataPattern(
    id: 'senha_texto',
    name: 'Senha em Texto',
    description: 'Senha armazenada em texto plano',
    category: PatternCategory.sensitive,
    regex: r'(?:senha|password|pwd):\s?[\w!@#\$%\^&\*]+',
  );

  static const tokenAcesso = DataPattern(
    id: 'token_acesso',
    name: 'Token de Acesso',
    description: 'Token de autenticação/API',
    category: PatternCategory.sensitive,
    regex: r'(?:token|access_token|bearer):\s?[A-Za-z0-9_\-\.]+',
  );

  static const chaveApi = DataPattern(
    id: 'chave_api',
    name: 'Chave de API',
    description: 'API Key',
    category: PatternCategory.sensitive,
    regex: r'(?:api_key|apikey):\s?[A-Za-z0-9_\-]+',
  );

  // ========== DADOS DE SAÚDE ==========

  static const cartaoSus = DataPattern(
    id: 'cartao_sus',
    name: 'Cartão SUS',
    description: 'Número do Cartão Nacional de Saúde',
    category: PatternCategory.health,
    regex: r'\d{3}\s?\d{4}\s?\d{4}\s?\d{4}',
  );

  static const diagnostico = DataPattern(
    id: 'diagnostico',
    name: 'Diagnóstico Médico',
    description: 'Diagnóstico ou condição de saúde',
    category: PatternCategory.health,
    regex: r'(?:diagnóstico|diagnostico|doença|patologia):\s?[A-Za-zÀ-ÿ\s]+',
  );

  static const medicamento = DataPattern(
    id: 'medicamento',
    name: 'Medicamento',
    description: 'Nome de medicamento',
    category: PatternCategory.health,
    regex: r'(?:medicamento|remédio|droga):\s?[A-Za-zÀ-ÿ\s]+',
  );

  static const prontuario = DataPattern(
    id: 'prontuario',
    name: 'Prontuário',
    description: 'Número de prontuário médico',
    category: PatternCategory.health,
    regex: r'(?:prontuário|prontuario):\s?\d+',
  );

  static const exame = DataPattern(
    id: 'exame',
    name: 'Resultado de Exame',
    description: 'Resultado de exame médico',
    category: PatternCategory.health,
    regex: r'(?:exame|resultado|laudo):\s?[A-Za-zÀ-ÿ0-9\s\.,]+',
  );

  // ========== DADOS BIOMÉTRICOS ==========

  static const impressaoDigital = DataPattern(
    id: 'impressao_digital',
    name: 'Impressão Digital',
    description: 'Dados de impressão digital',
    category: PatternCategory.biometric,
    regex: r'(?:impressão digital|fingerprint|biometria)',
  );

  static const reconhecimentoFacial = DataPattern(
    id: 'reconhecimento_facial',
    name: 'Reconhecimento Facial',
    description: 'Dados de reconhecimento facial',
    category: PatternCategory.biometric,
    regex: r'(?:reconhecimento facial|face recognition|facial)',
  );

  static const iris = DataPattern(
    id: 'iris',
    name: 'Íris',
    description: 'Dados de íris',
    category: PatternCategory.biometric,
    regex: r'(?:íris|iris|biometria ocular)',
  );

  // ========== DADOS DE LOCALIZAÇÃO ==========

  static const coordenadasGps = DataPattern(
    id: 'coordenadas_gps',
    name: 'Coordenadas GPS',
    description: 'Latitude e longitude',
    category: PatternCategory.location,
    regex: r'-?\d{1,3}\.\d+,\s?-?\d{1,3}\.\d+',
  );

  static const latitude = DataPattern(
    id: 'latitude',
    name: 'Latitude',
    description: 'Coordenada de latitude',
    category: PatternCategory.location,
    regex: r'(?:lat|latitude):\s?-?\d{1,3}\.\d+',
  );

  static const longitude = DataPattern(
    id: 'longitude',
    name: 'Longitude',
    description: 'Coordenada de longitude',
    category: PatternCategory.location,
    regex: r'(?:lon|lng|longitude):\s?-?\d{1,3}\.\d+',
  );

  static const enderecoIp = DataPattern(
    id: 'endereco_ip',
    name: 'Endereço IP',
    description: 'Endereço IP v4',
    category: PatternCategory.location,
    regex: r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}',
  );

  static const placaVeiculo = DataPattern(
    id: 'placa_veiculo',
    name: 'Placa de Veículo',
    description: 'Placa de veículo (Mercosul ou antiga)',
    category: PatternCategory.location,
    regex: r'[A-Z]{3}-?\d{1}[A-Z0-9]{1}\d{2}',
  );

  // Lista completa de todos os padrões
  static List<DataPattern> get allPatterns => [
        // ID
        cpf, cnpj, rg, cnh, passaporte, tituloEleitor, pisPasep, ctps,
        certidaoNascimento,
        // PERSONAL
        nomeCompleto, dataNascimento, nomeMae, nomePai,
        // CONTACT
        email, telefone, celular, cep, endereco,
        // FINANCIAL
        cartaoCredito, cvv, contaBancaria, agenciaBancaria, pix, salario,
        // SENSITIVE
        senhaTexto, tokenAcesso, chaveApi,
        // HEALTH
        cartaoSus, diagnostico, medicamento, prontuario, exame,
        // BIOMETRIC
        impressaoDigital, reconhecimentoFacial, iris,
        // LOCATION
        coordenadasGps, latitude, longitude, enderecoIp, placaVeiculo,
      ];

  // Obter padrões por categoria
  static List<DataPattern> getByCategory(PatternCategory category) {
    return allPatterns.where((p) => p.category == category).toList();
  }

  // Obter padrão por ID
  static DataPattern? getById(String id) {
    try {
      return allPatterns.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  // Contar total de padrões
  static int get totalPatterns => allPatterns.length;

  // Contar por categoria
  static Map<PatternCategory, int> get countByCategory {
    final map = <PatternCategory, int>{};
    for (var pattern in allPatterns) {
      map[pattern.category] = (map[pattern.category] ?? 0) + 1;
    }
    return map;
  }
}
