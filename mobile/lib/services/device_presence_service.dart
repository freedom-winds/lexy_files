import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_service.dart';

const _deviceIdKey = 'device_id';
const _deviceDbIdKey = 'device_db_id';
const _presenceHeartbeatInterval = Duration(seconds: 30);

class DevicePresenceService {
  DevicePresenceService(this._api);

  final ApiService _api;
  Timer? _heartbeatTimer;
  Future<void>? _startFuture;
  int? _deviceDbId;

  int? get deviceDbId => _deviceDbId;

  Future<void> ensureStarted() {
    _startFuture ??= _start().catchError((Object error) {
      _startFuture = null;
      throw error;
    });
    return _startFuture!;
  }

  Future<void> heartbeatNow() async {
    final deviceId = _deviceDbId ?? await _loadDeviceDbId();
    if (deviceId == null) {
      await ensureStarted();
      return;
    }

    try {
      await _api.markDeviceOnline(deviceId);
    } catch (_) {
      _startFuture = null;
      await ensureStarted();
    }
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _startFuture = null;
    _deviceDbId = null;
  }

  Future<void> _start() async {
    final prefs = SharedPreferencesAsync();
    var deviceId = await prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    final resp = await _api.getDevices();
    final devices = (resp.data as List).cast<Map<String, dynamic>>();
    Map<String, dynamic>? currentDevice;
    for (final device in devices) {
      if (device['device_id'] == deviceId) {
        currentDevice = device;
        break;
      }
    }

    if (currentDevice == null) {
      final created = await _api.registerDevice(
        name: _deviceName(),
        deviceType: _deviceType(),
        platform: _platform(),
        deviceId: deviceId,
      );
      currentDevice = created.data as Map<String, dynamic>;
    }

    _deviceDbId = currentDevice['id'] as int;
    await prefs.setInt(_deviceDbIdKey, _deviceDbId!);
    await _api.markDeviceOnline(_deviceDbId!);

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_presenceHeartbeatInterval, (_) {
      unawaited(heartbeatNow());
    });
  }

  Future<int?> _loadDeviceDbId() async {
    final prefs = SharedPreferencesAsync();
    _deviceDbId = await prefs.getInt(_deviceDbIdKey);
    return _deviceDbId;
  }

  String _platform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'linux';
  }

  String _deviceType() {
    if (Platform.isAndroid || Platform.isIOS) return 'phone';
    return 'desktop';
  }

  String _deviceName() {
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    if (Platform.isWindows) return 'Windows Desktop';
    if (Platform.isMacOS) return 'macOS Desktop';
    if (Platform.isLinux) return 'Linux Desktop';
    return 'Lexy Device';
  }
}
