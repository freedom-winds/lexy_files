# Decisions

_Last updated: 2026-03-18_

## Accepted decisions

### D1: Flutter for native clients (Android, iOS, Desktop) — 2026-03-18
**Options considered:**
- **Option A (Flutter):** Single Dart codebase for Android, iOS, Desktop. Mature BLE and LAN plugins. Strong UI reuse. Web support exists but heavy.
- **Option B (TypeScript monorepo):** React web + React Native mobile + Electron desktop. Better web ecosystem, but significantly more code duplication and three separate UI frameworks.

**Decision:** Flutter for Android/iOS/Desktop clients. React+TypeScript for Web client.

**Rationale:** The native clients need Bluetooth, LAN discovery, and file system access — Flutter has mature plugins for all three. Desktop support is production-ready. Maximum UI/logic reuse across 3 platforms. Web client stays React because: (1) web requires anonymous access with fast load times (Flutter web is heavy), (2) admin console is web-only and benefits from React ecosystem, (3) web SEO/accessibility is better with React.

### D2: Monorepo structure — 2026-03-18
Single repository with top-level directories: `backend/`, `web/`, `flutter/`, `shared/`, `docs/`.

### D3: REST API with WebSocket for real-time — 2026-03-18
REST for CRUD operations, file upload/download, admin. WebSocket for same-account relay streaming, device discovery signals, and transfer progress notifications.

### D4: JWT authentication with refresh tokens — 2026-03-18
Short-lived access tokens (15 min) + long-lived refresh tokens stored in Redis. Anonymous users get temporary tokens tied to IP+device fingerprint.

### D5: File storage on local filesystem with configurable path — 2026-03-18
Files stored in a configurable directory, organized by user_id/file_id. Abstracted behind a storage interface for future S3/cloud migration.

### D6: Pickup codes are 6-character alphanumeric — 2026-03-18
Case-insensitive, collision-checked, expire with the file. Format: `[A-Z0-9]{6}` excluding ambiguous characters (0/O, 1/I/L).

## Deferred decisions
- Cloud storage backend (S3, etc.) — implement local first, abstract behind interface
- Push notification provider for mobile clients
- WebRTC vs raw TCP for LAN transfer signaling

## Rejected options
- Flutter for web: Too heavy for anonymous-access web client, poor SEO, slow initial load
- SQLite: Not suitable for multi-user concurrent server workload
- gRPC: Overkill for this project, REST+WS sufficient
