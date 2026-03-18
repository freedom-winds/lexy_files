# API Contracts

_Last updated: 2026-03-18_

## Current API style
REST JSON API. Base path: `/api/v1`. WebSocket at `/ws`.

## Auth model
- **JWT Bearer tokens** in `Authorization: Bearer <token>` header
- Access token: 15 min TTL, refresh token: 30 day TTL
- Anonymous users: auto-issued token tied to IP + device fingerprint
- Endpoints: `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`

## Core resources

### Auth
```
POST   /api/v1/auth/register        — { username, email, password } → { user, tokens }
POST   /api/v1/auth/login            — { username, password } → { user, tokens }
POST   /api/v1/auth/refresh          — { refresh_token } → { access_token }
POST   /api/v1/auth/logout           — revoke refresh token
GET    /api/v1/auth/me               — current user profile
POST   /api/v1/auth/anonymous        — { device_id, fingerprint } → { user, tokens }
```

### Files (Pickup Code / Direct Link mode)
```
POST   /api/v1/files/upload          — multipart file upload → { file_id, pickup_code, download_url, expires_at }
GET    /api/v1/files/pickup/:code    — get file metadata by pickup code
GET    /api/v1/files/download/:id    — download file (speed-limited, quota-checked)
GET    /api/v1/files                 — list user's uploaded files
DELETE /api/v1/files/:id             — delete own file
```

### Devices
```
GET    /api/v1/devices               — list user's registered devices
POST   /api/v1/devices               — register device { name, type, platform, device_id }
DELETE /api/v1/devices/:id           — unregister device
PUT    /api/v1/devices/:id/online    — mark device online (heartbeat)
```

### Transfer Sessions
```
POST   /api/v1/transfers             — initiate transfer { mode, target_device_id, file_metadata }
GET    /api/v1/transfers/:id         — get transfer status
PUT    /api/v1/transfers/:id/accept  — accept incoming transfer
PUT    /api/v1/transfers/:id/reject  — reject incoming transfer
DELETE /api/v1/transfers/:id         — cancel transfer
```

### Admin
```
GET    /api/v1/admin/users                — list/search users (paginated)
PUT    /api/v1/admin/users/:id/group      — change user group
PUT    /api/v1/admin/users/:id/quota      — set per-user quota overrides
PUT    /api/v1/admin/users/:id/ban        — ban/unban user
POST   /api/v1/admin/users/:id/kick       — force user/devices offline
GET    /api/v1/admin/files                — list/search all files (paginated)
GET    /api/v1/admin/files/:id/download   — admin download any file
PUT    /api/v1/admin/files/:id/expire     — force-expire file
DELETE /api/v1/admin/files/:id            — force-delete file (bypasses grace period)
GET    /api/v1/admin/groups               — list user group defaults
PUT    /api/v1/admin/groups/:name         — update group default quotas
GET    /api/v1/admin/stats                — system stats (storage, users, transfers)
```

### WebSocket events
```
WS /ws — authenticated WebSocket connection

Events (server → client):
  transfer.request     — incoming transfer request
  transfer.accepted    — transfer accepted by recipient
  transfer.rejected    — transfer rejected
  transfer.progress    — transfer progress update
  transfer.complete    — transfer finished
  device.online        — another device came online
  device.offline       — another device went offline

Events (client → server):
  transfer.data        — file chunk (same-account relay mode)
  transfer.cancel      — cancel in-progress transfer
  device.heartbeat     — keep-alive ping
```

## Error model
```json
{
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "Daily download traffic quota exceeded",
    "details": { "limit": 1073741824, "used": 1073741824, "resets_at": "2026-03-19T00:00:00Z" }
  }
}
```
Standard error codes: `UNAUTHORIZED`, `FORBIDDEN`, `NOT_FOUND`, `VALIDATION_ERROR`, `QUOTA_EXCEEDED`, `FILE_TOO_LARGE`, `STORAGE_FULL`, `RATE_LIMITED`, `FILE_EXPIRED`, `TRANSFER_FAILED`, `DEVICE_OFFLINE`, `SERVER_ERROR`.

HTTP status codes: 400 (validation), 401 (auth), 403 (forbidden/banned), 404 (not found), 409 (conflict), 413 (file too large), 429 (rate limited), 500 (server error).

## Pagination
```
GET /api/v1/admin/users?page=1&per_page=20&sort=created_at&order=desc&q=search
→ { "data": [...], "pagination": { "page": 1, "per_page": 20, "total": 150, "pages": 8 } }
```

## Versioning notes
- API versioned via URL path `/api/v1/`
- Breaking changes require new version
- No version negotiation needed for v1

## Open contract questions
- WebRTC signaling protocol for LAN transfer (deferred to LAN implementation phase)
- Chunked upload protocol for large files (consider tus.io)
