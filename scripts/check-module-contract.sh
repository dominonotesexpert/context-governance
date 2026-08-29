#!/usr/bin/env bash
# Preferred path: delegate to policy_engine.cli if available.
# Fallback: embedded directory-walk logic for downstream projects that
# don't yet have the Python engine colocated.
# Authority: docs/plans/2026-04-23-policy-engine-design.md §2.3

set -euo pipefail

usage() {
  echo "Usage: scripts/check-module-contract.sh [--target <path>]"
  echo "  --target <path>  Project root (default: auto-detect)"
  echo "  -h, --help       Show this help text"
  echo "Exit codes: 0 = PASSED, 1 = FAILED (missing contracts), 2 = invalid args"
}

TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$SCRIPT_DIR/../governance-mcp-server"

if [[ -z "$TARGET" ]]; then
  d="$(pwd)"
  while [[ "$d" != "/" ]]; do
    if [[ -d "$d/.governance" ]]; then TARGET="$d"; break; fi
    d="$(dirname "$d")"
  done
  [[ -z "$TARGET" ]] && TARGET="."
fi

if [[ -d "$MCP_DIR/policy_engine" ]] && command -v python3 >/dev/null 2>&1; then
  PYTHONPATH="$MCP_DIR" exec python3 -m policy_engine.cli check module-contract --target "$TARGET"
fi

# ==============================================================
# Fallback: legacy directory-walk logic
# ==============================================================

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: must be run from within a git repository" >&2
  exit 2
fi

AGENTS_DIR="$TARGET/docs/agents"
MODULES_DIR="$AGENTS_DIR/modules"
STAGED_FILES=$(git diff --cached --name-only || true)
if [[ -z "$STAGED_FILES" ]]; then
  echo "Module Contract Check"
  echo ""
  echo "No staged files. PASSED."
  exit 0
fi

MISSING=0
echo "Module Contract Check"
while IFS= read -r file; do
  case "$file" in
    docs/*|tests/*|*.md|.governance/*|.githooks/*|.claude/*|.codex/*|scripts/*|adapters/*|core/*)
      continue ;;
  esac
  dir="$(dirname "$file")"
  found_module=""
  while [[ "$dir" != "." && "$dir" != "/" ]]; do
    dirname_part="$(basename "$dir")"
    if [[ -d "$MODULES_DIR/$dirname_part" ]]; then
      found_module="$dirname_part"
      break
    fi
    dir="$(dirname "$dir")"
  done
  [[ -z "$found_module" ]] && continue
  CONTRACT="$MODULES_DIR/$found_module/MODULE_CONTRACT.md"
  if [[ -f "$CONTRACT" ]]; then
    echo "  OK       $file (module: $found_module)"
  else
    echo "  MISSING  $file (module: $found_module — MODULE_CONTRACT.md not found)"
    MISSING=$((MISSING + 1))
  fi
done <<< "$STAGED_FILES"

echo ""
if [[ "$MISSING" -eq 0 ]]; then
  echo "0 MISSING contract(s). PASSED."
  exit 0
else
  echo "$MISSING MISSING contract(s). FAILED."
  exit 1
fi
