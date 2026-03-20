---
artifact_type: regression-cases
status: proposed
owner_role: autoresearch
scope: optimization
downstream_consumers: [system-architect]
last_reviewed: YYYY-MM-DD
---

# REGRESSION_CASES

**Status:** proposed
**Owner:** Autoresearch process
**Last Updated:** YYYY-MM-DD

> Registry of failure scenarios that were fixed by the optimization loop.
> These must continue passing in ALL future optimization rounds.
> The registry only grows — cases are never removed unless the underlying check item is deprecated.

---

## 1. Rules

1. **Only grows.** Every failure fixed by an optimization round is automatically added here.
2. **Never removed.** Unless the corresponding check item in the governance mechanics checklist is deprecated.
3. **Must all pass.** Before any optimization round is accepted, ALL regression cases must be re-verified.
4. **Source linked.** Each case links to the optimization round that fixed it and the check items it covers.

## 2. Registry

### RC-001: [Short description of the failure that was fixed]

- **Date Added:** YYYY-MM-DD
- **Fixed In:** Optimization Round NNN
- **Skill Modified:** <!-- e.g., .claude/skills/verification/SKILL.md -->
- **Check Items Covered:** <!-- e.g., GM-E1 -->
- **Failure Description:** <!-- What was happening before the fix -->
- **Fix Applied:** <!-- What change fixed it (reference OPTIMIZATION_LOG) -->
- **Verification:** <!-- How to confirm this case still passes -->

<!-- Add more RC entries as optimizations fix failures -->

## 3. Deprecation

A regression case may ONLY be deprecated when:
- The underlying check item (e.g., GM-E1) is removed from the governance mechanics checklist
- The System Architect approves the deprecation with documented rationale

Deprecated cases are moved to the Deprecated section below, not deleted.

## 4. Deprecated Cases

| Case ID | Deprecated Date | Reason | Approver |
|---------|----------------|--------|----------|
| <!-- RC-XXX --> | <!-- YYYY-MM-DD --> | <!-- check item GM-XX deprecated --> | <!-- System Architect --> |
