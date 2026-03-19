# Context Governance

**A truth-ownership framework for multi-agent coding.**

A system that ensures agents don't silently corrupt each other's work over long-lived codebases.

> *[Superpowers](https://github.com/obra/superpowers) teaches agents how to drive. Context Governance builds the roads that keep them on course.*

Context Governance is the layer that stops AI agents from drifting into contradictory beliefs over time.

It does this by making 4 things explicit:

- who owns each artifact
- which docs are active vs historical
- which route a task must take
- how bugs must be debugged before they are fixed

This is not another orchestration layer. It is a governance layer for what agents are allowed to believe.

## You Need This When...

Context Governance is designed for **projects that have outgrown their initial phase**. You probably recognize these symptoms:

**The same type of bug keeps appearing**
> You fix a visibility bug on Monday. On Thursday, a different visibility bug shows up in another module — same root cause, same mistake. The agent never learned the pattern because there is no bug class register, no recurrence prevention rule, no way to say "we've seen this category before, here's how we handle it."

**The agent ignores your architecture**
> You have a clear module boundary: auth service handles tokens, API gateway handles routing. But Codex keeps putting token validation logic in the gateway because it read an old migration note and treated it as current design.

**"I already told you this" — every session**
> Every new conversation starts with you re-pasting the same 5 constraints. The agent still occasionally violates them because your paste competes with 30 other documents it found, and it can't tell which one is authoritative.

**Fix one thing, break another**
> The agent fixes the billing calculation but silently changes the data format that the reporting module depends on. Nobody told it that billing's output contract is consumed downstream — because there is no contract.

**Historical workarounds become "architecture"**
> Six months ago someone added a retry loop as a temporary fix. Now every agent session treats it as a design pattern and builds new features on top of it. The hack has become load-bearing.

**Debug sessions go in circles**
> The agent jumps straight into "fixing" a bug by changing code, without understanding the root cause. The fix creates a new bug. The new fix reverts the old fix. Three sessions later, you're back where you started.

**Design docs say one thing, code says another**
> Your architecture doc says "fail-closed on validation errors." The code fails open. A new agent reads the code, assumes fail-open is intentional, and builds more fail-open paths. The doc becomes fiction.

**Multi-agent chaos**
> You run parallel agents on different features. Agent A refactors a shared utility. Agent B depends on the old interface. Neither knows about the other. Both PRs look fine individually. Merged together, they break.

If you recognize **two or more** of these, it's time to introduce Context Governance.

### When NOT to Introduce

Do NOT introduce it on day one. At the start of a project there is nothing to govern — no stable boundaries, no conflicting documents, no historical baggage. You would be adding friction with zero payoff.

### Typical Project Lifecycle

```
Phase 1: From zero to one
  Tools like Superpowers shine here — brainstorming, planning, TDD, shipping.
  Context Governance adds friction with no payoff at this stage.

Phase 2: Framework takes shape (introduce Context Governance here)
  Module boundaries stabilize. Documents accumulate. Multi-session work begins.
  → Bootstrap system truth docs and module contracts.

Phase 3: Long-term maintenance (both tools working together)
  Superpowers drives execution for each task.
  Context Governance ensures every session starts with correct context.
```

### Relationship with Superpowers

[Superpowers](https://github.com/obra/superpowers) and Context Governance solve different problems at different layers:

| | Superpowers | Context Governance |
|---|---|---|
| **Layer** | Execution — how to do the work | Governance — what is true |
| **Problem** | Agents skip planning, testing, review | Agents drift into contradictory beliefs |
| **When** | From project start | After framework stabilizes |
| **Skills** | brainstorming, TDD, code review, plans | truth ownership, contract boundaries, routing |

They compose naturally: Superpowers drives how each task is executed (plan → implement → test → review), while Context Governance ensures the agent's context is correct before execution begins (which docs are authoritative, which module owns what, what the invariants are).

You can use either one independently. When used together, Context Governance's routing runs first (classify task, load correct artifacts), then Superpowers' execution skills take over (plan, implement, verify).

## 60-Second Start

### 1. Install skills for your platform

- **Claude Code**
  ```bash
  cp -r .claude/skills/* your-project/.claude/skills/
  ```
- **Codex**
  Follow [.codex/INSTALL.md](.codex/INSTALL.md)
- **Gemini CLI**
  Follow [GEMINI.md](GEMINI.md)
- **Cursor / OpenCode / GitHub Copilot**
  Copy `.claude/skills/` into your project and point your platform at the `docs/agents/` namespace. These platforms support project-level instructions but do not have dedicated install guides yet — see [CONTRIBUTING.md](CONTRIBUTING.md) if you'd like to add one.

### 2. Bootstrap your target project

```bash
bash scripts/bootstrap-project.sh --target your-project --platform claude
```

Or:

```bash
make bootstrap TARGET=your-project PLATFORM=claude
```

Platform examples:

```bash
bash scripts/bootstrap-project.sh --target your-project --platform claude
bash scripts/bootstrap-project.sh --target your-project --platform codex
bash scripts/bootstrap-project.sh --target your-project --platform gemini
```

### 3. Fill in the minimum truth docs

Start with:

- `docs/agents/system/SYSTEM_GOAL_PACK.md`
- `docs/agents/system/SYSTEM_AUTHORITY_MAP.md`
- `docs/agents/system/SYSTEM_INVARIANTS.md`
- optional first module contract:
  - `docs/agents/modules/<your-module>/MODULE_CONTRACT.md`

### 4. Start using it

Describe the task naturally. The platform entrypoint routes it automatically:

- **bug / regression / log analysis**
  - `System -> Module -> Debug -> Implementation -> Verification`
- **implementation / refactor / feature**
  - `System -> Module -> Implementation -> Verification`
- **UI / interaction / a11y / performance**
  - add `Frontend Specialist`

## What the Bootstrap Script Creates

The bootstrap script creates a complete governance scaffold:

- project-level platform entrypoint
  - `CLAUDE.md` for Claude Code
  - `AGENTS.md` for Codex
  - `GEMINI.md` for Gemini
- `docs/agents/BOOTSTRAP_READINESS.md`
- core system truth docs (including `SYSTEM_CONFLICT_REGISTER.md`)
- debug governance docs
- verification acceptance rules
- namespace READMEs for every `docs/agents/` subdirectory
- directory structure for implementation, frontend, execution, task-checklists
- `docs/plans/agents/` namespace with README

If you already know your first module boundary, you can also seed one module contract:

```bash
bash scripts/bootstrap-project.sh --target your-project --platform claude --seed-module billing
```

Or:

```bash
make bootstrap TARGET=your-project PLATFORM=claude SEED_MODULE=billing
```

### What "module" means here

A `module` in Context Governance is **a stable unit of responsibility**, not a mandatory framework concept.

Use a module when you can point to something that has:

- a clear responsibility
- a boundary
- inputs and outputs
- behavior that can be verified independently

Good module candidates:

- a backend service such as `auth`, `billing`, or `notifications`
- a runtime subsystem such as `preview-runtime` or `style-generation`
- a major business flow such as `checkout` or `case-intake`
- a bounded UI domain such as `admin-dashboard` when it has its own contract and verification needs

Poor module candidates:

- vague buckets like `misc`
- one-off bugfix names
- temporary branches of work
- the entire repo when it has multiple distinct responsibilities

If you are not sure what your first module is, **do not pass `--seed-module` yet**.
Bootstrap the whole project first, then define module boundaries after your first real task or first architecture review.

Important behavior:

- existing files are skipped by default
- use `--force` only when you want to overwrite
- use `--copy-commands` when you also want `.claude/commands/`
- use `--copy-skills` when you also want `.claude/skills/`

## Core Model

### Persistent roles

- **System Architect**
  - owns system truth, authority, invariants, scenario maps
- **Module Architect**
  - owns module contracts, boundaries, workflows, dataflows
- **Debug**
  - owns debug cases, bug classes, recurrence prevention
- **Implementation**
  - writes code within upstream contracts
- **Verification**
  - checks contract satisfaction with evidence
- **Domain Specialist**
  - owns domain-specific constraints such as frontend or security
- **Task Orchestrator**
  - assembles the minimum task context, owns no long-term truth

### Hard rules

1. **No fix without root cause.** For bugs, a DEBUG_CASE must exist before any code change.
2. **No implementation without contract.** If the module contract doesn't cover the task, escalate to Module Architect.
3. **No completion without evidence.** Verification requires runtime proof, not just "code looks right."
4. **Code is evidence, not truth.** When code contradicts `docs/agents/` artifacts, the artifacts win.
5. **Downstream never rewrites upstream.** If a contract is wrong, escalate — don't silently fix in code.

## Why This Exists

The failure mode in long-running multi-agent codebases is not "the model can't code." It is **context corruption** — agents silently drifting into contradictory beliefs until the codebase becomes ungovernable.

Every scenario in ["You Need This When..."](#you-need-this-when) traces back to the same root causes:

1. no explicit owner for each piece of truth
2. no way to distinguish active docs from historical ones
3. no rule preventing downstream agents from silently rewriting upstream design
4. no mandatory root-cause analysis before fixes
5. code being treated as design truth instead of implementation evidence

Context Governance exists to make these five things explicit and enforceable.

## Repository Map

- [AGENTS.md](AGENTS.md)
  - Codex-style project entrypoint
- [CLAUDE.md](CLAUDE.md)
  - Claude Code auto-routing entrypoint
- [GEMINI.md](GEMINI.md)
  - Gemini CLI installation and project bootstrap notes
- [.codex/INSTALL.md](.codex/INSTALL.md)
  - Codex installation notes
- [docs/README.md](docs/README.md)
  - docs index
- [docs/templates/README.md](docs/templates/README.md)
  - template-to-artifact bootstrap guide
- [docs/design/2026-03-18-context-governance-multi-agent-design.md](docs/design/2026-03-18-context-governance-multi-agent-design.md)
  - full framework architecture
- [docs/design/2026-03-18-context-governance-bootstrap-implementation-plan.md](docs/design/2026-03-18-context-governance-bootstrap-implementation-plan.md)
  - bootstrap plan
- [docs/design/2026-03-19-debug-agent-flow-map-design.md](docs/design/2026-03-19-debug-agent-flow-map-design.md)
  - debug and flow map design
- [docs/design/2026-03-19-debug-agent-flow-map-implementation-plan.md](docs/design/2026-03-19-debug-agent-flow-map-implementation-plan.md)
  - debug and flow map implementation plan
- [docs/design/2026-03-19-repo-agent-routing-hardening-design.md](docs/design/2026-03-19-repo-agent-routing-hardening-design.md)
  - agent routing hardening design
- [docs/design/2026-03-19-repo-semantic-router-design.md](docs/design/2026-03-19-repo-semantic-router-design.md)
  - semantic router design for multilingual intent classification
- [docs/examples/debug-case-example.md](docs/examples/debug-case-example.md)
  - example debug case
- [docs/examples/task-execution-pack-example.md](docs/examples/task-execution-pack-example.md)
  - example implementation task pack
- [CONTRIBUTING.md](CONTRIBUTING.md)
  - contribution rules
- [CHANGELOG.md](CHANGELOG.md)
  - project change history

## Optional Claude Slash Commands

If you want command shortcuts in Claude Code:

```bash
bash scripts/bootstrap-project.sh --target your-project --platform claude --copy-commands
```

This copies:

- `/bug`
- `/impl`
- `/audit`
- `/verify`

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

## License

MIT
