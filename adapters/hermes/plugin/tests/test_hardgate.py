"""Tests for hardgate.py — HARD-GATE requirement checking."""

from adapters.hermes.plugin.hardgate import (
    check_hardgate_satisfaction,
    get_missing_hardgate_docs,
    get_required_docs_for_role,
)


class TestGetRequiredDocsForRole:
    def test_sa_requires_baseline(self):
        docs = get_required_docs_for_role("system-architect")
        assert "docs/agents/PROJECT_BASELINE.md" in docs

    def test_implementation_does_not_require_baseline(self):
        docs = get_required_docs_for_role("implementation")
        assert "docs/agents/PROJECT_BASELINE.md" not in docs

    def test_implementation_requires_goal_pack(self):
        docs = get_required_docs_for_role("implementation")
        assert "docs/agents/system/SYSTEM_GOAL_PACK.md" in docs

    def test_module_architect_includes_module_contract(self):
        docs = get_required_docs_for_role("module-architect", "auth")
        assert "docs/agents/modules/auth/MODULE_CONTRACT.md" in docs

    def test_module_architect_without_module_has_no_contract(self):
        docs = get_required_docs_for_role("module-architect")
        contract_docs = [d for d in docs if "MODULE_CONTRACT" in d]
        assert len(contract_docs) == 0

    def test_debug_requires_debug_template(self):
        docs = get_required_docs_for_role("debug")
        assert "docs/agents/debug/DEBUG_CASE_TEMPLATE.md" in docs

    def test_verification_requires_acceptance_rules(self):
        docs = get_required_docs_for_role("verification")
        assert "docs/agents/verification/ACCEPTANCE_RULES.md" in docs


class TestCheckHardgateSatisfaction:
    def test_all_docs_loaded_passes(self):
        required = get_required_docs_for_role("implementation")
        assert check_hardgate_satisfaction("implementation", set(required))

    def test_missing_doc_fails(self):
        assert not check_hardgate_satisfaction("implementation", set())

    def test_extra_docs_still_passes(self):
        required = get_required_docs_for_role("implementation")
        loaded = set(required) | {"extra/file.md"}
        assert check_hardgate_satisfaction("implementation", loaded)

    def test_path_normalization(self):
        required = get_required_docs_for_role("implementation")
        # Add leading ./
        loaded = {"./"+d for d in required}
        assert check_hardgate_satisfaction("implementation", loaded)


class TestGetMissingHardgateDocs:
    def test_all_loaded_returns_empty(self):
        required = get_required_docs_for_role("implementation")
        missing = get_missing_hardgate_docs("implementation", set(required))
        assert missing == []

    def test_none_loaded_returns_all(self):
        missing = get_missing_hardgate_docs("implementation", set())
        required = get_required_docs_for_role("implementation")
        assert len(missing) == len(required)
