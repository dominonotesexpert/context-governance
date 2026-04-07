---
artifact_type: architecture-change-proposal
status: active
owner_role: system-architect
scope: system
downstream_consumers: [system-architect, module-architect, implementation, verification, debug]
last_reviewed: 2026-03-22
---

# ARCHITECTURE_CHANGE_PROPOSAL

**Status:** active
**Owner:** System Architect
**Last Updated:** 2026-03-22

---

## Proposal Registry

### ACP-001: Replace in-process queue with Redis

- **Date:** 2026-03-22
- **Raised By:** Implementation Agent
- **Affected Section:** PROJECT_ARCHITECTURE_BASELINE 2 (Decision 4)
- **Trigger:** engineering-constraint conflict
- **Evidence:** EC-001 (PostgreSQL connection pool limit) makes in-process queue unreliable under load. Worker restarts lose queued jobs.
- **Options:**
  1. Add Redis as external message broker
  2. Add PostgreSQL-based job queue (pg-boss pattern)
- **Recommendation:** Option 2 — preserves "no external broker" decision while solving reliability
- **User Decision:** pending
- **Resolution:** —
