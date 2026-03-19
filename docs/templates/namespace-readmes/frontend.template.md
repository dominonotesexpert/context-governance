---
artifact_type: namespace-readme
status: proposed
owner_role: frontend-specialist
scope: frontend
downstream_consumers: [frontend-specialist, implementation]
last_reviewed: 2026-03-20
---

# Frontend Artifact Namespace

**Status:** active
**Owner:** Frontend Specialist Agent
**Purpose:** Store frontend constraints, UI contracts, a11y/perf/theme guardrail artifacts

---

## What Goes Here

Long-term frontend truth, for example:

1. `AGENT_SPEC.md` — Frontend Specialist Agent role specification
2. `FRONTEND_CONSTRAINTS.md` — Production frontend constraints
3. `UI_A11Y_PERF_RULES.md` — Accessibility and performance baselines
4. `THEME_SYSTEM_RULES.md` — Theme system guardrails

## Boundary with `docs/plans/`

1. Frontend exploration, page drafts, style experiments stay in `docs/plans/`
2. Only documents that enter the long-term constraint layer belong here
3. Frontend freedom must not breach system / module artifact semantic boundaries

## Update Rules

Only update this directory when these change:

1. UI contracts
2. Theme guardrails
3. a11y baselines
4. perf baselines

Single-page implementation details should NOT be promoted to long-term frontend truth.
