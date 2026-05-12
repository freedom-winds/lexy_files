import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/lan_service.dart';
import '../services/bluetooth_service.dart';
import '../models/transfer.dart';
import '../widgets/file_size_text.dart';
import '../widgets/transfer_widgets.dart';
import '../widgets/app_ui.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.cloud_sync), text: 'Relay'),
            Tab(icon: Icon(Icons.wifi), text: 'LAN'),
            Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_RelayTab(), _LanTab(), _BluetoothTab()],
      ),
    );
  }
}

// ── Same-Account Relay Tab ─────────────────────────────────────────────────

const int _chunkSize = 128 * 1024; // 128 KB per chunk
const Duration _acceptTimeout = Duration(seconds: 120);

class _RelayTab extends StatefulWidget {
  const _RelayTab();

  @override
  State<_RelayTab> createState() => _RelayTabState();
}

class _RelayTabState extends State<_RelayTab> {
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  String? _error;
  double _sendProgress = 0;
  bool _sending = false;
  String? _sendTarget;
  String? _sendResult;
  bool _sendOk = false;
  final Map<int, Completer<void>> _pendingAccepts = {};

  // WebSocket
  WebSocketService? _wsService;
  Timer? _heartbeatTimer;
  bool _wsConnected = false;

  // Incoming transfer
  IncomingTransferRequest? _incomingRequest;

  // Receiving state
  int? _receivingTransferId;
  String? _receivingFileName;
  int _receivingFileSize = 0;
  int _receivingBytesReceived = 0;
  final List<Uint8List> _receivedChunks = [];

  // Completed downloads
  final List<_CompletedDownload> _completedDownloads = [];

  // Device identity
  int? _myDeviceDbId;
  String? _myDeviceId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final api = context.read<ApiService>();
    try {
      await _loadDeviceId();
      if (!mounted) return;
      await _ensureDeviceRegistered();
      if (!mounted) return;
      await _fetchDevices();
      _connectWebSocket();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = api.getApiError(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadDeviceId() async {
    final prefs = SharedPreferencesAsync();
    _myDeviceId = await prefs.getString('device_id');
    _myDeviceDbId = await prefs.getInt('device_db_id');
  }

  String _currentPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'linux';
  }

  String _currentDeviceType() {
    if (Platform.isAndroid || Platform.isIOS) return 'phone';
    return 'desktop';
  }

  String _currentDeviceName() {
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    if (Platform.isWindows) return 'Windows Desktop';
    if (Platform.isMacOS) return 'macOS Desktop';
    if (Platform.isLinux) return 'Linux Desktop';
    return 'Lexy Device';
  }

  Future<void> _ensureDeviceRegistered() async {
    final api = context.read<ApiService>();
    final prefs = SharedPreferencesAsync();
    _myDeviceId ??= const Uuid().v4();
    await prefs.setString('device_id', _myDeviceId!);

    final resp = await api.getDevices();
    final data = (resp.data as List).cast<Map<String, dynamic>>();
    Map<String, dynamic>? existing;
    for (final d in data) {
      if (d['device_id'] == _myDeviceId) {
        existing = d;
        break;
      }
    }

    if (existing == null) {
      final created = await api.registerDevice(
        name: _currentDeviceName(),
        deviceType: _currentDeviceType(),
        platform: _currentPlatform(),
        deviceId: _myDeviceId!,
      );
      existing = created.data as Map<String, dynamic>;
    }

    _myDeviceDbId = existing['id'] as int;
    await prefs.setInt('device_db_id', _myDeviceDbId!);
    await api.markDeviceOnline(_myDeviceDbId!);
  }

  Future<void> _fetchDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    try {
      final resp = await api.getDevices();
      final data = (resp.data as List).cast<Map<String, dynamic>>();
      if (_myDeviceId != null) {
        for (final d in data) {
          if (d['device_id'] == _myDeviceId) {
            _myDeviceDbId = d['id'] as int;
            break;
          }
        }
      }
      if (_myDeviceDbId != null) {
        await api.markDeviceOnline(_myDeviceDbId!);
      }
      setState(() {
        _devices = data.where((d) => d['device_id'] != _myDeviceId).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = api.getApiError(e);
        _loading = false;
      });
    }
  }

  void _connectWebSocket() async {
    if (_myDeviceId == null) return;

    final api = context.read<ApiService>();
    final token = await api.getAccessToken();
    if (token == null) return;

    _wsService?.dispose();
    _wsService = WebSocketService();

    _wsService!.onTransferRequest = _onTransferRequest;
    _wsService!.onTransferAccepted = _onTransferAccepted;
    _wsService!.onTransferRejected = _onTransferRejected;
    _wsService!.onTransferData = _onTransferData;
    _wsService!.onTransferProgress = _onTransferProgress;
    _wsService!.onTransferComplete = _onTransferComplete;

    _wsService!.addListener(() {
      if (mounted) {
        setState(() {
          _wsConnected = _wsService?.connected ?? false;
        });
      }
    });

    _wsService!.connect(token: token, deviceId: _myDeviceId!);

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _wsService?.heartbeat();
    });
  }

  // ── WebSocket callbacks ─────────────────────────────────────────────

  void _onTransferRequest(IncomingTransferRequest req) {
    if (!mounted) return;
    setState(() => _incomingRequest = req);
  }

  void _onTransferAccepted(int transferId) {
    final pending = _pendingAccepts.remove(transferId);
    if (pending != null && !pending.isCompleted) {
      pending.complete();
      return;
    }
  }

  void _onTransferRejected(int transferId) {
    final pending = _pendingAccepts.remove(transferId);
    if (pending != null && !pending.isCompleted) {
      pending.completeError('Transfer rejected');
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sendResult = 'Transfer rejected';
      _sendOk = false;
    });
  }

  void _onTransferData(int transferId, Uint8List chunk) {
    if (!mounted) return;
    if (_receivingTransferId != transferId) return;
    setState(() {
      _receivedChunks.add(chunk);
      _receivingBytesReceived += chunk.length;
    });
  }

  void _onTransferProgress(int transferId, double progress) {
    if (!mounted) return;
    if (_sending) {
      setState(() => _sendProgress = progress);
    }
  }

  void _onTransferComplete(int transferId) {
    if (!mounted) return;

    if (_receivingTransferId == transferId && _receivingFileName != null) {
      final builder = BytesBuilder();
      for (final chunk in _receivedChunks) {
        builder.add(chunk);
      }
      final bytes = builder.toBytes();

      setState(() {
        _completedDownloads.add(
          _CompletedDownload(fileName: _receivingFileName!, data: bytes),
        );
        _receivingTransferId = null;
        _receivingFileName = null;
        _receivingFileSize = 0;
        _receivingBytesReceived = 0;
        _receivedChunks.clear();
      });
    }

    if (_sending) {
      setState(() {
        _sending = false;
        _sendProgress = 100;
        _sendResult = 'File sent successfully';
        _sendOk = true;
      });
    }
  }

  void _acceptIncoming() {
    final req = _incomingRequest;
    if (req == null || _wsService == null) return;

    _wsService!.acceptTransfer(req.transferId);
    setState(() {
      _receivingTransferId = req.transferId;
      _receivingFileName = req.fileName;
      _receivingFileSize = req.fileSize;
      _receivingBytesReceived = 0;
      _receivedChunks.clear();
      _incomingRequest = null;
    });
  }

  void _rejectIncoming() {
    final req = _incomingRequest;
    if (req == null || _wsService == null) return;
    _wsService!.rejectTransfer(req.transferId);
    setState(() => _incomingRequest = null);
  }

  Future<void> _sendToDevice(Map<String, dynamic> device) async {
    if (_wsService == null || !_wsConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to server')),
      );
      return;
    }

    final api = context.read<ApiService>();
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _sending = true;
      _sendProgress = 0;
      _sendTarget = device['name'] as String;
      _sendResult = null;
    });

    int? activeTransferId;
    try {
      final resp = await api.createTransfer(
        senderDeviceId: _myDeviceDbId ?? 0,
        targetDeviceId: device['id'] as int,
        fileName: file.name,
        fileSize: file.size,
        mode: 'same_account',
      );
      final transferData = resp.data as Map<String, dynamic>;
      final transferId = transferData['id'] as int;
      activeTransferId = transferId;

      final accepted = Completer<void>();
      _pendingAccepts[transferId] = accepted;
      await accepted.future.timeout(_acceptTimeout);
      _pendingAccepts.remove(transferId);

      var sent = 0;
      await for (final chunk in File(file.path!).openRead(0, file.size)) {
        var offset = 0;
        while (offset < chunk.length) {
          final end = (offset + _chunkSize).clamp(0, chunk.length);
          final bytes = Uint8List.fromList(chunk.sublist(offset, end));
          offset = end;
          sent += bytes.length;

          _wsService!.sendChunk(transferId, bytes);

          final pct = file.size > 0
              ? (sent / file.size * 100).clamp(0, 100).toDouble()
              : 100.0;
          if (mounted) {
            setState(() => _sendProgress = pct);
          }

          await Future.delayed(Duration.zero);
        }
      }

      _wsService!.sendComplete(transferId);

      if (mounted) {
        setState(() {
          _sending = false;
          _sendProgress = 100;
          _sendResult = 'Sent successfully';
          _sendOk = true;
        });
      }
    } catch (e) {
      if (activeTransferId != null) {
        _pendingAccepts.remove(activeTransferId);
      }
      if (mounted) {
        setState(() {
          _sending = false;
          _sendResult = e is TimeoutException
              ? 'Timed out waiting for accept'
              : e is String
              ? e
              : context.read<ApiService>().getApiError(e);
          _sendOk = false;
        });
      }
    }
  }

  Future<void> _saveFile(_CompletedDownload dl) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/${dl.fileName}';
      await File(savePath).writeAsBytes(dl.data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to: $savePath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    for (final pending in _pendingAccepts.values) {
      if (!pending.isCompleted) {
        pending.completeError('Screen closed');
      }
    }
    _pendingAccepts.clear();
    _wsService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Connection Error',
        subtitle: _error!,
        action: FilledButton(onPressed: _fetchDevices, child: const Text('Retry')),
      );
    }

    final onlineDevices = _devices.where((d) => d['is_online'] == true).toList();
    final offlineDevices = _devices.where((d) => d['is_online'] != true).toList();

    return RefreshIndicator(
      onRefresh: _fetchDevices,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection status
          ConnectionStatusPanel(
            isConnected: _wsConnected,
            connectedMessage: 'Connected to relay server',
            disconnectedMessage: _myDeviceId == null && !_loading
                ? 'Registering device...'
                : 'Connecting to relay server...',
          ),

          // Incoming transfer request
          if (_incomingRequest != null) ...[
            const SizedBox(height: 12),
            StatusBanner(
              message: 'Incoming: ${_incomingRequest!.fileName} (${formatFileSize(_incomingRequest!.fileSize)})',
              type: StatusBannerType.info,
              icon: Icons.download,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _acceptIncoming,
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _rejectIncoming,
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],

          // Receiving progress
          if (_receivingTransferId != null) ...[
            const SizedBox(height: 12),
            TransferProgressPanel(
              fileName: _receivingFileName ?? 'file',
              progress: _receivingFileSize > 0
                  ? (_receivingBytesReceived / _receivingFileSize * 100)
                  : 0,
              bytesTransferred: _receivingBytesReceived,
              totalBytes: _receivingFileSize,
              isSending: false,
            ),
          ],

          // Completed downloads
          ..._completedDownloads.map(
            (dl) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: StatusBanner(
                message: '${dl.fileName} (${formatFileSize(dl.data.length)})',
                type: StatusBannerType.success,
                onDismiss: () => setState(() => _completedDownloads.remove(dl)),
              ),
            ),
          ),

          // Sending progress
          if (_sending) ...[
            const SizedBox(height: 12),
            TransferProgressPanel(
              fileName: 'Sending...',
              progress: _sendProgress,
              targetName: _sendTarget,
              isSending: true,
            ),
          ],

          // Send result
          if (_sendResult != null) ...[
            const SizedBox(height: 8),
            StatusBanner(
              message: _sendResult!,
              type: _sendOk ? StatusBannerType.success : StatusBannerType.error,
              onDismiss: () => setState(() => _sendResult = null),
            ),
          ],

          const SizedBox(height: 16),

          // Online devices
          if (onlineDevices.isNotEmpty) ...[
            const SectionHeader(title: 'Online Devices'),
            ...onlineDevices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DeviceTargetCard(
                  name: device['name'] ?? 'Unknown',
                  subtitle: '${device['platform']} • Online',
                  onSend: _sending ? null : () => _sendToDevice(device),
                  isOnline: true,
                ),
              ),
            ),
          ],

          // Offline devices
          if (offlineDevices.isNotEmpty) ...[
            const SizedBox(height: 8),
            const SectionHeader(title: 'Offline Devices'),
            ...offlineDevices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DeviceTargetCard(
                  name: device['name'] ?? 'Unknown',
                  subtitle: '${device['platform']} • Offline',
                  onSend: null,
                  isOnline: false,
                ),
              ),
            ),
          ],

          if (onlineDevices.isEmpty && offlineDevices.isEmpty)
            AppEmptyState(
              icon: Icons.devices,
              title: 'No devices found',
              subtitle: 'Register devices on the Devices page',
            ),
        ],
      ),
    );
  }
}

class _CompletedDownload {
  final String fileName;
  final Uint8List data;

  _CompletedDownload({required this.fileName, required this.data});
}

// ── LAN Transfer Tab ───────────────────────────────────────────────────────

class _LanTab extends StatefulWidget {
  const _LanTab();

  @override
  State<_LanTab> createState() => _LanTabState();
}

class _LanTabState extends State<_LanTab> {
  late LanService _lanService;
  bool _started = false;
  double _sendProgress = 0;
  bool _sending = false;
  String? _sendTarget;
  String? _receivedFile;

  @override
  void initState() {
    super.initState();
    _lanService = LanService();
    _lanService.addListener(_onLanUpdate);
    _lanService.onFileReceived = _onFileReceived;
  }

  void _onLanUpdate() {
    if (mounted) setState(() {});
  }

  void _onFileReceived(String fileName, int fileSize, Uint8List data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$fileName';
      await File(savePath).writeAsBytes(data);
      if (!mounted) return;
      setState(() => _receivedFile = fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Received: $fileName — saved to $savePath')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _receivedFile = fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Received $fileName but save failed: $e')),
      );
    }
  }

  Future<void> _startLan() async {
    await _lanService.start(
      deviceName: 'Lexy Device',
      devicePlatform: Platform.operatingSystem,
    );
    setState(() => _started = true);
  }

  Future<void> _sendToDevice(LanDevice device) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _sending = true;
      _sendProgress = 0;
      _sendTarget = device.name;
    });

    try {
      await _lanService.sendFileFromPath(
        target: device,
        filePath: file.path!,
        fileName: file.name,
        fileSize: file.size,
        onProgress: (sent, total) {
          if (mounted) {
            setState(() => _sendProgress = (sent / total) * 100);
          }
        },
      );

      setState(() {
        _sending = false;
        _sendProgress = 100;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent ${file.name} to ${device.name}')),
      );
    } catch (e) {
      setState(() => _sending = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _lanService.removeListener(_onLanUpdate);
    _lanService.stop();
    _lanService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return AppEmptyState(
        icon: Icons.wifi,
        title: 'LAN Transfer',
        subtitle: 'Discover devices on your local network',
        action: FilledButton.icon(
          onPressed: _startLan,
          icon: const Icon(Icons.search),
          label: const Text('Start Discovery'),
        ),
      );
    }

    final devices = _lanService.discoveredDevices;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_lanService.localIp != null)
          StatusBanner(
            message: 'Your IP: ${_lanService.localIp}${_lanService.isReceiving ? ' • Listening' : ''}',
            type: StatusBannerType.info,
          ),
        
        if (_sending) ...[
          const SizedBox(height: 12),
          TransferProgressPanel(
            fileName: 'Sending...',
            progress: _sendProgress,
            targetName: _sendTarget,
            isSending: true,
          ),
        ],
        
        if (_receivedFile != null) ...[
          const SizedBox(height: 8),
          StatusBanner(
            message: 'Received: $_receivedFile',
            type: StatusBannerType.success,
            onDismiss: () => setState(() => _receivedFile = null),
          ),
        ],
        
        const SizedBox(height: 16),
        SectionHeader(title: 'Discovered Devices (${devices.length})'),
        
        if (devices.isEmpty)
          AppEmptyState(
            icon: Icons.wifi_find,
            title: 'Scanning for devices',
            subtitle: 'Make sure both devices are on the same WiFi network',
          )
        else
          ...devices.map(
            (device) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DeviceTargetCard(
                name: device.name,
                subtitle: '${device.platform} • ${device.ip}',
                onSend: () => _sendToDevice(device),
                icon: Icons.computer,
                iconColor: Colors.blue,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Bluetooth Transfer Tab ─────────────────────────────────────────────────

class _BluetoothTab extends StatefulWidget {
  const _BluetoothTab();

  @override
  State<_BluetoothTab> createState() => _BluetoothTabState();
}

class _BluetoothTabState extends State<_BluetoothTab> {
  late BluetoothTransferService _bleService;
  double _sendProgress = 0;
  bool _sending = false;
  String? _sendTarget;
  String? _receivedFile;

  @override
  void initState() {
    super.initState();
    _bleService = BluetoothTransferService();
    _bleService.addListener(_onBleUpdate);
    _bleService.onFileReceived = _onFileReceived;
  }

  void _onBleUpdate() {
    if (mounted) setState(() {});
  }

  void _onFileReceived(String fileName, int fileSize, String filePath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$fileName';
      final source = File(filePath);
      await source.copy(savePath);
      await source.delete().catchError((_) => source);
      if (!mounted) return;
      setState(() => _receivedFile = fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Received: $fileName — saved to $savePath')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _receivedFile = fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Received $fileName but save failed: $e')),
      );
    }
  }

  Future<void> _toggleAdvertising() async {
    if (_bleService.isAdvertising) {
      await _bleService.stopAdvertising();
    } else {
      final err = await _bleService.startAdvertising();
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
    }
  }

  Future<void> _sendToDevice(BleDiscoveredDevice device) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _sending = true;
      _sendProgress = 0;
      _sendTarget = device.name;
    });

    try {
      final error = await _bleService.sendFileFromPath(
        device: device.device,
        filePath: file.path!,
        fileName: file.name,
        fileSize: file.size,
        onProgress: (sent, total) {
          if (mounted) {
            setState(() => _sendProgress = (sent / total) * 100);
          }
        },
      );

      setState(() => _sending = false);

      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent ${file.name} to ${device.name}')),
        );
      }
    } catch (e) {
      setState(() => _sending = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _bleService.removeListener(_onBleUpdate);
    _bleService.onFileReceived = null;
    _bleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bleService.isAdapterStateLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking Bluetooth status...'),
          ],
        ),
      );
    }

    if (!_bleService.isAdapterOn) {
      return const AppEmptyState(
        icon: Icons.bluetooth_disabled,
        title: 'Bluetooth is off',
        subtitle: 'Please enable Bluetooth in your device settings',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Receive mode toggle
        ConnectionStatusPanel(
          isConnected: _bleService.isAdvertising,
          connectedMessage: 'Receiving mode active',
          disconnectedMessage: 'Start receiving to accept files',
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _toggleAdvertising,
          icon: Icon(_bleService.isAdvertising ? Icons.stop : Icons.bluetooth),
          label: Text(_bleService.isAdvertising ? 'Stop Receiving' : 'Start Receiving'),
        ),
        
        if (_bleService.peripheralError != null) ...[
          const SizedBox(height: 8),
          StatusBanner(
            message: _bleService.peripheralError!,
            type: StatusBannerType.error,
          ),
        ],
        
        if (_receivedFile != null) ...[
          const SizedBox(height: 8),
          StatusBanner(
            message: 'Received: $_receivedFile',
            type: StatusBannerType.success,
            onDismiss: () => setState(() => _receivedFile = null),
          ),
        ],
        
        if (_sending) ...[
          const SizedBox(height: 12),
          TransferProgressPanel(
            fileName: 'Sending via Bluetooth...',
            progress: _sendProgress,
            targetName: _sendTarget,
            isSending: true,
          ),
          const SizedBox(height: 4),
          const StatusBanner(
            message: 'BLE transfers are slow for large files',
            type: StatusBannerType.warning,
          ),
        ],
        
        const SizedBox(height: 16),
        
        if (_bleService.platformLimitation != null)
          StatusBanner(
            message: _bleService.platformLimitation!,
            type: StatusBannerType.warning,
          )
        else
          SectionHeader(
            title: 'Nearby Devices',
            action: _bleService.isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton.icon(
                    onPressed: _bleService.startScan,
                    icon: const Icon(Icons.bluetooth_searching, size: 18),
                    label: const Text('Scan'),
                  ),
          ),
        
        const SizedBox(height: 8),
        
        if (_bleService.error != null)
          StatusBanner(
            message: _bleService.error!,
            type: StatusBannerType.error,
          ),
        
        if (_bleService.canScanAndSend &&
            _bleService.devices.isEmpty &&
            !_bleService.isScanning)
          AppEmptyState(
            icon: Icons.bluetooth,
            title: 'No Bluetooth devices found',
            subtitle: 'Tap "Scan" to search for nearby devices',
          )
        else
          ..._bleService.devices.map(
            (device) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DeviceTargetCard(
                name: device.name,
                subtitle: 'Bluetooth device',
                onSend: () => _sendToDevice(device),
                icon: Icons.bluetooth,
                iconColor: Colors.blue,
              ),
            ),
          ),
      ],
    );
  }
}
