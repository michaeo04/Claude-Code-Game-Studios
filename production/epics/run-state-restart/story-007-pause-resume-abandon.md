# Story 007: Pause, resume countdown, Paused guard and abandon

> **Epic**: Run State & Restart
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-006`, `TR-run-state-restart-015`, `TR-run-state-restart-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (primary, `app_interrupted` and Back); ADR-0002 (focus-out as primary pause)
**ADR Decision Summary**: Platform Services turns `NOTIFICATION_APPLICATION_FOCUS_OUT` into `app_interrupted`, applied by Run State when sent (between ticks); Back arrives only as `back_pressed` and is turned into `pause_requested(back)`; handlers never send requests from inside a Run State tick or handler.
**Engine**: Godot 4.7.2 | **Risk**: HIGH (Android lifecycle, device spikes PS-1, PS-2, PS-4 verify delivery; this story is the pure core side)
**Engine Notes**: the core only receives requests; focus-out delivery and Back are verified by Platform Services spikes, not here.
**Control Manifest Rules (this layer)**:
- Required: `app_interrupted` applied at send time in Running or Resuming; countdown measured with timestamps, never deltas
- Forbidden: lifecycle handlers sending requests from inside a tick or handler
- Guardrail: `resume_requested` is never guarded and wins same-tick ties; guard restarts on every entry to Paused

## Acceptance Criteria
- [ ] **AC-15**: `progress_for(duration, elapsed)` and the core give (elapsed, remaining, digit, progress): 0 s: 2.0, 2, 0; 0.7 s: 1.3, 2, 0.35; 2.0 s: 0 and the countdown ends; 5 s on the static helper only: remaining clamped to 0; duration 0 or less gives progress 1, no NaN; an interruption at 1.5 s followed by a resume counts the full 2.0 s again; `run_resuming` emitted once per entry
- [ ] **AC-22**: run 1.0 s, pause, resume, run 0.5 s gives `run_time` 1.5 s; a second `resume_requested` in Resuming is rejected; a pause on the settling tick after `run_started` is accepted with `run_time_ms` 0; abandoning from Paused emits `run_abandoned(id, 0)` first when no time passed; a pause in Hit or Menu is rejected; without `map_ready` the phase stays Boot with no events and `start_requested` is rejected
- [ ] **AC-23**: `request_pause(back)` in Running gives `run_paused(back)`, in Resuming gives Paused, in every other phase a silent no-op
- [ ] **AC-28**: with a guard of 0.3 s, restart or menu stamped 299,999 us after `paused_us` is rejected (debug, no event); 300,000 us is accepted (`run_abandoned` first); `resume_requested` accepted at any time and wins a same-tick tie against both; for `app_interrupted`, `paused_us` is the clock at the moment of the send; the guard restarts on each entry to Paused including Resuming to Paused; bad `press_us` handled as in Story 006
- [ ] **AC-29**: `pause_requested(sensor_lost)` in Running gives `run_paused(sensor_lost)`, in Resuming gives Paused, elsewhere a silent no-op with no log; on the same tick as a hit it loses to the hit; with `app_interrupted` on one frame it gives one pause with source `app_interrupted`

## Implementation Notes
`remaining = max(0, RESUME_COUNTDOWN - (now_us - resume_us) / 1e6)`; `resume_us` set on every entry to Resuming; `run_resuming(duration_ms)` carries `round(RESUME_COUNTDOWN * 1000)`. Add an elapsed -1 row for `progress_for` (no negative clamp yet, test-plan section 6). `app_interrupted` is the one non-queued request; a duplicate is a no-op once Paused; it is silent in Menu, Paused, Hit and Boot. `sensor_lost` is queued like `button`. Abandon emits `run_abandoned(run_id, run_time_ms)` before `run_reset` / Menu.

## Out of Scope
- Story 008: stall pause source and countdown expiry timing against ticks
- Story 009: same-tick orderings
- Platform Services epic: focus-out and Back delivery

## QA Test Cases
- **AC-15**: countdown table and interruption restart
- **AC-22**: run/pause/resume/abandon and Boot rejection
- **AC-23**: Back in each phase (silent outside Running/Resuming)
- **AC-28**: guard boundary 299,999 vs 300,000; `app_interrupted` anchor at send; reset on re-entry
- **AC-29**: `sensor_lost` per phase and tie with hit and `app_interrupted`
  - Given: `core_in(phase)` per row
  - When: the stated request is sent and a tick runs (clock stepped exactly as in the row)
  - Then: events, phase and log lines equal the row
  - Edge cases: AC-15 5 s and -1 rows on the static helper; `press_us` 0 / future in Paused

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/run_state/run_state_pause_resume_test.gd`
**Evidence**: tests/unit/run_state/run_state_pause_resume_test.gd (31 tests), passing in `run_ci.py --only all`.
**Status**: [x] Created and passing

## Dependencies
- Depends on: Stories 002, 003, 004, 006
- Unlocks: Stories 008, 009
