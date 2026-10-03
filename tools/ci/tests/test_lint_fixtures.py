"""Story TH-007: table-driven fixture checks, string/comment immunity, runner wiring (ADR-0009 Decision 5)."""
import io
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402

TABLE = lr.load_table()
RUN_CI = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "run_ci.py")


def _fixture(rule, name):
    return lr.load_fixture(os.path.join(lr.FIXTURES_DIR, lr.safe_id(rule["id"]), name))


class PerRuleOutcomeTest(unittest.TestCase):
    def test_pass_fixture_has_no_finding_and_fail_fixture_has_this_rule(self):
        for rule in TABLE["rules"]:
            if rule.get("stub"):
                continue
            with self.subTest(rule=rule["id"]):
                p_path, p_text = _fixture(rule, "pass.txt")
                self.assertEqual(lr.evaluate(rule, lr.MemSource({p_path: p_text})).violations, [])
                f_path, f_text = _fixture(rule, "fail.txt")
                res = lr.evaluate(rule, lr.MemSource({f_path: f_text}))
                self.assertTrue(res.violations)
                self.assertEqual({v.rule_id for v in res.violations}, {rule["id"]})
                lines = f_text.count("\n") + 1
                for v in res.violations:
                    self.assertTrue(1 <= v.line <= lines)


class CommentAndStringImmunityTest(unittest.TestCase):
    def _forbid_gd_rules(self):
        for rule in TABLE["rules"]:
            if rule["kind"] != "forbid" or not rule.get("pattern") or rule.get("stub"):
                continue
            if rule.get("pattern_on") == "raw":
                continue  # raw rules scan unstripped text by design (e.g. the lint-ignore-comment rule)
            path, text = _fixture(rule, "fail.txt")
            if path.endswith(".gd"):
                yield rule, path, text

    def test_failing_fixture_turned_into_comments_passes(self):
        count = 0
        for rule, path, text in self._forbid_gd_rules():
            count += 1
            with self.subTest(rule=rule["id"]):
                body = "".join("# " + ln for ln in text.splitlines(True))
                self.assertEqual(lr.evaluate(rule, lr.MemSource({path: body})).violations, [])
        self.assertGreater(count, 0)

    def test_failing_fixture_turned_into_a_string_passes(self):
        count = 0
        triple = "'" * 3
        for rule, path, text in self._forbid_gd_rules():
            if triple in text or rule.get("keep_strings"):
                continue
            count += 1
            with self.subTest(rule=rule["id"]):
                body = "var s = " + triple + "\n" + text.replace("\\", "/") + "\n" + triple + "\n"
                self.assertEqual(lr.evaluate(rule, lr.MemSource({path: body})).violations, [])
        self.assertGreater(count, 0)


class FixtureSelfCheckNamesRuleTest(unittest.TestCase):
    def test_runner_exits_non_zero_and_names_rule_when_a_fixture_is_missing(self):
        rule = TABLE["rules"][0]
        with tempfile.TemporaryDirectory() as tmp:
            fx = os.path.join(tmp, "fx")
            shutil.copytree(lr.FIXTURES_DIR, fx)
            os.remove(os.path.join(fx, lr.safe_id(rule["id"]), "fail.txt"))
            out = io.StringIO()
            code = lr.run(tmp, TABLE, only_rule=rule["id"], out=out, fixtures_dir=fx)
        self.assertEqual(code, 1)
        self.assertIn(rule["id"], out.getvalue())


class RunnerWiringTest(unittest.TestCase):
    def test_run_ci_runs_python_tests_as_step_4a_and_fails_on_nonzero(self):
        with open(RUN_CI, encoding="utf-8") as fh:
            src = fh.read()
        body = src.split("def step_python_tests", 1)[1].split("def step_lint", 1)[0]
        for needle in ("unittest", "discover", "if code != 0", "self.fail("):
            self.assertIn(needle, body)
        self.assertIn("step_python_tests", src.split("def run(self)", 1)[1])

    def test_tools_folder_is_hidden_from_godot_import(self):
        self.assertTrue(os.path.isfile(os.path.join(lr.REPO_ROOT, "tools", ".gdignore")))


if __name__ == "__main__":
    unittest.main()
