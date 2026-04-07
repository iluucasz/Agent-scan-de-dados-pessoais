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
      success: json['success'] as bool,
      message: json['message'] as String,
      jobId: json['jobId'] as int,
      scanName: json['scanName'] as String,
      uploadedFiles: (json['uploadedFiles'] as List<dynamic>)
          .map((file) => UploadedFile.fromJson(file as Map<String, dynamic>))
          .toList(),
      stats: UploadStats.fromJson(json['stats'] as Map<String, dynamic>),
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
      originalName: json['originalName'] as String,
      digitalOceanUrl: json['digitalOceanUrl'] as String,
      size: json['size'] as int,
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
      totalFiles: json['totalFiles'] as int,
      uploadedSuccessfully: json['uploadedSuccessfully'] as int,
      totalSizeBytes: json['totalSizeBytes'] as int,
    );
  }
}
