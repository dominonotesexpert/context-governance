"""Tests for router.py — task classification and routing."""

from adapters.hermes.plugin.router import classify_task, reroute_after_debug


class TestClassifyTask:
    def test_bug_keywords(self):
        task_type, route, conf = classify_task("Fix the login bug")
        assert task_type == "bug"
        assert "debug" in route

    def test_regression_is_bug(self):
        task_type, route, conf = classify_task("Regression in auth module")
        assert task_type == "bug"

    def test_feature_keywords(self):
        task_type, route, conf = classify_task("Implement user dashboard")
        assert task_type == "feature"
        assert "implementation" in route
        assert "debug" not in route

    def test_design_keywords(self):
        task_type, route, conf = classify_task("Design the new API protocol")
        assert task_type == "design"
        assert "implementation" not in route

    def test_authority_keywords(self):
        task_type, route, conf = classify_task("Resolve baseline conflict")
        assert task_type == "authority"
        assert route == ["system-architect"]

    def test_frontend_keywords_add_specialist(self):
        task_type, route, conf = classify_task("Fix the UI layout bug")
        assert "frontend-specialist" in route

    def test_unknown_defaults_to_feature(self):
        task_type, route, conf = classify_task("Do something vague")
        assert task_type == "feature"
        assert conf < 0.5

    def test_all_routes_start_with_system_architect(self):
        for desc in ["fix bug", "add feature", "design API", "resolve conflict"]:
            _, route, _ = classify_task(desc)
            assert route[0] == "system-architect"

    def test_all_non_authority_routes_end_with_verification(self):
        for desc in ["fix bug", "add feature", "design API"]:
            _, route, _ = classify_task(desc)
            assert route[-1] == "verification"


class TestRerouteAfterDebug:
    def test_code_level(self):
        route = reroute_after_debug("code")
        assert route == ["implementation", "verification"]

    def test_module_level(self):
        route = reroute_after_debug("module")
        assert route == ["implementation", "verification"]

    def test_cross_module_includes_ma(self):
        route = reroute_after_debug("cross-module")
        assert "module-architect" in route
        assert "implementation" in route

    def test_architecture_includes_sa(self):
        route = reroute_after_debug("architecture")
        assert "system-architect" in route

    def test_baseline_returns_empty(self):
        route = reroute_after_debug("baseline")
        assert route == []
