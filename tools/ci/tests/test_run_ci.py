"""Unit tests for the pure helpers of run_ci.py (no Godot needed)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import run_ci  # noqa: E402

GOOD = '<testsuites><testsuite name="s" tests="2" failures="0" errors="0"><testcase name="a"/><testcase name="b"/></testsuite></testsuites>'


def _write(tmp, text):
    path = os.path.join(tmp, "r.xml")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return path


class JunitCheckTest(unittest.TestCase):
    def test_good_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(run_ci.check_junit(_write(tmp, GOOD), 2), [])

    def test_missing_report(self):
        self.assertTrue(run_ci.check_junit(os.path.join(tempfile.gettempdir(), "no-such-report.xml"), 1))

    def test_zero_tests(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertTrue(any("zero tests" in p for p in run_ci.check_junit(_write(tmp, "<testsuites/>"), 0)))

    def test_fewer_tests_than_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertTrue(any("skipped or failed to parse" in p for p in run_ci.check_junit(_write(tmp, GOOD), 5)))

    def test_failure_and_skip(self):
        xml = '<testsuites><testsuite tests="2" failures="1"><testcase name="a"><failure/></testcase><testcase name="b"><skipped/></testcase></testsuite></testsuites>'
        with tempfile.TemporaryDirectory() as tmp:
            problems = run_ci.check_junit(_write(tmp, xml), 1)
        self.assertTrue(any("failing" in p for p in problems))
        self.assertTrue(any("skipped" in p for p in problems))

    def test_unreadable(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertTrue(any("unreadable" in p for p in run_ci.check_junit(_write(tmp, "<oops"), 1)))


class OutputScanTest(unittest.TestCase):
    def test_markers(self):
        out = "ok\nSCRIPT ERROR: Parse Error: x\nfine\n  Parse Error: y\n"
        self.assertEqual(len(run_ci.scan_output(out)), 2)
        self.assertEqual(run_ci.scan_output("all good\n"), [])


class GodotResolutionTest(unittest.TestCase):
    def test_missing_binary_is_prerequisite_not_traceback(self):
        with self.assertRaises(run_ci.Prerequisite):
            run_ci.find_godot({}, env={"GODOT": os.path.join(tempfile.gettempdir(), "no-such-godot-binary")})

    def test_expected_version(self):
        self.assertEqual(run_ci.expected_engine_version({"godot": {"version": "4.7.2-stable"}}), "4.7.2")
        self.assertEqual(run_ci.expected_engine_version(run_ci.load_versions()), "4.7.2")

    def test_count_test_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, "a"))
            for name in ("a/x_test.gd", "y_test.gd", "helper.gd"):
                with open(os.path.join(tmp, name), "w") as fh:
                    fh.write("")
            self.assertEqual(run_ci.count_test_files(tmp), 2)


if __name__ == "__main__":
    unittest.main()
