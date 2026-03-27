# Current Focus

_Last updated: 2026-03-21_

## Active objective
All transfer modes complete and verified. Ready for next phase (integration testing, UI polish, or desktop packaging).

## What's done
- Phases 0-5: All complete (backend, web, Flutter, tests, docs)
- WebSocket relay: Backend relay + web client + Flutter client all wired up
- LAN transfer: UDP discovery + TCP send/receive — bidirectional, Flutter-only
- Bluetooth transfer: BLE scan + send (central) AND receive (peripheral/GATT server) — bidirectional, Flutter-only
- Device management: Web (DevicesPage) + Flutter (DevicesScreen) — register, delete, online status
- Web platform: relay-only (browsers can't do raw TCP/BLE — documented limitation)

## Known gaps
- Android APK build blocked by network (dl.google.com inaccessible from China)
- iOS build requires macOS + Xcode
- No end-to-end cross-device integration test yet
- Desktop packaging not done

## Verification
- Backend: 81/81 tests passing
- Flutter: `flutter analyze` — 0 issues
- Web: `tsc --noEmit` clean, `vite build` 379KB JS

## Blocking issues
None.
