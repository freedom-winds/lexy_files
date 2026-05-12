# Lexy Files Release Guide

This guide is the release source of truth for the four supported deliverables:
Backend, Web, Mobile (Android/iOS), and Desktop (Windows/Linux).

Production baseline: one HTTPS domain behind Nginx, for example
`https://files.example.com`.

## Capability Matrix

| Capability | Backend | Web | Mobile Android/iOS | Desktop Windows/Linux |
|---|---:|---:|---:|---:|
| Pickup-code upload/download | Yes | Yes | Yes | Yes |
| Registered account flows | Yes | Yes | Yes | Yes |
| Anonymous upload/download | Yes | Yes | Yes | Yes |
| Same-account relay | Yes | Yes | Yes | Yes |
| LAN transfer | API not required | Not supported | Yes | Yes |
| Bluetooth transfer | API not required | Not supported | Yes | Partial |
| Admin console | Yes | Yes | No | No |

Web does not claim native LAN or Bluetooth support. Mobile is the fully
supported Bluetooth sender/receiver. Desktop supports LAN; Windows Bluetooth
state detection and receive mode are present, but direct Windows Bluetooth send
is gated until a native BLE central implementation is added and device-tested.

## 1. Backend

### Required runtime

- Python 3.11+
- MySQL 8+
- Redis 7+
- Nginx with HTTPS
- Local disk storage or S3-compatible object storage

### Environment

Create `backend/.env` from `backend/.env.example` and set production values:

```env
FLASK_ENV=production
SECRET_KEY=<64-char-random-secret>
JWT_SECRET_KEY=<different-64-char-random-secret>

MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=lexy
MYSQL_PASSWORD=<strong-password>
MYSQL_DATABASE=lexy_files

REDIS_URL=redis://localhost:6379/0

STORAGE_BACKEND=local
UPLOAD_FOLDER=/var/data/lexy_files/uploads

# Or use S3-compatible storage
# STORAGE_BACKEND=s3
# AWS_ACCESS_KEY_ID=<secret>
# AWS_SECRET_ACCESS_KEY=<secret>
# AWS_REGION=us-east-1
# AWS_S3_BUCKET=lexy-files
# AWS_S3_PREFIX=uploads
# AWS_S3_ENDPOINT_URL=https://s3.example.com

CORS_ORIGINS=https://files.example.com
SOCKETIO_CORS_ORIGINS=https://files.example.com
MAX_CONTENT_LENGTH=5368709120
SCHEDULER_ENABLED=true
CLEANUP_INTERVAL_MINUTES=30
```

Production startup intentionally fails if default secrets or wildcard CORS are
used.

### Install, migrate, verify

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

flask db upgrade
python -m pytest -q
python -m flake8 app tests --max-line-length=120
```

### Run with Gunicorn

```bash
gunicorn \
  --worker-class eventlet \
  --workers 1 \
  --bind 127.0.0.1:5000 \
  --timeout 120 \
  "app:create_app('production')"
```

Use one eventlet worker for Socket.IO relay. Scale with more instances behind a
proper Socket.IO message queue if needed.

## 2. Web

### Environment

Create `web/.env.production`:

```env
VITE_API_BASE_URL=https://files.example.com/api/v1
VITE_SOCKET_URL=https://files.example.com
```

### Build and verify

```bash
cd web
npm ci
npm run lint
npx tsc --noEmit
npm run build
```

Deploy `web/dist/` to the Nginx static root.

## 3. Mobile (Android/iOS)

All mobile release builds must inject the production backend URL:

```bash
--dart-define=API_BASE_URL=https://files.example.com/api/v1 \
--dart-define=WS_URL=https://files.example.com
```

### Android

Create `mobile/android/key.properties` from
`mobile/android/key.properties.example`; do not commit real keys.

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --release \
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 \
  --dart-define=WS_URL=https://files.example.com
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 \
  --dart-define=WS_URL=https://files.example.com
```

Outputs:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

### iOS

Requires macOS, Xcode, CocoaPods, and an Apple Developer team.

```bash
cd mobile
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release \
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 \
  --dart-define=WS_URL=https://files.example.com
```

Archive and export from Xcode Organizer for TestFlight/App Store or Ad Hoc
distribution.

## 4. Desktop (Windows/Linux)

Desktop uses the same Flutter app and the same production URL build arguments.

### Windows

```powershell
cd mobile
flutter pub get
flutter build windows --release `
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 `
  --dart-define=WS_URL=https://files.example.com
```

Output:

`build/windows/x64/runner/Release/`

Distribute that folder as a signed ZIP, or build an installer with Inno Setup.

### Linux

Install Flutter Linux desktop prerequisites, then:

```bash
cd mobile
flutter pub get
flutter build linux --release \
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 \
  --dart-define=WS_URL=https://files.example.com
```

Output:

`build/linux/x64/release/bundle/`

Package the bundle as a tarball, `.deb`, or AppImage according to your release
channel.

## Nginx

```nginx
upstream lexy_backend {
    server 127.0.0.1:5000;
}

server {
    listen 443 ssl http2;
    server_name files.example.com;

    client_max_body_size 5g;

    root /var/www/lexy_files;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://lexy_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    location /socket.io/ {
        proxy_pass http://lexy_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 3600s;
    }
}
```

## Release Gate

Before publishing, all automated checks in `docs/release-checklist.md` must pass
and the manual matrix must be completed on real devices for relay, LAN, and the
supported Bluetooth paths.

## Rollback

1. Stop the backend service.
2. Restore the previous backend artifact and Web `dist/`.
3. Run `flask db downgrade` only if the release applied a new migration.
4. Restore uploads or S3 objects from backup if storage changes were involved.
5. Restart backend and reload Nginx.
