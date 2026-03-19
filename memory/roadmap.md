# Roadmap

_Last updated: 2026-03-19_

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
- [x] Backend unit + integration tests (66 passing)

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

## Phase 4 — Cross-platform hardening
- [ ] Android APK build verification
- [ ] Windows desktop build verification
- [ ] Backend integration test (full API flow)
- [ ] E2E happy-path test
- [ ] Quota enforcement verification
- [ ] File lifecycle verification

## Phase 5 — Release readiness
- [ ] README and setup docs
- [ ] Architecture decision records
- [ ] Deployment notes
- [ ] Release checklist
