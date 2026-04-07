# Enforcement Mechanism Strengthening Design

**Date:** 2026-03-23
**Status:** Proposed
**Depends on:** `2026-03-22-project-architecture-baseline-design.md`, `2026-03-22-open-risks-implementation-plan.md`
**Scope:** Turn the framework's key text-based expectations into actual enforcement mechanisms — root cause level classification, HARD-GATE document loading validation, derivation chain staleness detection, derived document protection, and `--validate` enhancement.

## 1. Problem

The framework's core principle is "Constraints by mechanism, not expectation" (Hard Rule #7). But currently, almost all constraints are text expectations in SKILL.md files with no actual enforcement:

### 1.1 Root Cause Identification is Unreliable

AI agents frequently:
- **Confuse symptom location with root cause location.** Bug crashes in Module B's code → AI fixes Module B → but the real cause is Module A sending bad data, or a system architecture gap.
- **Self-declare "confirmed" when evidence is insufficient.** The DEBUG_CASE template has `Confidence: confirmed | partial | hypothesis` but the AI itself decides when to mark "confirmed." No validation gate exists.
- **Skip upstream tracing.** The protocol says "trace to files and functions" but doesn't force checking module boundaries or upstream inputs.
- **Miss architecture-level root causes.** No field exists to classify whether a root cause is code-level, module-level, cross-module, architecture-level, or baseline-level. Without this classification, all bugs route to Implementation Agent — even when the real fix belongs at the architecture or baseline level.

This is the most critical gap because **a wrong root cause leads to a wrong fix, which creates new bugs.**

### 1.2 HARD-GATE Document Loading Has No Enforcement

Each SKILL.md has a `<HARD-GATE>` section listing required documents. ROUTING_POLICY §4 defines minimum artifact loading per role. But:
- No script validates whether required documents exist
- No hook blocks agent activation when prerequisites are missing
- The document lists are completely deterministic (role → file list) — this is a pure engineering problem, not an AI judgment problem

### 1.3 Derivation Chain Staleness Goes Undetected

All derived documents have `derivation_context.upstream_hash` in frontmatter. ROUTING_POLICY §7 defines staleness rules. But:
- No script compares `upstream_hash` to actual current git hash
- `--validate` only checks whether `derived_from_baseline_version` exists, not whether it's current
- A stale derivation chain means all downstream standards may be wrong — this is infrastructure-level failure

### 1.4 Derived Documents Have No Protection

Framework rule: "Derived documents never hand-edited. Changes flow upstream." But:
- No mechanism detects or prevents direct edits to derived documents
- Derived documents are identifiable by `derivation_type` field in frontmatter
- A pre-commit hook could catch this automatically

### 1.5 `--validate` is Incomplete

Current validate checks: file existence, frontmatter completeness, placeholder detection, derivation version. Missing: staleness detection, governance mode expiry, interpretation log completeness, health scoring.

## 2. Decision Summary

### 2.1 Root Cause Level Classification (Issue Group A)

Add a mandatory **Root Cause Level** field to DEBUG_CASE_TEMPLATE:

| Level | Definition | Routes To |
|-------|-----------|-----------|
| `code` | Bug in a single function/file, contract is correct | Implementation Agent |
| `module` | Module implementation doesn't match its contract | Implementation + Module Architect review |
| `cross-module` | Interaction between modules produces unexpected behavior | Module Architect (both modules) |
| `engineering-constraint` | Root cause is a known engineering limitation (third-party defect, capacity limit, migration window) documented or documentable in ENGINEERING_CONSTRAINTS | System Architect (update EC) → downstream route |
| `architecture` | System design doesn't account for this scenario | System Architect |
| `baseline` | Business requirement is ambiguous or contradictory | User (BASELINE update) |

The `engineering-constraint` level is necessary because ENGINEERING_CONSTRAINTS (Tier 1.5) is a first-class input consumed by Debug, Module Architect, and Implementation (per ROUTING_POLICY §4 and `2026-03-22-open-risks-implementation-plan.md` Workstream 1). Without this level, issues like third-party API defects, migration windows, or performance ceilings would be misclassified as `code` or `architecture`, causing incorrect routing.

**Key insight:** Root cause level determines whether the problem goes DOWN (fix code) or UP (fix design/requirements/constraints). The level is classified by the Debug Agent and confirmed autonomously through the validation gate for technical levels, or escalated to the user only when the level crosses the business-semantics boundary.

### 2.2 Root Cause Validation Gate

Add a **Root Cause Validation Gate** (§5A in DEBUG_CASE_TEMPLATE) — a checklist that must ALL pass before Confidence can be set to `confirmed`:

1. **Anti-falsification:** At least 2 alternative hypotheses proposed AND disproven with evidence
2. **Prediction verified:** A specific falsifiable prediction derived from hypothesis was confirmed by observation
3. **All symptoms explained:** Root cause accounts for every observed symptom
4. **Open gaps empty:** No items remain in Evidence Ledger > Open Evidence Gaps

This is the scientific method applied to debugging — it doesn't require AI to be "smarter," it requires AI to follow a structured process.

**Note:** User confirmation is NOT in this gate. The validation gate is the autonomous quality gate that the Debug Agent must pass. User confirmation is a separate, conditional escalation governed by the business-semantics confirmation boundary (§2.3).

### 2.3 Debug Protocol Enhancements

Add three new steps to the Debug Agent's investigation protocol:

- **Step 6A: Upstream Boundary Check** — At each module hop in the trace, verify whether the failure originated within the module or was passed from upstream. This catches the most common AI debugging mistake.
- **Step 7A: Prediction-Observation Validation** — Before declaring root cause, state a falsifiable prediction and verify it. If prediction fails, return to investigation.
- **Step 8A: Business-Semantics Escalation Gate** — After the validation gate passes, check whether the root cause level crosses the business-semantics boundary. If it does, escalate to user. If it doesn't, proceed autonomously.

**Business-semantics escalation boundary for root cause levels:**

This follows the project's established confirmation boundary (`2026-03-21-business-semantics-confirmation-design.md`, ROUTING_POLICY §5.1): user confirmation is required ONLY for unresolved business semantics. Normal technical design is not blocked on user confirmation.

| Root Cause Level | Requires User Confirmation? | Rationale |
|-----------------|---------------------------|-----------|
| `code` | No | Pure technical — single code fix |
| `module` | No | Technical — module logic within existing contract |
| `cross-module` | No (unless contract gap has business-semantic implications) | Technical — contract boundary issue |
| `engineering-constraint` | No | Engineering fact, not business semantics |
| `architecture` | Yes, if fix requires Tier 0.8 change OR changes business semantics | See below |
| `baseline` | Always | This IS a business-semantics issue by definition |

For `architecture` level, user escalation is required in TWO cases:
1. **Business-semantic impact:** The architectural issue would alter business meaning, scope, or success semantics — per ROUTING_POLICY §5.1.
2. **Tier 0.8 structural change:** The fix requires modifying `PROJECT_ARCHITECTURE_BASELINE` — per `2026-03-22-project-architecture-baseline-design.md` §8.3-§8.4, agents may NOT directly edit Tier 0.8. Any such change requires `ARCHITECTURE_CHANGE_PROPOSAL` + user approval, even if business semantics are unchanged. Tier 0.8 is user-owned structural truth, protected like Tier 0 and Tier 0.5 (§9: no governance mode may suspend Tier 0.8).

If neither condition applies (issue resolvable within Tier 2 SYSTEM_ARCHITECTURE without touching Tier 0.8 or business semantics) → System Architect handles autonomously.

**Governance mode compatibility:**

The new debug steps interact with GOVERNANCE_MODE (ROUTING_POLICY §8):

| Mode | Effect on New Steps |
|------|-------------------|
| `steady-state` | Full enforcement — all steps required |
| `exploration` | Validation gate is advisory (flags but doesn't block) |
| `incident` | Steps 6A/7A/8A are DEFERRED to post-incident review. Incident mode routing (System → Implementation → post-incident review) takes precedence per ROUTING_POLICY §8. The deferred steps become mandatory during post-incident review. |
| `migration` | Full enforcement within declared scope |
| `exception` | Only declared suspended rules are relaxed |

This preserves the existing incident-mode shortcut while ensuring the validation rigor is not permanently lost.

### 2.4 Level-Based Routing from Debug

After root cause is confirmed and the validation gate passes, routing changes:

```
Debug Agent: validation gate passes (4 items)
         ↓
  Level classified
         ↓
  ┌──────┴─────────────────────────────────────────────────┐
  │                                          │              │
code / module /                      architecture          baseline
cross-module /                       (check: business      (always user)
engineering-constraint               semantics affected?)
  ↓                                    ↓           ↓
Appropriate                         No → SA      Yes → User → SA
technical route                     directly
```

This is the critical architectural change: **root cause level determines direction (downstream vs upstream), not just severity.** The user is only involved when the root cause crosses the business-semantics boundary.

### 2.5 HARD-GATE Enforcement Script (Issue Group B)

Create `scripts/check-hardgate.sh` that:
- Takes a role name and target project path
- Reads each Bootstrap Pack's `required_files` frontmatter field as the authoritative source
- Falls back to hardcoded mapping only when Bootstrap Pack is not available
- Verifies each file exists
- Returns non-zero if any missing

**Single source of truth:** ROUTING_POLICY §4 is the authoritative definition. Bootstrap Pack frontmatter `required_files` is the machine-readable encoding of that authority. The script reads from Bootstrap Packs, not from a separate hardcoded list, to avoid drift. This follows the ROUTING_POLICY "single source of truth" principle (`ROUTING_POLICY.template.md:17`).

### 2.6 Staleness Detection Script (Issue Group C)

Create `scripts/check-staleness.sh` that:
- Scans derived documents for `derivation_context.upstream_hash`
- Reads each document's `upstream_sources` frontmatter field to determine its upstream files (not a hardcoded mapping)
- Compares `upstream_hash` against current git hash of those upstream source files
- Reports FRESH/STALE/NO_HASH per document

**Single source of truth for upstream mapping:** Each derived document template's frontmatter already lists `derived_from_baseline_version` and related fields. We add an explicit `upstream_sources` field to each derived template's frontmatter. This makes each document self-describing — the script reads the document itself to find its upstream, rather than maintaining a separate mapping table that can drift.

**Correct upstream mappings** (per `2026-03-22-project-architecture-baseline-design.md` §7.2 and §12):
- SYSTEM_GOAL_PACK → PROJECT_BASELINE + BASELINE_INTERPRETATION_LOG
- SYSTEM_INVARIANTS → PROJECT_BASELINE + BASELINE_INTERPRETATION_LOG
- SYSTEM_ARCHITECTURE → PROJECT_BASELINE + BASELINE_INTERPRETATION_LOG + PROJECT_ARCHITECTURE_BASELINE + SYSTEM_GOAL_PACK + ENGINEERING_CONSTRAINTS
- MODULE_CONTRACT → SYSTEM_GOAL_PACK + SYSTEM_ARCHITECTURE + SYSTEM_INVARIANTS + ENGINEERING_CONSTRAINTS
- ACCEPTANCE_RULES → SYSTEM_GOAL_PACK + SYSTEM_INVARIANTS + MODULE_CONTRACT
- VERIFICATION_ORACLE → ACCEPTANCE_RULES + MODULE_CONTRACT

### 2.7 Derived Document Protection (Issue Group D)

Create `scripts/check-derived-edits.sh` that:
- Checks git staged files for documents with `derivation_type` in frontmatter
- For each staged derived document, compares the staged version's `derivation_context` against the current committed version
- If `derivation_context.derivation_timestamp` or `upstream_hash` has been updated → legitimate re-derivation → allow
- If content changed but `derivation_context` is unchanged → direct edit without re-derivation → warn or block
- Provide example `.githooks/pre-commit`

**Why not "upstream also staged" heuristic:** The previous design checked whether upstream files were also staged alongside the derived document. This is wrong because:
1. A proper re-derivation updates `derivation_context` (timestamp, hash, model_id) — this IS the legitimate signal, per DERIVATION_REGISTRY protocol (`DERIVATION_REGISTRY.template.md:24`)
2. "Upstream staged" would false-positive on legitimate re-derivations that happen in a separate commit
3. "Upstream staged" would false-negative on direct edits that coincidentally stage the upstream file

The correct signal is: **did the derivation metadata change?** If `derivation_context` is updated, the edit is a controlled re-derivation. If only content changed without metadata update, it's an unauthorized direct edit.

### 2.8 `--validate` Enhancement (Issue Group E)

Integrate staleness detection, governance mode expiry check, and interpretation log cross-check into existing `--validate` mode.

**Output model:** Each check produces a deterministic `PASS` or `FAIL` verdict with a specific reason. The final output is `PASS` (all checks pass) or `FAIL` (any check fails) with a list of failed checks. No gradient scores, no percentages — this follows the project's established deterministic pass/fail model (`README.md:180`).

## 3. What This Design Does NOT Do

- **Does not make HARD-GATE loading a runtime enforcement.** We cannot track which files Claude Code has read within a session. The script validates prerequisites exist, but cannot force the agent to read them. This remains a protocol-level constraint.
- **Does not automate root cause identification.** The validation gate and upstream boundary check improve the process structure, but root cause identification remains an AI + human collaborative task.
- **Does not add CI/CD pipelines.** Scripts are provided for local use and hook integration. CI/CD setup is left to the consuming project.

## 4. Risks

| Risk | Mitigation |
|------|-----------|
| New Debug steps add overhead to bug investigations | Steps are structural (checklists), not open-ended research. Overhead is bounded. |
| AI might check validation gate items without actually doing the work | For `baseline`/`architecture` (business-semantic) levels, user reviews the evidence. For `code`/`module` levels, the validation gate structure (anti-falsification, prediction) makes superficial checking harder. |
| Script mapping drifts from authoritative documents | Scripts read from document frontmatter (`required_files`, `upstream_sources`), not hardcoded tables. Drift is structurally prevented. |
| `upstream_hash` comparison requires git repo | Script handles non-git gracefully (skip with warning) |
| New template fields break existing bootstrapped projects | All new fields use HTML comment placeholders; missing fields = UNFILLED, not error |

## 5. Implementation Phases

See `2026-03-23-enforcement-mechanism-strengthening-implementation-plan.md` for detailed phase breakdown.

Phases 1-3 are independent and can be implemented in parallel. Phase 4 depends on Phase 3.
