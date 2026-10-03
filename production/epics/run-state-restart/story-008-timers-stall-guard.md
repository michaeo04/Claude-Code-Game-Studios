# Story 008: Timers, stall guard and clock robustness

> **Epic**: Run State & Restart
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-011`, `TR-run-state-restart-012`, `TR-run-state-restart-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: `real_dt` is computed by the driver from the injected monotonic clock (raw, unclamped) because the stall guard needs it; the stall guard is only the backup to the `FOCUS_OUT` notification, and `Time.get_ticks_usec()` may stand still across deep sleep.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: engine `delta` is `time_scale`-scaled and capped near 0.133 s, so it must never feed the guard; clock behaviour across device sleep is unverified (Run State Open Question 5, device).
**Control Manifest Rules (this layer)**:
- Required: timers measured with timestamps from the injected clock; one `now_us` snapshot per tick
- Forbidden: `Engine.time_scale` writes; counting per-frame deltas for the lock or countdown
- Guardrail: a repeated or backwards `now_us` never finishes a timer early

## Acceptance Criteria
- [ ] **AC-2**: 2 timers x 6 phases = 12 cases: the countdown expiry acts only in Resuming (to Running, emits `run_resumed`); the lock expiry acts only in Hit (emits `restart_unlocked` once, no phase change); the other 10 cases give no event and no log
- [ ] **AC-13**: with `world_dt` 0, `real_dt` 1/60 and the clock advancing 16,667 us per tick, `restart_unlocked` fires at tick 30 exactly (not 29) and `run_resumed` at tick 120 exactly; a tick with a huge `world_dt` and `now_us` advanced by only 0.1 s expires neither timer; Resuming with `real_dt` 0.6 and the clock past expiry gives Paused and no `run_resumed`
- [ ] **AC-16** (also closes the stall-pause clause of AC-11 left open by story 004: the tick that stall-pauses returns `dt_eff` 0): `real_dt` 0.499 in Running does not pause; 0.5 gives one `run_paused(app_interrupted)` and `dt_eff` 0 with `run_time` unchanged; in Resuming it returns to Paused; no stall pause in Hit, Paused, Menu or Boot; on a settling tick a `real_dt` of 5.0 gives no pause, `dt_eff` 0 and ignored hits; NaN, INF or negative `real_dt` gives no pause and exactly one warning per second
- [ ] **AC-21**: a repeated or backwards `now_us` never unlocks or expires a timer early; a 30 s background in Hit stays Hit and `restart_unlocked` is emitted on the first tick; an interruption in Resuming gives Paused and the next resume takes the full countdown; `pause(app_interrupted)` and `pause(back)` in Menu, Paused, Boot and Hit change nothing and log nothing

## Implementation Notes
Tick step 1 (stall guard) applies if the phase at the start is Running or Resuming, the tick is not a settling tick and `real_dt >= STALL_PAUSE_THRESHOLD`: pause as `app_interrupted` and discard the tick's hits (debug log each). Step 4 evaluates timers after requests, so a pause on the expiry tick wins. Elapsed is clamped to 0 or more. A stall on the tick where a countdown would expire pauses instead. Warning rate limit uses injected `now_us`.

## Out of Scope
- Story 012: the driver computing `real_dt` from the clock (the `Engine.time_scale` 0.1 driver test)
- Story 010: threshold clamping

## QA Test Cases
- **AC-2**: per-phase timer matrix (state factory per phase, advance the clock past each limit, assert events and log)
- **AC-13**: tick arithmetic at 16,667 us and the huge `world_dt` row
- **AC-16**: stall boundary 0.499 / 0.5 per phase, settling-tick row, non-finite rows
- **AC-21**: clock regression and 30 s background
  - Given: `core_in(phase)` with the clock set as stated
  - When: ticks run with the listed `real_dt`, `world_dt` and clock steps
  - Then: phases, events and log lines match; timers never fire early
  - Edge cases: backwards clock; stall on the countdown expiry tick

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/run_state/run_state_timers_stall_test.gd`
**Evidence**: tests/unit/run_state/run_state_timers_stall_test.gd (19 tests), passing in `run_ci.py --only all`.
**Status**: [x] Created and passing

## Dependencies
- Depends on: Stories 004, 006, 007
- Unlocks: Stories 009, 011, 012
