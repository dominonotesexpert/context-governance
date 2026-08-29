# Worked Example: A Plausible Fix That Introduced New Authority

This example is intentionally domain-neutral. You do not need to know the production system it was derived from.

## Situation

A system generates an interactive page from a canonical model. Each generated control must map back to exactly one semantic object in that model. The mapping is what preserves behavior when the visual structure changes.

Some generated controls stopped mapping correctly after their wrappers changed.

An agent proposed a sophisticated fallback:

1. read the visible label near the control;
2. inspect the control's current location in the rendered page;
3. choose the semantic object whose label and location look most similar;
4. cache that match so later stages treat it as identity.

The proposal was plausible. It repaired the visible examples and could have produced clean code and green tests.

## Why Governance Rejected It

The System and Module contracts established two different authority lanes:

- canonical semantic identity came from the generation model;
- visible labels and rendered locations were observations used for display and diagnosis.

The proposed fallback crossed those lanes. It promoted observations into a new identity authority. Once cached, a translated label, repeated caption, responsive reorder, or hidden element could silently bind behavior to the wrong semantic object.

The decisive question was:

> What new authority does this solution introduce?

Answer: it allowed the rendered page to redefine canonical identity.

That architectural change had never been requested or approved.

## How the Contracts Operated

### 1. Active Baseline Lock

- **Authoritative:** one generated control maps to one canonical semantic object through deterministic model-derived identity.
- **Observation-only:** label text, rendered order, proximity, and wrapper shape.
- **Retired/non-authoritative:** older repair rules that special-cased particular wrapper shapes.
- **Allowed RCA space:** identify where deterministic identity was lost or malformed.

### 2. Double-Anchor Root Cause

- **Authority anchor:** the module contract required deterministic mapping to a canonical semantic object.
- **Observation anchor:** artifacts showed several different wrapper shapes failing at the same identity-closure step.

Together they proved that the bug was not “one special label” or “one special wrapper.” It was a failure class: generated identity had drifted from the authoritative model.

### 3. Authority Diff

| | Before proposed fix | After proposed fix |
|---|---|---|
| Identity owner | Canonical generation model | Canonical model plus rendered label/location heuristic |
| Observation role | Diagnosis and search boundary | Source of semantic truth |
| Ambiguity behavior | Reject | Guess and cache |

The diff exposed the hidden architectural change.

### 4. Corrected Design

The accepted repair kept observation subordinate to truth:

- use verified structure only to narrow where to search;
- require the final match to resolve deterministically to one canonical object;
- repair deterministic formatting or transport mismatches;
- reject no-match or ambiguous-match cases instead of guessing;
- add a family-level regression rule so new wrapper shapes do not create new special cases.

In pseudocode:

```ts
function resolveGeneratedIdentity(
  generated: GeneratedControl,
  canonical: CanonicalObject[],
): CanonicalObject {
  const candidates = narrowByVerifiedStructure(generated, canonical);
  const matches = candidates.filter((item) =>
    deterministicIdentity(item) === normalizeGeneratedIdentity(generated)
  );

  if (matches.length !== 1) {
    throw new IdentityClosureError("identity is missing or ambiguous");
  }

  return matches[0];
}
```

The rendered label may help explain a failure. It never becomes the identity key.

## Production Effect

The governance contract changed the result at two levels:

1. It prevented a locally successful implementation from creating a second source of truth.
2. It converted several apparently unrelated visual failures into one reusable bug class enforced at the owning identity boundary.

The important lesson is not about generated pages. It applies anywhere an agent wants to turn an observation into authority: logs into state, cache contents into ownership, UI text into identity, runtime shape into schema, or a historical workaround into architecture.
