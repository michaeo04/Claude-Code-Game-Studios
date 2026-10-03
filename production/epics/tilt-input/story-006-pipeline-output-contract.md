# Story 006: Pipeline order and the published output contract

> **Epic**: Tilt Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-002`, `TR-tilt-input-007`, `TR-tilt-input-008`, `TR-tilt-input-017`, `TR-tilt-input-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0005: Sensor source and input pipeline (primary); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: `TiltCore` owns the whole pipeline (neutral, dead zone, filter); the node does not smooth or filter. The interface is `poll()` plus read-only `steer`, `valid`, `input_source`, published by pull.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: ADR-0005 Verification Required (1)-(3): gravity units, screen-relative axes on Android and the ~50 Hz refresh are unverified on 4.7.2 (device story 014). `Vector3` is float32: (1e30,0,0) is finite and `length_squared` overflows, (1e200,0,0) becomes INF.
**Control Manifest Rules (this layer)**:
- Required: pipeline order validity, roll F1, subtract neutral, low-pass F3, then dead zone + scale + clamp + curve F4; `steer > 0` when the right edge is lowered; publish by pull, no per-frame signal.
- Forbidden: smoothing or filtering in the `TiltInput` node; any `Input.`/`Engine.`/`Time.` in `TiltCore`.
- Guardrail: `poll()` p95 at most 0.1 ms.

## Acceptance Criteria
- [ ] **AC-2b [C*]**: with `live_core(0)`, a pose 10 deg above neutral gives `steer > 0` with sign +1 and `< 0` with -1.
- [ ] **AC-5 [C]**: `live_core(0)`, constant pose 10: `phi_f` after 1, 3, 6 and 12 ticks is 2.8347, 6.3213, 8.6467 and 9.8169.
- [ ] **AC-9 [C]**: `live_core(0)`, alternating +-4 deg from the first tick gives `steer` exactly 0 on all 120 ticks (max `|phi_f|` 1.1339).
- [ ] **AC-10a [C]**: `live_core(0)`, 60 ticks at 10 deg give `steer` 0.361702; Acquiring and Unavailable give 0.
- [ ] **AC-10b [C*]**: with FS = 0 (`dz_eff` 0), a poll equal to the neutral gives `phi_f` 0 and F4 computes 0/0 = NaN: `steer` 0, `phi_f` reset to 0 and one `BAD_OUTPUT`; at `phi_f` 5 it gives `steer` 1 and no error.
- [ ] **AC-20 [C]**: `live_core(0)`, holding 12 deg gives `steer` 0.446809 after 120 ticks and after 1800 ticks (difference below 1e-4: no recentering).
- [ ] **AC-25 [C]**: a poll 500000 us after the previous uses `dt = 0.1` (`phi_f` 8.6466 from a 10 deg step at 0); the first poll uses `dt = 0`, is accepted at stamp 0 and appends; a second poll with the same stamp appends nothing and leaves `phi_f` unchanged; stamps 100, 200, 150 (ignored, `previous_now` stays 200), 250 give `dt` 0, 100 us, 0, 50 us.
- [ ] **AC-35 [C]**: a non-portrait boot logs one `NOT_PORTRAIT` error and the `steer` for a 10 deg pose is identical with `is_portrait` true and false.
- [ ] **AC-46 [C]**: 46a reading `steer` twice without a poll returns the same value and emits no signal; 46b a fed vector (1e30,0,0) gives a finite `steer` and no error; 46c (1e200,0,0), which becomes INF in a float32 `Vector3`, is an invalid sample (AC-3) and never reaches F1.

## Implementation Notes
Pipeline per GDD rule 5. The dead zone acts on the filtered signal. `steer` is never NaN/INF: a bad value becomes 0, the filter state resets to 0 and one `BAD_OUTPUT` is logged. In Acquiring and Unavailable `valid` is false and `steer` is 0; while a capture is pending `steer` is 0. The roll axis is screen-relative on Android in every orientation, so no axis remap and no sign flip in reverse portrait; `NOT_PORTRAIT` is diagnostic only (F1 still uses the screen-relative x). `SENSOR_SIGN` (expected -1) comes from `TiltConfig`; the fixtures use +1. A valid sample uses the `dt` of its own poll; invalid polls do not update the filter. Entering Live from Acquiring/Unavailable without a capture starts the filter at the current relative angle. Oracles use ticks of +16667 us.

## Out of Scope
- Story 005: capture and `live_core`; Story 009: invalid-sample hold; Story 011: FALLBACK steering.
- Story 014: device check that the sign is right (V-1); Ball Movement epic: AC-40 (end-to-end sign).

## QA Test Cases
- **AC-2b/10a**: Given `live_core(0)`; When a 10 deg pose is held with sign +1 / -1; Then `steer` positive / negative; 0.361702 after 60 ticks; 0 while not Live
- **AC-5/9/20**: oracles at 1e-3 deg / 1e-4 steer; alternation stays exactly 0; no drift at 1800 ticks
- **AC-10b**: unvalidated config FS 0; Then BAD_OUTPUT once, steer 0; infinite quotient clamps to 1 without error
- **AC-25**: explicit stamp sequences; Then the dt values and sample counts stated
- **AC-35/46**: `is_portrait` false logs once, same steer; repeated getter reads equal; float32 overflow cases
  - Edge cases: no `availability_changed` or other signal on a getter read

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tilt_input/tilt_core_pipeline_output_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 005
- Unlocks: Story 008, Story 009, Story 011, Story 012
