# Context Governance Bootstrap Implementation Plan

**Goal:** Bootstrap the first production-usable artifact set for the context-governance multi-agent system.

**Architecture:** Create a new `docs/agents/` namespace separated from legacy plan documents. Start with system-owned artifacts derived from current top-level truth, then add one pilot module (`runtime-kernel`) contract and its first verification oracle so the governance model is proven on a narrow but critical scope.

**Tech Stack:** Markdown docs, existing repo architecture docs, `DEV_STATUS`, implementation specs, runtime/gate policy docs

---

### Task 1: Create the `docs/agents/` bootstrap structure

**Files:**
- Create: `docs/agents/README.md`
- Create: `docs/agents/system/README.md`
- Create: `docs/agents/modules/README.md`
- Create: `docs/agents/verification/README.md`
- Create: `docs/agents/frontend/README.md`

**Step 1: Write the doc skeletons**

Create directory READMEs that define:

1. what each namespace owns,
2. what belongs in `docs/agents/` versus `docs/plans/`,
3. that artifacts in `docs/agents/` are persistent role-owned truth artifacts.

**Step 2: Verify structure and wording**

Run:

```bash
rg -n "owns|persistent|docs/plans|docs/agents" docs/agents
```

Expected: each README contains role ownership and directory-boundary wording.

---

### Task 2: Materialize the first system-owned artifacts

**Files:**
- Create: `docs/agents/system/SYSTEM_GOAL_PACK.md`
- Create: `docs/agents/system/SYSTEM_AUTHORITY_MAP.md`
- Create: `docs/agents/system/SYSTEM_CONFLICT_REGISTER.md`
- Create: `docs/agents/system/SYSTEM_INVARIANTS.md`

**Step 1: Build `SYSTEM_GOAL_PACK.md`**

Derive from:

1. `docs/product/current/PRD_V2_1_CN.md`
2. `docs/architecture/SYSTEM_ARCHITECTURE.md`
3. `docs/architecture/STYLE_SYSTEM_ARCHITECTURE_CN.md`
4. `docs/DEV_STATUS.md` §0

Include:

1. final product goal,
2. current runtime/system direction,
3. non-negotiable production obligations,
4. failure philosophy.

**Step 2: Build `SYSTEM_AUTHORITY_MAP.md`**

Include at minimum:

1. top-level active docs,
2. active Step3 B baseline docs,
3. supporting accepted docs,
4. historical/deprecated families now explicitly downgraded.

**Step 3: Build `SYSTEM_CONFLICT_REGISTER.md`**

Seed it with the conflicts already resolved in this session, including:

1. pre-paint region-authoring vs visibility-mask baseline,
2. tag-role parity vs layout-agnostic text parity,
3. historical mitigations that are still implemented but are not architectural truth.

**Step 4: Build `SYSTEM_INVARIANTS.md`**

Include the project’s hard invariants, especially:

1. production quality rule,
2. fail-closed rule,
3. runtime/source truth ownership,
4. code-is-evidence-not-truth,
5. downstream agents may not silently rewrite upstream truth.

**Step 5: Verify consistency**

Run:

```bash
rg -n "active|historical|deprecated|fail-closed|source truth|code is evidence" docs/agents/system
```

Expected: all four docs contain the expected governance vocabulary.

---

### Task 3: Create the pilot module contract for `runtime-kernel`

**Files:**
- Create: `docs/agents/modules/runtime-kernel/MODULE_CONTRACT.md`
- Create: `docs/agents/modules/runtime-kernel/MODULE_BOUNDARY.md`
- Create: `docs/agents/modules/runtime-kernel/MODULE_DATAFLOW.md`
- Create: `docs/agents/modules/runtime-kernel/MODULE_WORKFLOW.md`

**Step 1: Build `MODULE_CONTRACT.md`**

Derive from:

1. `docs/plans/2026-03-10-runtime-kernel-protocol-renderer-architecture.md`
2. `docs/implementation/RUNTIME_MODULE_SPEC.md`
3. `docs/DEV_STATUS.md` §0 / §0A

Define:

1. module purpose,
2. inputs,
3. outputs,
4. owned responsibilities,
5. non-owned responsibilities,
6. downstream consumers.

**Step 2: Build `MODULE_BOUNDARY.md`**

Clarify responsibility cuts between:

1. source runtime kernel,
2. protocol renderer,
3. runtime-owned visibility sync,
4. validator/gate/fallback layers.

**Step 3: Build `MODULE_DATAFLOW.md`**

Describe the critical dataflow from:

1. source page truth,
2. protocol/patch/command channels,
3. mapping/binding/gate,
4. fallback decisions.

**Step 4: Build `MODULE_WORKFLOW.md`**

Describe the critical execution workflow:

1. bootstrap,
2. binding,
3. render,
4. sync,
5. gate/preflight,
6. fallback.

**Step 5: Verify module artifact alignment**

Run:

```bash
rg -n "input|output|boundary|workflow|fallback|source truth|protocol" docs/agents/modules/runtime-kernel
```

Expected: each module artifact uses the same vocabulary and does not drift into unsupported claims.

---

### Task 4: Create the first runtime-kernel verification artifacts

**Files:**
- Create: `docs/agents/verification/ACCEPTANCE_RULES.md`
- Create: `docs/agents/verification/runtime-kernel/VERIFICATION_ORACLE.md`
- Create: `docs/agents/verification/runtime-kernel/REGRESSION_MATRIX.md`

**Step 1: Build `ACCEPTANCE_RULES.md`**

Define:

1. what counts as pass,
2. what counts as pass-with-risk,
3. what counts as fail,
4. what counts as insufficient evidence.

**Step 2: Build `VERIFICATION_ORACLE.md`**

Derive from:

1. `MODULE_CONTRACT.md`
2. `docs/implementation/FALLBACK_GATE_POLICY.md`
3. `docs/DEV_STATUS.md` current authority conclusions

Map contract to explicit checks:

1. source truth ownership,
2. runtime current-state visibility ownership,
3. parity-first fail-closed gate behavior,
4. fallback correctness.

**Step 3: Build `REGRESSION_MATRIX.md`**

Seed at least these regression classes:

1. baseline drift from historical mitigations,
2. prompt/validator/runtime contract mismatch,
3. visibility-mask vs shell-completeness confusion,
4. gate passes but contract fails,
5. code changes that require system-level re-audit.

**Step 4: Verify oracle completeness**

Run:

```bash
rg -n "pass|fail|insufficient evidence|fallback|parity|visibility|source truth" docs/agents/verification
```

Expected: verification docs define explicit acceptance language and runtime-kernel checks.

---

### Task 5: Re-link the governance design to the new artifact namespace

**Files:**
- Modify: `docs/plans/2026-03-18-context-governance-multi-agent-design.md`

**Step 1: Ensure the design document points at the new `docs/agents/` bootstrap**

Verify the document’s directory guidance matches the files created above.

**Step 2: Run a final consistency scan**

Run:

```bash
rg -n "docs/agents/" docs/plans/2026-03-18-context-governance-multi-agent-design.md docs/agents
```

Expected: the new design and the new artifact tree refer to the same namespace structure.

