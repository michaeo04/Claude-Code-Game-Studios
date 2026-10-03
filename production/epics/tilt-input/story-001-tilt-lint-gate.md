# Story 001: Tilt Input CI lint gate (AC-37a-f)

> **Epic**: Tilt Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-024`, `TR-tilt-input-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (lint framework, Decision 5); ADR-0005: Sensor source and input pipeline (Decision 7)
**ADR Decision Summary**: Lint rules live in `tools/ci/lint_rules.json` and run through `tools/ci/lint_runner.py` (comments and strings stripped, kinds `forbid`, `only_in`, `project_setting`, `custom`). ADR-0005 Decision 7 lists what CI must fail on for sensors, the tap catcher and the editor-only source.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No engine API; Python 3 stdlib only. Each rule needs one passing and one failing fixture under `tools/ci/tests/` (a rule without both fails the runner self-check). Deliberately invalid GDScript fixtures live as `.txt` or under a `.gdignore` folder.
**Control Manifest Rules (this layer)**:
- Required: `get_gravity`/`get_accelerometer`/`get_gyroscope`/`get_magnetometer` only in `tilt_input.gd` (`only_in` rule); lints are BLOCKING unless the rule says ADVISORY.
- Forbidden: reading sensors outside `tilt_input.gd`; `Input.is_action_*` in gameplay; `OS.is_debug_build()` in dev-input code.
- Guardrail: the whole CI run stays at most 5 minutes; a rule whose scope has no file yet passes with a note.

## Acceptance Criteria
- [ ] **AC-37a**: the sensor pattern `\bInput\.(get_(gravity|accelerometer|gyroscope|magnetometer)|get_joy_(gravity|gyroscope|accelerometer)|set_gravity)\b` matches only the `TiltInput` node file; `Input.call(` and `Engine.get_singleton` do not appear in the tilt files.
- [ ] **AC-37b**: no `Input.`, `Engine.`, `Time.` or `OS.` in `TiltCore` or `TiltMath`, and neither extends Node.
- [ ] **AC-37c**: no `InputEventScreen*`, `InputEventMouse*`, `_input(`, `_unhandled_input(` or `Input.is_mouse_button_pressed` in the tilt files.
- [ ] **AC-37d (action check only)**: `project.godot` defines the actions `steer_left` and `steer_right`. The orientation and sensor-flag checks are Platform Services' manifest lint (its AC-13, entries tagged `tilt`); this story only wires the tag.
- [ ] **AC-37e**: `TiltConfig.unvalidated()` is not referenced from `src/` (its definition site excluded).
- [ ] **AC-37f**: `poll(` is called on a `TiltCore` only in the driver file, and no `_physics_process` in it calls it.
- [ ] The ADR-0005 Decision 7 rules also exist: the tap catcher does not read `InputEventMouseButton`; the editor-only synthetic source is reachable only behind `OS.has_feature("editor")`.

## Implementation Notes
Scan `src/` only (`prototypes/` and `tests/` excluded), after the stripper removes comments and strings. Rules are best-effort and cannot see aliasing such as `var i := Input`. Register each as its own result (37a-37f). The `steer_left`/`steer_right` check is a `project_setting`-style rule. This gate is BLOCKING and must exist before the first Tilt Input story is marked Done (GDD gate policy 4); until `src/` has tilt files the rules pass with a note. `tools/ci/lint_runner.py` itself comes from the test-harness-ci epic.

## Out of Scope
- Story 013: the `TiltInput` node file the rules scan.
- Platform Services epic: the orientation and sensor-flag manifest checks (AC-37d first half).

## QA Test Cases
- **AC-37a..f**: one passing and one failing fixture per rule
  - Given: a fixture file containing the banned token (failing) and a clean copy (passing), plus a comment/string containing the token
  - When: `python tools/ci/lint_runner.py` runs over the fixtures
  - Then: the failing fixture reports the rule id with the file and line; the clean one and the comment/string one pass
  - Edge cases: CRLF files; token inside a triple-quoted string; sensor call inside `tilt_input.gd` passes while the same call in another file fails; a rule with no files in scope passes with a note

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tools/ci/tests/` Python unittest cases (run in `run_ci.py` step 4a) plus a green `python tools/ci/lint_runner.py`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: test-harness-ci (lint runner and `lint_rules.json` framework)
- Unlocks: Story 002 to Story 013 can be marked Done (gate)
