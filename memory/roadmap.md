# Roadmap

_Last updated: 2026-03-20_

## Phase 0 — Discovery and architecture ✅
- [x] Read and analyze requirements
- [x] Write project brief
- [x] Architecture decisions (Flutter + React + Flask)
- [x] Define API contracts
- [x] Define data models

## Phase 1 — Backend foundation + first vertical slice ✅
- [x] Project scaffolding (monorepo, configs, dependencies)
- [x] Database models (User, Device, File, Transfer, Quota)
- [x] Auth system (register, login, JWT, refresh, anonymous)
- [x] File upload/download with pickup codes
- [x] Quota enforcement (speed, size, storage, traffic)
- [x] File lifecycle (expiration, redemption, deletion)
- [x] Background task for file cleanup
- [x] Backend unit + integration tests (81 passing)

## Phase 2 — Web client + admin console ✅
- [x] React project setup (Vite + TypeScript + Tailwind)
- [x] Auth pages (login, register)
- [x] File upload/download UI
- [x] Pickup code entry
- [x] My Files dashboard
- [x] Admin console (stats, users, files, groups)
- [x] Web client build verified (315KB bundle)

## Phase 3 — Flutter clients ✅
- [x] Flutter project setup (shared packages)
- [x] Auth flow (login required)
- [x] File upload/download
- [x] Pickup code entry and file retrieval
- [x] My Files management
- [x] flutter analyze: 0 issues
- [x] flutter test: 1/1 passing
- [ ] Device registration (stubbed in API, UI deferred)
- [ ] Same-account device transfer (WebSocket relay — API defined, not wired)
- [ ] LAN discovery and transfer (deferred)
- [ ] Bluetooth transfer (deferred)

## Phase 4 — Cross-platform hardening ✅
- [x] Android internet permission added
- [x] Backend integration test (full API flow — 15 new tests)
- [x] Flutter analyze: 0 issues confirmed
- [x] Windows desktop build verified (lexy_files.exe)
- [x] Android APK build attempted (network-blocked in China, code correct)
- [ ] iOS build verification (requires macOS)

## Phase 5 — Release readiness ✅
- [x] README.md
- [x] Setup/bootstrap docs (docs/setup.md)
- [x] Deployment notes (docs/deployment.md)
- [x] Release checklist (docs/release-checklist.md)

## Deferred — Future features
- [ ] Same-account device relay (WebSocket streaming implementation)
- [ ] LAN peer-to-peer transfer
- [ ] Bluetooth transfer
- [ ] Device registration UI
- [ ] Push notifications for mobile
- [ ] Cloud storage backend (S3)
- [ ] Chunked upload for large files (tus.io)
