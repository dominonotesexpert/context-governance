#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage:"
  echo "  scripts/check-derived-edits.sh [--strict]"
  echo ""
  echo "Options:"
  echo "  --strict    Exit 1 on any unauthorized direct edit to a derived document"
  echo "  -h, --help  Show this help text"
  echo ""
  echo "Exit code:"
  echo "  0  No issues (or warnings without --strict)"
  echo "  1  Direct edits detected in --strict mode"
}

STRICT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=1
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

# Must be in a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: must be run from within a git repository" >&2
  exit 1
fi

# Get staged .md files
STAGED_FILES=$(git diff --cached --name-only | grep '\.md$' || true)

if [[ -z "$STAGED_FILES" ]]; then
  exit 0
fi

DIRECT_EDIT_COUNT=0

echo "Derived Document Edit Check"

while IFS= read -r file; do
  # Check if the staged version is a derived document (has derivation_type: in frontmatter)
  staged_content="$(git show ":$file" 2>/dev/null || true)"
  if [[ -z "$staged_content" ]]; then
    continue
  fi

  if ! echo "$staged_content" | head -20 | grep -q "derivation_type:" 2>/dev/null; then
    continue
  fi

  # Extract derivation_timestamp and upstream_hash from staged version
  staged_timestamp=""
  staged_hash=""
  staged_timestamp=$(echo "$staged_content" | grep -m1 "derivation_timestamp:" | sed 's/.*derivation_timestamp:[[:space:]]*//' | tr -d '"' || true)
  staged_hash=$(echo "$staged_content" | grep -m1 "upstream_hash:" | sed 's/.*upstream_hash:[[:space:]]*//' | tr -d '"' || true)

  # Try to extract from committed version (HEAD)
  committed_content="$(git show "HEAD:$file" 2>/dev/null || true)"
  if [[ -z "$committed_content" ]]; then
    # File is new (not in HEAD) — always allow
    echo "  ALLOW  $file (new file)"
    continue
  fi

  committed_timestamp=""
  committed_hash=""
  committed_timestamp=$(echo "$committed_content" | grep -m1 "derivation_timestamp:" | sed 's/.*derivation_timestamp:[[:space:]]*//' | tr -d '"' || true)
  committed_hash=$(echo "$committed_content" | grep -m1 "upstream_hash:" | sed 's/.*upstream_hash:[[:space:]]*//' | tr -d '"' || true)

  # Compare derivation_context fields
  context_changed=0
  if [[ "$staged_timestamp" != "$committed_timestamp" ]] || [[ "$staged_hash" != "$committed_hash" ]]; then
    context_changed=1
  fi

  if [[ "$context_changed" -eq 1 ]]; then
    echo "  ALLOW  $file (derivation_context updated — re-derivation)"
  else
    # Check if content actually differs
    if [[ "$staged_content" != "$committed_content" ]]; then
      echo "  WARN   $file (content changed but derivation_context unchanged — possible direct edit)"
      DIRECT_EDIT_COUNT=$((DIRECT_EDIT_COUNT + 1))
    fi
  fi
done <<< "$STAGED_FILES"

if [[ "$DIRECT_EDIT_COUNT" -gt 0 ]]; then
  echo ""
  echo "$DIRECT_EDIT_COUNT possible direct edit(s) detected."
  if [[ "$STRICT" -eq 1 ]]; then
    exit 1
  fi
fi

exit 0
