#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage:"
  echo "  scripts/check-staleness.sh --target <project-path>"
  echo ""
  echo "Options:"
  echo "  --target <path>  Target project root to check for staleness"
  echo "  -h, --help       Show this help text"
  echo ""
  echo "Exit code:"
  echo "  0  No STALE documents found"
  echo "  1  One or more STALE documents found"
}

TARGET=""

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
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  usage >&2
  exit 1
fi

AGENTS_DIR="$TARGET/docs/agents"
if [[ ! -d "$AGENTS_DIR" ]]; then
  echo "Staleness Report: $TARGET"
  echo "  No docs/agents/ directory found."
  exit 0
fi

# Hardcoded fallback mapping (only used when upstream_sources field is missing)
get_fallback_sources() {
  local basename="$1"
  case "$basename" in
    SYSTEM_GOAL_PACK.md)
      echo "PROJECT_BASELINE.md system/BASELINE_INTERPRETATION_LOG.md"
      ;;
    SYSTEM_INVARIANTS.md)
      echo "PROJECT_BASELINE.md system/BASELINE_INTERPRETATION_LOG.md"
      ;;
    SYSTEM_ARCHITECTURE.md)
      echo "PROJECT_BASELINE.md system/BASELINE_INTERPRETATION_LOG.md PROJECT_ARCHITECTURE_BASELINE.md system/SYSTEM_GOAL_PACK.md system/ENGINEERING_CONSTRAINTS.md"
      ;;
    MODULE_CONTRACT.md)
      echo "system/SYSTEM_GOAL_PACK.md system/SYSTEM_ARCHITECTURE.md system/SYSTEM_INVARIANTS.md system/ENGINEERING_CONSTRAINTS.md"
      ;;
    ACCEPTANCE_RULES.md)
      echo "system/SYSTEM_GOAL_PACK.md system/SYSTEM_INVARIANTS.md"
      ;;
    VERIFICATION_ORACLE.md)
      echo "verification/ACCEPTANCE_RULES.md"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Check if target is a git repo
IS_GIT=0
if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  IS_GIT=1
fi

STALE_COUNT=0

echo "Staleness Report: $TARGET"

while IFS= read -r -d '' file; do
  # Only process files that contain derivation_context:
  if ! grep -q "derivation_context:" "$file" 2>/dev/null; then
    continue
  fi

  # Compute relative path from agents dir
  rel_path="${file#"$AGENTS_DIR"/}"

  # Extract upstream_hash from frontmatter
  stored_hash=""
  stored_hash=$(grep -m1 "upstream_hash:" "$file" 2>/dev/null | sed 's/.*upstream_hash:[[:space:]]*//' | tr -d '"' || true)

  if [[ -z "$stored_hash" ]]; then
    echo "  NO_HASH  $rel_path (upstream_hash not set)"
    continue
  fi

  # Extract upstream_sources from frontmatter (YAML list)
  sources=()
  in_sources=0
  while IFS= read -r line; do
    # Stop at end of frontmatter
    if [[ "$in_sources" -eq 0 ]] && [[ "$line" =~ ^upstream_sources: ]]; then
      in_sources=1
      continue
    fi
    if [[ "$in_sources" -eq 1 ]]; then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(\"[^\"]*\"|\'[^\']*\'|[^[:space:]]+) ]]; then
        val="${BASH_REMATCH[1]}"
        val="${val#\"}"
        val="${val%\"}"
        val="${val#\'}"
        val="${val%\'}"
        sources+=("$val")
      else
        break
      fi
    fi
    # Stop at end of frontmatter
    if [[ "$line" == "---" ]] && [[ "${#sources[@]}" -gt 0 || "$in_sources" -eq 1 ]]; then
      break
    fi
  done < "$file"

  # If upstream_sources not found, try hardcoded fallback
  if [[ ${#sources[@]} -eq 0 ]]; then
    file_basename="$(basename "$file")"
    fallback="$(get_fallback_sources "$file_basename")"
    if [[ -n "$fallback" ]]; then
      echo "  WARN     $rel_path (upstream_sources field missing — using hardcoded fallback)" >&2
      read -ra sources <<< "$fallback"
    else
      echo "  NO_HASH  $rel_path (upstream_hash not set)"
      continue
    fi
  fi

  if [[ "$IS_GIT" -eq 0 ]]; then
    echo "  NO_GIT   $rel_path (not a git repository — skipping hash comparison)"
    continue
  fi

  # Compute current combined hash from upstream source files
  hash_inputs=""
  missing_source=0
  for src in "${sources[@]}"; do
    src_path="$AGENTS_DIR/$src"
    if [[ ! -f "$src_path" ]]; then
      continue
    fi
    src_hash="$(git -C "$TARGET" hash-object "$src_path" 2>/dev/null || true)"
    if [[ -n "$src_hash" ]]; then
      hash_inputs="$hash_inputs$src_hash"$'\n'
    fi
  done

  if [[ -z "$hash_inputs" ]]; then
    echo "  NO_HASH  $rel_path (upstream_hash not set)"
    continue
  fi

  # Sort hashes, concatenate, sha256, take first 12 chars
  current_hash=$(echo "$hash_inputs" | sort | tr -d '\n' | shasum -a 256 | cut -c1-12)

  if [[ "$stored_hash" == "$current_hash" ]]; then
    echo "  FRESH    $rel_path (upstream_hash matches)"
  else
    echo "  STALE    $rel_path (stored: $stored_hash, current: $current_hash)"
    STALE_COUNT=$((STALE_COUNT + 1))
  fi
done < <(find "$AGENTS_DIR" -name "*.md" -print0)

echo ""
if [[ "$STALE_COUNT" -gt 0 ]]; then
  echo "$STALE_COUNT STALE document(s)."
  exit 1
else
  echo "0 STALE document(s)."
  exit 0
fi
