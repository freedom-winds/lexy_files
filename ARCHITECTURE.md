# Lexy Files Architecture

_Last updated: 2026-05-12_

## 1. System Overview

**Lexy Files** is a cross-platform file transfer platform that enables seamless file sharing across Web, Android, iOS, Windows, and Linux devices. The system supports four distinct transfer modes optimized for different use cases:

1. **Pickup Code/Direct Link**: Traditional upload-download with temporary server storage
2. **Same-Account Relay**: Real-time streaming between logged-in devices (no server persistence)
3. **LAN Transfer**: Peer-to-peer transfer on local networks (no server relay)
4. **Bluetooth Transfer**: Direct device-to-device transfer via BLE

### Key Characteristics

- **Multi-platform**: Single backend serves web, mobile (Android/iOS), and desktop (Windows/Linux) clients
- **Quota-based**: Per-user-group limits for speed, storage, traffic, file size, and retention
- **Anonymous support**: Web allows anonymous access; native clients require login
- **Admin console**: Full user/device/file management with audit capabilities
- **Production-ready**: Automated tests, deployment docs, release checklist, systemd service

## 2. High-Level Architecture

```
                                  ┌─────────────────────────┐
                                  │   Nginx (HTTPS, :443)   │
                                  │  files.example.com      │
                                  └───────────┬─────────────┘
                                              │
                  ┌───────────────────────────┼───────────────────────────┐
                  │ /                         │ /api/                     │ /socket.io/
                  ▼                           ▼                           ▼
        ┌──────────────────┐       ┌─────────────────────────────────────────────┐
        │ Web static SPA   │       │   Flask Backend (Gunicorn + eventlet :5000) │
        │ (web/dist/)      │       │   ┌──────────┬──────────┬────────────────┐  │
        │ React + Vite     │       │   │ REST API │ WS Relay │ Scheduler/Jobs │  │
        └──────────────────┘       │   └──────────┴──────────┴────────────────┘  │
                                   └────────┬────────────┬───────────────┬───────┘
                                            │            │               │
                                            ▼            ▼               ▼
                                     ┌────────────┐ ┌────────┐ ┌───────────────────┐
                                     │  MySQL 8   │ │ Redis  │ │ Storage           │
                                     │ (metadata) │ │ (JWT   │ │  local FS or      │
                                     │            │ │  block,│ │  S3-compatible    │
                                     │            │ │ rate-  │ │                   │
                                     │            │ │ limit, │ │                   │
                                     │            │ │ device │ │                   │
                                     │            │ │ pres.) │ │                   │
                                     └────────────┘ └────────┘ └───────────────────┘

                              Native clients (Flutter, single codebase)
                       ┌──────────────┬──────────────┬──────────────────┐
                       │   Android    │     iOS      │ Windows / Linux  │
                       └──────────────┴──────────────┴──────────────────┘
                              │              │              │
                              └──── HTTPS / WSS to backend──┘
                              │              │              │
                              └── LAN UDP/TCP (peer-to-peer) ─┘
                              │              │              │
                              └──── BLE (peer-to-peer) ──────┘
```

### Request flow summary

- **Web SPA** is served as static assets from `web/dist/`. It calls REST endpoints under `/api/v1/` and connects to Socket.IO at the same origin.
- **Flutter clients** (Android, iOS, Windows, Linux) are built from a single Dart codebase under `mobile/`. They reach the backend over HTTPS+WSS for relay, but bypass the backend entirely for LAN and Bluetooth transfers.
- **Backend** uses Flask for REST, Flask-SocketIO for the WebSocket relay namespace, APScheduler (or equivalent) for background cleanup, MySQL for metadata, Redis for transient state, and a pluggable storage backend (local FS or S3).

## 3. Technology Stack

### Backend
- **Framework**: Flask 3.x (Python 3.11+)
- **Database**: MySQL 8.0+ (production), SQLite (testing)
- **ORM**: SQLAlchemy with Flask-Migrate for migrations
- **Cache/State**: Redis 7+ (JWT blacklist, rate limiting, device presence)
- **Real-time**: Flask-SocketIO (Socket.IO server)
- **Auth**: Flask-JWT-Extended (JWT with refresh tokens)
- **Storage**: Pluggable backend (local filesystem or S3-compatible)
- **WSGI**: Gunicorn with eventlet worker (for Socket.IO)
- **Testing**: pytest (81 tests passing)
- **Linting**: flake8

### Web Frontend
- **Framework**: React 18 + TypeScript
- **Build tool**: Vite 5
- **Styling**: Tailwind CSS
- **Routing**: React Router v6
- **HTTP client**: Axios
- **WebSocket**: socket.io-client
- **State**: React Context API (AuthProvider)
- **Type checking**: TypeScript strict mode

### Mobile/Desktop (Flutter)
- **Framework**: Flutter 3.x (Dart)
- **Platforms**: Android, iOS, Windows, Linux
- **State management**: Provider pattern
- **HTTP**: http package
- **WebSocket**: socket_io_client
- **LAN discovery**: UDP broadcast + TCP sockets (network_info_plus)
- **Bluetooth**: flutter_blue_plus (central/scan) + ble_peripheral (peripheral/GATT server)
- **Permissions**: permission_handler
- **Storage**: path_provider
- **Testing**: flutter_test

### Infrastructure
- **Reverse proxy**: Nginx (HTTPS termination, static serving, WebSocket upgrade)
- **Process manager**: systemd (production)
- **Deployment**: Manual or CI/CD (GitHub Actions ready)

## 4. Backend Architecture

### Layered structure

```
backend/app/
├── __init__.py          # create_app factory (Flask app + extensions + blueprints + scheduler)
├── extensions.py        # db, migrate, jwt, socketio, redis_client singletons
├── api/                 # HTTP layer — thin controllers, blueprint registration
│   ├── auth.py          #   /api/v1/auth/*       (register, login, refresh, logout, me, anonymous)
│   ├── files.py         #   /api/v1/files/*      (upload, pickup, download, list, delete)
│   ├── devices.py       #   /api/v1/devices/*    (register, list, delete, heartbeat)
│   ├── transfers.py     #   /api/v1/transfers/*  (create, accept/reject, cancel)
│   └── admin.py         #   /api/v1/admin/*      (users, files, groups, stats)
├── services/            # Business logic (reusable from REST + WS)
│   ├── auth_service.py  #   Password hashing, token lifecycle, anonymous consolidation
│   ├── file_service.py  #   Upload, pickup-code generation, download streaming
│   ├── quota_service.py #   Group lookup, quota checks, traffic accounting
│   └── cleanup_service.py # Expiration, redemption grace period, physical deletion
├── models/              # SQLAlchemy ORM models
│   ├── user.py          #   User + user_group
│   ├── device.py        #   Device + online status
│   ├── file.py          #   File metadata + lifecycle state
│   ├── transfer.py      #   Transfer session record
│   └── quota.py         #   GroupQuota + per-user overrides
├── storage/             # Pluggable storage backend
│   ├── base.py          #   StorageBackend interface (save, open, delete, size)
│   ├── local.py         #   LocalFilesystemStorage
│   └── s3.py            #   S3Storage (boto3, supports R2/MinIO/etc.)
├── ws/                  # Socket.IO namespace + events
│   ├── __init__.py
│   └── events.py        #   TransferNamespace: connect, presence, accept/reject, data relay,
│                        #   WebRTC signaling (offer/answer/ICE)
├── middleware/          # Request-level concerns (rate limiting, anonymous user hook)
└── utils/               # Constants, error model, helpers
    ├── constants.py
    ├── errors.py        #   Unified error envelope { error: { code, message, details } }
    └── helpers.py
```

### Request lifecycle

1. **Nginx** terminates TLS and proxies `/api/*` to Gunicorn (eventlet worker on :5000).
2. **Flask** routes by blueprint prefix (`auth_bp`, `files_bp`, `devices_bp`, `transfers_bp`, `admin_bp`).
3. **JWT middleware** validates the Bearer token; anonymous endpoints auto-provision a token tied to IP + device fingerprint.
4. **Controllers** (under `api/`) parse input, call into the matching **service**, and shape the response.
5. **Services** encapsulate business rules — quota checks, file lifecycle transitions, pickup-code generation, etc. — and talk to models and storage.
6. **Models** persist via SQLAlchemy to MySQL. Migrations live under `backend/migrations/`.
7. **Storage backend** is selected at boot from `STORAGE_BACKEND=local|s3`; controllers only know the `StorageBackend` interface.
8. **Errors** are normalized to `{ error: { code, message, details } }` with the code mapped to an HTTP status (see §9 and `memory/api-contracts.md`).

### Background work

- A scheduler is started by the app factory in **one** worker (selected via a process flag) to avoid duplicate jobs under Gunicorn.
- `cleanup_service.cleanup_job()` runs every `CLEANUP_INTERVAL_MINUTES` (default 30) and:
  - Flags files whose retention window has elapsed as **expired** (enter the 7-day redemption grace period).
  - Physically deletes files whose grace period has ended.
  - Releases storage quota accordingly.

### Boot-time checks

`create_app` performs fail-fast validation in production:
- Rejects default `SECRET_KEY` / `JWT_SECRET_KEY`.
- Rejects wildcard `CORS_ORIGINS` / `SOCKETIO_CORS_ORIGINS`.
- Validates that the configured storage path is writable (local) or bucket is reachable (s3).
- Seeds default group quotas (anonymous/normal/vip/admin) on first startup.

## 5. Web Frontend Architecture

### Structure

```
web/src/
├── main.tsx             # Entry point, React root, router setup
├── App.tsx              # Top-level routes + Layout wrapper
├── index.css            # Tailwind directives
├── components/          # Reusable UI components
│   ├── Layout.tsx       #   Header, nav, footer shell
│   ├── FileUpload.tsx   #   Drag-drop + file picker
│   ├── PickupCodeInput.tsx # 6-char code entry
│   ├── ProtectedRoute.tsx  # Auth guard (redirects to /login)
│   └── AdminRoute.tsx      # Admin-only guard
├── pages/               # Route-level components
│   ├── HomePage.tsx     #   Landing + quick upload
│   ├── LoginPage.tsx
│   ├── RegisterPage.tsx
│   ├── PickupPage.tsx   #   Enter code → download
│   ├── MyFilesPage.tsx  #   User's uploaded files
│   ├── DevicesPage.tsx  #   Device registration + online status
│   ├── TransferPage.tsx #   WebSocket relay UI (send/receive)
│   └── admin/           #   Admin console pages (users, files, groups, stats)
├── providers/
│   └── AuthProvider.tsx #   Context: user, token, login/logout/refresh
├── lib/
│   ├── api.ts           #   Axios instance + interceptors (auto-refresh, error handling)
│   ├── auth.ts          #   Token storage (localStorage), refresh logic
│   ├── webDevice.ts     #   Auto-register browser as a device
│   └── utils.ts         #   Helpers (formatBytes, etc.)
└── ...
```

### Key patterns

- **AuthProvider** wraps the app and exposes `{ user, token, login, logout, register }` via React Context.
- **api.ts** configures Axios with:
  - Base URL from `VITE_API_BASE_URL` (injected at build time).
  - Request interceptor: attaches `Authorization: Bearer <token>`.
  - Response interceptor: on 401, attempts token refresh; on failure, logs out.
- **ProtectedRoute** checks `user` from context; redirects to `/login` if null.
- **AdminRoute** additionally checks `user.user_group === 'admin'`.
- **TransferPage** uses `socket.io-client` to connect to `VITE_SOCKET_URL`, streams file chunks as base64, and assembles received chunks into a downloadable Blob.
- **DevicesPage** auto-registers the browser as a device on mount (using `webDevice.ts`), displays online/offline status, and allows manual device deletion.

### Build output

- `npm run build` produces `web/dist/` with:
  - `index.html` (SPA shell)
  - `assets/*.js` (code-split bundles, ~379KB total)
  - `assets/*.css` (Tailwind, ~29KB)
- Vite performs tree-shaking, minification, and asset hashing.
- The SPA uses client-side routing; Nginx must serve `index.html` for all non-API routes.

## 6. Mobile/Desktop Architecture

### Structure (single Flutter codebase for Android/iOS/Windows/Linux)

```
mobile/lib/
├── main.dart            # App entry, Provider setup, root MaterialApp
├── config/
│   ├── api_config.dart  #   API_BASE_URL / WS_URL from --dart-define
│   └── theme.dart       #   Material theme + dark/light tokens
├── models/              # Plain Dart data classes (JSON serializable)
│   ├── user.dart
│   ├── device.dart
│   ├── file_info.dart
│   └── transfer.dart    #   Transfer + IncomingTransferRequest
├── providers/
│   └── auth_provider.dart # ChangeNotifier: user, token, login/logout
├── services/            # Cross-platform business logic
│   ├── api_service.dart        #   HTTP client wrapper (login, upload, download, devices, transfers)
│   ├── websocket_service.dart  #   Socket.IO client (relay events, presence)
│   ├── device_presence_service.dart # Heartbeat + online tracking
│   ├── lan_service.dart        #   UDP discovery (:42424) + TCP transfer (:42425)
│   └── bluetooth_service.dart  #   BLE scan/send (central) + GATT server receive (peripheral)
├── screens/             # Page-level widgets
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart
│   ├── pickup_screen.dart      # Pickup-code download
│   ├── my_files_screen.dart    # User's uploaded files
│   ├── devices_screen.dart     # Device registration + presence
│   └── transfer_screen.dart    # 3-tab UI: Relay / LAN / Bluetooth
└── widgets/             # Shared UI primitives (app_ui, file_size_text, ...)
```

### Platform adapters

The Flutter app is intentionally **one product**, with platform-specific code isolated behind plugins:

| Concern               | Plugin                | Platforms supported           |
|-----------------------|-----------------------|-------------------------------|
| Storage paths         | `path_provider`       | All                           |
| Runtime permissions   | `permission_handler`  | Android, iOS                  |
| LAN info / interfaces | `network_info_plus`   | All                           |
| BLE central (send)    | `flutter_blue_plus`   | Android, iOS, macOS, Windows  |
| BLE peripheral (recv) | `ble_peripheral`      | Android, iOS, macOS, Windows  |
| WebSocket             | `socket_io_client`    | All                           |
| HTTP                  | `http`                | All                           |

### Build-time configuration

Production URLs are injected via Dart defines so the same binary can target dev or prod:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 \
  --dart-define=WS_URL=https://files.example.com
```

Defaults live in `mobile/lib/config/api_config.dart` (Android emulator `10.0.2.2:5000`).

### Cross-platform behaviour

- **Web cannot** open raw TCP sockets or act as a BLE peripheral; the Web SPA therefore only exposes the relay path for direct transfers.
- **Desktop (Windows/Linux)** uses the same Flutter code; LAN is fully supported. Windows BLE receive (GATT server) is wired; Windows BLE *send* is gated until validated against real hardware (see README §Release Scope).

## 7. Transfer Modes

### Mode 1: Pickup Code / Direct Link

**Flow:**
1. Sender uploads file via `POST /api/v1/files/upload` (multipart).
2. Backend stores file in configured storage (local FS or S3), generates a 6-char pickup code, returns `{ file_id, pickup_code, download_url, expires_at }`.
3. Sender shares the pickup code or direct link.
4. Receiver calls `GET /api/v1/files/pickup/:code` to get metadata, then `GET /api/v1/files/download/:id` to stream the file.
5. Download is speed-limited per user group, traffic is counted against the receiver's quota.

**Lifecycle:**
- File is **active** until `expires_at` (retention period per user group).
- After expiration, enters **7-day redemption grace period** (visible to admins, not downloadable by normal users).
- After grace period, **physically deleted** by the cleanup job.

**Backend involvement:** Full (upload, storage, download).

---

### Mode 2: Same-Account Relay

**Flow:**
1. Sender creates a transfer session via `POST /api/v1/transfers` with `{ mode: "relay", target_device_id, file_metadata }`.
2. Backend emits `transfer.request` event to the target device over WebSocket.
3. Receiver accepts via `PUT /api/v1/transfers/:id/accept` or WebSocket `transfer.accept` event.
4. Sender streams file chunks as base64 via WebSocket `transfer.data` events.
5. Backend relays chunks in real time to the receiver's WebSocket connection.
6. Receiver assembles chunks and saves the file locally.
7. Backend enforces quota on the receiver's download traffic but **does not persist the file**.

**Backend involvement:** Signaling + real-time relay (no storage).

**Implementation:**
- `backend/app/ws/events.py` — `TransferNamespace` handles `on_transfer_data`, relays to target device room.
- `web/src/pages/TransferPage.tsx` — streams file as base64 chunks, assembles received chunks into Blob.
- `mobile/lib/services/websocket_service.dart` + `mobile/lib/screens/transfer_screen.dart` — same pattern in Flutter.

---

### Mode 3: LAN Transfer

**Flow:**
1. Sender broadcasts UDP discovery packet on port **42424** with `{ type: "discover", device_id, device_name }`.
2. Receiver (listening on UDP 42424) responds with `{ type: "response", device_id, device_name, ip }`.
3. Sender opens TCP connection to receiver's IP on port **42425**.
4. Sender sends JSON header `{ file_name, file_size }` + null terminator, then raw file bytes.
5. Receiver reads header, allocates buffer, reads file data, saves locally.

**Backend involvement:** None (peer-to-peer).

**Implementation:**
- `mobile/lib/services/lan_service.dart` — UDP broadcast/listen + TCP send/receive.
- **Not available on Web** (browsers cannot open raw TCP sockets).

---

### Mode 4: Bluetooth Transfer

**Flow:**
1. Receiver starts BLE advertising as a GATT peripheral with Lexy service UUID `12345678-1234-5678-1234-56789abcdef0`.
2. Sender scans for BLE devices, finds Lexy service, connects.
3. Sender writes JSON header `{ file_name, file_size }` + null terminator to RX characteristic, then file data in 512-byte chunks, then `{ type: "eot" }` signal.
4. Receiver (GATT server) receives writes via callback, parses protocol, assembles file, saves locally.

**Backend involvement:** None (peer-to-peer).

**Implementation:**
- `mobile/lib/services/bluetooth_service.dart`:
  - **Central (send)**: `flutter_blue_plus` — scan, connect, write to characteristic.
  - **Peripheral (receive)**: `ble_peripheral` v2.4.0 — advertise, accept writes via callback.
- **Not available on Web** (browsers cannot act as BLE peripheral).
- **Throughput**: ~2-20 KB/s, impractical for large files (use LAN or relay instead).

---

### Mode selection matrix

| Mode       | Backend storage | Backend relay | Peer-to-peer | Web support | Quota enforcement |
|------------|-----------------|---------------|--------------|-------------|-------------------|
| Pickup     | Yes             | No            | No           | Yes         | Speed + traffic   |
| Relay      | No              | Yes           | No           | Yes         | Traffic (receiver)|
| LAN        | No              | No            | Yes          | No          | None              |
| Bluetooth  | No              | No            | Yes          | No          | None              |

## 8. Data Models

### Core entities (SQLAlchemy models in `backend/app/models/`)

**User** (`user.py`)
```python
- id: int (PK)
- username: str (unique, indexed)
- email: str (unique, indexed)
- password_hash: str
- user_group: enum('anonymous', 'normal', 'vip', 'admin')
- is_banned: bool
- created_at, updated_at: datetime
- devices: relationship → Device[]
- files: relationship → File[]
```

**Device** (`device.py`)
```python
- id: int (PK)
- user_id: int (FK → User)
- device_id: str (unique, client-generated UUID)
- name: str
- device_type: enum('web', 'android', 'ios', 'windows', 'linux')
- platform: str
- is_online: bool
- last_seen_at: datetime
- created_at: datetime
```

**File** (`file.py`)
```python
- id: int (PK)
- user_id: int (FK → User)
- filename: str
- file_size: int (bytes)
- mime_type: str
- storage_path: str (relative path in storage backend)
- pickup_code: str (unique, 6-char, indexed)
- download_count: int
- status: enum('active', 'expired', 'deleted')
- expires_at: datetime
- grace_period_ends_at: datetime (expires_at + 7 days)
- created_at, updated_at: datetime
```

**Transfer** (`transfer.py`)
```python
- id: int (PK)
- sender_device_id: int (FK → Device)
- receiver_device_id: int (FK → Device)
- transfer_mode: enum('relay', 'lan', 'bluetooth')
- file_name: str
- file_size: int
- status: enum('pending', 'accepted', 'in_progress', 'completed', 'rejected', 'cancelled', 'failed')
- created_at, completed_at: datetime
```

**GroupQuota** (`quota.py`)
```python
- id: int (PK)
- group_name: enum('anonymous', 'normal', 'vip', 'admin')
- download_speed_limit: int (bytes/sec, NULL = unlimited)
- max_file_size: int (bytes, NULL = unlimited)
- max_storage: int (bytes, NULL = unlimited)
- traffic_quota: int (bytes, NULL = unlimited)
- traffic_period: enum('day', 'month')
- max_retention_seconds: int (NULL = unlimited)
```

### Anonymous user consolidation

Anonymous users are identified by **IP address OR device fingerprint** (union match). The `auth_service.get_or_create_anonymous_user()` method:
1. Checks for existing anonymous user with matching IP.
2. If not found, checks for matching device fingerprint.
3. If neither match, creates a new anonymous user record.
4. Returns a JWT token tied to that anonymous user.

This allows the same anonymous user to be recognized across sessions from the same IP or device.

## 9. Authentication & Authorization

### JWT token flow

**Access tokens** (15 min TTL):
- Issued on login/register/refresh.
- Stored in memory (web) or secure storage (mobile).
- Sent in `Authorization: Bearer <token>` header.
- Validated by Flask-JWT-Extended middleware.

**Refresh tokens** (30 day TTL):
- Issued alongside access tokens.
- Stored in Redis with key `refresh_token:<jti>`.
- Used to obtain new access tokens via `POST /api/v1/auth/refresh`.
- Revoked on logout (removed from Redis).

**Token revocation**:
- JWT blacklist is implemented via Redis.
- On logout, the refresh token JTI is deleted from Redis.
- `@jwt.token_in_blocklist_loader` checks Redis for revoked tokens.

### Anonymous users

- Web clients can access the platform without registration.
- `POST /api/v1/auth/anonymous` with `{ device_id, fingerprint }` returns a JWT tied to an anonymous user.
- Anonymous users are consolidated by IP OR device fingerprint (see §8).
- Anonymous users have the most restrictive quotas (3 MB/s, 500 MB max file, 15 min retention).

### Authorization levels

| User Group | Access                                                                 |
|------------|------------------------------------------------------------------------|
| anonymous  | Upload/download files, pickup codes. No device registration.           |
| normal     | All anonymous + device registration, same-account relay, LAN, BLE.     |
| vip        | All normal + higher quotas (15 MB/s, 5 GB files, 5-day retention).    |
| admin      | All vip + admin console access, unlimited quotas, user/file management.|

**Admin-only endpoints** are protected by `@admin_required` decorator (checks `user.user_group == 'admin'`).

### CORS policy

- Development: `CORS_ORIGINS=*` (permissive for local testing).
- Production: Must explicitly list allowed origins (e.g., `https://files.example.com`).
- Wildcard CORS is rejected at boot in production mode.

## 10. Storage Architecture

### Pluggable backend interface

The storage layer is abstracted behind `StorageBackend` (`backend/app/storage/base.py`):

```python
class StorageBackend(ABC):
    @abstractmethod
    def save(self, file_stream, path: str) -> int:
        """Save file, return size in bytes"""
    
    @abstractmethod
    def open(self, path: str):
        """Return file-like object for streaming"""
    
    @abstractmethod
    def delete(self, path: str) -> None:
        """Remove file from storage"""
    
    @abstractmethod
    def size(self, path: str) -> int:
        """Get file size in bytes"""
```

### Local filesystem (`storage/local.py`)

- Files stored under `UPLOAD_FOLDER` (default `./uploads`).
- Path structure: `{user_id}/{file_id}_{filename}`.
- Production: mount a dedicated volume at `/var/data/lexy_files/uploads`.

### S3-compatible storage (`storage/s3.py`)

- Uses `boto3` to interact with S3 or S3-compatible services (R2, MinIO, Backblaze B2, etc.).
- Configuration via environment variables:
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
  - `AWS_S3_BUCKET`, `AWS_S3_PREFIX` (default `uploads`)
  - `AWS_S3_ENDPOINT_URL` (for non-AWS S3 services)
- Path structure: `{prefix}/{user_id}/{file_id}_{filename}`.

### Selection

Set `STORAGE_BACKEND=local` or `STORAGE_BACKEND=s3` in `.env`. The backend is instantiated once at app boot and injected into services.

---

## 11. Real-Time Communication

### WebSocket (Socket.IO)

**Server**: Flask-SocketIO with eventlet worker (required for async I/O).

**Namespace**: `/` (default namespace, custom `TransferNamespace` in `backend/app/ws/events.py`).

**Events**:

| Direction | Event                | Payload                                      | Purpose                                    |
|-----------|----------------------|----------------------------------------------|--------------------------------------------|
| C→S       | `connect`            | —                                            | Client connects, joins device room         |
| C→S       | `disconnect`         | —                                            | Client disconnects, leaves room            |
| C→S       | `transfer.accept`    | `{ transfer_id }`                            | Accept incoming transfer                   |
| C→S       | `transfer.reject`    | `{ transfer_id }`                            | Reject incoming transfer                   |
| C→S       | `transfer.data`      | `{ transfer_id, chunk, chunk_index, total }` | Stream file chunk (base64)                 |
| C→S       | `transfer.complete`  | `{ transfer_id }`                            | Signal transfer finished                   |
| C→S       | `transfer.cancel`    | `{ transfer_id }`                            | Cancel in-progress transfer                |
| S→C       | `transfer.request`   | `{ transfer_id, sender_device, file_name, file_size }` | Notify receiver of incoming transfer |
| S→C       | `transfer.accepted`  | `{ transfer_id }`                            | Notify sender that receiver accepted       |
| S→C       | `transfer.rejected`  | `{ transfer_id }`                            | Notify sender that receiver rejected       |
| S→C       | `transfer.progress`  | `{ transfer_id, bytes_transferred, total }`  | Progress update                            |
| S→C       | `transfer.complete`  | `{ transfer_id }`                            | Transfer finished                          |
| S→C       | `device.online`      | `{ device_id, device_name }`                 | Another device came online                 |
| S→C       | `device.offline`     | `{ device_id }`                              | Another device went offline                |

**WebRTC signaling** (for future LAN NAT traversal):
- `webrtc_offer`, `webrtc_answer`, `webrtc_ice_candidate` events relay SDP/ICE between device rooms.
- Not currently used by LAN transfer (which uses direct UDP/TCP), but wired for future enhancement.

### Device presence

- On WebSocket connect, device is marked `is_online=True` in Redis (`device:{device_id}:online`).
- On disconnect, marked offline.
- Heartbeat via `device.heartbeat` event (optional, extends TTL).
- Other devices in the same user account are notified via `device.online` / `device.offline` events.

---

## 12. Deployment Architecture

### Production stack

```
┌─────────────────────────────────────────────────────────────┐
│ Internet (HTTPS :443)                                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  Nginx (reverse proxy)│
              │  - TLS termination    │
              │  - Static serving     │
              │  - WebSocket upgrade  │
              └──────────┬───────────┘
                         │
         ┌───────────────┼───────────────┐
         │ /             │ /api/         │ /socket.io/
         ▼               ▼               ▼
  ┌────────────┐  ┌─────────────────────────────┐
  │ web/dist/  │  │ Gunicorn + eventlet :5000   │
  │ (static)   │  │ (Flask app)                 │
  └────────────┘  └──────────┬──────────────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌──────────┐  ┌──────────┐  ┌──────────────┐
        │ MySQL    │  │ Redis    │  │ Storage      │
        │ :3306    │  │ :6379    │  │ (local/S3)   │
        └──────────┘  └──────────┘  └──────────────┘
```

### Systemd service

`docs/lexy-files-backend.service` provides a production-ready systemd unit:
- Runs as dedicated `lexy` user.
- Activates Python venv.
- Starts Gunicorn with eventlet worker.
- Auto-restart on failure.
- Logs to journald.

### Deployment checklist

See `docs/release-checklist.md` for the full gate. Key items:
1. Backend tests pass (`pytest -q`).
2. Web build succeeds (`npm run build`).
3. Flutter analyze clean (`flutter analyze`).
4. Production secrets set (no defaults).
5. CORS restricted (no wildcards).
6. Database migrations applied (`flask db upgrade`).
7. Storage backend validated (writable path or reachable S3 bucket).
8. Manual device testing for relay, LAN, Bluetooth on target platforms.

### Rollback procedure

1. Stop backend service (`systemctl stop lexy-files-backend`).
2. Restore previous backend code + web dist.
3. Downgrade database if migration was applied (`flask db downgrade`).
4. Restore storage from backup if needed.
5. Restart service.

### Monitoring

- **Logs**: `journalctl -u lexy-files-backend -f`
- **Health check**: `GET /api/v1/health` (returns `{ status: "ok" }`)
- **Metrics**: Not implemented (future: Prometheus exporter for transfer counts, quota usage, active connections)

---

## Summary

Lexy Files is a production-ready, multi-platform file transfer system with:
- **4 transfer modes** (pickup, relay, LAN, Bluetooth) optimized for different scenarios
- **Single backend** (Flask + MySQL + Redis) serving all clients
- **3 client codebases** (React web, Flutter mobile/desktop) with maximum code reuse
- **Quota enforcement** per user group (speed, storage, traffic, retention)
- **Admin console** for user/device/file management
- **Pluggable storage** (local FS or S3-compatible)
- **Real-time relay** via WebSocket (Socket.IO)
- **Peer-to-peer** LAN and Bluetooth for local transfers
- **81 passing tests**, deployment docs, release checklist, systemd service

For setup instructions, see `docs/setup.md`. For deployment, see `DEPLOY.md`. For API contracts, see `memory/api-contracts.md`.
