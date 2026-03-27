import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import '../models/transfer.dart';

/// Emitted when a transfer request arrives from another device.
typedef TransferRequestCallback = void Function(IncomingTransferRequest req);

/// Emitted as a chunk of file data arrives (base64-encoded string in payload).
typedef TransferDataCallback = void Function(int transferId, Uint8List chunk);

/// Emitted each time a progress update arrives.
typedef TransferProgressCallback = void Function(int transferId, double progress);

/// Emitted when the remote side accepts our transfer.
typedef TransferAcceptedCallback = void Function(int transferId);

/// Emitted when the remote side rejects our transfer.
typedef TransferRejectedCallback = void Function(int transferId);

/// Emitted when a transfer is fully complete.
typedef TransferCompleteCallback = void Function(int transferId);

class WebSocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _connected = false;
  String? _connectionError;

  bool get connected => _connected;
  String? get connectionError => _connectionError;

  // Callbacks – callers set these before calling connect().
  TransferRequestCallback? onTransferRequest;
  TransferDataCallback? onTransferData;
  TransferProgressCallback? onTransferProgress;
  TransferAcceptedCallback? onTransferAccepted;
  TransferRejectedCallback? onTransferRejected;
  TransferCompleteCallback? onTransferComplete;

  /// Connect to the Socket.IO server. Call after the user is authenticated.
  /// [deviceId] is the string UUID device_id, not the DB integer ID.
  void connect({required String token, required String deviceId}) {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
    }

    _connectionError = null;
    _socket = io.io(
      ApiConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'token': token, 'device_id': deviceId})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      _connectionError = null;
      notifyListeners();
      // Send initial heartbeat
      _socket!.emit('device_heartbeat');
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      notifyListeners();
    });

    _socket!.onConnectError((err) {
      _connected = false;
      _connectionError = err?.toString() ?? 'Connection error';
      notifyListeners();
    });

    _socket!.on('transfer.request', (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : jsonDecode(data as String) as Map<String, dynamic>;
        onTransferRequest?.call(IncomingTransferRequest.fromJson(map));
      } catch (e) {
        debugPrint('WebSocket: failed to parse transfer.request: $e');
      }
    });

    _socket!.on('transfer.accepted', (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : jsonDecode(data as String) as Map<String, dynamic>;
        final transferId = (map['id'] ?? map['transfer_id']) as int;
        onTransferAccepted?.call(transferId);
      } catch (e) {
        debugPrint('WebSocket: failed to parse transfer.accepted: $e');
      }
    });

    _socket!.on('transfer.rejected', (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : jsonDecode(data as String) as Map<String, dynamic>;
        final transferId = (map['id'] ?? map['transfer_id']) as int;
        onTransferRejected?.call(transferId);
      } catch (e) {
        debugPrint('WebSocket: failed to parse transfer.rejected: $e');
      }
    });

    _socket!.on('transfer.data', (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : jsonDecode(data as String) as Map<String, dynamic>;
        final transferId = map['transfer_id'] as int;
        final chunkB64 = map['chunk'] as String;
        final bytes = base64Decode(chunkB64);
        onTransferData?.call(transferId, bytes);
      } catch (e) {
        debugPrint('WebSocket: failed to parse transfer.data: $e');
      }
    });

    _socket!.on('transfer.progress', (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : jsonDecode(data as String) as Map<String, dynamic>;
        final transferId = (map['id'] ?? map['transfer_id']) as int;
        final progress = (map['progress_percent'] ?? map['progress'] ?? 0) as num;
        onTransferProgress?.call(transferId, progress.toDouble());
      } catch (e) {
        debugPrint('WebSocket: failed to parse transfer.progress: $e');
      }
    });

    _socket!.on('transfer.complete', (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : jsonDecode(data as String) as Map<String, dynamic>;
        final transferId = (map['id'] ?? map['transfer_id']) as int;
        onTransferComplete?.call(transferId);
      } catch (e) {
        debugPrint('WebSocket: failed to parse transfer.complete: $e');
      }
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _connected = false;
    notifyListeners();
  }

  /// Accepts an incoming transfer request.
  void acceptTransfer(int transferId) {
    _socket?.emit('transfer_accept', {'transfer_id': transferId});
  }

  /// Rejects an incoming transfer request.
  void rejectTransfer(int transferId) {
    _socket?.emit('transfer_reject', {'transfer_id': transferId});
  }

  /// Sends a file chunk (base64-encoded) to the server for relay.
  void sendChunk(int transferId, Uint8List chunk) {
    _socket?.emit('transfer_data', {
      'transfer_id': transferId,
      'chunk': base64Encode(chunk),
    });
  }

  /// Signals that all chunks have been sent.
  void sendComplete(int transferId) {
    _socket?.emit('transfer_complete', {'transfer_id': transferId});
  }

  /// Sends a heartbeat to keep the device marked online.
  void heartbeat() {
    _socket?.emit('device_heartbeat');
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
