"""Story TH-008: registry coverage meta-rule (ADR-0009 Decision 5)."""
import io
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402

YAML = ("forbidden_patterns:\n  - pattern: alpha\n    status: active\n"
        "  - pattern: beta\n    status: active\n  - pattern: gamma\n    status: active\n")


def _rule(rule_id):
    return {"id": rule_id, "source": "t", "severity": "BLOCKING", "kind": "forbid", "message": "m",
            "scope": ["src/**/*.gd"], "pattern": "zzz_never"}


def _table(rule_ids=(), review=()):
    return {"rules": [_rule(i) for i in rule_ids],
            "review_only": [{"pattern": p, "reason": "r"} for p in review]}


def _root(tmp, data):
    path = os.path.join(tmp, *lr.REGISTRY_REL.split("/"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(data)


def _run(tmp, table):
    out = io.StringIO()
    code = lr.run(tmp, table, out=out, fixtures_dir=os.path.join(tmp, "nofx"))
    return code, out.getvalue()


class RunnerReportTest(unittest.TestCase):
    def test_unenforced_entries_are_listed_and_do_not_change_the_exit_code(self):
        with tempfile.TemporaryDirectory() as tmp:
            _root(tmp, YAML.encode())
            code, out = _run(tmp, _table(["forbidden:alpha"], ["beta"]))
            self.assertIn("'gamma'", out)
            self.assertNotIn("'alpha'", out)
            self.assertNotIn("'beta'", out)
            self.assertIn("[ADVISORY] registry:coverage", out)
            code_covered, out2 = _run(tmp, _table(["forbidden:alpha", "forbidden:gamma"], ["beta"]))
            self.assertEqual(code, code_covered)
            self.assertNotIn("'gamma'", out2)

    def test_adding_a_rule_or_review_only_mark_removes_the_entry(self):
        t = _table(["forbidden:alpha"])
        self.assertEqual(lr.registry_coverage(t, YAML), ["beta", "gamma"])
        t["review_only"].append({"pattern": "beta", "reason": "r"})
        self.assertEqual(lr.registry_coverage(t, YAML), ["gamma"])
        t["rules"].append(_rule("forbidden:gamma"))
        self.assertEqual(lr.registry_coverage(t, YAML), [])

    def test_crlf_registry_is_parsed(self):
        self.assertEqual(lr.registry_coverage(_table(), YAML.replace("\n", "\r\n")), ["alpha", "beta", "gamma"])


class MissingOrMalformedRegistryTest(unittest.TestCase):
    def test_absent_registry_warns_without_crash(self):
        with tempfile.TemporaryDirectory() as tmp:
            rows, warning = lr.load_registry_rows(tmp, _table())
            self.assertEqual(rows, [])
            self.assertIn("not found", warning)
            _code, out = _run(tmp, _table())
            self.assertIn("warning: registry:coverage", out)

    def test_garbage_registry_warns_without_crash(self):
        for blob in (b"\x00\xff\xfe garbage {{{", b"", b"forbidden_patterns:\n  - nonsense\n", b"just: text\n"):
            with self.subTest(blob=blob[:12]), tempfile.TemporaryDirectory() as tmp:
                _root(tmp, blob)
                rows, warning = lr.load_registry_rows(tmp, _table())
                self.assertEqual(rows, [])
                self.assertIsNotNone(warning)
                _code, out = _run(tmp, _table())
                self.assertIn("warning: registry:coverage", out)


class CoverageOptionTest(unittest.TestCase):
    def test_coverage_table_lists_each_pattern_once_and_exits_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            _root(tmp, YAML.encode())
            out = io.StringIO()
            code = lr.print_coverage(tmp, _table(["forbidden:alpha"], ["beta"]), out)
            text = out.getvalue()
            self.assertEqual(code, 0)
            for p, cov in (("alpha", "rule"), ("beta", "review_only"), ("gamma", "MISSING")):
                self.assertEqual(text.count(p + "\tactive\t" + cov), 1)
            self.assertIn("1 unenforced", text)


class RealRegistryTest(unittest.TestCase):
    def test_real_registry_has_no_untriaged_entry(self):
        path = os.path.join(lr.REPO_ROOT, lr.REGISTRY_REL)
        self.assertTrue(os.path.isfile(path), "registry must exist for the Validation Criterion")
        rows, warning = lr.load_registry_rows(lr.REPO_ROOT, lr.load_table())
        self.assertIsNone(warning)
        self.assertTrue(rows)
        self.assertEqual([r for r in rows if r[2] == "MISSING"], [])


if __name__ == "__main__":
    unittest.main()
