# Story 009: Same-tick request conflicts and order independence

> **Epic**: Run State & Restart
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-003`, `TR-run-state-restart-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: Requests are applied in a fixed class priority inside `RunState.tick`, each validated against the phase as it stands after the previous one.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none; pure logic.
**Control Manifest Rules (this layer)**:
- Required: class priority order hit, pause, resume, menu, restart, map_ready, start; arrival order inside a class
- Forbidden: computing expectations by sorting inside the test (hard-coded expectations only)
- Guardrail: log level is classified by the phase at the request's turn (GDD Core Rule 3)

## Acceptance Criteria
- [x] **AC-18**: table-driven, one row per pair: hit + `pause(button)` gives Hit and one debug line for the pause; `pause(app_interrupted)` sent while a hit is queued gives Paused, no `run_ended`, no log for the interruption and one debug line for the ignored hit; stall tick + hit gives Paused, no `run_ended` and one debug line; menu + restart in unlocked Hit or in Paused after the guard gives Menu with the restart rejected (debug); resume + restart in Paused after the guard gives Resuming, restart rejected (debug), no `run_abandoned`; `pause(button)` + restart and `pause(button)` + menu from Running give Paused with the second ignored inside the guard (debug); `app_interrupted` + `button` gives one pause with source `app_interrupted`; `button` + `back` gives one pause with the first's source; `app_interrupted` + restart in unlocked Hit gives Running; a pause on the countdown-expiry tick wins
- [x] **AC-19**: for each of the 120 orderings of {hit, `pause(button)`, menu, restart, resume} sent in one tick, from Running, Paused (after the guard) and unlocked Hit, the outcome (final phase, ordered events, log lines) equals the hard-coded row of `test-plan.md` section 5 (Running gives Hit with 3 debug and 1 warning; Paused gives Resuming with 4 debug; unlocked Hit gives Menu with `phase_changed` only, 1 debug, 2 warning, 1 debug); arrival order inside a class checked by separate rows (two pause sources, two restarts)

## Implementation Notes
Generate the 120 permutations in the test with a helper, but compare only against the three hard-coded expectation tables. Class priority means {pause, resume} from Running gives Paused then Resuming (GDD Open Question 17 asks for a semantic oracle; note the finding in the test, do not change behaviour). Reuse the factory and recorder from Story 002.

## Out of Scope
- Story 005: tie-break among several hits
- Story 007: individual pause/guard rules

## QA Test Cases
- **AC-18**: pair table
  - Given: the state named in each row, requests queued before one tick
  - When: the tick runs
  - Then: phase, events and log level match the row
  - Edge cases: the interruption applied at send before the queued hit is processed
- **AC-19**: permutation sweep
  - Given: 3 start phases x 120 orderings
  - When: the requests are sent in that order and the tick runs
  - Then: all 360 outcomes equal the 3 expected tables
  - Edge cases: separate rows for two sources and two restarts

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/run_state/run_state_same_tick_test.gd`
**Status**: [x] Created and passing
**Evidence**: `tests/unit/run_state/run_state_same_tick_test.gd` (AC-18 pair rows, AC-19 3 x 120 orderings plus separate rows).

## Dependencies
- Depends on: Stories 005, 006, 007, 008
- Unlocks: Story 011
