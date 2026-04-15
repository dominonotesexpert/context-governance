"""Task classification and route determination for Context Governance.

Classifies tasks by keyword matching against ROUTING_POLICY §2,
and determines the governance role chain.
"""

from __future__ import annotations

from .constants import (
    AUTHORITY_KEYWORDS,
    BUG_KEYWORDS,
    DEBUG_LEVEL_ROUTES,
    DESIGN_KEYWORDS,
    FEATURE_KEYWORDS,
    FRONTEND_KEYWORDS,
    ROLE_FRONTEND_SPECIALIST,
    ROLE_IMPLEMENTATION,
    ROLE_VERIFICATION,
    ROUTES,
    TASK_TYPE_AUTHORITY,
    TASK_TYPE_BUG,
    TASK_TYPE_DESIGN,
    TASK_TYPE_FEATURE,
)


def classify_task(description: str) -> tuple[str, list[str], float]:
    """Classify a task description and determine the governance route.

    Returns:
        (task_type, route, confidence)
        - task_type: one of "bug", "feature", "design", "authority"
        - route: ordered list of role names
        - confidence: 0.0–1.0
    """
    desc_lower = description.lower()

    # Score each task type by keyword matches
    scores = {
        TASK_TYPE_BUG: _score_keywords(desc_lower, BUG_KEYWORDS),
        TASK_TYPE_FEATURE: _score_keywords(desc_lower, FEATURE_KEYWORDS),
        TASK_TYPE_DESIGN: _score_keywords(desc_lower, DESIGN_KEYWORDS),
        TASK_TYPE_AUTHORITY: _score_keywords(desc_lower, AUTHORITY_KEYWORDS),
    }

    # Pick the highest scoring type
    best_type = max(scores, key=scores.get)  # type: ignore[arg-type]
    best_score = scores[best_type]

    # If no keywords matched at all, default to feature
    if best_score == 0:
        best_type = TASK_TYPE_FEATURE
        confidence = 0.3
    else:
        # Confidence is based on how dominant the best score is
        total = sum(scores.values())
        confidence = min(best_score / max(total, 1), 1.0)

    route = list(ROUTES.get(best_type, ROUTES[TASK_TYPE_FEATURE]))

    # Add Frontend Specialist if UI-related keywords are present
    if _score_keywords(desc_lower, FRONTEND_KEYWORDS) > 0:
        route = _insert_frontend_specialist(route)

    return best_type, route, round(confidence, 2)


def reroute_after_debug(root_cause_level: str) -> list[str]:
    """Determine remaining route after Debug agent classifies root cause level.

    Returns the remaining role chain based on the root cause level.
    An empty list means escalation to user (baseline-level issue).
    """
    return list(DEBUG_LEVEL_ROUTES.get(root_cause_level, []))


def _score_keywords(text: str, keywords: list[str]) -> int:
    """Count how many keywords appear in the text."""
    return sum(1 for kw in keywords if kw in text)


def _insert_frontend_specialist(route: list[str]) -> list[str]:
    """Insert Frontend Specialist before Implementation in the route.

    If Implementation is not in the route, insert before Verification.
    """
    result = list(route)

    if ROLE_FRONTEND_SPECIALIST in result:
        return result  # Already present

    # Insert before Implementation
    if ROLE_IMPLEMENTATION in result:
        idx = result.index(ROLE_IMPLEMENTATION)
        result.insert(idx, ROLE_FRONTEND_SPECIALIST)
    elif ROLE_VERIFICATION in result:
        idx = result.index(ROLE_VERIFICATION)
        result.insert(idx, ROLE_FRONTEND_SPECIALIST)
    else:
        result.append(ROLE_FRONTEND_SPECIALIST)

    return result
