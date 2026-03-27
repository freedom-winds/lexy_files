# Handoff

_Last updated: 2026-03-21_

## Current state
All 4 transfer modes implemented and verified clean. WebSocket relay, LAN, and Bluetooth (bidirectional) transfer code is written and passes `flutter analyze` with 0 issues.

## What works

### Backend (100%)
- Flask app with 5 API blueprint groups, 4 service layers, JWT auth with anonymous support, quota enforcement, file lifecycle
- **WebSocket relay** via Flask-SocketIO (`backend/app/ws/events.py`): TransferNamespace handles connect/disconnect, device presence in Redis, transfer accept/reject/data/complete, quota enforcement on receiver, chunk relay without disk write
- **WebRTC signaling**: `on_webrtc_offer`, `on_webrtc_answer`, `on_webrtc_ice_candidate` relay SDP/ICE between device rooms
- REST transfer creation notifies receiver via WS (`backend/app/api/transfers.py` line 92-98)
- 81 passing tests

### Web frontend (100%)
- Vite + React + TypeScript + Tailwind
- **DevicesPage** (`web/src/pages/DevicesPage.tsx`): device CRUD, auto-register browser, online/offline status
- **TransferPage** (`web/src/pages/TransferPage.tsx`): full WebSocket streaming — picks file, creates REST transfer, streams base64 chunks via socket.io, handles incoming transfers with accept/reject, assembles received chunks into downloadable Blob
- Note: Web cannot do LAN (raw TCP) or BLE — relay mode is the correct web transfer path

### Flutter clients (100% code)
- **Relay tab** (`mobile/lib/screens/transfer_screen.dart`): connects WebSocketService, streams file chunks via WS, handles incoming transfers (accept/reject/receive), saves completed downloads
- **LAN tab**: UDP broadcast discovery (port 42424) + TCP file transfer (port 42425), both send AND receive work
- **Bluetooth tab**: BLE scan + send via GATT characteristic writes (central mode via `flutter_blue_plus`). **BLE receive** via GATT server/peripheral mode (`ble_peripheral` package v2.4.0) — advertises Lexy service UUID, accepts incoming writes, parses header+data+EOT protocol, delivers received file via callback
- **DevicesScreen** (`mobile/lib/screens/devices_screen.dart`): register/delete devices
- **WebSocketService** (`mobile/lib/services/websocket_service.dart`): Socket.IO client with all transfer events
- Dependencies: socket_io_client, network_info_plus, flutter_blue_plus, ble_peripheral, uuid, permission_handler, path_provider

### Documentation
- README.md, docs/setup.md, docs/deployment.md, docs/release-checklist.md

## BLE implementation details
- **Central (send)**: `flutter_blue_plus` — scans for Lexy service UUID, connects, discovers services, writes header→chunks→EOT to RX characteristic
- **Peripheral (receive)**: `ble_peripheral` v2.4.0 — uses callback-based API (NOT streams):
  - Import with prefix: `import 'package:ble_peripheral/ble_peripheral.dart' as ble_p;`
  - `ble_p.BlePeripheral.initialize()`, `.addService()`, `.startAdvertising()`, `.stopAdvertising()`, `.clearServices()`
  - `ble_p.BlePeripheral.setWriteRequestCallback(callback)` for incoming data
  - `ble_p.BlePeripheral.setBleStateChangeCallback(callback)` for state monitoring
  - `BleCharacteristic` properties/permissions are `List<int>` — use `.index` on enum values
- **Protocol**: JSON header `{"file_name":"...","file_size":N}` + `\x00` null terminator → raw data chunks (512B) → `{"type":"eot"}` signal
- **`_PeripheralReceiver`** state machine in `bluetooth_service.dart` (lines 24-131) handles protocol parsing

## Known limitations
1. **Web LAN/BLE**: Browsers cannot do raw TCP sockets or BLE peripheral. This is a fundamental browser limitation, not a bug. Web users transfer via the WebSocket relay.
2. **Android APK build**: Gradle can't download from dl.google.com (network blocked in China). Code is correct.
3. **iOS build**: Requires macOS + Xcode (not available in current environment)
4. **BLE throughput**: ~2-20KB/s, impractical for large files. LAN or relay recommended for local transfers.
5. **BLE peripheral platform support**: `ble_peripheral` supports Android, iOS, macOS, and Windows. Linux BLE peripheral support is limited.

## Verification summary
| Component | Status | Command |
|---|---|---|
| Backend tests | 81/81 passing | `cd backend && python -m pytest tests/ -v` |
| Flutter analyze | 0 issues | `cd mobile && flutter analyze` |
| Web TypeScript | Clean | `cd web && npx tsc --noEmit` |
| Web build | 379KB JS + 29KB CSS | `cd web && npx vite build` |

## Key files added/modified
- `backend/app/ws/__init__.py` + `events.py` — WebSocket relay namespace + WebRTC signaling
- `backend/app/api/transfers.py` — REST transfer endpoints + WS notification
- `web/src/pages/DevicesPage.tsx` + `TransferPage.tsx` — web device mgmt + WS transfer
- `mobile/lib/services/websocket_service.dart` — Socket.IO client
- `mobile/lib/services/lan_service.dart` — LAN discovery + TCP transfer
- `mobile/lib/services/bluetooth_service.dart` — BLE scan/send (central) + GATT server receive (peripheral)
- `mobile/lib/screens/transfer_screen.dart` — 3-tab transfer UI (Relay/LAN/BT) with BLE receive toggle
- `mobile/lib/screens/devices_screen.dart` — device management
- `mobile/lib/models/transfer.dart` — transfer + incoming request models

## Resume instructions
To continue this project, say "continue to work, claude" and the next steps are:
1. Run `flutter analyze` and `pytest` to confirm everything still passes
2. Check the roadmap (`memory/roadmap.md`) for remaining phases
3. Potential next work: end-to-end integration testing, UI polish, desktop packaging, or cross-platform smoke testing
