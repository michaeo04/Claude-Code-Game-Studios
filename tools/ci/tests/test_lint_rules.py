"""One passing and one failing fixture per rule, plus runner-level behaviour (ADR-0009 Decision 5)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402

TABLE = lr.load_table()


class RuleTableTest(unittest.TestCase):
    def test_table_is_valid(self):
        self.assertEqual(lr.validate_table(TABLE), [])

    def test_every_kind_is_used(self):
        kinds = {r["kind"] for r in TABLE["rules"]}
        self.assertEqual(kinds, set(lr.KINDS))

    def test_required_registered_rules_exist(self):
        ids = {r["id"] for r in TABLE["rules"]}
        for needed in ("forbidden:raw_s_in_vector3", "forbidden:autoload_singletons", "forbidden:extra_sensor_flags",
                       "project_setting:emulate_mouse_from_touch", "project_setting:emulate_touch_from_mouse",
                       "project_setting:quit_on_go_back", "project_setting:handheld_orientation",
                       "project_setting:physics_interpolation", "forbidden:save_io_outside_save_service",
                       "forbidden:map_content_file_io", "forbidden:sensor_reads_outside_tilt_input",
                       "forbidden:global_param_write_outside_render_globals", "manifest:exclude_filter"):
            self.assertIn(needed, ids)
        sev = {r["id"]: r["severity"] for r in TABLE["rules"]}
        self.assertEqual(sev["forbidden:raw_s_in_vector3"], "ADVISORY")


class RuleFixtureTest(unittest.TestCase):
    def test_each_rule_has_passing_and_failing_fixture(self):
        for rule in TABLE["rules"]:
            with self.subTest(rule=rule["id"]):
                self.assertEqual(lr.check_rule_fixtures(rule), [])

    def test_failing_fixture_reports_this_rule_with_line(self):
        for rule in TABLE["rules"]:
            if rule.get("stub"):
                continue
            with self.subTest(rule=rule["id"]):
                vpath, text = lr.load_fixture(os.path.join(lr.FIXTURES_DIR, lr.safe_id(rule["id"]), "fail.txt"))
                res = lr.evaluate(rule, lr.MemSource({vpath: text}))
                self.assertTrue(res.violations)
                for v in res.violations:
                    self.assertEqual(v.rule_id, rule["id"])
                    self.assertEqual(v.severity, rule["severity"])
                    self.assertGreaterEqual(v.line, 1)

    def test_no_fixture_directory_is_orphaned(self):
        known = {lr.safe_id(r["id"]) for r in TABLE["rules"]}
        for name in os.listdir(lr.FIXTURES_DIR):
            if os.path.isdir(os.path.join(lr.FIXTURES_DIR, name)):
                self.assertIn(name, known)

    def test_fixtures_are_txt_files(self):
        for dirpath, _dirs, files in os.walk(lr.FIXTURES_DIR):
            for f in files:
                if f == "expected_lines.json":
                    continue  # data for the stripper line-number test, not a GDScript fixture
                self.assertTrue(f.endswith(".txt"), f"{dirpath}/{f}: invalid GDScript fixtures must be .txt")


class SelfCheckTest(unittest.TestCase):
    RULE = {"id": "forbid:demo", "source": "t", "severity": "BLOCKING", "kind": "forbid", "scope": ["src/**/*.gd"],
            "pattern": r"\bbad\b", "message": "m"}

    def _fixtures(self, tmp, pass_text, fail_text):
        d = os.path.join(tmp, "forbid_demo")
        os.makedirs(d)
        for name, text in (("pass", pass_text), ("fail", fail_text)):
            if text is not None:
                with open(os.path.join(d, name + ".txt"), "w", newline="\n") as fh:
                    fh.write(text)

    def test_ok(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._fixtures(tmp, "#@path: src/a.gd\nvar ok\n", "#@path: src/a.gd\nvar bad\n")
            self.assertEqual(lr.check_rule_fixtures(self.RULE, tmp), [])

    def test_missing_failing_fixture_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._fixtures(tmp, "#@path: src/a.gd\nvar ok\n", None)
            self.assertTrue(any("missing fail" in e for e in lr.check_rule_fixtures(self.RULE, tmp)))

    def test_missing_both_fixtures_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(len(lr.check_rule_fixtures(self.RULE, tmp)), 2)

    def test_failing_fixture_that_does_not_fail_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._fixtures(tmp, "#@path: src/a.gd\nvar ok\n", "#@path: src/a.gd\nvar fine\n")
            self.assertTrue(any("no violation" in e for e in lr.check_rule_fixtures(self.RULE, tmp)))

    def test_passing_fixture_that_violates_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._fixtures(tmp, "#@path: src/a.gd\nvar bad\n", "#@path: src/a.gd\nvar bad\n")
            self.assertTrue(any("passing fixture violates" in e for e in lr.check_rule_fixtures(self.RULE, tmp)))

    def test_out_of_scope_passing_fixture_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._fixtures(tmp, "#@path: docs/a.gd\nvar ok\n", "#@path: src/a.gd\nvar bad\n")
            self.assertTrue(any("out of scope" in e for e in lr.check_rule_fixtures(self.RULE, tmp)))

    def test_fixture_without_path_header_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._fixtures(tmp, "var ok\n", "var bad\n")
            self.assertTrue(any("#@path" in e for e in lr.check_rule_fixtures(self.RULE, tmp)))


class KindBehaviourTest(unittest.TestCase):
    def _rule(self, **kw):
        base = {"id": "r", "source": "t", "severity": "BLOCKING", "message": "m"}
        base.update(kw)
        return base

    def test_banned_token_in_comment_or_string_does_not_trigger(self):
        r = self._rule(kind="forbid", scope=["src/**/*.gd"], pattern=r"\bFileAccess\b")
        res = lr.evaluate(r, lr.MemSource({"src/a.gd": '# FileAccess\nvar s = "FileAccess"\n'}))
        self.assertEqual(res.violations, [])

    def test_empty_scope_passes_with_note(self):
        r = self._rule(kind="forbid", scope=["src/**/*.gd"], pattern="x")
        res = lr.evaluate(r, lr.MemSource({"docs/a.md": "x"}))
        self.assertEqual(res.violations, [])
        self.assertTrue(res.notes)

    def test_only_in_allows_listed_file(self):
        r = self._rule(kind="only_in", scope=["src/**/*.gd"], pattern=r"\bFileAccess\b", allow=["src/**/save_service.gd"])
        src = lr.MemSource({"src/x/save_service.gd": "FileAccess.open()", "src/y/other.gd": "FileAccess.open()"})
        res = lr.evaluate(r, src)
        self.assertEqual([v.path for v in res.violations], ["src/y/other.gd"])

    def test_string_argument_rule_sees_empty_quotes(self):
        r = self._rule(kind="forbid", scope=["src/**/*.gd"], pattern=r"\.connect\s*\(\s*\"\"")
        res = lr.evaluate(r, lr.MemSource({"src/a.gd": 'x.connect("sig", cb)\n'}))
        self.assertEqual(len(res.violations), 1)

    def test_tscn_deferred_flag_bit(self):
        r = next(x for x in TABLE["rules"] if x["id"] == "forbidden:connect_deferred_control_signals_scene")
        for flags, expect in ((1, 1), (2, 0), (3, 1), (0, 0)):
            text = f'[connection signal="hit_reported" from="A" to="B" method="m" flags={flags}]\n'
            res = lr.evaluate(r, lr.MemSource({"x.tscn": text}))
            self.assertEqual(len(res.violations), expect, flags)

    def test_project_godot_absent_passes_with_note(self):
        for r in TABLE["rules"]:
            if r["kind"] in ("project_setting", "manifest"):
                res = lr.evaluate(r, lr.MemSource({}))
                self.assertEqual(res.violations, [], r["id"])
                self.assertTrue(res.notes, r["id"])

    def test_sensor_flag_other_than_gravity_fails(self):
        r = next(x for x in TABLE["rules"] if x["id"] == "forbidden:extra_sensor_flags")
        text = "[input_devices]\nsensors/enable_magnetometer=true\n"
        self.assertEqual(len(lr.evaluate(r, lr.MemSource({"project.godot": text})).violations), 1)

    def test_advisory_does_not_fail_the_run(self):
        table = {"rules": [self._rule(id="forbidden:adv", severity="ADVISORY", kind="forbid", scope=["src/**/*.gd"], pattern="bad")],
                 "review_only": []}
        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, "src"))
            with open(os.path.join(tmp, "src", "a.gd"), "w") as fh:
                fh.write("bad\n")
            out = _Sink()
            orig = lr.self_check
            lr.self_check = lambda rules, fixtures_dir=lr.FIXTURES_DIR: []
            try:
                self.assertEqual(lr.run(tmp, table, out=out), 0)
                table["rules"][0]["severity"] = "BLOCKING"
                self.assertEqual(lr.run(tmp, table, out=out), 1)
            finally:
                lr.self_check = orig
            self.assertIn("src/a.gd:1:", out.text)

    def test_self_check_failure_fails_the_run(self):
        table = {"rules": [self._rule(id="no:fixtures", kind="forbid", scope=["src/**/*.gd"], pattern="x")], "review_only": []}
        with tempfile.TemporaryDirectory() as tmp:
            out = _Sink()
            self.assertEqual(lr.run(tmp, table, out=out), 1)
            self.assertIn("SELF-CHECK FAILED", out.text)


class _Sink:
    def __init__(self):
        self.text = ""

    def write(self, s):
        self.text += s

    def flush(self):
        pass


class RegistryCoverageTest(unittest.TestCase):
    YAML = (
        "other: 1\n\nforbidden_patterns:\n"
        "  - pattern: alpha\n    status: active\n    description: \"x\"\n\n"
        "  - pattern: beta\n    status: active\n"
        "  - pattern: gamma\n    status: retired\n"
        "# comment at column 0\n"
        "  - pattern: delta\n    status: active\n"
        "next_section:\n  - pattern: not_a_forbidden_pattern\n"
    )

    def test_reader(self):
        self.assertEqual(lr.read_registry_forbidden_patterns(self.YAML),
                         [("alpha", "active"), ("beta", "active"), ("gamma", "retired"), ("delta", "active")])

    def test_coverage_reports_uncovered(self):
        table = {"rules": [{"id": "forbidden:alpha"}], "review_only": [{"pattern": "beta", "reason": "r"}]}
        self.assertEqual(lr.registry_coverage(table, self.YAML), ["delta"])

    def test_real_registry_is_fully_covered(self):
        path = os.path.join(lr.REPO_ROOT, lr.REGISTRY_REL)
        if not os.path.isfile(path):
            self.skipTest("registry not present")
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        self.assertTrue(lr.read_registry_forbidden_patterns(text))
        self.assertEqual(lr.registry_coverage(TABLE, text), [])


class GlobTest(unittest.TestCase):
    def test_globs(self):
        self.assertTrue(lr.matches_any("src/a.gd", ["src/**/*.gd"]))
        self.assertTrue(lr.matches_any("src/a/b/c.gd", ["src/**/*.gd"]))
        self.assertFalse(lr.matches_any("src2/a.gd", ["src/**/*.gd"]))
        self.assertFalse(lr.matches_any("src/a.gd.txt", ["src/**/*.gd"]))
        self.assertTrue(lr.matches_any("x/y.tscn", ["**/*.tscn"]))
        self.assertTrue(lr.matches_any("y.tscn", ["**/*.tscn"]))


if __name__ == "__main__":
    unittest.main()
