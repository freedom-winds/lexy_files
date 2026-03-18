# CLAUDE.md

This repository starts from requirements only. Your job is to take the project from zero to a working, tested product with a professional engineering workflow.

## Operating principles

- Work in English unless the user explicitly asks otherwise.
- Be proactive, but not reckless. Default to making conservative, reversible choices.
- Keep the main thread focused on goals, decisions, and acceptance criteria.
- Delegate local implementation, code search, test execution, and narrow reviews to subagents whenever the task is self-contained.
- Prefer one end-to-end vertical slice early, then expand breadth.
- Optimize for code reuse, testability, and maintainability over short-term speed.
- NEVER BE LAZY FOR ANY TASKS.

## High-level delivery flow

Follow this order unless the user explicitly overrides it:

1. Read all available requirement and design documents.
2. Produce a concise project brief:
   - problem statement
   - target users
   - platforms
   - constraints
   - assumptions
   - unresolved questions
   - acceptance criteria
3. Produce an architecture decision memo before major coding starts.
4. Define API contracts before large frontend implementation.
5. Implement the backend foundation and one thin vertical slice.
6. Verify the slice with automated tests.
7. Expand feature-by-feature across all clients.
8. Run cross-platform verification and integration checks.
9. Prepare developer documentation, setup docs, and release notes.

Do not jump straight into broad implementation before steps 1-4 are complete.

## Default architecture policy

Because this is a greenfield multi-platform project, prioritize maximum reuse.

- Prefer a monorepo.
- Prefer shared domain models, shared API schemas, and generated SDKs.
- Prefer a contract-first API workflow.
- Prefer a shared design system and shared validation logic.
- Prefer shared authentication, networking, configuration, and error-handling packages.
- Minimize platform-specific code and isolate it behind adapters.

When stack choice is still open, compare at least these options:

- Option A: Flutter client stack for strongest single-codebase reuse across web, Android, iOS, and desktop.
- Option B: TypeScript monorepo with shared packages, React web, React Native / Expo mobile, and desktop wrapper when ecosystem fit matters more than absolute UI reuse.

Pick one only after writing down the trade-offs. If requirements clearly favor one option, choose it and document why.

## Decision policy

Only interrupt the user for questions that materially affect:
- architecture
- product scope
- compliance / security
- external accounts, credentials, billing, or provider selection
- irreversible migrations or destructive actions

Batch questions. Do not ask one small question at a time.

If a choice is missing but non-critical, choose a sensible default, record it in memory, and continue.

## API-first policy

Before building substantial client features:

- define resources, workflows, and auth model
- define request / response schemas
- define error model
- define pagination, filtering, sorting, and idempotency conventions where relevant
- define versioning strategy
- generate or maintain typed client bindings when possible

Do not let frontend and backend drift independently.

## Platform delivery policy

Treat each platform as a client of the same product, not as a separate product.

Required delivery targets:
- backend
- web client
- Android APK
- iOS app
- desktop client
- end-to-end test path

For each feature, explicitly state:
- shared logic
- shared UI or shared components
- platform-specific adaptations
- test coverage

## Testing policy

Every meaningful implementation phase must include verification.

At minimum, provide:
- unit tests for critical business logic
- integration tests for core backend flows
- API contract checks
- smoke tests for each client
- one end-to-end happy-path flow that exercises the real product flow

If UI work is changed, verify visually when tooling allows.
If something cannot be tested automatically, state the gap explicitly.

## Task slicing policy

Prefer small, reviewable slices:
- one domain capability at a time
- one API area at a time
- one screen / route cluster at a time
- one integration at a time

Do not create giant speculative scaffolds without wiring them into a working flow.

## Subagent policy

Use subagents for:
- codebase investigation
- API contract drafting
- feature implementation in a narrow scope
- test execution and failure analysis
- code review
- documentation drafts

Do not let subagents make broad architectural decisions without main-thread review.
Do not let implementation subagents rewrite unrelated areas.
Ask subagents to return concise findings, file lists, risks, and next actions.

## Memory policy

This repository maintains a `memory/` directory to compress project context and reduce token waste.

Use it aggressively but cleanly:
- update it after every major decision
- update it after stack selection
- update it after API contract changes
- update it after each major feature slice
- update it when discovering hidden constraints, edge cases, or failed approaches worth remembering

Always prefer updating an existing memory file over creating many tiny files.

### Required memory files

- `memory/project-brief.md`
- `memory/decisions.md`
- `memory/api-contracts.md`
- `memory/roadmap.md`
- `memory/current-focus.md`
- `memory/test-strategy.md`
- `memory/handoff.md`

### Memory writing rules

When updating memory:
- keep it compressed and high signal
- record facts, not chatty narration
- include dates
- record rationale for non-obvious decisions
- record open questions separately from settled decisions
- keep `current-focus.md` very short

Before reading large swaths of old conversation, first check whether the answer is already in `memory/`.

## Documentation outputs

Keep the following documents current once they exist:
- README
- setup / bootstrap docs
- architecture decision records
- API spec
- testing / QA docs
- deployment notes
- release checklist

## Git / change policy

- Make small commits with descriptive messages.
- Keep generated files out of commits unless intentionally needed.
- Before large refactors, create a checkpoint or isolated worktree if available.
- Prefer reversible changes over sweeping rewrites.

## Communication style

When reporting progress:
- state what was done
- state what was verified
- state what is blocked or still assumed
- state the next smallest useful step

Be concise and concrete.

## Failure policy

When blocked:
1. identify the exact blocker
2. propose 1-3 viable options
3. recommend one option with rationale
4. continue on the least risky path if possible

Never pretend something was tested if it was not tested.
Never claim a platform is complete unless it was built and verified.

## First-session behavior

At the start of a new project from requirements only:

1. read the requirements
2. create or update the required memory files
3. write a project brief
4. write an architecture decision memo
5. write an initial implementation roadmap
6. propose the first vertical slice
7. only then start implementation
