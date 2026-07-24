# Design

**Project:** Document Consolidator

**Status:** Release 1

---

# Purpose

This document defines the high-level engineering architecture for Release 1.

It identifies the major subsystems, their responsibilities, and the flow of information through the application.

Implementation details remain intentionally unspecified.

---

# Architectural Principles

The architecture shall:

- remain simple;
- remain deterministic;
- remain non-destructive;
- maintain a single source of truth for application state;
- clearly separate analysis from execution;
- allow verification before modification.

---

# High-Level Architecture

Release 1 consists of six primary subsystems:

```
User Interface
        │
        ▼
Scan Manager
        │
        ▼
Inventory
        │
        ▼
Recommendation Engine
        │
        ▼
Execution Engine
        │
        ▼
Audit & Recovery
```

Each subsystem owns a single responsibility.

---

# Subsystem Responsibilities

## User Interface

Responsible for:

- folder selection
- Scan Session management
- displaying inventory
- displaying recommendations
- collecting user approval
- presenting execution and recovery results

The UI contains no business logic.

---

## Scan Manager

Responsible for:

- scanning selected folders
- discovering supported documents
- creating Scan Sessions
- collecting document metadata

The Scan Manager never modifies the filesystem.

---

## Inventory

Responsible for maintaining the authoritative representation of discovered documents.

The Inventory is the single source of truth for Release 1.

No other subsystem duplicates document state.

---

## Recommendation Engine

Responsible for:

- analysing the Inventory;
- producing consolidation recommendations;
- assigning recommendation categories;
- producing deterministic results.

The Recommendation Engine never modifies the filesystem.

---

## Execution Engine

Responsible for executing approved recommendations.

Each archive operation is a verified relocation:

1. copy the approved redundant document to the archive location;
2. verify that the archived copy matches the approved document;
3. only after successful verification, remove the redundant original from its active location;
4. record the execution outcome for Audit & Recovery.

Execution performs only approved operations.

Non-destructive execution means user data is never permanently destroyed. At no point may an archive operation leave the user with no valid copy of the document. The definitive document identified by the Execution Plan is never modified or relocated.

---

## Audit & Recovery

Responsible for:

- execution history;
- preserved documents;
- verification records;
- recovery operations;
- audit reporting.

This subsystem provides engineering evidence rather than business logic.

---

# Data Flow

The application follows a single forward workflow:

```
Folders
    ↓
Scan
    ↓
Inventory
    ↓
Recommendations
    ↓
User Approval
    ↓
Execution
    ↓
Verification
    ↓
Audit
```

Recovery is a separate workflow initiated only when required.

---

# Ownership

| Subsystem | Owns |
|-----------|------|
| Scan Manager | Folder scanning |
| Inventory | Document state |
| Recommendation Engine | Analysis |
| Execution Engine | Filesystem modification |
| Audit & Recovery | Execution history and recovery |

No responsibility is shared between subsystems.

---

# Design Constraints

Release 1 shall not:

- combine analysis with execution;
- execute recommendations automatically;
- overwrite archive destinations or remove an original before its archived copy is verified;
- depend upon cloud services;
- depend upon external APIs;
- perform background monitoring.

---

# Engineering Success

The architecture is considered successful when:

- subsystem responsibilities remain clear;
- ownership is unambiguous;
- filesystem operations remain non-destructive;
- deterministic behaviour is maintained;
- additional functionality can be introduced without violating subsystem boundaries.

---

# Guiding Principle

Every subsystem should have one clear responsibility and one authoritative owner.

When architecture becomes unclear, return to engineering review before implementation.
