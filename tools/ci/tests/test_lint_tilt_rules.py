"""Story TI-001: Tilt Input CI lint gate (AC-37a to AC-37f, ADR-0005 Decision 7)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402

RULES = {r["id"]: r for r in lr.load_table()["rules"]}
NODE = "src/core/tilt_input/tilt_input.gd"
CORE = "src/core/tilt_input/tilt_core.gd"
MATH = "src/core/tilt_input/tilt_math.gd"
OTHER = "src/core/other/foo.gd"
SENSOR = "forbidden:tilt_sensor_pattern_outside_tilt_input"
CALL = "forbidden:tilt_input_call_or_singleton"
PURITY = "forbidden:tilt_core_math_purity"
POINTER = "forbidden:tilt_pointer_input_events"
UNVAL = "forbidden:tilt_config_unvalidated_in_src"
POLL = "forbidden:tilt_core_poll_outside_driver"
PHYS = "forbidden:tilt_driver_physics_process"
EDITOR = "forbidden:tilt_synthetic_source_outside_editor_gate"


def scan(rule_id, path, text):
    return lr.evaluate(RULES[rule_id], lr.MemSource({path: text})).violations


def lines(rule_id, path, text):
    return [v.line for v in scan(rule_id, path, text)]


class SensorRuleTest(unittest.TestCase):
    def test_every_sensor_call_fails_outside_the_node_file_with_line(self):
        for call in ("get_gravity()", "get_accelerometer()", "get_gyroscope()", "get_magnetometer()",
                     "get_joy_gravity(0)", "get_joy_gyroscope(0)", "get_joy_accelerometer(0)", "set_gravity(v)"):
            with self.subTest(call=call):
                self.assertEqual(lines(SENSOR, OTHER, "extends Node\n\nInput.%s\n" % call), [3])

    def test_the_same_call_passes_in_the_node_file(self):
        self.assertEqual(scan(SENSOR, NODE, "extends Node\nvar g = Input.get_gravity()\n"), [])

    def test_comment_string_and_triple_quoted_string_pass(self):
        text = 'extends Node\n# Input.get_gravity()\nvar a = "Input.get_gyroscope()"\nvar b = """\nInput.set_gravity(x)\n"""\n'
        self.assertEqual(scan(SENSOR, OTHER, text), [])

    def test_crlf_reports_the_same_line(self):
        text = "extends Node\r\n\r\nInput.get_gravity()\r\n"
        self.assertEqual(lines(SENSOR, OTHER, text), [3])

    def test_reflective_call_and_singleton_fail_in_the_tilt_files(self):
        self.assertEqual(lines(CALL, NODE, "extends Node\nInput.call(&\"x\")\n"), [2])
        self.assertEqual(lines(CALL, CORE, "extends RefCounted\n\nvar s = Engine.get_singleton(&\"Input\")\n"), [3])
        self.assertEqual(scan(CALL, NODE, "extends Node\n# Input.call(\n"), [])


class PurityRuleTest(unittest.TestCase):
    def test_banned_singletons_fail_in_core_and_math(self):
        for tok in ("Input.get_gravity()", "Engine.get_frames_drawn()", "Time.get_ticks_usec()", "OS.get_name()"):
            for path in (CORE, MATH):
                with self.subTest(token=tok, path=path):
                    self.assertEqual(lines(PURITY, path, "extends RefCounted\n\n%s\n" % tok), [3])

    def test_extending_node_fails(self):
        self.assertEqual(lines(PURITY, CORE, "extends Node\n"), [1])
        self.assertEqual(lines(PURITY, MATH, "extends Node3D\n"), [1])

    def test_ref_counted_and_lookalikes_pass(self):
        self.assertEqual(scan(PURITY, CORE, "extends RefCounted\nvar t: Timeline\nvar o: OSC\nvar n: NodePath\n"), [])

    def test_node_file_is_out_of_scope(self):
        self.assertEqual(scan(PURITY, NODE, "extends Node\nvar g = Input.get_gravity()\n"), [])


class PointerRuleTest(unittest.TestCase):
    def test_each_token_fails(self):
        for tok in ("var e: InputEventScreenTouch", "var e: InputEventScreenDrag", "var e: InputEventMouseButton",
                    "var e: InputEventMouseMotion", "func _input(e):", "func _unhandled_input(e):",
                    "var p = Input.is_mouse_button_pressed(1)"):
            with self.subTest(token=tok):
                self.assertEqual(lines(POINTER, NODE, "extends Node\n\n%s\n" % tok), [3])

    def test_comment_and_string_pass_and_other_files_are_out_of_scope(self):
        self.assertEqual(scan(POINTER, NODE, "extends Node\n# _input(\nvar s = \"InputEventMouse\"\n"), [])
        self.assertEqual(scan(POINTER, OTHER, "func _input(e):\n\tpass\n"), [])


class UnvalidatedAndPollRuleTest(unittest.TestCase):
    def test_unvalidated_call_in_src_fails_and_definition_passes(self):
        self.assertEqual(lines(UNVAL, OTHER, "extends Node\n\nvar c = cfg.unvalidated()\n"), [3])
        self.assertEqual(lines(UNVAL, OTHER, "extends Node\nvar c = TiltConfig.unvalidated()\n"), [2])
        self.assertEqual(scan(UNVAL, "src/core/tilt_input/tilt_config.gd", "func unvalidated() -> TiltConfig:\n\treturn duplicate()\n"), [])

    def test_unvalidated_in_tests_is_out_of_scope(self):
        self.assertEqual(scan(UNVAL, "tests/unit/tilt_input/x_test.gd", "var c = cfg.unvalidated()\n"), [])

    def test_core_poll_only_in_the_driver_file(self):
        self.assertEqual(lines(POLL, OTHER, "extends Node\n\n_tilt_core.poll()\n"), [3])
        self.assertEqual(scan(POLL, NODE, "func poll() -> void:\n\t_core.poll()\n"), [])
        self.assertEqual(scan(POLL, OTHER, "_tilt.poll()\n"), [])

    def test_driver_has_no_physics_process(self):
        self.assertEqual(lines(PHYS, NODE, "extends Node\nfunc _physics_process(d: float) -> void:\n\t_core.poll()\n"), [2])
        self.assertEqual(scan(PHYS, NODE, "extends Node\n# _physics_process\n"), [])


class EditorGateAndActionsTest(unittest.TestCase):
    def test_only_editor_feature_gate_is_allowed(self):
        self.assertEqual(scan(EDITOR, NODE, "var e: bool = OS.has_feature(\"editor\")\n"), [])
        self.assertEqual(lines(EDITOR, NODE, "extends Node\nvar e: bool = OS.has_feature(\"debug\")\n"), [2])
        self.assertEqual(lines(EDITOR, NODE, "extends Node\nvar e: bool = OS.is_debug_build()\n"), [2])

    def test_actions_present_pass_and_missing_fail(self):
        good = "[input]\n\nsteer_left={\n\"deadzone\": 0.5,\n\"events\": []\n}\nsteer_right={\n\"events\": []\n}\n"
        for name in ("steer_left", "steer_right"):
            rid = "project_setting:action_" + name
            self.assertEqual(lr.evaluate(RULES[rid], lr.MemSource({"project.godot": good})).violations, [])
            bad = good.replace(name + "=", "other_" + name + "=")
            v = lr.evaluate(RULES[rid], lr.MemSource({"project.godot": bad})).violations
            self.assertEqual(len(v), 1)

    def test_real_project_defines_the_actions(self):
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
        for name in ("steer_left", "steer_right"):
            res = lr.evaluate(RULES["project_setting:action_" + name], lr.FsSource(root))
            self.assertEqual(res.violations, [])

    def test_all_new_rules_are_blocking(self):
        for rid in (SENSOR, CALL, PURITY, POINTER, UNVAL, POLL, PHYS, EDITOR,
                    "project_setting:action_steer_left", "project_setting:action_steer_right"):
            self.assertEqual(RULES[rid]["severity"], "BLOCKING")

    def test_rule_with_no_file_in_scope_passes_with_a_note(self):
        res = lr.evaluate(RULES[POINTER], lr.MemSource({OTHER: "x\n"}))
        self.assertEqual(res.violations, [])
        self.assertTrue(res.notes)


if __name__ == "__main__":
    unittest.main()
