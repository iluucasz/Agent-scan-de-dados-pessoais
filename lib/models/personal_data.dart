class PersonalData {
  final String dataType;
  final String value;
  final String filePath;
  final int lineNumber;
  final double confidence;
  final String? context;
  final int? position;
  final String? category;
  final String? subcategory;
  final String? criticality;
  final String? displayName;
  final String? description;
  final String? evidence;
  final String? fileType;
  final String? parserType;

  PersonalData({
    required this.dataType,
    required this.value,
    required this.filePath,
    required this.lineNumber,
    required this.confidence,
    this.context,
    this.position,
    this.category,
    this.subcategory,
    this.criticality,
    this.displayName,
    this.description,
    this.evidence,
    this.fileType,
    this.parserType,
  });

  String get fileName {
    final parts = filePath.split(RegExp(r'[\\/]'));
    return parts.isNotEmpty ? parts.last : filePath;
  }

  String get confidenceLabel {
    if (confidence >= 0.9) return 'Alta';
    if (confidence >= 0.7) return 'Média';
    return 'Baixa';
  }

  Map<String, dynamic> toJson() => {
        'dataType': dataType,
        'value': value,
        'filePath': filePath,
        'lineNumber': lineNumber,
        'confidence': confidence,
      };

  factory PersonalData.fromJson(Map<String, dynamic> json) => PersonalData(
        dataType: json['dataType'],
        value: json['value'],
        filePath: json['filePath'],
        lineNumber: json['lineNumber'],
        confidence: json['confidence'],
      );
}

enum DataType {
  cpf('CPF'),
  email('E-mail'),
  phone('Telefone'),
  address('Endereço'),
  creditCard('Cartão de Crédito'),
  rg('RG'),
  passport('Passaporte'),
  other('Outros');

  final String label;
  const DataType(this.label);
}
