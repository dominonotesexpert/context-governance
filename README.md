# Context Governance

**One developer + agent team, governing large production projects.**

A framework that lets a single developer command an AI agent team through a 100-line business baseline. You maintain one business truth document; the system derives and enforces the rest so the project stays aligned across tasks, sessions, and AI models.

> *Context Governance builds the roads that keep agents on course. You define the destination; the agent team figures out the route.*

## The Core Idea

You write one document: **PROJECT_BASELINE** — under 100 lines, pure business language, zero technical terms. It defines what your product is, who it's for, what it must do, and what it must never violate.

That document is not just startup input. It is the root that keeps the whole project consistent over time:

- across **tasks** — bug fix, feature, design, audit all trace back to the same baseline
- across **sessions** — a new conversation does not reset the product truth
- across **models/tools** — Claude, Codex, Gemini, or future agents consume the same derived standards
- across the **full development lifecycle** — design, implementation, verification, feedback, and optimization all stay anchored to the same baseline

Everything else is derived:

```
PROJECT_BASELINE (you write this — ≤100 lines, plain business language)
    │
    │  System Architect identifies business ambiguities
    ↓
BASELINE_INTERPRETATION_LOG (you confirm semantic clarifications)
    │
    │  System Architect derives automatically
    ↓
SYSTEM_GOAL_PACK → SYSTEM_INVARIANTS → MODULE_CONTRACTS
    │
    ↓
ACCEPTANCE_RULES → VERIFICATION_ORACLE → evaluation criteria
```

The agent team — 7 specialized roles — enforces these derived standards on every task, every session, without you repeating yourself.

### What You Maintain vs. What the System Maintains

**You maintain:**
- `PROJECT_BASELINE.md`
- Confirming business-semantic interpretations when asked (recorded in `BASELINE_INTERPRETATION_LOG`)

**The system maintains from that baseline:**
- technical goals (`SYSTEM_GOAL_PACK`)
- hard invariants (`SYSTEM_INVARIANTS`)
- module truth (`MODULE_CONTRACT`)
- acceptance criteria and verification oracles
- routing, escalation, feedback, and optimization artifacts

This is the point of the framework: you should not have to restate product truth in every session or manually keep multiple technical documents synchronized.

## You Need This When...

Context Governance is designed for **projects that have outgrown their initial phase**. You probably recognize these symptoms:

**The same type of bug keeps appearing**
> You fix a visibility bug on Monday. On Thursday, a different visibility bug shows up in another module — same root cause, same mistake. The agent never learned the pattern because there is no bug class register, no recurrence prevention rule, no way to say "we've seen this category before, here's how we handle it."

**The agent ignores your architecture**
> You have a clear module boundary: auth service handles tokens, API gateway handles routing. But the agent keeps putting token validation logic in the gateway because it read an old migration note and treated it as current design.

**"I already told you this" — every session**
> Every new conversation starts with you re-pasting the same 5 constraints. The agent still occasionally violates them because your paste competes with 30 other documents it found, and it can't tell which one is authoritative.

**Fix one thing, break another**
> The agent fixes the billing calculation but silently changes the data format that the reporting module depends on. Nobody told it that billing's output contract is consumed downstream — because there is no contract.

**Debug sessions go in circles**
> The agent jumps straight into "fixing" a bug by changing code, without understanding the root cause. The fix creates a new bug. Three sessions later, you're back where you started.

If you recognize **two or more** of these, it's time to introduce Context Governance.

### When NOT to Introduce

Do NOT introduce it on day one. At the start of a project there is nothing to govern — no stable boundaries, no conflicting documents, no historical baggage. You would be adding friction with zero payoff.

## 60-Second Start

### 1. Bootstrap your target project

```bash
bash scripts/bootstrap-project.sh --target your-project --platform claude
```

### 2. Write your PROJECT_BASELINE

This is the **only document you write**. Everything else is derived from it.

```
docs/agents/PROJECT_BASELINE.md
```

Fill in 6 sections in plain business language:
1. Product Definition — what is this product?
2. Target Users — who uses it?
3. Core Capabilities — what must it do?
4. Business Rules — what must it never violate?
5. Success Criteria — how do you know it's working?
6. Out of Scope — what is this product NOT?

### 3. Let the system derive the rest

The System Architect agent automatically derives:
- `SYSTEM_GOAL_PACK` — technical translation of your baseline
- `SYSTEM_INVARIANTS` — hard constraints from your business rules
- `MODULE_CONTRACTS` — approved module truth when modules are introduced or re-derived

Structural derivations happen automatically. Interpretive derivations (where multiple valid translations exist) are presented to you for confirmation: *"BASELINE says X, I translated as Y, because Z."*

The important invariant is:

- you update `PROJECT_BASELINE`
- the system re-derives downstream standards
- downstream artifacts do **not** become independent hand-maintained truth

This is what preserves consistency across long-running work, session restarts, and model switches.

### 4. Start using it

Describe the task naturally. The routing protocol classifies and routes automatically:

- **bug / regression / log analysis** → `System → Module → Debug → Implementation → Verification`
- **feature / refactor** → `System → Module → Implementation → Verification`
- **design / architecture** → `System → Module → Verification`
- **document conflict / audit** → `System Architect` only
- **evaluate / optimize governance** → `/autoresearch`

## Core Model

### Single developer + agent team

This framework is designed for **one developer commanding an agent team** to manage projects that would normally require a human team. The governance protocol replaces human team coordination — role assignments, contract reviews, escalation decisions, acceptance standards — so one person can maintain a large production codebase.

### The derivation chain

Every standard traces back to PROJECT_BASELINE (Tier 0):

| Tier | Document | Derived From | Owner |
|------|----------|-------------|-------|
| 0 | PROJECT_BASELINE | (user writes directly) | User |
| 0.5 | BASELINE_INTERPRETATION_LOG | BASELINE ambiguities (user confirms) | System Architect |
| 1 | SYSTEM_GOAL_PACK | BASELINE + interpretation log | System Architect |
| 2 | Top-level architecture | — | System Architect |
| 3 | SYSTEM_INVARIANTS | BASELINE §4 + interpretation log | System Architect |
| 4 | MODULE_CONTRACTS | BASELINE §3 via GOAL_PACK | Module Architect |
| 5 | ACCEPTANCE_RULES, VERIFICATION_ORACLE | upstream contracts | Verification |
| 6 | Historical / superseded | — | — |
| 7 | Code | — | (evidence, not truth) |

**Derived documents are never hand-edited into independent truth.** To change a standard, update the upstream source and re-derive. This prevents the authority chain from breaking.

### 7 agent roles

| Role | Responsibility | Loads BASELINE directly? |
|------|---------------|------------------------|
| **System Architect** | Truth arbitration, baseline derivation, conflict resolution | Yes (only role) |
| **Module Architect** | Module contracts, boundaries, dataflow, workflows | No — consumes baseline constraints from System Architect |
| **Debug** | Root-cause analysis, DEBUG_CASE creation, bug class promotion | No |
| **Implementation** | Code within contract boundaries, escalates gaps | No |
| **Verification** | Evidence-based acceptance, feedback collection | No |
| **Frontend Specialist** | UI within semantic contracts | No |
| **Autoresearch** | Governance self-improvement, criteria generation, optimization loop | No — consumes baseline-derived standards and escalates gaps upstream |

### Hard rules

1. **No fix without root cause.** A DEBUG_CASE must exist before any code change.
2. **No implementation without contract.** If the module contract doesn't cover the task, escalate.
3. **No completion without evidence.** Verification requires runtime proof, not just "code looks right."
4. **Code is evidence, not truth.** When code contradicts `docs/agents/` artifacts, the artifacts win.
5. **Downstream never rewrites upstream.** If a contract is wrong, escalate — don't silently fix in code.
6. **Derived documents never hand-edited.** Changes flow upstream through the derivation chain.
7. **Constraints by mechanism, not expectation.** Rules encoded in HARD-GATEs and hooks, not just suggestions.

## Self-Improving Governance

The framework includes an autoresearch-inspired self-improvement loop. Run `/autoresearch` to:

**Generate evaluation criteria** — The system derives check items from your BASELINE, contracts, and invariants. You only answer business questions the system can't derive from documents.

**Evaluate governance quality** — 8 deterministic checks (pass/fail, no percentages): routing correctness, artifact completeness, boundary respect, evidence quality. All items must pass — there is no "95% is good enough" in production.

**Optimize agent prompts** — One change per round, zero tolerance for regression. Every fix is backed up. Any regression triggers immediate revert.

**Evolve standards through feedback** — Feedback never directly modifies derived documents. It traces back to which upstream document is missing coverage, suggests an update, and standards naturally evolve when the upstream document changes.

## Why This Works Across Sessions And Models

Without a root baseline, every new session and every new model tends to drift:

- one session reads an old plan and treats it as current truth
- another session infers a different module boundary from current code
- a third session fixes a bug but weakens an invariant because the original reason was lost

Context Governance prevents this by separating:

- **business truth** — `PROJECT_BASELINE`
- **derived technical truth** — goals, invariants, contracts, verification rules
- **implementation evidence** — code, logs, tests

Because every technical standard remains traceable to the same root, the project can survive:

- session restarts
- context compression
- switching from one model/tool to another
- long-running iterative development

The user does not need to re-explain the product every time. The baseline already carries it.

## What the Bootstrap Script Creates

```bash
bash scripts/bootstrap-project.sh --target your-project --platform claude
```

Creates:

- `docs/agents/PROJECT_BASELINE.md` — root document (you fill this in)
- `docs/agents/system/BASELINE_INTERPRETATION_LOG.md` — Tier 0.5 semantic clarification log
- Platform entrypoint (`CLAUDE.md` / `AGENTS.md` / `GEMINI.md`)
- System truth docs with Tier 0/0.5 authority map and derivation metadata
- Debug governance docs (DEBUG_CASE template, bug class register, recurrence prevention)
- Verification docs (acceptance rules, feedback log, criteria evolution)
- Optimization infrastructure (optimization log, tuning protocol, rollback guard, regression cases, 4 seed test scenarios)
- Cross-session state support (GOVERNANCE_PROGRESS template, execution directory)
- Namespace READMEs for every `docs/agents/` subdirectory

Options:

```bash
--seed-module billing     # seed one module contract
--copy-commands           # copy /bug /impl /audit /verify /autoresearch commands
--copy-skills             # copy all 7 agent skills
--dry-run                 # preview without writing
--validate                # check an existing project for completeness
--force                   # overwrite existing files
```

## Compatibility

Platforms with install guides:

- Claude Code
- Codex
- Gemini CLI

Platforms that work with manual setup (copy skills + point at `docs/agents/`):

- Cursor
- OpenCode
- GitHub Copilot

Composes with execution frameworks like [Superpowers](https://github.com/obra/superpowers) — they handle task execution, Context Governance handles truth ownership.

## Repository Map

- [CLAUDE.md](CLAUDE.md) — Claude Code auto-routing entrypoint
- [AGENTS.md](AGENTS.md) — Codex-style project entrypoint
- [GEMINI.md](GEMINI.md) — Gemini CLI installation notes
- [docs/templates/](docs/templates/) — all template files (source of truth for bootstrap)
- [docs/design/](docs/design/) — architecture and design documents
- [docs/examples/](docs/examples/) — real-world artifact examples including minimal governed repo
- [scripts/bootstrap-project.sh](scripts/bootstrap-project.sh) — project bootstrap script
- [tests/bootstrap-project.test.sh](tests/bootstrap-project.test.sh) — 229 tests
- [CONTRIBUTING.md](CONTRIBUTING.md) — contribution rules
- [CHANGELOG.md](CHANGELOG.md) — project change history

## Enforcement Scripts

### HARD-GATE Document Checker
```bash
# Verify all required documents exist for a role
bash scripts/check-hardgate.sh --role debug --target your-project

# Check with specific module
bash scripts/check-hardgate.sh --role implementation --target your-project --module billing
```

Can be used as a Claude Code hook or CI check to ensure governance prerequisites are met before agent activation.

## License

Apache 2.0 License
