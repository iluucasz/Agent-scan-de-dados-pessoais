class ScanConfig {
  final String id;
  final String scanName;
  final String path;
  final List<String> selectedPatterns;
  final bool includeSubfolders;
  final int? maxFileSize;
  final DateTime createdAt;
  final String status; // 'pending', 'running', 'completed', 'failed'

  ScanConfig({
    required this.id,
    this.scanName = '',
    required this.path,
    required this.selectedPatterns,
    this.includeSubfolders = true,
    this.maxFileSize,
    required this.createdAt,
    this.status = 'pending',
  });

  factory ScanConfig.fromJson(Map<String, dynamic> json) {
    return ScanConfig(
      id: json['id'] as String,
      scanName: json['scan_name'] as String? ?? '',
      path: json['path'] as String,
      selectedPatterns: (json['selected_patterns'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      includeSubfolders: json['include_subfolders'] as bool? ?? true,
      maxFileSize: json['max_file_size'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: json['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scan_name': scanName,
      'path': path,
      'selected_patterns': selectedPatterns,
      'include_subfolders': includeSubfolders,
      'max_file_size': maxFileSize,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }

  ScanConfig copyWith({
    String? id,
    String? scanName,
    String? path,
    List<String>? selectedPatterns,
    bool? includeSubfolders,
    int? maxFileSize,
    DateTime? createdAt,
    String? status,
  }) {
    return ScanConfig(
      id: id ?? this.id,
      scanName: scanName ?? this.scanName,
      path: path ?? this.path,
      selectedPatterns: selectedPatterns ?? this.selectedPatterns,
      includeSubfolders: includeSubfolders ?? this.includeSubfolders,
      maxFileSize: maxFileSize ?? this.maxFileSize,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
