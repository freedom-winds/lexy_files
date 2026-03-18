---
name: implement-slice
description: Implement one vertical feature slice across backend and clients with tests and a concise verification summary.
disable-model-invocation: true
argument-hint: [feature-name]
---
Implement one bounded vertical slice for: $ARGUMENTS

Rules:
- do not start until the relevant API contract exists or is updated
- prefer shared packages first
- implement backend before broad client wiring
- add tests as you go
- verify the smallest useful end-to-end flow
- update memory after completion

Typical delegation:
- backend code -> `backend-implementer`
- web UI -> `web-frontend-implementer`
- mobile client -> `mobile-implementer`
- desktop client -> `desktop-implementer`
- verification -> `qa-test-runner`

End with:
- changed files
- what was verified
- remaining gaps
- next recommended slice
