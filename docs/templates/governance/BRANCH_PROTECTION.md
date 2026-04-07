# Branch Protection Setup Guide

**Authority:** `docs/plans/2026-03-24-deerflow-inspired-governance-engine-plan.md` §7.3

---

## Purpose

Protected branches are the final enforcement boundary. Combined with CI governance checks, they ensure non-compliant changes cannot enter the governed repository state.

---

## Required GitHub Branch Protection Rules

### For `main` (or primary protected branch)

| Setting | Value | Reason |
|---------|-------|--------|
| Require status checks to pass | **Yes** | CI governance gate must pass |
| Required status checks | `Governance Compliance` | The governance workflow job name |
| Require branches to be up to date | **Yes** | Prevent stale merges that skip new governance rules |
| Require pull request reviews | **Yes** | Human oversight required |
| Required approvals | **1+** | At least one reviewer |
| Dismiss stale reviews on push | **Yes** | New pushes invalidate prior approvals |
| Require review from code owners | **Optional** | Recommended for Tier 0/0.5 artifacts |
| Restrict who can push | **Yes** | Prevent direct pushes bypassing PR |
| Allow force pushes | **No** | Preserve commit history and trailers |
| Allow deletions | **No** | Prevent branch deletion |

---

## Manual Attestation Approval

When a PR contains commits bound to `attestation_mode: manual_attestation` receipts:

1. The CI workflow emits a `::warning::` annotation visible in the PR checks tab
2. The reviewer **must** acknowledge the manual attestation before approving
3. Merging without reviewer awareness of the manual attestation is a governance gap

### Reviewer Checklist for Manual Attestation

- [ ] `manual_fallback_reason` is legitimate (MCP unavailable, not convenience bypass)
- [ ] All required evidence artifacts exist and are meaningful
- [ ] The work could not have reasonably used MCP attestation
- [ ] Receipt claims are consistent with the actual changes

---

## Setup Steps

### GitHub UI

1. Go to **Settings > Branches > Branch protection rules**
2. Click **Add rule** for `main`
3. Apply settings from the table above
4. Save changes

### GitHub CLI

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["Governance Compliance"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field restrictions=null
```

---

## CODEOWNERS Integration (Optional)

For stronger protection of governance artifacts, add a `CODEOWNERS` file:

```
# Governance truth namespace — requires system architect review
docs/agents/system/         @system-architect-team
docs/agents/PROJECT_BASELINE.md  @system-architect-team

# Governance enforcement — requires infra review
scripts/check-*.sh          @governance-infra-team
.github/workflows/governance.yml @governance-infra-team
.governance/                @governance-infra-team
```

---

## Verification

After setup, verify with:

```bash
# Check branch protection is active
gh api repos/{owner}/{repo}/branches/main/protection

# Verify required status checks
gh api repos/{owner}/{repo}/branches/main/protection/required_status_checks
```
