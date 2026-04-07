/// Modelo alinhado com GET /api/data-scan-jobs/:id do backend.
/// Status possíveis: 'pending' | 'in_progress' | 'completed' | 'failed'
class ScanJob {
  final int id;
  final int? configId;
  final int organizationId;
  final String status;
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
      id: _safeInt(json['id']),
      configId: json['configId'] != null ? _safeInt(json['configId']) : null,
      organizationId: _safeInt(json['organizationId']),
      status: _safeString(json['status'], 'unknown'),
      startedAt: _safeDateTime(json['startedAt']) ?? DateTime.now(),
      completedAt: _safeDateTime(json['completedAt']),
      foundItems: _safeList(json['foundItems'])
          .map((item) =>
              FoundItem.fromJson(item is Map<String, dynamic> ? item : {}))
          .toList(),
      stats: json['stats'] is Map<String, dynamic>
          ? ScanJobStats.fromJson(json['stats'] as Map<String, dynamic>)
          : ScanJobStats(
              totalFiles: 0,
              filesWithData: 0,
              totalDataItems: 0,
              executionTime: 0),
      error: json['error']?.toString(),
      createdAt: _safeDateTime(json['createdAt']) ?? DateTime.now(),
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

/// Backend retorna: dataType, category, subcategory, criticality, value,
/// file, fileName, location, matches, line, cdnUrl, uploadUrl, id
class FoundItem {
  final String type;
  final String? category;
  final String? subcategory;
  final String? criticality;
  final String value;
  final String file;
  final String? fileName;
  final String? location;
  final int matches;
  final int line;
  final double confidence;
  final String? cdnUrl;
  final String? uploadUrl;

  FoundItem({
    required this.type,
    this.category,
    this.subcategory,
    this.criticality,
    required this.value,
    required this.file,
    this.fileName,
    this.location,
    this.matches = 1,
    required this.line,
    required this.confidence,
    this.cdnUrl,
    this.uploadUrl,
  });

  factory FoundItem.fromJson(Map<String, dynamic> json) {
    return FoundItem(
      // Backend envia 'dataType', fallback para 'type'
      type: _safeString(json['dataType'] ?? json['type'], ''),
      category: json['category']?.toString(),
      subcategory: json['subcategory']?.toString(),
      criticality: json['criticality']?.toString(),
      value: _safeString(json['value'], ''),
      file: _safeString(json['file'], ''),
      fileName: json['fileName']?.toString(),
      location: json['location']?.toString(),
      matches: _safeInt(json['matches'], 1),
      line: _safeInt(json['line']),
      confidence: _safeDouble(json['confidence']),
      cdnUrl: json['cdnUrl']?.toString(),
      uploadUrl: json['uploadUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dataType': type,
      'type': type,
      'category': category,
      'subcategory': subcategory,
      'criticality': criticality,
      'value': value,
      'file': file,
      'fileName': fileName,
      'location': location,
      'matches': matches,
      'line': line,
      'confidence': confidence,
      'cdnUrl': cdnUrl,
      'uploadUrl': uploadUrl,
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
      totalFiles: _safeInt(json['totalFiles']),
      filesWithData: _safeInt(json['filesWithData']),
      totalDataItems: _safeInt(json['totalDataItems']),
      executionTime: _safeInt(json['executionTime']),
      errors: _safeInt(json['errors']),
      clientVersion: json['clientVersion']?.toString(),
      systemInfo: json['systemInfo'] is Map<String, dynamic>
          ? json['systemInfo'] as Map<String, dynamic>
          : null,
      uploadResults: json['uploadResults'] is Map<String, dynamic>
          ? json['uploadResults'] as Map<String, dynamic>
          : null,
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

// ──────── helpers seguros para parsing ────────

String _safeString(dynamic v, [String fallback = '']) =>
    v is String ? v : (v?.toString() ?? fallback);

int _safeInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _safeDouble(dynamic v, [double fallback = 0.0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

DateTime? _safeDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) {
    return DateTime.tryParse(v);
  }
  return null;
}

List<dynamic> _safeList(dynamic v) {
  if (v is List<dynamic>) return v;
  return [];
}
