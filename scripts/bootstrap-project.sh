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
  --platform <name>     Copy the project-level platform entrypoint (`claude`, `codex`, or `gemini`)
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

case "$PLATFORM" in
  claude|codex|gemini)
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

  echo ""
  echo "Bootstrap Readiness:"
  check_file "$TARGET/docs/agents/BOOTSTRAP_READINESS.md" "BOOTSTRAP_READINESS"

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

  echo ""
  echo "================================"
  if [[ "$ISSUES" -eq 0 ]]; then
    echo "All checks passed."
  else
    echo "$ISSUES issue(s) found. Fill in the documents above to complete governance setup."
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
copy_file "$ROOT/docs/templates/system/ROUTING_POLICY.template.md" \
  "$TARGET/docs/agents/system/ROUTING_POLICY.md"
copy_file "$ROOT/docs/templates/system/MODULE_TAXONOMY.template.md" \
  "$TARGET/docs/agents/system/MODULE_TAXONOMY.md"

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

# Optional: copy commands
if [[ "$COPY_COMMANDS" -eq 1 ]]; then
  copy_dir "$ROOT/.claude/commands" "$TARGET/.claude/commands"
fi

# Optional: copy skills
if [[ "$COPY_SKILLS" -eq 1 ]]; then
  copy_dir "$ROOT/.claude/skills" "$TARGET/.claude/skills"
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
