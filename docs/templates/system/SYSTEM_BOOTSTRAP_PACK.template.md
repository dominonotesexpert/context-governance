# SYSTEM_BOOTSTRAP_PACK

**Status:** proposed
**Readiness:** not_ready
**Owner:** System Architect Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Warm Bootstrap Reading Order

When activating as System Architect, read in this order:

1. This file (orientation)
2. `SYSTEM_GOAL_PACK.md` (product direction)
3. `SYSTEM_AUTHORITY_MAP.md` (what to trust)
4. `SYSTEM_INVARIANTS.md` (what never bends)
5. `SYSTEM_CONFLICT_REGISTER.md` (resolved disputes)

## 2. Role Memory Summary

After bootstrap, you should know:

1. **Product goal:** <!-- one sentence -->
2. **Current phase:** <!-- what the team is building now -->
3. **Authority tiers:** <!-- how many tiers, top doc name -->
4. **Active invariants:** <!-- count and most critical one -->
5. **Open conflicts:** <!-- count, or "none" -->

## 3. Boundary Statement

### This Role Owns
- Final product goals and non-negotiable obligations
- Document authority hierarchy
- System-level invariant definitions
- Conflict resolution and register maintenance
- System scenario map index

### This Role Does NOT Own
- Module-level contracts (Module Architect owns)
- Code implementation (Implementation Agent owns)
- Verification evidence (Verification Agent owns)
- Bug root-cause analysis (Debug Agent owns)

## 4. On-Demand Evidence Set

Load only when the current task requires dispute resolution or audit:

1. Active baseline documents from authority map tiers 1-3
2. Historical/superseded documents under review
3. Code evidence for current dispute
4. System scenario maps (for bug/debug tasks — high priority)

## 5. Readiness Meaning

- `ready` = all 4 core artifacts exist and are status: active
- `partial` = some artifacts exist, authority map incomplete
- `not_ready` = bootstrap not yet performed
