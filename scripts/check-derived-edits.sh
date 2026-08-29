#!/usr/bin/env bash
# Preferred path: delegate to policy_engine.cli if available.
# Fallback: embedded grep/sed logic (used when the Python engine is
# not colocated, e.g., in downstream projects bootstrapped before M2).
# Authority: docs/plans/2026-04-23-policy-engine-design.md §2.3

set -euo pipefail

usage() {
  echo "Usage: scripts/check-derived-edits.sh [--strict]"
  echo "  --strict    Exit 1 on any unauthorized direct edit to a derived document"
  echo "  -h, --help  Show this help text"
}

STRICT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$SCRIPT_DIR/../governance-mcp-server"
ENGINE_AVAILABLE=0
if [[ -d "$MCP_DIR/policy_engine" ]] && command -v python3 >/dev/null 2>&1; then
  ENGINE_AVAILABLE=1
fi

if [[ "$ENGINE_AVAILABLE" -eq 1 ]]; then
  d="$(pwd)"
  TARGET="."
  while [[ "$d" != "/" ]]; do
    if [[ -d "$d/.governance" ]]; then TARGET="$d"; break; fi
    d="$(dirname "$d")"
  done
  set +e
  PYTHONPATH="$MCP_DIR" python3 -m policy_engine.cli check derived-edits --target "$TARGET"
  RC=$?
  set -e
  if [[ "$STRICT" -eq 1 ]]; then
    exit "$RC"
  fi
  exit 0
fi

# ==============================================================
# Fallback: legacy grep/sed path. Keeps downstream projects working
# until M5 ships policy_engine via bootstrap.
# ==============================================================

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: must be run from within a git repository" >&2
  exit 1
fi

STAGED_FILES=$(git diff --cached --name-only | grep '\.md$' || true)
if [[ -z "$STAGED_FILES" ]]; then exit 0; fi

DIRECT_EDIT_COUNT=0
echo "Derived Document Edit Check"
while IFS= read -r file; do
  staged_content="$(git show ":$file" 2>/dev/null || true)"
  [[ -z "$staged_content" ]] && continue
  if ! echo "$staged_content" | head -20 | grep -q "derivation_type:" 2>/dev/null; then
    continue
  fi
  staged_timestamp=$(echo "$staged_content" | grep -m1 "derivation_timestamp:" | sed 's/.*derivation_timestamp:[[:space:]]*//' | tr -d '"' || true)
  staged_hash=$(echo "$staged_content" | grep -m1 "upstream_hash:" | sed 's/.*upstream_hash:[[:space:]]*//' | tr -d '"' || true)
  committed_content="$(git show "HEAD:$file" 2>/dev/null || true)"
  if [[ -z "$committed_content" ]]; then
    echo "  ALLOW  $file (new file)"
    continue
  fi
  committed_timestamp=$(echo "$committed_content" | grep -m1 "derivation_timestamp:" | sed 's/.*derivation_timestamp:[[:space:]]*//' | tr -d '"' || true)
  committed_hash=$(echo "$committed_content" | grep -m1 "upstream_hash:" | sed 's/.*upstream_hash:[[:space:]]*//' | tr -d '"' || true)
  context_changed=0
  if [[ "$staged_timestamp" != "$committed_timestamp" ]] || [[ "$staged_hash" != "$committed_hash" ]]; then
    context_changed=1
  fi
  if [[ "$context_changed" -eq 1 ]]; then
    echo "  ALLOW  $file (derivation_context updated — re-derivation)"
  else
    if [[ "$staged_content" != "$committed_content" ]]; then
      echo "  WARN   $file (content changed but derivation_context unchanged — possible direct edit)"
      DIRECT_EDIT_COUNT=$((DIRECT_EDIT_COUNT + 1))
    fi
  fi
done <<< "$STAGED_FILES"

if [[ "$DIRECT_EDIT_COUNT" -gt 0 ]]; then
  echo ""
  echo "$DIRECT_EDIT_COUNT possible direct edit(s) detected."
  if [[ "$STRICT" -eq 1 ]]; then exit 1; fi
fi
exit 0
