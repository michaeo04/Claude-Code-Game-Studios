# Story 013: TiltInput node, ProjectSettings and log sink

> **Epic**: Tilt Input
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-001`, `TR-tilt-input-016`, `TR-tilt-input-017`, `TR-tilt-input-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0005: Sensor source and input pipeline (primary); ADR-0006: Android platform integration; ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: `TiltInput` (`class_name TiltInput extends Node`, file `tilt_input.gd`, no `_process`) reads `Input.get_gravity()` once per `poll()` and passes the raw `Vector3` to `TiltCore`. Required settings: `enable_gravity = true`, orientation 1; the other sensor flags stay false. Only when `OS.has_feature("editor")` is true does `GameRoot` replace `sample_source` with a synthetic arrow-key gravity vector.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0005 Verification Required (1), (2), (9): `Input.get_gravity()` behaviour on Android 4.7.2, the setting names and defaults (sensor flags default false and need a restart in the editor), and that a missing flag reads as the zero vector (Platform Services' manifest check tells it apart). Android gravity is screen-relative in every orientation. Not covered by the engine reference modules (stop at 4.6). Use `get_setting` with an explicit default.
**Control Manifest Rules (this layer)**:
- Required: `TiltInput` interface is `poll()` plus read-only `steer`, `valid`, `input_source`; receives `clock_us` by injection; the production log sink allows at most one message per code per 1.0 s of injected clock; sensors read only in `tilt_input.gd`.
- Forbidden: `Time.` in `TiltInput`; `_process`/`_physics_process` in the node; `OS.is_debug_build()` for the editor source; reading touch; any sensor flag besides `enable_gravity` true.
- Guardrail: `poll()` p95 at most 0.1 ms; ring buffer about 4 KB.

## Acceptance Criteria
- [x] **AC-28 [I]**: the `TiltInput` node passes `sensors_enabled` from `ProjectSettings` (`input_devices/sensors/enable_gravity`) to the core in a scene tree: false gives Live `FALLBACK` (debug) or Unavailable (release) with one `SENSORS_DISABLED`; true gives Acquiring with no error.
- [x] **AC-42 [C]**: the production sink lets at most one message per code per 1.0 s of injected clock through and does not let none through: one at t = 0; none at 999999 us; one at 1000000 us; two different codes at the same stamp both pass; the level is preserved.
- [x] `poll()` reads `Input.get_gravity()` once per call, passes the raw `Vector3` unfiltered, and the node exposes read-only `steer`, `valid`, `input_source` getters that return the core's values (a test with an injected `sample_source` double and a scene-tree instance).
- [x] Editor-only steering: a synthetic `sample_source` turns left/right arrow keys into a fixed-roll gravity vector, is attached only behind `OS.has_feature("editor")`, and `TiltCore`, `valid` and `input_source` (still `SENSOR`) are unchanged. Lint 37a/37f (Story 001) pass on the node file.
- [x] `project.godot` carries `display/window/handheld/orientation = 1`, `enable_gravity = true`, no other sensor flag true, and the actions `steer_left`/`steer_right` (smoke check, with Platform Services' manifest lint).

## Implementation Notes
Do not smooth or filter in the node (`TiltCore` owns the pipeline). `poll()` guards non-finite and oversized vectors via the core's validity rule (`G_MIN` 3 m/s^2). The node reads `ProjectSettings` at boot, passes `sensors_enabled`, `is_portrait` (from the orientation, a diagnostic only) and `is_debug` to the core; the rate-limited production sink wraps the core's `log_sink`. `GameRoot` calls `poll()` once per rendered frame in every phase before Ball Movement steps (composition-root epic); the node holds no `_process`. The synthetic source must not be reachable in an exported APK, including a debug APK. `project.godot` already exists untracked; the settings edit belongs to this story and Platform Services' manifest lint owns the check.

## Out of Scope
- Story 014: V-1 sign/units on a real device; Story 015: P-1/P-2 timings.
- Composition-root epic: `GameRoot` calling `poll()` and the `_wire()` rows; Platform Services epic: the boot manifest check.

## QA Test Cases
- **AC-28 [I]**: Given a scene-tree test that sets the project setting true/false (or injects it); When the node is built; Then core state and the `SENSORS_DISABLED` log as listed
  - Edge cases: setting missing reads as default false
- **AC-42**: Given a fake clock; When the same code is logged at 0, 999999 and 1000000 us, and two codes at one stamp; Then pass counts 1, 0, 1 and 2
- **Node interface**: Given a stub `sample_source`; When `poll()` runs; Then the getters match the core; no filtering in the node
- **Editor source**: Given a feature-tag stub; Then the synthetic source is used only when the tag is true

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/tilt_input/tilt_input_node_test.gd` and `tests/unit/tilt_input/tilt_log_sink_test.gd` (AC-42)
**Evidence**: `tests/integration/tilt_input/tilt_input_node_test.gd` (AC-28, node interface, editor-only source, project.godot smoke) and `tests/unit/tilt_input/tilt_log_sink_test.gd` (AC-42) pass in CI.
**Status**: [x] Created

## Dependencies
- Depends on: Story 001, Story 006, Story 008, Story 011; test-harness-ci; platform-services (manifest lint for the settings)
- Unlocks: Story 014, Story 015, Story 016; composition-root `GameRoot` tick wiring
