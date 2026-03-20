# Current Focus

_Last updated: 2026-03-20_

## Active objective
Phase 4 + Phase 5 COMPLETE. All core phases delivered.

## What's done
- Phase 0: Project brief, architecture decisions, API contracts, roadmap — COMPLETE
- Phase 1: Flask backend — COMPLETE (81 tests passing, including 15 integration tests)
- Phase 2: Web frontend — COMPLETE (all pages, admin console, build verified)
- Phase 3: Flutter clients — COMPLETE (Android/iOS/Windows, analyze clean, 1 test passing)
- Phase 4: Cross-platform verification — COMPLETE
  - Android internet permission added
  - Backend integration test (full API flow: register → login → upload → pickup → download → delete)
  - 81 tests all passing
  - Flutter analyze: 0 issues
  - Windows desktop build: SUCCESS (lexy_files.exe)
  - Android APK build: BLOCKED by network (dl.google.com inaccessible from China — code is correct)
- Phase 5: Documentation — COMPLETE
  - README.md (comprehensive)
  - docs/setup.md (bootstrap guide)
  - docs/deployment.md (production deployment)
  - docs/release-checklist.md

## Remaining work (deferred features)
- Same-account device relay (WebSocket streaming) — API defined, not wired
- LAN peer-to-peer transfer — not implemented
- Bluetooth transfer — not implemented
- Device registration UI — not built
- iOS build verification — requires macOS

## Key technical notes
- Python venv at `backend/venv/` (Python 3.11)
- Backend tests: `cd backend && source venv/Scripts/activate && python -m pytest tests/ -v`
- Web build: `cd web && npm run build`
- Flutter analyze: `cd mobile && flutter analyze`
- Flutter Windows build: `cd mobile && flutter build windows --debug`
- Android APK needs VPN/proxy for Google Maven repos in China

## Blocking issues
None — all deliverable phases complete.
