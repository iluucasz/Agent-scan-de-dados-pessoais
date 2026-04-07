class ExternalScanResultsPayload {
  final String scanId;
  final String scanName;
  final DateTime timestamp;
  final ScanConfigInfo config;
  final ScanUserInfo user;
  final SystemInfo systemInfo;
  final ScanStatsInfo stats;
  final List<ScanResultItem> results;
  final String? directory;
  final Map<String, dynamic>? userInfo;

  ExternalScanResultsPayload({
    required this.scanId,
    required this.scanName,
    required this.timestamp,
    required this.config,
    required this.user,
    required this.systemInfo,
    required this.stats,
    required this.results,
    this.directory,
    this.userInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'scanId': scanId,
      'scanName': scanName,
      'timestamp': timestamp.toIso8601String(),
      'config': config.toJson(),
      'user': user.toJson(),
      // Compatibilidade com o payload do core/base.
      if (directory != null) 'directory': directory,
      if (userInfo != null) 'userInfo': userInfo,
      'systemInfo': systemInfo.toJson(),
      'stats': stats.toJson(),
      'results': results.map((r) => r.toJson()).toList(),
    };
  }
}

class ScanConfigInfo {
  final String directory;
  final int maxDepth;
  final int maxFileSize;
  final String fileTypes;
  final List<String> selectedPatterns;

  ScanConfigInfo({
    required this.directory,
    required this.maxDepth,
    required this.maxFileSize,
    required this.fileTypes,
    required this.selectedPatterns,
  });

  Map<String, dynamic> toJson() {
    return {
      'directory': directory,
      'maxDepth': maxDepth,
      'maxFileSize': maxFileSize,
      'fileTypes': fileTypes,
      'selectedPatterns': selectedPatterns,
    };
  }
}

class ScanUserInfo {
  final String name;
  final String email;
  final String? department;
  final int organizationId;

  ScanUserInfo({
    required this.name,
    required this.email,
    this.department,
    required this.organizationId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'department': department,
      'organizationId': organizationId,
    };
  }
}

class SystemInfo {
  final String os;
  final String hostname;
  final String version;

  SystemInfo({
    required this.os,
    required this.hostname,
    required this.version,
  });

  Map<String, dynamic> toJson() {
    return {
      'os': os,
      'hostname': hostname,
      'version': version,
    };
  }
}

class ScanStatsInfo {
  final int totalFiles;
  final int processedFiles;
  final int totalFindings;
  final int executionTime;
  final int errors;
  final int? uniqueDataTypes;

  ScanStatsInfo({
    required this.totalFiles,
    required this.processedFiles,
    required this.totalFindings,
    required this.executionTime,
    this.errors = 0,
    this.uniqueDataTypes,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalFiles': totalFiles,
      'processedFiles': processedFiles,
      'totalFindings': totalFindings,
      'executionTime': executionTime,
      'errors': errors,
      if (uniqueDataTypes != null) 'uniqueDataTypes': uniqueDataTypes,
    };
  }
}

class ScanResultItem {
  final String id;
  final String file;
  final String? fileName;
  final int line;
  final int column;
  final int? position;
  final String type;
  final String? displayName;
  final String? description;
  final String? category;
  final String? subcategory;
  final String? criticality;
  final String value;
  final String context;
  final String? evidence;
  final String? fileType;
  final String? parserType;
  final double confidence;
  final DateTime timestamp;
  final Map<String, dynamic>? userInfo;

  ScanResultItem({
    required this.id,
    required this.file,
    this.fileName,
    required this.line,
    required this.column,
    this.position,
    required this.type,
    this.displayName,
    this.description,
    this.category,
    this.subcategory,
    this.criticality,
    required this.value,
    required this.context,
    this.evidence,
    this.fileType,
    this.parserType,
    required this.confidence,
    required this.timestamp,
    this.userInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file': file,
      if (fileName != null) 'fileName': fileName,
      'line': line,
      'column': column,
      if (position != null) 'position': position,
      'type': type,
      // Alias para compatibilidade com o payload do core/base.
      'dataType': type,
      if (displayName != null) 'displayName': displayName,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (subcategory != null) 'subcategory': subcategory,
      if (criticality != null) 'criticality': criticality,
      'value': value,
      'context': context,
      if (evidence != null) 'evidence': evidence,
      if (fileType != null) 'fileType': fileType,
      if (parserType != null) 'parserType': parserType,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      // Alias para compatibilidade com o payload do core/base.
      'scanDate': timestamp.toIso8601String(),
      if (userInfo != null) 'userInfo': userInfo,
    };
  }
}

class ExternalScanResultsResponse {
  final bool success;
  final String message;
  final int? jobId;
  final String? scanId;

  ExternalScanResultsResponse({
    required this.success,
    required this.message,
    this.jobId,
    this.scanId,
  });

  factory ExternalScanResultsResponse.fromJson(Map<String, dynamic> json) {
    return ExternalScanResultsResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      jobId: json['jobId'] as int?,
      scanId: json['scanId'] as String?,
    );
  }
}
