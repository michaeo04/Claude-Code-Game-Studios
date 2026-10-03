# Story 002: Phase machine, request queue and validation by phase

> **Epic**: Run State & Restart
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-002`, `TR-run-state-restart-003`, `TR-run-state-restart-020`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0004: Map Loader and MapConfig (`map_ready` only after a successful load)
**ADR Decision Summary**: Run State is the sole owner of phase; Boot to Menu happens only on the external `map_ready` that the loader sends after Tube Track's `load_map` returned true; on failure Run State stays in Boot with no events.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none beyond Story 001; no post-cutoff API.
**Control Manifest Rules (this layer)**:
- Required: Run State remains the sole owner of phase; a phase change is never delayed by presentation; in Boot it emits nothing and rejects `start_requested` (ADR-0004)
- Forbidden: a test-only `force_phase`; every phase is reached through the public API (state factory `core_in(phase)`)
- Guardrail: rejected requests produce no state change, no event (including `phase_changed`) and exactly one log line at the class level of GDD Core Rule 3

## Acceptance Criteria
- [ ] **AC-1**: the 6 phases x 7 requests table (46 cases with Hit locked/unlocked and Paused inside/after guard) accepts exactly 10 pairs and rejects 36; a rejected case leaves phase, `run_id` and `run_time` unchanged, emits nothing, logs exactly one line at the level of `test-plan.md` section 4 (10 debug, 26 warning); the phase enum has exactly 6 values and starts at Boot
- [ ] **AC-6**: `run_id` is 0 in Boot and in Menu before the first `run_reset`, +1 on every `run_reset`, unchanged by pause, resume, abandon and Hit to Menu, strictly increasing over 1000 restarts, a double tap increases it once; `run_time` is 0 after a reset and advances only in Running

## Implementation Notes
Requests are queued when sent and processed at the next `tick` (the one exception, `app_interrupted`, is Story 007); a queued request has no effect before the tick. Log level classes: silent, debug, warning, error through the injected `log_sink(level, message)`. Implement the transition table of the GDD (States and Transitions) and the class priority order (`hit_reported`, `pause_requested`, `resume_requested`, `menu_requested`, `restart_requested`, `map_ready`, `start_requested`). Lock and guard decisions (`press_us`) are Stories 006 and 007; here the factory supplies a `press_us` after the limit for the accepted rows and one inside it for the debug rows, using simple `hit_us`/`paused_us` anchors. Build `tests/support/run_state_factory.gd` (`core_in(phase)`, clock starting at 1,000,000 us, recorder, log list cleared after the factory returns) as plain RefCounted, no GUT call.

## Out of Scope
- Story 003: event order and handler contract
- Story 004: `tick` return value and run clock
- Story 005: same-tick hit selection

## QA Test Cases
- **AC-1**: acceptance matrix
  - Given: a core in each of the 8 factory states (Boot, Menu, Running, Paused inside/after guard, Resuming, Hit locked/unlocked)
  - When: each of the 7 requests is sent (hit with the current `run_id` on a non-settling tick) and a tick runs
  - Then: the 10 accepted pairs transition; the 36 others change nothing, emit nothing and log once at the listed level
  - Edge cases: a lock-limit row `anchor + limit - 1` is rejected, `anchor + limit` accepted; `clock` never at 0
- **AC-6**: run id and run time
  - Given: a core driven through start, pause, resume, abandon, hit and menu
  - When: `run_id` is read after each step and over 1000 restart cycles
  - Then: it increments only on `run_reset`, holds the last id in Menu, never repeats; a double `restart_requested` gives +1
  - Edge cases: `run_time` stays 0 outside Running

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/run_state/run_state_transitions_test.gd`, support `tests/support/run_state_factory.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001
- Unlocks: Stories 003, 005, 006, 007, 008, 009
