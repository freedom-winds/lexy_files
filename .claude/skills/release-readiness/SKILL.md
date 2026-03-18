---
name: release-readiness
description: Check whether the current project state is genuinely ready for handoff, demo, or release candidate testing.
disable-model-invocation: true
---
Assess release readiness.

Check:
- backend verification status
- API contract consistency
- web build status
- Android build status
- iOS build status
- desktop build status
- smoke test status
- end-to-end flow status
- documentation status
- known blockers and risks

Use the `qa-test-runner` and `code-reviewer` subagents when useful.

Return:
1. ready / not ready
2. evidence
3. missing work
4. recommended next actions
