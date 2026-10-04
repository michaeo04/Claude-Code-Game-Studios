# Story 007: Capture policy, conditional re-anchor and run-stop recording

> **Epic**: Tilt Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-011`, `TR-tilt-input-025`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; ADR-0009: Test framework and CI (secondary)
**ADR Decision Summary**: Cores are `RefCounted` with injected seams; the policy is a pure function (`should_reanchor`) plus core events, tested without a scene tree.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No `nextafter` in GDScript: exact boundary cases (offset 12 vs 12.01, spread 3.0) are tested on the pure function because `asin` output carries about 1e-14 of float error.
**Control Manifest Rules (this layer)**:
- Required: injected clock and integer-microsecond comparisons; `TiltMath` pure functions, no engine singletons; no persistence (neutral resets each launch).
- Forbidden: `Time.`/`Input.` in the core; recapturing the neutral with continuous recentering (the neutral is fixed).
- Guardrail: no allocation per event.

## Acceptance Criteria
- [ ] **AC-16 [C]** (unless a case says otherwise: `live_core(5)`, 5 polls at pose 5, `on_run_stopped()`, 60 polls at the stated pose, `run_reset` at the last stamp): **16a** pose 12: from Hit and from Paused `phi0` stays 5, the filter is not reset, steady `steer` 0.234043; **16b** pose 20: `phi0 = 20` and `phi_f = 0`; **16c** window alternating 20/22 (spread 2) recaptures `phi0 = 21`, alternating 20/24 (spread 4) inherits; **16d** `run_reset` from Menu at pose 6, from Boot, with unknown `previous_phase`, and `run_resumed` at pose 6 each give `phi0 = 6`; **16e** after app background, foreground and 1.0 s at pose 12, `run_reset` from Hit and from Paused captures (`phi0 = 12`) and the stale flag clears; **16f** post-stop window with four samples (not stale) inherits, pending stays false; **16h** steady death tilt (`live_core(5)`, 60 polls at 25, `on_run_stopped()`, 60 polls at 25, `run_reset` from Hit): `phi0` stays 5, filter not reset; **16i** `on_run_stopped()` from Paused at P, 18 polls at pose 20, `run_reset` at P + 300006 us: window holds 4 samples, `phi0` stays 5; with 60 polls `phi0 = 20`; **16j** `live_core(5)` with sensitivity 2 (`RA_eff` 6.25): pose 12 recaptures `phi0 = 12`; **16k** `live_core(70)` (one `POSTURE_UNSUPPORTED`), `on_run_stopped()` at 70, 60 polls at 90, `run_reset` from Hit: `phi0` stays 70.
- [ ] **AC-16g [M]**: `should_reanchor(n, spread, median, phi0, phi_stop, n_min, ra_spread, ra_offset, fs_eff)` with `n_min` 5, `ra_spread` 3.0, `ra_offset` 12, `fs_eff` 25: offset from `phi0` exactly 12 false, 12.01 true (`phi_stop` far); offset from `phi_stop` exactly 12 false, 12.01 true (`phi0` far); spread 3.0 true, 3.01 false; `n` 4 false, 5 true; unknown `phi_stop` (NaN) false; offset -12.01 true; median 90 with `phi0` 70 false; `fs_eff` 12.5 gives `RA_eff` 6.25: 6.26 true, 6.25 false.
- [ ] **AC-22 [C]**: `run_started` leaves `phi0`, `phi_f`, state, sample count, `stop_us` and `phi_stop` unchanged; `run_paused` and `run_ended` (`on_run_stopped`) leave `phi0`, `phi_f`, state and sample count unchanged and record `stop_us` and `phi_stop` (median of the pre-stop window, or unknown with fewer than `N_min` samples).
- [ ] **AC-23 [C]**: samples at 2 deg, a 10 s clock gap, then 0.6 s at 8 deg: `run_resumed` gives `phi0 = 8` and the buffer holds only post-gap samples.

## Implementation Notes
Always capture on `run_reset` from Boot, Menu or an unknown previous phase and on `run_resumed`. `run_reset` from Hit/Paused: capture if `neutral_stale`; otherwise conditional re-anchor. On `run_ended`/`run_paused` record `stop_us` and `phi_stop` (median of `[stop_us - G - W, stop_us - G]`, unknown with too few samples). Re-anchor window is the F2 window with its start clamped to `stop_us` (post-stop samples only). `should_reanchor`: recapture iff `N >= N_min`, `spread <= RA_S`, `phi_stop` known, `|m_c - phi0| > RA_eff` and `|m_c - phi_stop| > RA_eff`, with `m_c = clamp(m, -PHI_MAX, PHI_MAX)` and `RA_eff = min(REANCHOR_OFFSET, REANCHOR_FS_CAP * FS_eff)` (cap 0.5). A re-anchor with too few samples inherits and never sets pending. The age purge at every append handles clock gaps (device sleep behavior is Open Question 26, not tested here).

## Out of Scope
- Story 005: the capture mechanics themselves; Story 010: app lifecycle events that set `neutral_stale`; Story 012: the adapter that supplies `previous_phase`.
- Story 016: V-9 false re-anchor rates on a device.

## QA Test Cases
- **AC-16a-k**: Given the stated setups; When `run_reset`/`run_resumed` fires; Then `phi0`, `phi_f` reset or not, pending false, as listed (Hit and Paused separately)
  - Edge cases: steady death tilt inherits; post-stop window excludes pre-stop samples; clamped median at 90
- **AC-16g**: table-driven pure function, one row per boundary listed
- **AC-22**: Given each lifecycle event; Then unchanged fields and recorded `stop_us`/`phi_stop`
- **AC-23**: Given a 10 s gap; Then `phi0` 8 from post-gap samples only

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tilt_input/tilt_core_capture_policy_test.gd`
**Evidence**: `tests/unit/tilt_input/tilt_core_capture_policy_test.gd` (passing). Gap: AC-16e needs `on_app_backgrounded` (Story 010); only the stale routing from construction is proven.

## Dependencies
- Depends on: Story 002, Story 005
- Unlocks: Story 010, Story 012
