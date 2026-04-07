#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/check-receipt-scope.sh [--target <path>]"
  echo ""
  echo "Options:"
  echo "  --target <path>  Target project root (default: .)"
  echo "  -h, --help       Show this help text"
  echo ""
  echo "Checks whether staged files are plausibly covered by the bound receipt's scope."
  echo "Exit: 0=PASSED, 1=BLOCKED (staged files outside receipt scope)"
}

TARGET="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

echo "Receipt Scope Check"

ATTESTATION_DIR="$TARGET/.governance/attestations"
INDEX_FILE="$ATTESTATION_DIR/index.jsonl"

# Guard: only enforce when attestation system is active
if [[ ! -f "$INDEX_FILE" ]] || [[ ! -s "$INDEX_FILE" ]]; then
  echo "  PASSED   Attestation system not yet active."
  exit 0
fi

# Get staged files
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
if [[ -z "$STAGED" ]]; then
  echo "  PASSED   No staged files."
  exit 0
fi

# Extract CG-Task from commit message
COMMIT_MSG_FILE="$TARGET/.git/COMMIT_EDITMSG"
if [[ ! -f "$COMMIT_MSG_FILE" ]]; then
  echo "  PASSED   No commit message available (will be validated by CI)."
  exit 0
fi

TASK_IDS=$(grep -oP '^CG-Task:\s*\K(T-\d{8}-\d{3,})' "$COMMIT_MSG_FILE" 2>/dev/null || true)
if [[ -z "$TASK_IDS" ]]; then
  echo "  PASSED   No CG-Task trailer — scope check not applicable."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "  WARNING  python3 not available — skipping scope check."
  exit 0
fi

# Collect all affected_paths from bound receipts
ALLOWED_PATHS=$(python3 - "$ATTESTATION_DIR" "$TASK_IDS" <<'PYEOF'
import sys, os, glob

att_dir = sys.argv[1]
task_ids = sys.argv[2].strip().split('\n')

paths = set()
for tid in task_ids:
    tid = tid.strip()
    if not tid:
        continue
    receipt = os.path.join(att_dir, f"{tid}.receipt.yaml")
    if not os.path.exists(receipt):
        continue
    in_scope = False
    in_paths = False
    with open(receipt) as f:
        for line in f:
            stripped = line.rstrip()
            if stripped.strip() == 'scope:':
                in_scope = True
                continue
            if in_scope and stripped.strip() == 'affected_paths:':
                in_paths = True
                continue
            if in_paths:
                if stripped.strip().startswith('- '):
                    p = stripped.strip()[2:].strip()
                    paths.add(p)
                elif not stripped.startswith('    ') and stripped.strip():
                    in_paths = False
                    in_scope = False

for p in sorted(paths):
    print(p)
PYEOF
)

if [[ -z "$ALLOWED_PATHS" ]]; then
  echo "  WARNING  Receipt has no affected_paths declared — scope check skipped."
  exit 0
fi

# Check each governed staged file against allowed paths
OUT_OF_SCOPE=""
while IFS= read -r f; do
  # Skip non-governed files
  case "$f" in
    .governance/*|.githooks/*|.claude/*|.codex/*) continue ;;
  esac

  MATCH=0
  while IFS= read -r allowed; do
    [[ -z "$allowed" ]] && continue
    # Exact match or prefix match (directory scope)
    if [[ "$f" == "$allowed" ]] || [[ "$f" == "$allowed"/* ]]; then
      MATCH=1
      break
    fi
    # Module-level match: if affected_path is a directory prefix
    if [[ "$allowed" == */ ]] && [[ "$f" == "${allowed}"* ]]; then
      MATCH=1
      break
    fi
  done <<< "$ALLOWED_PATHS"

  if [[ "$MATCH" -eq 0 ]]; then
    OUT_OF_SCOPE="$OUT_OF_SCOPE$f"$'\n'
  fi
done <<< "$STAGED"
OUT_OF_SCOPE="${OUT_OF_SCOPE%$'\n'}"

if [[ -n "$OUT_OF_SCOPE" ]]; then
  COUNT=$(echo "$OUT_OF_SCOPE" | wc -l | tr -d ' ')
  echo "  BLOCKED  $COUNT file(s) outside receipt scope:"
  echo "$OUT_OF_SCOPE" | sed 's/^/           /'
  echo "           Update receipt affected_paths or split the commit."
  exit 1
fi

echo "  PASSED   All staged files within receipt scope."
exit 0
