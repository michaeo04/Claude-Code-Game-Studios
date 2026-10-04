"""Stories PS-009 and PS-010: Platform Services ownership lint (AC-12) and manifest lint (AC-13)."""
import contextlib
import io
import os
import re
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402

RULES = {r["id"]: r for r in lr.load_table()["rules"]}
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OWN = "forbidden:platform_os_calls_outside_platform_services"
SETTINGS = "forbidden:project_settings_outside_platform_services"
PURITY = "forbidden:platform_core_purity"
NODE = "src/core/platform/platform_services.gd"
CORE_FILES = ("src/core/platform/platform_core.gd", "src/core/platform/platform_math.gd",
              "src/core/platform/rate_limited_log.gd")


def scan(rule_id, path, text):
    return lr.evaluate(RULES[rule_id], lr.MemSource({path: text})).violations


class OwnershipTest(unittest.TestCase):
    TOKENS = ["NOTIFICATION_APPLICATION_FOCUS_IN", "NOTIFICATION_APPLICATION_FOCUS_OUT",
              "NOTIFICATION_APPLICATION_PAUSED", "NOTIFICATION_APPLICATION_RESUMED",
              "NOTIFICATION_WM_GO_BACK_REQUEST", "Input.vibrate_handheld(5)",
              "DisplayServer.get_display_safe_area()", "DisplayServer.screen_get_refresh_rate()",
              "DisplayServer.screen_get_size()", "DisplayServer.screen_set_keep_on(true)"]

    def test_each_token_fails_elsewhere_with_file_and_line_and_passes_in_the_node(self):
        for tok in self.TOKENS:
            with self.subTest(token=tok):
                v = scan(OWN, "src/core/x/other.gd", "extends RefCounted\n\nvar a = " + tok + "\n")
                self.assertEqual([(x.path, x.line) for x in v], [("src/core/x/other.gd", 3)])
                self.assertEqual(scan(OWN, NODE, "var a = " + tok + "\n"), [])

    def test_comment_and_string_pass(self):
        text = "# NOTIFICATION_WM_GO_BACK_REQUEST DisplayServer.screen_get_size()\nvar s = \"Input.vibrate_handheld\"\n"
        self.assertEqual(scan(OWN, "src/core/x/other.gd", text), [])

    def test_project_settings_allowlist_is_node_and_tilt_input(self):
        text = "var a = ProjectSettings.get_setting(\"k\")\n"
        self.assertEqual(len(scan(SETTINGS, "src/core/x/other.gd", text)), 1)
        self.assertEqual(scan(SETTINGS, NODE, text), [])
        self.assertEqual(scan(SETTINGS, "src/core/tilt_input/tilt_input.gd", text), [])

    def test_real_sources_pass(self):
        for rid in (OWN, SETTINGS, PURITY):
            with self.subTest(rule=rid):
                self.assertEqual(lr.evaluate(RULES[rid], lr.FsSource(ROOT)).violations, [])


class PurityTest(unittest.TestCase):
    TOKENS = ["extends Node", "var a = Input.get_gravity()", "var a = DisplayServer.get_name()",
              "var a = ProjectSettings.get_setting('k')", "var a = Engine.get_frames_drawn()",
              "var a = Time.get_ticks_usec()", "var a = OS.get_name()", "var a = get_tree()"]

    def test_each_token_fails_in_all_three_files_with_line(self):
        for path in CORE_FILES:
            for tok in self.TOKENS:
                with self.subTest(path=path, token=tok):
                    v = scan(PURITY, path, "\n" + tok + "\n")
                    self.assertEqual([x.line for x in v], [2])

    def test_lookalikes_and_comments_pass(self):
        text = "extends RefCounted\nvar t: Timer\nvar a = Overtime.x()\nvar b = Timeline.x()\nvar c = x_get_tree_y()\n# OS.get_name()\n"
        self.assertEqual(scan(PURITY, CORE_FILES[0], text), [])
        self.assertEqual(scan(PURITY, CORE_FILES[0], "extends Node3D\n"), [])


def parse_manifest_entries():
    """Entries of PlatformSettings.manifest() read from the GDScript source (one place for the data)."""
    with open(os.path.join(ROOT, "src/core/platform/platform_settings.gd"), encoding="utf-8") as fh:
        text = fh.read()
    pattern = r'_entry\("(\w+)", "([\w/]+)", (true|false|\d+), (\w+), (true|false)\)'
    out = []
    for sec, key, exp, owner, runtime in re.findall(pattern, text):
        out.append({"section": sec, "key": key, "expected": exp, "owner": {"OWNER_TILT": "tilt", "OWNER_PLATFORM": "platform"}.get(owner, owner), "runtime": runtime == "true"})
    return out


ENTRIES = parse_manifest_entries()
RUNTIME = [e for e in ENTRIES if e["runtime"]]
PRESET = [e for e in ENTRIES if not e["runtime"]]


def rules_for_key(key, file):
    out = []
    for r in RULES.values():
        if r["kind"] == "project_setting" and r.get("check") == "equals" and r["key"] == key and r["file"] == file:
            out.append(r)
        if r["kind"] == "manifest" and file == "export_presets.cfg" and r["file"] == file:
            for spec in r.get("lines_require", []):
                if spec["line_pattern"] == "^" + key + "=":
                    out.append(r)
    return out


def project_text(overrides=None, drop=None, wrong_section=None):
    lines = {}
    for e in RUNTIME:
        lines[e["key"]] = (e["section"], e["expected"])
    if overrides:
        for k, v in overrides.items():
            lines[k] = (lines[k][0], v)
    if drop:
        lines.pop(drop)
    text = ""
    for key, (sec, val) in lines.items():
        sec = "other" if key == wrong_section else sec
        text += "[%s]\n%s=%s\n" % (sec, key.split("/", 1)[1], val)
    return text


def wrong_value(expected):
    return "false" if expected == "true" else ("true" if expected == "false" else str(int(expected) + 7))


class ManifestLintTest(unittest.TestCase):
    def test_entries_parsed(self):
        self.assertGreaterEqual(len(RUNTIME), 6)
        self.assertEqual(len(PRESET), 3)

    def violations_for(self, e, text, file):
        found = []
        for r in rules_for_key(e["key"], file):
            found.extend(lr.evaluate(r, lr.MemSource({file: text})).violations)
        return found

    def test_every_runtime_entry_has_a_rule_and_valid_file_passes(self):
        for e in RUNTIME:
            with self.subTest(key=e["key"]):
                self.assertTrue(rules_for_key(e["key"], "project.godot"), "no lint rule for the entry")
                self.assertEqual(self.violations_for(e, project_text(), "project.godot"), [])

    def test_each_entry_missing_and_wrong_fails_with_key_and_file(self):
        for e in RUNTIME:
            with self.subTest(key=e["key"], case="missing"):
                v = self.violations_for(e, project_text(drop=e["key"]), "project.godot")
                if not all(r.get("required", True) for r in rules_for_key(e["key"], "project.godot")):
                    continue  # emulate_mouse_from_touch stays optional (registered ADR-0005 rule, gap noted in the story)
                self.assertTrue(v)
                self.assertEqual(v[0].path, "project.godot")
                self.assertIn(e["key"], v[0].message)
            with self.subTest(key=e["key"], case="wrong"):
                v = self.violations_for(e, project_text(overrides={e["key"]: wrong_value(e["expected"])}), "project.godot")
                self.assertTrue(v)
                self.assertIn(e["key"], v[0].message)

    def test_right_key_in_the_wrong_section_fails(self):
        for e in RUNTIME:
            with self.subTest(key=e["key"]):
                if not all(r.get("required", True) for r in rules_for_key(e["key"], "project.godot")):
                    continue  # optional registered rule (emulate_mouse_from_touch)
                self.assertTrue(self.violations_for(e, project_text(wrong_section=e["key"]), "project.godot"))

    def test_preset_entries_missing_and_wrong_fail_and_valid_passes(self):
        for e in PRESET:
            key = e["key"]
            with self.subTest(key=key):
                self.assertTrue(rules_for_key(key, "export_presets.cfg"))
                self.assertEqual(self.violations_for(e, "%s=%s\n" % (key, e["expected"]), "export_presets.cfg"), [])
                self.assertTrue(self.violations_for(e, "%s=%s\n" % (key, wrong_value(e["expected"])), "export_presets.cfg"))
                self.assertTrue(self.violations_for(e, "other/key=1\n", "export_presets.cfg"))

    def test_tilt_entries_are_tagged_and_present(self):
        tilt = {e["key"] for e in ENTRIES if e["owner"] == "tilt"}
        self.assertIn("input_devices/sensors/enable_gravity", tilt)
        self.assertIn("display/window/handheld/orientation", tilt)

    def test_real_project_godot_passes_every_runtime_rule(self):
        src = lr.FsSource(ROOT)
        for e in RUNTIME:
            for r in rules_for_key(e["key"], "project.godot"):
                with self.subTest(rule=r["id"]):
                    self.assertEqual(lr.evaluate(r, src).violations, [])

    def test_no_preset_skips_with_loud_warning_and_android_export_fails(self):
        r = RULES["manifest:preset_vibrate"]
        res = lr.evaluate(r, lr.MemSource({}))
        self.assertEqual(res.violations, [])
        self.assertTrue(any("WARNING" in n for n in res.notes))
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = lr.main(["--rule", "manifest:preset_vibrate", "--android-export", "--root", ROOT])
        if not os.path.exists(os.path.join(ROOT, "export_presets.cfg")):
            self.assertEqual(code, 1)
            self.assertIn("export_presets.cfg:1", out.getvalue())


if __name__ == "__main__":
    unittest.main()
