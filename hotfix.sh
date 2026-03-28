#!/usr/bin/env bash
#
# hotfix.sh — Pull latest code and redeploy Lexy Files on the server.
#
# Usage:
#   sudo bash hotfix.sh          # full update (backend + web)
#   sudo bash hotfix.sh web      # web frontend only (no backend restart)
#   sudo bash hotfix.sh backend  # backend only (no web rebuild)
#
# Assumes the deployment layout from DEPLOY.md:
#   Project root:  /opt/lexy_files
#   Web docroot:   /var/www/lexy_files
#   Systemd unit:  lexy-backend.service
#   Python venv:   /opt/lexy_files/backend/venv

set -euo pipefail

# ── Configuration (edit these if your paths differ) ──────────────────────────
PROJECT_DIR="/opt/lexy_files"
WEB_DOCROOT="/var/www/lexy_files"
BACKEND_SERVICE="lexy-backend"
VENV_DIR="$PROJECT_DIR/backend/venv"
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

MODE="${1:-all}"  # all | web | backend

# ── Preflight checks ────────────────────────────────────────────────────────

if [[ ! -d "$PROJECT_DIR/.git" ]]; then
    err "Not a git repository: $PROJECT_DIR"
    exit 1
fi

if [[ "$MODE" == "all" || "$MODE" == "web" ]]; then
    if ! command -v node &>/dev/null; then
        err "Node.js not found. Install it before rebuilding the web frontend."
        exit 1
    fi
fi

if [[ "$MODE" == "all" || "$MODE" == "backend" ]]; then
    if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
        err "Python venv not found at $VENV_DIR"
        exit 1
    fi
    if ! systemctl list-units --type=service --all | grep -q "$BACKEND_SERVICE"; then
        warn "Systemd service '$BACKEND_SERVICE' not found. Backend will not be restarted."
    fi
fi

# ── Step 1: Git pull ────────────────────────────────────────────────────────

log "Pulling latest code ..."
cd "$PROJECT_DIR"
BEFORE=$(git rev-parse HEAD)
git pull --ff-only origin main
AFTER=$(git rev-parse HEAD)

if [[ "$BEFORE" == "$AFTER" ]]; then
    warn "Already up-to-date ($AFTER). Proceeding anyway in case of manual changes."
else
    log "Updated: ${BEFORE:0:8} -> ${AFTER:0:8}"
    echo "---"
    git --no-pager log --oneline "$BEFORE".."$AFTER"
    echo "---"
fi

# ── Step 2: Backend update ──────────────────────────────────────────────────

if [[ "$MODE" == "all" || "$MODE" == "backend" ]]; then
    log "Updating backend dependencies ..."
    source "$VENV_DIR/bin/activate"
    pip install -q -r "$PROJECT_DIR/backend/requirements.txt"

    # Run database migrations if flask-migrate is configured
    cd "$PROJECT_DIR/backend"
    if [[ -d "migrations" ]]; then
        log "Running database migrations ..."
        flask db upgrade || warn "flask db upgrade failed — check manually"
    fi

    log "Restarting backend service ..."
    systemctl restart "$BACKEND_SERVICE"
    sleep 2

    if systemctl is-active --quiet "$BACKEND_SERVICE"; then
        log "Backend service is running."
    else
        err "Backend service failed to start! Check: journalctl -u $BACKEND_SERVICE -n 30"
        systemctl status "$BACKEND_SERVICE" --no-pager || true
    fi

    deactivate 2>/dev/null || true
fi

# ── Step 3: Web frontend rebuild ────────────────────────────────────────────

if [[ "$MODE" == "all" || "$MODE" == "web" ]]; then
    log "Rebuilding web frontend ..."
    cd "$PROJECT_DIR/web"
    npm install --silent
    npm run build

    if [[ -d "dist" ]]; then
        log "Deploying to $WEB_DOCROOT ..."
        rm -rf "$WEB_DOCROOT"/*
        cp -r dist/* "$WEB_DOCROOT/"
        log "Web frontend deployed."
    else
        err "Web build failed — dist/ directory not found."
        exit 1
    fi
fi

# ── Done ────────────────────────────────────────────────────────────────────

echo ""
log "Hotfix applied successfully.  (commit: ${AFTER:0:8})"
echo ""
echo "  Verify:"
echo "    Backend:  curl -s http://localhost:7891/api/v1/auth/me | head"
echo "    Web:      curl -s -o /dev/null -w '%{http_code}' http://localhost/"
echo "    Logs:     journalctl -u $BACKEND_SERVICE -f"
echo ""
