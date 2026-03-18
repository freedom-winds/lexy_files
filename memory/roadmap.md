# Roadmap

_Last updated: 2026-03-18_

## Phase 0 — Discovery and architecture ✅
- [x] Read and analyze requirements
- [x] Write project brief
- [x] Architecture decisions (Flutter + React + Flask)
- [x] Define API contracts
- [x] Define data models

## Phase 1 — Backend foundation + first vertical slice
- [ ] Project scaffolding (monorepo, configs, dependencies)
- [ ] Database models (User, Device, File, Transfer, Quota)
- [ ] Auth system (register, login, JWT, refresh, anonymous)
- [ ] File upload/download with pickup codes
- [ ] Quota enforcement (speed, size, storage, traffic)
- [ ] File lifecycle (expiration, redemption, deletion)
- [ ] Background task for file cleanup
- [ ] Backend unit + integration tests

## Phase 2 — Web client + admin console
- [ ] React project setup (Vite + TypeScript + Tailwind)
- [ ] Auth pages (login, register)
- [ ] File upload/download UI
- [ ] Pickup code entry
- [ ] My Files dashboard
- [ ] Admin console (users, files, quotas, stats)
- [ ] Web client smoke tests

## Phase 3 — Flutter clients
- [ ] Flutter project setup (shared packages)
- [ ] Auth flow (login required)
- [ ] File upload/download
- [ ] Device registration
- [ ] Same-account device transfer (WebSocket relay)
- [ ] LAN discovery and transfer
- [ ] Bluetooth transfer
- [ ] Client smoke tests

## Phase 4 — Cross-platform hardening
- [ ] End-to-end happy-path test
- [ ] Quota enforcement verification across all modes
- [ ] File lifecycle verification
- [ ] Admin console full verification
- [ ] Performance and edge case testing

## Phase 5 — Release readiness
- [ ] README and setup docs
- [ ] Architecture decision records
- [ ] Deployment notes
- [ ] Release checklist
