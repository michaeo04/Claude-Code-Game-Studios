# Story 012: No-engine-coupling lint for Pattern modules

> **Epic**: Pattern & Difficulty
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1-2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (AC-24)
**Requirement**: `TR-pattern-difficulty-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary; lint rules in `tools/ci/lint_rules.json`); ADR-0008: Hazard, collision and content format (Decision 8: PRNG)
**ADR Decision Summary**: Registered forbidden patterns are machine-checked by `tools/ci/lint_rules.json`; Pattern bans `randomize()`, `randf` and global `Array.shuffle()`, and allows `RandomNumberGenerator` only with an explicit `seed`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Lint runs in `python tools/ci/run_ci.py`; the class cache needs `godot --headless --import` first.
**Control Manifest Rules (this layer)**:
- Required: lint bans `CollisionObject3D`, `CharacterBody3D`, `Area3D`, `PhysicsServer`, `Input.`, `Engine.`, `Time.`, `OS.`, `DisplayServer.`, `get_tree`, `_process`, `_physics_process`, `randi`, `randf`, `randi_range`, `randf_range`, `randomize`, `seed(`, `RandomNumberGenerator` over `PatternMath`, `PatternCore`, `PatternConfig` and their transitive dependencies, with one named exception.
- Forbidden: allow-listing `RandomNumberGenerator` unconditionally.
- Guardrail: API-surface scan, not a determinism proof (AC-17 is the backstop).

## Acceptance Criteria
- [ ] **AC-24** The lint reports none of the banned tokens over `src/core/pattern_difficulty/` and its transitive dependencies, except `PatternCore`'s own seeded `RandomNumberGenerator`; the lint verifies the exception: `seed` is explicitly set before the first draw and `randomize()` never appears. A fixture file containing an unseeded `RandomNumberGenerator` fails the lint.

## Implementation Notes
Add a rule entry to `tools/ci/lint_rules.json` scoped to `src/core/pattern_difficulty/` following the format of the existing Obstacle/Ball Movement entries, including a seed-before-first-draw check (a structural scan: the `RandomNumberGenerator` construction site is followed by a `seed =` assignment before any draw call). Note `randi_range` is permitted only on the seeded instance: the token rule matches the global function form, not `rng.randi_range`. Check the registry `forbidden_patterns` in `docs/registry/architecture.yaml` before adding.

## Out of Scope
- Changing other systems' lint rules.

## QA Test Cases
- **AC-24**: lint passes and bites
  - Given: the real sources; a negative fixture with unseeded RNG, `randomize()`, `Array.shuffle()`, `Engine.` use. When: lint runs. Then: real sources pass; each negative fixture fails with the rule id.
  - Edge cases: the seeded construction passes only when `seed` precedes the first draw.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_lint_test.gd` plus a green `python tools/ci/run_ci.py` lint stage
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 005, 006, 007 (code exists to scan); test-harness-ci lint runner
- Unlocks: Story 013
