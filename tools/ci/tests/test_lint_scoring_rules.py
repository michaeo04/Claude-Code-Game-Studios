"""Story SPB-010: Scoring lint rules (AC-10, AC-12b, AC-11a typed binding)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402

RULES = {r["id"]: r for r in lr.load_table()["rules"]}
CORE = "src/core/scoring_personal_best/score_core.gd"
MATH = "src/core/scoring_personal_best/score_math.gd"
ROOT = "src/core/game_root.gd"


def scan(rule_id, path, text):
    return lr.evaluate(RULES[rule_id], lr.MemSource({path: text})).violations


class NearMissIdentifierTest(unittest.TestCase):
    R = "forbidden:scoring_no_near_miss_identifiers"

    def test_code_identifiers_fail(self):
        for text in ("func on_near_miss(a: int) -> void:\n", "var d: NearMissDetection\n", "var near_miss_count: int\n"):
            with self.subTest(text=text):
                self.assertEqual(len(scan(self.R, CORE, "extends RefCounted\n" + text)), 1)
                self.assertEqual(len(scan(self.R, MATH, "extends RefCounted\n" + text)), 1)

    def test_comment_string_and_hazard_id_pass(self):
        text = "extends RefCounted\n## Rule 8: near_miss events are never consumed here.\n# NearMiss\nvar s: String = \"near_miss\"\nvar hazard_id: int\n"
        self.assertEqual(scan(self.R, CORE, text), [])


class HazardIdTest(unittest.TestCase):
    R = "forbidden:scoring_hazard_id_unread"

    def test_read_in_body_fails_signature_passes(self):
        sig = "func on_run_ended(_run_id: int, _hazard_id: int, _t: int) -> void:\n"
        self.assertEqual(scan(self.R, CORE, sig + "\t_finalize()\n"), [])
        self.assertEqual(len(scan(self.R, CORE, sig + "\tprint(_hazard_id)\n")), 1)
        self.assertEqual(len(scan(self.R, CORE, sig + "\tprint(hazard_id)\n")), 1)


class DenyListTest(unittest.TestCase):
    R = "forbidden:scoring_core_deny_list"

    def test_each_token_fails(self):
        for tok in ("OS.get_ticks_msec()", "Engine.get_frames_drawn()", "ProjectSettings.get_setting(&'a')",
                    "FileAccess.open('a', 1)", "get_tree()", "get_node('a')"):
            with self.subTest(tok=tok):
                self.assertEqual(len(scan(self.R, CORE, "func a() -> void:\n\t" + tok + "\n")), 1)

    def test_time_vector3_and_comments_pass(self):
        text = "func a() -> void:\n\tvar v: Vector3 = Vector3.ZERO\n\tvar t: int = Time.get_ticks_usec()\n\t# OS.x\n"
        self.assertEqual(scan(self.R, CORE, text), [])


class TypedBindingTest(unittest.TestCase):
    R = "forbidden:composition_root_string_built_callable"

    def test_string_built_fails_direct_reference_passes(self):
        self.assertEqual(len(scan(self.R, ROOT, 'var a: Callable = Callable(save, "get_value")\n')), 1)
        self.assertEqual(len(scan(self.R, ROOT, "var a: Callable = Callable(save, &\"get_value\")\n")), 1)
        self.assertEqual(scan(self.R, ROOT, "var a: Callable = save.get_value\nvar b: Callable = Callable()\n"), [])

    def test_real_composition_root_is_clean(self):
        with open(os.path.join(lr.REPO_ROOT, *ROOT.split("/")), encoding="utf-8") as fh:
            self.assertEqual(scan(self.R, ROOT, fh.read()), [])


if __name__ == "__main__":
    unittest.main()
