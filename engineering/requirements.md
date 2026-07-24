# Requirements

**Project:** Document Consolidator

**Status:** Release 1

---

# Purpose

This document defines the engineering requirements for Release 1.

It is derived from the approved Product Definition and Release1Scope documents and is the authoritative source of required behaviour for implementation.

---

# Functional Requirements

## RQ-001 — Scan Sources

The application shall scan one or more user-selected folders.

The scan shall identify supported document types.

The scan shall create a Scan Session representing the complete snapshot of the analysed folders.

---

## RQ-002 — Inventory

The application shall maintain an inventory of all discovered documents within a Scan Session.

The inventory shall include sufficient metadata to support recommendation generation and audit reporting.

---

## RQ-003 — Exact Duplicate Archival Proposals

DocumentConsolidate identifies byte-identical duplicate files, establishes one definitive retained copy for each duplicate group, and archives the redundant copies after explicit user approval. It does not merge documents, interpret semantic similarity, reorganise unique documents, or provide general document-management functionality in Release 1.

Duplicate grouping and archive proposals shall be deterministic.

Identical inputs shall produce identical grouping and proposal output.

Unique files receive no duplicate archive proposal or archive-plan operation. A definitive copy may be proposed automatically only through an approved deterministic rule; otherwise, the user selects exactly one definitive copy. Every other file in that exact duplicate group becomes a redundant archive candidate. Release 1 does not support excluding individual files from a duplicate group.

---

## RQ-004 — User Review

Archive proposals shall never be executed automatically.

Approval applies only to archival of redundant byte-identical copies. Rejected, postponed, and Needs Selection groups shall not enter the archive plan.

---

## RQ-005 — Dry Run

Users shall be able to preview every proposed filesystem operation before execution.

No filesystem modifications shall occur during a Dry Run.

---

## RQ-006 — Execution

Execution shall perform only approved operations.

Execution shall be non-destructive: the application shall never permanently destroy user data.

Each archive operation shall be a verified relocation. The application shall copy the approved redundant document to the archive location, verify that the archived copy matches the approved document, and only after successful verification remove the redundant original from its active location.

Archive destinations shall never be overwritten. At no point may an archive operation leave the user with no valid copy of the document. The definitive document identified by the Execution Plan shall never be modified or relocated.

---

## RQ-007 — Recovery

The application shall preserve sufficient information to recover from an execution.

Recovery shall restore preserved documents where required.

---

## RQ-008 — Audit

Every execution shall produce an audit record.

The audit shall record:

- Scan Session identifier
- Execution identifier
- Scan date and time
- Execution date and time
- Approved recommendations
- Executed operations
- Preserved documents
- Verification results
- Recovery activity (if applicable)

---

# Non-Functional Requirements

## Safety

Document preservation has priority over performance.

---

## Reliability

Operations shall complete deterministically.

---

## Transparency

All recommendations shall be understandable.

---

## Local First

Release 1 shall operate entirely on the local filesystem.

---

## Maintainability

Engineering shall favour simple, maintainable implementations.

---

# Constraints

Release 1 shall not include:

- Cloud synchronisation
- AI-generated recommendations
- Automatic execution
- Background monitoring
- Collaboration
- Version control integration
- External services

---

# Acceptance Criteria

Release 1 is complete when:

- all functional requirements are implemented;
- all approved filesystem operations are non-destructive;
- execution is fully auditable;
- recovery functions correctly;
- implementation remains within the approved Release1Scope.
