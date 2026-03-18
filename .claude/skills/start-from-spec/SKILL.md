---
name: start-from-spec
description: Start a greenfield project from requirement and design documents. Use at the beginning of a project or when resetting direction.
disable-model-invocation: true
argument-hint: [optional focus]
---
Start from the available specification material.

Process:
1. Use the `requirements-analyst` subagent to read all requirement and design files.
2. Create or refresh the required files in `memory/`.
3. Produce:
   - project brief
   - assumptions list
   - unresolved questions
   - initial architecture options
   - first implementation roadmap
4. If architecture is not yet settled, hand off to the `system-architect` subagent.
5. End with one recommended first vertical slice.

Optional focus: $ARGUMENTS
