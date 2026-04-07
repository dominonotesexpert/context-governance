#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage:"
  echo "  scripts/check-hardgate.sh --role <role> --target <path> [options]"
  echo ""
  echo "Options:"
  echo "  --role <role>         Agent role to check (system-architect, module-architect, debug,"
  echo "                        implementation, verification, frontend-specialist)"
  echo "  --target <path>       Target project root to check"
  echo "  --module <name>       Module name (required for module-architect, optional for others)"
  echo "  -h, --help            Show this help text"
  echo ""
  echo "Validates that all required governance documents exist for the given agent role."
  echo "Exit codes: 0 = PASSED, 1 = FAILED (missing files), 2 = invalid arguments"
}

ROLE=""
TARGET=""
MODULE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role)
      ROLE="${2:-}"
      shift 2
      ;;
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --module)
      MODULE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ROLE" ]]; then
  echo "Error: --role is required" >&2
  usage >&2
  exit 2
fi

if [[ -z "$TARGET" ]]; then
  echo "Error: --target is required" >&2
  usage >&2
  exit 2
fi

# Validate role
case "$ROLE" in
  system-architect|module-architect|debug|implementation|verification|frontend-specialist)
    ;;
  *)
    echo "Error: unknown role '$ROLE'" >&2
    echo "Supported roles: system-architect, module-architect, debug, implementation, verification, frontend-specialist" >&2
    exit 2
    ;;
esac

# module-architect requires --module
if [[ "$ROLE" == "module-architect" && -z "$MODULE" ]]; then
  echo "Error: --module is required for role 'module-architect'" >&2
  exit 2
fi

AGENTS_DIR="$TARGET/docs/agents"

# --- Determine Bootstrap Pack path and read required_files ---
PACK_PATH=""
PACK_LABEL=""
REQUIRED_FILES=()
SOURCE_TYPE=""

case "$ROLE" in
  system-architect)
    PACK_PATH="$AGENTS_DIR/system/SYSTEM_BOOTSTRAP_PACK.md"
    PACK_LABEL="SYSTEM_BOOTSTRAP_PACK"
    ;;
  module-architect)
    PACK_PATH="$AGENTS_DIR/modules/$MODULE/MODULE_BOOTSTRAP_PACK.md"
    PACK_LABEL="MODULE_BOOTSTRAP_PACK"
    ;;
  debug)
    PACK_PATH="$AGENTS_DIR/debug/DEBUG_BOOTSTRAP_PACK.md"
    PACK_LABEL="DEBUG_BOOTSTRAP_PACK"
    ;;
  verification)
    if [[ -n "$MODULE" ]]; then
      PACK_PATH="$AGENTS_DIR/verification/$MODULE/VERIFICATION_BOOTSTRAP_PACK.md"
    else
      PACK_PATH="$AGENTS_DIR/verification/VERIFICATION_BOOTSTRAP_PACK.md"
    fi
    PACK_LABEL="VERIFICATION_BOOTSTRAP_PACK"
    ;;
  implementation)
    PACK_PATH=""
    PACK_LABEL=""
    ;;
  frontend-specialist)
    PACK_PATH=""
    PACK_LABEL=""
    ;;
esac

# Try to read required_files from Bootstrap Pack frontmatter
parse_required_files() {
  local pack="$1"
  local in_frontmatter=0
  local in_required=0
  local files=()

  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if [[ "$in_frontmatter" -eq 0 ]]; then
        in_frontmatter=1
        continue
      else
        break
      fi
    fi
    if [[ "$in_frontmatter" -eq 1 ]]; then
      if [[ "$line" =~ ^required_files: ]]; then
        in_required=1
        continue
      fi
      if [[ "$in_required" -eq 1 ]]; then
        if [[ "$line" =~ ^[[:space:]]+- ]]; then
          local val
          val=$(echo "$line" | sed 's/^[[:space:]]*- *//' | tr -d '"' | tr -d "'")
          files+=("$val")
        else
          break
        fi
      fi
    fi
  done < "$pack"

  if [[ ${#files[@]} -gt 0 ]]; then
    printf '%s\n' "${files[@]}"
    return 0
  fi
  return 1
}

if [[ -n "$PACK_PATH" && -f "$PACK_PATH" ]]; then
  if PARSED=$(parse_required_files "$PACK_PATH"); then
    while IFS= read -r f; do
      REQUIRED_FILES+=("$f")
    done <<< "$PARSED"
    SOURCE_TYPE="$PACK_LABEL"
  fi
fi

# Fallback to hardcoded defaults if no pack or no required_files found
if [[ ${#REQUIRED_FILES[@]} -eq 0 ]]; then
  case "$ROLE" in
    system-architect)
      REQUIRED_FILES=(
        "PROJECT_BASELINE.md"
        "system/BASELINE_INTERPRETATION_LOG.md"
        "PROJECT_ARCHITECTURE_BASELINE.md"
        "system/SYSTEM_GOAL_PACK.md"
        "system/SYSTEM_AUTHORITY_MAP.md"
        "system/SYSTEM_CONFLICT_REGISTER.md"
        "system/SYSTEM_INVARIANTS.md"
        "execution/GOVERNANCE_MODE.md"
      )
      ;;
    module-architect)
      REQUIRED_FILES=(
        "system/SYSTEM_INVARIANTS.md"
      )
      ;;
    debug)
      REQUIRED_FILES=(
        "system/SYSTEM_GOAL_PACK.md"
        "system/SYSTEM_SCENARIO_MAP_INDEX.md"
        "debug/DEBUG_CASE_TEMPLATE.md"
      )
      ;;
    verification)
      REQUIRED_FILES=(
        "system/SYSTEM_INVARIANTS.md"
        "verification/ACCEPTANCE_RULES.md"
      )
      ;;
    implementation)
      REQUIRED_FILES=(
        "system/SYSTEM_GOAL_PACK.md"
      )
      ;;
    frontend-specialist)
      REQUIRED_FILES=(
        "system/SYSTEM_GOAL_PACK.md"
      )
      ;;
  esac

  if [[ -n "$PACK_PATH" && ! -f "$PACK_PATH" ]]; then
    SOURCE_TYPE="hardcoded defaults (pack not found)"
  elif [[ -n "$PACK_PATH" ]]; then
    SOURCE_TYPE="hardcoded defaults (no required_files in pack)"
  else
    SOURCE_TYPE="hardcoded defaults"
  fi
fi

# When --module is provided, additionally check MODULE_CONTRACT
if [[ -n "$MODULE" ]]; then
  REQUIRED_FILES+=("modules/$MODULE/MODULE_CONTRACT.md")
fi

# --- Run checks ---
MODULE_SUFFIX=""
if [[ -n "$MODULE" ]]; then
  MODULE_SUFFIX=" module=$MODULE"
fi
echo "HARDGATE Check: role=$ROLE target=$TARGET${MODULE_SUFFIX} (source: $SOURCE_TYPE)"

MISSING=0
for f in "${REQUIRED_FILES[@]}"; do
  FULL_PATH="$AGENTS_DIR/$f"
  if [[ -f "$FULL_PATH" ]]; then
    echo "  OK       docs/agents/$f"
  else
    echo "  MISSING  docs/agents/$f"
    MISSING=$((MISSING + 1))
  fi
done

echo ""
if [[ "$MISSING" -eq 0 ]]; then
  echo "0 MISSING file(s). HARD-GATE PASSED."
  exit 0
else
  echo "$MISSING MISSING file(s). HARD-GATE FAILED."
  exit 1
fi
