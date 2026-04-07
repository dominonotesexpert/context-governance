1 -# Cross-Platform Governance Adapter Plan
       2 -
       3 -**Date:** 2026-03-24 (updated 2026-03-24 after code review)
       4 -**Status:** Proposed
       5 -**Depends on:** `2026-03-23-enforcement-mechanism-strengthening-design
          .md` (Phases 1-4 — **partially implemented**)
       6 -**Scope:** Transform Context Governance from a Claude Code-centric fra
          mework into a cross-platform governance adapter that works with Codex
          (primary) and Claude Code (secondary), with a shared platform-agnostic
           core.
       7 -
       8 -> **Implementation Status Note (2026-03-24):** Several enforcement scr
          ipts from the prerequisite plan are already implemented: `scripts/chec
          k-hardgate.sh`, `scripts/check-staleness.sh`, `scripts/check-derived-e
          dits.sh`, `.githooks/pre-commit`. The bootstrap `--validate` mode now
          includes governance mode expiry, staleness detection, architecture bas
          eline checks, and interpretation log cross-checks. Bootstrap Pack temp
          lates (SYSTEM_BOOTSTRAP_PACK, DEBUG_BOOTSTRAP_PACK, etc.) provide mach
          ine-readable `required_files` per role. This plan accounts for these e
          xisting implementations.
       9 -
      10 ----
      11 -
      12 -## 0. Strategic Direction
      13 -
      14 -### 0.1 Positioning
      15 -
      16 -Context Governance is a **governance standard**, not an execution plat
          form. It defines WHAT rules to enforce and WHY. Each platform adapter
          translates rules into that platform's native enforcement mechanisms.
      17 -
      18 -> Like OWASP defines security rules but doesn't build web servers — CG
           defines governance rules but doesn't build agent loops.
      19 -
      20 -### 0.2 Platform Priority
      21 -
      22 -| Priority | Platform | Reason |
      23 -|----------|----------|--------|
      24 -| **1st** | Codex (OpenAI) | Primary target — broader audience, strong
           sandbox, full Skills system |
      25 -| **2nd** | Claude Code (Anthropic) | Current integration — unique hoo
          k-based enforcement |
      26 -| Future | DeerFlow, LangGraph, Cursor, etc. | Community adapters when
           core is stable |
      27 -
      28 -### 0.3 Design Principle from DeerFlow
      29 -
      30 -DeerFlow's `GuardrailProvider` Protocol proves governance and executio
          n should be separate concerns:
      31 -
      32 -```python
      33 -# DeerFlow: governance is pluggable, not hardcoded
      34 -class GuardrailProvider(Protocol):
      35 -    def evaluate(self, request: GuardrailRequest) -> GuardrailDecision
          : ...
      36 -```
      37 -
      38 -Context Governance should be a governance provider that any platform c
          an consume.
      39 -
      40 -### 0.4 What This Plan Does NOT Do
      41 -
      42 -- Does not build an execution platform (no agent loop, no API server)
      43 -- Does not compete with DeerFlow / LangGraph / CrewAI
      44 -- Does not require both adapters simultaneously — each works independe
          ntly
      45 -
      46 ----
      47 -
      48 -## 1. Platform Capability Mapping
      49 -
      50 -### 1.1 Codex CLI Capabilities (from official docs)
      51 -
      52 -| Capability | Details | Governance Use |
      53 -|-----------|---------|---------------|
      54 -| **AGENTS.md** | Hierarchical: AGENTS.override.md > AGENTS.md > TEAM_
          GUIDE.md > .agents.md, layered from global → repo root → current dir |
           Governance routing + hard rules at repo root; module-specific overrid
          es in subdirs |
      55 -| **Skills** | SKILL.md + agents/openai.yaml + scripts/ + references/;
           explicit (`$skill-name`) or implicit invocation; progressive context
          loading | 7 governance skills (system-architect, debug, impl, etc.) |
      56 -| **.codex/config.toml** | Project-level TOML config; team-shareable;
          `requirements.toml` for admin constraints | Governance config (enforce
          ment level, tier protection) |
      57 -| **Subagents** | `spawn_agent` / `send_input` / `wait_agent` | Govern
          ance role delegation (System → Module → Debug) |
      58 -| **MCP** | Native STDIO + streaming HTTP; Codex can also serve as MCP
           server | Governance validation as MCP tools |
      59 -| **Sandbox** | OS-level `workspace-write` (default); `danger-full-acc
          ess` mode; `--add-dir` for extra paths | chmod 444 on Tier 0 files (PO
          SIX-enforced) |
      60 -| **Approval modes** | Auto (default) / Read-only / Full Access; `/per
          missions` to switch | Read-only mode for audit tasks |
      61 -| **exec mode** | Non-interactive `codex exec "task"` with JSON output
           | CI governance validation |
      62 -| **Web search** | Built-in: cached (default) / live / disabled | Rese
          arch tasks in System Architect role |
      63 -| **No tool hooks** | Cannot intercept tool calls pre/post execution |
           Checkpoints must be embedded in Skills/AGENTS.md |
      64 -
      65 -### 1.2 Claude Code Capabilities
      66 -
      67 -| Capability | Details | Governance Use |
      68 -|-----------|---------|---------------|
      69 -| **CLAUDE.md** | Auto-loaded at session start | Governance routing +
          hard rules |
      70 -| **Skills** | .claude/skills/*/SKILL.md; activated by routing or /com
          mands | 7 governance skills (already exist) |
      71 -| **Hooks** | PreToolUse / PostToolUse / Stop / Notification; can bloc
          k (exit 2) | Real-time tool interception — unique to Claude Code |
      72 -| **Commands** | .claude/commands/*.md | /bug /impl /verify /escalate
          |
      73 -| **settings.local.json** | Project-level JSON config; hook registrati
          on, permissions | Hook pipeline configuration |
      74 -| **Subagents** | Agent tool with subagent_type | Governance role dele
          gation |
      75 -| **MCP** | Native support | Governance validation as MCP tools |
      76 -| **No sandbox** | No OS-level isolation | Cannot do chmod-based prote
          ction |
      77 -
      78 -### 1.3 Capability Symmetry Analysis
      79 -
      80 -```
      81 -                    Codex           Claude Code
      82 -                    ─────           ───────────
      83 -Skills              ✓ (rich)        ✓ (simpler)
      84 -Project config      ✓ (.codex/)     ✓ (.claude/)
      85 -Subagents           ✓               ✓
      86 -MCP                 ✓               ✓
      87 -Tool hooks          ✗               ✓ ◄── Claude Code unique advantage
      88 -OS sandbox          ✓               ✗ ◄── Codex unique advantage
      89 -Approval modes      ✓               ✓ (different mechanism)
      90 -AGENTS/CLAUDE.md    ✓               ✓
      91 -exec/CI mode        ✓               ✓ (codex exec vs claude --print)
      92 -```
      93 -
      94 -**Key insight:** The platforms are far more symmetric than assumed. Th
          e adapter design should exploit each platform's unique advantage (Code
          x: sandbox; Claude Code: hooks) while using the shared capabilities (S
          kills, MCP, subagents, config) as the primary enforcement surface.
      95 -
      96 ----
      97 -
      98 -## 2. Target Architecture
      99 -
     100 -### 2.1 Directory Structure
     101 -
     102 -```
     103 -context-governance/
     104 -├── core/                              # Platform-agnostic governance
     105 -│   ├── rules/                         # Governance rules as structure
          d data (YAML)
     106 -│   │   ├── tier-protection.yaml       # File protection tiers + who c
          an modify
     107 -│   │   ├── routing-rules.yaml         # Task → agent route mapping
     108 -│   │   ├── staleness-rules.yaml       # Derivation freshness threshol
          ds
     109 -│   │   ├── escalation-rules.yaml      # When user confirmation is req
          uired
     110 -│   │   └── hardgate-rules.yaml        # Required documents per role
     111 -│   ├── scripts/                       # Platform-agnostic validation
          scripts
     112 -│   │   ├── lib/governance-config.sh   # Shared config reader (NEW)
     113 -│   │   ├── check-tier-protection.sh   # Is this file agent-writable?
          (NEW)
     114 -│   │   ├── check-governance-mode.sh   # Is governance mode expired? (
          NEW — standalone)
     115 -│   │   ├── check-staleness.sh         # Are derived docs fresh? (MOVE
           from scripts/)
     116 -│   │   ├── check-hardgate.sh          # Do required docs exist? (MOVE
           from scripts/)
     117 -│   │   ├── check-derived-edits.sh     # Derived doc direct edit? (MOV
          E from scripts/)
     118 -│   │   ├── stamp-derivation.sh        # Auto-populate derivation meta
          data (NEW)
     119 -│   │   └── pre-task-check.sh          # Combined pre-task validation
          (NEW — orchestrator)
     120 -│   ├── githooks/
     121 -│   │   └── pre-commit                 # Derived doc protection (MOVE
          from .githooks/)
     122 -│   └── governance.yaml                # Unified governance configurat
          ion
     123 -│
     124 -├── adapters/
     125 -│   ├── codex/                         # PRIMARY adapter
     126 -│   │   ├── AGENTS.md                  # Generated from core/rules/
     127 -│   │   ├── .codex/
     128 -│   │   │   └── config.toml            # Codex project config (governa
          nce settings)
     129 -│   │   ├── skills/                    # Governance skills for Codex
     130 -│   │   │   ├── governance-check/
     131 -│   │   │   │   ├── SKILL.md           # Pre-task governance validatio
          n
     132 -│   │   │   │   ├── agents/openai.yaml
     133 -│   │   │   │   └── scripts/
     134 -│   │   │   │       └── run-check.sh   # Calls core/scripts/pre-task-c
          heck.sh
     135 -│   │   │   ├── system-architect/
     136 -│   │   │   │   ├── SKILL.md
     137 -│   │   │   │   ├── agents/openai.yaml
     138 -│   │   │   │   └── scripts/
     139 -│   │   │   ├── debug/
     140 -│   │   │   ├── implementation/
     141 -│   │   │   ├── verification/
     142 -│   │   │   ├── module-architect/
     143 -│   │   │   └── frontend-specialist/
     144 -│   │   ├── scripts/
     145 -│   │   │   ├── setup.sh               # One-command adapter installat
          ion
     146 -│   │   │   ├── sandbox-init.sh        # chmod Tier 0 + git hooks
     147 -│   │   │   └── generate-agents-md.sh  # Generate AGENTS.md from core/
          rules/
     148 -│   │   └── tests/
     149 -│   │
     150 -│   └── claude-code/                   # SECONDARY adapter
     151 -│       ├── CLAUDE.md                  # Generated from core/rules/
     152 -│       ├── .claude/
     153 -│       │   ├── settings.local.json    # Hook registration
     154 -│       │   ├── skills/                # 7 governance skills (existing
          , enhanced)
     155 -│       │   └── commands/              # /bug /impl /verify /escalate
     156 -│       ├── hooks/                     # Claude Code-specific hook scr
          ipts
     157 -│       │   ├── pre-edit-guardrail.sh  # Calls core/scripts/check-tier
          -protection.sh
     158 -│       │   ├── post-edit-audit.sh     # Appends to .governance/audit-
          log.jsonl
     159 -│       │   └── session-summary.sh     # Generates session summary
     160 -│       ├── scripts/
     161 -│       │   └── setup.sh              # One-command adapter installati
          on
     162 -│       └── tests/
     163 -│
     164 -├── docs/templates/                    # Governance document templates
           (unchanged)
     165 -├── scripts/bootstrap-project.sh       # Bootstrap (enhanced with --ad
          apter)
     166 -└── tests/
     167 -    └── core/                          # Core script tests
     168 -```
     169 -
     170 -### 2.2 Information Flow
     171 -
     172 -```
     173 -governance.yaml + core/rules/*.yaml
     174 -         │
     175 -         │ (read by)
     176 -         │
     177 -   core/scripts/*.sh ◄── Platform-agnostic validation
     178 -         │
     179 -    ┌────┴────────────────┐
     180 -    │                     │
     181 -    ▼                     ▼
     182 -  Codex Adapter         Claude Code Adapter
     183 -    │                     │
     184 -    ├─ Skills             ├─ Skills (+ checkpoint scripts)
     185 -    │  (scripts/ call     │
     186 -    │   core/scripts/)    ├─ Hooks (call core/scripts/)
     187 -    │                     │
     188 -    ├─ AGENTS.md          ├─ CLAUDE.md
     189 -    │  (generated from    │  (generated from core/rules/)
     190 -    │   core/rules/)      │
     191 -    │                     ├─ Commands (/bug /impl /verify)
     192 -    ├─ .codex/config.toml │
     193 -    │                     ├─ .claude/settings.local.json
     194 -    ├─ sandbox-init.sh    │
     195 -    │  (chmod 444)        └─ (no OS sandbox equivalent)
     196 -    │
     197 -    └─ git pre-commit hook
     198 -```
     199 -
     200 ----
     201 -
     202 -## 3. Core: Platform-Agnostic Governance Rules
     203 -
     204 -### 3.1 Rule Data Files (YAML)
     205 -
     206 -All governance rules expressed as structured YAML data. Adapters read
          these and translate to platform-native formats.
     207 -
     208 -#### core/rules/tier-protection.yaml
     209 -
     210 -```yaml
     211 -# Who can modify which governance documents.
     212 -# Adapters enforce via:
     213 -#   Codex  → chmod 444 (POSIX) + AGENTS.md instructions + skill checkp
          oints
     214 -#   Claude → PreToolUse hook (exit 2) + skill checkpoints
     215 -
     216 -tiers:
     217 -  - tier: 0
     218 -    files: ["PROJECT_BASELINE.md"]
     219 -    writable_by: [user]
     220 -    enforcement: read-only
     221 -    description: "Business truth root"
     222 -
     223 -  - tier: 0.5
     224 -    files: ["system/BASELINE_INTERPRETATION_LOG.md"]
     225 -    writable_by: [user, system-architect-with-confirmation]
     226 -    enforcement: restricted
     227 -    description: "User-confirmed semantic clarifications"
     228 -
     229 -  - tier: 0.8
     230 -    files: ["PROJECT_ARCHITECTURE_BASELINE.md"]
     231 -    writable_by: [user]
     232 -    enforcement: read-only
     233 -    description: "User-owned architecture floor"
     234 -
     235 -  - tier: 1
     236 -    files: ["system/SYSTEM_GOAL_PACK.md"]
     237 -    writable_by: [system-architect]
     238 -    derivation_required: true
     239 -    upstream: ["PROJECT_BASELINE.md", "system/BASELINE_INTERPRETATION_
          LOG.md"]
     240 -
     241 -  - tier: 3
     242 -    files: ["system/SYSTEM_INVARIANTS.md"]
     243 -    writable_by: [system-architect]
     244 -    derivation_required: true
     245 -    upstream: ["PROJECT_BASELINE.md", "system/BASELINE_INTERPRETATION_
          LOG.md"]
     246 -
     247 -  - tier: 4
     248 -    pattern: "modules/*/MODULE_CONTRACT.md"
     249 -    writable_by: [module-architect]
     250 -    derivation_required: false
     251 -```
     252 -
     253 -#### core/rules/routing-rules.yaml
     254 -
     255 -```yaml
     256 -routes:
     257 -  - type: bug
     258 -    triggers: ["bug", "fix", "broken", "regression", "fail", "crash",
          "error"]
     259 -    sequence: [system-architect, module-architect, debug, implementati
          on, verification]
     260 -    checkpoint_before: [implementation]
     261 -    checkpoint_script: "core/scripts/check-hardgate.sh debug"
     262 -
     263 -  - type: feature
     264 -    triggers: ["add", "implement", "create", "refactor", "feature", "b
          uild"]
     265 -    sequence: [system-architect, module-architect, implementation, ver
          ification]
     266 -    checkpoint_before: [implementation]
     267 -    checkpoint_script: "core/scripts/check-hardgate.sh implementation"
     268 -
     269 -  - type: design
     270 -    triggers: ["design", "architect", "protocol", "document", "plan",
          "contract"]
     271 -    sequence: [system-architect, module-architect, verification]
     272 -
     273 -  - type: ui
     274 -    triggers: ["ui", "frontend", "visual", "accessibility", "layout",
          "css"]
     275 -    modifier: add-frontend-specialist
     276 -
     277 -  - type: authority
     278 -    triggers: ["conflict", "dispute", "authority", "baseline", "tier"]
     279 -    sequence: [system-architect]
     280 -```
     281 -
     282 -#### core/rules/escalation-rules.yaml
     283 -
     284 -```yaml
     285 -always_require_user:
     286 -  - type: baseline-change
     287 -  - type: tier-0.8-change
     288 -  - type: business-ambiguity
     289 -  - type: scope-ambiguity
     290 -
     291 -never_require_user:
     292 -  - type: technical-design
     293 -  - type: testing-strategy
     294 -  - type: implementation-approach
     295 -
     296 -root_cause_escalation:
     297 -  - level: code
     298 -    requires_user: false
     299 -  - level: module
     300 -    requires_user: false
     301 -  - level: cross-module
     302 -    requires_user: false
     303 -  - level: engineering-constraint
     304 -    requires_user: false
     305 -  - level: architecture
     306 -    requires_user: conditional  # Only if Tier 0.8 change or business-
          semantic impact
     307 -  - level: baseline
     308 -    requires_user: always
     309 -```
     310 -
     311 -#### Hardgate Rules: Bootstrap Pack Pattern (Already Implemented)
     312 -
     313 -Hardgate rules are NOT stored in a separate YAML file. They are embedd
          ed in **Bootstrap Pack** templates as `required_files` frontmatter — o
          ne per role. The existing `scripts/check-hardgate.sh` reads these pack
          s as the authoritative source, with hardcoded fallback when packs are
          absent.
     314 -
     315 -**Authoritative sources (already exist):**
     316 -- `docs/templates/system/SYSTEM_BOOTSTRAP_PACK.template.md` → System A
          rchitect required files
     317 -- `docs/templates/debug/DEBUG_BOOTSTRAP_PACK.template.md` → Debug Agen
          t required files
     318 -- `docs/templates/modules/MODULE_BOOTSTRAP_PACK.template.md` → Module
          Architect required files
     319 -- `docs/templates/verification/VERIFICATION_BOOTSTRAP_PACK.template.md
          ` → Verification Agent required files
     320 -
     321 -**Existing script interface:**
     322 -```bash
     323 -scripts/check-hardgate.sh --role system-architect --target /path/to/pr
          oject [--module name]
     324 -# Exit 0 = PASSED, Exit 1 = FAILED (missing files), Exit 2 = invalid a
          rguments
     325 -```
     326 -
     327 -**For the core/ extraction:** Instead of creating a new `core/rules/ha
          rdgate-rules.yaml`, the core script wraps the existing `check-hardgate
          .sh` logic. Bootstrap Pack frontmatter remains the single source of tr
          uth — this follows the principle that each document is self-describing
          .
     328 -
     329 -### 3.2 Core Validation Scripts
     330 -
     331 -**Already implemented** (in `scripts/`; need to be moved to `core/scri
          pts/` or wrapped):
     332 -- `scripts/check-hardgate.sh` — `--role ROLE --target PATH [--module N
          AME]` → exit 0/1/2
     333 -- `scripts/check-staleness.sh` — `--target PATH` → exit 0/1
     334 -- `scripts/check-derived-edits.sh` — `[--strict]` → exit 0/1
     335 -- `.githooks/pre-commit` — calls check-derived-edits.sh --strict
     336 -- `scripts/bootstrap-project.sh --validate` — includes governance mode
           expiry, staleness, architecture baseline, BIL cross-check
     337 -
     338 -**Still need to create:**
     339 -- `core/scripts/pre-task-check.sh` — combined pre-task validation (orc
          hestrates existing scripts)
     340 -- `core/scripts/check-governance-mode.sh` — standalone mode expiry che
          ck (currently only in `--validate`)
     341 -- `core/scripts/check-tier-protection.sh` — standalone tier protection
           check
     342 -- `core/scripts/lib/governance-config.sh` — shared config reader for g
          overnance.yaml
     343 -
     344 -Exit codes across all scripts: `0` = pass, `1` = fail/warning, `2` = b
          lock/invalid args.
     345 -
     346 -#### core/scripts/pre-task-check.sh (NEW — orchestrates existing scrip
          ts)
     347 -
     348 -```bash
     349 -#!/usr/bin/env bash
     350 -# Combined pre-task governance validation.
     351 -# Called by both adapters before any task begins.
     352 -# Orchestrates existing enforcement scripts.
     353 -#
     354 -# Usage: pre-task-check.sh --target PATH [--task-type TYPE] [--role RO
          LE] [--module NAME]
     355 -
     356 -set -euo pipefail
     357 -SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
     358 -source "$SCRIPT_DIR/lib/governance-config.sh"
     359 -
     360 -TASK_TYPE="" TARGET="" ROLE="" MODULE=""
     361 -
     362 -while [[ $# -gt 0 ]]; do
     363 -  case "$1" in
     364 -    --task-type) TASK_TYPE="$2"; shift 2 ;;
     365 -    --target)    TARGET="$2"; shift 2 ;;
     366 -    --role)      ROLE="$2"; shift 2 ;;
     367 -    --module)    MODULE="$2"; shift 2 ;;
     368 -    *) shift ;;
     369 -  esac
     370 -done
     371 -
     372 -[[ -z "$TARGET" ]] && TARGET="."
     373 -WARNINGS=0 VIOLATIONS=0
     374 -
     375 -# Check 1: Governance mode expiry (standalone script)
     376 -if ! "$SCRIPT_DIR/check-governance-mode.sh" --target "$TARGET" > /dev/
          null 2>&1; then
     377 -  echo "VIOLATION: Governance mode expired." >&2
     378 -  VIOLATIONS=$((VIOLATIONS + 1))
     379 -fi
     380 -
     381 -# Check 2: Required documents for role (existing check-hardgate.sh)
     382 -if [[ -n "$ROLE" ]]; then
     383 -  HARDGATE_ARGS=(--role "$ROLE" --target "$TARGET")
     384 -  [[ -n "$MODULE" ]] && HARDGATE_ARGS+=(--module "$MODULE")
     385 -  if ! "$SCRIPT_DIR/check-hardgate.sh" "${HARDGATE_ARGS[@]}" > /dev/nu
          ll 2>&1; then
     386 -    echo "VIOLATION: Required documents missing for role '$ROLE'." >&2
     387 -    VIOLATIONS=$((VIOLATIONS + 1))
     388 -  fi
     389 -fi
     390 -
     391 -# Check 3: Derived document staleness (existing check-staleness.sh)
     392 -STALE=$("$SCRIPT_DIR/check-staleness.sh" --target "$TARGET" 2>/dev/nul
          l | grep -c "STALE" || true)
     393 -if [[ "$STALE" -gt 0 ]]; then
     394 -  echo "WARNING: $STALE derived document(s) are stale." >&2
     395 -  WARNINGS=$((WARNINGS + 1))
     396 -fi
     397 -
     398 -# Check 4: Pending escalations
     399 -ESC_FILE="$(gc_get "governance_data" ".governance")/escalations.jsonl"
     400 -if [[ -f "$ESC_FILE" ]]; then
     401 -  PENDING=$(grep -c '"status":"pending"' "$ESC_FILE" 2>/dev/null || tr
          ue)
     402 -  if [[ "$PENDING" -gt 0 ]]; then
     403 -    echo "WARNING: $PENDING pending escalation(s)." >&2
     404 -    WARNINGS=$((WARNINGS + 1))
     405 -  fi
     406 -fi
     407 -
     408 -# Result
     409 -if [[ "$VIOLATIONS" -gt 0 ]]; then
     410 -  echo "BLOCKED: $VIOLATIONS violation(s), $WARNINGS warning(s)." >&2
     411 -  exit 2
     412 -elif [[ "$WARNINGS" -gt 0 ]]; then
     413 -  echo "PASSED with $WARNINGS warning(s)." >&2
     414 -  exit 1
     415 -else
     416 -  echo "PASSED: All governance checks passed." >&2
     417 -  exit 0
     418 -fi
     419 -```
     420 -
     421 -### 3.3 governance.yaml
     422 -
     423 -```yaml
     424 -config_version: 1
     425 -adapter: codex  # codex | claude-code (set by bootstrap)
     426 -governance_level: 3  # 1-5
     427 -
     428 -enforcement:
     429 -  level: strict      # strict | advisory | off
     430 -  fail_closed: true
     431 -
     432 -staleness:
     433 -  max_hours: 72
     434 -  block_on_stale: false
     435 -
     436 -mode:
     437 -  check_expiry: true
     438 -  default_mode: steady-state
     439 -
     440 -loop_detection:
     441 -  enabled: true
     442 -  warn_threshold: 3
     443 -  hard_limit: 5
     444 -
     445 -escalation:
     446 -  persist_to_disk: true
     447 -  resurface_pending: true
     448 -
     449 -audit:
     450 -  enabled: true
     451 -  log_path: .governance/audit-log.jsonl
     452 -
     453 -modules:
     454 -  require_contract: true
     455 -
     456 -paths:
     457 -  governance_root: docs/agents
     458 -  governance_data: .governance
     459 -```
     460 -
     461 ----
     462 -
     463 -## 4. Codex Adapter (PRIMARY)
     464 -
     465 -### 4.1 Enforcement Strategy
     466 -
     467 -Codex has no tool hooks but has a full Skills system + OS sandbox + gi
          t hooks:
     468 -
     469 -| Layer | Mechanism | What It Enforces | Bypassable? |
     470 -|-------|-----------|-----------------|-------------|
     471 -| **OS** | `chmod 444` on Tier 0 files | File write protection | No (k
          ernel-level) |
     472 -| **Git** | pre-commit hook | Derived doc protection, metadata validat
          ion | No (blocks commit) |
     473 -| **Skill** | scripts/ in governance skills call core/scripts/ | Pre-t
          ask validation, role checkpoints | Skippable (agent choice) |
     474 -| **AGENTS.md** | Instructions + checkpoint commands | Routing, escala
          tion rules | Skippable (agent choice) |
     475 -| **Config** | .codex/config.toml | Governance parameters | User-edita
          ble |
     476 -
     477 -**Layered defense:** Even if the agent ignores AGENTS.md instructions
          and skips skill checkpoints, it still CANNOT:
     478 -- Write to Tier 0 files (chmod 444 → "Permission denied")
     479 -- Commit derived doc edits without metadata (pre-commit hook → rejecte
          d)
     480 -
     481 -### 4.2 Codex Skills
     482 -
     483 -Each governance role becomes a Codex Skill with `scripts/` that call c
          ore validation:
     484 -
     485 -#### adapters/codex/skills/governance-check/SKILL.md
     486 -
     487 -```markdown
     488 ----
     489 -name: governance-check
     490 -description: Run governance validation before starting any task. Check
          s governance mode, required documents, tier protection, staleness, and
           pending escalations.
     491 ----
     492 -
     493 -# Governance Check
     494 -
     495 -Run this skill before starting any task to validate governance prerequ
          isites.
     496 -
     497 -## Usage
     498 -
     499 -Invoke explicitly with `$governance-check` or implicitly when starting
           a new task.
     500 -
     501 -## Steps
     502 -
     503 -1. Run the pre-task validation script:
     504 -   ```bash
     505 -   bash core/scripts/pre-task-check.sh --task-type "$TASK_TYPE" --role
           "$ROLE"
     506 -   ```
     507 -
     508 -2. If exit code is 2 (BLOCKED): **STOP**. Address violations before pr
          oceeding.
     509 -3. If exit code is 1 (WARNINGS): Note warnings, proceed with caution.
     510 -4. If exit code is 0 (PASSED): Proceed normally.
     511 -
     512 -## What It Checks
     513 -
     514 -- Governance mode not expired
     515 -- Required documents exist for your role
     516 -- Target files are not tier-protected
     517 -- Derived documents are not stale
     518 -- No pending unresolved escalations
     519 -```
     520 -
     521 -#### adapters/codex/skills/governance-check/agents/openai.yaml
     522 -
     523 -```yaml
     524 -interface:
     525 -  display_name: "Governance Check"
     526 -  short_description: "Validate governance prerequisites before task"
     527 -  brand_color: "#DC2626"
     528 -policy:
     529 -  allow_implicit_invocation: true  # Auto-invoke when task detected
     530 -```
     531 -
     532 -#### adapters/codex/skills/governance-check/scripts/run-check.sh
     533 -
     534 -```bash
     535 -#!/usr/bin/env bash
     536 -# Thin wrapper: calls core pre-task-check from Codex skill context
     537 -CORE="$(cd "$(dirname "$0")/../../../../core/scripts" && pwd)"
     538 -exec "$CORE/pre-task-check.sh" "$@"
     539 -```
     540 -
     541 -#### adapters/codex/skills/system-architect/SKILL.md
     542 -
     543 -```markdown
     544 ----
     545 -name: system-architect
     546 -description: Establishes what is true in the governance hierarchy. Rea
          ds PROJECT_BASELINE, derives downstream documents, resolves authority
          conflicts. Activate when documents conflict, historical mitigations ar
          e treated as baselines, or authority hierarchy needs adjudication.
     547 ----
     548 -
     549 -# System Architect Role
     550 -
     551 -## Activation
     552 -
     553 -Activate when:
     554 -- Documents conflict or authority hierarchy needs adjudication
     555 -- PROJECT_BASELINE has been created/updated and derived docs need refr
          esh
     556 -- Historical mitigations are treated as baselines
     557 -- Code is treated as design truth
     558 -
     559 -## Pre-Activation Checkpoint
     560 -
     561 -```bash
     562 -bash core/scripts/pre-task-check.sh --role system-architect
     563 -```
     564 -If BLOCKED, address violations first.
     565 -
     566 -## Mandatory Document Loading
     567 -
     568 -Read ALL of the following (this is a HARD-GATE):
     569 -1. `docs/agents/PROJECT_BASELINE.md` (Tier 0)
     570 -2. `docs/agents/system/BASELINE_INTERPRETATION_LOG.md` (Tier 0.5)
     571 -3. `docs/agents/PROJECT_ARCHITECTURE_BASELINE.md` (Tier 0.8)
     572 -4. `docs/agents/system/SYSTEM_GOAL_PACK.md` (Tier 1)
     573 -5. `docs/agents/system/ENGINEERING_CONSTRAINTS.md` (Tier 1.5)
     574 -6. `docs/agents/system/SYSTEM_ARCHITECTURE.md` (Tier 2)
     575 -7. `docs/agents/system/SYSTEM_INVARIANTS.md` (Tier 3)
     576 -8. `docs/agents/system/SYSTEM_AUTHORITY_MAP.md`
     577 -9. `docs/agents/execution/GOVERNANCE_MODE.md`
     578 -
     579 -## Judgment Protocol
     580 -
     581 -When authority conflict is found:
     582 -1. Identify the conflicting documents and their tiers
     583 -2. Higher tier wins (Tier 0 > Tier 1 > ... > Tier 7)
     584 -3. If same tier: escalate to user
     585 -4. After resolution: update relevant artifacts
     586 -
     587 -## Derivation Protocol
     588 -
     589 -When deriving downstream documents from BASELINE:
     590 -1. Read all upstream sources
     591 -2. Derive the document
     592 -3. Stamp metadata: `bash core/scripts/stamp-derivation.sh <derived> <u
          pstream1> [upstream2...]`
     593 -4. Verify derivation is consistent with upstream
     594 -
     595 -## Business Ambiguity Protocol
     596 -
     597 -When business meaning is ambiguous:
     598 -1. Create BASELINE_INTERPRETATION_LOG entry with candidate interpretat
          ions
     599 -2. Present to user for confirmation
     600 -3. Do NOT proceed with downstream derivation until confirmed
     601 -```
     602 -
     603 -Similar SKILL.md files for: debug, implementation, verification, modul
          e-architect, frontend-specialist — each adapted from existing `.claude
          /skills/` content with added checkpoint scripts.
     604 -
     605 -### 4.3 sandbox-init.sh
     606 -
     607 -```bash
     608 -#!/usr/bin/env bash
     609 -# adapters/codex/scripts/sandbox-init.sh
     610 -# Sets up OS-level governance protections. Run once at session start.
     611 -# Referenced in AGENTS.md as mandatory first step.
     612 -#
     613 -# Leverages existing enforcement infrastructure:
     614 -# - .githooks/pre-commit (already exists — calls check-derived-edits.s
          h --strict)
     615 -# - scripts/check-hardgate.sh, check-staleness.sh, check-derived-edits
          .sh (already exist)
     616 -
     617 -set -euo pipefail
     618 -SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
     619 -CORE="$SCRIPT_DIR/../../../core"
     620 -source "$CORE/scripts/lib/governance-config.sh"
     621 -
     622 -GOVERNANCE_ROOT=$(gc_get "governance_root" "docs/agents")
     623 -LEVEL=$(gc_get "governance_level" "3")
     624 -
     625 -echo "=== Context Governance: Sandbox Init (Codex) ==="
     626 -echo "Level: $LEVEL | Enforcement: $(gc_get 'level' 'strict')"
     627 -
     628 -# --- Tier 0/0.5/0.8: chmod 444 (POSIX file protection) ---
     629 -if [[ "$LEVEL" -ge 3 ]]; then
     630 -  for f in \
     631 -    "$GOVERNANCE_ROOT/PROJECT_BASELINE.md" \
     632 -    "$GOVERNANCE_ROOT/system/BASELINE_INTERPRETATION_LOG.md" \
     633 -    "$GOVERNANCE_ROOT/PROJECT_ARCHITECTURE_BASELINE.md"
     634 -  do
     635 -    if [[ -f "$f" ]]; then
     636 -      chmod 444 "$f"
     637 -      echo "PROTECTED (read-only): $f"
     638 -    fi
     639 -  done
     640 -fi
     641 -
     642 -# --- Git pre-commit hook ---
     643 -# .githooks/pre-commit already exists in the framework. Just activate
          it.
     644 -if [[ "$LEVEL" -ge 3 && -d .git ]]; then
     645 -  if [[ -d .githooks ]]; then
     646 -    git config core.hooksPath .githooks
     647 -    echo "ACTIVATED: .githooks/pre-commit (derived document protection
          )"
     648 -  else
     649 -    # Fallback: install hook directly
     650 -    mkdir -p .git/hooks
     651 -    cat > .git/hooks/pre-commit << 'HOOKEOF'
     652 -#!/usr/bin/env bash
     653 -CORE="core/scripts"
     654 -[[ -x "$CORE/check-derived-edits.sh" ]] && "$CORE/check-derived-edits.
          sh" --strict
     655 -HOOKEOF
     656 -    chmod +x .git/hooks/pre-commit
     657 -    echo "INSTALLED: .git/hooks/pre-commit"
     658 -  fi
     659 -fi
     660 -
     661 -# --- Create .governance/ directory ---
     662 -mkdir -p .governance
     663 -echo "CREATED: .governance/ audit directory"
     664 -
     665 -# --- Initial governance check ---
     666 -"$CORE/scripts/pre-task-check.sh" --target "." 2>&1 || true
     667 -
     668 -echo "=== Sandbox init complete ==="
     669 -```
     670 -
     671 -### 4.4 AGENTS.md (Generated)
     672 -
     673 -`generate-agents-md.sh` produces AGENTS.md from `core/rules/*.yaml`. K
          ey sections:
     674 -
     675 -```markdown
     676 -# Context Governance — Codex Adapter
     677 -
     678 -> Auto-generated from core/rules/. Regenerate: bash adapters/codex/scr
          ipts/generate-agents-md.sh
     679 -
     680 -## First-Run Setup
     681 -
     682 -Run once when opening this project:
     683 -```
     684 -bash adapters/codex/scripts/sandbox-init.sh
     685 -```
     686 -
     687 -## Before Every Task
     688 -
     689 -Invoke the governance check skill:
     690 -```
     691 -$governance-check
     692 -```
     693 -Or manually: `bash core/scripts/pre-task-check.sh --task-type TYPE --r
          ole ROLE`
     694 -
     695 -## Task Routing
     696 -
     697 -| Task Type | Route |
     698 -|-----------|-------|
     699 -| bug / regression / test failure | system-architect → module-architec
          t → debug → implementation → verification |
     700 -| feature / refactor | system-architect → module-architect → implement
          ation → verification |
     701 -| design / architecture | system-architect → module-architect → verifi
          cation |
     702 -| UI / interaction / a11y | Add frontend-specialist to applicable rout
          e |
     703 -| authority dispute | system-architect only |
     704 -
     705 -Activate each role by invoking its skill: `$system-architect`, `$debug
          `, `$implementation`, etc.
     706 -
     707 -## File Protection (Enforced by OS Permissions)
     708 -
     709 -These files are chmod 444 — you WILL get "Permission denied":
     710 -- docs/agents/PROJECT_BASELINE.md (Tier 0)
     711 -- docs/agents/system/BASELINE_INTERPRETATION_LOG.md (Tier 0.5)
     712 -- docs/agents/PROJECT_ARCHITECTURE_BASELINE.md (Tier 0.8)
     713 -
     714 -To change these files, output proposed changes and ask the user.
     715 -
     716 -## Escalation Rules
     717 -[... generated from core/rules/escalation-rules.yaml ...]
     718 -
     719 -## Hard Rules
     720 -1. No fix without root cause.
     721 -2. No implementation without contract.
     722 -3. No completion without evidence.
     723 -4. Code is evidence, not truth.
     724 -5. Downstream does not rewrite upstream truth.
     725 -6. Derived documents never hand-edited.
     726 -7. Constraints by mechanism, not expectation.
     727 -8. Design tasks default to a complete draft.
     728 -9. MODULE_CONTRACT is approved truth, not code snapshot.
     729 -10. Inference is not root cause.
     730 -```
     731 -
     732 -### 4.5 .codex/config.toml
     733 -
     734 -```toml
     735 -# Context Governance — Codex project config
     736 -# This file is checked into the repo and shared with the team.
     737 -
     738 -model = "gpt-5.4"
     739 -approval_policy = "on-request"
     740 -sandbox_mode = "workspace-write"
     741 -
     742 -# Governance skills are auto-discovered from adapters/codex/skills/
     743 -# To disable a specific skill:
     744 -# [[skills.config]]
     745 -# path = "adapters/codex/skills/governance-check/SKILL.md"
     746 -# enabled = false
     747 -```
     748 -
     749 -### 4.6 Codex Adapter Enforcement Summary
     750 -
     751 -| Governance Rule | Codex Mechanism | Level |
     752 -|-----------------|----------------|-------|
     753 -| Tier 0/0.5/0.8 protection | `chmod 444` | **Kernel** (unbypassable)
          |
     754 -| Derived doc commit block | git pre-commit hook | **Git** (unbypassab
          le) |
     755 -| Governance mode expiry | `$governance-check` skill → core script | *
          *Skill** (agent-invoked) |
     756 -| Required docs exist | Role skill checkpoint → core script | **Skill*
          * |
     757 -| Staleness detection | `$governance-check` → core script | **Skill**
          |
     758 -| No impl without contract | `$implementation` skill checkpoint | **Sk
          ill** |
     759 -| Routing rules | AGENTS.md + skill activation | **Prompt** |
     760 -| Escalation rules | AGENTS.md + skill instructions | **Prompt** |
     761 -| Derivation metadata | `stamp-derivation.sh` in system-architect skil
          l | **Skill** |
     762 -
     763 ----
     764 -
     765 -## 5. Claude Code Adapter (SECONDARY)
     766 -
     767 -### 5.1 Enforcement Strategy
     768 -
     769 -Claude Code's unique advantage is **tool hooks** — real-time intercept
          ion that Codex lacks:
     770 -
     771 -| Layer | Mechanism | What It Enforces | Bypassable? |
     772 -|-------|-----------|-----------------|-------------|
     773 -| **Hook** | PreToolUse exit 2 | Tier protection, contract check | No
          (Claude Code enforced) |
     774 -| **Hook** | PostToolUse | Automatic audit trail | No (auto-fires) |
     775 -| **Hook** | Stop | Session summary | No (auto-fires) |
     776 -| **Git** | pre-commit hook | Derived doc protection | No (blocks comm
          it) |
     777 -| **Skill** | Checkpoint scripts in skills | Pre-task validation | Ski
          ppable |
     778 -| **CLAUDE.md** | Instructions | Routing, escalation | Skippable |
     779 -| **Command** | /bug /impl /verify /escalate | Quick-access governance
           | Optional |
     780 -
     781 -### 5.2 Hook Pipeline (calls core scripts)
     782 -
     783 -```jsonc
     784 -// adapters/claude-code/.claude/settings.local.json
     785 -{
     786 -  "hooks": {
     787 -    "PreToolUse": [
     788 -      {
     789 -        "matcher": "Edit|Write",
     790 -        "command": "bash adapters/claude-code/hooks/pre-edit-guardrail
          .sh",
     791 -        "timeout": 5000
     792 -      }
     793 -    ],
     794 -    "PostToolUse": [
     795 -      {
     796 -        "matcher": "Edit|Write",
     797 -        "command": "bash adapters/claude-code/hooks/post-edit-audit.sh
          ",
     798 -        "timeout": 5000
     799 -      }
     800 -    ],
     801 -    "Stop": [
     802 -      {
     803 -        "command": "bash adapters/claude-code/hooks/session-summary.sh
          ",
     804 -        "timeout": 3000
     805 -      }
     806 -    ]
     807 -  }
     808 -}
     809 -```
     810 -
     811 -```bash
     812 -#!/usr/bin/env bash
     813 -# adapters/claude-code/hooks/pre-edit-guardrail.sh
     814 -# Thin wrapper: translates Claude Code hook event → core validation
     815 -
     816 -SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
     817 -CORE="$SCRIPT_DIR/../../../core/scripts"
     818 -
     819 -FILE_PATH=$(echo "$1" | jq -r '.file_path // empty' 2>/dev/null)
     820 -[[ -z "$FILE_PATH" ]] && exit 0
     821 -
     822 -"$CORE/check-tier-protection.sh" "$FILE_PATH" "$(source "$CORE/lib/gov
          ernance-config.sh" && gc_get governance_root docs/agents)"
     823 -exit $?
     824 -```
     825 -
     826 -### 5.3 Enhanced Skills (existing skills + checkpoint scripts)
     827 -
     828 -Existing `.claude/skills/` enhanced with core script checkpoints:
     829 -
     830 -```markdown
     831 -<!-- Addition to existing .claude/skills/implementation/SKILL.md -->
     832 -
     833 -## Pre-Implementation Checkpoint
     834 -
     835 -Before writing any code, run:
     836 -```
     837 -bash core/scripts/pre-task-check.sh --task-type feature --role impleme
          ntation
     838 -```
     839 -If BLOCKED: STOP. Address violations first.
     840 -```
     841 -
     842 -### 5.4 Claude Code Adapter Enforcement Summary
     843 -
     844 -| Governance Rule | Claude Code Mechanism | Level |
     845 -|-----------------|----------------------|-------|
     846 -| Tier 0/0.5/0.8 protection | PreToolUse hook → exit 2 | **Hook** (unb
          ypassable) |
     847 -| Derived doc commit block | git pre-commit hook | **Git** (unbypassab
          le) |
     848 -| Governance mode expiry | Hook + skill checkpoint | **Hook + Skill**
          |
     849 -| Required docs exist | Skill checkpoint | **Skill** |
     850 -| Staleness detection | Skill checkpoint | **Skill** |
     851 -| No impl without contract | Hook (check for MODULE_CONTRACT) | **Hook
          ** |
     852 -| Routing rules | CLAUDE.md + skills | **Prompt** |
     853 -| Escalation rules | /escalate command + skill | **Prompt** |
     854 -| Audit trail | PostToolUse hook (automatic) | **Hook** (automatic) |
     855 -| Session summary | Stop hook (automatic) | **Hook** (automatic) |
     856 -
     857 ----
     858 -
     859 -## 6. MCP Governance Server (Core Enforcement Engine)
     860 -
     861 -### 6.1 The Problem That Adapters Alone Cannot Solve
     862 -
     863 -Sections §4-§5 above describe per-platform enforcement: chmod/hooks bl
          ock file writes, skills embed checkpoint instructions, AGENTS.md/CLAUD
          E.md define routing rules. But a critical gap remains:
     864 -
     865 -**Skills and prompt instructions are skippable.** The agent's reasonin
          g process is a black box — no external mechanism can force the agent t
          o activate `$governance-check` before writing code, or create a DEBUG_
          CASE before fixing a bug. chmod and hooks only guard files; they canno
          t enforce step sequencing.
     866 -
     867 -DeerFlow solves this with in-process middleware — every tool call pass
          es through a chain that the agent cannot bypass. Context Governance ca
          nnot do in-process interception (we don't control the agent loop). But
           we can achieve equivalent enforcement through a different mechanism.
     868 -
     869 -### 6.2 The Insight: Block Standard Paths, Provide Governed Paths
     870 -
     871 -```
     872 -Agent reasoning (black box — cannot intercept)
     873 -         │
     874 -         ▼
     875 -Agent wants to act
     876 -         │
     877 -    ┌────┴────┐
     878 -    │         │
     879 -    ▼         ▼
     880 -Standard    Governance
     881 -tool        MCP tool
     882 -    │         │
     883 -    ▼         ▼
     884 -  ❌ BLOCKED    ✅ Checks pass → execute
     885 -  (chmod/hook)    ❌ Checks fail → reject with reason
     886 -```
     887 -
     888 -If the standard path (Edit, Write) is blocked for governed files, and
          the governance MCP tools are the only alternative, then **every govern
          ance-related action must flow through the MCP server** — regardless of
           what the agent's reasoning decided.
     889 -
     890 -This is the same principle as a building with locked doors: you can th
          ink about entering any room you want, but you physically must use the
          keycard system, and the keycard system enforces access rules.
     891 -
     892 -### 6.3 MCP Governance Server Design
     893 -
     894 -Both Codex and Claude Code support MCP natively. The governance MCP se
          rver provides tools that wrap standard operations with governance chec
          ks:
     895 -
     896 -```
     897 -governance-mcp-server/
     898 -├── server.py              # MCP server (~500 lines)
     899 -├── session_state.py       # Per-session governance state tracking
     900 -├── requirements.txt       # mcp, pyyaml
     901 -└── README.md
     902 -```
     903 -
     904 -#### Tools Provided
     905 -
     906 -```yaml
     907 -# governance_start_task — MUST be called before any work
     908 -# Runs: core/scripts/pre-task-check.sh
     909 -# Sets session state: task_active, role, task_type
     910 -governance_start_task:
     911 -  input:
     912 -    task_type: string    # bug | feature | design | ui | authority
     913 -    role: string         # system-architect | debug | implementation |
           ...
     914 -    target: string       # project root path
     915 -    module: string?      # optional module name
     916 -  output:
     917 -    status: PASS | BLOCKED
     918 -    violations: string[]
     919 -    warnings: string[]
     920 -  side_effects:
     921 -    - Updates .governance/session-state.json
     922 -    - Appends to .governance/audit-log.jsonl
     923 -
     924 -# governance_edit_governed — edit files in docs/agents/
     925 -# Standard Edit tool is BLOCKED for these paths (chmod on Codex, hook
          on Claude Code)
     926 -# This is the ONLY way to modify governance documents
     927 -governance_edit_governed:
     928 -  input:
     929 -    file_path: string
     930 -    old_string: string
     931 -    new_string: string
     932 -  checks:
     933 -    - session_state.task_active == true (must start task first)
     934 -    - tier_protection: Tier 0/0.5/0.8 → REJECT (user-only)
     935 -    - derived_doc: if derivation_type present, derivation_context must
           be updated
     936 -    - role_permission: current role allowed to edit this tier?
     937 -  output:
     938 -    status: ALLOWED | REJECTED
     939 -    reason: string?
     940 -  side_effects:
     941 -    - Performs the actual file edit
     942 -    - Appends to .governance/audit-log.jsonl
     943 -
     944 -# governance_edit_code — edit code files in governed modules
     945 -# Standard Edit tool remains available for code (not blocked)
     946 -# But AGENTS.md/CLAUDE.md instructs agent to use this tool for governe
          d modules
     947 -# Provides contract checking that standard Edit cannot
     948 -governance_edit_code:
     949 -  input:
     950 -    file_path: string
     951 -    old_string: string
     952 -    new_string: string
     953 -  checks:
     954 -    - session_state.task_active == true
     955 -    - module has MODULE_CONTRACT? (Hard Rule #2)
     956 -    - if task_type == bug: session_state.debug_case_created == true?
     957 -  output:
     958 -    status: ALLOWED | REJECTED | WARNED
     959 -    reason: string?
     960 -  side_effects:
     961 -    - Performs the actual file edit
     962 -    - Appends to .governance/audit-log.jsonl
     963 -
     964 -# governance_create_debug_case — create DEBUG_CASE (bug tasks)
     965 -# Sets session state: debug_case_created = true
     966 -# Agent cannot edit code for bug tasks until this is called
     967 -governance_create_debug_case:
     968 -  input:
     969 -    module: string
     970 -    trigger: string
     971 -    environment: string
     972 -  checks:
     973 -    - session_state.task_type == "bug"
     974 -    - DEBUG_CASE_TEMPLATE exists
     975 -  output:
     976 -    debug_case_path: string
     977 -  side_effects:
     978 -    - Creates DEBUG_CASE file from template
     979 -    - Sets session_state.debug_case_created = true
     980 -
     981 -# governance_escalate — formal escalation with execution halt
     982 -governance_escalate:
     983 -  input:
     984 -    type: string  # business-ambiguity | authority-conflict | baseline
          -change | tier-0.8-change
     985 -    context: string
     986 -    options: string[]
     987 -    recommendation: string
     988 -  output:
     989 -    escalation_id: string
     990 -  side_effects:
     991 -    - Appends to .governance/escalations.jsonl with status "pending"
     992 -    - Sets session_state.escalation_pending = true
     993 -    - governance_edit_governed and governance_edit_code REJECT while p
          ending
     994 -
     995 -# governance_complete_task — verify and close task
     996 -governance_complete_task:
     997 -  input:
     998 -    evidence: string[]  # List of evidence items
     999 -  checks:
    1000 -    - All required governance steps completed for this task_type
    1001 -    - No pending escalations
    1002 -    - For bug tasks: debug_case has confirmed root cause
    1003 -  output:
    1004 -    status: COMPLETE | INCOMPLETE
    1005 -    missing_steps: string[]
    1006 -```
    1007 -
    1008 -#### Session State Machine
    1009 -
    1010 -```
    1011 -                    governance_start_task
    1012 -                           │
    1013 -                           ▼
    1014 -                    ┌──────────────┐
    1015 -                    │ task_active   │
    1016 -                    │ role = X      │
    1017 -                    │ task_type = Y │
    1018 -                    └──────┬───────┘
    1019 -                           │
    1020 -          ┌────────────────┼────────────────┐
    1021 -          │                │                │
    1022 -     (bug task)      (feature task)    (design task)
    1023 -          │                │                │
    1024 -          ▼                ▼                ▼
    1025 -  governance_create   governance_edit   governance_edit
    1026 -  _debug_case         _code             _governed
    1027 -          │                │                │
    1028 -          ▼                │                │
    1029 -  debug_case_created       │                │
    1030 -  = true                   │                │
    1031 -          │                │                │
    1032 -          ▼                │                │
    1033 -  governance_edit          │                │
    1034 -  _code (now allowed)      │                │
    1035 -          │                │                │
    1036 -          └────────────────┼────────────────┘
    1037 -                           │
    1038 -                           ▼
    1039 -                  governance_complete_task
    1040 -                           │
    1041 -                           ▼
    1042 -                    task_active = false
    1043 -```
    1044 -
    1045 -#### Enforcement Flow Example: Bug Fix Without DEBUG_CASE
    1046 -
    1047 -```
    1048 -Agent reasoning: "I see the bug, let me just fix it directly"
    1049 -
    1050 -1. Agent calls Edit("src/auth/handler.ts", ...)
    1051 -   → Codex: file is writable (code files not chmod'd) — BUT:
    1052 -     AGENTS.md says "use governance_edit_code for governed modules"
    1053 -   → Claude Code: PreToolUse hook checks — if module is governed,
    1054 -     stderr warning "Use governance_edit_code for governed modules"
    1055 -
    1056 -2. Agent calls governance_edit_code("src/auth/handler.ts", ...)
    1057 -   → MCP Server checks session_state:
    1058 -     - task_active? → false (never called governance_start_task)
    1059 -   → REJECTED: "Call governance_start_task first."
    1060 -
    1061 -3. Agent calls governance_start_task(task_type="bug", role="debug")
    1062 -   → MCP Server runs pre-task-check.sh
    1063 -   → PASS. session_state = {task_active: true, task_type: "bug", role:
           "debug"}
    1064 -
    1065 -4. Agent calls governance_edit_code("src/auth/handler.ts", ...)
    1066 -   → MCP Server checks:
    1067 -     - task_active? → true
    1068 -     - task_type == "bug" && debug_case_created? → false
    1069 -   → REJECTED: "Bug tasks require DEBUG_CASE. Call governance_create_d
          ebug_case."
    1070 -
    1071 -5. Agent calls governance_create_debug_case(module="auth", ...)
    1072 -   → MCP Server creates DEBUG_CASE
    1073 -   → session_state.debug_case_created = true
    1074 -
    1075 -6. Agent calls governance_edit_code("src/auth/handler.ts", ...)
    1076 -   → MCP Server checks: task_active ✓, debug_case_created ✓, MODULE_CO
          NTRACT exists ✓
    1077 -   → ALLOWED. File edited. Audit logged.
    1078 -```
    1079 -
    1080 -**The agent's reasoning wanted to skip steps 3-5. The MCP server force
          d them anyway.**
    1081 -
    1082 -### 6.4 Per-Platform Integration
    1083 -
    1084 -#### Codex + MCP Governance Server
    1085 -
    1086 -```toml
    1087 -# .codex/config.toml — MCP server registration
    1088 -[[mcp.servers]]
    1089 -name = "governance"
    1090 -type = "stdio"
    1091 -command = "python"
    1092 -args = ["governance-mcp-server/server.py"]
    1093 -```
    1094 -
    1095 -Codex enforcement stack:
    1096 -1. `chmod 444` on Tier 0 files → kernel blocks direct writes
    1097 -2. AGENTS.md instructs: "use `governance_edit_code` for governed modul
          es"
    1098 -3. MCP server enforces step sequencing via session state
    1099 -4. pre-commit hook blocks derived doc commits without metadata
    1100 -
    1101 -#### Claude Code + MCP Governance Server
    1102 -
    1103 -```json
    1104 -// .claude/settings.local.json — MCP + hooks
    1105 -{
    1106 -  "mcpServers": {
    1107 -    "governance": {
    1108 -      "command": "python",
    1109 -      "args": ["governance-mcp-server/server.py"]
    1110 -    }
    1111 -  },
    1112 -  "hooks": {
    1113 -    "PreToolUse": [
    1114 -      {
    1115 -        "matcher": "Edit|Write",
    1116 -        "command": "bash adapters/claude-code/hooks/pre-edit-guardrail
          .sh",
    1117 -        "timeout": 5000
    1118 -      }
    1119 -    ]
    1120 -  }
    1121 -}
    1122 -```
    1123 -
    1124 -Claude Code enforcement stack:
    1125 -1. PreToolUse hook → blocks `docs/agents/*` edits (forces governance_e
          dit_governed)
    1126 -2. PreToolUse hook → warns for governed module code (suggests governan
          ce_edit_code)
    1127 -3. MCP server enforces step sequencing via session state
    1128 -4. PostToolUse hook → auto audit trail
    1129 -5. pre-commit hook → derived doc protection
    1130 -
    1131 -### 6.5 What MCP Enforcement Adds to Each Platform
    1132 -
    1133 -| Without MCP Server | With MCP Server |
    1134 -|-------------------|-----------------|
    1135 -| chmod/hooks block file writes | chmod/hooks block file writes **+ MC
          P enforces step order** |
    1136 -| Skills say "run check first" (skippable) | MCP rejects actions if ch
          eck wasn't run (unskippable) |
    1137 -| No DEBUG_CASE enforcement for bug tasks | Code edit rejected until D
          EBUG_CASE exists |
    1138 -| No task lifecycle tracking | Full state machine: start → work → comp
          lete |
    1139 -| Escalation is a prompt instruction | Escalation blocks all edits unt
          il resolved |
    1140 -| Audit trail only on Claude Code (hooks) | Audit trail on both platfo
          rms (MCP logs) |
    1141 -
    1142 -### 6.6 Enforcement Level Summary (Updated)
    1143 -
    1144 -| Layer | Mechanism | Bypassable? | Platform |
    1145 -|-------|-----------|-------------|----------|
    1146 -| **Kernel** | chmod 444 | No | Codex |
    1147 -| **App hook** | PreToolUse exit 2 | No | Claude Code |
    1148 -| **MCP state** | Session state → tool rejection | No (if standard pat
          h blocked) | Both |
    1149 -| **Git** | pre-commit hook | No | Both |
    1150 -| **Skill** | Checkpoint instructions | Yes (agent can skip) | Both |
    1151 -| **Prompt** | AGENTS.md / CLAUDE.md | Yes (agent can ignore) | Both |
    1152 -
    1153 -The MCP layer fills the gap between "file-level blocking" (kernel/hook
          /git) and "step-level suggestion" (skill/prompt). But MCP alone is ins
          ufficient — the agent can bypass MCP tools and use standard Edit for c
          ode files. The commit-time enforcement layer (§6.7) closes this gap.
    1154 -
    1155 -### 6.7 Commit-Time Enforcement (Closes the MCP Bypass Gap)
    1156 -
    1157 -#### The Remaining Gap
    1158 -
    1159 -MCP governance tools enforce step sequencing, but only when the agent
          uses them. For code files (not governance docs), the standard Edit too
          l is NOT blocked — blocking it would destroy coding productivity. This
           means the agent CAN:
    1160 -
    1161 -1. Skip `governance_start_task` entirely
    1162 -2. Use standard Edit to modify code in governed modules
    1163 -3. Never create a DEBUG_CASE for a bug fix
    1164 -
    1165 -The MCP state machine is irrelevant if the agent never enters it.
    1166 -
    1167 -#### The Solution: Enforce at Commit, Not at Edit
    1168 -
    1169 -The agent can edit freely, but the work only becomes "real" when commi
          tted. The pre-commit hook checks governance state at commit time — a g
          it-level enforcement point that is unbypassable.
    1170 -
    1171 -```
    1172 -Agent edits freely (standard Edit — no interference)
    1173 -         │
    1174 -         ▼
    1175 -Agent runs: git commit
    1176 -         │
    1177 -         ▼
    1178 -pre-commit hook fires (unbypassable)
    1179 -         │
    1180 -    ┌────┴────────────────────────────────┐
    1181 -    │                                     │
    1182 -    ▼                                     ▼
    1183 -Code files staged in                  Governance docs staged
    1184 -governed module?                      (docs/agents/*)?
    1185 -    │                                     │
    1186 -    ▼                                     ▼
    1187 -Check MODULE_CONTRACT exists          check-derived-edits.sh --strict
    1188 -    │                                 (already implemented)
    1189 -    ▼
    1190 -Check session-state.json:
    1191 -  - task_type == "bug"
    1192 -    && debug_case_created != true?
    1193 -    → ❌ BLOCK
    1194 -  - escalation_pending == true?
    1195 -    → ❌ BLOCK
    1196 -    │
    1197 -    ▼
    1198 -  All pass → ✅ commit allowed
    1199 -```
    1200 -
    1201 -#### Enhanced pre-commit Hook
    1202 -
    1203 -```bash
    1204 -#!/usr/bin/env bash
    1205 -# core/githooks/pre-commit (enhanced)
    1206 -# Three enforcement layers in one hook:
    1207 -#   1. Derived document protection (already implemented)
    1208 -#   2. Module contract requirement
    1209 -#   3. Governance session state validation
    1210 -
    1211 -set -euo pipefail
    1212 -
    1213 -SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    1214 -
    1215 -# Locate project root
    1216 -if [[ -d "$SCRIPT_DIR/../../core" ]]; then
    1217 -  ROOT="$SCRIPT_DIR/../.."
    1218 -elif [[ -d "$SCRIPT_DIR/../core" ]]; then
    1219 -  ROOT="$SCRIPT_DIR/.."
    1220 -else
    1221 -  ROOT="."
    1222 -fi
    1223 -
    1224 -CORE="$ROOT/core/scripts"
    1225 -GOVERNANCE_STATE="$ROOT/.governance/session-state.json"
    1226 -GOVERNANCE_ROOT="$ROOT/docs/agents"
    1227 -ESCALATION_FILE="$ROOT/.governance/escalations.jsonl"
    1228 -
    1229 -STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)
    1230 -[[ -z "$STAGED_FILES" ]] && exit 0
    1231 -
    1232 -# ─── Layer 1: Derived document protection (existing) ───
    1233 -if [[ -x "$CORE/check-derived-edits.sh" ]]; then
    1234 -  "$CORE/check-derived-edits.sh" --strict || exit 1
    1235 -fi
    1236 -
    1237 -# ─── Layer 2: Module contract requirement ───
    1238 -# "No implementation without contract" — enforced at commit time
    1239 -for f in $STAGED_FILES; do
    1240 -  # Skip non-code files
    1241 -  [[ "$f" == docs/* || "$f" == tests/* || "$f" == *.md || "$f" == core
          /* || "$f" == adapters/* ]] && continue
    1242 -
    1243 -  # Walk up directory tree looking for a governed module
    1244 -  dir=$(dirname "$f")
    1245 -  while [[ "$dir" != "." && "$dir" != "/" ]]; do
    1246 -    module_name=$(basename "$dir")
    1247 -    if [[ -d "$GOVERNANCE_ROOT/modules/$module_name" ]]; then
    1248 -      contract="$GOVERNANCE_ROOT/modules/$module_name/MODULE_CONTRACT.
          md"
    1249 -      if [[ ! -f "$contract" ]]; then
    1250 -        echo "GOVERNANCE VIOLATION: Code in module '$module_name' but
          no MODULE_CONTRACT exists." >&2
    1251 -        echo "  Staged file: $f" >&2
    1252 -        echo "  Expected: $contract" >&2
    1253 -        echo "  Action: Create the module contract first." >&2
    1254 -        exit 1
    1255 -      fi
    1256 -      break
    1257 -    fi
    1258 -    dir=$(dirname "$dir")
    1259 -  done
    1260 -done
    1261 -
    1262 -# ─── Layer 3: Session state validation ───
    1263 -if [[ -f "$GOVERNANCE_STATE" ]]; then
    1264 -  TASK_TYPE=$(python3 -c "
    1265 -import json, sys
    1266 -try:
    1267 -    s = json.load(open('$GOVERNANCE_STATE'))
    1268 -    print(s.get('task_type', ''))
    1269 -except: pass
    1270 -" 2>/dev/null || true)
    1271 -
    1272 -  DEBUG_CASE=$(python3 -c "
    1273 -import json, sys
    1274 -try:
    1275 -    s = json.load(open('$GOVERNANCE_STATE'))
    1276 -    print(str(s.get('debug_case_created', False)).lower())
    1277 -except: pass
    1278 -" 2>/dev/null || true)
    1279 -
    1280 -  # Bug task: code changes require DEBUG_CASE
    1281 -  if [[ "$TASK_TYPE" == "bug" && "$DEBUG_CASE" != "true" ]]; then
    1282 -    CODE_STAGED=$(echo "$STAGED_FILES" | grep -v '^docs/' | grep -v '\
          .md$' | head -1 || true)
    1283 -    if [[ -n "$CODE_STAGED" ]]; then
    1284 -      echo "GOVERNANCE VIOLATION: Bug task — cannot commit code withou
          t DEBUG_CASE." >&2
    1285 -      echo "  Create a DEBUG_CASE first (via governance_create_debug_c
          ase or manually)." >&2
    1286 -      exit 1
    1287 -    fi
    1288 -  fi
    1289 -fi
    1290 -
    1291 -# ─── Layer 3b: Pending escalation blocks code commits ───
    1292 -if [[ -f "$ESCALATION_FILE" ]]; then
    1293 -  PENDING=$(grep -c '"status":"pending"' "$ESCALATION_FILE" 2>/dev/nul
          l || echo "0")
    1294 -  if [[ "$PENDING" -gt 0 ]]; then
    1295 -    CODE_STAGED=$(echo "$STAGED_FILES" | grep -v '^docs/' | grep -v '\
          .md$' | head -1 || true)
    1296 -    if [[ -n "$CODE_STAGED" ]]; then
    1297 -      echo "GOVERNANCE VIOLATION: $PENDING pending escalation(s). Reso
          lve before committing code." >&2
    1298 -      exit 1
    1299 -    fi
    1300 -  fi
    1301 -fi
    1302 -
    1303 -exit 0
    1304 -```
    1305 -
    1306 -#### Three-Point Enforcement Model (Complete)
    1307 -
    1308 -The combination of MCP (edit-time) + pre-commit (commit-time) creates
          a defense-in-depth model:
    1309 -
    1310 -| Time | What's Checked | Enforcement Level | If Bypassed |
    1311 -|------|---------------|-------------------|-------------|
    1312 -| **Edit time** (MCP tools) | Step sequencing, tier protection, role p
          ermissions | Soft for code, Hard for governance docs | Agent uses stan
          dard Edit → code is modified but not committed |
    1313 -| **Commit time** (pre-commit hook) | CONTRACT exists, DEBUG_CASE exis
          ts (for bugs), no pending escalations, derived doc metadata | **Hard**
           (git-level, unbypassable) | Cannot be bypassed — git rejects the comm
          it |
    1314 -| **PR/CI time** (optional future) | Full governance validation, cross
          -module consistency | **Hard** (CI-level) | Cannot be bypassed — PR bl
          ocked |
    1315 -
    1316 -**Agent can edit freely, but cannot commit violations.** Work that doe
          sn't pass governance checks stays in the working directory and never b
          ecomes part of the project history.
    1317 -
    1318 -#### Coverage Assessment
    1319 -
    1320 -| Governance Rule | Edit-Time (MCP) | Commit-Time (Hook) | Overall |
    1321 -|----------------|-----------------|-------------------|---------|
    1322 -| Tier 0/0.5/0.8 protection | **Blocked** (chmod/hook) | **Blocked** (
          derived-edits check) | **100% enforced** |
    1323 -| Derived doc direct edit | Warned (MCP) | **Blocked** (--strict) | **
          100% enforced** |
    1324 -| No impl without contract | Advised (MCP) | **Blocked** (contract che
          ck) | **100% enforced** |
    1325 -| Bug requires DEBUG_CASE | Advised (MCP) | **Blocked** (state check)
          | **100% enforced** |
    1326 -| Pending escalation blocks work | **Blocked** (MCP) | **Blocked** (es
          calation check) | **100% enforced** |
    1327 -| Governance mode expiry | **Blocked** (MCP) | Can add to hook | **95%
           enforced** |
    1328 -| Routing order (System→Module→Debug→...) | Advised (Skills/AGENTS.md)
           | Not checkable | **0% enforced** (inherent limit) |
    1329 -
    1330 -**6 out of 7 key governance rules are now fully enforced through unbyp
          assable mechanisms.** The one exception — routing order — is inherentl
          y unobservable from outside the agent's reasoning process and cannot b
          e enforced by any framework, including DeerFlow.
    1331 -
    1332 -### 6.8 Implementation
    1333 -
    1334 -~500 lines Python. Dependencies: `mcp` SDK + `pyyaml`.
    1335 -
    1336 -```python
    1337 -# governance-mcp-server/server.py (skeleton)
    1338 -
    1339 -from mcp.server import Server
    1340 -from mcp.types import Tool, TextContent
    1341 -import json, subprocess, os
    1342 -from pathlib import Path
    1343 -from datetime import datetime, timezone
    1344 -
    1345 -app = Server("context-governance")
    1346 -
    1347 -SESSION_STATE_FILE = ".governance/session-state.json"
    1348 -AUDIT_LOG_FILE = ".governance/audit-log.jsonl"
    1349 -
    1350 -def load_state() -> dict:
    1351 -    if Path(SESSION_STATE_FILE).exists():
    1352 -        return json.loads(Path(SESSION_STATE_FILE).read_text())
    1353 -    return {
    1354 -        "task_active": False,
    1355 -        "task_type": None,
    1356 -        "role": None,
    1357 -        "debug_case_created": False,
    1358 -        "escalation_pending": False,
    1359 -        "documents_read": [],
    1360 -        "started_at": None,
    1361 -    }
    1362 -
    1363 -def save_state(state: dict):
    1364 -    Path(SESSION_STATE_FILE).parent.mkdir(parents=True, exist_ok=True)
    1365 -    Path(SESSION_STATE_FILE).write_text(json.dumps(state, indent=2))
    1366 -
    1367 -def audit(event: str, **details):
    1368 -    Path(AUDIT_LOG_FILE).parent.mkdir(parents=True, exist_ok=True)
    1369 -    entry = {"ts": datetime.now(timezone.utc).isoformat(), "event": ev
          ent, **details}
    1370 -    with open(AUDIT_LOG_FILE, "a") as f:
    1371 -        f.write(json.dumps(entry) + "\n")
    1372 -
    1373 -@app.tool()
    1374 -async def governance_start_task(task_type: str, role: str, target: str
           = ".", module: str = "") -> str:
    1375 -    """Start a governed task. Must be called before any governance act
          ion."""
    1376 -    # Run pre-task-check.sh
    1377 -    cmd = ["bash", "core/scripts/pre-task-check.sh", "--target", targe
          t, "--task-type", task_type, "--role", role]
    1378 -    if module:
    1379 -        cmd += ["--module", module]
    1380 -    result = subprocess.run(cmd, capture_output=True, text=True)
    1381 -
    1382 -    if result.returncode == 2:
    1383 -        audit("task_start_blocked", task_type=task_type, role=role, re
          ason=result.stderr.strip())
    1384 -        return f"BLOCKED: {result.stderr.strip()}"
    1385 -
    1386 -    state = load_state()
    1387 -    state.update({
    1388 -        "task_active": True,
    1389 -        "task_type": task_type,
    1390 -        "role": role,
    1391 -        "debug_case_created": False,
    1392 -        "escalation_pending": False,
    1393 -        "started_at": datetime.now(timezone.utc).isoformat(),
    1394 -    })
    1395 -    save_state(state)
    1396 -    audit("task_started", task_type=task_type, role=role)
    1397 -
    1398 -    warnings = result.stderr.strip() if result.returncode == 1 else ""
    1399 -    return f"PASS. Task started: type={task_type}, role={role}." + (f"
           Warnings: {warnings}" if warnings else "")
    1400 -
    1401 -@app.tool()
    1402 -async def governance_edit_code(file_path: str, old_string: str, new_st
          ring: str) -> str:
    1403 -    """Edit a code file in a governed module. Enforces contract and de
          bug case checks."""
    1404 -    state = load_state()
    1405 -
    1406 -    if not state.get("task_active"):
    1407 -        return "REJECTED: No active task. Call governance_start_task f
          irst."
    1408 -
    1409 -    if state.get("escalation_pending"):
    1410 -        return "REJECTED: Pending escalation must be resolved before e
          diting."
    1411 -
    1412 -    # Bug tasks require DEBUG_CASE
    1413 -    if state.get("task_type") == "bug" and not state.get("debug_case_c
          reated"):
    1414 -        return "REJECTED: Bug tasks require DEBUG_CASE. Call governanc
          e_create_debug_case first."
    1415 -
    1416 -    # Check MODULE_CONTRACT exists for the module containing this file
    1417 -    # (uses check-hardgate.sh logic or direct file check)
    1418 -    governance_root = "docs/agents"  # from governance.yaml
    1419 -    # ... module contract check logic ...
    1420 -
    1421 -    # Perform the actual edit
    1422 -    path = Path(file_path)
    1423 -    if not path.exists():
    1424 -        return f"REJECTED: File not found: {file_path}"
    1425 -
    1426 -    content = path.read_text()
    1427 -    if old_string not in content:
    1428 -        return f"REJECTED: old_string not found in {file_path}"
    1429 -
    1430 -    new_content = content.replace(old_string, new_string, 1)
    1431 -    path.write_text(new_content)
    1432 -
    1433 -    audit("code_edited", file=file_path, role=state.get("role"))
    1434 -    return f"ALLOWED: {file_path} edited successfully."
    1435 -
    1436 -# ... similar implementations for other tools ...
    1437 -
    1438 -if __name__ == "__main__":
    1439 -    import asyncio
    1440 -    from mcp.server.stdio import stdio_server
    1441 -    asyncio.run(stdio_server(app))
    1442 -```
    1443 -
    1444 ----
    1445 -
    1446 -## 7. Cross-Platform Enforcement Comparison (Updated with MCP)
    1447 -
    1448 -| Rule | Codex | Claude Code | Notes |
    1449 -|------|-------|-------------|-------|
    1450 -| Tier 0 file protection | chmod 444 **(kernel)** | Hook exit 2 **(app
          )** | Codex stronger |
    1451 -| Derived doc commit block | pre-commit **(git)** | pre-commit **(git)
          ** | Equal |
    1452 -| Real-time edit interception | N/A | PreToolUse hook | **Claude Code
          unique** |
    1453 -| **Step sequencing** | **MCP state machine** | **MCP state machine**
          | **Both — via MCP server** |
    1454 -| **Bug task requires DEBUG_CASE** | **MCP rejects code edit** | **MCP
           rejects code edit** | **Both — via MCP server** |
    1455 -| **Task lifecycle enforcement** | **MCP start → work → complete** | *
          *MCP start → work → complete** | **Both — via MCP server** |
    1456 -| **Escalation blocks edits** | **MCP rejects while pending** | **MCP
          rejects while pending** | **Both — via MCP server** |
    1457 -| Audit trail | **MCP logs (both)** | **MCP logs + PostToolUse hook**
          | Claude Code has dual audit |
    1458 -| Session summary | N/A | Stop hook | **Claude Code unique** |
    1459 -| Role activation | `$skill-name` explicit | Skill auto-routing | Simi
          lar |
    1460 -| Pre-task validation | `$governance-check` skill | Skill checkpoint |
           Same core script |
    1461 -| Escalation | MCP governance_escalate | MCP + /escalate command | Cla
          ude Code richer |
    1462 -| CI integration | `codex exec --json` | `claude --print` | Both suppo
          rted |
    1463 -| Network isolation | Sandbox default | N/A | **Codex unique** |
    1464 -
    1465 -**The MCP Governance Server is the equalizer.** It gives both platform
          s step-level enforcement that neither could achieve alone. Combined wi
          th platform-specific strengths (chmod on Codex, hooks on Claude Code),
           the governance system now has three enforcement layers:
    1466 -1. **File-level** — can you touch this file? (chmod/hooks/git)
    1467 -2. **Step-level** — have you done the prerequisites? (MCP state machin
          e)
    1468 -3. **Prompt-level** — do you know the rules? (AGENTS.md/CLAUDE.md/Skil
          ls)
    1469 -
    1470 ----
    1471 -
    1472 -## 7. Shared Infrastructure
    1473 -
    1474 -### 7.1 .governance/ Directory
    1475 -
    1476 -```
    1477 -.governance/                    # Created by both adapters
    1478 -├── audit-log.jsonl            # Governance events (both adapters appe
          nd)
    1479 -├── escalations.jsonl          # Pending/resolved escalations
    1480 -├── step-log.jsonl             # Loop detection tracking
    1481 -└── derivation-cache/
    1482 -    └── staleness-snapshot.json
    1483 -```
    1484 -
    1485 -### 7.2 Bootstrap Integration
    1486 -
    1487 -```bash
    1488 -# Codex-first (primary):
    1489 -scripts/bootstrap-project.sh --target my-project --adapter codex --lev
          el 3
    1490 -
    1491 -# Claude Code:
    1492 -scripts/bootstrap-project.sh --target my-project --adapter claude-code
           --level 3 --copy-skills --copy-commands
    1493 -
    1494 -# Both:
    1495 -scripts/bootstrap-project.sh --target my-project --adapter codex,claud
          e-code --level 3
    1496 -
    1497 -# Default (backward compatible): --adapter claude-code
    1498 -scripts/bootstrap-project.sh --target my-project
    1499 -```
    1500 -
    1501 -Bootstrap creates:
    1502 -1. `core/` (always)
    1503 -2. `governance.yaml` (always)
    1504 -3. `docs/agents/` (always)
    1505 -4. Adapter-specific:
    1506 -   - `--adapter codex` → adapters/codex/ (skills, AGENTS.md, .codex/,
          sandbox-init.sh)
    1507 -   - `--adapter claude-code` → adapters/claude-code/ (CLAUDE.md, hooks
          , .claude/)
    1508 -
    1509 ----
    1510 -
    1511 -## 8. Implementation Roadmap
    1512 -
    1513 -### Phase 1: Core Extraction (Week 1)
    1514 -
    1515 -> **Status: Partially implemented.** `check-hardgate.sh`, `check-stale
          ness.sh`, `check-derived-edits.sh`, `.githooks/pre-commit` already exi
          st in `scripts/`. Bootstrap `--validate` already includes mode expiry,
           staleness, architecture baseline checks.
    1516 -
    1517 -| ID | Task | Status | Output |
    1518 -|----|------|--------|--------|
    1519 -| 1A | Create `core/rules/*.yaml` from existing ROUTING_POLICY + SYSTE
          M_AUTHORITY_MAP | **New** | 4 rule files (tier-protection, routing-rul
          es, staleness-rules, escalation-rules). Note: hardgate rules stay in B
          ootstrap Pack frontmatter, not a separate YAML. |
    1520 -| 1B | Move existing scripts to `core/scripts/`, create missing ones |
           **Partial** | Move `check-hardgate.sh`, `check-staleness.sh`, `check-
          derived-edits.sh` → `core/scripts/`. Create new: `pre-task-check.sh` (
          orchestrator), `check-governance-mode.sh` (standalone), `check-tier-pr
          otection.sh`, `stamp-derivation.sh`. |
    1521 -| 1C | Create `governance.yaml` + `lib/governance-config.sh` | **New**
           | Config system |
    1522 -| 1D | Core tests | **New** | `tests/core/` (extend existing `tests/bo
          otstrap-project.test.sh`) |
    1523 -
    1524 -### Phase 2: Codex Adapter (Week 2-3) — PRIMARY
    1525 -
    1526 -| ID | Task | Output |
    1527 -|----|------|--------|
    1528 -| 2A | Create 7 governance skills for Codex (SKILL.md + openai.yaml +
          scripts/) | `adapters/codex/skills/` |
    1529 -| 2B | Create `sandbox-init.sh` (chmod + pre-commit) | OS-level protec
          tion |
    1530 -| 2C | Create `generate-agents-md.sh` + generated AGENTS.md | AGENTS.m
          d from rules |
    1531 -| 2D | Create `.codex/config.toml` template | Project config |
    1532 -| 2E | Create `setup.sh` (one-command installation) | Setup script |
    1533 -| 2F | Update bootstrap with `--adapter codex` | Bootstrap integration
           |
    1534 -| 2G | Codex adapter tests | `adapters/codex/tests/` |
    1535 -
    1536 -### Phase 3: Claude Code Adapter (Week 4) — SECONDARY
    1537 -
    1538 -| ID | Task | Output |
    1539 -|----|------|--------|
    1540 -| 3A | Create hook scripts wrapping core | `adapters/claude-code/hooks
          /` |
    1541 -| 3B | Move existing skills/commands, add checkpoint scripts | Enhance
          d skills |
    1542 -| 3C | Generate CLAUDE.md from rules | CLAUDE.md from rules |
    1543 -| 3D | Create settings.local.json with hook registration | Hook config
           |
    1544 -| 3E | Create setup.sh | Setup script |
    1545 -| 3F | Update bootstrap with `--adapter claude-code` | Bootstrap integ
          ration |
    1546 -| 3G | Claude Code adapter tests | `adapters/claude-code/tests/` |
    1547 -
    1548 -### Phase 4: MCP Governance Server (Week 5) — CRITICAL PATH
    1549 -
    1550 -> This is the phase that delivers the qualitative leap: step-level enf
          orcement that is unskippable.
    1551 -
    1552 -| ID | Task | Output |
    1553 -|----|------|--------|
    1554 -| 4A | MCP Server skeleton (session state, audit, MCP protocol) | `gov
          ernance-mcp-server/server.py` (~100 lines) |
    1555 -| 4B | `governance_start_task` tool (calls core/scripts/pre-task-check
          .sh) | State: task_active, role, task_type |
    1556 -| 4C | `governance_edit_governed` tool (tier check + derivation check
          + edit) | Governed doc editing |
    1557 -| 4D | `governance_edit_code` tool (contract check + debug case check
          + edit) | Code editing with governance |
    1558 -| 4E | `governance_create_debug_case` tool | DEBUG_CASE creation + sta
          te update |
    1559 -| 4F | `governance_escalate` tool (blocks edits while pending) | Forma
          l escalation |
    1560 -| 4G | `governance_complete_task` tool (verification checks) | Task li
          fecycle closure |
    1561 -| 4H | Enhanced pre-commit hook (contract check + session state + esca
          lation) | `core/githooks/pre-commit` — the commit-time enforcement lay
          er |
    1562 -| 4I | Codex MCP integration (`.codex/config.toml` MCP section) | Code
          x adapter wiring |
    1563 -| 4J | Claude Code MCP integration (settings.local.json mcpServers) |
          Claude Code adapter wiring |
    1564 -| 4K | MCP server tests | `governance-mcp-server/tests/` |
    1565 -| 4L | Pre-commit hook tests (bug without DEBUG_CASE → commit blocked)
           | `tests/core/pre-commit-hook.test.sh` |
    1566 -
    1567 -### Phase 5: Shared Infrastructure (Week 6)
    1568 -
    1569 -| ID | Task | Output |
    1570 -|----|------|--------|
    1571 -| 5A | `.governance/` directory + audit trail | Event logging (MCP + h
          ooks both write here) |
    1572 -| 5B | Escalation registry (persistent) | Cross-session escalations |
    1573 -| 5C | Loop detection (step tracker) | Repeated action detection |
    1574 -| 5D | `stamp-derivation.sh` integration | Auto-metadata |
    1575 -| 5E | Progressive governance levels (1-5) | `--level` flag |
    1576 -
    1577 -### Phase 6: Verification (Week 7)
    1578 -
    1579 -| ID | Task | Output |
    1580 -|----|------|--------|
    1581 -| 6A | Core platform-agnosticism boundary tests | No platform terms in
           core |
    1582 -| 6B | Cross-adapter consistency tests | Same rules → same behavior |
    1583 -| 6C | MCP enforcement tests (bug without DEBUG_CASE → blocked) | Step
          -level enforcement verified |
    1584 -| 6D | End-to-end: bootstrap → validate for both platforms | Full pipe
          line |
    1585 -
    1586 -### Dependency Graph
    1587 -
    1588 -```
    1589 -Phase 1 (Core — foundation):
    1590 -  1A-1D ──→ Phase 2 (Codex) + Phase 3 (Claude Code) + Phase 4 (MCP Ser
          ver)
    1591 -
    1592 -Phase 2 (Codex — PRIMARY):     Phase 3 (Claude Code):     Phase 4 (MCP
           Server):
    1593 -  2A-2G                          3A-3G                      4A-4J
    1594 -    │                              │                          │
    1595 -    └──────────────┬───────────────┘                          │
    1596 -                   │                                          │
    1597 -                   ├──── Phase 4H (Codex MCP wiring) ◄────────┘
    1598 -                   ├──── Phase 4I (Claude Code MCP wiring) ◄──┘
    1599 -                   │
    1600 -                   ▼
    1601 -             Phase 5 (Shared infra)
    1602 -                   │
    1603 -                   ▼
    1604 -             Phase 6 (Verification)
    1605 -```
    1606 -
    1607 -**Critical path:** Phase 1 → Phase 4 (MCP Server) → Phase 4H/4I (adapt
          er wiring) → Phase 6C (enforcement tests). The MCP server is the compo
          nent that transforms the system from "rules on paper" to "rules in cod
          e."
    1608 -
    1609 ----
    1610 -
    1611 -## 9. Migration Path
    1612 -
    1613 -### 9.1 What Moves Where
    1614 -
    1615 -| Current | New | Notes |
    1616 -|---------|-----|-------|
    1617 -| `AGENTS.md` (root) | `adapters/codex/AGENTS.md` (generated) | Symlin
          k at root during transition |
    1618 -| `CLAUDE.md` (root) | `adapters/claude-code/CLAUDE.md` | Symlink at r
          oot during transition |
    1619 -| `.claude/skills/` | `adapters/claude-code/.claude/skills/` | Enhance
          d with checkpoints |
    1620 -| `.claude/commands/` | `adapters/claude-code/.claude/commands/` | Unc
          hanged |
    1621 -| `.claude/settings.local.json` | `adapters/claude-code/.claude/settin
          gs.local.json` | Hooks added |
    1622 -| `scripts/check-hardgate.sh` | `core/scripts/check-hardgate.sh` | **M
          ove** (already implemented, uses `--role`/`--target`/`--module` interf
          ace) |
    1623 -| `scripts/check-staleness.sh` | `core/scripts/check-staleness.sh` | *
          *Move** (already implemented, uses `--target` interface) |
    1624 -| `scripts/check-derived-edits.sh` | `core/scripts/check-derived-edits
          .sh` | **Move** (already implemented, uses `--strict` flag) |
    1625 -| `.githooks/pre-commit` | `core/githooks/pre-commit` | **Move** (alre
          ady implemented) |
    1626 -| `scripts/bootstrap-project.sh` | Same (enhanced with `--adapter`) |
          Backward compatible; `--validate` already has mode/staleness/BIL check
          s |
    1627 -| `docs/templates/` | Same | Unchanged; Bootstrap Packs provide `requi
          red_files` for hardgate checks |
    1628 -| N/A | `core/rules/*.yaml` | New: tier-protection, routing-rules, esc
          alation-rules, staleness-rules |
    1629 -| N/A | `core/scripts/pre-task-check.sh` | New: orchestrates existing
          scripts |
    1630 -| N/A | `core/scripts/check-governance-mode.sh` | New: standalone mode
           expiry (currently only in `--validate`) |
    1631 -| N/A | `core/scripts/check-tier-protection.sh` | New: standalone tier
           check |
    1632 -| N/A | `core/scripts/stamp-derivation.sh` | New: auto-populate deriva
          tion metadata |
    1633 -| N/A | `governance.yaml` | New: unified config |
    1634 -| N/A | `governance-mcp-server/` | **New: MCP Governance Server (~500
          lines Python)** — the core enforcement engine |
    1635 -| N/A | `adapters/codex/skills/` | New: 7 governance skills for Codex
          |
    1636 -| N/A | `adapters/codex/.codex/` | New: Codex config |
    1637 -
    1638 -### 9.2 Backward Compatibility
    1639 -
    1640 -- `bootstrap-project.sh` without `--adapter` defaults to `claude-code`
    1641 -- Root AGENTS.md and CLAUDE.md preserved as symlinks during transition
    1642 -- Existing bootstrapped projects continue to work
    1643 -
    1644 ----
    1645 -
    1646 -## 10. Success Criteria
    1647 -
    1648 -### Core
    1649 -- [ ] `core/rules/*.yaml` defines all governance rules as structured d
          ata
    1650 -- [ ] `core/scripts/*.sh` validates without referencing any platform
    1651 -- [ ] Boundary test: no platform-specific terms in core files
    1652 -
    1653 -### Codex Adapter
    1654 -- [ ] 7 governance skills with SKILL.md + openai.yaml + scripts/
    1655 -- [ ] `chmod 444` makes Tier 0 files kernel-protected
    1656 -- [ ] pre-commit hook blocks unauthorized derived doc edits
    1657 -- [ ] AGENTS.md auto-generated from `core/rules/`
    1658 -- [ ] `$governance-check` skill runs pre-task validation
    1659 -- [ ] `codex exec` mode works for CI governance checks
    1660 -
    1661 -### Claude Code Adapter
    1662 -- [ ] PreToolUse hook blocks Tier 0 edits (exit 2)
    1663 -- [ ] PostToolUse hook auto-logs governance events
    1664 -- [ ] Skills enhanced with checkpoint scripts calling core
    1665 -- [ ] `/escalate` command formalizes escalation
    1666 -
    1667 -### MCP Governance Server + Commit-Time Enforcement (Qualitative Leap)
    1668 -- [ ] `governance_start_task` blocks work until pre-task checks pass
    1669 -- [ ] `governance_edit_governed` blocks Tier 0 edits, enforces derivat
          ion metadata
    1670 -- [ ] `governance_edit_code` blocks bug-task code edits until DEBUG_CA
          SE exists
    1671 -- [ ] `governance_escalate` blocks all edits while escalation is pendi
          ng
    1672 -- [ ] `governance_complete_task` validates all lifecycle steps complet
          ed
    1673 -- [ ] Session state machine enforced: start → work → complete
    1674 -- [ ] MCP server registered and working on both Codex and Claude Code
    1675 -- [ ] Pre-commit hook blocks commit of code in module without MODULE_C
          ONTRACT
    1676 -- [ ] Pre-commit hook blocks commit of code in bug task without DEBUG_
          CASE
    1677 -- [ ] Pre-commit hook blocks commit while escalation is pending
    1678 -- [ ] Agent bypassing MCP (using standard Edit) still cannot commit vi
          olations
    1679 -
    1680 -### Cross-Platform
    1681 -- [ ] Same `governance.yaml` + `core/rules/` → equivalent enforcement
          on both
    1682 -- [ ] `.governance/` audit format identical across platforms
    1683 -- [ ] MCP server provides identical enforcement on both platforms
    1684 -
    1685 ----
    1686 -
    1687 -## 11. Risks
    1688 -
    1689 -| Risk | Mitigation |
    1690 -|------|-----------|
    1691 -| **MCP server process overhead** | MCP stdio is lightweight (~10ms pe
          r call). Server is stateless between calls (reads/writes JSON files).
          No persistent daemon. |
    1692 -| **Agent uses standard Edit tool instead of MCP governance tools for
          code files** | For governed docs: standard tools are blocked (chmod/ho
          oks) — agent MUST use MCP. For code files: AGENTS.md/CLAUDE.md instruc
          ts to use governance tools; Claude Code hook warns. This is a soft bou
          ndary for code, hard boundary for governed docs. |
    1693 -| **MCP SDK compatibility across Codex and Claude Code** | Both use st
          andard MCP stdio protocol. Server implementation is SDK-agnostic (stan
          dard JSON-RPC over stdio). |
    1694 -| **Session state file conflicts (multiple agents)** | State file uses
           atomic write (write-to-temp + rename). Per-thread state if needed (ke
          yed by thread ID from MCP context). |
    1695 -| Codex skill `allow_implicit_invocation` may fire too often | Set to
          `false` for role skills; `true` only for governance-check |
    1696 -| chmod 444 persists after session — user can't edit Tier 0 | sandbox-
          init.sh only runs in Codex sandbox; document `chmod 644` restore comma
          nd |
    1697 -| AGENTS.md generated content too large for context | Monitor token co
          unt; split sections; use progressive loading via skills |
    1698 -| Core rules YAML gets out of sync with doc templates | CI test: every
           file referenced in rules exists in templates |
    1699 -| Users confused by core/ + adapters/ | Bootstrap handles all setup; u
          ser sees only their platform's interface |
    1700 -| Codex may change skill format in future versions | Pin to documented
           format; adapter tests catch format drift |
    1701 -
    1702 ----
    1703 -
    1704 -## 12. Relationship to Existing Plans
    1705 -
    1706 -| Existing Plan | Relationship |
    1707 -|--------------|-------------|
    1708 -| `2026-03-23-enforcement-mechanism-strengthening` | **Partially imple
          mented, remaining absorbed.** `check-hardgate.sh`, `check-staleness.sh
          `, `check-derived-edits.sh`, `.githooks/pre-commit` already exist. Enh
          anced `--validate` with mode expiry, staleness, BIL cross-check alread
          y integrated. Remaining work (standalone mode check, tier protection,
          stamp-derivation) absorbed into this plan's Phase 1B. |
    1709 -| `2026-03-22-project-architecture-baseline` | **Implemented.** PROJEC
          T_ARCHITECTURE_BASELINE template exists. Architecture baseline lightne
          ss check (≤50 lines, ≤2 Mermaid) in `--validate`. ARCHITECTURE_CHANGE_
          PROPOSAL template exists. Tier 0.8 in System Architect loading list. |
    1710 -| `2026-03-21-business-semantics-confirmation` | **Implemented + Exten
          ded.** Root cause level classification, escalation gate (Step 8A), and
           business-semantics boundary table in debug/SKILL.md. Escalation rules
           further formalized in `core/rules/escalation-rules.yaml`. |
    1711 -
    1712 ----
    1713 -
    1714 -## 13. Future Adapters (Not in Scope)
    1715 -
    1716 -Since the MCP Governance Server is platform-agnostic (standard MCP std
          io protocol), any platform that supports MCP gets step-level enforceme
          nt for free. Future adapters only need to provide file-level blocking
          (the platform-specific part):
    1717 -
    1718 -| Adapter | File-Level Blocking | MCP Server | Effort |
    1719 -|---------|-------------------|------------|--------|
    1720 -| DeerFlow | `GuardrailProvider` middleware | Reuse same server | ~200
           lines Python (provider only) |
    1721 -| Cursor | .cursorrules + file restrictions | Reuse same server | ~100
           lines config |
    1722 -| Gemini | GEMINI.md generated from `core/rules/` | Reuse same server
          (if Gemini supports MCP) | ~50 lines generator |
    1723 -| LangGraph | Custom nodes for file-level checks | Reuse same server |
           ~300 lines Python (nodes only) |
    1724 -| Any MCP-capable platform | Platform-specific | **Reuse same server**
           | File blocking only |