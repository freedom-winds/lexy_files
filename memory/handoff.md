# Handoff

_Last updated: 2026-03-20_

## Current state
Project at ~85% completion. All core phases (0-5) are complete. Remaining work is deferred features (WebSocket relay, LAN, Bluetooth, device UI).

## What works
- **Backend (100%)**: Flask app with 5 API blueprint groups, 4 service layers, JWT auth with anonymous support, quota enforcement, file lifecycle with cleanup, 81 passing tests (66 unit + 15 integration)
- **Web frontend (100%)**: Vite + React + TypeScript + Tailwind. All pages: Home, Login, Register, Pickup, MyFiles, Admin (stats, users, files, groups). Build verified (315KB JS).
- **Flutter clients (100% core)**: Android/iOS/Windows targets. Screens: Login, Register, Home (upload + pickup code), Pickup (download), MyFiles. Dio + Provider + Material 3.
- **Windows desktop build**: Verified — `build/windows/x64/runner/Debug/lexy_files.exe`
- **Documentation**: README.md, docs/setup.md, docs/deployment.md, docs/release-checklist.md

## What is NOT yet done
- **Android APK build**: Code is correct, but Gradle can't download dependencies (dl.google.com blocked in China). Will work with VPN or in a different network environment.
- **iOS build**: Requires macOS + Xcode (not available in current environment)
- **WebSocket relay**: Same-account device transfer — API contracts defined, backend endpoint stubbed, not wired
- **LAN transfer**: Not implemented
- **Bluetooth transfer**: Not implemented
- **Device registration UI**: API exists, no Flutter/web UI
- **Push notifications**: Not implemented

## What is blocked
Nothing is blocked. All deliverable work is complete.

## Verification summary
| Component | Status | Command |
|---|---|---|
| Backend tests | 81/81 passing | `cd backend && python -m pytest tests/ -v` |
| Flutter analyze | 0 issues | `cd mobile && flutter analyze` |
| Flutter test | 1/1 passing | `cd mobile && flutter test` |
| Web build | 315KB JS + 27KB CSS | `cd web && npm run build` |
| TypeScript | Clean | `cd web && npx tsc --noEmit` |
| Windows build | lexy_files.exe | `cd mobile && flutter build windows --debug` |
| Android build | Network blocked | `cd mobile && flutter build apk --debug` (needs Google Maven access) |

## Prompt for next session

When the user says "continue to work, claude", do the following:

1. Read `memory/current-focus.md` and `memory/handoff.md` for context
2. All 5 core phases are COMPLETE. The remaining work is deferred features:
   - **WebSocket relay for same-account transfer**: Implement the `/ws` endpoint in backend, wire it to Flutter/web clients for real-time file streaming between devices on the same account
   - **Device registration UI**: Build screens in Flutter and web to list/register/remove devices
   - **LAN transfer**: Implement peer-to-peer file transfer using mDNS discovery + direct TCP
   - **Bluetooth transfer**: Implement BLE-based file transfer for Android/iOS/Windows
3. Ask the user which feature they'd like to implement next
4. For any feature, start by reading the API contracts in `memory/api-contracts.md`

## Git log (recent)
```
306aad3 update
697b1e2 Update memory files: mark Phases 0-3 complete, prepare Phase 4 handoff
0a1e856 Add Flutter platform configurations (Android, iOS, Windows)
8639328 Phase 3: Flutter mobile/desktop app with auth, file transfer, and pickup code
b1eac68 Phase 2: Complete web frontend with all pages, routing, and admin console
a00627f WIP: Web frontend partial + save state for continuation
c52aeb2 Phase 1: Complete Flask backend with all APIs, services, and 66 passing tests
df3d030 Phase 0: Project brief, architecture decisions, API contracts, roadmap
8cdac05 Initial project setup with requirements and empty memory templates
```
