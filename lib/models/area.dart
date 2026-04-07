class Area {
  final int id;
  final String name;
  final String? description;
  final bool isActive;

  Area({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
  });

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
