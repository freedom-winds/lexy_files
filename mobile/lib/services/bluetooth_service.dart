import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:ble_peripheral/ble_peripheral.dart' as ble_p;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Custom Lexy Files BLE service UUID (Nordic UART Service compatible).
const String lexyServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

/// RX characteristic (central writes to this to send data to us when we are peripheral).
const String lexyRxCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

/// TX characteristic (peripheral writes here; central subscribes for notifications).
const String lexyTxCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

/// Max BLE write size per packet (conservative, covers most devices).
const int _bleChunkSize = 512;

// ---------------------------------------------------------------------------
// Peripheral protocol state machine
// ---------------------------------------------------------------------------

enum _RxState { waitingHeader, receivingData, done }

/// Accumulates incoming BLE writes and parses the Lexy file transfer protocol.
///
/// Protocol:
///   1. Central writes JSON header terminated by 0x00:
///      {"file_name":"foo.txt","file_size":1234}\x00
///   2. Central writes raw file data in <=512-byte chunks.
///   3. Central writes EOT: {"type":"eot"}
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
typedef BleReceiveCallback = void Function(
    String fileName, int fileSize, Uint8List data);

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class BluetoothTransferService extends ChangeNotifier {
  // ── Central (scan + send) state ────────────────────────────────────────────

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isAdapterOn = false;
  bool get isAdapterOn => _isAdapterOn;

  String? _error;
  String? get error => _error;

  final List<BleDiscoveredDevice> _devices = [];
  List<BleDiscoveredDevice> get devices => List.unmodifiable(_devices);

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  // ── Peripheral (GATT server) state ─────────────────────────────────────────

  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  String? _peripheralError;
  String? get peripheralError => _peripheralError;

  final _PeripheralReceiver _receiver = _PeripheralReceiver();

  // ── Callbacks ──────────────────────────────────────────────────────────────

  /// Called when a complete file has been received via GATT server mode.
  BleReceiveCallback? onFileReceived;

  // ── Constructor ────────────────────────────────────────────────────────────

  BluetoothTransferService() {
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      _isAdapterOn = state == BluetoothAdapterState.on;
      if (!_isAdapterOn) {
        _isScanning = false;
        _devices.clear();
        if (_isAdvertising) {
          _isAdvertising = false;
        }
      }
      notifyListeners();
    });
  }

  // ── Central: scan ──────────────────────────────────────────────────────────

  /// Start scanning for BLE devices advertising the Lexy service UUID.
  Future<void> startScan() async {
    if (!_isAdapterOn) {
      _error = 'Bluetooth is turned off. Please enable Bluetooth.';
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

          final existing = _devices
              .indexWhere((d) => d.device.remoteId == result.device.remoteId);
          if (existing >= 0) {
            _devices[existing] = BleDiscoveredDevice(
              device: result.device,
              name: name,
              discoveredAt: DateTime.now(),
            );
          } else {
            _devices.add(BleDiscoveredDevice(
              device: result.device,
              name: name,
              discoveredAt: DateTime.now(),
            ));
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
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  // ── Central: send ──────────────────────────────────────────────────────────

  /// Send a file to a BLE device.
  /// Returns null on success, or an error string.
  Future<String?> sendFile({
    required BluetoothDevice device,
    required String fileName,
    required Uint8List fileData,
    BleProgressCallback? onProgress,
  }) async {
    try {
      await device.connect(timeout: const Duration(seconds: 15));
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
      final headerBytes =
          Uint8List.fromList([...utf8.encode(header), 0x00]); // null terminator
      await rxChar.write(headerBytes, withoutResponse: false);

      // Send file in BLE-sized chunks.
      int sent = 0;
      while (sent < fileData.length) {
        final end = (sent + _bleChunkSize).clamp(0, fileData.length);
        final chunk = fileData.sublist(sent, end);
        await rxChar.write(chunk, withoutResponse: false);
        sent = end;
        onProgress?.call(sent, fileData.length);
        // Small delay to avoid overflowing GATT queue.
        await Future.delayed(const Duration(milliseconds: 20));
      }

      // Send end-of-transfer signal.
      final eot = utf8.encode('{"type":"eot"}');
      await rxChar.write(eot, withoutResponse: false);

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
      // Initialise the peripheral stack (idempotent).
      await ble_p.BlePeripheral.initialize();

      // Define the RX characteristic — writable by the central.
      final rxChar = ble_p.BleCharacteristic(
        uuid: lexyRxCharUuid,
        properties: [
          ble_p.CharacteristicProperties.write.index,
          ble_p.CharacteristicProperties.writeWithoutResponse.index,
        ],
        permissions: [
          ble_p.AttributePermissions.writeable.index,
        ],
      );

      // Define the TX characteristic — readable/notifiable by the central.
      final txChar = ble_p.BleCharacteristic(
        uuid: lexyTxCharUuid,
        properties: [
          ble_p.CharacteristicProperties.read.index,
          ble_p.CharacteristicProperties.notify.index,
        ],
        permissions: [
          ble_p.AttributePermissions.readable.index,
        ],
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
      ble_p.BlePeripheral.setWriteRequestCallback(
        (String deviceId, String characteristicId, int offset, Uint8List? value) {
          // Only process writes to our RX characteristic.
          if (characteristicId.toLowerCase() != lexyRxCharUuid.toLowerCase()) {
            return null;
          }
          if (value == null || value.isEmpty) return null;

          final result = _receiver.feed(value);
          if (result != null) {
            debugPrint(
              'BLE peripheral: received "${result.fileName}" '
              '(${result.data.length} bytes)',
            );
            onFileReceived?.call(
              result.fileName,
              result.fileSize,
              result.data,
            );
          }

          return ble_p.WriteRequestResult(status: 0); // success
        },
      );

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
    FlutterBluePlus.stopScan();
    // Best-effort: stop advertising on dispose.
    ble_p.BlePeripheral.stopAdvertising().ignore();
    super.dispose();
  }
}
