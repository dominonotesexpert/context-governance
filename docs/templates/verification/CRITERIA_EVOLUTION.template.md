---
artifact_type: criteria-evolution
status: proposed
owner_role: verification
scope: verification
downstream_consumers: [implementation, debug]
last_reviewed: YYYY-MM-DD
---

# CRITERIA_EVOLUTION

**Status:** proposed
**Owner:** Verification Agent
**Last Updated:** YYYY-MM-DD

> This document tracks the history of evaluation criteria changes.
> It is a changelog, NOT a source of truth. Criteria themselves live in derived documents
> (ACCEPTANCE_RULES, VERIFICATION_ORACLE) which are derived from upstream sources.

---

## 1. Change History

### CE-001: [Criteria Name]

- **Date Added:** YYYY-MM-DD
- **Source:** baseline | prd | system_invariant | contract | engineering_practice | user_input | feedback_history
- **Derived From:** <!-- source document and section, e.g., "PROJECT_BASELINE §4.2" or "FEEDBACK_LOG FB-003, FB-007" -->
- **Current Status:** active | deprecated | removed
- **Deterministic?:** yes | no (if no, marked as "needs human ruling")
- **Question:** <!-- yes/no check question -->
- **Changelog:**
  - YYYY-MM-DD: Created. Source: [explanation]
  - YYYY-MM-DD: Wording refined. Reason: [feedback FB-XXX revealed ambiguity]
  - YYYY-MM-DD: Deprecated. Reason: [upstream contract updated, criteria re-derived]

<!-- Add more CE entries as criteria evolve -->

## 2. Deprecation Log

| ID | Deprecated Date | Reason | Replacement |
|----|----------------|--------|-------------|
| <!-- CE-XXX --> | <!-- YYYY-MM-DD --> | <!-- upstream doc updated --> | <!-- CE-YYY or "re-derived" --> |

## 3. Pending Items

<!-- Criteria changes suggested by feedback but not yet traced to upstream documents -->

| Suggestion | From Feedback | Upstream Gap | Status |
|-----------|--------------|-------------|--------|
| <!-- e.g., "add boundary case check" --> | <!-- FB-003, FB-007 --> | <!-- MODULE_CONTRACT api-service §3 --> | <!-- pending upstream update --> |
