# Deployment Notes

## Backend Deployment

### Production Configuration

Set these environment variables in production:

```bash
# Security -- MUST change from defaults
SECRET_KEY=<generate-a-random-64-char-string>
JWT_SECRET_KEY=<generate-a-different-random-64-char-string>

# Database
MYSQL_HOST=your-mysql-host
MYSQL_PORT=3306
MYSQL_USER=lexy
MYSQL_PASSWORD=<strong-password>
MYSQL_DATABASE=lexy_files

# Redis
REDIS_URL=redis://your-redis-host:6379/0

# File storage
UPLOAD_FOLDER=/var/data/lexy_files/uploads
MAX_CONTENT_LENGTH=5368709120  # 5 GB

# Server
FLASK_ENV=production
SCHEDULER_ENABLED=true
CLEANUP_INTERVAL_MINUTES=30
```

### Running with Gunicorn

```bash
pip install gunicorn eventlet

gunicorn --worker-class eventlet \
         --workers 1 \
         --bind 0.0.0.0:5000 \
         --timeout 120 \
         "app:create_app('production')"
```

**Note:** WebSocket support requires eventlet workers. Use `--workers 1` with eventlet (it handles concurrency via green threads). For WebSocket-less deployments, use `--workers 4` with sync workers.

### Nginx Reverse Proxy

```nginx
upstream lexy_backend {
    server 127.0.0.1:5000;
}

server {
    listen 80;
    server_name files.example.com;

    client_max_body_size 5g;

    # Web client static files
    location / {
        root /var/www/lexy_files/dist;
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

    # WebSocket proxy
    location /ws {
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

### Database Initialization

```bash
# Run migrations
cd backend
flask db upgrade

# Or create tables directly
python -c "from app import create_app; from app.extensions import db; app = create_app('production'); app.app_context().push(); db.create_all()"
```

Group quotas are seeded automatically on first startup.

### File Storage

- Create the upload directory: `mkdir -p /var/data/lexy_files/uploads`
- Ensure the application user has read/write permissions
- For high-traffic deployments, consider a dedicated partition or network-attached storage
- Back up the upload directory regularly

### Monitoring

Key metrics to watch:
- Disk usage on the upload folder
- MySQL connection pool utilization
- Redis memory usage
- Background cleanup job execution (check logs for "Cleanup completed")

### Scheduled Cleanup

The backend runs an APScheduler job every 30 minutes (configurable) that:
1. Expires files past their retention time (sets status to "expired")
2. Deletes files past their 7-day redemption window (removes from disk)

Verify it's running by checking logs for `Cleanup completed: {expired: N, deleted: N}`.

## Web Client Deployment

### Build

```bash
cd web
npm run build
```

### Serve Static Files

Copy `web/dist/` to your web server's document root. The web client is a single-page application -- configure your server to serve `index.html` for all routes (see nginx config above).

### API URL Configuration

The production web client expects the API to be available at the same origin under `/api/v1/`. No additional configuration is needed if served behind the same nginx instance.

## Mobile App Distribution

### Android

```bash
cd mobile

# Debug APK (for testing)
flutter build apk --debug

# Release APK (requires keystore setup)
flutter build apk --release

# App Bundle for Play Store
flutter build appbundle --release
```

The APK is at `build/app/outputs/flutter-apk/`.

Before release, update `api_config.dart` to point to the production backend URL.

### iOS

Requires macOS with Xcode installed.

```bash
flutter build ios --release
```

Then archive and upload via Xcode Organizer.

### Windows Desktop

```bash
flutter build windows --release
```

Output is at `build/windows/x64/runner/Release/`. Package with MSIX or InnoSetup for distribution.

## Security Checklist

- [ ] Change `SECRET_KEY` and `JWT_SECRET_KEY` from defaults
- [ ] Use HTTPS (TLS) for all connections
- [ ] Set strong MySQL password
- [ ] Restrict Redis access to localhost or private network
- [ ] Set `CORS_ORIGINS` to your domain(s) instead of `*`
- [ ] Run MySQL with minimal privileges for the lexy user
- [ ] Enable firewall rules (only expose ports 80/443)
- [ ] Set appropriate `MAX_CONTENT_LENGTH` for your use case
- [ ] Review and set upload folder permissions (no execute)
- [ ] Enable MySQL audit logging for compliance
