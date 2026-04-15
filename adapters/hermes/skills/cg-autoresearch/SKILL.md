---
name: cg-autoresearch
description: "Activates when the user wants to evaluate and optimize the governance chain quality, generate business-layer evaluation criteria from documents, or run the autoresearch optimization loop on SKILL.md prompts. Use for governance self-improvement."
version: "1.0.0"
metadata:
  hermes:
    tags: [governance, autoresearch, optimization, self-improvement]
    category: context-governance
    requires_toolsets: [governance-guard]
---

# Autoresearch — Governance Self-Improvement

You evaluate and optimize the governance chain. Two modes: **criteria generation** and **optimization loop**.

<HARD-GATE>
Before running any evaluation or optimization:
1. Call `governance_load_role_context(role="autoresearch")` to load required documents
2. Call `governance_enforce_hardgate(role="autoresearch", loaded_docs=[...])` to verify completeness
3. If FAIL: STOP and report missing documents

Required documents:
1. `docs/agents/system/SYSTEM_GOAL_PACK.md`
2. `docs/agents/system/SYSTEM_INVARIANTS.md`
3. `docs/agents/system/BASELINE_INTERPRETATION_LOG.md`
4. `docs/agents/optimization/OPTIMIZATION_LOG.md`
5. `docs/agents/optimization/test-scenarios/`

You do NOT load PROJECT_BASELINE directly — only System Architect does.
Do NOT run optimization without test scenarios.
</HARD-GATE>

## Produces

- Evaluation criteria checklist (deterministic or needs-human-ruling)
- Governance mechanics pass/fail report (GM-R1..E2)
- SKILL.md modification proposals (one change at a time, with backup)
- Updated OPTIMIZATION_LOG.md and regression case registry

## Mode 1: Business-Layer Criteria Generation

Derive evaluation criteria from documents (7-phase deterministic process):
- Phase 0: Baseline Constraints Gate
- Phase 1: PRD Extraction from SYSTEM_GOAL_PACK
- Phase 2: Contract & Constraint Layer
- Phase 3: Engineering Practice Fill
- Phase 4: Gap Identification
- Phase 5: Business Intent Clarification (ONLY if gaps found)
- Phase 6: Checklist Synthesis + Classification
- Phase 7: User Confirmation

## Mode 2: Governance Mechanics Evaluation

8 deterministic checks:
- **GM-R1**: Task routed to correct agent sequence?
- **GM-R2**: Route updated when task type changed mid-session?
- **GM-A1**: All required upstream documents read?
- **GM-A2**: All required outputs produced?
- **GM-B1**: Downstream agents avoided modifying upstream contracts?
- **GM-B2**: Agents escalated when contract insufficient?
- **GM-E1**: Verification included concrete runtime evidence?
- **GM-E2**: Verification checked REGRESSION_MATRIX.md?

Result: PASS (all pass) or FAIL (any fails) — no percentages.

## Mode 3: Optimization Loop

One-change-at-a-time cycle:
1. Checklist Self-Check
2. Baseline Evaluation (run GM-R1..E2)
3. Failure Analysis (trace to responsible SKILL.md)
4. Single Change (modify ONE thing)
5. Verify (fixed item pass + regression check)
6. Decision: KEEP (pass + no regression) / REVERT
7. Termination: all pass OR 3 consecutive no-fix OR max 10 rounds

**Zero tolerance for regression.** Any previously passing item that fails → immediate revert.

## Governance Tool Integration

- Start autoresearch: use MCP `governance_start_autoresearch`
- Record optimization: use MCP `governance_record_optimization`
- Before modifying SKILL.md files: call `governance_check_authority(file_path, "write", "autoresearch")`
- Hermes self-evolution (GEPA) must NOT modify governance artifacts directly. It must operate through this autoresearch protocol.
