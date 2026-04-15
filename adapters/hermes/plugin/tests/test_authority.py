"""Tests for authority.py — tier classification and authority checks."""

import pytest

from adapters.hermes.plugin.authority import (
    check_authority,
    classify_file_tier,
    get_role_authority_constraints,
)
from adapters.hermes.plugin.constants import (
    TIER_0,
    TIER_0_5,
    TIER_0_8,
    TIER_1,
    TIER_3,
    TIER_4,
    TIER_5,
    TIER_7,
)


class TestClassifyFileTier:
    def test_project_baseline_is_tier_0(self):
        assert classify_file_tier("docs/agents/PROJECT_BASELINE.md") == TIER_0

    def test_baseline_interpretation_log_is_tier_0_5(self):
        assert (
            classify_file_tier("docs/agents/system/BASELINE_INTERPRETATION_LOG.md")
            == TIER_0_5
        )

    def test_architecture_baseline_is_tier_0_8(self):
        assert (
            classify_file_tier("docs/agents/PROJECT_ARCHITECTURE_BASELINE.md")
            == TIER_0_8
        )

    def test_system_goal_pack_is_tier_1(self):
        assert classify_file_tier("docs/agents/system/SYSTEM_GOAL_PACK.md") == TIER_1

    def test_system_invariants_is_tier_3(self):
        assert classify_file_tier("docs/agents/system/SYSTEM_INVARIANTS.md") == TIER_3

    def test_routing_policy_is_tier_3(self):
        assert classify_file_tier("docs/agents/system/ROUTING_POLICY.md") == TIER_3

    def test_module_contract_is_tier_4(self):
        assert (
            classify_file_tier("docs/agents/modules/auth/MODULE_CONTRACT.md") == TIER_4
        )

    def test_docs_agents_general_is_tier_5(self):
        assert classify_file_tier("docs/agents/debug/DEBUG_CASE_TEMPLATE.md") == TIER_5

    def test_code_file_is_tier_7(self):
        assert classify_file_tier("src/auth/token.py") == TIER_7

    def test_unknown_file_is_tier_7(self):
        assert classify_file_tier("README.md") == TIER_7


class TestCheckAuthority:
    def test_sa_can_read_baseline(self):
        result = check_authority(
            "docs/agents/PROJECT_BASELINE.md", "read", "system-architect"
        )
        assert result["decision"] == "ALLOW"

    def test_implementation_cannot_read_baseline(self):
        result = check_authority(
            "docs/agents/PROJECT_BASELINE.md", "read", "implementation"
        )
        assert result["decision"] == "DENY"
        assert "escalation_target" in result

    def test_nobody_can_write_baseline(self):
        result = check_authority(
            "docs/agents/PROJECT_BASELINE.md", "write", "system-architect"
        )
        assert result["decision"] == "DENY"
        assert result["escalation_target"] == "user"

    def test_implementation_can_write_code(self):
        result = check_authority("src/main.py", "write", "implementation")
        assert result["decision"] == "ALLOW"

    def test_verification_cannot_write_code(self):
        result = check_authority("src/main.py", "write", "verification")
        assert result["decision"] == "DENY"

    def test_all_roles_can_read_code(self):
        for role in ["implementation", "verification", "debug", "autoresearch"]:
            result = check_authority("src/main.py", "read", role)
            assert result["decision"] == "ALLOW", f"{role} should read code"

    def test_ma_can_write_module_contract(self):
        result = check_authority(
            "docs/agents/modules/auth/MODULE_CONTRACT.md",
            "write",
            "module-architect",
        )
        assert result["decision"] == "ALLOW"

    def test_implementation_cannot_write_module_contract(self):
        result = check_authority(
            "docs/agents/modules/auth/MODULE_CONTRACT.md",
            "write",
            "implementation",
        )
        assert result["decision"] == "DENY"


class TestGetRoleAuthorityConstraints:
    def test_sa_has_broadest_read_access(self):
        constraints = get_role_authority_constraints("system-architect")
        assert 0 in constraints["read_tiers"]
        assert 0.5 in constraints["read_tiers"]
        assert 0.8 in constraints["read_tiers"]

    def test_implementation_cannot_read_tier_0(self):
        constraints = get_role_authority_constraints("implementation")
        assert 0 not in constraints["read_tiers"]

    def test_implementation_can_write_tier_7(self):
        constraints = get_role_authority_constraints("implementation")
        assert 7 in constraints["write_tiers"]
