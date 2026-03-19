---
artifact_type: escalation-record
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [all-roles]
last_reviewed: YYYY-MM-DD
---

# ESCALATION_RECORD

**Status:** proposed
**Owner:** System Architect Agent

## 1. Purpose

Lightweight record of governance escalations, so future agents can see that a dispute was raised and how it was resolved. This is a log entry, not a ticket system. Keep entries brief and factual.

## 2. When to Create an Escalation Record

- A downstream role discovers a contract gap and cannot proceed
- Two artifacts contradict each other
- An implementation requires violating a stated invariant
- A role disagrees with an upstream decision and needs resolution

## 3. Template

Copy the block below for each escalation. Fill in the fields. Do not add extra fields.

```
### ESC-NNN

- **Date:** YYYY-MM-DD
- **Raised By:** [role that raised the escalation]
- **Trigger:** [what caused the escalation — 1-2 sentences]
- **Escalated To:** [role responsible for resolution]
- **Decision:** [what was decided — 1-2 sentences]
- **Action Items:** [what must change as a result]
- **Affected Artifacts:** [which docs/contracts were updated]
- **Status:** open | resolved
```

## 4. Example

### ESC-001

- **Date:** 2026-03-15
- **Raised By:** Implementation Agent
- **Trigger:** MODULE_CONTRACT for api-service does not specify behavior when the database connection pool is exhausted. Implementation cannot proceed without a decision.
- **Escalated To:** Module Architect
- **Decision:** api-service returns 503 with retry-after header when pool is exhausted. Added to MODULE_CONTRACT section 8 (Invariants).
- **Action Items:** Update api-service MODULE_CONTRACT to include pool exhaustion behavior.
- **Affected Artifacts:** modules/api-service/MODULE_CONTRACT.md
- **Status:** resolved
