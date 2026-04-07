class ScanRunResponse {
  final bool success;
  final String message;
  final int jobId;
  final String scanName;
  final List<UploadedFile> uploadedFiles;
  final UploadStats stats;

  ScanRunResponse({
    required this.success,
    required this.message,
    required this.jobId,
    required this.scanName,
    required this.uploadedFiles,
    required this.stats,
  });

  factory ScanRunResponse.fromJson(Map<String, dynamic> json) {
    return ScanRunResponse(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String? ?? '',
      jobId: json['jobId'] as int? ?? 0,
      scanName: json['scanName'] as String? ?? '',
      uploadedFiles: (json['uploadedFiles'] as List<dynamic>?)
              ?.map(
                  (file) => UploadedFile.fromJson(file as Map<String, dynamic>))
              .toList() ??
          [],
      stats: json['stats'] != null
          ? UploadStats.fromJson(json['stats'] as Map<String, dynamic>)
          : UploadStats(
              totalFiles: 0, uploadedSuccessfully: 0, totalSizeBytes: 0),
    );
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
      totalFiles: json['totalFiles'] as int? ?? 0,
      uploadedSuccessfully: json['uploadedSuccessfully'] as int? ?? 0,
      totalSizeBytes: json['totalSizeBytes'] as int? ?? 0,
    );
  }
}
