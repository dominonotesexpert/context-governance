# Project Architecture Baseline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Add a user-owned `PROJECT_ARCHITECTURE_BASELINE` Tier `0.8`, a derived Tier `2` `SYSTEM_ARCHITECTURE`, and an `ARCHITECTURE_CHANGE_PROPOSAL` mechanism so architectural floor-setting is user-controlled while detailed architecture remains derived and traceable.

**Architecture:** The implementation proceeds in five layers. First, lock failing tests for the new authority model. Second, add the new templates and bootstrap wiring. Third, register the new layer in authority, routing, derivation, engineering-constraint, and governance-mode artifacts. Fourth, integrate Tier `2` and architectural traceability into downstream templates. Fifth, verify with the shell suite and consistency checks.

**Tech Stack:** Markdown templates, shell bootstrap tooling, shell test suite

**Dependencies:** This plan integrates with the open-risks work already planned in [2026-03-22-open-risks-implementation-plan.md](/Users/prominic2/work/context-governance/docs/plans/2026-03-22-open-risks-implementation-plan.md), especially `ENGINEERING_CONSTRAINTS`, `GOVERNANCE_MODE`, and `DERIVATION_REGISTRY`. If those slices are not yet merged, implement the prerequisite file creation and metadata updates in the same branch before wiring this feature end-to-end.

---

## Success Criteria

This plan is complete when:

1. `PROJECT_ARCHITECTURE_BASELINE.md` exists as Tier `0.8` user-owned structural truth
2. `SYSTEM_ARCHITECTURE.md` exists as Tier `2` derived architecture with full derivation metadata
3. `ARCHITECTURE_CHANGE_PROPOSAL.md` exists and is registered as a meta-artifact outside the tier chain
4. `DERIVATION_REGISTRY` explicitly tracks `SYSTEM_ARCHITECTURE.md`
5. `GOVERNANCE_MODE` explicitly protects Tier `0`, `0.5`, and `0.8`
6. `ROUTING_POLICY` explicitly includes `SYSTEM_ARCHITECTURE` in its staleness and load-order rules
7. Debug loading rules include `SYSTEM_ARCHITECTURE`
8. `bootstrap-project.sh --validate` enforces architecture-baseline size limits by mechanism
9. shell tests cover upstream creation, validation, routing metadata, and downstream architectural traceability
10. the full shell suite passes without regressions

---

### Task 1: Lock the new authority model with failing tests

**Files:**
- Modify: `tests/bootstrap-project.test.sh`

**Step 1: Add failing assertions for the new Tier 0.8 artifact**

Extend the shell suite to expect:

- `docs/agents/PROJECT_ARCHITECTURE_BASELINE.md` is bootstrapped
- frontmatter includes:
  - `artifact_type: project-architecture-baseline`
  - `owner_role: user`
  - `authority_tier: 0.8`

**Step 2: Add failing assertions for the new Tier 2 artifact**

Extend the suite to expect:

- `docs/agents/system/SYSTEM_ARCHITECTURE.md` is bootstrapped
- its frontmatter includes:
  - `artifact_type: system-architecture`
  - `derived_from_baseline_version`
  - `derived_from_architecture_baseline_version`
  - `derivation_context`

**Step 3: Add failing assertions for authority-map wording**

Assert that `SYSTEM_AUTHORITY_MAP` now:

- registers Tier `0.8`
- defines Tier `2` as `SYSTEM_ARCHITECTURE`
- states that Tier `2` derives from Tier `0.8`

**Step 4: Add failing assertions for the proposal artifact**

Assert that:

- `docs/agents/system/ARCHITECTURE_CHANGE_PROPOSAL.md` is bootstrapped
- it includes `User Decision: pending | approved | rejected`
- it forbids direct rewrite of `PROJECT_ARCHITECTURE_BASELINE`

**Step 5: Run the shell suite to verify the new expectations fail**

Run:

```bash
bash tests/bootstrap-project.test.sh
```

Expected:

- FAIL because Tier `0.8`, derived Tier `2`, and proposal flow do not exist yet

**Step 6: Commit the failing-test checkpoint**

```bash
git add tests/bootstrap-project.test.sh
git commit -m "test: add architecture baseline authority expectations"
```

### Task 2: Add the new templates and bootstrap file creation

**Files:**
- Create: `docs/templates/PROJECT_ARCHITECTURE_BASELINE.template.md`
- Create: `docs/templates/system/SYSTEM_ARCHITECTURE.template.md`
- Create: `docs/templates/system/ARCHITECTURE_CHANGE_PROPOSAL.template.md`
- Modify: `docs/templates/README.md`
- Modify: `docs/templates/system/README.md`
- Modify: `scripts/bootstrap-project.sh`

**Step 1: Create `PROJECT_ARCHITECTURE_BASELINE.template.md`**

The template must include:

- `owner_role: user`
- `authority_tier: 0.8`
- allowed sections only:
  - System Topology
  - Key Architectural Decisions
  - Non-Negotiable Structural Boundaries
  - Canonical Workflows
  - Canonical Data Flows
- explicit statement that downstream agents must not rewrite it

**Step 2: Create `SYSTEM_ARCHITECTURE.template.md`**

The template must include:

- `artifact_type: system-architecture`
- `owner_role: system-architect`
- `scope: system`
- `derived_from_baseline_version`
- `derived_from_architecture_baseline_version`
- `derivation_context`
- explicit `Derived From:` line covering:
  - `PROJECT_BASELINE`
  - `BASELINE_INTERPRETATION_LOG`
  - `PROJECT_ARCHITECTURE_BASELINE`
  - `SYSTEM_GOAL_PACK`
  - `ENGINEERING_CONSTRAINTS`

**Step 3: Create `ARCHITECTURE_CHANGE_PROPOSAL.template.md`**

It must include:

- proposal entry structure from the design
- explicit user-decision field
- explicit note that proposals do not modify architecture truth directly

**Step 4: Update template indexes**

Modify:

- `docs/templates/README.md`
- `docs/templates/system/README.md`

so all three templates are indexed and destination paths are documented.

**Step 5: Bootstrap the new files**

Modify `scripts/bootstrap-project.sh` so it copies:

- `docs/templates/PROJECT_ARCHITECTURE_BASELINE.template.md` to `docs/agents/PROJECT_ARCHITECTURE_BASELINE.md`
- `docs/templates/system/SYSTEM_ARCHITECTURE.template.md` to `docs/agents/system/SYSTEM_ARCHITECTURE.md`
- `docs/templates/system/ARCHITECTURE_CHANGE_PROPOSAL.template.md` to `docs/agents/system/ARCHITECTURE_CHANGE_PROPOSAL.md`

Bootstrap ordering must ensure:

1. user-owned roots are copied first
2. then derived system artifacts

**Step 6: Run a focused grep check**

Run:

```bash
rg -n "PROJECT_ARCHITECTURE_BASELINE|SYSTEM_ARCHITECTURE|ARCHITECTURE_CHANGE_PROPOSAL|authority_tier: 0.8|derived_from_architecture_baseline_version" docs/templates scripts/bootstrap-project.sh
```

Expected:

- PASS with hits in the new templates, indexes, and bootstrap script

**Step 7: Commit the template/bootstrap layer**

```bash
git add docs/templates/PROJECT_ARCHITECTURE_BASELINE.template.md docs/templates/system/SYSTEM_ARCHITECTURE.template.md docs/templates/system/ARCHITECTURE_CHANGE_PROPOSAL.template.md docs/templates/README.md docs/templates/system/README.md scripts/bootstrap-project.sh
git commit -m "feat: add architecture baseline and derived architecture templates"
```

### Task 3: Wire authority, routing, derivation, engineering constraints, and governance modes

**Files:**
- Modify: `docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md`
- Modify: `docs/templates/system/ROUTING_POLICY.template.md`
- Modify: `docs/templates/system/DERIVATION_REGISTRY.template.md`
- Modify: `docs/templates/system/ENGINEERING_CONSTRAINTS.template.md`
- Modify: `docs/templates/execution/GOVERNANCE_MODE.template.md`
- Modify: `docs/templates/BOOTSTRAP_READINESS.template.md`
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `GEMINI.md`
- Modify: `.claude/skills/system-architect/SKILL.md`
- Modify: `.claude/skills/debug/SKILL.md`

**Step 1: Update `SYSTEM_AUTHORITY_MAP.template.md`**

Add:

- Tier `0.8` = `PROJECT_ARCHITECTURE_BASELINE.md`
- Tier `2` = `SYSTEM_ARCHITECTURE.md`

Clarify:

- Tier `0.8` is user-owned structural truth
- Tier `2` is derived detailed architecture
- Tier `2` derives from `0 / 0.5 / 0.8 / 1 / 1.5`
- `ARCHITECTURE_CHANGE_PROPOSAL.md` is registered as a meta-artifact outside the tier chain

Also add the exact conflict-classification rule from design §6.2:

- business-semantic conflicts between `BASELINE_INTERPRETATION_LOG` and `PROJECT_ARCHITECTURE_BASELINE` resolve at Tier `0 / 0.5`
- structural conflicts resolve at Tier `0.8`
- mixed clauses must be split and escalated, not silently classified

**Step 2: Update `ROUTING_POLICY.template.md`**

Add System Architect load order explicitly:

1. Tier `0`
2. Tier `0.5`
3. Tier `0.8`
4. Tier `1`
5. Tier `1.5`
6. Tier `2`

Add routing rules that:

- architecture conflicts produce `ARCHITECTURE_CHANGE_PROPOSAL`
- downstream agents may not silently rewrite Tier `0.8`
- stale Tier `2` blocks downstream consumption until re-derived
- Debug route loads `SYSTEM_ARCHITECTURE.md` alongside `MODULE_CONTRACT.md`

Also update the staleness section to list `SYSTEM_ARCHITECTURE.md` explicitly among the derived artifacts checked at routing time.

Also update `ROUTING_POLICY` section 4 (SA loading list) to include `PROJECT_ARCHITECTURE_BASELINE.md`, `ENGINEERING_CONSTRAINTS.md`, `GOVERNANCE_MODE.md`, and `SYSTEM_ARCHITECTURE.md` — matching the complete enumerated list given for `CLAUDE.md` in Step 7. The ROUTING_POLICY section 4 is the authoritative loading specification; platform entrypoints must mirror it, not the other way around.

Also update the section 8 pre-routing checklist item 2 from "Tier 0 or 0.5" to "Tier 0, 0.5, or 0.8" so mode-window integrity checks cover the architecture baseline.

**Step 3: Update `DERIVATION_REGISTRY.template.md`**

Ensure the registry explicitly tracks:

- `SYSTEM_ARCHITECTURE.md`
- `derived_from_architecture_baseline_version`
- Tier `0.8` upstream hashes
- an example row or required entry format for `SYSTEM_ARCHITECTURE.md`

This closes the earlier gap where a new upstream source would otherwise be invisible to staleness tracking.

**Step 4: Update `ENGINEERING_CONSTRAINTS.template.md`**

Add explicit conflict rule text:

- engineering constraints may challenge Tier `0.8`
- engineering constraints may not rewrite Tier `0.8`
- conflict resolution path is `ARCHITECTURE_CHANGE_PROPOSAL`

**Step 5: Update `GOVERNANCE_MODE.template.md`**

Add Tier `0.8` protection:

- hard rule 1 becomes: no mode may suspend Tier `0`, `0.5`, or `0.8`
- exploration may produce draft Tier `2` alternatives only
- migration may allow scoped Tier `2` / module deviations without changing Tier `0.8`

**Step 6: Update `BOOTSTRAP_READINESS.template.md`**

Add:

- readiness handling for `PROJECT_ARCHITECTURE_BASELINE`
- readiness handling for `SYSTEM_ARCHITECTURE`
- blocked state when:
  - architecture baseline exceeds size limits
  - Tier `2` is stale and required for downstream work

**Step 7: Update platform entrypoints and System Architect skill**

Modify:

- `CLAUDE.md`
- `AGENTS.md`
- `GEMINI.md` (scope note: `GEMINI.md` is an installation guide, not a governance routing entrypoint like `CLAUDE.md` or `AGENTS.md`. Updates here are limited to documenting the new artifact in the installation/setup context — do not add routing tables or loading lists to an installation document.)
- `.claude/skills/system-architect/SKILL.md`
- `.claude/skills/debug/SKILL.md`

to include:

- Tier `0.8`
- Tier `2`
- exact loading order
- proposal-only change mechanism
- `GOVERNANCE_MODE` in the System Architect mandatory load list
- `SYSTEM_ARCHITECTURE` in the Debug mandatory load list

For `CLAUDE.md`, make the System Architect load list explicit and complete:

1. `PROJECT_BASELINE.md`
2. `BASELINE_INTERPRETATION_LOG.md`
3. `PROJECT_ARCHITECTURE_BASELINE.md`
4. `SYSTEM_GOAL_PACK.md`
5. `ENGINEERING_CONSTRAINTS.md`
6. `SYSTEM_AUTHORITY_MAP.md`
7. `SYSTEM_CONFLICT_REGISTER.md`
8. `SYSTEM_INVARIANTS.md`
9. `GOVERNANCE_MODE.md`
10. `SYSTEM_ARCHITECTURE.md` (when present; if stale, re-derive before downstream use)

**Step 8: Run focused consistency checks**

Run:

```bash
rg -n "Tier 0.8|SYSTEM_ARCHITECTURE|derived from Tier 0.8|ARCHITECTURE_CHANGE_PROPOSAL|load order|GOVERNANCE_MODE|BASELINE_INTERPRETATION_LOG" docs/templates CLAUDE.md AGENTS.md GEMINI.md .claude/skills/system-architect/SKILL.md .claude/skills/debug/SKILL.md
```

Expected:

- PASS with consistent authority and load-order wording

**Step 9: Commit the authority/routing/mechanism layer**

```bash
git add docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md docs/templates/system/ROUTING_POLICY.template.md docs/templates/system/DERIVATION_REGISTRY.template.md docs/templates/system/ENGINEERING_CONSTRAINTS.template.md docs/templates/execution/GOVERNANCE_MODE.template.md docs/templates/BOOTSTRAP_READINESS.template.md CLAUDE.md AGENTS.md GEMINI.md .claude/skills/system-architect/SKILL.md .claude/skills/debug/SKILL.md
git commit -m "feat: wire architecture baseline authority and guardrails"
```

### Task 4: Enforce lightness and add example artifacts

**Files:**
- Modify: `scripts/bootstrap-project.sh`
- Modify: `tests/bootstrap-project.test.sh`
- Create: `docs/examples/minimal-governed-repo/PROJECT_ARCHITECTURE_BASELINE.md`
- Create: `docs/examples/minimal-governed-repo/system/SYSTEM_ARCHITECTURE.md`
- Create: `docs/examples/minimal-governed-repo/system/ARCHITECTURE_CHANGE_PROPOSAL.md`
- Modify: `docs/examples/minimal-governed-repo/README.md`

**Step 1: Add validation logic for lightness**

Modify `scripts/bootstrap-project.sh --validate` to check:

- body line count for `PROJECT_ARCHITECTURE_BASELINE.md`
- Mermaid block count for `PROJECT_ARCHITECTURE_BASELINE.md`

Report a blocking issue if:

- body lines > 50
- Mermaid blocks > 2

**Step 2: Add shell tests for the size-limit mechanism**

Extend `tests/bootstrap-project.test.sh` so the validator expectations cover:

- valid architecture baseline passes
- oversized baseline is reported as blocking / invalid
- too many Mermaid blocks is reported as blocking / invalid

**Step 3: Add example files**

Create:

- `docs/examples/minimal-governed-repo/PROJECT_ARCHITECTURE_BASELINE.md`
- `docs/examples/minimal-governed-repo/system/SYSTEM_ARCHITECTURE.md`
- `docs/examples/minimal-governed-repo/system/ARCHITECTURE_CHANGE_PROPOSAL.md`

The example must show:

- a lightweight Tier `0.8`
- a richer derived Tier `2`
- one proposal entry demonstrating challenge-without-rewrite

**Step 4: Update the example README**

Document:

- the difference between `PROJECT_BASELINE`, `PROJECT_ARCHITECTURE_BASELINE`, and `SYSTEM_ARCHITECTURE`
- how architectural changes flow through proposals

**Step 5: Run the shell suite**

Run:

```bash
bash tests/bootstrap-project.test.sh
```

Expected:

- PASS for file creation
- PASS for validation logic
- PASS for example expectations

**Step 6: Commit the validation/example layer**

```bash
git add scripts/bootstrap-project.sh tests/bootstrap-project.test.sh docs/examples/minimal-governed-repo/PROJECT_ARCHITECTURE_BASELINE.md docs/examples/minimal-governed-repo/system/SYSTEM_ARCHITECTURE.md docs/examples/minimal-governed-repo/system/ARCHITECTURE_CHANGE_PROPOSAL.md docs/examples/minimal-governed-repo/README.md
git commit -m "feat: enforce architecture baseline lightness and examples"
```

### Task 5: Add downstream architectural traceability and tests

**Files:**
- Modify: `tests/bootstrap-project.test.sh`
- Modify: `docs/templates/modules/MODULE_CONTRACT.template.md`
- Modify: `docs/templates/modules/MODULE_CANONICAL_WORKFLOW.template.md`
- Modify: `docs/templates/modules/MODULE_CANONICAL_DATAFLOW.template.md`
- Modify: `docs/templates/system/MODULE_TAXONOMY.template.md`
- Modify: `docs/templates/system/ROUTING_POLICY.template.md`
- Modify: `docs/templates/system/SYSTEM_INVARIANTS.template.md`
- Modify: `docs/templates/verification/ACCEPTANCE_RULES.template.md`
- Modify: `docs/templates/verification/VERIFICATION_ORACLE.template.md`
- Modify: `.claude/skills/debug/SKILL.md`

**Step 1: Add failing assertions before editing downstream templates**

Extend the shell suite to expect:

- `MODULE_CONTRACT` references `SYSTEM_ARCHITECTURE` / architecture baseline provenance
- canonical workflow/dataflow templates mention upstream architecture traceability in addition to code links
- `MODULE_TAXONOMY` acknowledges derivation from system architecture where relevant
- verification templates mention architectural conformance / workflow drift / dataflow drift
- `SYSTEM_INVARIANTS` only cite Tier `0.8` when a structural rule becomes a true invariant
- `ROUTING_POLICY` Debug loading rules include `SYSTEM_ARCHITECTURE`
- Debug skill loading rules include `SYSTEM_ARCHITECTURE`

**Step 2: Run the shell suite to verify these downstream expectations fail**

Run:

```bash
bash tests/bootstrap-project.test.sh
```

Expected:

- FAIL because downstream templates do not yet know about the new architectural layers

**Step 3: Update downstream templates**

Modify the listed templates so they:

- consume Tier `2` as the detailed architecture source
- preserve code-link requirements where they serve debug truth
- add architecture provenance without turning downstream docs into new architecture roots

Also update:

- `docs/templates/system/ROUTING_POLICY.template.md` Debug loading list
- `.claude/skills/debug/SKILL.md`

so the debug path has the same architecture context as the authority model.

**Step 4: Run targeted grep checks**

Run:

```bash
rg -n "SYSTEM_ARCHITECTURE|architecture baseline|architectural conformance|workflow drift|dataflow drift" docs/templates/modules docs/templates/system docs/templates/verification .claude/skills/debug/SKILL.md
```

Expected:

- PASS with explicit references in all affected downstream templates

**Step 5: Re-run the shell suite**

Run:

```bash
bash tests/bootstrap-project.test.sh
```

Expected:

- PASS for the new downstream expectations

**Step 6: Commit the downstream integration**

```bash
git add tests/bootstrap-project.test.sh docs/templates/modules/MODULE_CONTRACT.template.md docs/templates/modules/MODULE_CANONICAL_WORKFLOW.template.md docs/templates/modules/MODULE_CANONICAL_DATAFLOW.template.md docs/templates/system/MODULE_TAXONOMY.template.md docs/templates/system/ROUTING_POLICY.template.md docs/templates/system/SYSTEM_INVARIANTS.template.md docs/templates/verification/ACCEPTANCE_RULES.template.md docs/templates/verification/VERIFICATION_ORACLE.template.md .claude/skills/debug/SKILL.md
git commit -m "feat: add architectural traceability to downstream templates"
```

### Task 6: Final verification and repository-wide consistency audit

**Files:**
- Modify as needed: any files found inconsistent during verification

**Step 1: Run the full shell suite**

Run:

```bash
bash tests/bootstrap-project.test.sh
```

Expected:

- PASS
- no regressions in bootstrap, authority, routing, validation, or downstream template behavior

**Step 2: Run repository-wide consistency checks**

Run:

```bash
rg -n "PROJECT_ARCHITECTURE_BASELINE|SYSTEM_ARCHITECTURE|ARCHITECTURE_CHANGE_PROPOSAL|Tier 0.8|derived_from_architecture_baseline_version" README.md CLAUDE.md AGENTS.md GEMINI.md docs .claude/skills
```

Expected:

- PASS with no stale references to the old "Tier 0.8 replaces Tier 2" model

**Step 3: Manually inspect the example chain**

Confirm:

- Tier `0.8` stays lightweight
- Tier `2` is clearly more detailed
- proposals demonstrate challenge-without-rewrite
- routing/authority wording is internally consistent

**Step 4: Commit the final verification pass**

```bash
git add CLAUDE.md AGENTS.md GEMINI.md .claude/skills/system-architect/SKILL.md .claude/skills/debug/SKILL.md scripts/bootstrap-project.sh tests/bootstrap-project.test.sh docs/templates/PROJECT_ARCHITECTURE_BASELINE.template.md docs/templates/BOOTSTRAP_READINESS.template.md docs/templates/README.md docs/templates/system/README.md docs/templates/system/ARCHITECTURE_CHANGE_PROPOSAL.template.md docs/templates/system/SYSTEM_ARCHITECTURE.template.md docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md docs/templates/system/ROUTING_POLICY.template.md docs/templates/system/DERIVATION_REGISTRY.template.md docs/templates/system/ENGINEERING_CONSTRAINTS.template.md docs/templates/system/MODULE_TAXONOMY.template.md docs/templates/system/SYSTEM_INVARIANTS.template.md docs/templates/modules/MODULE_CONTRACT.template.md docs/templates/modules/MODULE_CANONICAL_WORKFLOW.template.md docs/templates/modules/MODULE_CANONICAL_DATAFLOW.template.md docs/templates/verification/ACCEPTANCE_RULES.template.md docs/templates/verification/VERIFICATION_ORACLE.template.md docs/templates/execution/GOVERNANCE_MODE.template.md docs/examples/minimal-governed-repo/PROJECT_ARCHITECTURE_BASELINE.md docs/examples/minimal-governed-repo/README.md docs/examples/minimal-governed-repo/system/SYSTEM_ARCHITECTURE.md docs/examples/minimal-governed-repo/system/ARCHITECTURE_CHANGE_PROPOSAL.md
git commit -m "test: verify architecture baseline governance flow"
```
