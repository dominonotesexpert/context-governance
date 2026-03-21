# Business Semantics Confirmation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the business-semantics confirmation layer across templates, bootstrap flow, example artifacts, and tests so the framework can distinguish user-confirmed business meaning from agent-derived technical design.

**Architecture:** The implementation proceeds in two layers. First, establish the new upstream structure by introducing `BASELINE_INTERPRETATION_LOG`, registering Tier `0.5`, and updating readiness/bootstrap behavior. Then update downstream templates so `SYSTEM_GOAL_PACK`, `SYSTEM_INVARIANTS`, `MODULE_CONTRACT`, `ACCEPTANCE_RULES`, and `ROUTING_POLICY` consume that structure correctly without turning technical design into user-owned truth.

**Tech Stack:** Markdown templates, shell bootstrap tooling, shell test suite

---

### Task 1: Lock bootstrap expectations with failing tests

**Files:**
- Modify: `tests/bootstrap-project.test.sh`

**Step 1: Add failing assertions for the new artifact and tier registration**

Update the shell test suite to expect:

- `docs/agents/system/BASELINE_INTERPRETATION_LOG.md` is bootstrapped
- frontmatter checks include the new artifact
- bootstrap validation output recognizes the new artifact where appropriate
- authority-map expectations mention Tier `0.5` and `BASELINE_INTERPRETATION_LOG`

**Step 2: Run the bootstrap test suite to verify the new expectations fail**

Run:

```bash
bash tests/bootstrap-project.test.sh
```

Expected:

- FAIL because the new artifact is not yet created
- FAIL because current templates and bootstrap logic do not yet reference Tier `0.5`

**Step 3: Commit the failing-test checkpoint**

```bash
git add tests/bootstrap-project.test.sh
git commit -m "test: add business semantics bootstrap expectations"
```

### Task 2: Add the upstream structure and bootstrap support

**Files:**
- Create: `docs/templates/system/BASELINE_INTERPRETATION_LOG.template.md`
- Modify: `docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md`
- Modify: `docs/templates/BOOTSTRAP_READINESS.template.md`
- Modify: `docs/templates/PROJECT_BASELINE.template.md`
- Modify: `docs/templates/README.md`
- Modify: `docs/templates/system/README.md`
- Modify: `scripts/bootstrap-project.sh`

**Step 1: Create the new template**

Add `docs/templates/system/BASELINE_INTERPRETATION_LOG.template.md` with:

- frontmatter including `artifact_type`, `owner_role: system-architect`, `authority_tier: 0.5`
- explicit note that entries require user confirmation
- entry structure for business-semantic ambiguity, candidate interpretations, confirmed interpretation, and effective baseline version

**Step 2: Update authority and readiness templates**

Modify:

- `docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md` to register Tier `0.5`
- `docs/templates/BOOTSTRAP_READINESS.template.md` to include readiness handling for `BASELINE_INTERPRETATION_LOG`
- `docs/templates/PROJECT_BASELINE.template.md` to clarify that detailed interpretation lives in the interpretation log, not in baseline itself

**Step 3: Update template indexes**

Modify:

- `docs/templates/README.md`
- `docs/templates/system/README.md`

so they mention the new template and its destination path.

**Step 4: Update bootstrap script**

Modify `scripts/bootstrap-project.sh` so bootstrap and validate mode:

- copy the new template to `docs/agents/system/BASELINE_INTERPRETATION_LOG.md`
- include it in readiness/reporting output
- keep bootstrap ordering coherent with the new upstream chain

**Step 5: Run bootstrap tests to verify stage-1 wiring passes**

Run:

```bash
bash tests/bootstrap-project.test.sh
```

Expected:

- bootstrap test passes for the new file and authority registration expectations
- no regressions in existing bootstrap behavior

**Step 6: Commit stage-1 infrastructure**

```bash
git add docs/templates/system/BASELINE_INTERPRETATION_LOG.template.md docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md docs/templates/BOOTSTRAP_READINESS.template.md docs/templates/PROJECT_BASELINE.template.md docs/templates/README.md docs/templates/system/README.md scripts/bootstrap-project.sh tests/bootstrap-project.test.sh
git commit -m "feat: add baseline interpretation bootstrap layer"
```

### Task 3: Update downstream derivation templates

**Files:**
- Modify: `docs/templates/system/SYSTEM_GOAL_PACK.template.md`
- Modify: `docs/templates/system/SYSTEM_INVARIANTS.template.md`
- Modify: `docs/templates/modules/MODULE_CONTRACT.template.md`
- Modify: `docs/templates/verification/ACCEPTANCE_RULES.template.md`
- Modify: `docs/templates/system/ROUTING_POLICY.template.md`
- Modify: `docs/templates/execution/GOVERNANCE_PROGRESS.template.md`

**Step 1: Update `SYSTEM_GOAL_PACK` to be translation-only**

Modify `docs/templates/system/SYSTEM_GOAL_PACK.template.md` so it:

- cites either `PROJECT_BASELINE` or `BASELINE_INTERPRETATION_LOG` as source
- removes or relocates `Current Direction`
- forbids independent business-meaning expansion

**Step 2: Update `SYSTEM_INVARIANTS` source model**

Modify `docs/templates/system/SYSTEM_INVARIANTS.template.md` so each invariant may cite:

- `PROJECT_BASELINE`
- `BASELINE_INTERPRETATION_LOG`

and explicitly indicates whether the invariant depends on a user-confirmed semantic interpretation.

**Step 3: Update `MODULE_CONTRACT` with business-impact guardrails**

Modify `docs/templates/modules/MODULE_CONTRACT.template.md` to add:

- `upstream_business_sources`
- `business_semantics_impact`

and text making escalation mandatory when a proposed contract would reinterpret business meaning.

Do not add a separate `escalation_required` field.

**Step 4: Split `ACCEPTANCE_RULES` into semantic and technical layers**

Modify `docs/templates/verification/ACCEPTANCE_RULES.template.md` so it distinguishes:

- business acceptance semantics
- technical verification gates

with explicit upstream source rules for each layer.

**Step 5: Tighten routing and execution-context wording**

Modify:

- `docs/templates/system/ROUTING_POLICY.template.md`
- `docs/templates/execution/GOVERNANCE_PROGRESS.template.md`

so routing asks users only for business-semantic questions and `GOVERNANCE_PROGRESS` becomes the home for phase/task-specific direction previously implied by `Current Direction`.

**Step 6: Run bootstrap tests after downstream template changes**

Run:

```bash
bash tests/bootstrap-project.test.sh
```

Expected:

- PASS
- no stale expectations around old `SYSTEM_GOAL_PACK` or routing wording

**Step 7: Commit downstream template updates**

```bash
git add docs/templates/system/SYSTEM_GOAL_PACK.template.md docs/templates/system/SYSTEM_INVARIANTS.template.md docs/templates/modules/MODULE_CONTRACT.template.md docs/templates/verification/ACCEPTANCE_RULES.template.md docs/templates/system/ROUTING_POLICY.template.md docs/templates/execution/GOVERNANCE_PROGRESS.template.md
git commit -m "feat: enforce business semantics decision boundary"
```

### Task 4: Update repository-level docs and platform guidance

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `GEMINI.md`

**Step 1: Update README derivation-chain wording**

Modify `README.md` so it:

- introduces `BASELINE_INTERPRETATION_LOG`
- explains Tier `0.5`
- clarifies that user confirmation applies to business semantics, not general technical design

**Step 2: Update platform entrypoint guidance**

Modify:

- `AGENTS.md`
- `CLAUDE.md`
- `GEMINI.md`

so system-architect loading lists and explanatory text reflect the new upstream artifact and the updated boundary between business meaning and technical design.

**Step 3: Verify references are consistent**

Run:

```bash
rg -n "BASELINE_INTERPRETATION_LOG|Tier 0.5|Current Direction|business semantics" README.md AGENTS.md CLAUDE.md GEMINI.md
```

Expected:

- all repo-level guidance uses the same terminology
- no stale language implies users should define ordinary technical details

**Step 4: Commit repo-level guidance changes**

```bash
git add README.md AGENTS.md CLAUDE.md GEMINI.md
git commit -m "docs: align repo guidance with semantics layer"
```

### Task 5: Refresh the minimal example artifacts

**Files:**
- Create: `docs/examples/minimal-governed-repo/system/BASELINE_INTERPRETATION_LOG.md`
- Modify: `docs/examples/minimal-governed-repo/README.md`
- Modify: `docs/examples/minimal-governed-repo/system/SYSTEM_AUTHORITY_MAP.md`
- Modify: `docs/examples/minimal-governed-repo/system/SYSTEM_GOAL_PACK.md`
- Modify: `docs/examples/minimal-governed-repo/system/SYSTEM_INVARIANTS.md`
- Modify: `docs/examples/minimal-governed-repo/modules/api-service/MODULE_CONTRACT.md`

**Step 1: Add a concrete interpretation-log example**

Create `docs/examples/minimal-governed-repo/system/BASELINE_INTERPRETATION_LOG.md` with one or two user-confirmed semantic clarifications tied to the sample baseline.

**Step 2: Update example system artifacts**

Modify the example artifacts so they:

- reference Tier `0.5`
- cite interpretation-log entries when relevant
- demonstrate the new source model rather than only the old baseline-only chain

**Step 3: Update the example README**

Modify `docs/examples/minimal-governed-repo/README.md` so readers can understand what the new example artifact does and why it exists.

**Step 4: Verify example consistency**

Run:

```bash
rg -n "BASELINE_INTERPRETATION_LOG|derived_from_baseline_version|user_confirmed|Tier 0.5" docs/examples/minimal-governed-repo
```

Expected:

- the example repo demonstrates the new semantics-confirmation model consistently

**Step 5: Commit the example refresh**

```bash
git add docs/examples/minimal-governed-repo
git commit -m "docs(example): add semantics confirmation example"
```

### Task 6: Final verification and integration check

**Files:**
- Verify only

**Step 1: Run the full bootstrap regression suite**

Run:

```bash
bash tests/bootstrap-project.test.sh
```

Expected:

- PASS

**Step 2: Run a bootstrap dry-run smoke check**

Run:

```bash
bash scripts/bootstrap-project.sh --target /tmp/context-governance-smoke --platform codex --dry-run
```

Expected:

- dry-run output lists `BASELINE_INTERPRETATION_LOG`
- no write occurs

**Step 3: Run validate-mode smoke check on a temp bootstrap**

Run:

```bash
T="$(mktemp -d)" && bash scripts/bootstrap-project.sh --target "$T" --platform claude >/dev/null && bash scripts/bootstrap-project.sh --target "$T" --validate
```

Expected:

- readiness report includes the new artifact where relevant
- output remains coherent for an unfilled bootstrap

**Step 4: Review the final diff for scope discipline**

Run:

```bash
git diff --stat HEAD~6..HEAD
```

Expected:

- changes are limited to the semantics-confirmation design surface
- no unrelated files are pulled in

**Step 5: Commit any final verification-only adjustments**

```bash
git add -A
git commit -m "test: verify semantics confirmation rollout"
```
