class Processo {
  final int id;
  final String name;
  final String? description;
  final String? purpose;
  final int areaId;
  final bool isActive;

  Processo({
    required this.id,
    required this.name,
    this.description,
    this.purpose,
    required this.areaId,
    required this.isActive,
  });

  factory Processo.fromJson(Map<String, dynamic> json) {
    return Processo(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      purpose: json['purpose'] as String?,
      areaId: json['areaId'] as int,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
