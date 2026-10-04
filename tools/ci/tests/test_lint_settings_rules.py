"""Story SA-009: architecture and coupling lint for SettingsCore and SettingsMath (AC-18)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402

RULES = {r["id"]: r for r in lr.load_table()["rules"]}
CORE = "src/core/settings/settings_core.gd"
MATH = "src/core/settings/settings_math.gd"
PURITY = "forbidden:settings_core_purity"
COUPLING = "forbidden:settings_core_coupling"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def scan(rule_id, path, text):
    return lr.evaluate(RULES[rule_id], lr.MemSource({path: text})).violations


class PurityTest(unittest.TestCase):
    TOKENS = ["var a: ConfigFile", "var a: FileAccess", "DirAccess.open('x')", "Input.get_accelerometer()",
              "DisplayServer.get_name()", "Engine.get_frames_drawn()", "Time.get_ticks_usec()", "OS.get_name()",
              "get_tree()"]

    def test_each_token_fails_in_both_files_with_file_and_line(self):
        for path in (CORE, MATH):
            for tok in self.TOKENS:
                with self.subTest(path=path, token=tok):
                    v = scan(PURITY, path, "extends RefCounted\n\n" + tok + "\n")
                    self.assertEqual([x.line for x in v], [3])
                    self.assertEqual(v[0].rule_id, PURITY)
                    self.assertEqual(v[0].path, path)

    def test_comment_and_string_pass(self):
        text = "extends RefCounted\n# OS.get_name() ConfigFile\nvar s: String = \"Time.now Input.x\"\n"
        self.assertEqual(scan(PURITY, CORE, text), [])

    def test_time_does_not_match_timer_or_prefixed_names(self):
        text = "extends RefCounted\nvar t: Timer\nvar x := SomeTime.now()\nvar y := Overtime.x\nvar z := Timeline.go()\n"
        self.assertEqual(scan(PURITY, CORE, text), [])

    def test_crlf_reports_the_same_line(self):
        text = "extends RefCounted\r\n\r\nvar a: ConfigFile\r\n"
        self.assertEqual([v.line for v in scan(PURITY, CORE, text)], [3])


class CouplingTest(unittest.TestCase):
    def test_each_symbol_fails(self):
        for sym in ("PlatformServices", "PlatformCore", "TiltInput", "TiltCore", "TubeTrack", "TubeWindow", "TubeMath"):
            with self.subTest(symbol=sym):
                v = scan(COUPLING, CORE, "extends RefCounted\nvar a: " + sym + "\n")
                self.assertEqual([x.line for x in v], [2])

    def test_opaque_key_strings_and_tilt_words_pass(self):
        text = ("extends RefCounted\nconst KEY: String = \"tilt/sensitivity\"\nvar tilt_sensitivity: float = 1.0\n"
                "# TiltInput PlatformServices TubeTrack\n")
        self.assertEqual(scan(COUPLING, MATH, text), [])


class RealSourcesTest(unittest.TestCase):
    def test_real_settings_sources_pass(self):
        src = lr.FsSource(ROOT)
        for rid in (PURITY, COUPLING):
            with self.subTest(rule=rid):
                res = lr.evaluate(RULES[rid], src)
                self.assertEqual(res.violations, [])
                self.assertFalse(any("no file in scope" in n for n in res.notes))

    def test_no_autoload_rule_is_in_force_and_project_has_no_settings_autoload(self):
        self.assertEqual(RULES["forbidden:autoload_singletons"]["severity"], "BLOCKING")
        with open(os.path.join(ROOT, "project.godot"), encoding="utf-8") as fh:
            text = fh.read()
        for line in text.split("[autoload]", 1)[1:]:
            body = line.split("\n[", 1)[0]
            self.assertNotIn("SettingsCore", body)
            self.assertNotIn("SettingsMath", body)


if __name__ == "__main__":
    unittest.main()
