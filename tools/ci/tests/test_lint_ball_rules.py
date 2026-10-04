"""Story BM-009: lint rules over BallCore, BallConfig and BallMath (AC-25, AC-27 static part)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402

RULES = {r["id"]: r for r in lr.load_table()["rules"]}
CORE = "src/core/ball_movement/ball_core.gd"
MATH = "src/core/ball_movement/ball_math.gd"
CONFIG = "src/core/ball_movement/ball_config.gd"
VIEW = "src/presentation/ball/ball_view.gd"
PURITY = "forbidden:ball_core_purity"


def scan(rule_id, path, text):
    return lr.evaluate(RULES[rule_id], lr.MemSource({path: text})).violations


class PurityTest(unittest.TestCase):
    TOKENS = ["var a: Node", "var a: Node3D", "var a: CollisionObject3D", "var a: CharacterBody3D", "var a: Area3D",
              "var a: RayCast3D", "var a: ShapeCast3D", "var a: PhysicsServer3D", "hit_reported.emit()",
              "request_restart()", "var a: RunState", "var a: TiltInput", "var a: TubeWindow",
              "Input.is_action_pressed(&'a')", "Engine.get_frames_drawn()", "Time.get_ticks_usec()", "OS.get_name()",
              "DisplayServer.get_name()", "get_tree()", "get_process_delta_time()", "get_physics_process_delta_time()",
              "func _process(d):", "func _physics_process(d):", "randi()", "randf()", "randomize()",
              "var a: RandomNumberGenerator"]

    def test_each_forbidden_token_fails_with_file_and_line(self):
        for tok in self.TOKENS:
            with self.subTest(token=tok):
                v = scan(PURITY, CORE, "extends RefCounted\n\n" + tok + "\n")
                self.assertEqual([x.line for x in v], [3])
                self.assertEqual(v[0].path, CORE)

    def test_token_in_comment_or_string_passes(self):
        text = "extends RefCounted\n# Node get_tree() Input.x\nvar s: String = \"Time.now randf()\"\n"
        self.assertEqual(scan(PURITY, CORE, text), [])

    def test_substring_of_another_identifier_passes(self):
        text = "extends RefCounted\nvar p: NodePath\nvar n: StringName\nvar t: Timeline\nvar o: OSC\n"
        self.assertEqual(scan(PURITY, CORE, text), [])

    def test_crlf_and_lf_report_same_line(self):
        lf = "extends RefCounted\n\nvar a: Node\n"
        self.assertEqual([x.line for x in scan(PURITY, CORE, lf)], [3])
        self.assertEqual([x.line for x in scan(PURITY, CORE, lf.replace("\n", "\r\n"))], [3])

    def test_wrap_angle_is_not_a_tube_reference(self):
        self.assertEqual(scan(PURITY, CORE, "var a: float = BallMath.wrap_angle(1.0)\n"), [])

    def test_base_classes(self):
        self.assertTrue(scan("forbidden:ball_core_base_class", CORE, "extends Node\n"))
        self.assertTrue(scan("forbidden:ball_core_base_class", MATH, "extends Resource\n"))
        self.assertEqual(scan("forbidden:ball_core_base_class", CORE, "extends RefCounted\n"), [])
        self.assertTrue(scan("forbidden:ball_config_base_class", CONFIG, "extends RefCounted\n"))
        self.assertEqual(scan("forbidden:ball_config_base_class", CONFIG, "extends Resource\n"), [])


class BallMathTest(unittest.TestCase):
    RULE = "forbidden:ball_math_statics_only"

    def test_each_construct_fails(self):
        for text in ("x = wrapf(a, -PI, PI)\n", "const A = [1]\n", "const A: Array = [1]\n",
                     "const D: Dictionary = {}\n", "TABLE[0] = 1\n"):
            with self.subTest(text=text):
                self.assertEqual(len(scan(self.RULE, MATH, "extends RefCounted\n" + text)), 1)

    def test_scalar_const_and_comment_pass(self):
        text = "extends RefCounted\nconst PI_HALF: float = PI / 2.0\n# wrapf( here\nconst N: int = 3\n"
        self.assertEqual(scan(self.RULE, MATH, text), [])

    def test_indented_subscript_assignment_passes(self):
        self.assertEqual(scan(self.RULE, MATH, "func f():\n\tlocal[0] = 1\n"), [])

    def test_other_ball_files_are_out_of_scope(self):
        self.assertEqual(scan(self.RULE, CORE, "const A = [1]\n"), [])


class PositionZTest(unittest.TestCase):
    def test_position_z_forms_fail(self):
        for form in ("position.z = 1.0", "global_position.z = 1.0", "global_transform.origin = Vector3.ZERO"):
            with self.subTest(form=form):
                self.assertEqual(len(scan("forbidden:ball_view_position_z", VIEW, "func f():\n\t" + form + "\n")), 1)

    def test_position_xy_passes(self):
        self.assertEqual(scan("forbidden:ball_view_position_z", VIEW, "func f():\n\tposition.x = 1.0\n"), [])


class ResetBodyTest(unittest.TestCase):
    RULE = "custom:ball_core_reset_body"

    def test_loop_new_and_load_in_reset_fail(self):
        for stmt in ("for i in 3:\n\t\tpass", "while true:\n\t\tpass", "var c := Foo.new()", "var r := load('x')"):
            with self.subTest(stmt=stmt):
                text = "extends RefCounted\n\nfunc reset() -> void:\n\t_a = 0.0\n\t" + stmt + "\n"
                self.assertTrue(scan(self.RULE, CORE, text))

    def test_loop_in_another_function_passes(self):
        text = ("extends RefCounted\n\nfunc other() -> void:\n\tfor i in 3:\n\t\tpass\n\nfunc reset() -> void:\n\t_a = 0.0\n\n"
                "func later() -> void:\n\twhile false:\n\t\tpass\n")
        self.assertEqual(scan(self.RULE, CORE, text), [])

    def test_preload_is_not_load(self):
        text = "extends RefCounted\n\nfunc reset() -> void:\n\tvar x: Script = preload('res://a.gd')\n"
        self.assertEqual(scan(self.RULE, CORE, text), [])

    def test_violation_line_is_the_offending_line(self):
        text = "extends RefCounted\n\nfunc reset() -> void:\n\t_a = 0.0\n\tfor i in 3:\n\t\tpass\n"
        self.assertEqual([v.line for v in scan(self.RULE, CORE, text)], [5])


class RealSourcesTest(unittest.TestCase):
    def test_real_ball_sources_pass_every_ball_rule(self):
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
        src = lr.FsSource(root)
        for rid in RULES:
            if rid.startswith(("forbidden:ball_", "custom:ball_")):
                with self.subTest(rule=rid):
                    self.assertEqual(lr.evaluate(RULES[rid], src).violations, [])


if __name__ == "__main__":
    unittest.main()
