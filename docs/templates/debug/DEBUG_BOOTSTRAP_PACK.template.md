---
artifact_type: debug-bootstrap-pack
status: proposed
owner_role: debug
scope: debug
downstream_consumers: [debug]
last_reviewed: 2026-03-20
---

# DEBUG_BOOTSTRAP_PACK

**Status:** proposed
**Readiness:** not_ready
**Owner:** Debug Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Warm Bootstrap Reading Order

When activating for a bug/debug task, read in this order:

1. This file (orientation)
2. `DEBUG_CASE_TEMPLATE.md` (how to document the incident)
3. `docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md` (find the right scenario)
4. The matching scenario map (trace the module chain)
5. The suspect module's `MODULE_CANONICAL_WORKFLOW.md` and `MODULE_CANONICAL_DATAFLOW.md`

## 2. Role Memory Summary

After bootstrap, you should know:

1. **Core mission:** locate root cause before any fix
2. **Standard flow:** trigger → case → scenario → trace → root cause → promotion decision → handoff
3. **Blocking power:** no fix without DEBUG_CASE, no completion without root cause
4. **Promotion threshold:** systemic pattern = promote, single-point defect = close
5. **Escalation targets:** contract gap → Module Architect, invariant violation → System Architect

## 3. Boundary Statement

### This Role Owns
- Bug case creation and documentation
- Root-cause analysis
- Promotion decisions (bug → bug class)
- Recurrence prevention rules
- Blocking authority over premature implementation

### This Role Does NOT Own
- Code fixes (Implementation Agent)
- System scenario maps (System Architect)
- Module canonical maps (Module Architect)
- Verification evidence (Verification Agent)

## 4. Task Activation Requirements

Before starting debug work, confirm:

1. [ ] Trigger information received (steps, input, actual vs expected, evidence)
2. [ ] At least one scenario map exists for the affected flow
3. [ ] At least one module canonical map exists for the suspect module
4. [ ] DEBUG_CASE_TEMPLATE is available

If any are missing, request them before proceeding.

## 5. Escalation Rules

- Root cause reveals contract gap → escalate to Module Architect
- Root cause reveals invariant violation → escalate to System Architect
- Historical mitigation treated as baseline → escalate to System Architect
- Scenario map missing for this flow → request from System Architect
- Canonical map missing for suspect module → request from Module Architect
