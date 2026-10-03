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
        self.assertEqual(out, 'a \nb ""\r\nc\r\n')

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


class StripCStyleTest(unittest.TestCase):
    def test_line_and_block_comments(self):
        out = lr.strip_c_style("a // TIME\nb /* TIME\nTIME */ c\n")
        self.assertNotIn("TIME", out)
        self.assertEqual(out.count("\n"), 3)

    def test_string_with_slashes(self):
        self.assertEqual(lr.strip_c_style('x = "a // b"; // c'), 'x = ""; ')


if __name__ == "__main__":
    unittest.main()
