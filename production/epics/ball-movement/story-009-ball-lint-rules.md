# Story 009: CI lint rules for BallCore, BallConfig and BallMath (AC-25)

> **Epic**: Ball Movement
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/ball-movement.md`
**Requirement**: `TR-ball-movement-001`, `TR-ball-movement-013`, `TR-ball-movement-014`, `TR-ball-movement-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary, Decision 5 lint runner); ADR-0008: Hazard, collision and content format (no physics nodes; contact is Obstacle's)
**ADR Decision Summary**: Lints are Python 3 stdlib rules in `tools/ci/lint_rules.json` run by `tools/ci/lint_runner.py` over comment- and string-stripped GDScript; each rule has one passing and one failing fixture; explicit `allow` lists, no inline ignores.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `wrapf(PI - 1e-9)` collapses to `-PI` on the pinned 4.7.2 binary, hence the token ban. Fixtures that are invalid GDScript are `.txt` or under a `.gdignore` folder.
**Control Manifest Rules (this layer)**:
- Required: rules registered with `id`, `source`, `severity` BLOCKING, `kind`, `scope`, `message`; a violation reports file and line; a token inside a comment passes.
- Forbidden: lints in GDScript or shell; inline ignore comments; scanning without the comment/string state machine.
- Guardrail: a rule without both fixtures fails the runner's self-check.

## Acceptance Criteria
- [ ] **AC-25 [L]** (R11 to R13) Fixture self-tests (violation reports file and line; a token in a comment passes) over `BallCore`, `BallConfig`, `BallMath`: each extends `RefCounted` (`Resource` for the config) and contains none of `Node`, `CollisionObject3D`, `CharacterBody3D`, `Area3D`, `RayCast3D`, `ShapeCast3D`, `PhysicsServer`, `hit_reported`, `request_`, `RunState`, Tilt or Tube Track type references (except the shared static `wrap_angle`), `Input.`, `Engine.`, `Time.`, `OS.`, `DisplayServer.`, `get_tree`, process-delta getters, `_process`, `_physics_process`, `randi`, `randf`, `randomize`, `RandomNumberGenerator`.
- [ ] **AC-25 (BallMath scope)** The literal token `wrapf(` is forbidden in `ball_math.gd`; a `const` declaration whose literal is a container (`{}` or `[]`) and any top-level subscript assignment (`IDENT[...] =`) are forbidden there.
- [ ] **AC-25 (position-z)** Tube Track's AC-25 regex (`position.z`, `global_position.z`, `global_transform.origin`) also runs over the ball driver and view scripts (this epic adds the paths in `scope`).
- [ ] **AC-27 (static part)** The `reset()` body of `ball_core.gd` has no loop (`for`, `while`), `.new()` or `load(` (custom rule over the function body).

## Implementation Notes
Add rules to `tools/ci/lint_rules.json` and Python `unittest` fixtures under `tools/ci/tests/` (one passing, one failing per rule). The reset-body check is a `custom` rule (named Python function). Scope uses globs: `src/core/ball_movement/ball_*.gd`, and for position-z the ball view/driver paths (`src/presentation/ball/*.gd`). Coordinate with the existing untracked `tools/ci/lint_runner.py` (see git status) rather than replacing it. Run with `python tools/ci/run_ci.py --only lint`.

## Out of Scope
- Lint rules owned by other epics (`_process` outside GameRoot etc.)
- AC-26 (no `CollisionObject3D` on the instantiated scene): Story 011

## QA Test Cases
- **AC-25 (forbidden tokens)**
  - Given: a failing fixture per token and a passing fixture with the token in a comment and a string
  - When: the runner scans the fixtures
  - Then: failing reports file and line; passing reports nothing
  - Edge cases: CRLF and LF files; token as a substring of another identifier (`Node` in `NodePath`)
- **AC-25 (BallMath)**
  - Given: fixtures with `wrapf(`, `const A = [1]`, `TABLE[0] = 1`
  - When: scanned
  - Then: each fails; a `const PI_HALF: float = ...` scalar passes
  - Edge cases: `wrapf` in a comment passes
- **AC-27 static**
  - Given: a reset body fixture with a `for` loop and one without
  - When: scanned
  - Then: first fails, second passes
  - Edge cases: loop in another function in the same file passes

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tools/ci/tests/` unittest cases pass under `python tools/ci/run_ci.py --only lint`
**Evidence**: `tools/ci/tests/test_lint_ball_rules.py` (token, substring, comment/string, CRLF, BallMath, position-z, reset-body cases and the real sources) plus one pass and one fail fixture per rule in `tools/ci/tests/fixtures/` (`forbidden_ball_core_purity`, `forbidden_ball_core_base_class`, `forbidden_ball_config_base_class`, `forbidden_ball_math_statics_only`, `forbidden_ball_view_position_z`, `custom_ball_core_reset_body`); new custom function `function_body_forbid` in `tools/ci/lint_runner.py`. Note: Tube Track's position-z regex was not registered as a rule, so `forbidden:ball_view_position_z` defines it for the ball driver and view paths.
**Status**: [x] Created and passing

## Dependencies
- Depends on: Story 001, Story 008 (final reset body); test-harness-ci (lint runner story)
- Unlocks: Story 010, Story 011
