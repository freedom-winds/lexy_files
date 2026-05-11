# Setup and Bootstrap Guide

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Python | 3.11+ | Backend server |
| Node.js | 18+ | Web client build tooling |
| npm | 9+ | Web dependency management |
| Flutter | 3.x | Mobile and desktop clients |
| MySQL | 8.0+ | Production database |
| Redis | 7.0+ | Token blacklist, rate limiting (optional for dev) |

## 1. Clone the Repository

```bash
git clone <repo-url> lexy_files
cd lexy_files
```

## 2. Backend Setup

### 2.1 Python Environment

```bash
cd backend
python -m venv venv

# Activate
source venv/Scripts/activate   # Windows Git Bash
source venv/bin/activate       # Linux / macOS

# Install dependencies
pip install -r requirements.txt
```

If behind a corporate proxy or in China, use a mirror:
```bash
pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com
```

### 2.2 Database Setup

**For development (SQLite -- no setup needed):**
Tests use SQLite in-memory automatically. For quick local development, you can set:
```bash
export SQLALCHEMY_DATABASE_URI="sqlite:///dev.db"
```

**For production (MySQL):**

```sql
CREATE DATABASE lexy_files CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'lexy'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT ALL PRIVILEGES ON lexy_files.* TO 'lexy'@'localhost';
FLUSH PRIVILEGES;
```

Set environment variables:
```bash
export MYSQL_HOST=localhost
export MYSQL_PORT=3306
export MYSQL_USER=lexy
export MYSQL_PASSWORD=your_secure_password
export MYSQL_DATABASE=lexy_files
```

### 2.3 Redis Setup (Optional)

Redis is used for JWT token blacklisting. Without Redis, token revocation (logout) will not work, but everything else functions normally.

```bash
# Install Redis (varies by OS)
# Ubuntu: sudo apt install redis-server
# macOS:  brew install redis
# Windows: Use WSL2 or download from https://github.com/microsoftarchive/redis/releases

# Default config works
export REDIS_URL=redis://localhost:6379/0
```

### 2.4 Initialize and Run

```bash
cd backend

# Initialize database tables
flask db upgrade

# Run development server
flask run --port 5000
```

The API is now available at `http://localhost:5000/api/v1/`.

Default group quotas are seeded automatically on first startup.

### 2.5 Verify Backend

```bash
# Run test suite
python -m pytest tests/ -v

# Expected: 81 tests, all passing
```

## 3. Web Client Setup

```bash
cd web

# Install dependencies
npm install

# Start development server
npm run dev
# Runs on http://localhost:3000, proxies /api to localhost:5000
```

### Production Build

```bash
VITE_API_BASE_URL=https://files.example.com/api/v1
VITE_SOCKET_URL=https://files.example.com
npm run build
# Output in web/dist/
# Serve with any static file server (nginx, caddy, etc.)
```

### Type Checking

```bash
npx tsc --noEmit
```

## 4. Flutter App Setup

### 4.1 Flutter SDK

Install Flutter following https://docs.flutter.dev/get-started/install

Verify:
```bash
flutter doctor
```

### 4.2 Get Dependencies

```bash
cd mobile
flutter pub get
```

### 4.3 Configure API URL

The default development API URL is `http://10.0.2.2:5000/api/v1`, which works
for Android emulators. For other devices, pass URLs at run/build time:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://<host-or-lan-ip>:5000/api/v1 \
  --dart-define=WS_URL=http://<host-or-lan-ip>:5000
```

Use `localhost` for iOS simulator and Windows/Linux desktop when the backend is
running on the same machine. Use your LAN IP for physical Android/iOS devices.

### 4.4 Run

```bash
# Run on connected device/emulator
flutter run

# Run on specific platform
flutter run -d chrome      # Web (experimental)
flutter run -d windows     # Windows desktop
flutter run -d <device_id> # Specific device
```

### 4.5 Build

```bash
# Android APK
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Android release APK (requires signing)
flutter build apk --release \
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 \
  --dart-define=WS_URL=https://files.example.com

# Android release app bundle
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 \
  --dart-define=WS_URL=https://files.example.com

# Windows desktop
flutter build windows --debug
# Output: build/windows/x64/runner/Debug/

# Linux desktop
flutter build linux --release \
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 \
  --dart-define=WS_URL=https://files.example.com

# iOS (requires macOS + Xcode)
flutter build ios --release \
  --dart-define=API_BASE_URL=https://files.example.com/api/v1 \
  --dart-define=WS_URL=https://files.example.com
```

### 4.6 Verify

```bash
flutter analyze   # Static analysis (expect 0 issues)
flutter test      # Run tests (expect 1 passing)
```

## 5. Running Everything Together

1. Start the backend: `cd backend && flask run --port 5000`
2. Start the web dev server: `cd web && npm run dev`
3. Run the Flutter app: `cd mobile && flutter run`

The web client at `http://localhost:3000` proxies API calls to the backend automatically.

The Flutter app connects to the backend URL supplied by `--dart-define`, or to
the development default in `api_config.dart` when no define is supplied.

## 6. Creating an Admin User

After starting the backend, register a normal user, then promote them to admin:

```bash
# Using Flask shell
cd backend
flask shell
>>> from app.extensions import db
>>> from app.models.user import User
>>> u = User.query.filter_by(username='yourusername').first()
>>> u.user_group = 'admin'
>>> db.session.commit()
```

Or via the API (if you already have an admin):
```bash
curl -X PUT http://localhost:5000/api/v1/admin/users/<user_id>/group \
  -H "Authorization: Bearer <admin_token>" \
  -H "Content-Type: application/json" \
  -d '{"group": "admin"}'
```

## Troubleshooting

### Backend won't start
- Check MySQL is running and credentials are correct
- Check port 5000 is not in use
- Try `flask db upgrade` if you get table-not-found errors

### Web proxy errors
- Ensure backend is running on port 5000
- Check `web/vite.config.ts` proxy settings

### Flutter can't connect to API
- Android emulator uses `10.0.2.2` to reach host machine
- Check firewall isn't blocking port 5000
- Try `adb reverse tcp:5000 tcp:5000` for physical Android devices

### pip install fails
- Try `pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org -r requirements.txt`
- Or use Aliyun mirror (see section 2.1)
