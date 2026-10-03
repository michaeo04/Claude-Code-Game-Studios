"""Edge cases of the GDScript comment/string stripper (ADR-0009 Decision 5)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402


class StripGdscriptTest(unittest.TestCase):
    def test_comment_removed(self):
        self.assertEqual(lr.strip_gdscript("var a = 1 # Engine.time_scale = 1\nvar b"), "var a = 1 \nvar b")

    def test_doc_comment_removed(self):
        self.assertEqual(lr.strip_gdscript("## _process docs\nfunc f():\n"), "\nfunc f():\n")

    def test_hash_inside_string_is_not_a_comment(self):
        out = lr.strip_gdscript('var s = "a # b"\nvar t = 2 # c\n')
        self.assertEqual(out, 'var s = ""\nvar t = 2 \n')

    def test_string_body_removed_quotes_kept(self):
        self.assertEqual(lr.strip_gdscript('x.connect("sig", cb)'), 'x.connect("", cb)')
        self.assertEqual(lr.strip_gdscript("Callable(o, 'm')"), 'Callable(o, "")')

    def test_escaped_quote(self):
        self.assertEqual(lr.strip_gdscript(r'var s = "a \" # still string" # real'), 'var s = "" ')

    def test_escaped_backslash_then_quote_ends_string(self):
        self.assertEqual(lr.strip_gdscript('var s = "a\\\\" # c\nvar t'), 'var s = "" \nvar t')

    def test_triple_quoted_preserves_newlines(self):
        src = 'var d = """line1\n# not a comment\nline3"""\nvar x'
        out = lr.strip_gdscript(src)
        self.assertEqual(out.count("\n"), src.count("\n"))
        self.assertNotIn("not a comment", out)
        self.assertTrue(out.endswith("\nvar x"))

    def test_triple_single_quotes_and_inner_quotes(self):
        out = lr.strip_gdscript("var d = '''a \"b\" 'c' _process'''\nvar y")
        self.assertNotIn("_process", out)
        self.assertTrue(out.endswith("var y"))

    def test_raw_string_prefix(self):
        out = lr.strip_gdscript('var r = r"C:\\dir # x"\nvar z')
        self.assertEqual(out, 'var r = r""\nvar z')

    def test_stringname_and_nodepath_literals(self):
        self.assertEqual(lr.strip_gdscript('var a = &"name"; var b = ^"Path/To" # c'), 'var a = &""; var b = ^"" ')

    def test_r_inside_identifier_is_not_a_prefix(self):
        self.assertEqual(lr.strip_gdscript('bar"x"'), 'bar""')

    def test_node_path_shorthand_is_not_a_string(self):
        src = "var a = $Node/Path\nvar b = %Unique\n"
        self.assertEqual(lr.strip_gdscript(src), src)

    def test_dollar_quoted_node_path_is_a_string(self):
        self.assertEqual(lr.strip_gdscript('var a = $"My Node/x"'), 'var a = $""')

    def test_crlf_preserved(self):
        src = "a # c\r\nb \"s\"\r\nc\r\n"
        out = lr.strip_gdscript(src)
        self.assertEqual(out.count("\n"), 3)
        # TH-005 AC-2: the CR before a comment's line end is kept (an earlier expectation dropped it).
        self.assertEqual(out, 'a \r\nb ""\r\nc\r\n')

    def test_lf_and_crlf_give_same_line_numbers(self):
        lf = 'func a():\n\tpass\n# c\nfunc _process(d):\n\tpass\n'
        rule = {"id": "t", "severity": "BLOCKING", "kind": "forbid", "scope": ["src/**/*.gd"],
                "pattern": r"\bfunc\s+_(?:physics_)?process\b", "message": "m"}
        for text in (lf, lf.replace("\n", "\r\n")):
            res = lr.evaluate(rule, lr.MemSource({"src/a.gd": text}))
            self.assertEqual([v.line for v in res.violations], [4])

    def test_unterminated_string_ends_at_newline(self):
        self.assertEqual(lr.strip_gdscript('var s = "oops\nvar t = 1'), 'var s = ""\nvar t = 1')

    def test_keep_strings_keeps_body_but_not_comments(self):
        out = lr.strip_gdscript('f("res://a") # "res://b"', keep_strings=True)
        self.assertEqual(out, 'f("res://a") ')

    def test_process_regex_distinguishes_calls(self):
        rx = lr.re.compile(r"\bfunc\s+_(?:physics_)?process\b")
        self.assertTrue(rx.search("func _process(delta):"))
        self.assertTrue(rx.search("func  _physics_process(delta):"))
        for text in ("set_process(true)", "func _process_input():", "var _processed = 1", "# func _process()"):
            self.assertFalse(rx.search(lr.strip_gdscript(text)), text)


class StripperExactOutputTest(unittest.TestCase):
    """Story TH-005 AC-1: exact stripped output for every construct in ADR-0009 Decision 5."""

    CASES = [
        ("hash_comment", "a # b\nc", "a \nc"),
        ("doc_comment", "## doc\nvar a", "\nvar a"),
        ("comment_at_eof_without_newline", "x # tail", "x "),
        ("hash_in_double_string", 'var s = "a#b"', 'var s = ""'),
        ("hash_in_single_string", "var s = 'a#b' # c", 'var s = "" '),
        ("escaped_quote", r'var s = "a\"b#c" # z', 'var s = "" '),
        ("escaped_backslash_before_closing_quote", r'var s = "a\\" # z', 'var s = "" '),
        ("triple_double_multiline", 'a """x\n# y\nz""" b', 'a ""\n\n b'),
        ("triple_single_multiline", "a '''x\n# y\nz''' b", 'a ""\n\n b'),
        ("triple_double_with_inner_quotes", '''a """it's "q" ok""" b''', 'a "" b'),
        ("triple_single_with_inner_double_triple", "a '''x\"\"\"y''' b", 'a "" b'),
        ("raw_string", 'r"a#b"', 'r""'),
        ("raw_string_with_escaped_quote", r'r"a\"b" # c', 'r"" '),
        ("raw_string_double_backslash_then_close", r'r"C:\\" # c', 'r"" '),
        ("raw_single_quote", "r'a#b' x", 'r"" x'),
        ("stringname_literal", 'x = &"name" # c', 'x = &"" '),
        ("nodepath_literal", 'x = ^"res://p#q" # c', 'x = ^"" '),
        ("dollar_node_path_not_string", "var a = $Node/Path # c", "var a = $Node/Path "),
        ("percent_unique_not_string", "var a = %Unique # c", "var a = %Unique "),
        ("dollar_node_path_then_string", 'var a = $A/B.get("k")', 'var a = $A/B.get("")'),
        ("modulo_is_not_a_string", "var a = 7 % 3", "var a = 7 % 3"),
        ("empty_string", 'f("", 1)', 'f("", 1)'),
        ("two_strings_one_line", 'f("a#", "b#") # c', 'f("", "") '),
        ("r_inside_identifier", 'bar"x"', 'bar""'),
        ("quotes_kept_for_connect", 'sig.connect("name", cb)', 'sig.connect("", cb)'),
    ]

    def test_exact_output(self):
        for name, src, expected in self.CASES:
            with self.subTest(case=name):
                self.assertEqual(lr.strip_gdscript(src), expected)

    def test_keep_strings_keeps_raw_prefix_and_triple_quotes(self):
        self.assertEqual(lr.strip_gdscript('r"a#b" # c', keep_strings=True), 'r"a#b" ')
        self.assertEqual(lr.strip_gdscript('x """a # b""" # c', keep_strings=True), 'x """a # b""" ')

    def test_escaped_newline_inside_string_keeps_line_count(self):
        src = 'var s = "a\\\nb"\nvar t'
        out = lr.strip_gdscript(src)
        self.assertEqual(out.count("\n"), src.count("\n"))
        self.assertTrue(out.endswith("\nvar t"))

    def test_escaped_crlf_inside_string_does_not_end_string(self):
        src = 'var s = "a\\\r\nb _process"\r\nvar t\r\n'
        out = lr.strip_gdscript(src)
        self.assertNotIn("_process", out)
        self.assertEqual(out.count("\n"), src.count("\n"))
        self.assertTrue(out.endswith("var t\r\n"))


class StripperLineStructureTest(unittest.TestCase):
    """Story TH-005 AC-2: line structure of the output equals the input, for LF and CRLF."""

    SAMPLES = [
        'var a = 1 # c\n## doc\nvar d = """l1\nl2\nl3"""\nvar e = "x"\n\nfunc f():\n\tpass\n',
        "var d = '''a\nb''' # c\nvar r = r\"x\"\n",
        '# only a comment\n\n\nvar x = &"n"\n',
    ]

    def test_line_count_equal(self):
        for ending in ("\n", "\r\n"):
            for idx, sample in enumerate(self.SAMPLES):
                with self.subTest(ending=repr(ending), sample=idx):
                    src = sample.replace("\n", ending)
                    out = lr.strip_gdscript(src)
                    self.assertEqual(len(out.splitlines()), len(src.splitlines()))
                    self.assertEqual(out.count("\n"), src.count("\n"))

    def test_crlf_endings_survive_after_comments_and_strings(self):
        self.assertEqual(lr.strip_gdscript('a # c\r\nb "s"\r\nc\r\n'), 'a \r\nb ""\r\nc\r\n')

    def test_crlf_inside_triple_string_is_kept_as_crlf(self):
        self.assertEqual(lr.strip_gdscript('x = """a\r\nb\r\nc"""\r\ny\r\n'), 'x = ""\r\n\r\n\r\ny\r\n')

    def test_code_lines_are_unchanged(self):
        src = "var a = 1\nfunc _process(d):\n\tpass\n"
        self.assertEqual(lr.strip_gdscript(src), src)
        src_crlf = src.replace("\n", "\r\n")
        self.assertEqual(lr.strip_gdscript(src_crlf), src_crlf)


class StripperRuleLevelTest(unittest.TestCase):
    """Story TH-005 AC-3 and AC-4: banned token in non-code does not match, in code does."""

    RULE = {"id": "forbidden:t", "source": "t", "severity": "BLOCKING", "kind": "forbid",
            "scope": ["src/**/*.gd"], "pattern": r"\bEngine\.time_scale\b", "message": "no Engine.time_scale here"}

    def _violations(self, text):
        return lr.evaluate(self.RULE, lr.MemSource({"src/a.gd": text})).violations

    def test_token_in_non_code_does_not_match(self):
        cases = {
            "comment": "var a # Engine.time_scale = 1\n",
            "doc_comment": "## Engine.time_scale docs\nvar a\n",
            "double_string": 'var a = "Engine.time_scale"\n',
            "single_string": "var a = 'Engine.time_scale'\n",
            "triple_string": 'var a = """\nEngine.time_scale\n"""\n',
            "message_string": 'push_error("do not set Engine.time_scale")\n',
            "raw_string": 'var a = r"Engine.time_scale"\n',
            "stringname": 'var a = &"Engine.time_scale"\n',
        }
        for name, text in cases.items():
            with self.subTest(case=name):
                self.assertEqual(self._violations(text), [])

    def test_token_in_code_matches_with_correct_line(self):
        text = 'var a = "x"\n# c\n"""doc\nmore"""\nEngine.time_scale = 0.5\n'
        self.assertEqual([v.line for v in self._violations(text)], [5])

    def test_code_after_a_string_with_hash_still_matches(self):
        self.assertEqual(len(self._violations('var a = "#"; Engine.time_scale = 1\n')), 1)

    def test_process_regex_on_stripped_text(self):
        rule = dict(self.RULE, pattern=r"\bfunc\s+_(?:physics_)?process\b")
        hit = ["func _process(d):\n", "func _physics_process(d):\n", "\tfunc  _process(d) -> void:\n"]
        miss = ["set_process(true)\n", "func my_process_x():\n", "func _process_input():\n",
                "var my_process_x = 1\n", "# func _process(d):\n", 'var s = "func _process(d)"\n']
        for text in hit:
            with self.subTest(hit=text):
                self.assertEqual(len(lr.evaluate(rule, lr.MemSource({"src/a.gd": text})).violations), 1)
        for text in miss:
            with self.subTest(miss=text):
                self.assertEqual(lr.evaluate(rule, lr.MemSource({"src/a.gd": text})).violations, [])

    def test_the_registered_process_rule_distinguishes_calls(self):
        table = lr.load_table()
        rule = next(r for r in table["rules"] if r["id"] == "forbidden:view_node_own_process")
        self.assertIn("process", rule["pattern"])
        path = "src/presentation/some_view.gd"
        for text, expected in (("func _process(d):\n", 1), ("func _physics_process(d):\n", 1),
                               ("set_process(true)\n", 0), ("var my_process_x = 1\n", 0)):
            with self.subTest(text=text):
                res = lr.evaluate(rule, lr.MemSource({path: text}))
                self.assertEqual(len(res.violations), expected)


class StripperTruncatedInputTest(unittest.TestCase):
    """Story TH-005 AC-5: truncated files neither crash nor leak into other files."""

    TRUNCATED = {
        "unterminated_triple_double": 'var a = """never closed\nEngine.time_scale = 1\n',
        "unterminated_triple_single": "var a = '''never closed\nEngine.time_scale = 1\n",
        "unterminated_single_line_string": 'var a = "never closed\nEngine.time_scale = 1\n',
        "lone_quote_at_eof": 'var a = "',
        "lone_triple_at_eof": 'var a = """',
        "two_quotes_at_eof": 'var a = ""',
        "trailing_backslash_in_string": 'var a = "abc\\',
        "trailing_backslash_alone": "var a = 1 \\",
        "raw_prefix_at_eof": "var a = r",
        "raw_prefix_quote_at_eof": 'var a = r"',
        "empty_file": "",
        "only_hash": "#",
    }

    def test_no_crash_and_newlines_kept(self):
        for name, src in self.TRUNCATED.items():
            with self.subTest(case=name):
                out = lr.strip_gdscript(src)
                self.assertEqual(out.count("\n"), src.count("\n"))

    def test_truncated_file_does_not_swallow_the_next_file(self):
        good = "Engine.time_scale = 1\n"
        for name, bad in self.TRUNCATED.items():
            with self.subTest(case=name):
                res = lr.evaluate(StripperRuleLevelTest.RULE, lr.MemSource({"src/a.gd": bad, "src/b.gd": good}))
                self.assertEqual([v.line for v in res.violations if v.path == "src/b.gd"], [1])

    def test_unterminated_single_line_string_ends_at_line_end(self):
        out = lr.strip_gdscript(self.TRUNCATED["unterminated_single_line_string"])
        self.assertIn("Engine.time_scale", out)


class StripCStyleTest(unittest.TestCase):
    def test_line_and_block_comments(self):
        out = lr.strip_c_style("a // TIME\nb /* TIME\nTIME */ c\n")
        self.assertNotIn("TIME", out)
        self.assertEqual(out.count("\n"), 3)

    def test_string_with_slashes(self):
        self.assertEqual(lr.strip_c_style('x = "a // b"; // c'), 'x = ""; ')


if __name__ == "__main__":
    unittest.main()
