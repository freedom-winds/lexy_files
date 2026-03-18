# Project Brief

_Last updated: 2026-03-18_

## Product summary
Lexy Files is a cross-device file transfer platform supporting Web, Android, iOS, and PC. It provides four transfer modes: Bluetooth, Local Network (LAN), Same-Account Device Relay, and Pickup Code/Direct Link. The system enforces per-user-group quotas for speed, storage, and traffic.

## Target users
- Individuals transferring files between their own devices (phone ↔ PC, tablet ↔ laptop)
- Users sharing files with others via pickup codes or direct links
- Administrators managing the platform, users, and files

## Platforms
- **Backend**: Flask (Python) + MySQL + Redis
- **Web client**: React + TypeScript (supports anonymous access)
- **Android**: Flutter
- **iOS**: Flutter
- **PC Desktop**: Flutter
- **Admin console**: Integrated into web client (admin-only routes)

## Core use cases
1. **Pickup Code transfer**: Upload file → get code/link → recipient downloads
2. **Same-Account relay**: Stream file between two logged-in devices in real time
3. **LAN transfer**: Peer-to-peer file transfer on same network, no server relay
4. **Bluetooth transfer**: Direct device-to-device transfer
5. **Admin management**: User/device/file management, quota control, audit

## Constraints
- Backend must use Flask + MySQL (required)
- Redis optional but strongly recommended for sessions, rate limiting, relay coordination
- File data must NOT pass through server for Bluetooth and LAN modes
- Same-Account relay must NOT persist files on server
- Anonymous users identified by IP OR device identity (union match)
- Web allows anonymous access; all native clients require login
- Files follow 3-stage lifecycle: active → 7-day redemption → physical deletion

## Non-goals
- End-to-end encryption (not specified in requirements)
- File versioning or collaboration features
- Social/sharing features beyond pickup codes
- Payment/billing integration (quotas are admin-managed)

## Acceptance criteria
1. All four transfer modes functional on their supported platforms
2. User group quotas enforced (speed, file size, storage, traffic, retention)
3. Anonymous user consolidation by IP or device identity
4. Admin console with full user/device/file management
5. File lifecycle with redemption grace period and physical deletion
6. Clean, modern, non-AI-looking UI across all clients
7. Automated tests for critical backend flows and one E2E happy path
