# Lexy Files

A cross-device file transfer platform supporting Web, Android, iOS, and Windows Desktop. Users can transfer files via pickup codes, same-account device relay, LAN, or Bluetooth.

## Features

- **Pickup Code Transfer** -- Upload a file, get a 6-character code, recipient downloads with that code
- **Same-Account Device Relay** -- Real-time streaming between devices logged into the same account (API defined, WebSocket relay in progress)
- **LAN Transfer** -- Peer-to-peer on the same network (planned)
- **Bluetooth Transfer** -- Direct device-to-device (planned)
- **User Group Quotas** -- Speed, storage, traffic, and retention limits per group (anonymous, normal, vip, admin)
- **Anonymous Access** -- Web allows upload/download without registration, identified by IP or device fingerprint
- **Admin Console** -- Web-based management for users, files, groups, and system stats
- **File Lifecycle** -- Active -> expired -> 7-day redemption -> physical deletion with automatic cleanup

## Architecture

```
lexy_files/
  backend/     Flask REST API + WebSocket (Python 3.11)
  web/         React + TypeScript + Vite + Tailwind (Web client + Admin console)
  mobile/      Flutter (Android, iOS, Windows Desktop)
  memory/      Project documentation and decision records
```

**Stack decisions:**
- Flask + MySQL + Redis for the backend (required by spec)
- React + TypeScript for the web client (fast loads, SEO, anonymous access)
- Flutter for native clients (maximum code reuse across Android/iOS/Desktop)
- JWT authentication with refresh tokens
- REST API at `/api/v1/` with WebSocket at `/ws`

## Quick Start

### Prerequisites

- Python 3.11+
- Node.js 18+ and npm
- Flutter 3.x (for mobile/desktop builds)
- MySQL 8.0+ (production) or SQLite (development/testing)
- Redis (optional, for token revocation)

### Backend

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/Scripts/activate   # Windows Git Bash
# source venv/bin/activate     # Linux/macOS

# Install dependencies
pip install -r requirements.txt

# Configure environment (optional -- defaults work for development)
cp .env.example .env  # edit as needed

# Initialize database
flask db upgrade

# Run the server
flask run --port 5000
```

The API will be available at `http://localhost:5000/api/v1/`.

### Web Client

```bash
cd web

# Install dependencies
npm install

# Start dev server (proxies /api to localhost:5000)
npm run dev
```

Open `http://localhost:3000` in your browser.

To build for production:
```bash
npm run build   # outputs to web/dist/
```

### Flutter App (Android / iOS / Windows)

```bash
cd mobile

# Get dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Build debug APK
flutter build apk --debug

# Build Windows desktop
flutter build windows --debug
```

**Note:** The Flutter app connects to `http://10.0.2.2:5000/api/v1` by default (Android emulator loopback). Update `lib/config/api_config.dart` for other environments.

## API Overview

| Endpoint Group | Prefix | Auth | Description |
|---|---|---|---|
| Auth | `/api/v1/auth/` | Mixed | Register, login, refresh, logout, anonymous, /me |
| Files | `/api/v1/files/` | Mixed | Upload, download, pickup by code, list, delete |
| Devices | `/api/v1/devices/` | Required | Register, list, unregister, heartbeat |
| Transfers | `/api/v1/transfers/` | Required | Initiate, accept, reject, cancel transfers |
| Admin | `/api/v1/admin/` | Admin only | User/file/group management, system stats |

### Error Response Format

All errors follow a consistent envelope:
```json
{
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "Daily download traffic quota exceeded",
    "details": {}
  }
}
```

### User Groups and Limits

| Group | Download Speed | Max File | Total Storage | Traffic Quota | Retention |
|---|---|---|---|---|---|
| anonymous | 3 MB/s | 500 MB | 2 GB | 1 GB/day | 15 min |
| normal | 8 MB/s | 2 GB | 10 GB | 5 GB/day | 6 hours |
| vip | 15 MB/s | 5 GB | 40 GB | 500 GB/month | 5 days |
| admin | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited |

## Testing

### Backend Tests

```bash
cd backend
source venv/Scripts/activate
python -m pytest tests/ -v
```

**81 tests** covering:
- Auth service (registration, login, anonymous, token lifecycle)
- File service (upload, download, pickup codes, expiration, deletion)
- Quota service (limits, enforcement, traffic tracking)
- Cleanup service (expiration, redemption, physical deletion)
- **Integration tests** (full API flow: register -> login -> upload -> pickup -> download -> delete)

### Flutter Tests

```bash
cd mobile
flutter test
flutter analyze  # static analysis, 0 issues
```

### Web Build Verification

```bash
cd web
npx tsc --noEmit   # type checking
npm run build       # production build
```

## Project Structure

### Backend (`backend/`)

```
app/
  __init__.py          Application factory
  extensions.py        Flask extension singletons
  api/                 Blueprint route handlers
    auth.py            Authentication endpoints
    files.py           File upload/download/listing
    devices.py         Device management
    transfers.py       Transfer session management
    admin.py           Admin console API
  models/              SQLAlchemy models
    user.py            User model with groups and quotas
    file.py            File model with lifecycle states
    device.py          Device registration
    transfer.py        Transfer session tracking
    quota.py           Group quotas and traffic usage
  services/            Business logic layer
    auth_service.py    Registration, auth, JWT, anonymous users
    file_service.py    File operations, pickup codes, streaming
    quota_service.py   Quota checking and enforcement
    cleanup_service.py Scheduled file cleanup
  utils/
    errors.py          Error classes and handlers
    helpers.py         Utility functions
    constants.py       Configuration constants
config.py              Environment-based configuration
tests/                 pytest test suite
```

### Web Client (`web/`)

```
src/
  App.tsx              Routes configuration
  main.tsx             Entry point with providers
  components/          Reusable UI components
    Layout.tsx         App shell with navigation
    FileUpload.tsx     Drag-and-drop file uploader
    PickupCodeInput.tsx  6-digit code entry
    ProtectedRoute.tsx   Auth guard
    AdminRoute.tsx       Admin-only guard
  pages/               Route pages
    HomePage.tsx       Upload + pickup code entry
    LoginPage.tsx      Login form
    RegisterPage.tsx   Registration form
    PickupPage.tsx     File info + download by code
    MyFilesPage.tsx    User's file dashboard
    admin/             Admin console pages
  providers/
    AuthProvider.tsx   Auth context with JWT management
  lib/
    api.ts             Axios instance with interceptors
    utils.ts           Error parsing helpers
```

### Flutter App (`mobile/`)

```
lib/
  main.dart            App entry, providers, routing
  config/
    api_config.dart    API endpoint URL builders
    theme.dart         Material 3 theme definition
  models/
    user.dart          User model
    file_info.dart     File metadata models
  services/
    api_service.dart   Dio HTTP client with JWT interceptor
  providers/
    auth_provider.dart Auth state management
  screens/
    login_screen.dart
    register_screen.dart
    home_screen.dart      Upload + pickup code entry
    pickup_screen.dart    File download by code
    my_files_screen.dart  File management
  widgets/
    file_size_text.dart   Formatting utilities
```

## Configuration

### Backend Environment Variables

| Variable | Default | Description |
|---|---|---|
| `SECRET_KEY` | `dev-secret-key-...` | Flask secret key |
| `JWT_SECRET_KEY` | `dev-jwt-secret-...` | JWT signing key |
| `MYSQL_HOST` | `localhost` | MySQL host |
| `MYSQL_PORT` | `3306` | MySQL port |
| `MYSQL_USER` | `lexy` | MySQL username |
| `MYSQL_PASSWORD` | `lexy_password` | MySQL password |
| `MYSQL_DATABASE` | `lexy_files` | MySQL database name |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection URL |
| `UPLOAD_FOLDER` | `./uploads` | File storage directory |
| `MAX_CONTENT_LENGTH` | `5368709120` (5 GB) | Max upload size |
| `SCHEDULER_ENABLED` | `true` | Enable background cleanup |
| `CLEANUP_INTERVAL_MINUTES` | `30` | Cleanup task interval |

### Web Proxy Configuration

The Vite dev server proxies `/api` requests to `http://localhost:5000`. See `web/vite.config.ts`.

### Flutter API Configuration

Edit `mobile/lib/config/api_config.dart` to change the backend URL:
- Android emulator: `http://10.0.2.2:5000/api/v1`
- iOS simulator: `http://localhost:5000/api/v1`
- Physical device: Use your machine's LAN IP

## Development Status

### Completed
- Backend API with all endpoints, services, and 81 tests
- Web client with all pages, admin console, and production build
- Flutter app for Android/iOS/Windows with all core screens
- Pickup code file transfer (full flow)
- User group quota enforcement
- File lifecycle management
- Anonymous user support

### In Progress
- Platform build verification (Android APK, Windows EXE)

### Planned
- Same-account device relay (WebSocket streaming)
- LAN peer-to-peer transfer
- Bluetooth transfer
- Device registration UI
- Push notifications

## License

Private project.
