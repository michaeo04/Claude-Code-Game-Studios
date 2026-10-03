# Story 005: Hit acceptance, stale run_id and same-tick tie-break

> **Epic**: Run State & Restart
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-005`, `TR-run-state-restart-023`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: Run State is called once per frame in the fixed `_tick()` order; Obstacle's test runs after `RunState.tick`, so a hit reported on tick N is processed at tick N+1 (level-triggered reports make this safe).
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none; pure logic.
**Control Manifest Rules (this layer)**:
- Required: only `hit_reported` with the current `run_id`, outside a settling tick, ends a run
- Forbidden: Run State remembering a discarded hit (the collision owner re-reports, GDD Core Rule 7)
- Guardrail: stale `run_id` is dropped before the tie-break; log levels follow GDD Core Rule 3 (debug for stale/settling/non-Running frozen phases)

## Acceptance Criteria
- [ ] **AC-7**: the first `request_hit(id, run_id)` emits `run_ended(run_id, id, run_time_ms)` exactly once and later hits are ignored; the next run ends independently; a hit with the previous run's `run_id` on a non-settling tick is ignored with a debug log and no `run_ended`; a hit on a settling tick (after `run_started` and after `run_resumed`) is ignored with a debug log, and the same hit on the next tick is accepted; the `run_time_ms` value in the event is asserted
- [ ] **AC-20**: ids {5, 2, 9} give 2; {0, 3} give 0; {-1, 4} give 4; {3, 3} give 3; {-1} gives `run_ended` with -1; {stale `run_id` with id 0, valid with id 5} give 5 (stale dropped first, debug log); {-5} is treated as -1 with one warning

## Implementation Notes
All `hit_reported` of a tick are taken together: drop stale `run_id` first, then the lowest non-negative `hazard_id` wins, `-1` only if no known id is present. Any other negative id is treated as -1 with one warning. A hit ends the run: phase to Hit, record `hit_us` as the tick's `now_us` snapshot, emit `run_ended` then `phase_changed`. Level-triggered reporting (TR-023) is the collision owner's contract; document it in the core's doc comment and cover it with the deferred D4 integration check, not here.

## Out of Scope
- Story 006: the restart lock that starts at `hit_us`
- Story 008: hits discarded by the stall guard
- Story 009: hit versus pause on the same tick

## QA Test Cases
- **AC-7**: single and stale hits
  - Given: Running with `run_id` 1; then a restart to `run_id` 2
  - When: hits with id 1 and 2 are sent, including on settling ticks
  - Then: only the current-id, non-settling hit ends the run; others log debug
  - Edge cases: next-tick acceptance after the settling tick; `run_ended` carries `run_time_ms`
- **AC-20**: tie-break table
  - Given: Running, several `request_hit` calls in one tick
  - When: the tick runs
  - Then: the winner id matches each row
  - Edge cases: duplicates {3,3}; only -1; -5 logs one warning

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/run_state/run_state_hit_test.gd`
**Evidence**: `tests/unit/run_state/run_state_hit_test.gd` (14 tests, passing): AC-7 (single, later, same-tick, next-run, stale, settling after start and after resume, run_time_ms asserted) and AC-20 (every tie-break row, stale-first, -5 warning).
**Status**: [x] Created and passing

## Dependencies
- Depends on: Stories 002, 003, 004
- Unlocks: Stories 006, 009, 011
