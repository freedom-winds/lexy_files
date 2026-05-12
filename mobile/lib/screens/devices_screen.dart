import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/device_presence_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/common_cards.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    final presence = context.read<DevicePresenceService>();
    try {
      await presence.ensureStarted();
      if (!mounted) return;
      final resp = await api.getDevices();
      final data = resp.data as List;
      setState(() {
        _devices = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = api.getApiError(e);
        _loading = false;
      });
    }
  }

  Future<void> _registerDevice() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register device'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Device name',
            hintText: 'My device',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Register'),
          ),
        ],
      ),
    );

    if (result != true || nameCtrl.text.trim().isEmpty) return;
    if (!mounted) return;

    final api = context.read<ApiService>();
    try {
      final deviceId = const Uuid().v4();
      final response = await api.registerDevice(
        name: nameCtrl.text.trim(),
        deviceType: _getDeviceType(),
        platform: _getPlatform(),
        deviceId: deviceId,
      );
      final created = response.data as Map<String, dynamic>;

      final prefs = SharedPreferencesAsync();
      await prefs.setString('device_id', deviceId);
      await prefs.setInt('device_db_id', created['id'] as int);

      await _fetchDevices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(api.getApiError(e))));
    }
  }

  String _getPlatform() {
    final platform = Theme.of(context).platform;
    switch (platform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'other';
    }
  }

  String _getDeviceType() {
    final platform = Theme.of(context).platform;
    switch (platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return 'phone';
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return 'desktop';
      default:
        return 'other';
    }
  }

  Future<void> _deleteDevice(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove device'),
        content: Text('Remove "$name" from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final api = context.read<ApiService>();
    try {
      await api.deleteDevice(id);
      await _fetchDevices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(api.getApiError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = _devices.where((d) => d['is_online'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Register device',
            onPressed: _registerDevice,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load devices',
              subtitle: _error!,
              action: FilledButton(
                onPressed: _fetchDevices,
                child: const Text('Retry'),
              ),
            )
          : _devices.isEmpty
          ? AppEmptyState(
              icon: Icons.devices_rounded,
              title: 'No devices registered',
              subtitle: 'This device should appear here after sign-in.',
              action: FilledButton.icon(
                onPressed: _registerDevice,
                icon: const Icon(Icons.add),
                label: const Text('Register this device'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchDevices,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _devices.length + 1,
                separatorBuilder: (_, index) => index == 0
                    ? const SizedBox(height: 12)
                    : const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return _SummaryCard(online: online, total: _devices.length);
                  }
                  return _buildDeviceCard(_devices[i - 1]);
                },
              ),
            ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final isOnline = device['is_online'] == true;
    final platform = (device['platform'] ?? '').toString();
    final type = (device['device_type'] ?? '').toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            AppIconBadge(
              icon: _getDeviceIcon(type),
              color: isOnline ? AppTheme.success : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device['name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$platform - $type',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            StatusPill(
              label: isOnline ? 'Online' : 'Offline',
              color: isOnline ? AppTheme.success : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove',
              onPressed: () => _deleteDevice(
                device['id'] as int,
                device['name'] ?? 'Unknown',
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'phone':
        return Icons.smartphone;
      case 'tablet':
        return Icons.tablet_mac;
      case 'desktop':
      case 'laptop':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.online, required this.total});

  final int online;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Icons.sensors_rounded,
            color: Colors.white,
            background: Color(0x3327D7C7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$online online',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$total registered device${total == 1 ? '' : 's'}',
                  style: const TextStyle(color: Color(0xCCFFFFFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
