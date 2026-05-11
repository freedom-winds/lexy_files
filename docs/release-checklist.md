# Release Checklist

## Automated Gate

### Backend

- [ ] `cd backend && python -m pytest -q`
- [ ] `cd backend && python -m flake8 app tests --max-line-length=120`
- [ ] `cd backend && flask db upgrade`
- [ ] `cd backend && flask db downgrade`
- [ ] Local storage smoke test: upload, pickup, download, delete
- [ ] S3/MinIO smoke test: upload, pickup, download, delete a large file

### Web

- [ ] `cd web && npm run lint`
- [ ] `cd web && npx tsc --noEmit`
- [ ] `cd web && npm run build`

### Mobile

- [ ] `cd mobile && flutter analyze`
- [ ] `cd mobile && flutter test`
- [ ] Android release APK builds with production `--dart-define`
- [ ] Android release AAB builds with production `--dart-define`
- [ ] iOS release build passes on macOS/Xcode

### Desktop

- [ ] Windows release build passes with production `--dart-define`
- [ ] Linux release build passes with production `--dart-define`

## Manual Acceptance Matrix

Use `https://files.example.com` or the target production domain.

| Scenario | Backend | Web | Android | iOS | Windows | Linux |
|---|---:|---:|---:|---:|---:|---:|
| Anonymous upload returns pickup code | N/A | [ ] | [ ] | [ ] | [ ] | [ ] |
| Anonymous pickup download works | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Register/login/logout | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Registered upload/list/delete | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Same-account relay request/accept/send | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Relay reject/cancel/offline failure states | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| LAN discovery and file send | N/A | N/A | [ ] | [ ] | [ ] | [ ] |
| Bluetooth discovery and file send | N/A | N/A | [ ] | [ ] | [ ] | [ ] |
| Admin users/files/groups/stats | [ ] | [ ] | N/A | N/A | N/A | N/A |

## Security Gate

- [ ] `SECRET_KEY` and `JWT_SECRET_KEY` are not defaults
- [ ] `CORS_ORIGINS` and `SOCKETIO_CORS_ORIGINS` are production domains only
- [ ] HTTPS certificate installed and auto-renewing
- [ ] Redis is not publicly exposed
- [ ] MySQL credentials are strong and not defaults
- [ ] Android keystore, Apple signing assets, S3 credentials, and CI secrets are not committed
- [ ] Upload directory has no execute permissions

## Release Artifacts

- [ ] Backend service revision/tag recorded
- [ ] Web `dist/` artifact stored
- [ ] Android APK and AAB stored
- [ ] iOS archive/IPA/TestFlight build recorded
- [ ] Windows release bundle or installer stored
- [ ] Linux release bundle/package stored

## Rollback Preparedness

- [ ] Previous backend and Web artifacts retained
- [ ] Database backup completed before migration
- [ ] Upload folder or S3 bucket backup policy verified
- [ ] Rollback command sequence from `DEPLOY.md` reviewed
