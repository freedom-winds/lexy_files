# Test Strategy

_Last updated: 2026-03-18_

## Unit tests
- **Backend models**: User, File, Device, Transfer, Quota — CRUD, validation, lifecycle transitions
- **Auth logic**: Token generation, validation, refresh, anonymous user consolidation
- **Quota engine**: Speed limiting, storage calculation, traffic tracking, group limits
- **File lifecycle**: Expiration, redemption period, deletion scheduling
- **Pickup code generation**: Uniqueness, format, collision avoidance

## Integration tests
- **Auth flow**: Register → login → refresh → access protected endpoint → logout
- **File upload flow**: Upload → get pickup code → download by code → verify content
- **Quota enforcement**: Upload beyond limit → rejected; download beyond traffic → throttled
- **File lifecycle**: Upload → expire → verify in redemption → wait → verify deleted
- **Admin operations**: Change user group, ban user, force-expire file, force-delete file
- **Anonymous user consolidation**: Same IP different device → same anonymous user

## API contract checks
- All endpoints return correct HTTP status codes
- Error responses match error model schema
- Pagination responses match pagination schema
- File upload respects size limits per user group

## Client smoke tests
- **Web**: Can load, register, login, upload file, get pickup code, download by code
- **Flutter**: Can launch, login, upload file, list devices, initiate transfer

## End-to-end flow
**Happy path**: Register user → upload file on web → get pickup code → download on different session → verify file integrity → verify quota deduction → verify file appears in user's file list → delete file → verify deletion

## Known gaps
- Bluetooth transfer testing requires physical devices (cannot automate)
- LAN transfer testing requires network setup (can simulate with loopback)
- WebSocket relay load testing deferred
- iOS build verification requires macOS
