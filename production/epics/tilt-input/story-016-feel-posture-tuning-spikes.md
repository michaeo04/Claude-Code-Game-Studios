# Story 016: Spikes V-2 to V-9 and AC-41, noise, jolt, feel and posture evidence

> **Epic**: Tilt Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: 4 h (plus tester time)
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-022`, `TR-tilt-input-011`, `TR-tilt-input-013`, `TR-tilt-input-023`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0005: Sensor source and input pipeline; ADR-0009: Test framework and CI (AC-41 fixture traces)
**ADR Decision Summary**: Every default is a guess until measured on a device; the sensor source is `get_gravity()` only and a revision (accelerometer fallback, native plugin) returns only through a new ADR if the spikes show a need.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: All numbers (noise, jolt, vehicle error, device-sleep clock behavior) are unmeasured on 4.7.2/Android and not covered by the engine reference. Device matrix: mid-tier Android, a low-end Android without a gyroscope, a foldable or tablet if in scope.
**Control Manifest Rules (this layer)**:
- Required: tilt tuning values are locked only after V-1 (Story 014) and P-1/P-2 (Story 015); evidence in `production/qa/evidence/tilt-input/` with one file per criterion (device, date, raw log, result).
- Forbidden: averaging away a failure; shipping unmeasured defaults as locked.
- Guardrail: recorded traces used as test fixtures stay small (text, in `tests/`).

## Acceptance Criteria
- [ ] **V-2**: rest noise (peak-to-peak and rms of `phi`) per pitch at 0, 30, 60, 85, above 90 deg and side-lying, 5 testers for 60 s each; hypothesis: p99 of `|phi - median phi|` at most `DZ` at every supported pitch, re-checked at sensitivity 2; record where the formula stops working.
- [ ] **V-3**: jolt of the Menu-Play tap and the pause tap, at least 59 taps per tap type over at least 5 testers, zero failures required; hypothesis `|phi_f|` below `DZ` within `G` plus one frame for at least 95% of taps.
- [ ] **V-4**: 5-point lag scale (1 = not noticeable) at tau 0.02, 0.05 and 0.10 in a blind A/B, 5 testers; pass: no tester above 2 at the default tau; full lock reached in at least 90% of trials at pitch 30 and 60. Lead sign-off required.
- [ ] **V-6**: (i) 30 s in the background then foreground: the age of the last stale vector accepted is 0 and no `steer` above `DZ` within `SETTLE`; (ii) posture drift over a 10-minute session per tester: median shift of the resting pose against `phi0` at most 5 deg; (iii) whether a motion permission prompt appears (none expected).
- [ ] **V-7**: `TYPE_GRAVITY` exists on the target devices; latency difference against raw accelerometer; vehicle test with a reference log of at least 2 m/s^2 lateral acceleration; hypothesis `get_gravity()` error at most `2 * DZ`.
- [ ] **V-8**: zero spurious `sensor_lost` pauses over 30 minutes of walking and 30 minutes of bus travel per tester; add a `sensor_lost` pause counter request to Playtest Telemetry.
- [ ] **V-9**: scripted restarts, at least 20 per case (death while holding a steady 25 deg, phone put down and picked up at another posture, posture change while paused, restart within 0.3 s of a pause): report counts of recaptures and inherits per case.
- [ ] **AC-41 [I]**: recorded rest traces per posture (from V-2, as fixture files) fed through `TiltCore` give `steer == 0` on at least 99% of ticks after warm-up for every trace whose p99 of `|phi - phi0|` is at most `DZ`; a posture-drift trace is added.

## Implementation Notes
Hypotheses are provisional and thresholds unmeasured: report every result, adjust knob defaults (`TILT_FULL_SCALE`, `DEAD_ZONE`, `FILTER_TAU`, `NEUTRAL_*`, `REANCHOR_*`, `DROPOUT_HOLD`) through `TiltConfig` data and a GDD revision, not code. Tester counts are exploratory. AC-41 is deferred until the V-2 traces exist; the trace player is an integration test that reads fixture files.

## Out of Scope
- Story 014: V-1/V-5; Story 015: P-1/P-2/P-3; Ball Movement GDD: the `|theta|` drift criterion.

## QA Test Cases
- **V-2 / V-3 / V-4 / V-6 / V-7 / V-8 / V-9**
  - Setup: debug APK with a trace logger and the knob values under test, testers per the protocol above
  - Verify: the measured quantity named in each criterion, written to its own evidence file
  - Pass condition: the stated hypothesis threshold; otherwise a recorded finding with the proposed knob change
- **AC-41**
  - Setup: V-2 trace files under `tests/` fixtures
  - Verify: `steer == 0` rate after warm-up per qualifying trace
  - Pass condition: at least 99%

## Test Evidence
**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/tilt-input/v2-noise.md` ... `v9-reanchor.md` (one file per criterion) with lead sign-off; `tests/integration/tilt_input/tilt_core_rest_traces_test.gd` for AC-41
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 014, Story 015
- Unlocks: locking the tilt tuning defaults; Settings & Accessibility sensitivity range review
