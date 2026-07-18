# Document Consolidator

## Product Definition

**Stage 1 – Product Overview & Existing Decisions**

---

# Product Overview

## Product Name

**Document Consolidator**

---

## Product Type

Internal productivity utility.

Native macOS application.

Not intended for commercial release.

---

## Product Status

**Conceptual MVP**

The product has been extensively discussed and its core purpose, workflow and design philosophy have already been validated.

This Product Definition exists to convert that conceptual MVP into an authoritative Release 1 definition.

Previously agreed decisions form the baseline for this document.

---

# Mission

Document Consolidator enables safe consolidation of documentation into a single authoritative document set while ensuring that no documents are lost.

---

# Primary User

The primary (and only) intended user for Release 1 is the developer responsible for maintaining the Nian Shou documentation ecosystem.

---

# Primary Problem

Documentation currently exists across multiple folder trees.

Over time this leads to:

- uncertainty over which copy is authoritative
- duplicate documents
- obsolete revisions
- inconsistent organisation
- manual reconciliation effort
- fear of deleting the wrong document

---

# Product Goal

Provide a safe, deterministic workflow that allows documentation to be reviewed, consolidated and archived with confidence.

The application should reduce organisational effort while never compromising document safety.

---

# Design Philosophy

Release 1 is intentionally conservative.

The application should favour safety over convenience.

Whenever confidence is insufficient to make a recommendation, the application should request user review rather than making assumptions.

---

# Core Principles

The following principles have already been agreed.

## Local Only

- No cloud services.
- No networking.
- No external dependencies.

---

## Deterministic

Recommendations are based on objective evidence.

The application does not attempt to infer intent using AI.

---

## Safe

Documents are archived rather than deleted.

Every operation must be reversible.

---

## Non-Destructive

Release 1 never performs destructive filesystem operations.

Existing documents are never overwritten or permanently deleted.

Whenever an operation would replace an existing document, the existing document is first preserved.

This guarantees that every filesystem operation remains recoverable.

---

## Transparent

Every recommendation should clearly explain the evidence used to reach it.

---

## User Controlled

No filesystem changes occur without explicit user approval.

---

## Trustworthy

The application should prioritise confidence over automation.

A recommendation of **Review** is preferable to an incorrect recommendation.

---

# Existing Release 1 Workflow

The following workflow has already been agreed.

1. Select folder trees
2. Scan
3. Build internal inventory
4. Generate recommendations
5. User review
6. Dry run
7. Execute approved actions
8. Verify execution
9. Produce audit log
10. Restore if required

---

# Recommendation Categories

- Keep
- Move
- Merge
- Review
- Archive

---

# Recommendation Evidence

The recommendation engine should rely on deterministic evidence including:

- SHA-256 hashes
- relative paths
- document families
- modification dates
- file sizes

Filename similarity alone must never be sufficient evidence.

---

# Scope Exclusions

Release 1 does not operate on:

- source code
- Git repositories
- build products
- generated files
- dependency folders
- repository operational files

---

# Product Exclusions

Release 1 explicitly excludes:

- AI
- cloud synchronisation
- background monitoring
- scheduled scanning
- automatic file operations
- source code management
- document editing
- general-purpose file management
- App Store distribution

---

# Success Definition

Release 1 will be considered successful if the user can confidently:

- scan documentation trees
- identify authoritative documents
- consolidate documentation safely
- archive obsolete material
- restore previous actions if necessary

without concern that documents may be lost or existing documents overwritten.

---

# Stage 1 Assessment

Stage 1 captures the agreed conceptual MVP and establishes the baseline for Release 1.

The remaining Product Definition work will focus only on unresolved areas rather than revisiting decisions that have already been agreed.

---

# Open Decision

## Scan Session Persistence

**Recommendation**

Scan Sessions should be persistent.

Each Scan Session should record:

- selected root folders
- scan timestamp
- inventory snapshot
- recommendations
- approved actions
- execution results
- audit history

Persistent Scan Sessions provide:

- a complete audit trail
- support for restoring previous operations
- the ability to pause and resume consolidation work
- historical evidence of previous cleanup activities

Scan Sessions may be deleted by the user when no longer required but should be retained by default.

---

## Stage Status

**Status:** Awaiting Approval

Once approved, proceed to **Stage 2 – Functional Definition**.
# Document Consolidator

## Product Definition

**Stage 2 – Functional Definition**

---

# Purpose

This stage defines the functionality required for Release 1.

The objective is to describe **what the application must do**, not how it will be implemented.

The feature set should remain intentionally small and focused on the core mission.

---

# Release 1 Functional Areas

Release 1 consists of five functional areas.

1. Scan
2. Inventory
3. Review
4. Execute
5. Restore

No additional functional areas are planned for Release 1.

---

# Functional Area 1 – Scan

## Objective

Discover documentation contained within one or more selected folder trees.

---

## User Capabilities

The user can:

- choose one or more root folders
- begin a new scan
- reopen an existing Scan Session
- refresh an existing scan
- cancel an in-progress scan

---

## Expected Behaviour

The application shall:

- recursively inspect all selected folders
- identify supported documentation files
- ignore excluded file types and folders
- record sufficient metadata for later analysis
- create a new Scan Session

No filesystem changes occur during scanning.

---

# Functional Area 2 – Inventory

## Objective

Create a complete internal representation of the discovered documentation.

---

## User Capabilities

The user can:

- browse discovered documents
- search the inventory
- filter inventory contents
- inspect document details

---

## Expected Behaviour

Each document should be represented by metadata sufficient for recommendation generation.

Examples include:

- filename
- location
- document hash
- file size
- timestamps
- document classification

The inventory represents the current state of the scanned folders.

---

# Functional Area 3 – Review

## Objective

Present deterministic recommendations before any filesystem changes occur.

---

## User Capabilities

The user can:

- review every recommendation
- inspect supporting evidence
- accept recommendations
- reject recommendations
- change recommendations
- mark items for later review

---

## Recommendation Types

Release 1 supports:

- Keep
- Move
- Merge
- Review
- Archive

---

## Design Principles

Recommendations should:

- explain why they were generated
- present supporting evidence
- never hide uncertainty
- favour Review whenever confidence is insufficient

---

# Functional Area 4 – Execute

## Objective

Safely perform approved non-desctructive filesystem operations.

---

## User Capabilities

The user can:

- perform a dry run
- execute approved actions
- cancel before execution

---

## Expected Behaviour

Immediately before execution the application shall:

- revalidate affected files
- confirm files have not changed
- abort execution if inconsistencies are detected

During execution the application shall:

- process approved actions
- verify each completed operation
- record execution results
- produce an audit log

If verification fails, the application shall clearly identify the affected operation.

Whenever an approved operation would replace an existing document, the application shall:

- preserve the existing document
- complete the approved operation without overwriting preserved data
- verify both preservation and execution

---

# Functional Area 5 – Restore

## Objective

Allow previously executed actions to be reversed where possible.

Restore operations are possible because Release 1 preserves existing documents before replacement rather than performing destructive updates.

---

## User Capabilities

The user can:

- inspect previous execution history
- select an execution session
- restore archived documents
- reverse supported operations

---

## Design Principles

Restore should prioritise safety.

The application should never overwrite existing files without explicit confirmation.

---

# Scan Session

A Scan Session represents a complete consolidation activity.

Each Scan Session records:

- selected folders
- scan date
- inventory snapshot
- generated recommendations
- user decisions
- execution history
- verification results
- audit information

Scan Sessions are persistent by default.

---

# Audit

Every execution produces an audit record.

The audit should provide sufficient information to understand:

- what changed
- why it changed
- when it changed
- who approved it
- whether verification succeeded

---

# Release 1 Success Criteria

Release 1 is complete when a user can:

- scan documentation
- understand recommendations
- confidently approve actions
- safely execute consolidation
- restore previous actions if required

without requiring external tools.

---

# Explicit Non-Goals

Release 1 will not include:

- automatic recommendations being applied
- AI-assisted decision making
- document editing
- duplicate content comparison
- OCR
- cloud storage
- background monitoring
- scheduling
- collaboration
- multi-user support
- version control integration
- workflow automation

These capabilities may be considered in future releases but are intentionally excluded from Release 1.

---

## Stage 2 Assessment

Release 1 functionality is intentionally minimal.

Every feature directly supports the mission:

> Safely consolidate documentation into a single authoritative document set without risking data loss.

No additional functionality should be added unless it materially contributes to that mission.

---

## Stage Status

**Status:** Awaiting Approval

Once approved, proceed to **Stage 3 – User Experience & Workflow**.
# Document Consolidator

## Product Definition

**Stage 3 – User Experience & Workflow**

---

# Purpose

This stage defines how the user interacts with the application.

It focuses on creating a workflow that is safe, understandable and efficient while remaining deliberately simple.

The objective is not to define user interface layouts, but to define the experience the application should provide.

---

# User Experience Principles

The application should feel:

- predictable
- deliberate
- trustworthy
- transparent
- safe
- calm

The application should never pressure the user into making decisions.

Every action should feel reversible.

---

# Primary Workflow

Release 1 follows a linear workflow.

```
Select Folders
        ↓
Create Scan Session
        ↓
Scan
        ↓
Inventory
        ↓
Recommendations
        ↓
User Review
        ↓
Dry Run
        ↓
Execute
        ↓
Verification
        ↓
Audit
```

Users should always know where they are within this process.

---

# Scan Sessions

A Scan Session is the central working object.

The application should make it easy to:

- create a new session
- continue a previous session
- inspect completed sessions
- review historical audit information

Users should never need to remember where they left off.

---

# User Decisions

Every recommendation should require a conscious decision.

The application should never make filesystem changes automatically.

For every recommendation the user should be able to:

- approve
- reject
- modify
- postpone

The application should remember these decisions within the Scan Session.

---

# Recommendation Presentation

Recommendations should be presented clearly.

Each recommendation should answer:

- What was found?
- What action is recommended?
- Why?
- What evidence supports the recommendation?
- What will happen if approved?

The user should never need to guess why a recommendation exists.

---

# Confidence

Confidence should be communicated honestly.

High confidence should be reserved for recommendations supported by strong deterministic evidence.

Whenever confidence is insufficient, the recommendation should become:

**Review**

rather than attempting to infer user intent.

---

# Safety Before Speed

The workflow should intentionally prioritise correctness.

The application should never optimise by:

- skipping validation
- hiding warnings
- automatically selecting recommendations
- executing immediately after scanning
- overwriting existing documents

---

# Dry Run

Before execution the application should provide a complete preview.

The preview should answer:

- What files will change?
- What folders are affected?
- What will be archived?
- What will remain unchanged?

No filesystem changes occur during the dry run.

---

# Execution

Execution should be deliberate.

Immediately before execution the application should perform a final validation.
If an approved operation would replace an existing document, the application shall preserve the existing document before continuing.

If anything has changed since the scan, execution should stop.

The user should be informed why execution cannot continue.

---

# Verification

Execution is not complete until verification succeeds.

Verification should confirm that every approved operation completed successfully.

If verification detects an unexpected outcome, the application should clearly identify the affected operation.

---

# Completion

When execution finishes successfully, the application should provide a clear completion summary.

The summary should include:

- files processed
- actions performed
- archives created
- warnings
- verification status

The user should leave the session confident that consolidation completed successfully.

The completion summary should identify any documents preserved as part of non-destructive operations.

---

# Restore Experience

Restoration should be as straightforward as execution.

Users should be able to:

- browse previous executions
- understand what changed
- restore supported operations
- confirm restoration before execution

Restore should feel like a normal workflow rather than an emergency recovery process.

---

# Error Handling

Errors should always be actionable.

The application should explain:

- what happened
- why it happened (where known)
- what was not completed
- how the user can recover

Technical implementation details should not be exposed unless they assist recovery.

---

# Release 1 Simplicity

The interface should remain intentionally focused.

Every screen should support one stage of the workflow.

Avoid:

- dashboards
- complex navigation
- unnecessary configuration
- multiple ways to perform the same task

The application exists to solve one problem well.

---

# Overall Experience

By the end of a Scan Session the user should feel:

- confident
- informed
- in control

The application should earn trust through transparency and predictable behaviour rather than automation.

---

## Stage 3 Assessment

The Release 1 workflow is intentionally linear and conservative.

The application guides the user through a single consolidation process from beginning to end, ensuring that every significant decision remains visible and under the user's control.

This experience directly supports the core mission of safely consolidating documentation without risking data loss.

---

## Stage Status

**Status:** Awaiting Approval**

Once approved, proceed to **Stage 4 – Release 1 Scope & Success Criteria**.
