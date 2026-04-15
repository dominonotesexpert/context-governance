#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/bootstrap-project.sh --target <project-path> [options]

Options:
  --target <path>       Target project root to bootstrap
  --seed-module <name>  Optionally seed one module contract (name must match [a-z0-9][a-z0-9_-]*)
  --module <name>       Deprecated alias for --seed-module
  --platform <name>     Copy the project-level platform entrypoint (`claude`, `codex`, `gemini`, or `hermes`)
  --adapter <name>      Generate adapter-specific enforcement config (`claude-code` or `codex`; default: matches --platform)
  --copy-commands       Also copy .claude/commands shortcuts into the target project
  --copy-skills         Also copy .claude/skills into the target project
  --dry-run             Show what would be created without writing anything
  --validate            Check an already-bootstrapped project for completeness
  --force               Overwrite existing files instead of skipping them
  -h, --help            Show this help text
EOF
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""
SEED_MODULE=""
PLATFORM="claude"
ADAPTER=""
COPY_COMMANDS=0
COPY_SKILLS=0
FORCE=0
DRY_RUN=0
VALIDATE=0

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
    --adapter)
      ADAPTER="${2:-}"
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
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --validate)
      VALIDATE=1
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

# Input safety: reject dangerous targets
case "$TARGET" in
  /|"$HOME"|"$HOME/"|/tmp|/tmp/)
    echo "Error: refusing to bootstrap into '$TARGET' — too broad" >&2
    exit 1
    ;;
esac

if [[ -z "$TARGET" || "$TARGET" == "/" ]]; then
  echo "Error: --target must be a non-empty, non-root path" >&2
  exit 1
fi

# Input safety: validate seed-module name
if [[ -n "$SEED_MODULE" ]]; then
  if ! [[ "$SEED_MODULE" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
    echo "Error: --seed-module name must match [a-z0-9][a-z0-9_-]* (got: '$SEED_MODULE')" >&2
    exit 1
  fi
fi

# Default adapter from platform if not specified
if [[ -z "$ADAPTER" ]]; then
  case "$PLATFORM" in
    claude) ADAPTER="claude-code" ;;
    codex)  ADAPTER="codex" ;;
    hermes) ADAPTER="hermes" ;;
    *)      ADAPTER="claude-code" ;;
  esac
fi

case "$ADAPTER" in
  claude-code|codex|hermes) ;;
  *)
    echo "Unsupported adapter: $ADAPTER (must be claude-code, codex, or hermes)" >&2
    exit 1
    ;;
esac

case "$PLATFORM" in
  claude|codex|gemini|hermes)
    ;;
  *)
    echo "Unsupported platform: $PLATFORM" >&2
    usage >&2
    exit 1
    ;;
esac

# --- Validate mode ---
if [[ "$VALIDATE" -eq 1 ]]; then
  echo "Readiness Report: $TARGET"
  echo "================================"
  ISSUES=0

  check_file() {
    local path="$1"
    local label="$2"
    if [[ ! -f "$path" ]]; then
      echo "  MISSING  $label"
      ISSUES=$((ISSUES + 1))
    elif head -5 "$path" | grep -q "^artifact_type:" 2>/dev/null; then
      # Check if key frontmatter fields are still placeholder
      if head -10 "$path" | grep -q "YYYY-MM-DD"; then
        echo "  UNFILLED $label (frontmatter has YYYY-MM-DD placeholder)"
        ISSUES=$((ISSUES + 1))
      else
        echo "  OK       $label"
      fi
    else
      echo "  OK       $label (no frontmatter expected)"
    fi
  }

  echo ""
  echo "Project Baseline (Tier 0):"
  # PROJECT_BASELINE uses a special check: we look at business content, not frontmatter dates.
  # The user fills business sections; they should NOT be required to edit metadata manually.
  BASELINE_PATH="$TARGET/docs/agents/PROJECT_BASELINE.md"
  if [[ ! -f "$BASELINE_PATH" ]]; then
    echo "  MISSING  PROJECT_BASELINE"
    ISSUES=$((ISSUES + 1))
  elif grep -q "<!-- " "$BASELINE_PATH" && ! grep -q "^[^<#-]" <(sed -n '/^## 1\./,/^---$/p' "$BASELINE_PATH" 2>/dev/null); then
    # All business sections still contain only HTML comments (template placeholders)
    echo "  UNFILLED PROJECT_BASELINE (business sections still contain only placeholders)"
    ISSUES=$((ISSUES + 1))
  else
    echo "  OK       PROJECT_BASELINE"
  fi

  echo ""
  echo "Derivation Consistency:"

  # Check if BASELINE business content has been filled (same logic as the Tier 0 check above).
  # We look at business sections, NOT frontmatter dates — users should not need to edit metadata.
  BASELINE_FILE="$TARGET/docs/agents/PROJECT_BASELINE.md"
  BASELINE_FILLED=0
  if [[ -f "$BASELINE_FILE" ]]; then
    # If any non-comment, non-heading, non-empty line exists in business sections, it's filled
    if grep -q "^[^<#-]" <(sed -n '/^## 1\./,$p' "$BASELINE_FILE" 2>/dev/null); then
      BASELINE_FILLED=1
    fi
  fi
  if [[ "$BASELINE_FILLED" -eq 0 ]]; then
    echo "  UNFILLED PROJECT_BASELINE business content not yet filled — derivation checks skipped"
  fi

  # Check all derived documents for metadata AND version consistency
  check_derived() {
    local path="$1"
    local label="$2"
    if [[ ! -f "$path" ]]; then
      return  # File absence is caught by check_file elsewhere
    fi
    if ! head -15 "$path" | grep -q "derived_from_baseline_version"; then
      echo "  STALE    $label (missing derived_from_baseline_version — needs re-derivation from BASELINE)"
      ISSUES=$((ISSUES + 1))
      return
    fi
    # Check if version is still the template placeholder
    local doc_version
    doc_version=$(grep -m1 "derived_from_baseline_version:" "$path" 2>/dev/null | sed 's/.*: *//' | tr -d '"' || true)
    if [[ "$doc_version" == "v0.0" ]]; then
      echo "  PENDING  $label (derived_from_baseline_version is v0.0 — System Architect has not yet derived from BASELINE)"
      ISSUES=$((ISSUES + 1))
    else
      echo "  OK       $label (derived version: $doc_version)"
    fi
  }

  # Only run derivation checks if BASELINE has been filled
  if [[ "$BASELINE_FILLED" -eq 1 ]]; then
    # System-level derived documents
    check_derived "$TARGET/docs/agents/system/SYSTEM_GOAL_PACK.md" "SYSTEM_GOAL_PACK"
    check_derived "$TARGET/docs/agents/system/SYSTEM_INVARIANTS.md" "SYSTEM_INVARIANTS"

    # Verification derived documents
    check_derived "$TARGET/docs/agents/verification/ACCEPTANCE_RULES.md" "ACCEPTANCE_RULES"
    if [[ -d "$TARGET/docs/agents/modules" ]]; then
      for mod_dir in "$TARGET/docs/agents/modules"/*/; do
        if [[ -d "$mod_dir" ]]; then
          mod_name="$(basename "$mod_dir")"
          check_derived "$mod_dir/MODULE_CONTRACT.md" "modules/$mod_name/MODULE_CONTRACT"
          # Check VERIFICATION_ORACLE if it exists
          if [[ -f "$mod_dir/VERIFICATION_ORACLE.md" ]]; then
            check_derived "$mod_dir/VERIFICATION_ORACLE.md" "modules/$mod_name/VERIFICATION_ORACLE"
          fi
        fi
      done
    fi
  fi

  echo ""
  echo "Business Semantics (Tier 0.5):"
  # BASELINE_INTERPRETATION_LOG uses a special check: an empty log (no entries) is valid —
  # it means no business ambiguities have been discovered yet, which is not a defect.
  # Only report an issue when entries exist that haven't been confirmed.
  BIL_PATH="$TARGET/docs/agents/system/BASELINE_INTERPRETATION_LOG.md"
  if [[ ! -f "$BIL_PATH" ]]; then
    echo "  MISSING  BASELINE_INTERPRETATION_LOG"
    ISSUES=$((ISSUES + 1))
  elif sed -n '/^## 4\. Entries/,$p' "$BIL_PATH" 2>/dev/null | grep -qE '^### INT-'; then
    # Has real interpretation entries (under §4, not the template example in §2) — check if any are unconfirmed
    if sed -n '/^## 4\. Entries/,$p' "$BIL_PATH" 2>/dev/null | grep -A5 '^### INT-' | grep -qiE 'Status:.*\b(pending|proposed|draft)\b'; then
      echo "  PENDING  BASELINE_INTERPRETATION_LOG (has unconfirmed interpretation entries)"
      ISSUES=$((ISSUES + 1))
    else
      echo "  OK       BASELINE_INTERPRETATION_LOG (all entries confirmed)"
    fi
  else
    echo "  OK       BASELINE_INTERPRETATION_LOG (no ambiguities recorded — not blocking)"
  fi

  echo ""
  echo "System Truth:"
  check_file "$TARGET/docs/agents/system/SYSTEM_GOAL_PACK.md" "SYSTEM_GOAL_PACK"
  check_file "$TARGET/docs/agents/system/SYSTEM_AUTHORITY_MAP.md" "SYSTEM_AUTHORITY_MAP"
  check_file "$TARGET/docs/agents/system/SYSTEM_INVARIANTS.md" "SYSTEM_INVARIANTS"
  check_file "$TARGET/docs/agents/system/ROUTING_POLICY.md" "ROUTING_POLICY"
  check_file "$TARGET/docs/agents/system/MODULE_TAXONOMY.md" "MODULE_TAXONOMY"
  check_file "$TARGET/docs/agents/system/SYSTEM_CONFLICT_REGISTER.md" "SYSTEM_CONFLICT_REGISTER"

  echo ""
  echo "Debug Governance:"
  check_file "$TARGET/docs/agents/debug/DEBUG_BOOTSTRAP_PACK.md" "DEBUG_BOOTSTRAP_PACK"
  check_file "$TARGET/docs/agents/debug/DEBUG_CASE_TEMPLATE.md" "DEBUG_CASE_TEMPLATE"

  echo ""
  echo "Verification:"
  check_file "$TARGET/docs/agents/verification/ACCEPTANCE_RULES.md" "ACCEPTANCE_RULES"

  echo ""
  echo "Feedback & Evolution:"
  check_file "$TARGET/docs/agents/verification/FEEDBACK_LOG.md" "FEEDBACK_LOG"
  check_file "$TARGET/docs/agents/verification/CRITERIA_EVOLUTION.md" "CRITERIA_EVOLUTION"
  check_file "$TARGET/docs/agents/verification/FEEDBACK_ANALYSIS_PROTOCOL.md" "FEEDBACK_ANALYSIS_PROTOCOL"

  echo ""
  echo "Authority:"
  check_file "$TARGET/docs/agents/system/AUTHORITY_CONFLICT_DETECTOR.md" "AUTHORITY_CONFLICT_DETECTOR"

  echo ""
  echo "Optimization:"
  check_file "$TARGET/docs/agents/optimization/OPTIMIZATION_LOG.md" "OPTIMIZATION_LOG"
  check_file "$TARGET/docs/agents/optimization/PROMPT_TUNING_PROTOCOL.md" "PROMPT_TUNING_PROTOCOL"
  check_file "$TARGET/docs/agents/optimization/ROLLBACK_GUARD.md" "ROLLBACK_GUARD"
  check_file "$TARGET/docs/agents/optimization/REGRESSION_CASES.md" "REGRESSION_CASES"
  if [[ -d "$TARGET/docs/agents/optimization/test-scenarios" ]]; then
    SCENARIO_COUNT=$(find "$TARGET/docs/agents/optimization/test-scenarios" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    echo "  OK       test-scenarios ($SCENARIO_COUNT scenario files)"
  else
    echo "  MISSING  test-scenarios directory"
    ISSUES=$((ISSUES + 1))
  fi
  if [[ -d "$TARGET/docs/agents/optimization/backups" ]]; then
    echo "  OK       backups directory"
  else
    echo "  MISSING  backups directory"
    ISSUES=$((ISSUES + 1))
  fi

  echo ""
  echo "Execution:"
  if [[ -d "$TARGET/docs/agents/execution" ]]; then
    echo "  OK       execution directory"
  else
    echo "  MISSING  execution directory"
    ISSUES=$((ISSUES + 1))
  fi
  check_file "$TARGET/docs/agents/execution/CURRENT_DIRECTION.md" "CURRENT_DIRECTION"

  echo ""
  echo "Bootstrap Readiness:"
  check_file "$TARGET/docs/agents/BOOTSTRAP_READINESS.md" "BOOTSTRAP_READINESS"

  # --- .governance/ directory check ---
  echo ""
  echo "Governance Attestation:"
  if [[ ! -d "$TARGET/.governance" ]]; then
    echo "  MISSING  .governance/ directory (run bootstrap to create)"
    ISSUES=$((ISSUES + 1))
  else
    echo "  OK       .governance/ directory"
  fi
  if [[ ! -d "$TARGET/.governance/attestations" ]]; then
    echo "  MISSING  .governance/attestations/ directory"
    ISSUES=$((ISSUES + 1))
  else
    echo "  OK       .governance/attestations/ directory"
    if [[ ! -f "$TARGET/.governance/attestations/index.jsonl" ]]; then
      echo "  MISSING  .governance/attestations/index.jsonl"
      ISSUES=$((ISSUES + 1))
    else
      echo "  OK       attestation index (index.jsonl)"
    fi
  fi

  # Architecture baseline lightness check
  echo ""
  echo "Architecture Baseline:"
  ARCH_BASELINE_PATH="$TARGET/docs/agents/PROJECT_ARCHITECTURE_BASELINE.md"
  if [[ -f "$ARCH_BASELINE_PATH" ]]; then
    # Count non-frontmatter, non-empty body lines (excluding Mermaid code blocks)
    BODY_LINES=$(awk '
      BEGIN { in_fm=0; fm_done=0; in_mermaid=0; count=0 }
      NR==1 && /^---$/ { in_fm=1; next }
      in_fm && /^---$/ { fm_done=1; next }
      !fm_done { next }
      /^```mermaid/ { in_mermaid=1; next }
      in_mermaid && /^```/ { in_mermaid=0; next }
      in_mermaid { next }
      /^[[:space:]]*$/ { next }
      { count++ }
      END { print count }
    ' "$ARCH_BASELINE_PATH")
    MERMAID_BLOCKS=$(grep -c '```mermaid' "$ARCH_BASELINE_PATH" 2>/dev/null || echo 0)
    if [[ "$BODY_LINES" -gt 50 ]]; then
      echo "  BLOCKING PROJECT_ARCHITECTURE_BASELINE body lines ($BODY_LINES) exceed limit of 50"
      ISSUES=$((ISSUES + 1))
    elif [[ "$MERMAID_BLOCKS" -gt 2 ]]; then
      echo "  BLOCKING PROJECT_ARCHITECTURE_BASELINE Mermaid blocks ($MERMAID_BLOCKS) exceed limit of 2"
      ISSUES=$((ISSUES + 1))
    else
      echo "  OK       PROJECT_ARCHITECTURE_BASELINE ($BODY_LINES body lines, $MERMAID_BLOCKS Mermaid blocks)"
    fi
  else
    echo "  SKIP     PROJECT_ARCHITECTURE_BASELINE not present (optional)"
  fi

  # Check for module contracts
  echo ""
  echo "Modules:"
  MODULE_COUNT=0
  if [[ -d "$TARGET/docs/agents/modules" ]]; then
    for mod_dir in "$TARGET/docs/agents/modules"/*/; do
      if [[ -d "$mod_dir" ]]; then
        mod_name="$(basename "$mod_dir")"
        check_file "$mod_dir/MODULE_CONTRACT.md" "modules/$mod_name/MODULE_CONTRACT"
        MODULE_COUNT=$((MODULE_COUNT + 1))
      fi
    done
  fi
  if [[ "$MODULE_COUNT" -eq 0 ]]; then
    echo "  NONE     No module contracts found (use --seed-module to create one)"
    ISSUES=$((ISSUES + 1))
  fi

  # --- Derivation Staleness ---
  echo ""
  echo "Derivation Staleness:"
  STALE_FOUND=0
  if [[ -d "$TARGET/docs/agents" ]]; then
    for derived_doc in "$TARGET/docs/agents/system/SYSTEM_GOAL_PACK.md" \
                       "$TARGET/docs/agents/system/SYSTEM_INVARIANTS.md" \
                       "$TARGET/docs/agents/system/SYSTEM_ARCHITECTURE.md" \
                       "$TARGET/docs/agents/verification/ACCEPTANCE_RULES.md"; do
      if [[ -f "$derived_doc" ]]; then
        doc_name="$(basename "$derived_doc")"
        stored=$(grep -m1 "upstream_hash:" "$derived_doc" 2>/dev/null | sed 's/.*upstream_hash:[[:space:]]*//' | tr -d '"' || true)
        if [[ -z "$stored" ]]; then
          echo "  NO_HASH  $doc_name"
        else
          echo "  HAS_HASH $doc_name (run check-staleness.sh for full comparison)"
        fi
      fi
    done
    if [[ "$STALE_FOUND" -gt 0 ]]; then
      echo "  FAIL     $STALE_FOUND stale document(s) detected"
      ISSUES=$((ISSUES + STALE_FOUND))
    fi
  else
    echo "  SKIP     docs/agents/ not found"
  fi
  echo "  INFO     Run 'scripts/check-staleness.sh --target $TARGET' for full staleness report"

  # --- Governance Mode Expiry ---
  echo ""
  echo "Governance Mode:"
  GM_PATH="$TARGET/docs/agents/execution/GOVERNANCE_MODE.md"
  if [[ -f "$GM_PATH" ]]; then
    CURRENT_MODE=$(grep -m1 "current_mode:" "$GM_PATH" 2>/dev/null | sed 's/.*: *//' | tr -d '"' || echo "unknown")
    EXPIRY_DATE=$(grep -m1 "expiry_date:" "$GM_PATH" 2>/dev/null | sed 's/.*: *//' | tr -d '"' || echo "null")
    if [[ "$CURRENT_MODE" == "steady-state" || "$CURRENT_MODE" == "unknown" ]]; then
      echo "  PASS     GOVERNANCE_MODE ($CURRENT_MODE)"
    elif [[ "$EXPIRY_DATE" == "null" || -z "$EXPIRY_DATE" || "$EXPIRY_DATE" == "~" ]]; then
      echo "  PASS     GOVERNANCE_MODE (mode: $CURRENT_MODE, no expiry set)"
    else
      TODAY=$(date +%Y-%m-%d)
      if [[ "$TODAY" > "$EXPIRY_DATE" ]]; then
        echo "  EXPIRED  GOVERNANCE_MODE (mode: $CURRENT_MODE, expired: $EXPIRY_DATE)"
        ISSUES=$((ISSUES + 1))
      else
        echo "  PASS     GOVERNANCE_MODE (mode: $CURRENT_MODE, expires: $EXPIRY_DATE)"
      fi
    fi
  else
    echo "  SKIP     GOVERNANCE_MODE not found"
  fi

  # --- Interpretation Log Cross-Check ---
  echo ""
  echo "Interpretation Log:"
  BIL_PATH="$TARGET/docs/agents/system/BASELINE_INTERPRETATION_LOG.md"
  if [[ -f "$BIL_PATH" ]]; then
    PENDING_COUNT=$(grep -ciE "status:.*\b(pending|proposed|draft)\b" "$BIL_PATH" 2>/dev/null || echo "0")
    if [[ "$PENDING_COUNT" -gt 0 ]]; then
      echo "  WARN     $PENDING_COUNT pending interpretation(s) in BASELINE_INTERPRETATION_LOG"
      # Check if derived docs reference interpretations
      for derived_doc in "$TARGET/docs/agents/system/SYSTEM_GOAL_PACK.md" "$TARGET/docs/agents/system/SYSTEM_INVARIANTS.md"; do
        if [[ -f "$derived_doc" ]] && grep -q "INT-" "$derived_doc" 2>/dev/null; then
          DOC_NAME=$(basename "$derived_doc")
          echo "  WARN     $DOC_NAME references interpretations, but some are still pending"
        fi
      done
    else
      echo "  PASS     No pending interpretations"
    fi
  else
    echo "  SKIP     BASELINE_INTERPRETATION_LOG not found"
  fi

  echo ""
  echo "================================"
  echo ""
  echo "Verdict:"
  if [[ "$ISSUES" -eq 0 ]]; then
    echo "  PASS — all checks passed"
  else
    echo "  FAIL — $ISSUES issue(s) found"
    echo "  Action: resolve the issues listed above"
  fi
  exit 0
fi

# --- Dry-run mode ---
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run — files that would be created in $TARGET:"
  echo ""
fi

mkdir_maybe() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return
  fi
  mkdir -p "$@"
}

mkdir_maybe \
  "$TARGET/docs/agents/system" \
  "$TARGET/docs/agents/system/scenarios" \
  "$TARGET/docs/agents/modules" \
  "$TARGET/docs/agents/debug" \
  "$TARGET/docs/agents/debug/cases" \
  "$TARGET/docs/agents/implementation" \
  "$TARGET/docs/agents/verification" \
  "$TARGET/docs/agents/frontend" \
  "$TARGET/docs/agents/execution" \
  "$TARGET/docs/agents/execution/completed" \
  "$TARGET/docs/agents/task-checklists" \
  "$TARGET/docs/agents/optimization" \
  "$TARGET/docs/agents/optimization/backups" \
  "$TARGET/docs/agents/optimization/test-scenarios" \
  "$TARGET/docs/plans/agents"

# --- .governance/ attestation layer (Phase 1.5 + Phase 2) ---
mkdir_maybe "$TARGET/.governance"
mkdir_maybe "$TARGET/.governance/attestations"

# Initialize empty attestation index if it doesn't exist
if [[ "$DRY_RUN" -eq 0 ]]; then
  if [[ ! -f "$TARGET/.governance/attestations/index.jsonl" ]]; then
    touch "$TARGET/.governance/attestations/index.jsonl"
    echo "write $TARGET/.governance/attestations/index.jsonl"
  fi
else
  echo "  write $TARGET/.governance/attestations/index.jsonl"
fi

# --- .gitignore entries for .governance/ non-committed data ---
if [[ "$DRY_RUN" -eq 0 ]]; then
  GITIGNORE_ENTRIES=(
    "# Governance session data (not committed)"
    ".governance/audit/"
    ".governance/sessions/"
    ".governance/steps/"
    ".governance/current-task.json"
  )
  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qF "$entry" "$TARGET/.gitignore" 2>/dev/null; then
      echo "$entry" >> "$TARGET/.gitignore"
    fi
  done
fi

copy_file() {
  local src="$1"
  local dst="$2"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -e "$dst" && "$FORCE" -ne 1 ]]; then
      echo "  skip  $dst"
    else
      echo "  write $dst"
    fi
    return
  fi

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

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  write $dst/ (directory copy)"
    return
  fi

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

# PROJECT_BASELINE — root document, must be created first
copy_file "$ROOT/docs/templates/PROJECT_BASELINE.template.md" \
  "$TARGET/docs/agents/PROJECT_BASELINE.md"

# Architecture baseline (Tier 0.8, user-owned)
copy_file "$ROOT/docs/templates/PROJECT_ARCHITECTURE_BASELINE.template.md" \
  "$TARGET/docs/agents/PROJECT_ARCHITECTURE_BASELINE.md"

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
  hermes)
    copy_file "$ROOT/HERMES.md" "$TARGET/HERMES.md"
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

# Business semantics interpretation log (Tier 0.5)
copy_file "$ROOT/docs/templates/system/BASELINE_INTERPRETATION_LOG.template.md" \
  "$TARGET/docs/agents/system/BASELINE_INTERPRETATION_LOG.md"

# Engineering constraints (Tier 1.5)
copy_file "$ROOT/docs/templates/system/ENGINEERING_CONSTRAINTS.template.md" \
  "$TARGET/docs/agents/system/ENGINEERING_CONSTRAINTS.md"

# Derivation registry (meta-artifact)
copy_file "$ROOT/docs/templates/system/DERIVATION_REGISTRY.template.md" \
  "$TARGET/docs/agents/system/DERIVATION_REGISTRY.md"

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
copy_file "$ROOT/docs/templates/system/ROUTING_POLICY.template.md" \
  "$TARGET/docs/agents/system/ROUTING_POLICY.md"
copy_file "$ROOT/docs/templates/system/MODULE_TAXONOMY.template.md" \
  "$TARGET/docs/agents/system/MODULE_TAXONOMY.md"

# Derived architecture (Tier 2)
copy_file "$ROOT/docs/templates/system/SYSTEM_ARCHITECTURE.template.md" \
  "$TARGET/docs/agents/system/SYSTEM_ARCHITECTURE.md"

# Architecture change proposals (meta-artifact)
copy_file "$ROOT/docs/templates/system/ARCHITECTURE_CHANGE_PROPOSAL.template.md" \
  "$TARGET/docs/agents/system/ARCHITECTURE_CHANGE_PROPOSAL.md"

# Seed module
if [[ -n "$SEED_MODULE" ]]; then
  mkdir_maybe "$TARGET/docs/agents/modules/$SEED_MODULE"
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
copy_file "$ROOT/docs/templates/verification/FEEDBACK_LOG.template.md" \
  "$TARGET/docs/agents/verification/FEEDBACK_LOG.md"
copy_file "$ROOT/docs/templates/verification/CRITERIA_EVOLUTION.template.md" \
  "$TARGET/docs/agents/verification/CRITERIA_EVOLUTION.md"
copy_file "$ROOT/docs/templates/verification/FEEDBACK_ANALYSIS_PROTOCOL.template.md" \
  "$TARGET/docs/agents/verification/FEEDBACK_ANALYSIS_PROTOCOL.md"

# Authority conflict detector (system-level)
copy_file "$ROOT/docs/templates/system/AUTHORITY_CONFLICT_DETECTOR.template.md" \
  "$TARGET/docs/agents/system/AUTHORITY_CONFLICT_DETECTOR.md"

# Optimization artifacts
copy_file "$ROOT/docs/templates/optimization/OPTIMIZATION_LOG.template.md" \
  "$TARGET/docs/agents/optimization/OPTIMIZATION_LOG.md"
copy_file "$ROOT/docs/templates/optimization/PROMPT_TUNING_PROTOCOL.template.md" \
  "$TARGET/docs/agents/optimization/PROMPT_TUNING_PROTOCOL.md"
copy_file "$ROOT/docs/templates/optimization/ROLLBACK_GUARD.template.md" \
  "$TARGET/docs/agents/optimization/ROLLBACK_GUARD.md"
copy_file "$ROOT/docs/templates/optimization/REGRESSION_CASES.template.md" \
  "$TARGET/docs/agents/optimization/REGRESSION_CASES.md"

# Seed test scenarios
for scenario in "$ROOT/docs/templates/optimization/test-scenarios"/seed-*.json; do
  if [[ -f "$scenario" ]]; then
    copy_file "$scenario" \
      "$TARGET/docs/agents/optimization/test-scenarios/$(basename "$scenario")"
  fi
done

# Execution state template
copy_file "$ROOT/docs/templates/execution/GOVERNANCE_PROGRESS.template.md" \
  "$TARGET/docs/agents/execution/GOVERNANCE_PROGRESS.template.md"

# Project-wide direction (execution context, not upstream truth)
copy_file "$ROOT/docs/templates/execution/CURRENT_DIRECTION.template.md" \
  "$TARGET/docs/agents/execution/CURRENT_DIRECTION.md"

# Governance mode (execution-layer)
copy_file "$ROOT/docs/templates/execution/GOVERNANCE_MODE.template.md" \
  "$TARGET/docs/agents/execution/GOVERNANCE_MODE.md"

# Mode transition log (execution-layer)
copy_file "$ROOT/docs/templates/execution/MODE_TRANSITION_LOG.template.md" \
  "$TARGET/docs/agents/execution/MODE_TRANSITION_LOG.md"

# --- Phase 1.5 enforcement scripts ---
for script in check-commit-governance.sh check-module-contract.sh check-escalation-block.sh check-bug-evidence.sh; do
  if [[ -f "$ROOT/scripts/$script" ]]; then
    copy_file "$ROOT/scripts/$script" "$TARGET/scripts/$script"
  fi
done

# --- Phase 3 receipt-dependent scripts ---
for script in check-task-binding.sh check-task-receipt.sh check-receipt-scope.sh check-manual-attestation-policy.sh check-index-consistency.sh; do
  if [[ -f "$ROOT/scripts/$script" ]]; then
    copy_file "$ROOT/scripts/$script" "$TARGET/scripts/$script"
  fi
done

# --- Receipt/index validators (Python) ---
for pyfile in validate-receipt.py validate-index.py; do
  if [[ -f "$ROOT/scripts/$pyfile" ]]; then
    copy_file "$ROOT/scripts/$pyfile" "$TARGET/scripts/$pyfile"
  fi
done

# --- CI governance workflow ---
if [[ -f "$ROOT/.github/workflows/governance.yml" ]]; then
  mkdir_maybe "$TARGET/.github/workflows"
  copy_file "$ROOT/.github/workflows/governance.yml" "$TARGET/.github/workflows/governance.yml"
fi

# --- Phase 2 governance attestation templates ---
GOVERNANCE_TEMPLATES_SRC="$ROOT/docs/templates/governance"
GOVERNANCE_TEMPLATES_DST="$TARGET/docs/templates/governance"
if [[ -d "$GOVERNANCE_TEMPLATES_SRC" ]]; then
  mkdir_maybe "$GOVERNANCE_TEMPLATES_DST"
  for tmpl in "$GOVERNANCE_TEMPLATES_SRC"/*; do
    [[ -f "$tmpl" ]] || continue
    copy_file "$tmpl" "$GOVERNANCE_TEMPLATES_DST/$(basename "$tmpl")"
  done
fi

# Optional: copy commands
if [[ "$COPY_COMMANDS" -eq 1 ]]; then
  copy_dir "$ROOT/.claude/commands" "$TARGET/.claude/commands"
fi

# Optional: copy skills
if [[ "$COPY_SKILLS" -eq 1 ]]; then
  copy_dir "$ROOT/.claude/skills" "$TARGET/.claude/skills"
fi

# --- Adapter-specific enforcement wiring ---
case "$ADAPTER" in
  claude-code)
    # Copy hooks template
    if [[ -f "$ROOT/adapters/claude-code/hooks.json.template" ]]; then
      mkdir_maybe "$TARGET/adapters/claude-code"
      copy_file "$ROOT/adapters/claude-code/hooks.json.template" \
        "$TARGET/adapters/claude-code/hooks.json.template"
    fi
    ;;
  codex)
    # Copy Codex config to .codex/config.toml (the path Codex CLI reads)
    if [[ -f "$ROOT/adapters/codex/config.toml.template" ]]; then
      mkdir_maybe "$TARGET/.codex"
      copy_file "$ROOT/adapters/codex/config.toml.template" \
        "$TARGET/.codex/config.toml"
    fi
    # Copy governance-check skill to .agents/skills/ (where Codex discovers skills)
    if [[ -d "$ROOT/adapters/codex/skills/governance-check" ]]; then
      mkdir_maybe "$TARGET/.agents/skills/governance-check"
      copy_file "$ROOT/adapters/codex/skills/governance-check/SKILL.md" \
        "$TARGET/.agents/skills/governance-check/SKILL.md"
    fi
    ;;
  hermes)
    # Copy Hermes MCP config template
    if [[ -f "$ROOT/adapters/hermes/config.yaml.template" ]]; then
      mkdir_maybe "$TARGET/adapters/hermes"
      copy_file "$ROOT/adapters/hermes/config.yaml.template" \
        "$TARGET/adapters/hermes/config.yaml.template"
    fi
    # Copy Hermes cron jobs template
    if [[ -f "$ROOT/adapters/hermes/cron-jobs.yaml.template" ]]; then
      copy_file "$ROOT/adapters/hermes/cron-jobs.yaml.template" \
        "$TARGET/adapters/hermes/cron-jobs.yaml.template"
    fi
    # Copy Hermes notifications template
    if [[ -f "$ROOT/adapters/hermes/notifications.yaml.template" ]]; then
      copy_file "$ROOT/adapters/hermes/notifications.yaml.template" \
        "$TARGET/adapters/hermes/notifications.yaml.template"
    fi
    # Copy governance-check skill for Hermes
    if [[ -d "$ROOT/adapters/hermes/skills/governance-check" ]]; then
      mkdir_maybe "$TARGET/.hermes/skills/governance-check"
      copy_file "$ROOT/adapters/hermes/skills/governance-check/SKILL.md" \
        "$TARGET/.hermes/skills/governance-check/SKILL.md"
    fi
    # Copy governance-guard plugin
    if [[ -d "$ROOT/adapters/hermes/plugin" ]]; then
      mkdir_maybe "$TARGET/adapters/hermes/plugin"
      for f in __init__.py schemas.py tools.py plugin.yaml authority.py \
               state.py hardgate.py router.py audit.py constants.py; do
        if [[ -f "$ROOT/adapters/hermes/plugin/$f" ]]; then
          copy_file "$ROOT/adapters/hermes/plugin/$f" \
            "$TARGET/adapters/hermes/plugin/$f"
        fi
      done
    fi
    # Copy CG role skills for Hermes
    for skill in cg-system-architect cg-module-architect cg-debug \
                 cg-implementation cg-verification cg-frontend-specialist \
                 cg-autoresearch cg-router; do
      if [[ -d "$ROOT/adapters/hermes/skills/$skill" ]]; then
        mkdir_maybe "$TARGET/.hermes/skills/$skill"
        copy_file "$ROOT/adapters/hermes/skills/$skill/SKILL.md" \
          "$TARGET/.hermes/skills/$skill/SKILL.md"
      fi
    done
    ;;
esac

# --- MCP server (both adapters) ---
if [[ -d "$ROOT/governance-mcp-server" ]]; then
  mkdir_maybe "$TARGET/governance-mcp-server"
  for f in "$ROOT/governance-mcp-server"/*.py "$ROOT/governance-mcp-server"/*.txt; do
    [[ -f "$f" ]] || continue
    copy_file "$f" "$TARGET/governance-mcp-server/$(basename "$f")"
  done
fi

# --- Readiness report ---
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ""
  echo "No files written (dry run)."
  exit 0
fi

echo ""
echo "Bootstrap complete."
echo ""
echo "  Target:       $TARGET"
echo "  Platform:     $PLATFORM"
echo "  Adapter:      $ADAPTER"
echo "  Seed module:  ${SEED_MODULE:-"(none)"}"
echo "  Commands:     $COPY_COMMANDS"
echo "  Skills:       $COPY_SKILLS"
echo ""
echo "Readiness:"
echo "  System truth docs    created (needs project-specific content)"
echo "  Routing policy       created (needs project-specific routes)"
echo "  Module taxonomy      created (review module type definitions)"
if [[ -n "$SEED_MODULE" ]]; then
  echo "  Module contract      created for '$SEED_MODULE' (fill in 10 sections)"
else
  echo "  Module contract      not seeded (use --seed-module when ready)"
fi
echo "  Debug governance     created (review before first bug task)"
echo "  Verification rules   created"
echo ""
echo "Next steps (in order — do not skip):"
echo ""
echo "  Step 1: Fill in docs/agents/PROJECT_BASELINE.md"
echo "          This is the ONLY document you write. Plain business language, under 100 lines."
echo ""
echo "  Step 2: Trigger first derivation"
echo "          Open your AI coding tool and say:"
echo "          \"PROJECT_BASELINE is ready. Derive SYSTEM_GOAL_PACK and SYSTEM_INVARIANTS from it.\""
echo "          The System Architect agent will:"
echo "            - Read your BASELINE"
echo "            - Auto-derive structural items (product vision, module scope, boundaries)"
echo "            - Present interpretive items for your confirmation (business rule → technical invariant)"
echo "            - Update derived_from_baseline_version in each output document"
echo ""
echo "  Step 3: Run --validate to confirm derivation completed"
echo "          bash scripts/bootstrap-project.sh --target $TARGET --validate"
echo "          Look for: all derived documents show version != v0.0"
echo ""
echo "  Until Step 2 is done, derived documents contain template placeholders (v0.0)."
echo "  The governance chain will NOT function correctly with unfilled derived documents."
