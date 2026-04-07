/// Resposta do POST /api/data-scan-configs/:id/run
/// Backend retorna: message, job, jobId, id, scanName, filesProcessed,
/// fileNames, storageProvider, uploadStats, warnings?
class ScanRunResponse {
  final bool success;
  final String message;
  final int jobId;
  final String scanName;
  final int filesProcessed;
  final List<String> fileNames;
  final String storageProvider;
  final List<UploadedFile> uploadedFiles;
  final UploadStats stats;

  ScanRunResponse({
    required this.success,
    required this.message,
    required this.jobId,
    required this.scanName,
    this.filesProcessed = 0,
    this.fileNames = const [],
    this.storageProvider = '',
    required this.uploadedFiles,
    required this.stats,
  });

  factory ScanRunResponse.fromJson(Map<String, dynamic> json) {
    return ScanRunResponse(
      success: json['success'] as bool? ?? true,
      message: json['message']?.toString() ?? '',
      jobId: json['jobId'] as int? ?? json['id'] as int? ?? 0,
      scanName: json['scanName']?.toString() ?? '',
      filesProcessed: json['filesProcessed'] as int? ?? 0,
      fileNames: (json['fileNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      storageProvider: json['storageProvider']?.toString() ?? '',
      uploadedFiles: (json['uploadedFiles'] as List<dynamic>?)
              ?.map(
                  (file) => UploadedFile.fromJson(file as Map<String, dynamic>))
              .toList() ??
          [],
      stats: _parseUploadStats(json),
    );
  }

  /// O backend retorna 'uploadStats' no nível raiz; fallback para 'stats'.
  static UploadStats _parseUploadStats(Map<String, dynamic> json) {
    final raw = json['uploadStats'] ?? json['stats'];
    if (raw is Map<String, dynamic>) {
      return UploadStats.fromJson(raw);
    }
    return UploadStats(
        totalFiles: 0, uploadedSuccessfully: 0, totalSizeBytes: 0);
  }
}

class UploadedFile {
  final String originalName;
  final String digitalOceanUrl;
  final int size;

  UploadedFile({
    required this.originalName,
    required this.digitalOceanUrl,
    required this.size,
  });

  factory UploadedFile.fromJson(Map<String, dynamic> json) {
    return UploadedFile(
      originalName: json['originalName'] as String? ?? '',
      digitalOceanUrl: json['digitalOceanUrl'] as String? ?? '',
      size: json['size'] as int? ?? 0,
    );
  }
}

class UploadStats {
  final int totalFiles;
  final int uploadedSuccessfully;
  final int totalSizeBytes;

  UploadStats({
    required this.totalFiles,
    required this.uploadedSuccessfully,
    required this.totalSizeBytes,
  });

  factory UploadStats.fromJson(Map<String, dynamic> json) {
    return UploadStats(
      totalFiles: json['totalFiles'] as int? ??
          json['totalAttempted'] as int? ??
          0,
      uploadedSuccessfully: json['uploadedSuccessfully'] as int? ??
          json['successfulUploads'] as int? ??
          0,
      totalSizeBytes: json['totalSizeBytes'] as int? ??
          json['totalBytes'] as int? ??
          0,
    );
  }
}
