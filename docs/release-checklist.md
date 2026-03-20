# Release Checklist

## Pre-release Verification

### Backend
- [ ] All 81 tests pass: `cd backend && python -m pytest tests/ -v`
- [ ] No lint warnings: `cd backend && flake8 app/ --max-line-length=120`
- [ ] Environment variables configured (SECRET_KEY, JWT_SECRET_KEY, MySQL, Redis)
- [ ] Database migrations applied: `flask db upgrade`
- [ ] Default group quotas seeded (automatic on first startup)
- [ ] Upload folder exists and is writable
- [ ] Cleanup scheduler enabled and running
- [ ] Redis connected (for token revocation)

### Web Client
- [ ] TypeScript compiles: `cd web && npx tsc --noEmit`
- [ ] Production build succeeds: `cd web && npm run build`
- [ ] Static files deployed to web server
- [ ] API proxy configured (nginx or equivalent)
- [ ] Test login, upload, pickup code, download manually

### Flutter App
- [ ] Static analysis clean: `cd mobile && flutter analyze`
- [ ] Tests pass: `cd mobile && flutter test`
- [ ] API URL points to production in `api_config.dart`
- [ ] Android APK builds: `flutter build apk --release` (requires keystore)
- [ ] Windows desktop builds: `flutter build windows --release`
- [ ] iOS builds: `flutter build ios --release` (requires macOS + Xcode)
- [ ] Test login, upload, pickup, download on each platform

### Security
- [ ] SECRET_KEY and JWT_SECRET_KEY changed from defaults
- [ ] HTTPS/TLS configured
- [ ] CORS_ORIGINS restricted to production domain(s)
- [ ] MySQL credentials are strong and not defaults
- [ ] Redis not exposed to public network
- [ ] Upload folder has no execute permissions
- [ ] `MAX_CONTENT_LENGTH` set appropriately

### Infrastructure
- [ ] MySQL 8.0+ running with utf8mb4 charset
- [ ] Redis 7.0+ running
- [ ] Nginx configured with WebSocket and file upload support
- [ ] `client_max_body_size` set to match `MAX_CONTENT_LENGTH`
- [ ] SSL certificate installed and auto-renewing
- [ ] Firewall rules: only 80/443 exposed
- [ ] Disk space monitoring on upload folder
- [ ] Log rotation configured

## Post-release Verification

- [ ] Register a new user via web
- [ ] Upload a file and get a pickup code
- [ ] Download using the pickup code from a different browser/session
- [ ] Verify file content matches
- [ ] Login on Flutter app
- [ ] Upload from Flutter app, download on web (and vice versa)
- [ ] Check admin console loads and shows correct stats
- [ ] Verify cleanup scheduler logs appear

## Known Limitations (v1.0)

- Same-account device relay (WebSocket streaming) is API-defined but not yet wired
- LAN peer-to-peer transfer not yet implemented
- Bluetooth transfer not yet implemented
- Device registration UI not yet built
- iOS build requires macOS (not verified on Windows/Linux CI)
- Android APK build requires access to Google Maven repositories

## Rollback Plan

1. Keep the previous deployment artifact (dist/, APK, etc.)
2. Database rollback: `flask db downgrade` (if migrations were applied)
3. Restore upload folder from backup if files were affected
4. Point nginx back to the previous web build directory
