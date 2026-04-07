---
artifact_type: mode-transition-log
status: proposed
owner_role: system-architect
scope: execution
downstream_consumers: [all-roles]
last_reviewed: YYYY-MM-DD
---

# MODE_TRANSITION_LOG

**Status:** proposed
**Owner:** System Architect
**Last Updated:** YYYY-MM-DD

> Append-only log of all governance mode changes.
> Provides audit trail for governance reviews.
> Do not delete or modify existing entries — only append new ones.

---

## Transition History

| Date | From Mode | To Mode | Activated By | Reason | Expiry | Scope |
|------|-----------|---------|-------------|--------|--------|-------|
| <!-- YYYY-MM-DD | steady-state | exploration | user | Spike on new auth approach | 2026-04-05 | auth module only --> |

## Rules

1. Every mode change (including revert to steady-state) MUST have an entry
2. Entries are append-only — never modify or delete
3. `exception` mode renewals count as separate entries (used to enforce the 2-renewal limit)
4. If an entry references an escalation, link to the ESCALATION_RECORD
