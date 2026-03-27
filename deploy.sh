#!/usr/bin/env bash
# ============================================================================
# Lexy Files — One-click deploy script for Ubuntu server
#
# Usage:
#   ./deploy.sh <user@host> [--skip-deps]
#
# What it does:
#   1. Syncs backend/ and web/ to the remote server via rsync
#   2. Installs system dependencies (Python 3, pip, Node.js, nginx, mysql, redis)
#   3. Sets up Python venv and installs backend requirements
#   4. Initialises MySQL database and runs Flask migrations
#   5. Installs web frontend deps and runs `npm run build`
#   6. Configures nginx to serve the web build + reverse-proxy /api and /socket.io
#   7. Creates a systemd service (lexy-backend) on port 32107
#   8. Starts everything
#
# Prerequisites:
#   - SSH access with sudo on the target server
#   - rsync installed locally
# ============================================================================

set -euo pipefail

# ── Args ────────────────────────────────────────────────────────────────────
if [ $# -lt 1 ]; then
    echo "Usage: ./deploy.sh <user@host> [--skip-deps]"
    echo ""
    echo "  user@host    SSH destination (e.g. root@123.45.67.89)"
    echo "  --skip-deps  Skip system dependency installation (faster re-deploys)"
    exit 1
fi

REMOTE="$1"
SKIP_DEPS="${2:-}"
DEPLOY_DIR="/opt/lexy-files"
BACKEND_PORT=32107
SERVICE_NAME="lexy-backend"
DB_NAME="lexy_files"
DB_USER="lexy"
DB_PASS="lexy_$(openssl rand -hex 8)"

# ── Colours ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Resolve project root (where this script lives) ─────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="${SCRIPT_DIR}/backend"
WEB_DIR="${SCRIPT_DIR}/web"

[ -d "$BACKEND_DIR" ] || error "backend/ directory not found at ${BACKEND_DIR}"
[ -d "$WEB_DIR" ]     || error "web/ directory not found at ${WEB_DIR}"

# ── Step 1: Sync files to remote ────────────────────────────────────────────
info "Syncing project files to ${REMOTE}:${DEPLOY_DIR} ..."

ssh "$REMOTE" "sudo mkdir -p ${DEPLOY_DIR}/{backend,web}"
ssh "$REMOTE" "sudo chown -R \$(whoami):\$(whoami) ${DEPLOY_DIR}"

rsync -az --delete \
    --exclude '__pycache__' \
    --exclude '*.pyc' \
    --exclude '.pytest_cache' \
    --exclude 'venv' \
    --exclude '.env' \
    "${BACKEND_DIR}/" "${REMOTE}:${DEPLOY_DIR}/backend/"

rsync -az --delete \
    --exclude 'node_modules' \
    --exclude 'dist' \
    "${WEB_DIR}/" "${REMOTE}:${DEPLOY_DIR}/web/"

info "Files synced."

# ── Step 2: Remote setup (single SSH session) ───────────────────────────────
info "Running remote setup on ${REMOTE} ..."

ssh -t "$REMOTE" bash -s -- \
    "$DEPLOY_DIR" "$BACKEND_PORT" "$SERVICE_NAME" "$DB_NAME" "$DB_USER" "$DB_PASS" "$SKIP_DEPS" \
    <<'REMOTE_SCRIPT'
set -euo pipefail

DEPLOY_DIR="$1"
BACKEND_PORT="$2"
SERVICE_NAME="$3"
DB_NAME="$4"
DB_USER="$5"
DB_PASS="$6"
SKIP_DEPS="$7"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info()  { echo -e "${GREEN}[REMOTE]${NC} $*"; }
warn()  { echo -e "${YELLOW}[REMOTE]${NC} $*"; }

export DEBIAN_FRONTEND=noninteractive

# ── 2a. System dependencies ────────────────────────────────────────────────
if [ "$SKIP_DEPS" != "--skip-deps" ]; then
    info "Installing system dependencies ..."
    sudo apt-get update -qq

    # Python
    sudo apt-get install -y -qq python3 python3-pip python3-venv > /dev/null

    # Node.js 20 LTS (via NodeSource if not present)
    if ! command -v node &> /dev/null || [ "$(node -v | cut -d. -f1 | tr -d v)" -lt 18 ]; then
        info "Installing Node.js 20 LTS ..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - > /dev/null 2>&1
        sudo apt-get install -y -qq nodejs > /dev/null
    fi

    # MySQL
    if ! command -v mysql &> /dev/null; then
        info "Installing MySQL server ..."
        sudo apt-get install -y -qq mysql-server > /dev/null
        sudo systemctl enable --now mysql
    fi

    # Redis
    if ! command -v redis-server &> /dev/null; then
        info "Installing Redis ..."
        sudo apt-get install -y -qq redis-server > /dev/null
        sudo systemctl enable --now redis-server
    fi

    # Nginx
    if ! command -v nginx &> /dev/null; then
        info "Installing Nginx ..."
        sudo apt-get install -y -qq nginx > /dev/null
        sudo systemctl enable --now nginx
    fi

    info "System dependencies installed."
else
    info "Skipping system dependency installation (--skip-deps)."
fi

# ── 2b. MySQL database & user ──────────────────────────────────────────────
info "Setting up MySQL database ..."

# Check if database exists; create if not
if ! sudo mysql -e "USE ${DB_NAME}" 2>/dev/null; then
    sudo mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    info "Created database: ${DB_NAME}"
fi

# Create or update user
sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
info "MySQL user '${DB_USER}' configured."

# ── 2c. Backend: venv + dependencies ──────────────────────────────────────
info "Setting up Python virtual environment ..."
cd "${DEPLOY_DIR}/backend"

if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt

# ── 2d. Backend: environment file ──────────────────────────────────────────
info "Writing backend .env ..."
ENV_FILE="${DEPLOY_DIR}/backend/.env"

# Preserve existing SECRET_KEY / JWT_SECRET_KEY if .env already exists
if [ -f "$ENV_FILE" ]; then
    EXISTING_SECRET=$(grep -oP '^SECRET_KEY=\K.*' "$ENV_FILE" 2>/dev/null || true)
    EXISTING_JWT=$(grep -oP '^JWT_SECRET_KEY=\K.*' "$ENV_FILE" 2>/dev/null || true)
fi

SECRET_KEY="${EXISTING_SECRET:-$(python3 -c 'import secrets; print(secrets.token_hex(32))')}"
JWT_SECRET="${EXISTING_JWT:-$(python3 -c 'import secrets; print(secrets.token_hex(32))')}"

cat > "$ENV_FILE" <<ENVEOF
FLASK_ENV=production
SECRET_KEY=${SECRET_KEY}
JWT_SECRET_KEY=${JWT_SECRET}
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=${DB_USER}
MYSQL_PASSWORD=${DB_PASS}
MYSQL_DATABASE=${DB_NAME}
REDIS_URL=redis://localhost:6379/0
UPLOAD_FOLDER=${DEPLOY_DIR}/uploads
CORS_ORIGINS=*
SCHEDULER_ENABLED=true
CLEANUP_INTERVAL_MINUTES=30
ENVEOF

chmod 600 "$ENV_FILE"

# ── 2e. Create upload directory ────────────────────────────────────────────
mkdir -p "${DEPLOY_DIR}/uploads"

# ── 2f. Database migration ────────────────────────────────────────────────
info "Running database migrations ..."
export FLASK_ENV=production

# Initialise migrations if they don't exist yet
if [ ! -d "migrations" ]; then
    flask db init
fi

flask db migrate -m "deploy" 2>/dev/null || true   # no-op if no new changes
flask db upgrade
info "Database migrations complete."

deactivate

# ── 2g. Web frontend: install + build ─────────────────────────────────────
info "Building web frontend ..."
cd "${DEPLOY_DIR}/web"
npm install --legacy-peer-deps 2>&1 | tail -1
npm run build
info "Web frontend built."

# ── 2h. Systemd service ──────────────────────────────────────────────────
info "Configuring systemd service: ${SERVICE_NAME} ..."

sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" > /dev/null <<SVCEOF
[Unit]
Description=Lexy Files Backend (Flask + SocketIO)
After=network.target mysql.service redis-server.service
Wants=mysql.service redis-server.service

[Service]
Type=simple
User=$(whoami)
Group=$(id -gn)
WorkingDirectory=${DEPLOY_DIR}/backend
EnvironmentFile=${DEPLOY_DIR}/backend/.env
ExecStart=${DEPLOY_DIR}/backend/venv/bin/python -m gunicorn \
    --worker-class eventlet \
    --workers 1 \
    --bind 127.0.0.1:${BACKEND_PORT} \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    "run:app"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl restart "${SERVICE_NAME}"
info "Service ${SERVICE_NAME} started on port ${BACKEND_PORT}."

# ── 2i. Nginx reverse proxy ──────────────────────────────────────────────
info "Configuring Nginx ..."

sudo tee /etc/nginx/sites-available/lexy-files > /dev/null <<NGXEOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Web frontend (static files)
    root ${DEPLOY_DIR}/web/dist;
    index index.html;

    # SPA fallback
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # API reverse proxy
    location /api/ {
        proxy_pass http://127.0.0.1:${BACKEND_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 5g;
    }

    # WebSocket (Socket.IO) reverse proxy
    location /socket.io/ {
        proxy_pass http://127.0.0.1:${BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
}
NGXEOF

# Enable site, remove default if it's different
sudo ln -sf /etc/nginx/sites-available/lexy-files /etc/nginx/sites-enabled/lexy-files
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl reload nginx
info "Nginx configured and reloaded."

# ── 2j. Verify ─────────────────────────────────────────────────────────────
sleep 2
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    info "✓ ${SERVICE_NAME} is running on port ${BACKEND_PORT}"
else
    warn "✗ ${SERVICE_NAME} may have failed to start. Check: sudo journalctl -u ${SERVICE_NAME} -n 50"
fi

if systemctl is-active --quiet nginx; then
    info "✓ Nginx is running"
else
    warn "✗ Nginx may have failed. Check: sudo journalctl -u nginx -n 20"
fi

echo ""
echo "=============================================="
echo "  Lexy Files deployed successfully!"
echo ""
echo "  Web UI:     http://$(hostname -I | awk '{print $1}')"
echo "  API:        http://$(hostname -I | awk '{print $1}')/api/v1/"
echo "  Backend:    127.0.0.1:${BACKEND_PORT} (internal)"
echo ""
echo "  Service:    sudo systemctl {status|restart|stop} ${SERVICE_NAME}"
echo "  Logs:       sudo journalctl -u ${SERVICE_NAME} -f"
echo "  DB pass:    ${DB_PASS} (saved in ${DEPLOY_DIR}/backend/.env)"
echo "=============================================="

REMOTE_SCRIPT

info "Deploy complete!"
