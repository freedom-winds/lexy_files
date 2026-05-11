import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

const int _udpPort = 42424;
const int _tcpPort = 42425;
const String _announceType = 'announce';

class LanDevice {
  final String name;
  final String platform;
  final String ip;
  final int port;
  final DateTime discoveredAt;

  LanDevice({
    required this.name,
    required this.platform,
    required this.ip,
    required this.port,
    required this.discoveredAt,
  });

  String get id => '$ip:$port';

  @override
  bool operator ==(Object other) => other is LanDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Progress callback: [sent] bytes / [total] bytes.
typedef LanProgressCallback = void Function(int sent, int total);

/// Called when an incoming file transfer arrives.
/// [fileName], [fileSize], [data] — full received bytes.
typedef LanReceiveCallback = void Function(
    String fileName, int fileSize, Uint8List data);

class LanService extends ChangeNotifier {
  final NetworkInfo _networkInfo = NetworkInfo();

  String? _localIp;
  String? get localIp => _localIp;

  final List<LanDevice> _discoveredDevices = [];
  List<LanDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  bool _isDiscovering = false;
  bool get isDiscovering => _isDiscovering;

  bool _isReceiving = false;
  bool get isReceiving => _isReceiving;

  String? _error;
  String? get error => _error;

  RawDatagramSocket? _udpSocket;
  ServerSocket? _tcpServer;
  Timer? _announceTimer;
  Timer? _pruneTimer;

  String _deviceName = 'Lexy Device';
  String _devicePlatform = 'unknown';

  // Callbacks
  LanReceiveCallback? onFileReceived;

  /// Initialise: get local IP, start UDP listener, start TCP server.
  Future<void> start({
    required String deviceName,
    required String devicePlatform,
  }) async {
    _deviceName = deviceName;
    _devicePlatform = devicePlatform;
    _error = null;

    try {
      _localIp = await _networkInfo.getWifiIP();
      _localIp ??= '0.0.0.0';
    } catch (e) {
      _localIp = '0.0.0.0';
    }

    await _startUdpListener();
    await _startTcpServer();

    // Start announcing every 3 seconds
    _announceTimer?.cancel();
    _announceTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _sendAnnounce();
    });
    _sendAnnounce();

    // Prune stale devices every 10 seconds
    _pruneTimer?.cancel();
    _pruneTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pruneStaleDevices();
    });

    notifyListeners();
  }

  Future<void> _startUdpListener() async {
    try {
      _udpSocket?.close();
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _udpPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen(_onUdpData);
    } catch (e) {
      debugPrint('LAN: UDP bind failed: $e');
    }
  }

  void _onUdpData(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _udpSocket?.receive();
    if (datagram == null) return;

    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;
      if (json['type'] != _announceType) return;

      final ip = json['ip'] as String? ?? datagram.address.address;
      if (ip == _localIp) return; // Ignore self

      final device = LanDevice(
        name: json['name'] as String? ?? 'Unknown',
        platform: json['platform'] as String? ?? 'unknown',
        ip: ip,
        port: json['port'] as int? ?? _tcpPort,
        discoveredAt: DateTime.now(),
      );

      final existing = _discoveredDevices.indexWhere((d) => d.id == device.id);
      if (existing >= 0) {
        _discoveredDevices[existing] = device;
      } else {
        _discoveredDevices.add(device);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('LAN: invalid UDP packet: $e');
    }
  }

  void _sendAnnounce() {
    if (_udpSocket == null) return;
    final payload = jsonEncode({
      'type': _announceType,
      'name': _deviceName,
      'platform': _devicePlatform,
      'ip': _localIp ?? '0.0.0.0',
      'port': _tcpPort,
    });
    try {
      _udpSocket!.send(
        utf8.encode(payload),
        InternetAddress('255.255.255.255'),
        _udpPort,
      );
    } catch (e) {
      debugPrint('LAN: UDP send failed: $e');
    }
  }

  void _pruneStaleDevices() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 15));
    final before = _discoveredDevices.length;
    _discoveredDevices.removeWhere((d) => d.discoveredAt.isBefore(cutoff));
    if (_discoveredDevices.length != before) notifyListeners();
  }

  Future<void> _startTcpServer() async {
    try {
      _tcpServer?.close();
      _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, _tcpPort);
      _isReceiving = true;
      notifyListeners();
      _tcpServer!.listen(_handleIncomingConnection);
    } catch (e) {
      _error = 'Could not start LAN receiver: $e';
      debugPrint('LAN: TCP server failed: $e');
      notifyListeners();
    }
  }

  void _handleIncomingConnection(Socket socket) async {
    try {
      final completer = Completer<void>();
      final headerBuffer = BytesBuilder();
      bool headerDone = false;
      String? fileName;
      int? fileSize;
      int received = 0;
      BytesBuilder fileBuffer = BytesBuilder();

      socket.listen(
        (Uint8List data) {
          if (!headerDone) {
            // Accumulate until we find newline (header terminator)
            for (int i = 0; i < data.length; i++) {
              if (data[i] == 10) {
                // '\n'
                headerDone = true;
                final headerStr = utf8.decode(headerBuffer.toBytes());
                try {
                  final header = jsonDecode(headerStr) as Map<String, dynamic>;
                  fileName = header['file_name'] as String;
                  fileSize = header['file_size'] as int;
                } catch (e) {
                  debugPrint('LAN: bad header: $e');
                  socket.close();
                  completer.complete();
                  return;
                }
                // Remaining bytes after newline are file data
                if (i + 1 < data.length) {
                  final rest = data.sublist(i + 1);
                  fileBuffer.add(rest);
                  received += rest.length;
                }
                break;
              } else {
                headerBuffer.addByte(data[i]);
              }
            }
          } else {
            fileBuffer.add(data);
            received += data.length;
          }

          if (fileSize != null && received >= fileSize!) {
            final bytes = fileBuffer.toBytes();
            onFileReceived?.call(fileName!, fileSize!, bytes);
            socket.close();
            completer.complete();
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            // Even if we didn't get full file, notify with what we have
            if (fileName != null && fileSize != null) {
              final bytes = fileBuffer.toBytes();
              if (bytes.isNotEmpty) {
                onFileReceived?.call(fileName!, fileSize!, bytes);
              }
            }
            completer.complete();
          }
        },
        onError: (e) {
          debugPrint('LAN: incoming socket error: $e');
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (e) {
      debugPrint('LAN: handle incoming error: $e');
    }
  }

  /// Send a file to [target] device.
  Future<void> sendFile({
    required LanDevice target,
    required String fileName,
    required Uint8List fileData,
    LanProgressCallback? onProgress,
  }) async {
    final socket = await Socket.connect(
      target.ip,
      target.port,
      timeout: const Duration(seconds: 10),
    );

    try {
      // Send header
      final header =
          jsonEncode({'file_name': fileName, 'file_size': fileData.length});
      socket.add(utf8.encode('$header\n'));

      // Send file in chunks of 64KB
      const chunkSize = 65536;
      int sent = 0;
      while (sent < fileData.length) {
        final end = (sent + chunkSize).clamp(0, fileData.length);
        socket.add(fileData.sublist(sent, end));
        sent = end;
        onProgress?.call(sent, fileData.length);
        // Yield to avoid blocking UI
        await Future.delayed(Duration.zero);
      }

      await socket.flush();
    } finally {
      await socket.close();
    }
  }

  /// Send a file from disk without loading the whole object into memory.
  Future<void> sendFileFromPath({
    required LanDevice target,
    required String filePath,
    required String fileName,
    required int fileSize,
    LanProgressCallback? onProgress,
  }) async {
    final socket = await Socket.connect(
      target.ip,
      target.port,
      timeout: const Duration(seconds: 10),
    );

    try {
      final header = jsonEncode({'file_name': fileName, 'file_size': fileSize});
      socket.add(utf8.encode('$header\n'));

      var sent = 0;
      await for (final chunk in File(filePath).openRead()) {
        socket.add(chunk);
        sent += chunk.length;
        onProgress?.call(sent, fileSize);
        await Future.delayed(Duration.zero);
      }

      await socket.flush();
    } finally {
      await socket.close();
    }
  }

  /// Start/stop discovery manually (without full restart).
  void startDiscovery() {
    _isDiscovering = true;
    _discoveredDevices.clear();
    notifyListeners();
  }

  void stopDiscovery() {
    _isDiscovering = false;
    notifyListeners();
  }

  void stop() {
    _announceTimer?.cancel();
    _pruneTimer?.cancel();
    _udpSocket?.close();
    _tcpServer?.close();
    _isReceiving = false;
    _isDiscovering = false;
    _discoveredDevices.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
