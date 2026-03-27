enum TransferStatus {
  pending,
  accepted,
  rejected,
  inProgress,
  completed,
  failed,
}

class TransferRecord {
  final int id;
  final int senderDeviceId;
  final int? receiverDeviceId;
  final String fileName;
  final int fileSize;
  final TransferStatus status;
  final String createdAt;

  TransferRecord({
    required this.id,
    required this.senderDeviceId,
    this.receiverDeviceId,
    required this.fileName,
    required this.fileSize,
    required this.status,
    required this.createdAt,
  });

  factory TransferRecord.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    final status = _parseStatus(statusStr);
    return TransferRecord(
      id: json['id'] as int,
      senderDeviceId: json['sender_device_id'] as int,
      receiverDeviceId: json['receiver_device_id'] as int?,
      fileName: json['file_name'] as String? ?? '',
      fileSize: json['file_size'] as int? ?? 0,
      status: status,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  static TransferStatus _parseStatus(String s) {
    switch (s) {
      case 'accepted':
        return TransferStatus.accepted;
      case 'rejected':
        return TransferStatus.rejected;
      case 'in_progress':
        return TransferStatus.inProgress;
      case 'completed':
        return TransferStatus.completed;
      case 'failed':
        return TransferStatus.failed;
      default:
        return TransferStatus.pending;
    }
  }
}

/// Represents an incoming transfer request shown to the receiver.
class IncomingTransferRequest {
  final int transferId;
  final int? senderDeviceId;
  final String fileName;
  final int fileSize;

  IncomingTransferRequest({
    required this.transferId,
    this.senderDeviceId,
    required this.fileName,
    required this.fileSize,
  });

  /// Parse from the backend's transfer.to_dict() payload.
  factory IncomingTransferRequest.fromJson(Map<String, dynamic> json) {
    return IncomingTransferRequest(
      transferId: (json['id'] ?? json['transfer_id']) as int,
      senderDeviceId: json['sender_device_id'] as int?,
      fileName: json['file_name'] as String? ?? 'file',
      fileSize: json['file_size'] as int? ?? 0,
    );
  }
}
