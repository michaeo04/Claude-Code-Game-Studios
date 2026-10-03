# Story 003: Event emission order, two-step start and re-entrancy guard

> **Epic**: Run State & Restart
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-007`, `TR-run-state-restart-008`, `TR-run-state-restart-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0006: Android platform integration (handlers never send requests from inside a tick or handler)
**ADR Decision Summary**: Signals are declared on the owning core and connected immediately (no `CONNECT_DEFERRED`); handlers never send requests from inside a Run State tick or handler and must not `await` inside `run_reset`.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: signal emission calls handlers in connection order and synchronously; `CONNECT_DEFERRED` would run handlers after `emit()` returns and is forbidden (verified in the engine reference).
**Control Manifest Rules (this layer)**:
- Required: immediate connections only; typed handlers; handlers never send requests from inside a tick or handler
- Forbidden: `CONNECT_DEFERRED` on control signals; `await` in a `run_reset` handler
- Guardrail: the specific event is emitted first and `phase_changed(new, old)` last; inside any handler `phase` already reads the new phase

## Acceptance Criteria
- [ ] **AC-3**: one table row per sequence asserts ordered events and arguments: Menu to Running `run_reset(n), run_started(n)`; Hit to Running `run_reset(n+1), run_started(n+1)` with no `run_abandoned`; Running to Hit `run_ended(id, hazard, ms)`; Running or Resuming to Paused `run_paused(source)` for each of the 4 sources; Paused to Resuming `run_resuming(2000)`; Resuming to Running `run_resumed(id)`; Paused to Running `run_abandoned(id, ms), run_reset, run_started`; Paused to Menu `run_abandoned(id, ms)`; Boot to Menu and Hit to Menu `phase_changed` only; `restart_unlocked(id)` alone, never with `phase_changed`
- [ ] **AC-4**: with 3 doubles whose `run_reset` handlers record a return marker, every marker precedes `run_started`, both carry the same `run_id`, both are emitted within the tick of the accepted request, `phase` reads the new phase inside every handler; `run_resumed` is emitted before the first tick of the resumed run
- [ ] **AC-5**: a mock handler on each of the 9 events that tries each request (7 requests, pause with 3 sources) is rejected with one error-level log line, no phase change and no extra event; the same request sent after the handler returns gives the AC-1 outcome
- [ ] **AC-17**: a `run_reset` handler that advances the injected clock by 5 s still yields `run_started` in that tick and no timer is re-evaluated in it; the next tick (settling) absorbs the hitch

## Implementation Notes
A re-entrancy flag set around the whole tick and around each `emit()` rejects any request sent from a handler (error level); the test plan suggests narrowing the guard to the `emit()` calls (Open Question 17), so keep one flag and document the choice. Include `app_interrupted` and "sent from inside a tick" in the AC-5 matrix (test-plan section 6). Two-step start: `run_reset` for all handlers, then `run_started` in the same tick; `run_id` +1 per `run_reset`. Boot to Menu and Hit to Menu emit `phase_changed` only.

## Out of Scope
- Story 001: signal declarations
- Story 012: real subscriber order via `GameRoot._wire()`
- Story 007: pause sources and resume countdown rules

## QA Test Cases
- **AC-3**: event sequences
  - Given: the recorder (one shared ordered Array) connected to all 9 signals
  - When: each listed sequence is driven through the public API
  - Then: the ordered events equal the table row
  - Edge cases: `restart_unlocked` never accompanied by `phase_changed`
- **AC-4**: handler contract
  - Given: 3 doubles with `run_reset` handlers
  - When: an accepted restart ticks
  - Then: all markers precede `run_started`; `phase` already new inside handlers
  - Edge cases: `run_resumed` precedes the settling tick
- **AC-5**: no nesting
  - Given: a handler on each event that sends each request
  - When: the event fires
  - Then: 1 error log per attempt, no change
  - Edge cases: after the handler returns the same request is processed normally
- **AC-17**: clock jump inside a handler
  - Given: a `run_reset` handler that moves the clock by 5 s
  - When: the restart is accepted
  - Then: `run_started` in the same tick; timers not re-evaluated

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/run_state/run_state_events_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002
- Unlocks: Stories 005, 007, 012
