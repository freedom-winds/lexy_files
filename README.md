# Lexy Files

Lexy Files is a four-deliverable file transfer platform:
Backend, Web, Mobile (Android/iOS), and Desktop (Windows/Linux).

Production releases are built around one HTTPS domain, for example
`https://files.example.com`, with Nginx in front of the Flask API and the Web
static bundle.

## Release Scope

| Capability | Backend | Web | Mobile Android/iOS | Desktop Windows/Linux |
|---|---:|---:|---:|---:|
| Pickup-code upload/download | Yes | Yes | Yes | Yes |
| Anonymous upload/download | Yes | Yes | Yes | Yes |
| Registered account flows | Yes | Yes | Yes | Yes |
| Same-account relay | Yes | Yes | Yes | Yes |
| LAN transfer | Not required | No | Yes | Yes |
| Bluetooth transfer | Not required | No | Yes | Partial |
| Admin console | Yes | Yes | No | No |

Web intentionally does not claim native LAN or Bluetooth. Mobile is the fully
supported Bluetooth sender/receiver. Desktop supports LAN; Windows Bluetooth
state detection and receive mode are present, but direct Windows Bluetooth send
is gated until a native BLE central implementation is added and device-tested.

## Project Layout

```text
backend/  Flask REST API, Socket.IO relay, migrations, storage backends
web/      React + TypeScript + Vite client and admin console
mobile/   Flutter app for Android, iOS, Windows, and Linux
docs/     Release checklist and supporting docs
DEPLOY.md Four-end release guide
```

## Backend Quick Start

```bash
cd backend
python -m venv venv
source venv/Scripts/activate  # Windows Git Bash
pip install -r requirements.txt
cp .env.example .env
flask db upgrade
flask run --port 5000
```

The API is available at `http://localhost:5000/api/v1/` in development.

Production must set non-default `SECRET_KEY`, `JWT_SECRET_KEY`, and explicit
`CORS_ORIGINS`; wildcard CORS is rejected in production. Storage supports
`STORAGE_BACKEND=local` and `STORAGE_BACKEND=s3`.

## Web Quick Start

```bash
cd web
npm install
npm run dev
```

For production:

```bash
VITE_API_BASE_URL=https://files.example.com/api/v1
VITE_SOCKET_URL=https://files.example.com
npm run lint
npx tsc --noEmit
npm run build
```

The production artifact is `web/dist/`.

## Flutter Quick Start

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

Release builds must inject the backend URLs:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 \
  --dart-define=WS_URL=https://files.example.com

flutter build windows --release \
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 \
  --dart-define=WS_URL=https://files.example.com
```

See [DEPLOY.md](DEPLOY.md) for Android App Bundle, iOS, Windows, and Linux
packaging commands.

## Verification

Required automated release checks:

```bash
cd backend && python -m pytest -q
cd backend && python -m flake8 app tests --max-line-length=120
cd backend && flask db upgrade && flask db downgrade
cd web && npm run lint && npx tsc --noEmit && npm run build
cd mobile && flutter analyze && flutter test
```

Device-dependent relay, LAN, and Bluetooth acceptance is tracked manually in
[docs/release-checklist.md](docs/release-checklist.md).
