---
artifact_type: verification-bootstrap-pack
status: proposed
owner_role: verification
scope: verification
downstream_consumers: [verification]
last_reviewed: 2026-03-20
required_files:
  - "system/SYSTEM_INVARIANTS.md"
  - "verification/ACCEPTANCE_RULES.md"
---

# VERIFICATION_BOOTSTRAP_PACK: [module-name]

**Status:** proposed
**Readiness:** not_ready
**Owner:** Verification Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Warm Bootstrap Reading Order

When verifying changes to this module, read in this order:

1. `docs/agents/verification/ACCEPTANCE_RULES.md` (what counts as pass/fail)
2. This file (module-specific verification context)
3. `VERIFICATION_ORACLE.md` (contract-to-check mapping)
4. `REGRESSION_MATRIX.md` (known regression classes)
5. The module's `MODULE_CONTRACT.md` (what the module must do)

## 2. Module-Specific Verification Context

<!-- What is unique about verifying this module? -->
<!-- - Key failure modes to watch for -->
<!-- - Common false positives -->
<!-- - Critical code paths that need runtime evidence -->

## 3. Evidence Collection Points

<!-- Where can verification evidence be found? -->

| Evidence Type | Location | How to Collect |
|--------------|----------|----------------|
| Runtime logs | <!-- e.g., browser console --> | <!-- e.g., filter for [ModuleName] prefix --> |
| Test output | <!-- e.g., npm test --> | <!-- e.g., run specific test suite --> |
| Diagnostics | <!-- e.g., sandbox events panel --> | <!-- e.g., look for specific event names --> |

## 4. Debug Closure Verification (bug fixes only)

For bug fix verification, also check:

- [ ] DEBUG_CASE exists with confirmed root cause
- [ ] Promotion decision was made by Debug Agent
- [ ] If promoted: BUG_CLASS_REGISTER and RECURRENCE_PREVENTION_RULES updated
- [ ] Required truth updates (maps, contracts) completed
