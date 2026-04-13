/// Sinal de contexto semântico ao redor de um match de dado detectado.
class ContextSignal {
  /// Score de -1.0 (contexto fortemente negativo) a 1.0 (fortemente positivo).
  /// 0.0 indica ausência de evidência contextual.
  final double score;

  /// Palavra-chave que gerou o sinal mais forte, se houver.
  final String? matchedKeyword;

  const ContextSignal({required this.score, this.matchedKeyword});

  static const neutral = ContextSignal(score: 0.0);
}

/// Analisador semântico de contexto ao redor de dados detectados.
///
/// Complementa a detecção por regex com análise do texto ao redor do match,
/// permitindo classificar dados apenas quando o contexto fizer sentido
/// (ex: "CPF: 529.982.247-25" vs "Protocolo: 52998224725").
abstract final class ContextAnalyzer {
  /// Analisa o contexto ao redor de um match e retorna um [ContextSignal].
  static ContextSignal analyze({
    required String patternId,
    required String line,
    required int matchStart,
    required int matchEnd,
  }) {
    // Janela de contexto: 80 chars antes e 40 depois do match.
    final contextStart = (matchStart - 80).clamp(0, line.length);
    final contextEnd = (matchEnd + 40).clamp(0, line.length);
    final contextText = line.substring(contextStart, contextEnd).toLowerCase();

    final positiveKeywords = _positiveContext[patternId];
    final negativeKeywords = _negativeContext[patternId];

    if (positiveKeywords == null && negativeKeywords == null) {
      return ContextSignal.neutral;
    }

    double score = 0.0;
    String? matchedKeyword;

    // Verifica palavras-chave positivas (label do campo, rótulo, etc.)
    if (positiveKeywords != null) {
      for (final keyword in positiveKeywords) {
        if (contextText.contains(keyword)) {
          score += 0.35;
          matchedKeyword = keyword;
          break;
        }
      }
    }

    // Verifica palavras-chave negativas (contextos onde o número não é o dado)
    if (negativeKeywords != null) {
      for (final keyword in negativeKeywords) {
        if (contextText.contains(keyword)) {
          score -= 0.50;
          matchedKeyword ??= keyword;
          break;
        }
      }
    }

    return ContextSignal(
      score: score.clamp(-1.0, 1.0),
      matchedKeyword: matchedKeyword,
    );
  }

  /// Retorna `true` para padrões cuja regex é genérica o bastante para
  /// produzir muitos falsos positivos sem evidência contextual.
  ///
  /// Para esses padrões, sem contexto positivo E sem validação estrutural,
  /// o match é descartado.
  static bool isAmbiguousPattern(String patternId) {
    return _ambiguousPatterns.contains(patternId);
  }

  // ─── Padrões ambíguos ───────────────────────────────────────────────

  static const _ambiguousPatterns = <String>{
    'rg',
    'cnh',
    'titulo_eleitor',
    'pis_pasep',
    'cep',
    'data_nascimento',
    'cartao_sus',
    'coordenadas_gps',
    'endereco_ip',
    'placa_veiculo',
    'nome_completo',
  };

  // ─── Palavras-chave de contexto positivo por padrão ─────────────────

  static const _positiveContext = <String, List<String>>{
    'cpf': [
      'cpf',
      'cadastro pessoa',
      'contribuinte',
      'pessoa física',
      'pessoa fisica',
    ],
    'cnpj': [
      'cnpj',
      'pessoa jurídica',
      'pessoa juridica',
      'razão social',
      'razao social',
      'inscrição estadual',
      'inscricao estadual',
    ],
    'rg': [
      'rg',
      'registro geral',
      'identidade',
      'ssp',
      'órgão emissor',
      'orgao emissor',
    ],
    'cnh': [
      'cnh',
      'habilitação',
      'habilitacao',
      'carteira de motorista',
      'renach',
    ],
    'titulo_eleitor': [
      'título de eleitor',
      'titulo de eleitor',
      'eleitor',
      'zona eleitoral',
      'seção eleitoral',
      'secao eleitoral',
    ],
    'pis_pasep': [
      'pis',
      'pasep',
      'nis',
      'nit',
    ],
    'cartao_credito': [
      'cartão',
      'cartao',
      'crédito',
      'credito',
      'débito',
      'debito',
      'visa',
      'mastercard',
      'master',
      'elo',
      'bandeira',
    ],
    'email': [
      'email',
      'e-mail',
      'correio',
      'mail',
    ],
    'telefone': [
      'telefone',
      'tel:',
      'tel.',
      'fone',
      'contato',
      'ligar',
    ],
    'celular': [
      'celular',
      'cel:',
      'cel.',
      'whatsapp',
      'whats',
      'mobile',
    ],
    'cep': [
      'cep',
      'código postal',
      'codigo postal',
      'endereço',
      'endereco',
      'bairro',
    ],
    'data_nascimento': [
      'nascimento',
      'nascido',
      'data de nascimento',
      'dt. nasc',
      'dt nasc',
      'idade',
      'aniversário',
      'aniversario',
    ],
    'cartao_sus': [
      'sus',
      'cns',
      'saúde',
      'saude',
      'cartão nacional de saúde',
      'cartao nacional de saude',
    ],
    'coordenadas_gps': [
      'latitude',
      'longitude',
      'coordenada',
      'gps',
      'geolocalização',
      'geolocalizacao',
      'lat',
      'lng',
      'lon',
    ],
    'endereco_ip': [
      'ip',
      'endereço ip',
      'endereco ip',
      'host',
      'servidor',
      'server',
    ],
    'placa_veiculo': [
      'placa',
      'veículo',
      'veiculo',
      'carro',
      'automóvel',
      'automovel',
      'detran',
    ],
    'nome_completo': [
      'nome',
      'responsável',
      'responsavel',
      'titular',
      'paciente',
      'cliente',
      'funcionário',
      'funcionario',
      'colaborador',
    ],
  };

  // ─── Palavras-chave de contexto negativo por padrão ─────────────────

  static const _negativeContext = <String, List<String>>{
    'cpf': [
      'protocolo',
      'pedido',
      'serial',
      'nota fiscal',
      'nf-e',
      'ordem de serviço',
      'ordem de servico',
      'os:',
    ],
    'cnpj': [
      'protocolo',
      'pedido',
      'serial',
    ],
    'rg': [
      'serial',
      'versão',
      'versao',
      'código',
      'codigo',
    ],
    'telefone': [
      'versão',
      'versao',
      'port:',
      'porta:',
    ],
    'celular': [
      'versão',
      'versao',
      'port:',
      'porta:',
    ],
    'cep': [
      'serial',
      'versão',
      'versao',
      'id:',
    ],
    'data_nascimento': [
      'emissão',
      'emissao',
      'vencimento',
      'validade',
      'prazo',
      'criado em',
      'atualizado em',
      'publicação',
      'publicacao',
    ],
    'cartao_credito': [
      'ip',
      'serial',
      'protocolo',
    ],
    'cartao_sus': [
      'protocolo',
      'pedido',
      'serial',
      'ip',
    ],
    'coordenadas_gps': [
      'versão',
      'versao',
      'preço',
      'preco',
      'valor',
    ],
    'endereco_ip': [
      'versão',
      'versao',
    ],
    'nome_completo': [
      'import',
      'class ',
      'function',
      'const ',
      'var ',
      'package',
    ],
  };
}
