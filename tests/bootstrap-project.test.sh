#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$(mktemp -d)"
trap 'rm -rf "$TARGET"' EXIT

bash "$ROOT/scripts/bootstrap-project.sh" --target "$TARGET" --platform claude >/dev/null

test -f "$TARGET/CLAUDE.md"
test -f "$TARGET/docs/agents/BOOTSTRAP_READINESS.md"
test -f "$TARGET/docs/agents/system/SYSTEM_GOAL_PACK.md"
test -f "$TARGET/docs/agents/system/SYSTEM_AUTHORITY_MAP.md"
test -f "$TARGET/docs/agents/system/SYSTEM_INVARIANTS.md"
test -f "$TARGET/docs/agents/system/SYSTEM_BOOTSTRAP_PACK.md"
test -f "$TARGET/docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md"
test -f "$TARGET/docs/agents/system/SYSTEM_CONFLICT_REGISTER.md"
test -f "$TARGET/docs/agents/debug/DEBUG_BOOTSTRAP_PACK.md"
test -f "$TARGET/docs/agents/debug/DEBUG_CASE_TEMPLATE.md"
test -f "$TARGET/docs/agents/debug/BUG_CLASS_REGISTER.md"
test -f "$TARGET/docs/agents/debug/RECURRENCE_PREVENTION_RULES.md"
test -f "$TARGET/docs/agents/verification/ACCEPTANCE_RULES.md"
test -d "$TARGET/docs/agents/modules"
test ! -f "$TARGET/docs/agents/modules/billing/MODULE_CONTRACT.md"

# Namespace READMEs
test -f "$TARGET/docs/agents/README.md"
test -f "$TARGET/docs/agents/system/README.md"
test -f "$TARGET/docs/agents/modules/README.md"
test -f "$TARGET/docs/agents/debug/README.md"
test -f "$TARGET/docs/agents/implementation/README.md"
test -f "$TARGET/docs/agents/verification/README.md"
test -f "$TARGET/docs/agents/frontend/README.md"
test -f "$TARGET/docs/agents/execution/README.md"
test -f "$TARGET/docs/agents/task-checklists/README.md"
test -f "$TARGET/docs/plans/agents/README.md"

# Additional directories created
test -d "$TARGET/docs/agents/implementation"
test -d "$TARGET/docs/agents/frontend"
test -d "$TARGET/docs/agents/execution"
test -d "$TARGET/docs/agents/task-checklists"
test -d "$TARGET/docs/plans/agents"

echo "existing" > "$TARGET/CLAUDE.md"
bash "$ROOT/scripts/bootstrap-project.sh" --target "$TARGET" --platform claude --copy-commands >/dev/null
test "$(cat "$TARGET/CLAUDE.md")" = "existing"
test -f "$TARGET/.claude/commands/bug.md"

bash "$ROOT/scripts/bootstrap-project.sh" --target "$TARGET" --platform claude --seed-module billing >/dev/null
test -f "$TARGET/docs/agents/modules/billing/MODULE_CONTRACT.md"

# Test --copy-skills flag
TARGET_SKILLS="$(mktemp -d)"
trap 'rm -rf "$TARGET" "$TARGET_SKILLS"' EXIT
bash "$ROOT/scripts/bootstrap-project.sh" --target "$TARGET_SKILLS" --platform claude --copy-skills >/dev/null
test -d "$TARGET_SKILLS/.claude/skills"
test -f "$TARGET_SKILLS/.claude/skills/system-architect/SKILL.md"

TARGET_CODEX="$(mktemp -d)"
TARGET_GEMINI="$(mktemp -d)"
trap 'rm -rf "$TARGET" "$TARGET_SKILLS" "$TARGET_CODEX" "$TARGET_GEMINI"' EXIT

bash "$ROOT/scripts/bootstrap-project.sh" --target "$TARGET_CODEX" --platform codex >/dev/null
test -f "$TARGET_CODEX/AGENTS.md"
test ! -f "$TARGET_CODEX/CLAUDE.md"

bash "$ROOT/scripts/bootstrap-project.sh" --target "$TARGET_GEMINI" --platform gemini >/dev/null
test -f "$TARGET_GEMINI/GEMINI.md"
test ! -f "$TARGET_GEMINI/CLAUDE.md"

echo PASS
