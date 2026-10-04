"""Story CR-009: composition-root lint rules and the import-before-test order (ADR-0002 VC-3 and VC-5)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402
import run_ci  # noqa: E402

GAME_ROOT_RULES = (
    "forbidden:view_node_own_process", "forbidden:physics_process_game_logic",
    "forbidden:connect_deferred_control_signals", "forbidden:engine_time_scale_writes",
    "forbidden:scene_tree_paused_for_pause", "forbidden:autoload_singletons",
    "project_setting:physics_interpolation", "forbidden:raw_s_in_vector3",
    "forbidden:game_root_logic_keywords",
)


def _rules() -> dict:
    import json
    with open(os.path.join(lr.REPO_ROOT, "tools", "ci", "lint_rules.json"), encoding="utf-8") as fh:
        return {r["id"]: r for r in json.load(fh)["rules"]}


class CompositionRootRulesTest(unittest.TestCase):
    def test_every_composition_root_rule_is_registered_with_pass_and_fail_fixtures(self):
        rules = _rules()
        for rule_id in GAME_ROOT_RULES:
            with self.subTest(rule=rule_id):
                self.assertIn(rule_id, rules)
                folder = os.path.join(lr.FIXTURES_DIR, lr.safe_id(rule_id))
                self.assertTrue(os.path.isfile(os.path.join(folder, "pass.txt")))
                self.assertTrue(os.path.isfile(os.path.join(folder, "fail.txt")))

    def test_raw_s_rule_is_advisory_and_the_rest_are_blocking(self):
        rules = _rules()
        for rule_id in GAME_ROOT_RULES:
            expected = "ADVISORY" if rule_id == "forbidden:raw_s_in_vector3" else "BLOCKING"
            self.assertEqual(rules[rule_id]["severity"], expected, rule_id)

    def test_physics_interpolation_rule_demands_false(self):
        rule = _rules()["project_setting:physics_interpolation"]
        self.assertEqual((rule["key"], rule["value"], rule["check"]),
                         ("physics/common/physics_interpolation", "false", "equals"))

    def test_game_root_keyword_rule_fires_on_state_and_ignores_comment(self):
        rule = _rules()["forbidden:game_root_logic_keywords"]
        path = "src/core/game_root.gd"
        bad = lr.evaluate(rule, lr.MemSource({path: "extends Node\nvar score_total: int = 0\n"}))
        self.assertEqual([v.line for v in bad.violations], [2])
        good = lr.evaluate(rule, lr.MemSource({path: "extends Node\n# var score: int = 0\nvar _scoring: Object\n"}))
        self.assertEqual(good.violations, [])

    def test_real_game_root_passes_the_keyword_rule(self):
        rule = _rules()["forbidden:game_root_logic_keywords"]
        path = os.path.join(lr.REPO_ROOT, "src", "core", "game_root.gd")
        with open(path, encoding="utf-8") as fh:
            result = lr.evaluate(rule, lr.MemSource({"src/core/game_root.gd": fh.read()}))
        self.assertEqual(result.violations, [])


class ImportBeforeTestsTest(unittest.TestCase):
    def test_import_step_runs_before_every_suite(self):
        calls = []
        runner = run_ci.Runner("all")
        runner.step_import = lambda: calls.append("import") or True
        runner.step_suite = lambda suite: calls.append("suite:" + suite)
        runner.step_python_tests = lambda: None
        runner.step_lint = lambda: None
        runner.run()
        self.assertEqual(calls, ["import", "suite:unit", "suite:integration", "suite:advisory"])

    def test_suites_do_not_run_when_import_fails(self):
        calls = []
        runner = run_ci.Runner("integration")
        runner.step_import = lambda: calls.append("import") or False
        runner.step_suite = lambda suite: calls.append("suite:" + suite)
        runner.run()
        self.assertEqual(calls, ["import"])

    def test_docstring_documents_a_run_without_import_as_invalid(self):
        doc = run_ci.__doc__
        self.assertIn("without step 1 is invalid", doc)
        self.assertIn("class_name", doc)


if __name__ == "__main__":
    unittest.main()
