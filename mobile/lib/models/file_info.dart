class FileInfo {
  final int id;
  final String originalFilename;
  final int fileSize;
  final String mimeType;
  final String pickupCode;
  final int downloadCount;
  final int? maxDownloads;
  final String expiresAt;
  final String createdAt;
  final bool isExpired;

  FileInfo({
    required this.id,
    required this.originalFilename,
    required this.fileSize,
    required this.mimeType,
    required this.pickupCode,
    required this.downloadCount,
    this.maxDownloads,
    required this.expiresAt,
    required this.createdAt,
    required this.isExpired,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      id: json['id'] as int,
      originalFilename: json['original_filename'] as String,
      fileSize: json['file_size'] as int,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      pickupCode: json['pickup_code'] as String,
      downloadCount: json['download_count'] as int? ?? 0,
      maxDownloads: json['max_downloads'] as int?,
      expiresAt: json['expires_at'] as String,
      createdAt: json['created_at'] as String,
      isExpired: json['is_expired'] as bool? ?? false,
    );
  }
}

class UploadResult {
  final int fileId;
  final String pickupCode;
  final String filename;
  final int fileSize;

  UploadResult({
    required this.fileId,
    required this.pickupCode,
    required this.filename,
    required this.fileSize,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      fileId: json['file_id'] as int? ?? json['id'] as int,
      pickupCode: json['pickup_code'] as String,
      filename: json['filename'] as String? ?? json['original_filename'] as String? ?? 'file',
      fileSize: json['file_size'] as int,
    );
  }
}
