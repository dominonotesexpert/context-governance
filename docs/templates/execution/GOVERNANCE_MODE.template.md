---
artifact_type: governance-mode
status: proposed
owner_role: system-architect
scope: execution
downstream_consumers: [all-roles]
last_reviewed: YYYY-MM-DD
---

# GOVERNANCE_MODE

**Status:** proposed
**Owner:** System Architect
**Last Updated:** YYYY-MM-DD

> This is an execution-layer artifact — it describes the current governance operating mode.
> It is NOT upstream truth. It does not change business goals, technical obligations, or authority hierarchy.
> It DOES affect which governance rules are enforced vs. advisory during the current operating period.

---

## 1. Current Mode

```yaml
current_mode: steady-state
activated_by: default
activation_date: YYYY-MM-DD
expiry_date: null
scope: "Full governance chain active"
suspended_rules: []
revert_plan: "N/A — steady-state is the default mode"
```

## 2. Mode Definitions

| Mode | Description | Tiers Enforced | Default Expiry |
|------|-------------|----------------|----------------|
| `steady-state` | Normal operation. Full governance chain active. | All tiers (0-7) | None (permanent default) |
| `exploration` | Design/spike phase. Contracts are drafts, not enforced. | Tier 0-1 enforced, Tier 2+ advisory | 14 days |
| `migration` | Active system transition. Temporary contract deviations allowed within declared scope. | Tier 0-0.5 enforced, must declare deviation scope | Declared revert date (required) |
| `incident` | Production emergency. Minimal governance overhead. | Tier 0-0.5 enforced, Tier 1+ suspended. Post-incident review mandatory. | 72 hours |
| `exception` | Named, time-boxed bypass of specific rules. | Must declare: which rule, why, expiry, revert plan. | Declared expiry date (required) |

## 3. Hard Rules

1. **No mode may suspend Tier 0, Tier 0.5, or Tier 0.8.** PROJECT_BASELINE, BASELINE_INTERPRETATION_LOG, and PROJECT_ARCHITECTURE_BASELINE are always authoritative, including during `incident`. Incident mode suspends Tier 1+ enforcement, not user-owned truth (business or structural).
2. **`exception` mode may not be renewed more than twice** without explicit user escalation. The third renewal requires user to either formalize the exception into a BASELINE change or revert to steady-state.
3. **`exploration` mode may not produce artifacts at `active` status** — only `draft` or `proposed`. Active promotion requires returning to steady-state first.
4. **Expired modes block all work.** If `current_mode ≠ steady-state` and today > `expiry_date`, no agent may proceed past routing. See ROUTING_POLICY §7 for the enforcement HARD-GATE.

## 4. Mode Activation Protocol

1. Only System Architect may activate a mode change (by user request or escalation)
2. Every mode change MUST be logged in MODE_TRANSITION_LOG
3. The activation MUST declare: scope, expiry_date, suspended_rules (if any), and revert_plan
4. `steady-state` is the default — it does not require explicit activation

## 5. Expiry Rules

- `exploration`: expires 14 days after activation unless renewed
- `migration`: expires on the declared revert date (must be set at activation)
- `incident`: expires 72 hours after activation unless renewed
- `exception`: expires on the declared expiry date (must be set at activation)
- When a mode expires, it does NOT automatically revert — it BLOCKS all work until:
  (a) The user explicitly renews the mode (new expiry_date set), OR
  (b) The System Architect reverts to steady-state and logs the transition
