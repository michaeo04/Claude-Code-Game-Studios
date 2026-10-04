# Story 008: Availability states, start timeout and availability signal

> **Epic**: Tilt Input
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-012`, `TR-tilt-input-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0005: Sensor source and input pipeline (primary); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: One sensor source; with no valid sample within `SENSOR_START_TIMEOUT` (2.0 s) after boot the device is "not supported" (Menus gates Play). The unwired fallback is built and unit-tested in `TiltCore` but no MVP driver wires it.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: ADR-0005 Verification Required (9): the boot manifest check, not this core, tells "sensor flag missing" from "no sensor" (both read as the zero vector). Note ADR-0005 Decision 1 says Unavailable after the timeout while the GDD and its ACs (AC-29, AC-48) keep the core's timeout to Live `FALLBACK` (no driver wires it, Menus requires `input_source == SENSOR`); implement the GDD ACs and do not change them without a `/propagate-design-change`.
**Control Manifest Rules (this layer)**:
- Required: if no valid sample arrives within `SENSOR_START_TIMEOUT` after boot, `valid` is false and Menus gates Play; `availability_changed(available: bool)` emitted whenever `valid` changes (none at construction).
- Forbidden: `Time.` in the core; `OS.is_debug_build()` in dev-input code (the constructor gets `is_debug` injected; ADR-0005 Decision 6 gates editor input by `has_feature("editor")`).
- Guardrail: state transitions allocate nothing.

## Acceptance Criteria
- [ ] **AC-28 [C]**: `sensors_enabled = false` gives Live with `FALLBACK` (debug) or Unavailable (release), each with one `SENSORS_DISABLED` error and no `availability_changed`; `true` gives Acquiring with no error.
- [ ] **AC-29 [C]**: first poll at stamp 0 with no valid sample; at 1999999 us the state is Acquiring, `valid` false, `steer` 0; with no valid sample at 2000000 us (inclusive) the state is Live `FALLBACK` (any build) with exactly one `SENSOR_TIMEOUT` and one `availability_changed(true)`; a valid sample at exactly 2000000 us gives Live `SENSOR` instead; an every-poll vector of (0,-1,0) (g units) ends the same way as no sample.
- [ ] **AC-38 [C]**: `availability_changed` is emitted exactly when `valid` changes value: none at construction (including boot into `FALLBACK`, Unavailable or Acquiring); `true` on Acquiring to Live (`SENSOR` or `FALLBACK`); `false` and `true` around a loss.
- [ ] **AC-47a [C]**: in a release build with `sensors_enabled = false` the state is Unavailable, the fallback source is ignored, and app backgrounded/foregrounded change nothing (never reaches Acquiring or `FALLBACK`).

## Implementation Notes
States per the GDD table: Acquiring, Live (`SENSOR` or `FALLBACK`), Unavailable. `sensor_ever_live` is set by the first valid sample accepted in `SENSOR` mode and never cleared. Timeout is counted from the first poll after any resume settle and compared in integer microseconds; a valid sample at the boundary wins. Timeout with `sensor_ever_live` false enters Live `FALLBACK` (clears `neutral_pending`/`neutral_stale`, one `SENSOR_TIMEOUT`); with it true the timeout leaves Acquiring for Unavailable (Story 010, AC-49). Unavailable from a release-build configuration error ignores every event and never leaves. This story builds the state machine and the `FALLBACK` entry; steering from `fallback_source` is Story 011. The `TiltInput` node reading `ProjectSettings` and passing `sensors_enabled` is Story 013.

## Out of Scope
- Story 009: Live to Unavailable via invalid polls; Story 010: app lifecycle transitions; Story 011: fallback steering and AC-32 table.
- Story 013: Menus-facing node behavior; Menus epic: the "No motion sensor" notice.

## QA Test Cases
- **AC-28**: Given `sensors_enabled` false/true, debug/release; When constructed; Then state, one `SENSORS_DISABLED` (or none), no signal
- **AC-29**: Given explicit stamps 0, 1999999, 2000000; When no valid sample / a valid sample at 2000000; Then Acquiring, then Live `FALLBACK` with one error and one `true`; or Live `SENSOR`
  - Edge cases: g-unit vector (0,-1,0) every poll equals no sample
- **AC-38**: Given each construction mode and transitions; Then signal counts exactly as listed
- **AC-47a**: Given a release core, sensors disabled; When lifecycle events and fallback input arrive; Then state stays Unavailable

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tilt_input/tilt_core_availability_states_test.gd`
**Evidence**: `tests/unit/tilt_input/tilt_core_availability_states_test.gd` (passing; AC-28 [I] half is Story 013)

## Dependencies
- Depends on: Story 004, Story 006
- Unlocks: Story 009, Story 010, Story 011, Story 013
