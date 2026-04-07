class ScanJob {
  final int id;
  final int? configId;
  final int organizationId;
  final String status; // 'pending' | 'running' | 'completed' | 'failed'
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<FoundItem> foundItems;
  final ScanJobStats stats;
  final String? error;
  final DateTime createdAt;

  ScanJob({
    required this.id,
    this.configId,
    required this.organizationId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    required this.foundItems,
    required this.stats,
    this.error,
    required this.createdAt,
  });

  factory ScanJob.fromJson(Map<String, dynamic> json) {
    return ScanJob(
      id: json['id'] as int,
      configId: json['configId'] as int?,
      organizationId: json['organizationId'] as int,
      status: json['status'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      foundItems: (json['foundItems'] as List<dynamic>?)
              ?.map((item) => FoundItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      stats: ScanJobStats.fromJson(json['stats'] as Map<String, dynamic>),
      error: json['error'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'configId': configId,
      'organizationId': organizationId,
      'status': status,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'foundItems': foundItems.map((item) => item.toJson()).toList(),
      'stats': stats.toJson(),
      'error': error,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class FoundItem {
  final String type;
  final String value;
  final String file;
  final int line;
  final double confidence;
  final String? cdnUrl;

  FoundItem({
    required this.type,
    required this.value,
    required this.file,
    required this.line,
    required this.confidence,
    this.cdnUrl,
  });

  factory FoundItem.fromJson(Map<String, dynamic> json) {
    return FoundItem(
      type: json['type'] as String,
      value: json['value'] as String,
      file: json['file'] as String,
      line: json['line'] as int,
      confidence: (json['confidence'] as num).toDouble(),
      cdnUrl: json['cdnUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
      'file': file,
      'line': line,
      'confidence': confidence,
      'cdnUrl': cdnUrl,
    };
  }
}

class ScanJobStats {
  final int totalFiles;
  final int filesWithData;
  final int totalDataItems;
  final int executionTime;
  final int errors;
  final String? clientVersion;
  final Map<String, dynamic>? systemInfo;
  final Map<String, dynamic>? uploadResults;

  ScanJobStats({
    required this.totalFiles,
    required this.filesWithData,
    required this.totalDataItems,
    required this.executionTime,
    this.errors = 0,
    this.clientVersion,
    this.systemInfo,
    this.uploadResults,
  });

  factory ScanJobStats.fromJson(Map<String, dynamic> json) {
    return ScanJobStats(
      totalFiles: json['totalFiles'] as int,
      filesWithData: json['filesWithData'] as int,
      totalDataItems: json['totalDataItems'] as int,
      executionTime: json['executionTime'] as int,
      errors: json['errors'] as int? ?? 0,
      clientVersion: json['clientVersion'] as String?,
      systemInfo: json['systemInfo'] as Map<String, dynamic>?,
      uploadResults: json['uploadResults'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalFiles': totalFiles,
      'filesWithData': filesWithData,
      'totalDataItems': totalDataItems,
      'executionTime': executionTime,
      'errors': errors,
      'clientVersion': clientVersion,
      'systemInfo': systemInfo,
      'uploadResults': uploadResults,
    };
  }
}
