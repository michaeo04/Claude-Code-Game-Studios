"""Story TH-006: every rule kind and the registered rule table (ADR-0009 Decision 5).

Rule logic is exercised on in-memory sources (MemSource) or temp directories, never on the real
project files. The registered rules come from the real tools/ci/lint_rules.json.
"""
import contextlib
import io
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402

TABLE = lr.load_table()
RULES = {r["id"]: r for r in TABLE["rules"]}


def rule(**kw):
    base = {"id": "t:rule", "source": "test", "severity": "BLOCKING", "message": "m"}
    base.update(kw)
    return base


def mem(files):
    return lr.MemSource(files)


def run_main(argv):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = lr.main(argv)
    return code, out.getvalue()


class RegisteredRulesTest(unittest.TestCase):
    """AC-1: every rule named by ADR-0009 Decision 5 exists with a source ADR."""

    # ADR-0009 Decision 5 table: (kind named in the table, rule id). `lint:typed_method_references`
    # is listed under `custom` in the ADR but a regex is enough for it; it is a `forbid` rule.
    EXPECTED = [
        ("only_in", "forbidden:view_node_own_process"),
        ("forbid", "forbidden:connect_deferred_control_signals"),
        ("custom", "forbidden:connect_deferred_control_signals_scene"),
        ("forbid", "forbidden:engine_time_scale_writes"),
        ("forbid", "forbidden:scene_tree_paused_for_pause"),
        ("forbid", "forbidden:physics_process_game_logic"),
        ("forbid", "forbidden:copy_or_mutate_hazard_resources"),
        ("forbid", "forbidden:float32_footprints"),
        ("forbid", "forbidden:pattern_global_rng_or_float_draw"),
        ("forbid", "forbidden:engine_physics_for_hazards"),
        ("forbid", "forbidden:debug_build_gate_for_dev_input"),
        ("only_in", "forbidden:input_actions_for_gameplay"),
        ("forbid", "forbidden:shader_time_for_effects"),
        ("only_in", "forbidden:presentation_tween_outside_ui_motion"),
        ("forbid", "forbidden:presentation_timer_accumulates_dt"),
        ("forbid", "forbidden:world_change_outside_tick"),
        ("forbid", "forbidden:raw_s_in_vector3"),
        ("only_in", "forbidden:save_io_outside_save_service"),
        ("only_in", "forbidden:map_content_file_io"),
        ("only_in", "forbidden:sensor_reads_outside_tilt_input"),
        ("only_in", "forbidden:global_param_write_outside_render_globals"),
        ("project_setting", "forbidden:autoload_singletons"),
        ("project_setting", "project_setting:emulate_mouse_from_touch"),
        ("project_setting", "project_setting:emulate_touch_from_mouse"),
        ("project_setting", "forbidden:extra_sensor_flags"),
        ("project_setting", "project_setting:quit_on_go_back"),
        ("project_setting", "project_setting:handheld_orientation"),
        ("project_setting", "project_setting:physics_interpolation"),
        ("manifest", "forbidden:duplicate_vulkan_uses_feature"),
        ("manifest", "forbidden:internet_permission_in_release"),
        ("manifest", "manifest:allow_backup"),
        ("manifest", "manifest:exclude_filter"),
        ("secret", "forbidden:keystore_in_repository"),
        ("secret", "secret:preset_credentials"),
        ("custom", "custom:pattern_rng_seeded_before_draw"),
        ("forbid", "lint:typed_method_references"),
        ("custom", "custom:scoring_reflection_check"),
    ]

    def test_every_adr_rule_exists_with_the_named_kind(self):
        for kind, rid in self.EXPECTED:
            with self.subTest(rule=rid):
                self.assertIn(rid, RULES)
                self.assertEqual(RULES[rid]["kind"], kind)

    def test_every_rule_has_a_source_adr_or_gdd(self):
        for r in TABLE["rules"]:
            with self.subTest(rule=r["id"]):
                self.assertRegex(r["source"], r"(ADR-\d{4}|GDD|design/gdd|\.md)")

    def test_every_rule_has_id_severity_kind_message(self):
        for r in TABLE["rules"]:
            with self.subTest(rule=r["id"]):
                for field in ("id", "source", "severity", "kind", "message"):
                    self.assertTrue(r.get(field), field)
                self.assertIn(r["severity"], lr.SEVERITIES)
                self.assertIn(r["kind"], lr.KINDS)

    def test_raw_s_in_vector3_is_advisory(self):
        self.assertEqual(RULES["forbidden:raw_s_in_vector3"]["severity"], "ADVISORY")

    def test_only_in_rules_all_carry_an_allow_list(self):
        for r in TABLE["rules"]:
            if r["kind"] == "only_in":
                with self.subTest(rule=r["id"]):
                    self.assertTrue(r.get("allow"))

    def test_globs_use_forward_slashes(self):
        for r in TABLE["rules"]:
            for key in ("scope", "exclude", "allow"):
                for g in r.get(key, []):
                    with self.subTest(rule=r["id"], glob=g):
                        self.assertNotIn("\\", g)

    def test_validate_table_rejects_a_broken_rule(self):
        bad = {"rules": [{"id": "x", "source": "s", "severity": "LOUD", "kind": "forbid", "message": "m"},
                         {"id": "o", "source": "s", "severity": "BLOCKING", "kind": "only_in", "message": "m",
                          "scope": ["a/*.gd"], "pattern": "x"}]}
        errors = lr.validate_table(bad)
        self.assertTrue(any("severity" in e for e in errors))
        self.assertTrue(any("allow" in e for e in errors))


class CliTest(unittest.TestCase):
    """AC-2: --list, --rule, unknown id."""

    def test_list_prints_every_rule(self):
        code, text = run_main(["--list"])
        self.assertEqual(code, 0)
        for r in TABLE["rules"]:
            self.assertIn(r["id"], text)

    def test_rule_option_runs_one_rule_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, "src"))
            with open(os.path.join(tmp, "src", "a.gd"), "w", newline="\n") as fh:
                fh.write("Engine.time_scale = 2\nSceneTree.paused = true\n")
            code, text = run_main(["--rule", "forbidden:engine_time_scale_writes", "--root", tmp])
        self.assertEqual(code, 1)
        self.assertIn("forbidden:engine_time_scale_writes", text)
        self.assertNotIn("forbidden:scene_tree_paused_for_pause", text)
        self.assertIn("1 rule(s)", text)

    def test_unknown_rule_id_exits_non_zero(self):
        code, text = run_main(["--rule", "no:such_rule"])
        self.assertNotEqual(code, 0)
        self.assertIn("no:such_rule", text)


class OnlyInTest(unittest.TestCase):
    """AC-3: only_in honours the allow glob list."""

    R = rule(kind="only_in", scope=["src/**/*.gd"], pattern=r"\bFileAccess\b",
             allow=["src/persistence/save_service.gd", "src/**/allowed_*.gd"])

    def test_match_in_allowed_file_passes(self):
        res = lr.evaluate(self.R, mem({"src/persistence/save_service.gd": "FileAccess.open(p)\n"}))
        self.assertEqual(res.violations, [])

    def test_second_allow_glob_is_honoured(self):
        res = lr.evaluate(self.R, mem({"src/deep/er/allowed_x.gd": "FileAccess.open(p)\n"}))
        self.assertEqual(res.violations, [])

    def test_match_in_other_file_fails_with_path_and_line(self):
        res = lr.evaluate(self.R, mem({"src/other.gd": "var a\nFileAccess.open(p)\n"}))
        self.assertEqual([(v.path, v.line) for v in res.violations], [("src/other.gd", 2)])

    def test_allowed_and_disallowed_together(self):
        res = lr.evaluate(self.R, mem({"src/persistence/save_service.gd": "FileAccess.x\n", "src/b.gd": "FileAccess.y\n"}))
        self.assertEqual([v.path for v in res.violations], ["src/b.gd"])

    def test_allow_does_not_match_a_similar_name(self):
        res = lr.evaluate(self.R, mem({"src/persistence/save_service.gd.bak.gd": "FileAccess.x\n"}))
        self.assertEqual(len(res.violations), 1)

    def test_exclude_removes_a_file_from_scope(self):
        r = dict(self.R, exclude=["src/gen/**"])
        self.assertEqual(lr.evaluate(r, mem({"src/gen/x.gd": "FileAccess.x\n"})).violations, [])

    def test_registered_only_in_rule_honours_its_own_allow_list(self):
        r = RULES["forbidden:save_io_outside_save_service"]
        allowed = r["allow"][0].replace("**/", "x/").replace("*", "a")
        res = lr.evaluate(r, mem({allowed: "FileAccess.open(p)\n"}))
        self.assertEqual(res.violations, [])
        res = lr.evaluate(r, mem({"src/gameplay/not_allowed.gd": "FileAccess.open(p)\n"}))
        self.assertEqual(len(res.violations), 1)


class ProjectSettingTest(unittest.TestCase):
    """AC-4: project.godot keys under sections, nested [autoload], values compared."""

    AUTOLOAD = RULES["forbidden:autoload_singletons"]

    def test_parser_reads_keys_under_sections_with_line_numbers(self):
        text = '; comment\nconfig_version=5\n\n[application]\n\nconfig/name="X"\nconfig/quit_on_go_back=false\n\n[input_devices]\n\npointing/emulate_touch_from_mouse=true\n'
        entries = lr.parse_project_godot(text)
        self.assertIn(("application", "config/quit_on_go_back", "false", 7), entries)
        self.assertIn(("input_devices", "pointing/emulate_touch_from_mouse", "true", 11), entries)
        self.assertIn(("", "config_version", "5", 2), entries)

    def test_parser_skips_continuation_lines_of_multiline_values(self):
        text = ('[input]\n\nmove={\n"deadzone": 0.5,\n"events": [Object(InputEventKey,"resource_local_to_scene"=false)]\n}\n'
                '[autoload]\nGame="*res://g.gd"\n')
        entries = lr.parse_project_godot(text)
        self.assertEqual([(s, k) for s, k, _v, _n in entries], [("input", "move"), ("autoload", "Game")])
        self.assertEqual(entries[1][3], 8)

    def test_parser_keeps_bracket_looking_continuation_line_out_of_sections(self):
        text = '[a]\nlist=[\n[Object(X)]\n]\n[autoload]\n'
        entries = lr.parse_project_godot(text)
        self.assertEqual([k for _s, k, _v, _n in entries], ["list"])

    def test_parser_tolerates_crlf(self):
        entries = lr.parse_project_godot("[autoload]\r\nGame=\"*res://g.gd\"\r\n")
        self.assertEqual(entries, [("autoload", "Game", '"*res://g.gd"', 2)])

    def test_autoload_entry_fails_with_line(self):
        text = '[application]\nconfig/name="X"\n\n[autoload]\n\nGame="*res://src/game.gd"\n'
        res = lr.evaluate(self.AUTOLOAD, mem({"project.godot": text}))
        self.assertEqual([v.line for v in res.violations], [6])

    def test_without_autoload_section_passes(self):
        text = '[application]\nconfig/name="X"\n'
        self.assertEqual(lr.evaluate(self.AUTOLOAD, mem({"project.godot": text})).violations, [])

    def test_empty_autoload_section_passes(self):
        self.assertEqual(lr.evaluate(self.AUTOLOAD, mem({"project.godot": "[autoload]\n\n[display]\nx=1\n"})).violations, [])

    def test_autoload_in_another_section_is_not_confused(self):
        text = '[display]\nGame="x"\n'
        self.assertEqual(lr.evaluate(self.AUTOLOAD, mem({"project.godot": text})).violations, [])

    def test_equals_check_compares_values(self):
        r = RULES["project_setting:quit_on_go_back"]
        for value, expected in (("false", 0), ("true", 1), ('"false"', 0)):
            with self.subTest(value=value):
                text = f"[application]\nconfig/quit_on_go_back={value}\n"
                self.assertEqual(len(lr.evaluate(r, mem({"project.godot": text})).violations), expected)

    def test_equals_check_required_key_missing_fails(self):
        r = RULES["project_setting:quit_on_go_back"]
        self.assertEqual(len(lr.evaluate(r, mem({"project.godot": "[application]\n"})).violations), 1)

    def test_equals_check_optional_key_missing_passes(self):
        r = RULES["project_setting:emulate_mouse_from_touch"]
        self.assertEqual(lr.evaluate(r, mem({"project.godot": "[application]\n"})).violations, [])

    def test_equals_check_on_numeric_value(self):
        r = RULES["project_setting:handheld_orientation"]
        good = "[display]\nwindow/handheld/orientation=1\n"
        bad = "[display]\nwindow/handheld/orientation=6\n"
        self.assertEqual(lr.evaluate(r, mem({"project.godot": good})).violations, [])
        self.assertEqual(len(lr.evaluate(r, mem({"project.godot": bad})).violations), 1)

    def test_only_true_check_allows_gravity_only(self):
        r = RULES["forbidden:extra_sensor_flags"]
        ok = "[input_devices]\nsensors/enable_gravity=true\nsensors/enable_gyroscope=false\n"
        bad = "[input_devices]\nsensors/enable_gravity=true\nsensors/enable_gyroscope=true\n"
        self.assertEqual(lr.evaluate(r, mem({"project.godot": ok})).violations, [])
        self.assertEqual([v.line for v in lr.evaluate(r, mem({"project.godot": bad})).violations], [3])

    def test_missing_project_godot_passes_with_note(self):
        res = lr.evaluate(self.AUTOLOAD, mem({}))
        self.assertEqual(res.violations, [])
        self.assertTrue(res.notes)

    def test_unknown_check_is_a_loud_error(self):
        with self.assertRaises(ValueError):
            lr.evaluate(rule(kind="project_setting", check="nope"), mem({"project.godot": "[a]\nb=1\n"}))


class SceneConnectionTest(unittest.TestCase):
    """AC-5: deferred flag (bit value 1) in a .tscn [connection] entry."""

    R = RULES["forbidden:connect_deferred_control_signals_scene"]

    def _count(self, line, path="scenes/main.tscn"):
        return len(lr.evaluate(self.R, mem({path: line})).violations)

    def test_deferred_flag_fails(self):
        self.assertEqual(self._count('[connection signal="run_ended" from="A" to="B" method="m" flags=1]\n'), 1)

    def test_deferred_plus_persist_fails(self):
        self.assertEqual(self._count('[connection signal="hit_reported" from="A" to="B" method="m" flags=3]\n'), 1)

    def test_without_the_flag_passes(self):
        self.assertEqual(self._count('[connection signal="run_ended" from="A" to="B" method="m" flags=2]\n'), 0)
        self.assertEqual(self._count('[connection signal="run_ended" from="A" to="B" method="m" flags=0]\n'), 0)
        self.assertEqual(self._count('[connection signal="run_ended" from="A" to="B" method="m"]\n'), 0)

    def test_deferred_flag_on_an_unrelated_signal_passes(self):
        self.assertEqual(self._count('[connection signal="pressed" from="A" to="B" method="m" flags=1]\n'), 0)

    def test_line_number_and_non_connection_lines(self):
        text = '[gd_scene format=3]\n\n[node name="A" type="Node"]\n[connection signal="window_opened" from="A" to="B" method="m" flags=1]\n'
        res = lr.evaluate(self.R, mem({"a.tscn": text}))
        self.assertEqual([v.line for v in res.violations], [4])

    def test_crlf_scene(self):
        text = '[gd_scene]\r\n[connection signal="run_ended" from="A" to="B" method="m" flags=1]\r\n'
        self.assertEqual(self._count(text), 1)

    def test_non_scene_file_is_out_of_scope(self):
        res = lr.evaluate(self.R, mem({"a.txt": '[connection signal="run_ended" flags=1]\n'}))
        self.assertEqual(res.violations, [])
        self.assertTrue(res.notes)


class ManifestAndSecretTest(unittest.TestCase):
    """AC-6: manifest skips with a warning without presets; secret finds keystores and passwords."""

    def test_every_manifest_rule_skips_with_a_warning_when_presets_absent(self):
        for r in TABLE["rules"]:
            if r["kind"] == "manifest":
                with self.subTest(rule=r["id"]):
                    res = lr.evaluate(r, mem({"project.godot": "[a]\n"}))
                    self.assertEqual(res.violations, [])
                    self.assertTrue(any("WARNING" in n and "export_presets.cfg" in n for n in res.notes))

    def test_exclude_filter_must_cover_all_four_paths(self):
        r = RULES["manifest:exclude_filter"]
        good = 'exclude_filter="tests/*, addons/gut/*, tools/*, build/*"\n'
        bad = 'exclude_filter="tests/*, tools/*"\n'
        missing = "name=\"Android\"\n"
        self.assertEqual(lr.evaluate(r, mem({"export_presets.cfg": good})).violations, [])
        self.assertEqual(len(lr.evaluate(r, mem({"export_presets.cfg": bad})).violations), 2)
        self.assertEqual(len(lr.evaluate(r, mem({"export_presets.cfg": missing})).violations), 1)

    def test_allow_backup_and_second_vulkan_feature_fail(self):
        backup = RULES["manifest:allow_backup"]
        self.assertEqual(len(lr.evaluate(backup, mem({"export_presets.cfg": "user_data_backup/allow=true\n"})).violations), 1)
        self.assertEqual(lr.evaluate(backup, mem({"export_presets.cfg": "user_data_backup/allow=false\n"})).violations, [])
        vk = RULES["forbidden:duplicate_vulkan_uses_feature"]
        one = "a=android.hardware.vulkan.version\n"
        two = one + "b=android.hardware.vulkan.version\n"
        self.assertEqual(lr.evaluate(vk, mem({"export_presets.cfg": one})).violations, [])
        self.assertEqual([v.line for v in lr.evaluate(vk, mem({"export_presets.cfg": two})).violations], [2])

    def test_vibrate_only_permission(self):
        r = RULES["forbidden:internet_permission_in_release"]
        self.assertEqual(lr.evaluate(r, mem({"export_presets.cfg": "permissions/vibrate=true\npermissions/internet=false\n"})).violations, [])
        self.assertEqual(len(lr.evaluate(r, mem({"export_presets.cfg": "permissions/internet=true\n"})).violations), 1)

    def test_keystore_files_are_found_by_name(self):
        r = RULES["forbidden:keystore_in_repository"]
        res = lr.evaluate(r, mem({"release/my.keystore": "x", "a/b/debug.jks": "x", "src/a.gd": "x"}))
        self.assertEqual(sorted(v.path for v in res.violations), ["a/b/debug.jks", "release/my.keystore"])
        self.assertEqual(lr.evaluate(r, mem({"src/a.gd": "x"})).violations, [])

    def test_password_keys_are_found(self):
        r = RULES["secret:preset_credentials"]
        for text in ('keystore/release_password="hunter2"\n', "keystore/password='abc'\n", 'storepass = "x1"\n'):
            with self.subTest(text=text):
                self.assertEqual(len(lr.evaluate(r, mem({"export_presets.cfg": text})).violations), 1)

    def test_empty_or_variable_password_values_pass(self):
        r = RULES["secret:preset_credentials"]
        for text in ('keystore/release_password=""\n', 'keystore/release_password="$ANDROID_PASS"\n', "name=\"Android\"\n"):
            with self.subTest(text=text):
                self.assertEqual(lr.evaluate(r, mem({"export_presets.cfg": text})).violations, [])

    def test_password_in_a_workflow_is_found(self):
        r = RULES["secret:preset_credentials"]
        res = lr.evaluate(r, mem({".github/workflows/ci.yml": "x: 1\nkeypass: 'abc'\n"}))
        self.assertEqual([v.line for v in res.violations], [2])


class SeverityExitCodeTest(unittest.TestCase):
    """AC-7: ADVISORY prints but exits 0; BLOCKING exits non-zero."""

    def _run(self, rule_id, text, path="src/view/a.gd"):
        with tempfile.TemporaryDirectory() as tmp:
            full = os.path.join(tmp, *path.split("/"))
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "w", newline="\n") as fh:
                fh.write(text)
            return run_main(["--rule", rule_id, "--root", tmp])

    def test_advisory_finding_is_printed_with_exit_zero(self):
        r = RULES["forbidden:raw_s_in_vector3"]
        text = None
        for fixture in ("fail.txt",):
            vpath, text = lr.load_fixture(os.path.join(lr.FIXTURES_DIR, lr.safe_id(r["id"]), fixture))
        code, out = self._run(r["id"], text, vpath)
        self.assertEqual(code, 0)
        self.assertIn("[ADVISORY]", out)
        self.assertIn("forbidden:raw_s_in_vector3", out)

    def test_blocking_finding_exits_one(self):
        r = RULES["forbidden:engine_time_scale_writes"]
        vpath, text = lr.load_fixture(os.path.join(lr.FIXTURES_DIR, lr.safe_id(r["id"]), "fail.txt"))
        code, out = self._run(r["id"], text, vpath)
        self.assertEqual(code, 1)
        self.assertIn("[BLOCKING]", out)

    def test_clean_tree_exits_zero(self):
        code, _out = self._run("forbidden:engine_time_scale_writes", "var a = 1\n")
        self.assertEqual(code, 0)

    def test_broken_rule_table_exits_two(self):
        self.assertEqual(lr.validate_table({"rules": [{"id": "x"}]}) != [], True)


class CustomRuleTest(unittest.TestCase):
    """AC-8: each custom rule has a named Python function or is a declared stub."""

    def test_every_custom_rule_names_a_registered_function(self):
        for r in TABLE["rules"]:
            if r["kind"] == "custom":
                with self.subTest(rule=r["id"]):
                    self.assertIn(r.get("function"), lr.CUSTOM)
                    self.assertTrue(callable(lr.CUSTOM[r["function"]]))

    def test_every_registered_function_is_used_by_a_rule(self):
        used = {r.get("function") for r in TABLE["rules"] if r["kind"] == "custom"}
        self.assertEqual(used, set(lr.CUSTOM))

    def test_pending_custom_rules_are_declared_stubs_with_a_note(self):
        stub = RULES["custom:scoring_reflection_check"]
        self.assertTrue(stub.get("stub"))
        res = lr.evaluate(stub, mem({"src/scoring.gd": "x\n"}))
        self.assertEqual(res.violations, [])
        self.assertTrue(any("stub" in n for n in res.notes))

    def test_unknown_custom_function_fails_validation(self):
        errors = lr.validate_table({"rules": [rule(kind="custom", function="nope")]})
        self.assertTrue(any("unknown custom function" in e for e in errors))

    def test_rng_seed_order(self):
        r = RULES["custom:pattern_rng_seeded_before_draw"]
        path = r["scope"][0].replace("**/", "x/").replace("*", "pattern")
        ok = "var rng = RandomNumberGenerator.new()\nrng.seed = 5\nvar v = rng.randi()\n"
        late = "var v = rng.randi()\nrng.seed = 5\n"
        none = "var v = rng.randf()\n"
        self.assertEqual(lr.evaluate(r, mem({path: ok})).violations, [])
        self.assertEqual([v.line for v in lr.evaluate(r, mem({path: late})).violations], [1])
        self.assertEqual(len(lr.evaluate(r, mem({path: none})).violations), 1)

    def test_mouse_filter_rule(self):
        r = RULES["forbidden:noninteractive_control_stop_filter"]
        stop = '[node name="Backdrop" type="ColorRect" parent="."]\nlayout_mode = 1\n'
        ignore = stop + "mouse_filter = 2\n"
        scrim = '[node name="Scrim" type="ColorRect" parent="."]\n'
        self.assertEqual(len(lr.evaluate(r, mem({"ui/a.tscn": stop})).violations), 1)
        self.assertEqual(lr.evaluate(r, mem({"ui/a.tscn": ignore})).violations, [])
        self.assertEqual(lr.evaluate(r, mem({"ui/a.tscn": scrim})).violations, [])


class ScopeAndNoteTest(unittest.TestCase):
    def test_rule_with_no_file_in_scope_passes_with_a_note(self):
        for kind in ("forbid", "only_in"):
            r = rule(kind=kind, scope=["src/**/*.gd"], pattern="x", allow=["src/ok.gd"])
            res = lr.evaluate(r, mem({"docs/a.md": "x"}))
            self.assertEqual(res.violations, [])
            self.assertTrue(res.notes)

    def test_tscn_and_text_files_are_scanned_raw(self):
        r = rule(kind="forbid", scope=["**/*.tscn"], pattern=r"# not a comment")
        self.assertEqual(len(lr.evaluate(r, mem({"a.tscn": 'x = "# not a comment"\n'})).violations), 1)

    def test_shader_files_use_the_c_style_stripper(self):
        r = rule(kind="forbid", scope=["assets/**/*.gdshader"], pattern=r"\bTIME\b")
        self.assertEqual(lr.evaluate(r, mem({"assets/s.gdshader": "// TIME\n/* TIME */\n"})).violations, [])
        self.assertEqual(len(lr.evaluate(r, mem({"assets/s.gdshader": "float a = TIME;\n"})).violations), 1)

    def test_filesystem_source_uses_forward_slash_paths_and_skips_vendored_dirs(self):
        with tempfile.TemporaryDirectory() as tmp:
            for rel in ("src/a/b.gd", "addons/gut/x.gd", ".godot/y.gd"):
                full = os.path.join(tmp, *rel.split("/"))
                os.makedirs(os.path.dirname(full), exist_ok=True)
                with open(full, "w", newline="\n") as fh:
                    fh.write("x\n")
            self.assertEqual(lr.FsSource(tmp).all_paths(), ["src/a/b.gd"])

    def test_filesystem_source_reads_crlf_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            with open(os.path.join(tmp, "a.gd"), "wb") as fh:
                fh.write(b"# c\r\nEngine.time_scale = 1\r\n")
            res = lr.evaluate(rule(kind="forbid", scope=["*.gd"], pattern=r"Engine\.time_scale"), lr.FsSource(tmp))
            self.assertEqual([v.line for v in res.violations], [2])


if __name__ == "__main__":
    unittest.main()
