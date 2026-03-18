---
name: api-contract
description: Define or revise the contract-first API before broad client implementation begins.
disable-model-invocation: true
argument-hint: [feature or domain]
---
Define or update the API contract for $ARGUMENTS.

Include:
- resources / endpoints / workflows
- request and response schemas
- auth expectations
- error model
- pagination / filtering / sorting rules if relevant
- idempotency requirements if relevant
- versioning notes
- generated SDK plan if applicable

Update:
- `memory/api-contracts.md`
- `memory/current-focus.md`

Use the `api-designer` subagent if the task is substantial.
