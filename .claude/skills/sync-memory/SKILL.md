---
name: sync-memory
description: Compress the current project state into the memory directory so future sessions can resume without rereading everything.
disable-model-invocation: true
---
Update the `memory/` directory.

Mandatory behavior:
- refresh only the files that truly changed
- keep wording compressed and factual
- remove stale assumptions
- add date stamps
- keep `memory/current-focus.md` short
- add open questions only if they are still open

At minimum review:
- `memory/project-brief.md`
- `memory/decisions.md`
- `memory/api-contracts.md`
- `memory/roadmap.md`
- `memory/current-focus.md`
- `memory/test-strategy.md`
- `memory/handoff.md`
