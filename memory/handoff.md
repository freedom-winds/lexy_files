# Handoff

_Last updated: 2026-03-19_

## Current state
Project at ~65% completion. Backend, web frontend, and Flutter clients are all built. Need verification, E2E tests, and documentation.

## What works
- **Backend (100%)**: Flask app at `backend/` with all models, 5 API blueprints (auth, files, devices, transfers, admin), 4 services (auth, file, quota, cleanup), JWT auth with anonymous support, quota enforcement, file lifecycle with redemption, APScheduler cleanup, 66 passing tests
- **Web frontend (100%)**: Vite + React + TypeScript + Tailwind at `web/`. All pages complete: Home (upload + pickup code), Login, Register, PickupPage, MyFilesPage, Admin (stats, users, files, groups). Build verified (315KB JS bundle).
- **Flutter clients (100% code)**: Flutter 3.38 app at `mobile/` targeting Android, iOS, Windows. Screens: Login, Register, Home (upload + pickup code), Pickup (download), MyFiles. Dio-based API service, Provider state management, Material 3 theme. `flutter analyze`: 0 issues, `flutter test`: 1/1 passing.

## What is NOT yet done
- **Platform builds**: Android APK and Windows exe not yet built/verified
- **Android manifest**: needs `<uses-permission android:name="android.permission.INTERNET"/>`
- **E2E tests**: no cross-platform integration test yet
- **WebSocket relay**: same-account device transfer not implemented (API contracts defined, backend endpoint stubbed)
- **LAN/Bluetooth transfer**: not implemented (deferred per roadmap)
- **Documentation**: README, setup docs, architecture records, deployment notes all missing

## What is blocked
Nothing is blocked.

## Prompt for next session

When the user says "continue to work, claude", do the following:

1. Read `memory/current-focus.md` and `memory/handoff.md` for context
2. Resume at Phase 4: Cross-platform verification
3. Add Android internet permission to `mobile/android/app/src/main/AndroidManifest.xml`
4. Try `flutter build apk --debug` and `flutter build windows --debug`
5. Write a backend integration test script that exercises the full API flow (register → login → upload → pickup → download → delete)
6. Then move to Phase 5: Documentation
   - Write a comprehensive README.md
   - Write setup/bootstrap docs
   - Update memory/roadmap.md to mark phases complete
   - Create deployment notes
7. Update handoff.md with final state
8. Commit each milestone separately

## Git log (recent)
```
0a1e856 Add Flutter platform configurations (Android, iOS, Windows)
8639328 Phase 3: Flutter mobile/desktop app with auth, file transfer, and pickup code
b1eac68 Phase 2: Complete web frontend with all pages, routing, and admin console
a00627f WIP: Web frontend partial + save state for continuation
c52aeb2 Phase 1: Complete Flask backend with all APIs, services, and 66 passing tests
df3d030 Phase 0: Project brief, architecture decisions, API contracts, roadmap
8cdac05 Initial project setup with requirements and empty memory templates
```
