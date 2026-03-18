# Current Focus

_Last updated: 2026-03-18_

## Active objective
Phase 2: Build web frontend with React/TypeScript + Admin Console

## What's done
- Phase 0: Project brief, architecture decisions, API contracts, roadmap — COMPLETE
- Phase 1: Flask backend — COMPLETE (66 tests passing)
  - All models, services, API endpoints, auth, quotas, file lifecycle, admin
  - Backend at `backend/` with Python 3.11 venv
- Phase 2 (partial): Web frontend scaffolded at `web/`
  - Vite + React + TypeScript + Tailwind CSS + lucide-react
  - Core files created: Layout, AuthProvider, api client, HomePage, LoginPage, FileUpload, PickupCodeInput, ProtectedRoute, AdminRoute
  - **AuthProvider fixed** to match backend response shape (`{user, tokens}`)
  - vite.config.ts configured with proxy to Flask backend

## In-progress tasks — RESUME HERE
1. Fix `App.tsx` — still has Vite default template, needs router setup
2. Fix `main.tsx` — needs BrowserRouter + AuthProvider wrapping
3. Fix `getApiError` in `utils.ts` — backend returns `{error: {code, message}}`, not `{error: string}`
4. Create missing pages:
   - `src/pages/RegisterPage.tsx`
   - `src/pages/PickupPage.tsx`
   - `src/pages/MyFilesPage.tsx`
   - `src/pages/admin/AdminLayout.tsx`
   - `src/pages/admin/AdminUsersPage.tsx`
   - `src/pages/admin/AdminFilesPage.tsx`
   - `src/pages/admin/AdminGroupsPage.tsx`
   - `src/pages/admin/AdminStatsPage.tsx`
5. Delete unused files: `src/App.css`, `src/assets/hero.png`, `src/assets/react.svg`, `src/assets/vite.svg`
6. Verify web frontend builds (`npm run build`)

## After web frontend
- Build Flutter clients (Android/iOS/Desktop)
- Implement WebSocket relay for same-account transfers
- LAN/Bluetooth transfer support
- End-to-end testing
- Documentation

## Key technical notes
- Python venv at `backend/venv/` (Python 3.11), activate: `source backend/venv/Scripts/activate`
- npm dependencies installed at `web/node_modules/`
- Backend tests: `cd backend && source venv/Scripts/activate && python -m pytest tests/ -v`
- Web dev server: `cd web && npm run dev` (port 3000, proxies /api to :5000)
- Network: pip install needs `--trusted-host pypi.org` or Aliyun mirror; Tsinghua mirror has SSL issues
- SQLite used for tests (naive datetimes, see tz fixes in test_file_service.py)
- FileUpload result shape from backend: `{id, pickup_code, download_url, original_filename, file_size, ...}`

## Blocking issues
None
