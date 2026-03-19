# Agents Artifact Namespace

**Status:** active
**Owner:** System Architect Agent
**Purpose:** Define the boundary between `docs/agents/` and `docs/plans/`, and the storage rules for long-term role-owned artifacts

---

## 1. What Goes Here

`docs/agents/` stores **persistent role-owned long-term artifacts**, and may extend into execution / checklist sub-namespaces under explicit governance:

1. System truth artifacts
2. Module contract artifacts
3. Verification oracles / regression matrices
4. Frontend constraint artifacts
5. Debug governance artifacts
6. Task-scoped execution artifact namespace
7. Reusable task checklist namespace

These documents are consumable by downstream agents and must be maintainable long-term.

---

## 2. What Does NOT Go Here

1. One-off brainstorming
2. Session audit drafts
3. Historical fix proposals
4. Temporary migration notes
5. Discussion-only plan documents not yet in long-term ownership

These belong in `docs/plans/`. If the document discusses **the agent system itself** (design, governance, implementation plans), it should go in `docs/plans/agents/`.

---

## 3. Boundary: `docs/agents/` vs `docs/plans/`

`docs/agents/`:
1. Role-owned
2. Persistent
3. Consumable by default
4. Used for bootstrap and task execution

`docs/plans/`:
1. Proposals
2. Audits
3. Migration records
4. Historical reasoning
5. Design material not yet promoted to long-term truth

`docs/plans/agents/`:
1. Agent system design documents
2. Agent system implementation plans
3. Routing / governance / flow-map / bootstrap proposals
4. NOT for task-level execution packs

---

## 4. Current Namespaces

0. `docs/agents/BOOTSTRAP_READINESS.md`
1. `docs/agents/system/`
2. `docs/agents/modules/`
3. `docs/agents/debug/`
4. `docs/agents/implementation/`
5. `docs/agents/verification/`
6. `docs/agents/frontend/`
7. `docs/agents/execution/`
8. `docs/agents/task-checklists/`

Additional sub-directories may be added as needed, but must not break the system / module / verification authority order.

---

## 5. Consumption Rules

1. At initialization, read `docs/agents/` first — do NOT scan `docs/plans/` before this
2. `docs/plans/` documents may only be consumed when the Authority Map explicitly marks them active or supporting
3. Downstream agents must not treat `docs/plans/` historical documents as default baselines
4. `docs/plans/agents/` is only consumed during agent system design / governance tasks — it does not replace `docs/agents/` active truth
5. `docs/agents/execution/` is only consumed when the current task explicitly needs execution packs — it does not participate in default bootstrap

---

## 6. Lifecycle

Every artifact should explicitly mark its status using at least:

1. `active`
2. `superseded`
3. `historical`

New artifacts become `active` only after the corresponding owner approves them.

---

## 7. Warm Bootstrap and Task Activation

`docs/agents/BOOTSTRAP_READINESS.md` tracks:

1. Which roles have completed taskless warm bootstrap
2. Which modules have warm bootstrap packs
3. Which roles still require a real task for task activation
