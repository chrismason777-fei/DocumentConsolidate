# AGENTS.md — TaskFlow
# com.nianshouapps.piggytasks | Swift 6 | SwiftUI | SwiftData | HealthKit | WatchConnectivity | CloudKit

## Session Start

At the beginning of a new working session, begin the first response with:

CHALLENGE: onryo
RESPONSE: I have read AGENTS.md. I will not build without an implementation task. I will not rewrite working code. Diffs only.

After providing the challenge response, continue processing any implementation task contained in the same user message. Do not stop or require the user to repeat the task.

## Operating Rules

1. **READ BEFORE WRITE** — Read all referenced files and relevant local documentation before proposing or making changes.
2. **DIFFS ONLY** — Modify only the minimum necessary lines. Never rewrite a working file unless it is explicitly approved for rewrite. Any rewrite exceeding 50 lines requires permission.
3. **PLAN AND APPROVAL** — Before making changes, provide exactly three concise execution-plan bullets and state any blocking ambiguity within them. Wait for explicit user approval unless the implementation task itself clearly states that the plan or milestone has already been approved and instructs implementation to proceed. An approved implementation task transferred from the engineering discussion is sufficient approval and must not require a second approval.
4. **ONE PHASE AT A TIME** — Complete and verify the approved phase before proposing or beginning another phase.
5. **SYNC CHECK** — Before implementation, report the current Git branch, working-tree status, and latest commit hash. Do not discard or overwrite uncommitted work.
6. **STOP ON MATERIAL AMBIGUITY** — Stop when a missing file, unclear requirement, conflicting instruction, or undecided design choice prevents a safe implementation. Do not guess.
7. **NO AUTOMATED TESTS** — Do not create or run unit, UI, integration, or other automated tests unless explicitly instructed.
8. **NO NEW FILES** — Do not create files unless the approved plan explicitly requires them.
9. **RESPONSE LIMIT** — Keep routine responses below 800 tokens. When essential content cannot fit, stop at a clean boundary and ask the user to continue.
10. **MANUAL VERIFICATION** — Conclude every implementation response with one precise, single-line instruction for manual verification on the local machine.
11. **NO CODE PREVIEWS** — Before approval, do not print proposed code, full replacement files, or speculative diffs. Identify the target files and objective only. After approval, make changes through tools and report the resulting diff at a summary level.
12. **COMMIT AND PUSH** — After an approved code change has been manually verified or the user explicitly instructs completion, commit with a descriptive message and run `git push origin HEAD`. Never switch to or push another branch implicitly. Never push to `main` unless `main` is already checked out.

## Project Context

Project structure and architecture: `docs/ai_context/architecture.md`

Read that file before any architecture-sensitive task.

## File Size Rule

Check the line count of every target Swift file before editing it.

If a target file exceeds 250 lines, do not add further implementation directly to it. Propose a narrow split into a base file and one or more focused extensions as part of the three-bullet plan. Perform the split only after explicit approval, then apply the required change.

## Swift 6

- Mark `@Observable` services that mutate UI-observed state as `@MainActor` when those mutations may originate from background work.
- Prefer structured concurrency with `async`/`await`; do not use `DispatchQueue.main.async` for actor isolation.
- Release builds must have zero strict-concurrency warnings.

## SwiftData and CloudKit

- Every `@Model` property must be optional or have a default value.
- Do not use `unique` constraints on `@Model` properties because they are incompatible with the project's CloudKit requirements.
- Relationships require explicit inverses and the approved delete rule, including cascade behavior where required by the data model.
- Before TestFlight, every schema change requires a new `VersionedSchema` and a documented migration plan.
- Views obtain `ModelContext` using `@Environment(\.modelContext)`. Do not pass a `ModelContext` between views.

## Logging

- Use `os.Logger` with subsystem `com.nianshouapps.piggytasks`.
- Do not leave `print()` calls in production code.
- Perform SwiftData mutations through `loggedInsert()`, `loggedDelete()`, and `loggedSave()`.

## Invariants

- Record human-readable timestamps in Singapore Time (SGT).
- Every created or modified source file must retain or receive a header in this format:

```swift
// YYYY-MM-DD HH:MM SGT
```

- Do not change product identifiers, persistence schemas, CloudKit behavior, entitlements, signing, or capabilities unless the approved task explicitly requires it.
