import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:ble_peripheral/ble_peripheral.dart' as ble_p;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Custom Lexy Files BLE service UUID (Nordic UART Service compatible).
const String lexyServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

/// RX characteristic (central writes to this to send data to us when we are peripheral).
const String lexyRxCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

/// TX characteristic (peripheral writes here; central subscribes for notifications).
const String lexyTxCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

const int _fallbackBlePayloadSize = 20;
const int _maxBlePayloadSize = 512;
const Duration _bleWriteDelay = Duration(milliseconds: 20);
const MethodChannel _windowsBluetoothChannel = MethodChannel(
  'lexy_files/windows_bluetooth',
);

// ---------------------------------------------------------------------------
// Peripheral protocol state machine
// ---------------------------------------------------------------------------

enum _RxState { waitingHeader, receivingData, done }

/// Streams incoming BLE writes to disk and parses the Lexy file transfer protocol.
///
/// Protocol:
///   1. Central writes JSON header terminated by 0x00:
///      {"file_name":"foo.txt","file_size":1234}\x00
///   2. Central writes raw file data in packet-sized chunks.
///   3. Central may write EOT: {"type":"eot"} for compatibility.
// ignore: unused_element
class _PeripheralReceiver {
  _RxState _state = _RxState.waitingHeader;

  String? _fileName;
  int _fileSize = 0;
  final BytesBuilder _dataBuffer = BytesBuilder(copy: false);

  // Trailing bytes that have not yet formed a complete header (edge case: header
  // arrives split across two writes, which is unusual but theoretically possible).
  final List<int> _headerAccum = [];

  /// Feed a raw write from the central into the state machine.
  /// Returns a completed [_ReceivedFile] when the EOT has been processed,
  /// or null if more data is expected.
  _ReceivedFile? feed(Uint8List bytes) {
    switch (_state) {
      case _RxState.waitingHeader:
        return _processHeader(bytes);
      case _RxState.receivingData:
        return _processData(bytes);
      case _RxState.done:
        // Ignore any trailing writes after completion.
        return null;
    }
  }

  _ReceivedFile? _processHeader(Uint8List bytes) {
    // Accumulate until we see the null terminator.
    _headerAccum.addAll(bytes);

    final nullIdx = _headerAccum.indexOf(0x00);
    if (nullIdx < 0) {
      // Header not complete yet.
      return null;
    }

    final jsonBytes = Uint8List.fromList(_headerAccum.sublist(0, nullIdx));
    final remainder = _headerAccum.sublist(nullIdx + 1);
    _headerAccum.clear();

    try {
      final Map<String, dynamic> meta = jsonDecode(utf8.decode(jsonBytes));
      _fileName = meta['file_name'] as String? ?? 'received_file';
      _fileSize = (meta['file_size'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('BLE peripheral: malformed header: $e');
      // Reset — we cannot continue without a valid header.
      _reset();
      return null;
    }

    _state = _RxState.receivingData;

    // There may be data bytes immediately after the null terminator in the same
    // write; process them now.
    if (remainder.isNotEmpty) {
      return _processData(Uint8List.fromList(remainder));
    }
    return null;
  }

  _ReceivedFile? _processData(Uint8List bytes) {
    // Check if this write is the EOT signal.
    if (_isEot(bytes)) {
      _state = _RxState.done;
      final assembled = _dataBuffer.takeBytes();
      final result = _ReceivedFile(
        fileName: _fileName ?? 'received_file',
        fileSize: _fileSize,
        data: assembled,
      );
      _reset();
      return result;
    }

    _dataBuffer.add(bytes);
    return null;
  }

  bool _isEot(Uint8List bytes) {
    // Fast path: check if the write looks like the EOT JSON.
    if (bytes.length > 64) return false; // File data chunks are larger.
    try {
      final text = utf8.decode(bytes, allowMalformed: true);
      final Map<String, dynamic> obj = jsonDecode(text);
      return obj['type'] == 'eot';
    } catch (_) {
      return false;
    }
  }

  void _reset() {
    _state = _RxState.waitingHeader;
    _fileName = null;
    _fileSize = 0;
    _dataBuffer.clear();
    _headerAccum.clear();
  }
}

class _StreamingPeripheralReceiver {
  _RxState _state = _RxState.waitingHeader;

  String? _fileName;
  int _fileSize = 0;
  int _receivedBytes = 0;
  RandomAccessFile? _output;
  String? _outputPath;
  final List<int> _headerAccum = [];

  _StreamingReceivedFile? feed(Uint8List bytes) {
    switch (_state) {
      case _RxState.waitingHeader:
        return _processHeader(bytes);
      case _RxState.receivingData:
        return _processData(bytes);
      case _RxState.done:
        return null;
    }
  }

  _StreamingReceivedFile? _processHeader(Uint8List bytes) {
    if (_isEot(bytes)) return null;

    _headerAccum.addAll(bytes);
    final nullIdx = _headerAccum.indexOf(0x00);
    if (nullIdx < 0) return null;

    final jsonBytes = Uint8List.fromList(_headerAccum.sublist(0, nullIdx));
    final remainder = _headerAccum.sublist(nullIdx + 1);
    _headerAccum.clear();

    try {
      final Map<String, dynamic> meta = jsonDecode(utf8.decode(jsonBytes));
      _fileName = meta['file_name'] as String? ?? 'received_file';
      _fileSize = (meta['file_size'] as num?)?.toInt() ?? 0;
      _receivedBytes = 0;
      _openOutputFile();
    } catch (e) {
      debugPrint('BLE peripheral: malformed header: $e');
      _reset();
      return null;
    }

    _state = _RxState.receivingData;
    if (_fileSize == 0) return _completeFile();

    if (remainder.isNotEmpty) {
      return _processData(Uint8List.fromList(remainder));
    }
    return null;
  }

  _StreamingReceivedFile? _processData(Uint8List bytes) {
    if (_isEot(bytes)) {
      return _receivedBytes >= _fileSize ? _completeFile() : null;
    }

    final remaining = _fileSize - _receivedBytes;
    if (remaining <= 0) return _completeFile();

    final writeLength = min(bytes.length, remaining);
    _output?.writeFromSync(bytes, 0, writeLength);
    _receivedBytes += writeLength;

    if (_receivedBytes >= _fileSize) return _completeFile();
    return null;
  }

  bool _isEot(Uint8List bytes) {
    if (bytes.length > 64) return false;
    try {
      final text = utf8.decode(bytes, allowMalformed: true);
      final Map<String, dynamic> obj = jsonDecode(text);
      return obj['type'] == 'eot';
    } catch (_) {
      return false;
    }
  }

  void _openOutputFile() {
    final tempDir = Directory.systemTemp.createTempSync('lexy_ble_');
    final safeName = _safeFileName(_fileName ?? 'received_file');
    final file = File('${tempDir.path}${Platform.pathSeparator}$safeName');
    _outputPath = file.path;
    _output = file.openSync(mode: FileMode.writeOnly);
  }

  _StreamingReceivedFile _completeFile() {
    _state = _RxState.done;
    _output?.flushSync();
    _output?.closeSync();
    _output = null;

    final result = _StreamingReceivedFile(
      fileName: _fileName ?? 'received_file',
      fileSize: _fileSize,
      filePath: _outputPath!,
    );
    _reset(keepCompletedFile: true);
    return result;
  }

  void _reset({bool keepCompletedFile = false}) {
    _output?.closeSync();
    if (!keepCompletedFile && _outputPath != null) {
      try {
        File(_outputPath!).deleteSync();
      } catch (_) {}
    }
    _state = _RxState.waitingHeader;
    _fileName = null;
    _fileSize = 0;
    _receivedBytes = 0;
    _output = null;
    _outputPath = null;
    _headerAccum.clear();
  }

  String _safeFileName(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return sanitized.isEmpty ? 'received_file' : sanitized;
  }
}

class _StreamingReceivedFile {
  final String fileName;
  final int fileSize;
  final String filePath;

  _StreamingReceivedFile({
    required this.fileName,
    required this.fileSize,
    required this.filePath,
  });
}

class _ReceivedFile {
  final String fileName;
  final int fileSize;
  final Uint8List data;

  _ReceivedFile({
    required this.fileName,
    required this.fileSize,
    required this.data,
  });
}

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

class BleDiscoveredDevice {
  final BluetoothDevice device;
  final String name;
  final DateTime discoveredAt;

  BleDiscoveredDevice({
    required this.device,
    required this.name,
    required this.discoveredAt,
  });
}

typedef BleProgressCallback = void Function(int sent, int total);
typedef BleReceiveCallback =
    void Function(String fileName, int fileSize, String filePath);

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class BluetoothTransferService extends ChangeNotifier {
  // ── Central (scan + send) state ────────────────────────────────────────────

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isAdapterOn = false;
  bool get isAdapterOn => _isAdapterOn;

  bool _isAdapterStateLoading = true;
  bool get isAdapterStateLoading => _isAdapterStateLoading;

  bool get canScanAndSend =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux;

  String? get platformLimitation {
    if (Platform.isWindows) {
      return 'Windows Bluetooth sending needs a native BLE central implementation; use LAN for desktop sending.';
    }
    return null;
  }

  String? _error;
  String? get error => _error;

  final List<BleDiscoveredDevice> _devices = [];
  List<BleDiscoveredDevice> get devices => List.unmodifiable(_devices);

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  Timer? _adapterPollTimer;

  // ── Peripheral (GATT server) state ─────────────────────────────────────────

  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  String? _peripheralError;
  String? get peripheralError => _peripheralError;

  final _StreamingPeripheralReceiver _receiver = _StreamingPeripheralReceiver();

  // ── Callbacks ──────────────────────────────────────────────────────────────

  /// Called when a complete file has been received via GATT server mode.
  BleReceiveCallback? onFileReceived;

  // ── Constructor ────────────────────────────────────────────────────────────

  BluetoothTransferService() {
    if (Platform.isWindows) {
      unawaited(refreshAdapterState());
      _adapterPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        unawaited(refreshAdapterState());
      });
    } else {
      _adapterSub = FlutterBluePlus.adapterState.listen((state) {
        _setAdapterState(state == BluetoothAdapterState.on);
      });
    }
  }

  // ── Central: scan ──────────────────────────────────────────────────────────

  Future<void> refreshAdapterState() async {
    if (!Platform.isWindows) return;

    try {
      final state = await _windowsBluetoothChannel
          .invokeMapMethod<String, dynamic>('getBluetoothState');
      _setAdapterState(
        state?['available'] == true && state?['poweredOn'] != false,
      );
    } catch (e) {
      _isAdapterStateLoading = false;
      _error = 'Unable to read Windows Bluetooth status: $e';
      notifyListeners();
    }
  }

  void _setAdapterState(bool isOn) {
    _isAdapterOn = isOn;
    _isAdapterStateLoading = false;
    if (!_isAdapterOn) {
      _isScanning = false;
      _devices.clear();
      if (_isAdvertising) {
        _isAdvertising = false;
      }
    }
    notifyListeners();
  }

  /// Start scanning for BLE devices advertising the Lexy service UUID.
  Future<void> startScan() async {
    await refreshAdapterState();

    if (!_isAdapterOn) {
      _error = 'Bluetooth is turned off. Please enable Bluetooth.';
      notifyListeners();
      return;
    }

    if (!canScanAndSend) {
      _error = platformLimitation;
      notifyListeners();
      return;
    }

    if (!await _ensureBluetoothPermissions()) {
      _error = 'Bluetooth permission is required to scan nearby devices.';
      notifyListeners();
      return;
    }

    _error = null;
    _devices.clear();
    _isScanning = true;
    notifyListeners();

    try {
      await FlutterBluePlus.stopScan();
      _scanSub?.cancel();

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        bool changed = false;
        for (final result in results) {
          final name = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.advertisementData.advName.isNotEmpty
              ? result.advertisementData.advName
              : 'Unknown (${result.device.remoteId})';

          final existing = _devices.indexWhere(
            (d) => d.device.remoteId == result.device.remoteId,
          );
          if (existing >= 0) {
            _devices[existing] = BleDiscoveredDevice(
              device: result.device,
              name: name,
              discoveredAt: DateTime.now(),
            );
          } else {
            _devices.add(
              BleDiscoveredDevice(
                device: result.device,
                name: name,
                discoveredAt: DateTime.now(),
              ),
            );
            changed = true;
          }
        }
        if (changed) notifyListeners();
      });

      await FlutterBluePlus.startScan(
        withServices: [Guid(lexyServiceUuid)],
        timeout: const Duration(seconds: 30),
      );

      await FlutterBluePlus.isScanning.where((s) => !s).first;
    } catch (e) {
      _error = 'Scan error: $e';
      debugPrint('BLE: scan error: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop scanning.
  Future<void> stopScan() async {
    if (canScanAndSend) {
      await FlutterBluePlus.stopScan();
    }
    _isScanning = false;
    notifyListeners();
  }

  // ── Central: send ──────────────────────────────────────────────────────────

  Future<bool> _ensureBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
  }

  int _payloadSizeFor(BluetoothDevice device) {
    final mtuPayload = device.mtuNow - 3;
    if (mtuPayload <= 0) return _fallbackBlePayloadSize;
    return mtuPayload
        .clamp(_fallbackBlePayloadSize, _maxBlePayloadSize)
        .toInt();
  }

  Future<void> _writePacketized(
    BluetoothCharacteristic characteristic,
    List<int> bytes,
    int payloadSize,
  ) async {
    var offset = 0;
    while (offset < bytes.length) {
      final end = min(offset + payloadSize, bytes.length);
      await characteristic.write(
        bytes.sublist(offset, end),
        withoutResponse: false,
      );
      offset = end;
      await Future.delayed(_bleWriteDelay);
    }
  }

  /// Send a file to a BLE device.
  /// Returns null on success, or an error string.
  Future<String?> sendFile({
    required BluetoothDevice device,
    required String fileName,
    required Uint8List fileData,
    BleProgressCallback? onProgress,
  }) async {
    if (!canScanAndSend) return platformLimitation;
    if (!await _ensureBluetoothPermissions()) {
      return 'Bluetooth permission is required to send files.';
    }

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      final payloadSize = _payloadSizeFor(device);
      final services = await device.discoverServices();

      BluetoothCharacteristic? rxChar;
      for (final service in services) {
        if (service.uuid == Guid(lexyServiceUuid)) {
          for (final c in service.characteristics) {
            if (c.uuid == Guid(lexyRxCharUuid)) {
              rxChar = c;
              break;
            }
          }
          break;
        }
      }

      if (rxChar == null) {
        await device.disconnect();
        return 'Device does not expose the Lexy Files RX characteristic.';
      }

      // Send metadata header as JSON followed by a null byte as delimiter.
      final header = jsonEncode({
        'file_name': fileName,
        'file_size': fileData.length,
      });
      final headerBytes = Uint8List.fromList([
        ...utf8.encode(header),
        0x00,
      ]); // null terminator
      await _writePacketized(rxChar, headerBytes, payloadSize);

      // Send file in BLE-sized chunks.
      int sent = 0;
      while (sent < fileData.length) {
        final end = min(sent + payloadSize, fileData.length);
        final chunk = fileData.sublist(sent, end);
        await rxChar.write(chunk, withoutResponse: false);
        sent = end;
        onProgress?.call(sent, fileData.length);
        await Future.delayed(_bleWriteDelay);
      }

      // Send end-of-transfer signal.
      final eot = utf8.encode('{"type":"eot"}');
      await _writePacketized(rxChar, eot, payloadSize);

      await device.disconnect();
      return null;
    } catch (e) {
      try {
        await device.disconnect();
      } catch (_) {}
      return 'Transfer failed: $e';
    }
  }

  /// Send a file from disk without loading the whole object into memory.
  Future<String?> sendFileFromPath({
    required BluetoothDevice device,
    required String filePath,
    required String fileName,
    required int fileSize,
    BleProgressCallback? onProgress,
  }) async {
    if (!canScanAndSend) return platformLimitation;
    if (!await _ensureBluetoothPermissions()) {
      return 'Bluetooth permission is required to send files.';
    }

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      final payloadSize = _payloadSizeFor(device);
      final services = await device.discoverServices();

      BluetoothCharacteristic? rxChar;
      for (final service in services) {
        if (service.uuid == Guid(lexyServiceUuid)) {
          for (final c in service.characteristics) {
            if (c.uuid == Guid(lexyRxCharUuid)) {
              rxChar = c;
              break;
            }
          }
          break;
        }
      }

      if (rxChar == null) {
        await device.disconnect();
        return 'Device does not expose the Lexy Files RX characteristic.';
      }

      final header = jsonEncode({'file_name': fileName, 'file_size': fileSize});
      final headerBytes = Uint8List.fromList([...utf8.encode(header), 0x00]);
      await _writePacketized(rxChar, headerBytes, payloadSize);

      var sent = 0;
      await for (final chunk in File(filePath).openRead()) {
        var offset = 0;
        while (offset < chunk.length) {
          final end = min(offset + payloadSize, chunk.length);
          final packet = Uint8List.fromList(chunk.sublist(offset, end));
          await rxChar.write(packet, withoutResponse: false);
          sent += packet.length;
          offset = end;
          onProgress?.call(sent, fileSize);
          await Future.delayed(_bleWriteDelay);
        }
      }

      final eot = utf8.encode('{"type":"eot"}');
      await _writePacketized(rxChar, eot, payloadSize);

      await device.disconnect();
      return null;
    } catch (e) {
      try {
        await device.disconnect();
      } catch (_) {}
      return 'Transfer failed: $e';
    }
  }

  // ── Peripheral: GATT server ────────────────────────────────────────────────

  /// Start the GATT server and advertise the Lexy service so that other
  /// devices (central role) can connect and write files to us.
  ///
  /// Returns null on success, or an error string on failure.
  Future<String?> startAdvertising() async {
    if (_isAdvertising) return null;

    _peripheralError = null;

    try {
      await refreshAdapterState();
      if (!_isAdapterOn) {
        _peripheralError = 'Bluetooth is turned off. Please enable Bluetooth.';
        notifyListeners();
        return _peripheralError;
      }

      if (!await _ensureBluetoothPermissions()) {
        _peripheralError = 'Bluetooth permission is required to receive files.';
        notifyListeners();
        return _peripheralError;
      }

      // Initialise the peripheral stack (idempotent).
      await ble_p.BlePeripheral.initialize();

      // Define the RX characteristic — writable by the central.
      final rxChar = ble_p.BleCharacteristic(
        uuid: lexyRxCharUuid,
        properties: [
          ble_p.CharacteristicProperties.write.index,
          ble_p.CharacteristicProperties.writeWithoutResponse.index,
        ],
        permissions: [ble_p.AttributePermissions.writeable.index],
      );

      // Define the TX characteristic — readable/notifiable by the central.
      final txChar = ble_p.BleCharacteristic(
        uuid: lexyTxCharUuid,
        properties: [
          ble_p.CharacteristicProperties.read.index,
          ble_p.CharacteristicProperties.notify.index,
        ],
        permissions: [ble_p.AttributePermissions.readable.index],
      );

      // Register the service.
      await ble_p.BlePeripheral.addService(
        ble_p.BleService(
          uuid: lexyServiceUuid,
          primary: true,
          characteristics: [rxChar, txChar],
        ),
      );

      // Set the write request callback to receive file data.
      ble_p.BlePeripheral.setWriteRequestCallback((
        String deviceId,
        String characteristicId,
        int offset,
        Uint8List? value,
      ) {
        // Only process writes to our RX characteristic.
        if (characteristicId.toLowerCase() != lexyRxCharUuid.toLowerCase()) {
          return null;
        }
        if (value == null || value.isEmpty) return null;

        final result = _receiver.feed(value);
        if (result != null) {
          debugPrint(
            'BLE peripheral: received "${result.fileName}" '
            '(${result.fileSize} bytes)',
          );
          onFileReceived?.call(
            result.fileName,
            result.fileSize,
            result.filePath,
          );
        }

        return ble_p.WriteRequestResult(status: 0); // success
      });

      // Monitor BLE state changes.
      ble_p.BlePeripheral.setBleStateChangeCallback((bool state) {
        if (!state) {
          _isAdvertising = false;
          notifyListeners();
        }
      });

      // Start advertising.
      await ble_p.BlePeripheral.startAdvertising(
        services: [lexyServiceUuid],
        localName: 'Lexy Files',
      );

      _isAdvertising = true;
      notifyListeners();
      return null;
    } catch (e) {
      _peripheralError = 'Advertising failed: $e';
      debugPrint('BLE peripheral: startAdvertising error: $e');
      _isAdvertising = false;
      notifyListeners();
      return _peripheralError;
    }
  }

  /// Stop the GATT server and cease advertising.
  Future<void> stopAdvertising() async {
    try {
      await ble_p.BlePeripheral.stopAdvertising();
      await ble_p.BlePeripheral.clearServices();
    } catch (e) {
      debugPrint('BLE peripheral: stopAdvertising error: $e');
    } finally {
      _isAdvertising = false;
      notifyListeners();
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _scanSub?.cancel();
    _adapterSub?.cancel();
    _adapterPollTimer?.cancel();
    if (canScanAndSend) {
      FlutterBluePlus.stopScan();
    }
    // Best-effort: stop advertising on dispose.
    ble_p.BlePeripheral.stopAdvertising().ignore();
    super.dispose();
  }
}
