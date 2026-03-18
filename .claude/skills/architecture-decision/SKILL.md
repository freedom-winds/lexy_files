---
name: architecture-decision
description: Produce or refresh the architecture decision memo, stack choice, repo layout, and shared-package plan for a multi-platform product.
disable-model-invocation: true
---
Create or update the architecture decision memo.

Requirements:
- optimize for reuse across backend, web, Android, iOS, and desktop
- compare the strongest realistic stack options
- recommend one stack with explicit trade-offs
- define repo layout and shared-package boundaries
- define backend and API strategy
- define client reuse strategy
- update `memory/decisions.md`, `memory/roadmap.md`, and `memory/current-focus.md`

Use the `system-architect` subagent for analysis when helpful.
