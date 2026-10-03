# Story 015: Spikes P-1, P-2, P-3, latency, poll cost and background behavior

> **Epic**: Tilt Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 h (plus device time)
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-022`, `TR-tilt-input-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0005: Sensor source and input pipeline; ADR-0006: Android platform integration (secondary)
**ADR Decision Summary**: `poll()` p95 must be at most 0.1 ms over 1000 frames; the end-to-end budget is 100 ms (`L_s` plus tau plus a frame); the sensor refreshes at about 50 Hz so some 60 fps frames reuse a sample.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Sensor rate, OS fusion latency and stale-sample behavior on Android 4.7.2 are unverified (ADR-0005 Verification Required (3)). Background behavior depends on the Platform Services lifecycle model (PS-1/PS-2).
**Control Manifest Rules (this layer)**:
- Required: `poll()` p95 at most 0.1 ms; end-to-end input latency budget 100 ms; spikes P-1 and P-2 recorded before tilt tuning is locked.
- Forbidden: measuring in a debug-only way that changes the code path under test.
- Guardrail: 60 FPS / 16.6 ms frame, 512 MB.

## Acceptance Criteria
- [ ] **P-1**: end-to-end latency (`L_s` plus tau plus a frame) measured with a 240 fps camera, at least 100 samples on 3 devices, plus whether gravity is pre-filtered; hypothesis p95 at most 100 ms.
- [ ] **P-2**: sensor rate and `poll()` cost on the mid-tier Android target over at least 1000 frames; hypothesis p95 at most 0.1 ms.
- [ ] **P-3**: app in the background for 30 s: no steer spike on return, exactly one `availability_changed(false)` and one `true`.
- [ ] Each result is a file under `production/qa/evidence/tilt-input/` (`p1-latency.md`, `p2-poll-cost.md`, `p3-background.md`) with device, date, raw log and result. A miss on P-1 is a tuning finding that sets the `FILTER_TAU` default (F5), not a silent pass.

## Implementation Notes
Time `poll()` with `Time.get_ticks_usec()` around the call inside a temporary profiling harness under `prototypes/` (never in `TiltCore`, which has no `Time.`). Report p50/p95/max. For P-1 film the screen and the phone motion; record `L_s`, tau and frame time separately. P-3 uses the real Platform Services signals; compare with PS-1/PS-2 results. Results feed `FILTER_TAU` (tuning knob, range 0.02-0.10) but do not lock it; locking happens after Story 016.

## Out of Scope
- Story 014: sign and units; Story 016: noise, jolt, feel and posture.
- Platform Services epic: PS-1/PS-2 lifecycle sequences.

## QA Test Cases
- **P-1**
  - Setup: 240 fps camera on 3 devices, phone tilted by hand, frame-count between motion and on-screen ball movement
  - Verify: latency per sample; p95
  - Pass condition: p95 at most 100 ms (hypothesis, otherwise a recorded finding)
- **P-2**
  - Setup: 1000+ frames on the mid-tier target
  - Verify: `poll()` microseconds per frame and the sensor update rate
  - Pass condition: p95 at most 0.1 ms
- **P-3**
  - Setup: run in Menu and in a run, background 30 s, return
  - Verify: `steer` trace and signal log
  - Pass condition: no steer above the dead zone within the settle, exactly one `false` and one `true`

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/tilt-input/p1-latency.md`, `p2-poll-cost.md`, `p3-background.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 013, Story 014; platform-services (lifecycle signals)
- Unlocks: Story 016 (tuning); the first-playable profiling pass
