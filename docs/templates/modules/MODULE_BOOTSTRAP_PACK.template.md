# MODULE_BOOTSTRAP_PACK: [module-name]

**Status:** proposed
**Readiness:** not_ready
**Owner:** Module Architect Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Warm Bootstrap Reading Order

When activating for this module, read in this order:

1. This file (orientation)
2. `MODULE_CONTRACT.md` (what this module must do)
3. `MODULE_BOUNDARY.md` (what this module must NOT do)
4. `MODULE_WORKFLOW.md` (execution phases)
5. `MODULE_DATAFLOW.md` (data transforms)
6. `MODULE_CANONICAL_WORKFLOW.md` (step-by-step with code links)
7. `MODULE_CANONICAL_DATAFLOW.md` (data edges with code links)

## 2. Role Memory Summary

After bootstrap, you should know:

1. **Module purpose:** <!-- one sentence -->
2. **Key inputs:** <!-- list the top 3 -->
3. **Key outputs:** <!-- list the top 3 -->
4. **Fail-closed rules:** <!-- most critical fail condition -->
5. **Upstream dependency:** <!-- what feeds this module -->

## 3. Boundary Statement

### This Module Owns
<!-- List owned responsibilities -->

### This Module Does NOT Own
<!-- List excluded responsibilities -->

## 4. On-Demand Evidence Set

Load only when debugging or resolving disputes:

1. <!-- Key source file: path/to/main-entry.ts -->
2. <!-- Key test file: path/to/module.test.ts -->
3. <!-- Upstream module contract (if dependency dispute) -->
4. <!-- Downstream consumer contract (if output dispute) -->
5. <!-- Related system scenario map -->

## 5. Readiness Meaning

- `ready` = all 6 core module artifacts exist and are status: active
- `partial` = base 4 artifacts exist, canonical maps pending
- `not_ready` = module not yet defined
