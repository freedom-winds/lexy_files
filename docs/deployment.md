# Deployment

The deployment source of truth is [../DEPLOY.md](../DEPLOY.md).

That guide covers all four release deliverables:

- Backend with Flask-Migrate/Alembic, Local or S3 storage, Gunicorn/eventlet,
  Nginx, HTTPS, and rollback.
- Web with `VITE_API_BASE_URL`, `VITE_SOCKET_URL`, lint, type-check, and build.
- Mobile Android/iOS with release signing, permissions, and
  `--dart-define=API_BASE_URL=... --dart-define=WS_URL=...`.
- Desktop Windows/Linux with Flutter packaging outputs and release commands.

Before publishing, complete [release-checklist.md](release-checklist.md).
