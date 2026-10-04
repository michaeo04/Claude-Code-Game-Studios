# Story 005: Neutral capture mechanics and pending capture

> **Epic**: Tilt Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-009`, `TR-tilt-input-010`, `TR-tilt-input-023`, `TR-tilt-input-025`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; ADR-0009: Test framework and CI (secondary)
**ADR Decision Summary**: Cores are `RefCounted` with injected seams and an injected microsecond clock; fixtures use explicit stamps and deterministic assertions.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. Integer-microsecond comparisons make the closed window exact; float error in `asin` is about 1e-14 (boundary tests use the pure function, Story 007).
**Control Manifest Rules (this layer)**:
- Required: time only from the injected `clock_us`; ring buffer is `PackedFloat64Array` + `PackedInt64Array` with a head index, capacity 256, `BUFFER_AGE` 1.0 s, oldest overwritten; durations converted once with `roundi(x * 1e6)`.
- Forbidden: persisting `phi0`, `phi_f`, `phi_stop` or the pending/stale flags (no persistence, neutral resets each launch); `Time.`/`Input.` in the core.
- Guardrail: no allocation per poll beyond the fixed buffers.

## Acceptance Criteria
- [ ] **AC-12 [C]**: a fresh core fed 60 polls where the pose is 5 for every stamp up to `t - 250000` and 30 after, then `run_reset` from Menu at `t`: `phi0 = 5.000`, and the next poll at 5 gives `steer` 0. Repeat with -5 and -30: `phi0 = -5`.
- [ ] **AC-13 [C]**: `live_core(15)` gives `phi0 = 15` and `steer` 0; `live_core(-15)` gives `phi0 = -15` and `steer` 0.
- [ ] **AC-14 [C]**: four samples at 0 and four at 10 in the window (median 5). A ninth sample at 10 stamped `t - 550000` (appended first) or `t - 250000` (appended last) gives `phi0 = 10` (included); stamped `t - 550001` or `t - 249999` gives `phi0 = 5` (excluded). Each case separate.
- [ ] **AC-15 [C]**: each case `live_core(pose)` then 120 ticks at the same pose: rest 35 gives `phi0 = 35`, `steer` 0, no error; rest 60 gives `phi0 = 60`, one `POSTURE_UNSUPPORTED`, `steer` 0, and a pose of 70 then gives a steady `steer` 0.361702; rest -60 gives `phi0 = -60`, one error; rest 90 (g = (9.81,0,0)) gives `phi0 = 70`, one error and steady `steer` 0.787234; with sensitivity 0.5 (`FS_eff` 50, `L_eff` 20) rest 35 gives `phi0 = 35`, one error, `steer` 0.
- [ ] **AC-17 [C]**: 17a an empty buffer, 17b only samples younger than 0.25 s, 17c only samples older than 1.0 s, 17d four samples in the window: in each case a capture event sets `neutral_pending`, `steer` is 0, four further valid samples at 7 keep pending true and `steer` 0, the fifth gives `phi0 = 7`, `steer` 0, pending false; 17e samples 7,7,90,7,7 give `phi0 = 7`; 17f with pending true after three samples at 7, a second capture event discards them: four further samples at 9 keep pending true, the fifth gives `phi0 = 9`.
- [ ] **AC-18 [C]**: a capture event while the state is Acquiring or Unavailable sets pending; the capture takes the median of the first `N_min` valid samples (`steer` 0, `phi_f` 0), with exactly one `availability_changed(true)` from the state change.
- [ ] **AC-19 [C]**: `live_core(5)` then N polls of 15: N=1 gives `phi_f` 2.8347 and `steer` 0.056797; N=2 gives 4.8659 and 0.143230; N=3 gives 6.3213 and 0.205161.
- [ ] **AC-21 [C]**: 21a two `run_resumed` events at `t` and `t + 1.5` s with pose 5 until `t + 0.5` and 12 afterwards: the first `phi0 = 5`, the second `phi0 = 12` and `phi_f = 0`; 21b two events at the same `t` give the same `phi0`.
- [ ] **AC-26 [C]**: 600 samples at 1 ms stamps leave `sample_count` at 256; 172 samples at pose A then 300 at pose B in the same burst and a `run_resumed` give `phi0` = B.
- [ ] **AC-45 [C]**: a fresh core has `neutral_stale` true and `neutral_pending` true, `steer` 0; `run_reset` from Boot then five valid samples give `phi0` from their median; both flags are false afterwards.

## Implementation Notes
Capture sets `phi0` to the median of samples in the closed window `[t - G - W, t - G]` (F2); `phi0 = clamp(m, -PHI_MAX, +PHI_MAX)`; when `|m| > L_eff = max(0, PHI_MAX - FS_eff)` log one `POSTURE_UNSUPPORTED` (the rest pose beyond `L_eff` loses range, it adds no bias). Fewer than `N_min` samples in the window, or not Live, sets `neutral_pending`; a pending capture takes the median of the first `N_min` valid samples after the event, `steer` is 0 until then; a new capture event while pending restarts the accumulator. After a capture the filter starts at 0. At construction `neutral_pending` and `neutral_stale` are true. This story provides `on_run_reset(previous_phase)` for the Boot/Menu always-capture path and `on_run_resumed()`; the Hit/Paused re-anchor policy is Story 007. Build the shared test helper `live_core(pose, step_us = 16667)` here: a fresh core, 60 polls at `pose` from stamp 0, then `run_reset` from Menu at the last stamp; result `phi0 = pose`, `phi_f = 0`, Live, pending false, stale false. Use the filter and F4 from `TiltMath` (Story 002) for the steer assertions; the full pipeline contract is Story 006.

## Out of Scope
- Story 007: conditional re-anchor from Hit/Paused, `stop_us`/`phi_stop`, AC-16, AC-22, AC-23.
- Story 006: the published-output contract and BAD_OUTPUT handling.
- Story 010: app-lifecycle clearing of the buffer.

## QA Test Cases
- **AC-12/13/14**: Given a built buffer with explicit stamps; When `run_reset` from Menu at `t`; Then `phi0` is the window median; window ends included, one microsecond outside excluded
- **AC-15**: Given `live_core(pose)` and 120 ticks; Then `phi0`, `steer` and error counts as listed (pass-through, not bias)
- **AC-17**: Given the five buffer states; When a capture event arrives; Then pending true, `steer` 0 until the fifth valid sample, then median; outlier ignored; re-entry restarts the count
- **AC-18/45**: Given Acquiring/Unavailable/fresh core; When a capture event and valid samples; Then pending then median, flags cleared, one `availability_changed(true)`
- **AC-19**: oracles after 1, 2, 3 polls of a 10 deg step (1e-4 steer, 1e-3 deg)
- **AC-21/26**: two resumes independent; 256-sample overwrite keeps the newest

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tilt_input/tilt_core_neutral_capture_test.gd`
**Evidence**: `tests/unit/tilt_input/tilt_core_neutral_capture_test.gd` (passing). Gap: AC-18 Unavailable half needs the Unavailable transition of Story 009; only Acquiring is proven.

## Dependencies
- Depends on: Story 002, Story 003, Story 004
- Unlocks: Story 006, Story 007, Story 010
