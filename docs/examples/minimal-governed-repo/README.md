# Minimal Governed Repository Example

This directory shows what a project looks like after bootstrapping Context Governance
and filling in the minimum truth documents.

## What's Here

This is a fictional "task-manager" project with one module (api-service).

### System Truth (filled in)

- `system/BASELINE_INTERPRETATION_LOG.md` — Tier 0.5: user-confirmed semantic clarifications (2 entries)
- `system/SYSTEM_GOAL_PACK.md` — product vision and obligations
- `system/SYSTEM_AUTHORITY_MAP.md` — which docs are authoritative (includes Tier 0.5)
- `system/SYSTEM_INVARIANTS.md` — hard rules
- `system/ROUTING_POLICY.md` — task routing rules

### Execution Context

- `execution/CURRENT_DIRECTION.md` — project-wide phase context (not upstream truth)

### Module Contract (filled in)

- `modules/api-service/MODULE_CONTRACT.md` — what the module does, inputs, outputs, boundaries

### What a Routed Task Looks Like

When a user says "fix the authentication timeout bug", the routing is:

1. **System Architect** reads BASELINE_INTERPRETATION_LOG + SYSTEM_GOAL_PACK + AUTHORITY_MAP + INVARIANTS
2. **Module Architect** reads modules/api-service/MODULE_CONTRACT.md
3. **Debug Agent** creates a DEBUG_CASE, traces root cause
4. **Implementation Agent** fixes within contract boundaries
5. **Verification Agent** checks contract satisfaction with evidence

## How to Use This Example

Compare your project's `docs/agents/` directory with these files.
If your files look roughly like these (with your own content), you're on track.
