# Lexy Files — Deployment Guide

This document covers end-to-end deployment for every component of Lexy Files: backend server, desktop client, Android APK, and iOS app.

---

## Table of Contents

- [Part 1: Backend Service Deployment](#part-1-backend-service-deployment)
  - [1A: Deploy on Ubuntu 22.04 / 24.04](#1a-deploy-on-ubuntu-2204--2404)
  - [1B: Deploy on CentOS Stream 8 / 9](#1b-deploy-on-centos-stream-8--9)
- [Part 2: Run Desktop Client from Source](#part-2-run-desktop-client-from-source)
  - [2A: Windows](#2a-windows)
  - [2B: Linux (Ubuntu)](#2b-linux-ubuntu)
  - [2C: macOS](#2c-macos)
- [Part 3: Package Desktop Client (Windows Installer)](#part-3-package-desktop-client-windows-installer)
- [Part 4: Package Android APK (on Windows)](#part-4-package-android-apk-on-windows)
- [Part 5: Package iOS App (on macOS)](#part-5-package-ios-app-on-macos)

---

## Part 1: Backend Service Deployment

The backend requires three services: **Python 3.11+**, **MySQL 8.0+**, and **Redis 7.0+**.

### 1A: Deploy on Ubuntu 22.04 / 24.04

#### Step 1 — Check and install system dependencies

```bash
# Check existing versions (if any)
python3 --version      # Need 3.11+
mysql --version        # Need 8.0+
redis-server --version # Need 7.0+
nginx -v               # Need any recent version
git --version

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install basic tools
sudo apt install -y git curl wget build-essential
```

**Install Python 3.11+ (if not present or version is too old):**

```bash
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3.11-dev

# Verify
python3.11 --version
```

**Install MySQL 8.0+ (if not present):**

```bash
sudo apt install -y mysql-server mysql-client

# Start and enable
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure installation (set root password, remove test DB, etc.)
sudo mysql_secure_installation

# Verify
mysql --version
```

**Install Redis 7.0+ (if not present):**

```bash
sudo apt install -y redis-server

# Start and enable
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Verify
redis-server --version
redis-cli ping   # Should output PONG
```

**Install Nginx:**

```bash
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

#### Step 2 — Create the MySQL database and user

```bash
sudo mysql -u root -p
```

```sql
CREATE DATABASE lexy_files CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'lexy'@'localhost' IDENTIFIED BY 'YOUR_STRONG_PASSWORD_HERE';
GRANT ALL PRIVILEGES ON lexy_files.* TO 'lexy'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

#### Step 3 — Clone the project and set up the Python environment

```bash
# Clone
cd /opt
sudo mkdir lexy_files && sudo chown $USER:$USER lexy_files
git clone <your-repo-url> lexy_files
cd lexy_files/backend

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# If in China and pip is slow, use a mirror:
# pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com
```

#### Step 4 — Configure environment variables

```bash
cat > /opt/lexy_files/backend/.env << 'EOF'
# Flask
FLASK_ENV=production
SECRET_KEY=GENERATE_A_RANDOM_64_CHAR_STRING_HERE
JWT_SECRET_KEY=GENERATE_A_DIFFERENT_RANDOM_64_CHAR_STRING_HERE

# Database
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=lexy
MYSQL_PASSWORD=YOUR_STRONG_PASSWORD_HERE
MYSQL_DATABASE=lexy_files

# Redis
REDIS_URL=redis://localhost:6379/0

# File storage
UPLOAD_FOLDER=/var/data/lexy_files/uploads
MAX_CONTENT_LENGTH=5368709120

# Scheduler
SCHEDULER_ENABLED=true
CLEANUP_INTERVAL_MINUTES=30

# CORS — set to your actual domain in production
CORS_ORIGINS=https://files.example.com
EOF
```

Generate random secret keys:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
python3 -c "import secrets; print(secrets.token_hex(32))"
```

Create the upload directory:

```bash
sudo mkdir -p /var/data/lexy_files/uploads
sudo chown $USER:$USER /var/data/lexy_files/uploads
```

#### Step 5 — Initialize the database

```bash
cd /opt/lexy_files/backend
source venv/bin/activate

# If Flask-Migrate migrations exist:
flask db upgrade

# If no migration folder exists, create tables directly:
python3 -c "
from app import create_app
from app.extensions import db
app = create_app('production')
with app.app_context():
    db.create_all()
    print('Tables created successfully.')
"
```

#### Step 6 — Build the web frontend

```bash
# Install Node.js 18+ if not present
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Build
cd /opt/lexy_files/web
npm install
npm run build

# Deploy static files
sudo mkdir -p /var/www/lexy_files
sudo cp -r dist/* /var/www/lexy_files/
```

#### Step 7 — Create a systemd service for the backend

```bash
sudo tee /etc/systemd/system/lexy-backend.service << 'EOF'
[Unit]
Description=Lexy Files Backend
After=network.target mysql.service redis-server.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/lexy_files/backend
Environment="PATH=/opt/lexy_files/backend/venv/bin:/usr/bin"
ExecStart=/opt/lexy_files/backend/venv/bin/gunicorn \
    --worker-class eventlet \
    --workers 1 \
    --bind 127.0.0.1:7891 \
    --timeout 120 \
    --access-logfile /var/log/lexy_files/access.log \
    --error-logfile /var/log/lexy_files/error.log \
    "app:create_app('production')"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

Prepare log directory and file permissions:

```bash
sudo mkdir -p /var/log/lexy_files
sudo chown www-data:www-data /var/log/lexy_files
sudo chown -R www-data:www-data /opt/lexy_files
sudo chown -R www-data:www-data /var/data/lexy_files

sudo systemctl daemon-reload
sudo systemctl start lexy-backend
sudo systemctl enable lexy-backend

# Check status
sudo systemctl status lexy-backend
```

> **Note on workers:** WebSocket support (same-account relay) requires `eventlet` with `--workers 1`. Eventlet handles concurrency via green threads internally. Do not increase worker count when using eventlet.

#### Step 8 — Configure Nginx reverse proxy

```bash
sudo tee /etc/nginx/sites-available/lexy_files << 'EOF'
upstream lexy_backend {
    server 127.0.0.1:5000;
}

server {
    listen 80;
    server_name files.example.com;  # Replace with your domain

    client_max_body_size 5g;

    # Web client (static SPA)
    location / {
        root /var/www/lexy_files;
        try_files $uri $uri/ /index.html;
    }

    # API proxy
    location /api/ {
        proxy_pass http://lexy_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # WebSocket proxy (for same-account relay transfers)
    location /socket.io {
        proxy_pass http://lexy_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 3600s;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/lexy_files /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

#### Step 9 — (Optional) Enable HTTPS with Certbot

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d files.example.com

# Auto-renewal is configured automatically. Verify with:
sudo certbot renew --dry-run
```

#### Step 10 — Verify deployment

```bash
# Backend health
curl -s http://localhost:5000/api/v1/auth/me | head

# Web frontend
curl -s -o /dev/null -w "%{http_code}" http://localhost/

# Run backend tests (optional)
cd /opt/lexy_files/backend
source venv/bin/activate
python -m pytest tests/ -v
```

---

### 1B: Deploy on CentOS Stream 8 / 9

The steps are structurally identical to Ubuntu. Only the package manager commands differ.

#### Step 1 — Check and install system dependencies

```bash
# Check existing versions
python3 --version
mysql --version
redis-server --version

# Enable EPEL and PowerTools/CRB repositories
sudo dnf install -y epel-release
# CentOS Stream 8:
sudo dnf config-manager --set-enabled powertools
# CentOS Stream 9:
sudo dnf config-manager --set-enabled crb

sudo dnf update -y
sudo dnf install -y git curl wget gcc make openssl-devel bzip2-devel libffi-devel zlib-devel
```

**Install Python 3.11+ (if not present or too old):**

```bash
# CentOS Stream 9 ships Python 3.9; you need 3.11+.
# Option A: Install from AppStream (if available)
sudo dnf install -y python3.11 python3.11-devel python3.11-pip

# Option B: Build from source (if AppStream doesn't have 3.11)
cd /tmp
wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
tar xzf Python-3.11.9.tgz
cd Python-3.11.9
./configure --enable-optimizations --prefix=/usr/local
make -j$(nproc)
sudo make altinstall

# Verify
python3.11 --version
```

**Install MySQL 8.0+ (if not present):**

```bash
# Add MySQL official repository
sudo dnf install -y https://dev.mysql.com/get/mysql80-community-release-el$(rpm -E %rhel)-1.noarch.rpm

# If in China and dev.mysql.com is slow, use Tsinghua mirror:
# Edit /etc/yum.repos.d/mysql-community.repo and replace baseurl with:
# https://mirrors.tuna.tsinghua.edu.cn/mysql/yum/mysql-8.0-community-el9-x86_64/

sudo dnf install -y mysql-community-server

sudo systemctl start mysqld
sudo systemctl enable mysqld

# Get temporary root password
sudo grep 'temporary password' /var/log/mysqld.log

# Secure installation (change root password)
mysql_secure_installation

mysql --version
```

**Install Redis 7.0+ (if not present):**

```bash
sudo dnf install -y redis

sudo systemctl start redis
sudo systemctl enable redis

redis-server --version
redis-cli ping
```

**Install Nginx:**

```bash
sudo dnf install -y nginx

sudo systemctl start nginx
sudo systemctl enable nginx
```

**Open firewall ports:**

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

#### Step 2 onwards — Same as Ubuntu

Follow Ubuntu Steps 2 through 10 above. The only differences:

- Replace `python3.11` with the actual Python binary path if you built from source (`/usr/local/bin/python3.11`).
- SELinux may block Nginx from connecting to Gunicorn. If you get 502 errors:

```bash
# Allow Nginx to connect to upstream
sudo setsebool -P httpd_can_network_connect 1

# Allow Nginx to serve files from /var/www/lexy_files
sudo chcon -R -t httpd_sys_content_t /var/www/lexy_files

# Allow the backend to write to the upload folder
sudo chcon -R -t httpd_sys_rw_content_t /var/data/lexy_files/uploads
```

- The systemd service file location and Nginx config directory are the same (`/etc/systemd/system/` and `/etc/nginx/conf.d/`), but CentOS uses `/etc/nginx/conf.d/lexy_files.conf` instead of `sites-available/sites-enabled`:

```bash
sudo tee /etc/nginx/conf.d/lexy_files.conf << 'EOF'
# ... same Nginx config content as the Ubuntu version above ...
EOF

sudo nginx -t
sudo systemctl reload nginx
```

---

## Part 2: Run Desktop Client from Source

The desktop client is built with Flutter. It shares the same codebase as the mobile app, located in the `mobile/` directory.

### 2A: Windows

#### Prerequisites

1. **Flutter SDK 3.27+**

   Download from https://docs.flutter.dev/get-started/install/windows/desktop and extract to a permanent location (e.g., `C:\flutter`).

   Add to your system PATH:
   ```
   C:\flutter\bin
   ```

   Alternatively, if you have an existing Flutter install:
   ```powershell
   flutter --version   # Verify 3.27+ and Dart 3.x
   flutter upgrade     # Upgrade if needed
   ```

2. **Visual Studio 2022** (not VS Code) with the **"Desktop development with C++"** workload.

   This is required by Flutter to compile Windows native code. Download from https://visualstudio.microsoft.com/downloads/ and during installation, check:
   - "Desktop development with C++"
   - Make sure "MSVC v143" and "Windows 10/11 SDK" are selected.

3. **Git for Windows** (https://git-scm.com/download/win).

#### Verify environment

Open a terminal (PowerShell or Git Bash):

```bash
flutter doctor
```

You should see checkmarks for "Flutter", "Windows Version", and "Visual Studio". Fix any issues it reports before continuing.

#### Run the desktop app

```bash
cd mobile

# Get dependencies
flutter pub get

# Edit the API URL to point to your backend
# Open lib/config/api_config.dart and set the base URL to your backend address:
#   - For local development: http://localhost:5000
#   - For production: https://files.example.com

# Run
flutter run -d windows
```

The app window will open and connect to the backend you configured.

---

### 2B: Linux (Ubuntu)

#### Prerequisites

1. **Flutter SDK 3.27+**

   ```bash
   # Option A: Install via snap
   sudo snap install flutter --classic

   # Option B: Manual install
   cd ~
   git clone https://github.com/flutter/flutter.git -b stable
   echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

2. **Linux desktop development dependencies**

   ```bash
   sudo apt install -y clang cmake ninja-build pkg-config \
       libgtk-3-dev liblzma-dev libstdc++-12-dev
   ```

3. **Bluetooth dependencies** (for BLE transfer support)

   ```bash
   sudo apt install -y libbluetooth-dev
   ```

#### Verify and run

```bash
flutter doctor         # Check for issues
cd mobile
flutter pub get

# Edit lib/config/api_config.dart — set the backend URL

flutter run -d linux
```

---

### 2C: macOS

#### Prerequisites

1. **Xcode 15+** — Install from the Mac App Store.

   After installing, accept the license and install command-line tools:
   ```bash
   sudo xcodebuild -license accept
   xcode-select --install
   ```

2. **Flutter SDK 3.27+**

   ```bash
   # Option A: Homebrew
   brew install --cask flutter

   # Option B: Manual
   cd ~
   git clone https://github.com/flutter/flutter.git -b stable
   echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

3. **CocoaPods**

   ```bash
   sudo gem install cocoapods
   # Or via Homebrew: brew install cocoapods
   ```

#### Verify and run

```bash
flutter doctor
cd mobile
flutter pub get

# Edit lib/config/api_config.dart — set the backend URL

flutter run -d macos
```

---

## Part 3: Package Desktop Client (Windows Installer)

This section produces a distributable Windows installer from the Flutter desktop build.

### Step 1 — Build a release binary

```bash
cd mobile
flutter build windows --release
```

The output is at:
```
mobile/build/windows/x64/runner/Release/
```

This folder contains `lexy_files.exe` and all required DLLs. You can zip this folder and distribute it directly, but a proper installer is recommended.

### Step 2 — Create an installer with Inno Setup

**Install Inno Setup** from https://jrsoftware.org/isinfo.php (free, widely used).

Create a file `installer/lexy_files_setup.iss` in the project root:

```iss
[Setup]
AppName=Lexy Files
AppVersion=1.0.0
DefaultDirName={autopf}\Lexy Files
DefaultGroupName=Lexy Files
OutputDir=..\installer\output
OutputBaseFilename=LexyFiles-1.0.0-Setup
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\mobile\windows\runner\resources\app_icon.ico
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "..\mobile\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\Lexy Files"; Filename: "{app}\lexy_files.exe"
Name: "{autodesktop}\Lexy Files"; Filename: "{app}\lexy_files.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\lexy_files.exe"; Description: "Launch Lexy Files"; Flags: nowait postinstall skipifsilent
```

Then compile:

```bash
# From command line (assuming Inno Setup is in PATH):
iscc installer/lexy_files_setup.iss

# Or open the .iss file in Inno Setup GUI and click "Compile".
```

The installer will be generated at `installer/output/LexyFiles-1.0.0-Setup.exe`.

### Alternative: MSIX packaging

If you prefer Microsoft Store-style packaging:

```bash
# Add the msix package to pubspec.yaml dev_dependencies:
#   msix: ^3.16.0

# Add msix config to the end of pubspec.yaml:
# msix_config:
#   display_name: Lexy Files
#   publisher_display_name: Lexy
#   identity_name: com.lexy.files
#   msix_version: 1.0.0.0
#   logo_path: windows/runner/resources/app_icon.ico

cd mobile
flutter pub get
dart run msix:create
```

The `.msix` file will be at `mobile/build/windows/x64/runner/Release/lexy_files.msix`.

---

## Part 4: Package Android APK (on Windows)

### Step 1 — Install prerequisites

1. **Flutter SDK 3.27+** — Same as Part 2A above. Ensure `flutter` is in your PATH.

2. **Android Studio** — Download from https://developer.android.com/studio and install.

   During installation or first launch, the setup wizard will install:
   - Android SDK
   - Android SDK Command-line Tools
   - Android SDK Build-Tools
   - Android Emulator (optional)

   If prompted, accept all SDK license agreements:
   ```bash
   flutter doctor --android-licenses
   ```

3. **Java Development Kit (JDK) 17** — Android Studio bundles a JDK, but if `flutter doctor` complains:

   ```bash
   # Download and install JDK 17 from https://adoptium.net/
   # Or via winget:
   winget install EclipseAdoptium.Temurin.17.JDK
   ```

4. **Environment variables** — Ensure these are set (adjust paths to match your install):

   ```
   ANDROID_HOME=C:\Users\<you>\AppData\Local\Android\Sdk
   JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
   PATH += %ANDROID_HOME%\platform-tools
   PATH += %ANDROID_HOME%\cmdline-tools\latest\bin
   ```

5. If in **China**, configure Gradle and Flutter mirrors:

   **Flutter mirror** (set as environment variables):
   ```
   PUB_HOSTED_URL=https://pub.flutter-io.cn
   FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
   ```

   **Gradle mirror** — edit `mobile/android/build.gradle`, replace `google()` and `mavenCentral()` with:
   ```groovy
   maven { url 'https://maven.aliyun.com/repository/google' }
   maven { url 'https://maven.aliyun.com/repository/central' }
   maven { url 'https://maven.aliyun.com/repository/public' }
   ```

   Apply the same change in both `buildscript { repositories { ... } }` and `allprojects { repositories { ... } }` blocks.

### Step 2 — Verify environment

```bash
flutter doctor -v
```

All items under "Android toolchain" should show checkmarks. Fix any issues before continuing.

### Step 3 — Configure the API URL

Edit `mobile/lib/config/api_config.dart` and set the production backend URL:

```dart
static const String baseUrl = 'https://files.example.com';
```

### Step 4 — Build a debug APK (quick test)

```bash
cd mobile
flutter pub get
flutter build apk --debug
```

Output: `mobile/build/app/outputs/flutter-apk/app-debug.apk`

Transfer this to a phone and install to test. Debug APKs are larger and slower but do not require signing.

### Step 5 — Generate a release signing key

A release APK must be signed. Create a keystore (run once, keep the file safe):

```bash
keytool -genkey -v \
  -keystore android/app/lexy-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias lexy-key \
  -storepass YOUR_KEYSTORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=Lexy Files, OU=Dev, O=Lexy, L=City, ST=Province, C=CN"
```

> **Important:** Back up `lexy-release-key.jks` and your passwords. If you lose them, you cannot update the app on any store.

### Step 6 — Configure signing in the project

Create `mobile/android/key.properties`:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=lexy-key
storeFile=lexy-release-key.jks
```

Edit `mobile/android/app/build.gradle` — add the signing config above the `android {` block:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Inside the `android { ... }` block, add:

```groovy
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

### Step 7 — Build the release APK

```bash
cd mobile
flutter build apk --release
```

Output: `mobile/build/app/outputs/flutter-apk/app-release.apk`

This APK is signed, optimized, and ready for distribution or sideloading.

To build an **App Bundle** for Google Play:

```bash
flutter build appbundle --release
```

Output: `mobile/build/app/outputs/bundle/release/app-release.aab`

---

## Part 5: Package iOS App (on macOS)

Building for iOS **requires a Mac** with macOS. There is no way to build iOS apps on Windows or Linux.

### Step 1 — Install Xcode

1. Open the **Mac App Store** on your Mac.
2. Search for **Xcode** and click **Get / Install**. (Download is ~12 GB, installation expands to ~35 GB. Ensure sufficient disk space.)
3. Wait for the download and installation to complete.
4. Launch Xcode once to complete initial setup. It will prompt to install additional components — click **Install**.

5. Accept the license and install command-line tools from the terminal:

```bash
sudo xcodebuild -license accept
xcode-select --install
```

6. Verify:

```bash
xcodebuild -version
# Should show Xcode 15.x or 16.x and Build version
```

### Step 2 — Install Homebrew (if not present)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Follow the instructions it prints to add Homebrew to your PATH.
# Typically for Apple Silicon Macs:
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc

brew --version
```

### Step 3 — Install Flutter SDK

```bash
# Option A: Via Homebrew (recommended)
brew install --cask flutter

# Option B: Manual download
cd ~
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Verify:

```bash
flutter --version    # Should show 3.27+ with Dart 3.x
```

### Step 4 — Install CocoaPods

CocoaPods is required by Flutter to manage iOS native dependencies.

```bash
# Via Homebrew (preferred, avoids Ruby permission issues)
brew install cocoapods

# Or via Ruby gem
sudo gem install cocoapods

pod --version
```

### Step 5 — Run Flutter doctor

```bash
flutter doctor -v
```

Ensure all items under **"Xcode"** and **"iOS toolchain"** show checkmarks:

- Xcode installed
- CocoaPods installed
- iOS simulator available

If `flutter doctor` reports "Unable to find a connected iOS device", that's fine — you can use the Simulator or a physical device later.

### Step 6 — Clone the project and fetch dependencies

```bash
git clone <your-repo-url> lexy_files
cd lexy_files/mobile

flutter pub get
```

Then install the iOS native dependencies:

```bash
cd ios
pod install
cd ..
```

If `pod install` fails with version conflicts:

```bash
cd ios
pod deintegrate
pod install --repo-update
cd ..
```

### Step 7 — Configure the API URL

Edit `lib/config/api_config.dart`:

```dart
// For iOS Simulator connecting to a Mac-local backend:
static const String baseUrl = 'http://localhost:5000';

// For a physical iPhone connecting to your backend server:
static const String baseUrl = 'https://files.example.com';
```

### Step 8 — Add required iOS permissions

The app uses Bluetooth and local network features. Edit `ios/Runner/Info.plist` — add these keys inside the top-level `<dict>` block (before the closing `</dict>`):

```xml
<!-- Bluetooth (required for BLE transfer) -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Lexy Files uses Bluetooth to transfer files to nearby devices.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Lexy Files uses Bluetooth to receive files from nearby devices.</string>

<!-- Local Network (required for LAN discovery and transfer) -->
<key>NSLocalNetworkUsageDescription</key>
<string>Lexy Files uses the local network to discover and transfer files to nearby devices.</string>
<key>NSBonjourServices</key>
<array>
    <string>_lexyfiles._tcp</string>
</array>

<!-- Photo Library (if saving received files to photos) -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Lexy Files needs access to save received images to your photo library.</string>

<!-- File access -->
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

### Step 9 — Configure signing (Apple Developer Account)

iOS apps must be code-signed to run on physical devices or be distributed.

#### Option A: Free Apple ID (development/testing only)

You can run on a physical device for 7 days without a paid developer account.

1. Open the Xcode project:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. In Xcode, select the **Runner** project in the left sidebar.
3. Select the **Runner** target, go to the **Signing & Capabilities** tab.
4. Check **"Automatically manage signing"**.
5. Under **Team**, click the dropdown and select **"Add an Account..."**.
6. Sign in with your Apple ID.
7. Select your Personal Team.
8. Xcode will generate a provisioning profile automatically.
9. Change the **Bundle Identifier** to something unique, e.g.: `com.yourname.lexyfiles`

#### Option B: Apple Developer Program ($99/year, required for App Store distribution)

1. Enroll at https://developer.apple.com/programs/enroll/
2. Wait for approval (usually 24-48 hours).
3. In Xcode → Runner target → Signing & Capabilities:
   - Select your Developer Team.
   - Set Bundle Identifier to your registered App ID (e.g., `com.yourcompany.lexyfiles`).
   - Xcode will automatically create/download provisioning profiles.

### Step 10 — Test on the iOS Simulator

```bash
# List available simulators
xcrun simctl list devices

# Run on iPhone simulator
cd mobile
flutter run -d "iPhone 16 Pro"
# Or simply:
flutter run
# Flutter will auto-select an available iOS simulator
```

### Step 11 — Test on a physical iPhone

1. Connect your iPhone to the Mac via USB.
2. On the iPhone, go to **Settings → Privacy & Security → Developer Mode** and enable it (iOS 16+).
3. Trust the Mac when prompted on the iPhone.
4. Run:

```bash
flutter run -d <device-id>

# To find the device ID:
flutter devices
```

5. The first time, your iPhone will show "Untrusted Developer". On the iPhone, go to **Settings → General → VPN & Device Management** → tap your developer profile → **Trust**.

### Step 12 — Build a release IPA

```bash
cd mobile

# Build the release iOS app
flutter build ios --release
```

This produces the `.app` bundle but not a distributable `.ipa`. To create an IPA:

#### Archive and export via Xcode

1. Open the workspace:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. In Xcode, set the device target to **"Any iOS Device (arm64)"** (top toolbar dropdown).

3. Go to **Product → Archive**. Wait for the build and archive to complete.

4. When the Organizer window opens showing your archive:

   **For Ad Hoc distribution (sideloading / TestFlight internal):**
   - Click **Distribute App**.
   - Select **Custom → Ad Hoc**.
   - Follow the prompts to select your distribution certificate and provisioning profile.
   - Click **Export**. Choose a save location.
   - The exported folder contains the `.ipa` file.

   **For App Store / TestFlight distribution:**
   - Click **Distribute App**.
   - Select **App Store Connect**.
   - Choose **Upload** (sends directly to App Store Connect) or **Export** (saves locally for manual upload).
   - Follow the prompts.
   - After upload, go to https://appstoreconnect.apple.com to manage TestFlight builds or submit for App Store review.

#### Archive via command line (alternative)

```bash
cd mobile/ios

xcodebuild archive \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=YES

xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/ipa
```

You'll need an `ExportOptions.plist` file. Here's a template for Ad Hoc distribution:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
```

Replace `YOUR_TEAM_ID` with your Apple Developer Team ID (found at https://developer.apple.com/account → Membership details).

### Step 13 — Verify the built IPA

Install the IPA on a test device using one of:

- **Apple Configurator 2** (Mac App Store, free) — connect the iPhone and drag the IPA to it.
- **Xcode → Window → Devices and Simulators** — select the connected device, click "+" under "Installed Apps", and choose the IPA.
- **TestFlight** — if you uploaded to App Store Connect, install via the TestFlight app on the iPhone.

---

## Quick Reference: Checklist for All Components

| Component | Build Command | Output Location |
|---|---|---|
| Backend | `gunicorn --worker-class eventlet ...` | Service on port 5000 |
| Web frontend | `cd web && npm run build` | `web/dist/` |
| Windows desktop | `cd mobile && flutter build windows --release` | `mobile/build/windows/x64/runner/Release/` |
| Windows installer | `iscc installer/lexy_files_setup.iss` | `installer/output/LexyFiles-1.0.0-Setup.exe` |
| Android debug APK | `cd mobile && flutter build apk --debug` | `mobile/build/app/outputs/flutter-apk/app-debug.apk` |
| Android release APK | `cd mobile && flutter build apk --release` | `mobile/build/app/outputs/flutter-apk/app-release.apk` |
| iOS release | `cd mobile && flutter build ios --release` then Xcode Archive | Xcode Organizer → Export |
