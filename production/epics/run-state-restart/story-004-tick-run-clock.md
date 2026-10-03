# Story 004: tick(), run clock F1 and settling tick

> **Epic**: Run State & Restart
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-004`, `TR-run-state-restart-009`, `TR-run-state-restart-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: `RunState.tick(world_dt, real_dt)` runs in `GameRoot._tick` with `world_dt == real_dt`; Pause, Hit and Resuming freeze the world through `dt_eff = 0`, never through `SceneTree.paused` or `Engine.time_scale`.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `run_time` is a 64-bit GDScript float; never pass raw `run_time` to a 32-bit shader uniform.
**Control Manifest Rules (this layer)**:
- Required: one `now_us` snapshot per tick; tick order: stall guard, step candidate, requests in class priority, timers, commit
- Forbidden: `Engine.time_scale` writes; `SceneTree.paused`
- Guardrail: float tolerance 1e-6 unless an AC states otherwise (AC-10 states 1e-3)

## Acceptance Criteria
- [ ] **AC-10**: after a run starts and its settling tick, 3600 ticks of `world_dt` = `real_dt` = 1/60 give `run_time` 60.0 (+/- 1e-3); `tick(0.3, 0.3)` adds 0.1 and returns 0.1; NaN, INF and -1 as `world_dt` add 0 and log exactly one warning for the first bad input, none within 1.0 s of injected clock, one again after it; `world_dt` 0 adds 0 and logs nothing; `run_time_ms` is 1234 for 1.2344 s and 1235 for 1.2346 s (`round`, not `int`); `run_time` never decreases
- [ ] **AC-11**: `tick()` returns non-zero `dt_eff` only on a tick that begins in Running, is not a settling tick, has no stall pause and ends in Running; the tick of a hit, button pause, restart, abandon, countdown expiry or stall pause, and each settling tick (after `run_started` and after `run_resumed`), returns 0 and leaves `run_time` unchanged; `run_ended` and `run_paused` carry the `run_time_ms` of the last full step; `tick()` returns 0 in every phase except Running; `pause(button)` + `restart` on one tick from Running gives Paused with restart ignored and `dt_eff` 0 (same for `menu`)

## Implementation Notes
F1: `step = min(dt, DT_MAX)` if finite and positive else 0; commit at the end of the tick only if the tick began in Running and the phase is still Running (GDD Core Rule 3 step 5). The settling flag is set by `run_started` and `run_resumed` and consumed by the next tick. Warning rate limit: at most one per second of injected `now_us`. Float comparisons use almost-equal. Stall guard and timers are Story 008; same-tick request ordering is Story 009; here use direct sequences.

## Out of Scope
- Story 008: stall guard, timers
- Story 005: hit selection
- Story 012: the real driver that computes `real_dt` from the clock

## QA Test Cases
- **AC-10**: run clock
  - Given: a core in Running after the settling tick
  - When: 3600 ticks of 1/60, then single ticks of 0.3, NaN, INF, -1, 0
  - Then: `run_time` 60.0; 0.3 clamps to 0.1; bad inputs add 0 with the warning cadence stated; 0 logs nothing
  - Edge cases: 1.2344 s gives 1234 ms, 1.2346 s gives 1235 ms
- **AC-11**: tick contract
  - Given: a core in each phase and a settling tick after start and after resume
  - When: ticks run with and without an accepted transition
  - Then: `dt_eff` is 0 for every listed case, `run_time` unchanged, events carry last-step ms
  - Edge cases: pause + restart and pause + menu from Running

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/run_state/run_state_clock_test.gd`
**Evidence**: `tests/unit/run_state/run_state_clock_test.gd` (18 tests, passing). AC-10 and AC-11 are proven except one clause.
**Status**: [x] Done (scope refined 2026-10-04). The "stall pause" clause of AC-11 (a tick with a stall pause returns 0) is tested by story 008 AC-16, which owns the stall guard; every other clause of AC-10 and AC-11 is proven by `tests/unit/run_state/run_state_clock_test.gd` (18 tests). Story 008 must not close without that stall test.

## Dependencies
- Depends on: Story 002
- Unlocks: Stories 005, 008, 009, 011, 012
