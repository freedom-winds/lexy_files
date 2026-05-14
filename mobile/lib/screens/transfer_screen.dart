import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/lan_service.dart';
import '../services/bluetooth_service.dart';
import '../models/transfer.dart';
import '../widgets/app_ui.dart';
import '../widgets/file_size_text.dart';

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
      backgroundColor: AppTheme.bgPage,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TransferHeader(),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusPill),
                      boxShadow: AppTheme.accentGlow(alpha: 0.30),
                    ),
                    labelColor: AppTheme.bgDeep,
                    unselectedLabelColor: AppTheme.text2,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        height: 40,
                        child: _TabLabel(
                          icon: Icons.cloud_sync_rounded,
                          label: 'Relay',
                        ),
                      ),
                      Tab(
                        height: 40,
                        child: _TabLabel(
                          icon: Icons.wifi_rounded,
                          label: 'LAN',
                        ),
                      ),
                      Tab(
                        height: 40,
                        child: _TabLabel(
                          icon: Icons.bluetooth_rounded,
                          label: 'Bluetooth',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [_RelayTab(), _LanTab(), _BluetoothTab()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferHeader extends StatelessWidget {
  const _TransferHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transfer',
          style: TextStyle(
            color: AppTheme.text1,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Send files via account relay, local network or Bluetooth.',
          style: TextStyle(color: AppTheme.text2, fontSize: 13),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
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
  int? _myDeviceDbId; // DB integer ID (for REST API)
  String? _myDeviceId; // UUID string (for WebSocket auth)

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      setState(() {
        _loading = false;
        _error = null;
        _devices = [];
      });
      return;
    }

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
      // Find our own device DB ID from the list
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
        // Show only OTHER devices (not ourselves)
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

    // Heartbeat every 30 seconds
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
    // Our outgoing transfer was accepted — data streaming starts.
    // Nothing to do here; the send loop already started after creating the transfer.
  }

  void _onTransferRejected(int transferId) {
    final pending = _pendingAccepts.remove(transferId);
    if (pending != null && !pending.isCompleted) {
      pending.completeError('Transfer was rejected by the receiver.');
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sendResult = 'Transfer was rejected by the receiver.';
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
    // Progress update from server for sends
    if (!mounted) return;
    if (_sending) {
      setState(() => _sendProgress = progress);
    }
  }

  void _onTransferComplete(int transferId) {
    if (!mounted) return;

    // If we were receiving this transfer, assemble the file
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

    // If we were sending, mark complete
    if (_sending) {
      setState(() {
        _sending = false;
        _sendProgress = 100;
        _sendResult = 'File sent successfully!';
        _sendOk = true;
      });
    }
  }

  // ── Accept/Reject incoming transfer ─────────────────────────────────

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

  // ── Send file to a device ───────────────────────────────────────────

  Future<void> _sendToDevice(Map<String, dynamic> device) async {
    if (_wsService == null || !_wsConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not connected to server. Please wait...'),
        ),
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
      // 1. Create transfer via REST
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

      // 2. Wait for the receiver to explicitly accept.
      final accepted = Completer<void>();
      _pendingAccepts[transferId] = accepted;
      await accepted.future.timeout(_acceptTimeout);
      _pendingAccepts.remove(transferId);

      // 3. Stream chunks via WebSocket without loading the whole file.
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

      // 4. Signal completion
      _wsService!.sendComplete(transferId);

      if (mounted) {
        setState(() {
          _sending = false;
          _sendProgress = 100;
          _sendResult = '"${file.name}" sent successfully!';
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
              ? 'Timed out waiting for the receiver to accept.'
              : e is String
              ? e
              : api.getApiError(e);
          _sendOk = false;
        });
      }
    }
  }

  // ── Save received file ──────────────────────────────────────────────

  Future<void> _saveFile(_CompletedDownload dl) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/${dl.fileName}';
      await File(savePath).writeAsBytes(dl.data);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to: $savePath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    for (final pending in _pendingAccepts.values) {
      if (!pending.isCompleted) {
        pending.completeError('Transfer screen closed.');
      }
    }
    _pendingAccepts.clear();
    _wsService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!auth.isAuthenticated) {
      return AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to use device transfer',
        subtitle:
            'Same-account relay needs you to be signed in so your devices can find each other.',
        action: CyanButton(
          label: 'Sign in',
          onPressed: () => Navigator.of(context).pushNamed('/login'),
        ),
      );
    }

    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load devices',
        subtitle: _error!,
        action: CyanButton(label: 'Retry', onPressed: _fetchDevices),
      );
    }

    final onlineDevices = _devices
        .where((d) => d['is_online'] == true)
        .toList();
    final offlineDevices = _devices
        .where((d) => d['is_online'] != true)
        .toList();

    return RefreshIndicator(
      onRefresh: _fetchDevices,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection status
          Card(
            color: _wsConnected ? Colors.green[50] : Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _wsConnected ? Icons.cloud_done : Icons.cloud_off,
                    size: 18,
                    color: _wsConnected ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _wsConnected
                        ? 'Connected to relay server'
                        : _myDeviceId == null && !_loading
                        ? 'Registering this device...'
                        : 'Connecting to relay server...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          // Incoming transfer request
          if (_incomingRequest != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Incoming Transfer',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_incomingRequest!.fileName} (${formatFileSize(_incomingRequest!.fileSize)})',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: _acceptIncoming,
                          child: const Text('Accept'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _rejectIncoming,
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Receiving progress
          if (_receivingTransferId != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Receiving: ${_receivingFileName ?? "file"}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _receivingFileSize > 0
                          ? _receivingBytesReceived / _receivingFileSize
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatFileSize(_receivingBytesReceived)} / ${formatFileSize(_receivingFileSize)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Completed downloads
          ..._completedDownloads.map(
            (dl) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Card(
                color: Colors.green[50],
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(dl.fileName, overflow: TextOverflow.ellipsis),
                  subtitle: Text(formatFileSize(dl.data.length)),
                  trailing: IconButton(
                    icon: const Icon(Icons.save_alt),
                    tooltip: 'Save file',
                    onPressed: () => _saveFile(dl),
                  ),
                ),
              ),
            ),
          ),

          // Sending progress
          if (_sending) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Sending to $_sendTarget...'),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: _sendProgress / 100),
                    const SizedBox(height: 4),
                    Text(
                      '${_sendProgress.toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Send result
          if (_sendResult != null) ...[
            const SizedBox(height: 8),
            Card(
              color: _sendOk ? Colors.green[50] : Colors.red[50],
              child: ListTile(
                leading: Icon(
                  _sendOk ? Icons.check_circle : Icons.error,
                  color: _sendOk ? Colors.green : Colors.red,
                ),
                title: Text(_sendResult!),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _sendResult = null),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Online devices
          if (onlineDevices.isNotEmpty) ...[
            Text(
              'Online Devices',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...onlineDevices.map(
              (device) => Card(
                child: ListTile(
                  leading: const Icon(Icons.devices, color: Colors.green),
                  title: Text(device['name'] ?? 'Unknown'),
                  subtitle: Text('${device['platform']} \u00b7 Online'),
                  trailing: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : () => _sendToDevice(device),
                    tooltip: 'Send file',
                  ),
                ),
              ),
            ),
          ],

          // Offline devices
          if (offlineDevices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Offline Devices',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...offlineDevices.map(
              (device) => Card(
                child: ListTile(
                  leading: Icon(Icons.devices, color: Colors.grey[400]),
                  title: Text(
                    device['name'] ?? 'Unknown',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  subtitle: Text('${device['platform']} \u00b7 Offline'),
                ),
              ),
            ),
          ],

          if (onlineDevices.isEmpty && offlineDevices.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.devices, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No other devices found'),
                    SizedBox(height: 4),
                    Text(
                      'Register devices on the Devices page,\nthen come back to transfer files.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
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
    // Save received file to documents directory
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$fileName';
      await File(savePath).writeAsBytes(data);
      if (!mounted) return;
      setState(() => _receivedFile = fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Received: $fileName (${formatFileSize(fileSize)}) — saved to $savePath',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _receivedFile = fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Received: $fileName but save failed: $e')),
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
            setState(() {
              _sendProgress = (sent / total) * 100;
            });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Send failed: $e')));
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('LAN Transfer'),
            const SizedBox(height: 4),
            const Text(
              'Discover devices on your local network\nand transfer files peer-to-peer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _startLan,
              icon: const Icon(Icons.search),
              label: const Text('Start Discovery'),
            ),
          ],
        ),
      );
    }

    final devices = _lanService.discoveredDevices;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_lanService.localIp != null)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Your IP: ${_lanService.localIp}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (_lanService.isReceiving)
                    const Chip(
                      label: Text('Listening'),
                      avatar: Icon(Icons.hearing, size: 16),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (_sending) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Sending to $_sendTarget...'),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _sendProgress / 100),
                  Text('${_sendProgress.toInt()}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_receivedFile != null) ...[
          Card(
            color: Colors.green[50],
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text('Received: $_receivedFile'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _receivedFile = null),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Discovered Devices (${devices.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (devices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for devices on your network...'),
                  SizedBox(height: 4),
                  Text(
                    'Make sure both devices are on the same WiFi network.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ...devices.map(
          (device) => Card(
            child: ListTile(
              leading: const Icon(Icons.computer, color: Colors.blue),
              title: Text(device.name),
              subtitle: Text('${device.platform} \u00b7 ${device.ip}'),
              trailing: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _sendToDevice(device),
                tooltip: 'Send file',
              ),
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
        SnackBar(
          content: Text(
            'Received: $fileName (${formatFileSize(fileSize)}) — saved to $savePath',
          ),
        ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
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
            setState(() {
              _sendProgress = (sent / total) * 100;
            });
          }
        },
      );

      setState(() => _sending = false);

      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent ${file.name} to ${device.name}')),
        );
      }
    } catch (e) {
      setState(() => _sending = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Send failed: $e')));
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
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Bluetooth is off'),
            SizedBox(height: 4),
            Text(
              'Please enable Bluetooth in your device settings.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Receive mode toggle
        Card(
          color: _bleService.isAdvertising ? Colors.green[50] : Colors.grey[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  _bleService.isAdvertising
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth,
                  size: 20,
                  color: _bleService.isAdvertising ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _bleService.isAdvertising
                            ? 'Receiving mode active'
                            : 'Receive files via Bluetooth',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _bleService.isAdvertising
                            ? 'Other devices can find and send files to you.'
                            : 'Start advertising so others can discover you.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _toggleAdvertising,
                  child: Text(_bleService.isAdvertising ? 'Stop' : 'Start'),
                ),
              ],
            ),
          ),
        ),
        if (_bleService.peripheralError != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _bleService.peripheralError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
        if (_receivedFile != null) ...[
          const SizedBox(height: 8),
          Card(
            color: Colors.green[50],
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text('Received: $_receivedFile'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _receivedFile = null),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_sending) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Sending to $_sendTarget via Bluetooth...'),
                  const SizedBox(height: 4),
                  const Text(
                    'BLE transfers are slow for large files.',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _sendProgress / 100),
                  Text('${_sendProgress.toInt()}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_bleService.platformLimitation != null)
          Card(
            color: Colors.amber[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _bleService.platformLimitation!,
                style: const TextStyle(color: Colors.black87, fontSize: 13),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nearby Devices',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_bleService.isScanning)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton.icon(
                  onPressed: _bleService.startScan,
                  icon: const Icon(Icons.bluetooth_searching, size: 18),
                  label: const Text('Scan'),
                ),
            ],
          ),
        const SizedBox(height: 8),
        if (_bleService.error != null)
          Card(
            color: Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _bleService.error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ),
        if (_bleService.canScanAndSend &&
            _bleService.devices.isEmpty &&
            !_bleService.isScanning)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.bluetooth, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No Bluetooth devices found'),
                  SizedBox(height: 4),
                  Text(
                    'Tap "Scan" to search for nearby devices\nrunning Lexy Files.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ..._bleService.devices.map(
          (device) => Card(
            child: ListTile(
              leading: const Icon(Icons.bluetooth, color: Colors.blue),
              title: Text(device.name),
              trailing: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _sendToDevice(device),
                tooltip: 'Send file via Bluetooth',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
