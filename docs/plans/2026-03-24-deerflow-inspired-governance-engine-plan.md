# Cross-Platform Governance Attestation Adapter Plan

**Date:** 2026-03-24 (revised 2026-03-24 after architecture review)
**Status:** Proposed
**Depends on:** `2026-03-23-enforcement-mechanism-strengthening-design.md`, `2026-03-22-project-architecture-baseline-design.md`, `2026-03-21-business-semantics-confirmation-design.md`
**Scope:** Evolve Context Governance into a cross-platform governance adapter for Codex and Claude Code by adding machine-checkable attestation, repository gates, and optional MCP-backed receipt issuance while preserving `docs/agents/` as the authority source.

> **Revision Note:** This revision replaces the earlier runtime-control framing. The framework does not own the agent runtime on every platform, so it must guarantee governed repository state transitions, not claim full control over agent cognition or tool sequencing.

---

## 0. Strategic Direction

### 0.1 Positioning

Context Governance remains a **governance adapter**, not an execution platform.

It defines:

- what governance artifacts are authoritative
- what evidence must exist before work is accepted
- what repository gates block non-compliant changes

It does **not** claim to:

- own the agent loop
- force every tool call through a proprietary runtime
- prove the exact order of an agent's internal reasoning steps

### 0.2 Guarantee Model

The framework's hard guarantee is:

> **Non-compliant work must not enter governed repository state, commit history, CI-passing state, or protected branches.**

This is intentionally narrower and more defensible than:

> "The agent always follows the intended workflow internally."

### 0.3 Core Design Principle

DeerFlow's `GuardrailProvider` remains the right inspiration at the architectural level: governance should be separable from task execution.

But for Context Governance, the portable enforcement target is:

- **state transition control**

not:

- **full runtime interception**

### 0.4 What This Plan Does NOT Do

- Does not build a proprietary agent loop
- Does not require all file edits to flow through a governance-specific editor
- Does not claim that MCP alone can make task sequencing unskippable on every platform
- Does not create a new authority source that competes with `docs/agents/`

---

## 1. Authority Model and Truth Ownership

### 1.1 `docs/agents/` Remains the Truth Namespace

The existing governance architecture remains intact:

- `docs/agents/` is the active truth namespace in a bootstrapped target repository
- `PROJECT_BASELINE` remains Tier 0 root truth
- `ROUTING_POLICY` remains the single source of truth for routing
- derived documents remain derived, never independent hand-maintained truth

This is already established in the framework:

- `README.md`
- `AGENTS.md`
- `docs/templates/system/ROUTING_POLICY.template.md`

This plan must not introduce a competing truth layer.

### 1.2 `core/rules/*.yaml` Are Projections, Not Authority

If `core/rules/*.yaml` are added, they are **machine-readable projections** of upstream authority documents, not primary truth.

Preferred rule:

- keep existing self-describing rule sources where they already exist

This means:

- hardgate requirements continue to come from Bootstrap Pack `required_files` frontmatter
- staleness rules continue to come from document `derivation_context` and `upstream_sources`
- routing continues to come from `ROUTING_POLICY`
- governance-mode behavior continues to come from `GOVERNANCE_MODE` plus upstream routing and verification docs

Allowed use:

- generation inputs for adapter entrypoints
- validation configuration
- CI-friendly routing and enforcement lookups

Not allowed:

- silently overriding `ROUTING_POLICY`
- becoming the source of truth for task routing
- becoming the source of truth for escalation policy

Conflict rule:

- if a projection disagrees with an authority document, the authority document wins

Implementation constraint:

- do not introduce a parallel YAML source for hardgate or derivation-staleness if the same data already lives in authoritative document frontmatter
- if projections are generated, generation must be strict and one-way: authority docs -> projection files

### 1.3 `.governance/` Is an Attestation Layer

`.governance/` is not a truth tier.

It exists to hold:

- task receipts
- audit logs
- runtime/session traces
- machine-readable linkage between code changes and formal governance evidence

Its role is:

- **attestation**

not:

- **truth arbitration**

### 1.4 Preserve the Existing Role System

This plan must preserve the framework's role model, including:

1. System Architect
2. Module Architect
3. Debug
4. Implementation
5. Verification
6. Frontend Specialist
7. Autoresearch

`Autoresearch` must remain a first-class role. A generic `governance-check` skill may be added as tooling, but it must not replace a governance role.

---

## 2. What the Framework Can and Cannot Enforce

### 2.1 Enforceable

The framework can enforce:

- protected files cannot be directly modified
- required evidence artifacts exist
- derived-document rules are respected
- code changes are linked to a governed task
- bug fixes cannot be accepted without bug-governance evidence
- governed work cannot merge while escalations remain unresolved
- manual fallback paths are explicitly surfaced and gated

### 2.2 Not Fully Enforceable Across Platforms

The framework cannot fully and portably prove:

- which files the agent actually read
- whether the agent thought in the ideal route order
- whether the agent used the preferred skill before every action
- whether every code edit passed through an optional MCP tool

Therefore, governance must be expressed as:

- required outputs
- required evidence
- required state transitions

not as unverifiable assumptions about internal thought order.

### 2.3 Enforcement Layers

The revised enforcement stack is:

1. **Prompt / Skill Layer**
   - `AGENTS.md`, `CLAUDE.md`, Skills
   - purpose: guidance and routing
2. **File Protection Layer**
   - Codex sandbox permissions, `chmod`, Claude Code hooks
   - purpose: block unauthorized edits to protected governance artifacts
3. **Attestation Layer**
   - `.governance/attestations/*.receipt.yaml`
   - purpose: machine-checkable proof that governed task requirements were satisfied
4. **Repository Gate Layer**
   - `pre-commit`
   - purpose: fast local rejection of obvious governance violations
5. **CI / Branch Protection Layer**
   - CI checks plus branch rules
   - purpose: final rejection of non-compliant changes before acceptance

### 2.4 Current State vs Target State

This section describes the **target-state architecture**, not the current implementation state.

Current state in this repository today is narrower:

1. **Prompt / Skill Layer**
   - exists
2. **Repository Gate Layer**
   - exists in limited form through `.githooks/pre-commit` plus `check-derived-edits.sh`

Not yet generally implemented in this repository:

- Codex `chmod`-based Tier protection
- Claude Code hook registration for file blocking
- attestation receipts
- receipt-aware `pre-commit`
- governance CI gate

Future sections must distinguish between:

- already implemented mechanisms
- target-state mechanisms still to be built

---

## 3. Evidence Model

### 3.1 Two Evidence Classes

The revised model uses two evidence classes:

1. **Formal governance evidence** in `docs/agents/`
   - authoritative artifacts
   - human-readable
   - semantically meaningful

2. **Task attestation evidence** in `.governance/`
   - machine-checkable
   - task-scoped
   - non-authoritative

Both are required for strong governance.

### 3.2 Receipt Requirement by Task Type

Canonical task receipts are required for:

- `bug`
- `feature` / `refactor`
- `design`
- `architecture`
- `protocol`
- `contract authoring`

Receipts are not mandatory by default for:

- review-only work
- audit-only work

Those paths may be added later if needed.

To reduce adoption friction, define a lightweight future path for:

- `trivial`

Candidate use:

- typo fixes
- docs-only touchups outside active governance artifacts
- non-semantic mechanical edits

`trivial` must never be allowed to modify:

- governed code modules with contract impact
- Tier 0 / 0.5 / 0.8 artifacts
- derived governance truth
- bug-fix changes that should route through Debug

### 3.3 Persisted vs Non-Persisted `.governance/` Data

Use a split persistence model:

- committed:
  - `.governance/attestations/*.receipt.yaml`
  - `.governance/attestations/index.jsonl`
- normally not committed:
  - `.governance/audit/*.jsonl`
  - `.governance/sessions/*.json`
  - `.governance/steps/*.jsonl`

This keeps canonical governance proof in version control while avoiding log noise and session-state churn.

### 3.4 Canonical Task Receipt

Each governed task has one canonical receipt file:

```yaml
schema_version: 1
task_id: T-20260324-001
task_type: bug
status: in_progress
attestation_mode: mcp
manual_fallback_reason: null

scope:
  affected_modules: [auth]
  affected_paths:
    - src/auth/handler.ts
    - docs/agents/debug/DEBUG_CASE_auth_login.md

governance_claims:
  debug_case_present: true
  module_contract_refs:
    - docs/agents/modules/auth/MODULE_CONTRACT.md
  verification_refs:
    - docs/agents/verification/ACCEPTANCE_RULES.md

evidence_refs:
  - path: docs/agents/debug/DEBUG_CASE_auth_login.md
    kind: debug_case
    upstream_hash: null
  - path: docs/agents/modules/auth/MODULE_CONTRACT.md
    kind: module_contract
    upstream_hash: a1b2c3d4e5f6

lifecycle:
  created_at: 2026-03-24T10:00:00Z
  updated_at: 2026-03-24T11:20:00Z
  issuer: governance-mcp
  session_ids:
    - S-001
```

### 3.4A Required Claims by Task Type

`check-task-receipt.sh` must validate that the receipt contains the required `governance_claims` for its declared `task_type`. Missing required claims make the receipt incomplete and block acceptance.

| `task_type` | Required `governance_claims` | Required `evidence_refs` kinds |
|-------------|------------------------------|-------------------------------|
| `bug` | `debug_case_present: true`, `module_contract_refs` | `debug_case`, `module_contract` |
| `feature` / `refactor` | `module_contract_refs` | `module_contract` |
| `design` | (none beyond base schema) | (none beyond base schema) |
| `architecture` | (none beyond base schema) | (none beyond base schema) |
| `protocol` | (none beyond base schema) | (none beyond base schema) |
| `contract authoring` | (none beyond base schema) | (none beyond base schema) |
| `trivial` | (none) | (none) |

Additional conditional claims:

- if `verification_refs` is present, the referenced `ACCEPTANCE_RULES` must exist and be parseable
- if `task_type=bug` and `engineering_constraint_refs` is present, the referenced `ENGINEERING_CONSTRAINTS` entry must exist
- if any `evidence_refs` entry has `upstream_hash`, the hash must match the artifact's current derivation state

This table is the input specification for `check-task-receipt.sh`. Schema evolution (new required claims) must increment `schema_version`.

### 3.5 Receipt Semantics

Receipts may contain:

- task identity
- task type
- task status
- scope hints
- machine-checkable claims
- references to formal evidence

Receipts must **not** become a parallel truth system by carrying:

- new business semantics
- new architecture truth
- unreviewed design conclusions
- authority overrides

Rule:

- receipts point to truth; they do not replace truth

### 3.6 Manual Attestation

Manual fallback is allowed but controlled.

Rules:

- `attestation_mode: manual_attestation` is explicit
- `manual_fallback_reason` is required
- formal evidence references are still required
- CI flags this path
- acceptance to protected branches requires explicit human approval

### 3.7 Governance Mode Interaction

Receipts must not ignore existing governance-mode semantics.

Required behavior:

- when `GOVERNANCE_MODE = incident`, receipt requirements may be partially deferred, but the deferred items must be completed during post-incident review
- when `GOVERNANCE_MODE = exploration`, receipts may reference `draft` or `proposed` artifacts, but must not treat them as promoted `active` truth
- when `GOVERNANCE_MODE = exception`, receipts must explicitly record which claims are intentionally absent because the rule is suspended
- when `GOVERNANCE_MODE = migration`, receipts may record scoped deviations, but only within the declared migration envelope

Receipt validation must therefore read governance mode as an input, not assume steady-state semantics by default.

### 3.8 Derivation Chain Interaction

Receipts do not replace derivation-chain validation.

Required behavior:

- if a referenced governance artifact is stale per `check-staleness.sh`, receipt validation must fail or require re-derivation before acceptance
- System Architect re-derivations may have their own receipts, but those receipts still point back to the derived artifacts rather than becoming the derived artifacts
- receipt validation must capture the freshness relationship between evidence and derivation state by recording each referenced artifact's `upstream_hash` in the `evidence_refs` entry (using the same hash format as `check-staleness.sh`); a receipt whose `evidence_refs` reference a stale artifact is invalid until the artifact is re-derived

This keeps attestation coupled to the real derivation chain instead of forming a parallel compliance surface.

### 3.9 Relationship to Verification Artifacts

Receipts are not a replacement for:

- `ACCEPTANCE_RULES`
- `VERIFICATION_ORACLE`
- Verification Agent judgment

Receipts serve as:

- task-scoped machine-checkable linkage
- proof that required verification evidence was produced
- an input to repository gates

They do not serve as:

- the final verification oracle
- a second acceptance framework that can disagree with formal verification artifacts

---

## 4. Task Identity and Change Binding

### 4.1 Canonical Binding Model

Binding uses two layers:

1. **Primary**
   - commit trailer:
   - `CG-Task: T-20260324-001`

2. **Secondary**
   - branch naming
   - PR metadata or title

This allows deterministic local checks and stronger CI reconciliation.

### 4.2 Task Type Declaration and Validation

`task_type` is declared in the receipt, but CI must validate it against the actual change set.

Examples:

- if `task_type=bug` and code changes exist, bug evidence must be present
- if `task_type=design` but implementation code is modified, CI must fail or require reclassification
- if `task_type=feature` includes governance-truth changes, CI must require the corresponding upstream design evidence

### 4.3 Scope Matching

Receipts contain `affected_paths` and optional `affected_modules`.

`pre-commit` and CI both check whether the staged or PR diff is plausibly covered by the receipt.

The receipt scope is:

- a validation aid

not:

- the authority source for module ownership

Module ownership still comes from formal governance documents.

### 4.4 Task ID Lifecycle

Task ID lifecycle must be explicit.

Rules:

- default issuer: MCP service
- fallback issuer: manual path with explicit `manual_attestation`
- registry: `.governance/attestations/index.jsonl`
- one task ID may span multiple commits and multiple sessions
- one commit should normally bind to one primary task ID
- if a commit legitimately spans multiple governed tasks, the relationship must be explicit in trailers or receipt linkage

Open integration point:

- external issue-tracker mapping may be added later, but task IDs must remain valid even when no external tracker exists

---

## 5. MCP Attestation Service

### 5.1 Revised Role of MCP

MCP is retained, but with a narrower and more accurate role:

- **default receipt issuer**
- **attestation update service**
- **optional workflow accelerator**

It is **not** the universal mandatory execution path.

### 5.2 MCP Responsibilities

The MCP service should provide tools like:

- `governance_start_task`
- `governance_update_receipt`
- `governance_record_debug_case`
- `governance_record_escalation`
- `governance_record_verification`
- `governance_complete_task`

These tools should:

- create or update the canonical receipt
- record machine-checkable governance claims
- attach evidence references
- normalize data for `pre-commit` and CI

They should also integrate with existing checks rather than duplicate them:

- hardgate prerequisites should continue to come from `check-hardgate.sh`
- staleness should continue to come from `check-staleness.sh`
- derived-document edit checks should continue to come from `check-derived-edits.sh`

### 5.3 What MCP Must NOT Claim

The MCP service must not claim that it can universally prove:

- all work started with `governance_start_task`
- all edits passed through governance tools
- all task sequencing is unbypassable

Those claims are not portable across Codex and Claude Code.

### 5.4 Manual Path Compatibility

When MCP is unavailable or bypassed:

- manual attestation remains possible
- CI and approval rules become stricter
- the framework still works without pretending the missing MCP trace does not matter

---

## 6. Platform Adapters

### 6.1 Codex Adapter

Codex strengths:

- project-scoped `.codex/config.toml`
- `AGENTS.md`
- skills with `agents/openai.yaml`
- MCP support
- sandbox and filesystem restrictions

Codex limitations:

- no generic tool hooks

Therefore the Codex adapter should provide:

- skill-guided routing
- optional MCP-backed receipt issuance
- sandbox/file protection for Tier 0 / 0.5 / 0.8
- `pre-commit` and CI-backed acceptance gates

The Codex adapter must not promise the same real-time interception semantics as Claude Code.

Tentative config direction for MCP registration in `.codex/config.toml` (verify against current Codex CLI documentation before implementation — format may have changed):

```toml
[mcp_servers.governance]
command = "python"
args = ["governance-mcp-server/server.py"]
```

Tentative per-skill config path form, if used (verify against current Codex CLI documentation):

```toml
[[skills.config]]
path = "adapters/codex/skills/governance-check"
enabled = true
```

### 6.2 Claude Code Adapter

Claude Code strengths:

- hooks
- skills
- commands
- MCP

Claude Code should use hooks for:

- Tier 0 / 0.5 / 0.8 edit blocking
- audit capture
- strong early warnings for governance bypasses

But even here, CI remains the final authority for repository acceptance.

### 6.3 Adapter Symmetry Goal

The correct symmetry target is:

- **equivalent acceptance rules**

not:

- **identical runtime control capability**

Prompt behavior, warning strength, and local ergonomics may differ by platform.

What must remain identical:

- receipt schema
- evidence requirements
- `pre-commit` rules
- CI rules
- branch acceptance criteria

---

## 7. Local Gate and CI Gate Design

### 7.1 Local `pre-commit` Gate

The local gate should reject obviously invalid changes early.

There are two categories of checks:

1. **Immediate extensions possible before full receipt rollout**
2. **Receipt-dependent checks that land after the attestation schema exists**

#### 7.1A Immediate Pre-Receipt Checks

These can be implemented on top of today's repository state:

- derived-document direct-edit blocking (existing: `check-derived-edits.sh --strict`)
- governed-module code change requires corresponding `MODULE_CONTRACT` (new: `check-module-contract.sh`)
- pending escalation blocks prohibited code acceptance (new: `check-escalation-block.sh`)
- bug task with code changes requires `DEBUG_CASE` (new: `check-bug-evidence.sh`, reads `.governance/current-task.json`)
- governance mode validity remains enforced by existing validation paths

These are the fastest path to narrowing the gap between current enforcement and the desired guarantee.

#### 7.1C Pre-Commit Orchestrator

The current `.githooks/pre-commit` (24 lines, calls only `check-derived-edits.sh`) must be replaced by a single orchestrator script that composes all checks. This orchestrator is also the entry point for MCP tools and CI, avoiding logic duplication.

Script: `check-commit-governance.sh`

Behavior:

1. Call `check-derived-edits.sh --strict` (existing)
2. Call `check-module-contract.sh` — for each staged code file, walk up to find a governed module and verify `MODULE_CONTRACT.md` exists (new, Phase 1.5)
3. Call `check-escalation-block.sh` — if `.governance/escalations.jsonl` exists and has pending entries, block code commits (new, Phase 1.5)
4. Call `check-bug-evidence.sh` — if `.governance/current-task.json` declares `task_type=bug`, verify a `DEBUG_CASE` is staged or already committed (new, Phase 1.5)
5. When receipt system is active (Phase 3+): call `check-task-binding.sh`, `check-task-receipt.sh`, `check-receipt-scope.sh`

The `.githooks/pre-commit` hook becomes a one-line wrapper:

```bash
exec bash scripts/check-commit-governance.sh "$@"
```

Exit codes: `0` = all checks pass, `1` = violation (block commit).

#### 7.1B Receipt-Dependent Checks

Checks:

- staged change has a bound `CG-Task` trailer
- referenced canonical receipt exists
- receipt scope plausibly covers staged paths
- protected governance artifacts were not directly edited
- derived-document edit rules still pass
- code changes in governed modules have required module contracts
- bug-type code changes require bug-governance claims
- unresolved pending escalations block prohibited changes

This gate is intentionally fast and conservative.

### 7.2 CI Gate

CI is the final repository judge.

Checks:

- commit trailer, branch metadata, PR metadata, and receipt `task_id` are consistent
- receipt `task_type` is consistent with actual change shape
- all `evidence_refs` exist and are parseable
- receipt claims are supported by formal evidence
- manual attestation paths have the required explicit approval
- stale or missing governance evidence fails acceptance
- existing governance validations still pass:
  - hardgate completeness
  - staleness checks
  - derived-document protection
  - governance mode validity

### 7.3 Branch Protection

Protected branches should require:

- passing governance CI
- normal code review
- explicit approval for `manual_attestation`

### 7.4 Correct Statement of Enforcement Strength

After this design, the framework can correctly claim:

- governed repository transitions are strongly enforced

It must not claim:

- the agent is fully runtime-governed on every platform
- 100% of governance logic is enforced at edit time

---

## 8. Core Scripts and Projections

### 8.1 Keep Existing Script Investments

The already-implemented scripts remain valuable:

- `check-hardgate.sh`
- `check-staleness.sh`
- `check-derived-edits.sh`
- `.githooks/pre-commit`

This plan builds on them rather than discarding them.

They must be composed into the attestation system rather than shadowed by a duplicate implementation layer.

### 8.2 New Script Responsibilities

#### Phase 1.5 Scripts (no receipt dependency)

- `check-commit-governance.sh`
  - pre-commit orchestrator: composes all commit-time checks into a single entry point
  - called by `.githooks/pre-commit`, MCP tools, and CI
  - sequentially runs each check script; exits on first failure
- `check-module-contract.sh`
  - for each staged code file in a governed module, verifies `docs/agents/modules/<name>/MODULE_CONTRACT.md` exists
  - uses same module-detection logic as `check-hardgate.sh` (walk up directory tree)
- `check-escalation-block.sh`
  - reads `.governance/escalations.jsonl`; blocks code commits if any entry has `"status":"pending"`
- `check-bug-evidence.sh`
  - reads `.governance/current-task.json`; if `task_type=bug`, checks that a `DEBUG_CASE` file exists for the affected module (staged or committed)

#### Phase 3 Scripts (receipt-dependent)

- `check-task-binding.sh`
  - validates `CG-Task` commit trailer linkage
- `check-task-receipt.sh`
  - validates receipt schema, required fields, and per-task-type governance claims (per §3.4A)
- `check-receipt-scope.sh`
  - checks whether the current change set is plausibly covered by the receipt's `affected_paths`
- `check-manual-attestation-policy.sh`
  - enforces extra approval rules for `attestation_mode: manual_attestation`

Naming rule:

- all enforcement scripts use the `check-<thing>.sh` convention

### 8.3 Projection Generation

If `core/rules/*.yaml` are introduced, generation must be one-way:

- authority docs -> projections

not:

- projections -> authority docs

Generated adapter entrypoints must explicitly state that they are projections of upstream governance docs.

---

## 9. Bootstrapped Target Repository Layout

The framework source repository may contain:

- `core/`
- `adapters/`
- `docs/templates/`

But the **bootstrapped target repository** should expose a simpler governed shape:

```text
target-project/
├── docs/agents/
├── .governance/
│   ├── attestations/
│   │   ├── index.jsonl
│   │   └── T-20260324-001.receipt.yaml
│   ├── audit/
│   ├── sessions/
│   └── steps/
├── .githooks/
├── .codex/          # when Codex adapter installed
└── .claude/         # when Claude Code adapter installed
```

The target project should not be forced to understand the framework source repository's internal structure in order to consume governance.

### 9.1 Bootstrap Script Changes

`bootstrap-project.sh` must be extended to support the attestation layer. Changes by phase:

**Phase 1.5:**

- Create `.governance/` directory (empty, with `.gitkeep`)
- Add `.governance/audit/`, `.governance/sessions/`, `.governance/steps/` to `.gitignore` in target project
- Copy `check-commit-governance.sh` to `scripts/` in target project
- Copy `check-module-contract.sh`, `check-escalation-block.sh`, `check-bug-evidence.sh` to `scripts/`
- Update `.githooks/pre-commit` to call `check-commit-governance.sh` instead of `check-derived-edits.sh` directly

**Phase 3:**

- Create `.governance/attestations/` directory
- Initialize `.governance/attestations/index.jsonl` (empty file)
- Copy receipt-dependent scripts (`check-task-binding.sh`, `check-task-receipt.sh`, `check-receipt-scope.sh`, `check-manual-attestation-policy.sh`) to `scripts/`

**Phase 4:**

- Add `--adapter codex|claude-code` flag (default: `claude-code` for backward compatibility)
- When `--adapter codex`: generate `.codex/config.toml` with MCP registration, run `sandbox-init.sh`
- When `--adapter claude-code`: update `.claude/settings.local.json` with hook registration

**`--validate` mode extensions:**

- Phase 1.5: verify `.governance/` directory exists, verify `check-commit-governance.sh` is wired into pre-commit
- Phase 3: verify receipt completeness for governed tasks (if receipts exist), verify no orphaned task bindings

---

## 10. Implementation Roadmap

### Phase 1: Correct the Architecture Contract

1. Revise this plan to remove runtime-control claims
2. Restate `docs/agents/` as authority source
3. Restate `core/rules/*.yaml` as projections only
4. Restore `Autoresearch` as first-class in adapter planning

### Phase 1.5: Extend Existing Enforcement Mechanisms

These items intentionally do **not** depend on full receipt rollout:

1. Create `check-commit-governance.sh` orchestrator script; update `.githooks/pre-commit` to call it
2. Create `check-module-contract.sh` — governed-module `MODULE_CONTRACT` existence check at commit time
3. Create `check-escalation-block.sh` — pending-escalation blocking where `.governance/escalations.jsonl` exists
4. Introduce `.governance/current-task.json` as a lightweight pre-receipt task marker:
   ```json
   {
     "task_type": "bug",
     "task_id": null,
     "affected_modules": ["auth"],
     "created_by": "manual",
     "created_at": "2026-03-24T10:00:00Z"
   }
   ```
   - created by MCP `governance_start_task` when available, or manually by the user/agent when MCP is not running
   - read by `check-bug-evidence.sh` to determine whether `DEBUG_CASE` enforcement applies
   - superseded by canonical receipts once the full attestation system is active (Phase 3+)
   - not committed to version control (add to `.gitignore`)
5. Create `check-bug-evidence.sh` — if `current-task.json` declares `task_type=bug` and code files are staged, verify a `DEBUG_CASE` exists for at least one affected module

This phase provides immediate value and reduces the distance between the architecture's guarantee language and the current implementation reality.

### Phase 2: Define the Attestation Schema

1. Add canonical receipt schema
2. Add receipt index format
3. Define `manual_attestation` rules
4. Define task binding via `CG-Task` trailer

### Phase 3: Add Local and CI Gates

1. Implement receipt validation scripts
2. Extend `pre-commit` with receipt-dependent task-binding checks
3. Add CI checks for receipt/evidence reconciliation
4. Add branch-protection guidance for manual attestation approvals

### Phase 4: Wire Adapters

1. Codex adapter
   - skills
   - sandbox/file protection
   - correct `.codex/config.toml` MCP registration
2. Claude Code adapter
   - hooks
   - skills
   - commands
3. keep entrypoints as projections of authority docs

### Phase 5: Add MCP Attestation Service

1. Implement minimal MCP tools for receipt issuance and update
2. Make MCP the default path, not the only valid path
3. Ensure manual fallback remains possible and visible

### Phase 6: Integrate Autoresearch

1. Define receipt requirements for governance-optimization tasks
2. Ensure optimization artifacts still escalate upstream instead of rewriting truth downstream

### Phase 7: Verification

1. Cross-platform acceptance parity tests
2. Receipt vs formal evidence consistency tests
3. Manual attestation approval-path tests
4. End-to-end bootstrap -> task -> pre-commit -> CI verification

---

## 11. Success Criteria

### Authority

- `docs/agents/` remains the authority source
- projections never outrank authority docs
- generated adapter entrypoints explicitly defer to upstream governance docs

### Attestation

- every governed task type has a canonical receipt path
- receipts are machine-checkable and schema-validated
- receipts never replace formal governance truth
- governance-mode and derivation-chain semantics are reflected in receipt validation

### Local Gate

- `pre-commit` blocks missing or mismatched task binding
- `pre-commit` blocks protected-file violations
- `pre-commit` blocks missing required bug or contract evidence where applicable
- at least a subset of enforcement is delivered before full receipt rollout

### CI Gate

- CI rejects missing or invalid receipts for governed task types
- CI reconciles receipts against formal evidence
- CI blocks `manual_attestation` without explicit approval

### Platform Support

- Codex and Claude Code both support the same receipt and acceptance model
- platform differences only affect guidance strength and interception ergonomics

### Honest Claim Boundary

After implementation, the framework may honestly claim:

- "Governed changes require attestation plus formal evidence and are blocked by repository gates when non-compliant."

It may not claim:

- "All task sequencing is universally unbypassable at runtime."

---

## 12. Risks

| Risk | Mitigation |
|------|------------|
| Receipts drift into a parallel truth system | Keep them pointer-heavy and evidence-referencing; ban authority overrides in schema |
| Manual attestation becomes a bypass path | Explicit mode flag, mandatory fallback reason, CI visibility, required human approval |
| Projection files drift from authority docs | Generate projections from upstream docs and fail CI on mismatch |
| Codex and Claude Code differ too much at runtime | Standardize acceptance gates, not runtime behavior |
| Developers view governance as optional because local guidance is skippable | Make CI and protected branches the non-optional enforcement point |
| MCP outage blocks work unnecessarily | Keep manual attestation path available, but visibly gated |
| Adoption friction for small changes | Add a lightweight `trivial` path with narrowly defined scope and minimum attestation burden |

---

## 13. Relationship to Existing Plans

| Existing Plan | Relationship |
|--------------|-------------|
| `2026-03-23-enforcement-mechanism-strengthening` | Reused. Its existing scripts and local checks remain the foundation of repository-gate enforcement. |
| `2026-03-22-project-architecture-baseline` | Preserved. Tier 0.8 protection remains part of file-level governance and upstream authority. |
| `2026-03-21-business-semantics-confirmation` | Preserved. Escalation remains rooted in business-semantics boundaries, not moved into receipts. |
| `2026-03-20-autoresearch-governance-evolution-design` | Must remain active. Autoresearch is still a first-class role and must be integrated into the attestation model rather than dropped. |

---

## 14. Final Design Statement

This revised plan adopts the following contract:

1. Context Governance does **not** guarantee agent obedience.
2. Context Governance **does** guarantee governed state transitions through:
   - formal evidence in `docs/agents/`
   - task attestation in `.governance/`
   - local repository gates
   - CI and protected-branch gates
3. MCP is the default attestation service, not the universal runtime owner.
4. Authority remains upstream; attestation proves compliance to that authority.

That boundary is both technically defensible and consistent with the framework's existing architecture.
