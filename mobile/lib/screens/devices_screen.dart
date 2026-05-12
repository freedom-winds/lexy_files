import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import '../services/device_presence_service.dart';

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
        title: const Text('Register Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Device name',
                hintText: 'My Phone',
              ),
              autofocus: true,
            ),
          ],
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

      // Store device ID locally
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
        title: const Text('Remove Device'),
        content: Text('Remove "$name" from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _fetchDevices,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _devices.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.devices, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No devices registered'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _registerDevice,
                    icon: const Icon(Icons.add),
                    label: const Text('Register this device'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchDevices,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _devices.length,
                itemBuilder: (ctx, i) {
                  final d = _devices[i];
                  final isOnline = d['is_online'] == true;
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        _getDeviceIcon(d['device_type'] ?? ''),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(d['name'] ?? 'Unknown'),
                      subtitle: Text(
                        '${d['platform'] ?? ''} \u00b7 ${d['device_type'] ?? ''}'
                        '${isOnline ? ' \u00b7 Online' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteDevice(
                              d['id'] as int,
                              d['name'] ?? 'Unknown',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'phone':
        return Icons.smartphone;
      case 'tablet':
        return Icons.tablet;
      case 'desktop':
      case 'laptop':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }
}
