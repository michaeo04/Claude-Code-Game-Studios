"""Story PD-012: lint rules over src/core/pattern_difficulty/ (AC-24)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lint_runner as lr  # noqa: E402

RULES = {r["id"]: r for r in lr.load_table()["rules"]}
CORE = "src/core/pattern_difficulty/pattern_core.gd"
BAG = "src/core/pattern_difficulty/tier_bag.gd"
PURITY = "forbidden:pattern_core_purity"
CTOR = "forbidden:pattern_rng_construction_outside_core"
SEEDED = "custom:pattern_rng_construction_seeded"


def scan(rule_id, path, text):
    return lr.evaluate(RULES[rule_id], lr.MemSource({path: text})).violations


class PurityTest(unittest.TestCase):
    TOKENS = ["var a: Area3D", "var a: CollisionObject3D", "var a: PhysicsServer3D", "Input.get_vector(&'a')",
              "Engine.get_frames_drawn()", "Time.get_ticks_usec()", "OS.get_name()", "DisplayServer.get_name()",
              "get_tree()", "func _process(d):", "func _physics_process(d):", "randomize()", "randf()", "randi()",
              "randi_range(0, 2)", "seed(1)", "items.shuffle()"]

    def test_each_banned_token_fails_with_rule_id(self):
        for tok in self.TOKENS:
            with self.subTest(token=tok):
                v = scan(PURITY, CORE, "extends RefCounted\n\n" + tok + "\n")
                self.assertEqual([(x.rule_id, x.line) for x in v], [(PURITY, 3)])

    def test_seeded_instance_draw_and_type_pass(self):
        text = "extends RefCounted\nvar _rng: RandomNumberGenerator\nfunc f() -> int:\n\treturn _rng.randi_range(0, 3)\n"
        self.assertEqual(scan(PURITY, BAG, text), [])

    def test_real_sources_pass_all_three_rules(self):
        for rid in (PURITY, CTOR, SEEDED):
            res = lr.evaluate(RULES[rid], lr.FsSource(lr.REPO_ROOT))
            self.assertEqual(res.violations, [], rid)


class SeedOrderTest(unittest.TestCase):
    def test_unseeded_rng_fails(self):
        text = "var rng := RandomNumberGenerator.new()\nfunc go():\n\treturn rng.randi()\n"
        self.assertEqual(len(scan(SEEDED, CORE, text)), 1)

    def test_unseeded_without_draw_fails(self):
        self.assertEqual(len(scan(SEEDED, CORE, "var rng := RandomNumberGenerator.new()\n")), 1)

    def test_draw_before_seed_fails(self):
        text = "func f():\n\trng = RandomNumberGenerator.new()\n\trng.randi()\n\trng.seed = 3\n"
        self.assertEqual(len(scan(SEEDED, CORE, text)), 1)

    def test_seed_then_draw_passes(self):
        text = "func f(s):\n\trng = RandomNumberGenerator.new()\n\trng.seed = s\n\trng.randi()\n"
        self.assertEqual(scan(SEEDED, CORE, text), [])

    def test_randomize_on_instance_is_caught_by_purity(self):
        self.assertEqual(len(scan(PURITY, CORE, "func f():\n\trandomize()\n")), 1)

    def test_construction_outside_core_fails(self):
        self.assertEqual(len(scan(CTOR, BAG, "var r := RandomNumberGenerator.new()\n")), 1)
        self.assertEqual(scan(CTOR, CORE, "var r := RandomNumberGenerator.new()\n"), [])


if __name__ == "__main__":
    unittest.main()
