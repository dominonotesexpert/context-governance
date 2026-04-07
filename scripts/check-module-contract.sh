#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage:"
  echo "  scripts/check-module-contract.sh [--target <path>]"
  echo ""
  echo "Options:"
  echo "  --target <path>  Project root (defaults to '.')"
  echo "  -h, --help       Show this help text"
  echo ""
  echo "Checks that every staged code file in a governed module has a MODULE_CONTRACT.md."
  echo "Exit codes: 0 = PASSED, 1 = FAILED (missing contracts), 2 = invalid arguments"
}

TARGET="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
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
  # Skip non-code paths
  case "$file" in
    docs/*|tests/*|*.md|.governance/*|.githooks/*|.claude/*|.codex/*|scripts/*|adapters/*|core/*)
      continue
      ;;
  esac

  # Walk up directory tree to find a governed module
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

  if [[ -z "$found_module" ]]; then
    continue
  fi

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
