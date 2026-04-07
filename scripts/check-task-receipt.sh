#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/check-task-receipt.sh [--target <path>] [--task-id <id>]"
  echo ""
  echo "Options:"
  echo "  --target <path>   Target project root (default: .)"
  echo "  --task-id <id>    Validate a specific receipt (default: validate all in-progress)"
  echo "  -h, --help        Show this help text"
  echo ""
  echo "Validates receipt YAML against schema and per-task-type required claims."
  echo "Exit: 0=PASSED, 1=BLOCKED"
}

TARGET="."
TASK_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --task-id) TASK_ID="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

echo "Task Receipt Check"

ATTESTATION_DIR="$TARGET/.governance/attestations"
INDEX_FILE="$ATTESTATION_DIR/index.jsonl"

# Guard: only enforce when attestation system is active
if [[ ! -f "$INDEX_FILE" ]] || [[ ! -s "$INDEX_FILE" ]]; then
  echo "  PASSED   Attestation system not yet active."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "  WARNING  python3 not available — skipping receipt validation."
  exit 0
fi

# Collect receipt files to validate
RECEIPTS=()
if [[ -n "$TASK_ID" ]]; then
  RECEIPT_PATH="$ATTESTATION_DIR/${TASK_ID}.receipt.yaml"
  if [[ ! -f "$RECEIPT_PATH" ]]; then
    echo "  BLOCKED  Receipt not found: $RECEIPT_PATH"
    exit 1
  fi
  RECEIPTS+=("$RECEIPT_PATH")
else
  # Validate receipts bound to current commit (from COMMIT_EDITMSG or all in_progress)
  COMMIT_MSG_FILE="$TARGET/.git/COMMIT_EDITMSG"
  if [[ -f "$COMMIT_MSG_FILE" ]]; then
    while IFS= read -r tid; do
      [[ -z "$tid" ]] && continue
      rpath="$ATTESTATION_DIR/${tid}.receipt.yaml"
      [[ -f "$rpath" ]] && RECEIPTS+=("$rpath")
    done < <(grep -oP '^CG-Task:\s*\K(T-\d{8}-\d{3,})' "$COMMIT_MSG_FILE" 2>/dev/null || true)
  fi

  # Fallback: validate all in_progress receipts
  if [[ ${#RECEIPTS[@]} -eq 0 ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      rpath=$(python3 -c "import json; print(json.loads('$line').get('receipt_path',''))" 2>/dev/null || true)
      status=$(python3 -c "import json; print(json.loads('$line').get('status',''))" 2>/dev/null || true)
      if [[ "$status" == "in_progress" && -n "$rpath" && -f "$TARGET/$rpath" ]]; then
        RECEIPTS+=("$TARGET/$rpath")
      fi
    done < "$INDEX_FILE"
  fi
fi

if [[ ${#RECEIPTS[@]} -eq 0 ]]; then
  echo "  PASSED   No receipts to validate."
  exit 0
fi

# Validate each receipt
ERRORS=0
for receipt in "${RECEIPTS[@]}"; do
  BASENAME=$(basename "$receipt")
  RESULT=$(python3 - "$receipt" "$TARGET" <<'PYEOF'
import sys, os

receipt_path = sys.argv[1]
target = sys.argv[2]

try:
    # Use basic YAML parsing (key: value) without external deps
    data = {}
    current_section = None
    current_list_key = None
    evidence_refs = []
    current_evidence = {}

    with open(receipt_path) as f:
        for line in f:
            stripped = line.rstrip()
            if stripped.startswith('#') or stripped == '---' or not stripped:
                continue

            # Top-level simple fields
            if not line.startswith(' ') and ':' in stripped:
                key, _, val = stripped.partition(':')
                key = key.strip()
                val = val.strip()
                if val and val != '':
                    if val == 'null':
                        val = None
                    elif val == 'true':
                        val = True
                    elif val == 'false':
                        val = False
                    data[key] = val
                else:
                    current_section = key
                    if key not in data:
                        data[key] = {}
                continue

            # Nested fields
            indent = len(line) - len(line.lstrip())
            content = stripped.strip()

            if current_section and indent >= 2:
                if content.startswith('- ') and current_section == 'evidence_refs':
                    # New evidence entry
                    if current_evidence:
                        evidence_refs.append(current_evidence)
                    kv = content[2:].strip()
                    if ':' in kv:
                        k, _, v = kv.partition(':')
                        current_evidence = {k.strip(): v.strip()}
                    else:
                        current_evidence = {}
                elif current_section == 'evidence_refs' and ':' in content:
                    k, _, v = content.partition(':')
                    current_evidence[k.strip()] = v.strip()
                elif content.startswith('- '):
                    val = content[2:].strip()
                    # Find the key this list belongs to
                    if ':' not in content:
                        parent = current_section
                        if isinstance(data.get(parent), dict):
                            # Find last key
                            pass
                        elif isinstance(data.get(parent), list):
                            data[parent].append(val)
                elif ':' in content:
                    k, _, v = content.partition(':')
                    k = k.strip()
                    v = v.strip()
                    if v == 'null': v = None
                    elif v == 'true': v = True
                    elif v == 'false': v = False
                    if isinstance(data.get(current_section), dict):
                        data[current_section][k] = v
                    else:
                        data[current_section] = {k: v}

    if current_evidence:
        evidence_refs.append(current_evidence)
    data['_evidence_refs'] = evidence_refs

except Exception as e:
    print(f"ERROR: Failed to parse receipt: {e}")
    sys.exit(1)

errors = []

# 1. Required top-level fields
for field in ['schema_version', 'task_id', 'task_type', 'status', 'attestation_mode']:
    if field not in data or data[field] is None:
        errors.append(f"Missing required field: {field}")

task_type = data.get('task_type', '')
attestation_mode = data.get('attestation_mode', '')

# 2. Task ID format
task_id = str(data.get('task_id', ''))
import re
if task_id and not re.match(r'^T-\d{8}-\d{3,}$', task_id):
    errors.append(f"Invalid task_id format: {task_id} (expected T-YYYYMMDD-NNN)")

# 3. Manual attestation requires fallback reason
if attestation_mode == 'manual_attestation':
    reason = data.get('manual_fallback_reason')
    if not reason or reason == 'null':
        errors.append("manual_attestation requires non-empty manual_fallback_reason")

# 4. Per-task-type required claims
claims = data.get('governance_claims', {})
if not isinstance(claims, dict):
    claims = {}

if task_type == 'bug':
    if claims.get('debug_case_present') is not True:
        errors.append("bug task requires governance_claims.debug_case_present: true")
    if not claims.get('module_contract_refs'):
        errors.append("bug task requires governance_claims.module_contract_refs")

if task_type in ('feature', 'refactor'):
    if not claims.get('module_contract_refs'):
        errors.append(f"{task_type} task requires governance_claims.module_contract_refs")

if task_type == 'autoresearch':
    if not claims.get('optimization_log_ref'):
        errors.append("autoresearch task requires governance_claims.optimization_log_ref")
    if claims.get('escalation_upstream') is not True:
        errors.append("autoresearch task requires governance_claims.escalation_upstream: true")

# 5. Evidence refs: check referenced files exist
for ref in evidence_refs:
    ref_path = ref.get('path', '')
    if ref_path:
        full_path = os.path.join(target, ref_path)
        if not os.path.exists(full_path):
            errors.append(f"evidence_refs path does not exist: {ref_path}")

# 6. Required evidence kinds by task type
ref_kinds = [r.get('kind', '') for r in evidence_refs]
if task_type == 'bug':
    if 'debug_case' not in ref_kinds:
        errors.append("bug task requires evidence_refs with kind: debug_case")
    if 'module_contract' not in ref_kinds:
        errors.append("bug task requires evidence_refs with kind: module_contract")
if task_type in ('feature', 'refactor'):
    if 'module_contract' not in ref_kinds:
        errors.append(f"{task_type} task requires evidence_refs with kind: module_contract")
if task_type == 'autoresearch':
    if 'optimization_artifact' not in ref_kinds:
        errors.append("autoresearch task requires evidence_refs with kind: optimization_artifact")

# 7. Lifecycle required fields
lifecycle = data.get('lifecycle', {})
if not isinstance(lifecycle, dict):
    lifecycle = {}
for lf in ['created_at', 'updated_at', 'issuer']:
    if not lifecycle.get(lf):
        errors.append(f"Missing lifecycle.{lf}")

if errors:
    for e in errors:
        print(f"ERROR: {e}")
    sys.exit(1)
else:
    print("OK")
    sys.exit(0)
PYEOF
  )

  if [[ $? -ne 0 ]]; then
    echo "  BLOCKED  $BASENAME:"
    echo "$RESULT" | sed 's/^/           /'
    ERRORS=$((ERRORS + 1))
  else
    echo "  OK       $BASENAME — valid"
  fi
done

if [[ "$ERRORS" -gt 0 ]]; then
  echo "  BLOCKED  $ERRORS receipt(s) failed validation."
  exit 1
fi

echo "  PASSED   All receipts valid."
exit 0
