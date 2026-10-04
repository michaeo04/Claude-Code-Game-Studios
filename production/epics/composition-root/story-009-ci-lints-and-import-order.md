# Story 009: Composition-root lint rules and the import-before-test order

> **Epic**: Composition Root & Game Loop
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: none, defined by ADR-0002 and ADR-0013
**Requirement**: `TR-composition-root-???` (ADR-0002 Implementation Guidelines; ADR-0013 Decision 2 and Validation Criteria)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; secondary ADR-0013, ADR-0009 (rule table and `project_setting` lint)
**ADR Decision Summary**: A lint rejects `_process`/`_physics_process` overrides outside `GameRoot`, `autoload` entries, `CONNECT_DEFERRED` on control signals and `Engine.time_scale` writes; `physics/common/physics_interpolation` stays false; no `Vector3(` built from `s` outside `world_frame.gd` in view code.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Lints are Python 3 stdlib (ADR-0009), not GDScript. `godot --headless --import` must run before the GUT run (class cache for `class_name GameRoot` and the cores).
**Control Manifest Rules (this layer)**:
- Required: `forbid` rules registered in `tools/ci/lint_rules.json` (`_process`/`_physics_process` outside `game_root.gd`, `CONNECT_DEFERRED` on control signals, `Engine.time_scale` writes, `SceneTree.paused`); `project_setting` lint for no `[autoload]` entries and `physics_interpolation=false`; the ADR-0013 Vector3-from-`s` rule is ADVISORY; allowlists by explicit rule field.
- Forbidden: inline ignore comments; lints written in GDScript or shell; disabling a failing rule to pass CI.
- Guardrail: full CI run at most 5 minutes with a warm cache.

## Acceptance Criteria
- [ ] The lint finds no `_process`/`_physics_process` override outside `GameRoot`, no `[autoload]` entry, no `CONNECT_DEFERRED`, no `Engine.time_scale` write (ADR-0002 VC-3); each rule has a failing fixture and a passing fixture
- [ ] The `project_setting` lint asserts `physics/common/physics_interpolation` is `false` and fails on `true` (ADR-0013 Decision 2)
- [ ] ADVISORY lint: a `Vector3(` built from `s`, `s_offset` or `snapshot.s` outside `world_frame.gd` in view code is reported, and the same text in `world_frame.gd` is not (ADR-0013 lint VC)
- [ ] A rule-keyword lint reports a `GameRoot` containing logic keywords from the agreed list (guard that `GameRoot` stays wiring only) (ADR-0002 Risks)
- [ ] `godot --headless --import` runs before the GUT run in the CI entry command, and a run without it is documented as invalid for `class_name GameRoot` tests (ADR-0002 VC-5)

## Implementation Notes
Add the rules to `tools/ci/lint_rules.json` and fixtures under `tests/fixtures/lint/composition_root/` (data files, not inline magic strings). `tools/ci/lint_runner.py` is created by test-harness-ci; this story only adds rules and tests. Comments and strings are stripped by the runner before matching, so fixtures include a commented-out violation that must not fire. The rule-keyword list for the "GameRoot holds no rules" guard is agreed in review and kept in the rule file.

## Out of Scope
- test-harness-ci: the lint runner, `run_ci.py` and the GUT harness
- Story 001/002: the code the lints guard

## QA Test Cases
- **AC-1**: forbidden constructs
  - Given: fixture files with each violation, one allowed `GameRoot` file, one commented violation
  - When: the runner executes the rules
  - Then: violations reported with rule id and line; allowed and commented ones are not
- **AC-2**: project setting
  - Given: two `project.godot` fixtures
  - When: linted
  - Then: `false` passes, `true` fails
- **AC-3**: advisory Vector3 rule
  - Given: view-code and `world_frame.gd` fixtures
  - When: linted
  - Then: advisory finding only in view code
- **AC-4**: keyword guard on a fixture `GameRoot`
- **AC-5**: CI entry order
  - Given: `run_ci.py` argument plan
  - When: dry-run listing
  - Then: import step precedes the test step

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/composition_root/composition_root_lint_rules_test.gd` (or a pytest file beside the lint runner if the harness defines one)
**Evidence**: `tools/ci/tests/test_lint_composition_root.py` (rule registration, fixtures, keyword guard, import-before-suite order, docstring), fixtures `tools/ci/tests/fixtures/forbidden_game_root_logic_keywords/`; pre-existing rules and fixtures cover the forbidden constructs. Fixtures live in `tools/ci/tests/fixtures/` (the runner convention), not `tests/fixtures/lint/`.

## Dependencies
- Depends on: test-harness-ci (lint runner and rule table); Story 001
- Unlocks: Story 010
