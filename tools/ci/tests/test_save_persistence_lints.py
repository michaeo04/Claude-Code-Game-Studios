"""Story SP-010: architecture and coupling lints for Save & Persistence (AC-16, AC-17)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402

RULES = {r["id"]: r for r in lr.load_table()["rules"]}
CORE = "src/core/persistence/save_core.gd"
MATH = "src/core/persistence/persist_math.gd"
FS = "src/core/persistence/save_fs.gd"
SERVICE = "src/core/persistence/save_service.gd"
PURITY = "forbidden:save_core_purity"
IO = "forbidden:save_io_outside_save_service"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def scan(rule_id, files):
    return lr.evaluate(RULES[rule_id], lr.MemSource(files)).violations


class PurityTest(unittest.TestCase):
    TOKENS = ["var a: ConfigFile", "var a: FileAccess", "DirAccess.open('x')", "Input.get_accelerometer()",
              "DisplayServer.get_name()", "Engine.get_frames_drawn()", "Time.get_unix_time_from_system()",
              "OS.get_name()", "get_tree()", "var theta: float", "var phase: int", "var r: RunState"]

    def test_each_token_fails_in_all_three_files_with_file_and_line(self):
        for path in (CORE, MATH, FS):
            for tok in self.TOKENS:
                with self.subTest(path=path, token=tok):
                    v = scan(PURITY, {path: "extends RefCounted\n\n" + tok + "\n"})
                    self.assertEqual([x.line for x in v], [3])
                    self.assertEqual(v[0].rule_id, PURITY)
                    self.assertEqual(v[0].path, path)

    def test_comment_and_string_pass(self):
        text = "extends RefCounted\n# Time.now ConfigFile theta\nvar s: String = \"OS.x RunState phase\"\n"
        self.assertEqual(scan(PURITY, {CORE: text}), [])

    def test_save_service_is_out_of_scope(self):
        self.assertEqual(scan(PURITY, {SERVICE: "var c: ConfigFile\n"}), [])

    def test_real_sources_pass_with_files_in_scope(self):
        res = lr.evaluate(RULES[PURITY], lr.FsSource(ROOT))
        self.assertEqual(res.violations, [])
        self.assertFalse(any("no file in scope" in n for n in res.notes))

    def test_no_autoload_entry_for_save_classes(self):
        self.assertEqual(RULES["forbidden:autoload_singletons"]["severity"], "BLOCKING")
        with open(os.path.join(ROOT, "project.godot"), encoding="utf-8") as fh:
            text = fh.read()
        for chunk in text.split("[autoload]", 1)[1:]:
            body = chunk.split("\n[", 1)[0]
            for name in ("SaveCore", "PersistMath", "SaveFs", "SaveService"):
                self.assertNotIn(name, body)


class IoOnlyInSaveServiceTest(unittest.TestCase):
    def test_other_file_using_fileaccess_fails(self):
        v = scan(IO, {"src/sub/x.gd": "var f := FileAccess.open(p, FileAccess.READ)\n"})
        self.assertEqual({x.line for x in v}, {1})
        self.assertEqual(v[0].path, "src/sub/x.gd")

    def test_only_save_service_passes(self):
        self.assertEqual(scan(IO, {SERVICE: "var f := FileAccess.open(p, FileAccess.READ)\n"}), [])

    def test_allow_list_is_exact_path_for_file_name(self):
        v = scan(IO, {"src/core/persistence/not_save_service.gd": "var c := ConfigFile.new()\n"})
        self.assertEqual(len(v), 1)

    def test_real_sources_confirmed_both_ways(self):
        src = lr.FsSource(ROOT)
        self.assertEqual(lr.evaluate(RULES[IO], src).violations, [])
        with open(os.path.join(ROOT, *SERVICE.split("/")), encoding="utf-8") as fh:
            body = fh.read()
        for word in ("ConfigFile", "FileAccess", "DirAccess"):
            self.assertIn(word, body)


if __name__ == "__main__":
    unittest.main()
