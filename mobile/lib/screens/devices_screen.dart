import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/device_presence_service.dart';
import '../widgets/app_ui.dart';

/// Devices screen.
///
/// Mirrors `design/windows/devices.png`:
///   • Top bar: title + cyan "Add" CTA on the right
///   • Summary tiles row (Total / Online / Offline)
///   • Device cards: avatar + name + meta + status pill + actions
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
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      setState(() {
        _loading = false;
        _error = null;
        _devices = [];
      });
      return;
    }

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
    final l = context.l10n;
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('devices.registerDevice')),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: l.t('devices.deviceName'),
            hintText: l.t('devices.deviceNameHint'),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('devices.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('devices.register')),
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
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('devices.removeDevice')),
        content: Text(l.t('devices.removeConfirm', params: {'name': name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('devices.cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('devices.remove')),
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
    final offline = _devices.length - online;

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
                _DevicesHeader(onAdd: _registerDevice),
                const SizedBox(height: 22),
                _SummaryRow(
                  total: _devices.length,
                  online: online,
                  offline: offline,
                ),
                const SizedBox(height: 22),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final auth = context.watch<AuthProvider>();
    final l = context.l10n;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!auth.isAuthenticated) {
      return AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: l.t('devices.signInPrompt'),
        subtitle: l.t('devices.signInPromptHint'),
        action: CyanButton(
          label: l.t('auth.signIn'),
          onPressed: () => Navigator.of(context).pushNamed('/login'),
        ),
      );
    }

    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: l.t('devices.couldNotLoad'),
        subtitle: _error!,
        action: CyanButton(
          label: l.t('devices.retry'),
          onPressed: _fetchDevices,
        ),
      );
    }
    if (_devices.isEmpty) {
      return AppEmptyState(
        icon: Icons.devices_other_rounded,
        title: l.t('devices.noDevices'),
        subtitle: l.t('devices.noDevicesHint'),
        action: CyanButton(
          label: l.t('devices.registerThisDevice'),
          icon: Icons.add_rounded,
          onPressed: _registerDevice,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDevices,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _devices.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _DeviceCard(
          device: _devices[i],
          onDelete: () => _deleteDevice(
            _devices[i]['id'] as int,
            _devices[i]['name'] ?? 'Unknown',
          ),
        ),
      ),
    );
  }
}

class _DevicesHeader extends StatelessWidget {
  const _DevicesHeader({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('devices.title'),
                style: const TextStyle(
                  color: AppTheme.text1,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.t('devices.subtitle'),
                style: const TextStyle(color: AppTheme.text2, fontSize: 13),
              ),
            ],
          ),
        ),
        CyanButton(
          label: l.t('devices.registerDevice'),
          icon: Icons.add_rounded,
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.total,
    required this.online,
    required this.offline,
  });
  final int total;
  final int online;
  final int offline;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: l.t('devices.totalDevices'),
            value: '$total',
            icon: Icons.devices_rounded,
            accent: AppTheme.accentColor,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SummaryTile(
            label: l.t('devices.onlineNow'),
            value: '$online',
            icon: Icons.sensors_rounded,
            accent: AppTheme.success,
            pulse: online > 0,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SummaryTile(
            label: l.t('devices.offline'),
            value: '$offline',
            icon: Icons.cloud_off_rounded,
            accent: AppTheme.text2,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.pulse = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppTheme.text1,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    if (pulse) ...[
                      const SizedBox(width: 8),
                      const PulsingDot(color: AppTheme.success, size: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.text2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onDelete});
  final Map<String, dynamic> device;
  final VoidCallback onDelete;

  IconData _icon(String type) {
    switch (type.toLowerCase()) {
      case 'phone':
        return Icons.smartphone_rounded;
      case 'tablet':
        return Icons.tablet_mac_rounded;
      case 'desktop':
      case 'laptop':
        return Icons.computer_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = device['is_online'] == true;
    final platform = (device['platform'] ?? '').toString();
    final type = (device['device_type'] ?? '').toString();
    final lastSeen = (device['last_seen'] ?? '').toString();
    final accent = isOnline ? AppTheme.success : AppTheme.text3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: isOnline
                        ? AppTheme.successGradient
                        : AppTheme.offlineGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _icon(type),
                    color: AppTheme.bgDeep,
                    size: 26,
                  ),
                ),
                if (isOnline)
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: PulsingDot(color: AppTheme.success, size: 8),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device['name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: AppTheme.text1,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        platform.isNotEmpty
                            ? platform
                            : context.l10n.t('devices.unknownPlatform'),
                        style: const TextStyle(
                          color: AppTheme.text2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppTheme.text3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        type.isNotEmpty ? type : 'device',
                        style: const TextStyle(
                          color: AppTheme.text2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isOnline && lastSeen.isNotEmpty)
                        Text(
                          context.l10n.t(
                            'devices.lastSeen',
                            params: {'time': lastSeen},
                          ),
                          style: const TextStyle(
                            color: AppTheme.text3,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusPill(
              label: isOnline
                  ? context.l10n.t('devices.online')
                  : context.l10n.t('devices.offline'),
              color: accent,
              icon: isOnline ? Icons.circle : null,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: context.l10n.t('devices.remove'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
