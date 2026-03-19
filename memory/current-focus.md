# Current Focus

_Last updated: 2026-03-19_

## Active objective
Phase 4: Cross-platform verification + E2E tests

## What's done
- Phase 0: Project brief, architecture decisions, API contracts, roadmap — COMPLETE
- Phase 1: Flask backend — COMPLETE (66 tests passing)
- Phase 2: Web frontend — COMPLETE (all pages, admin console, build verified)
- Phase 3: Flutter clients — COMPLETE (Android/iOS/Windows, analyze clean, 1 test passing)

## Next steps — RESUME HERE
1. Add Android internet permission in AndroidManifest.xml
2. Write E2E test script (start backend + run integration flow)
3. Run backend + web together, smoke test manually if possible
4. Verify Flutter builds for Android (flutter build apk --debug)
5. Verify Flutter builds for Windows (flutter build windows --debug)
6. Write additional integration tests for backend API contract
7. Phase 5: Documentation — README, setup docs, architecture notes, deployment guide

## Key technical notes
- Python venv at `backend/venv/` (Python 3.11), activate: `source backend/venv/Scripts/activate`
- npm dependencies installed at `web/node_modules/`
- Flutter at `mobile/`, using Flutter 3.38.10
- Backend tests: `cd backend && source venv/Scripts/activate && python -m pytest tests/ -v`
- Web dev server: `cd web && npm run dev` (port 3000, proxies /api to :5000)
- Web build: `cd web && npm run build` (outputs to web/dist/)
- Flutter analyze: `cd mobile && flutter analyze`
- Flutter test: `cd mobile && flutter test`
- Network: pip install needs `--trusted-host pypi.org` or Aliyun mirror
- SQLite used for tests (naive datetimes, see tz fixes in test_file_service.py)
- Git: large platform dirs (mobile/android, ios, windows) can be slow to stage

## Blocking issues
None
