#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/bootstrap-project.sh --target <project-path> [--seed-module <module-name>] [--platform <claude|codex|gemini>] [--copy-commands] [--copy-skills] [--force]

Options:
  --target <path>       Target project root to bootstrap
  --seed-module <name>  Optionally seed one module contract during initial bootstrap
  --module <name>       Deprecated alias for --seed-module
  --platform <name>     Copy the project-level platform entrypoint (`claude`, `codex`, or `gemini`)
  --copy-commands       Also copy .claude/commands shortcuts into the target project
  --copy-skills         Also copy .claude/skills into the target project
  --force               Overwrite existing files instead of skipping them
  -h, --help            Show this help text
EOF
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""
SEED_MODULE=""
PLATFORM="claude"
COPY_COMMANDS=0
COPY_SKILLS=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --seed-module)
      SEED_MODULE="${2:-}"
      shift 2
      ;;
    --module)
      SEED_MODULE="${2:-}"
      shift 2
      ;;
    --platform)
      PLATFORM="${2:-}"
      shift 2
      ;;
    --copy-commands)
      COPY_COMMANDS=1
      shift
      ;;
    --copy-skills)
      COPY_SKILLS=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  usage >&2
  exit 1
fi

case "$PLATFORM" in
  claude|codex|gemini)
    ;;
  *)
    echo "Unsupported platform: $PLATFORM" >&2
    usage >&2
    exit 1
    ;;
esac

mkdir -p \
  "$TARGET/docs/agents/system" \
  "$TARGET/docs/agents/system/scenarios" \
  "$TARGET/docs/agents/modules" \
  "$TARGET/docs/agents/debug" \
  "$TARGET/docs/agents/debug/cases" \
  "$TARGET/docs/agents/implementation" \
  "$TARGET/docs/agents/verification" \
  "$TARGET/docs/agents/frontend" \
  "$TARGET/docs/agents/execution" \
  "$TARGET/docs/agents/task-checklists" \
  "$TARGET/docs/plans/agents"

copy_file() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && "$FORCE" -ne 1 ]]; then
    echo "skip $dst"
    return
  fi
  cp "$src" "$dst"
  echo "write $dst"
}

copy_dir() {
  local src="$1"
  local dst="$2"

  mkdir -p "$dst"
  if [[ "$FORCE" -eq 1 ]]; then
    cp -R "$src"/. "$dst"/
    echo "write $dst/"
    return
  fi

  while IFS= read -r -d '' file; do
    local rel="${file#"$src"/}"
    local target_file="$dst/$rel"
    mkdir -p "$(dirname "$target_file")"
    if [[ -e "$target_file" ]]; then
      echo "skip $target_file"
    else
      cp "$file" "$target_file"
      echo "write $target_file"
    fi
  done < <(find "$src" -type f -print0)
}

case "$PLATFORM" in
  claude)
    copy_file "$ROOT/CLAUDE.md" "$TARGET/CLAUDE.md"
    ;;
  codex)
    copy_file "$ROOT/AGENTS.md" "$TARGET/AGENTS.md"
    ;;
  gemini)
    copy_file "$ROOT/GEMINI.md" "$TARGET/GEMINI.md"
    ;;
esac

# Namespace READMEs
copy_file "$ROOT/docs/templates/namespace-readmes/agents-root.template.md" \
  "$TARGET/docs/agents/README.md"
copy_file "$ROOT/docs/templates/namespace-readmes/system.template.md" \
  "$TARGET/docs/agents/system/README.md"
copy_file "$ROOT/docs/templates/namespace-readmes/modules.template.md" \
  "$TARGET/docs/agents/modules/README.md"
copy_file "$ROOT/docs/templates/namespace-readmes/debug.template.md" \
  "$TARGET/docs/agents/debug/README.md"
copy_file "$ROOT/docs/templates/namespace-readmes/implementation.template.md" \
  "$TARGET/docs/agents/implementation/README.md"
copy_file "$ROOT/docs/templates/namespace-readmes/verification.template.md" \
  "$TARGET/docs/agents/verification/README.md"
copy_file "$ROOT/docs/templates/namespace-readmes/frontend.template.md" \
  "$TARGET/docs/agents/frontend/README.md"
copy_file "$ROOT/docs/templates/namespace-readmes/execution.template.md" \
  "$TARGET/docs/agents/execution/README.md"
copy_file "$ROOT/docs/templates/namespace-readmes/task-checklists.template.md" \
  "$TARGET/docs/agents/task-checklists/README.md"
copy_file "$ROOT/docs/templates/namespace-readmes/plans-agents.template.md" \
  "$TARGET/docs/plans/agents/README.md"

# Bootstrap readiness
copy_file "$ROOT/docs/templates/BOOTSTRAP_READINESS.template.md" \
  "$TARGET/docs/agents/BOOTSTRAP_READINESS.md"

# System artifacts
copy_file "$ROOT/docs/templates/system/SYSTEM_GOAL_PACK.template.md" \
  "$TARGET/docs/agents/system/SYSTEM_GOAL_PACK.md"
copy_file "$ROOT/docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md" \
  "$TARGET/docs/agents/system/SYSTEM_AUTHORITY_MAP.md"
copy_file "$ROOT/docs/templates/system/SYSTEM_INVARIANTS.template.md" \
  "$TARGET/docs/agents/system/SYSTEM_INVARIANTS.md"
copy_file "$ROOT/docs/templates/system/SYSTEM_BOOTSTRAP_PACK.template.md" \
  "$TARGET/docs/agents/system/SYSTEM_BOOTSTRAP_PACK.md"
copy_file "$ROOT/docs/templates/system/SYSTEM_SCENARIO_MAP_INDEX.template.md" \
  "$TARGET/docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md"
copy_file "$ROOT/docs/templates/system/SYSTEM_CONFLICT_REGISTER.template.md" \
  "$TARGET/docs/agents/system/SYSTEM_CONFLICT_REGISTER.md"

# Seed module
if [[ -n "$SEED_MODULE" ]]; then
  mkdir -p "$TARGET/docs/agents/modules/$SEED_MODULE"
  copy_file "$ROOT/docs/templates/modules/MODULE_CONTRACT.template.md" \
    "$TARGET/docs/agents/modules/$SEED_MODULE/MODULE_CONTRACT.md"
fi

# Debug artifacts
copy_file "$ROOT/docs/templates/debug/DEBUG_BOOTSTRAP_PACK.template.md" \
  "$TARGET/docs/agents/debug/DEBUG_BOOTSTRAP_PACK.md"
copy_file "$ROOT/docs/templates/debug/DEBUG_CASE_TEMPLATE.template.md" \
  "$TARGET/docs/agents/debug/DEBUG_CASE_TEMPLATE.md"
copy_file "$ROOT/docs/templates/debug/BUG_CLASS_REGISTER.template.md" \
  "$TARGET/docs/agents/debug/BUG_CLASS_REGISTER.md"
copy_file "$ROOT/docs/templates/debug/RECURRENCE_PREVENTION_RULES.template.md" \
  "$TARGET/docs/agents/debug/RECURRENCE_PREVENTION_RULES.md"

# Verification artifacts
copy_file "$ROOT/docs/templates/verification/ACCEPTANCE_RULES.template.md" \
  "$TARGET/docs/agents/verification/ACCEPTANCE_RULES.md"

# Optional: copy commands
if [[ "$COPY_COMMANDS" -eq 1 ]]; then
  copy_dir "$ROOT/.claude/commands" "$TARGET/.claude/commands"
fi

# Optional: copy skills
if [[ "$COPY_SKILLS" -eq 1 ]]; then
  copy_dir "$ROOT/.claude/skills" "$TARGET/.claude/skills"
fi

cat <<EOF

Bootstrap complete.

Target: $TARGET
Seed module: ${SEED_MODULE:-"(none)"}
Platform: $PLATFORM
Copy commands: $COPY_COMMANDS
Copy skills: $COPY_SKILLS
Overwrite mode: $FORCE

Next:
1. Fill in docs/agents/system/*.md with project-specific truth
2. Review docs/agents/debug/*.md before first bug task
3. Install skills for your platform if not already installed
4. Optionally seed a first module contract with --seed-module if you want to start module-level governance immediately
EOF
