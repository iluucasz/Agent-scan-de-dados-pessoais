class ScanConfigApi {
  final String name;
  final String description;
  final String sourceType;
  final ConnectionConfig connectionConfig;
  final ScanPattern scanPattern;
  final dynamic scanSchedule; // null por enquanto

  ScanConfigApi({
    required this.name,
    required this.description,
    this.sourceType = 'directory',
    required this.connectionConfig,
    required this.scanPattern,
    this.scanSchedule,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'sourceType': sourceType,
      'connectionConfig': connectionConfig.toJson(),
      'scanPattern': scanPattern.toJson(),
      'scanSchedule': scanSchedule,
    };
  }
}

class ConnectionConfig {
  final String baseDirectory;
  final bool recursive;

  ConnectionConfig({
    required this.baseDirectory,
    this.recursive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'baseDirectory': baseDirectory,
      'recursive': recursive,
    };
  }
}

class ScanPattern {
  final List<String> contentPatterns;
  final List<String> fileTypes;
  final int maxDepth;
  final int maxFileSize;

  ScanPattern({
    required this.contentPatterns,
    required this.fileTypes,
    this.maxDepth = 5,
    this.maxFileSize = 52428800, // 50MB
  });

  Map<String, dynamic> toJson() {
    return {
      'contentPatterns': contentPatterns,
      'fileTypes': fileTypes,
      'maxDepth': maxDepth,
      'maxFileSize': maxFileSize,
    };
  }
}

class ScanConfigResponse {
  final int id;
  final int organizationId;
  final String name;
  final String description;
  final String sourceType;
  final Map<String, dynamic> connectionConfig;
  final Map<String, dynamic> scanPattern;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScanConfigResponse({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.description,
    required this.sourceType,
    required this.connectionConfig,
    required this.scanPattern,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ScanConfigResponse.fromJson(Map<String, dynamic> json) {
    return ScanConfigResponse(
      id: json['id'] as int,
      organizationId: json['organizationId'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      sourceType: json['sourceType'] as String,
      connectionConfig: json['connectionConfig'] as Map<String, dynamic>,
      scanPattern: json['scanPattern'] as Map<String, dynamic>,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
