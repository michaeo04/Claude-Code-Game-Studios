# Story 008: Flush no-op and SaveService node wiring

> **Epic**: Save & Persistence
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-018`, `TR-save-persistence-005` (boot ordering of the node), `TR-save-persistence-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `flush()` is a no-op because every write is already synchronous; `SaveService` connects only `app_backgrounded` and calls `flush()` once per emission. It is built second by `GameRoot`, converts `clock_us` to seconds, and is never an autoload.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `_ready`-equivalent boot ordering: the load must complete before the node is observable to dependents; Platform Services does not replay signals, so no replay is expected here. The `[N]` test runs under the dummy headless renderer and asserts structure only.
**Control Manifest Rules (this layer)**:
- Required: construct `PlatformServices`, then `SaveService` (synchronous load, connect `app_backgrounded`); `app_backgrounded` handler stays small and synchronous.
- Forbidden: connecting `app_foregrounded`/`app_interrupted`/`app_returned` to the persist path; write-behind; any interface to Run State; autoload.
- Guardrail: handlers never send requests from inside a Run State tick.

## Acceptance Criteria
- [ ] **AC-7 [C]** `flush()` with nothing pending produces zero seam calls (a future async rewrite that adds a race fails this AC).
- [ ] **AC-18 [N]** With a spy core and a stub Platform-Services-shaped signal source, emitting `app_backgrounded` calls the spy's flush exactly once; emitting `app_foregrounded`, `app_interrupted` or `app_returned` calls it zero times.
- [ ] **AC-19 [N]** Boot ordering: construction calls the real load path (`boot_load`) exactly once, before the node is observable as ready by anything else in the scene tree.

## Implementation Notes
Add `flush()` to `save_core.gd`; create `src/core/persistence/save_service.gd` (`extends Node`) taking an injected signal source and a `SaveFs` (the real inner class arrives in Story 009; here a fake is injected). The node owns no rules. Keep `clock` conversion (`clock_us` to float seconds) in one tiny function with a unit test row. Note: there is no interface to Run State and no mid-run persistence (CR8/CR10 stay unchanged).

## Out of Scope
- Story 009: the real `SaveFs` inner class.
- Story 015: real `PlatformServices` wiring (AC-21).

## QA Test Cases
- **AC-7**: Given a loaded core with a recording fake; When `flush()`; Then zero entries in the fake's call log; Edge: after a failed `set_value` flush still makes no call.
- **AC-18**: Given a stub emitter with the four signals; When each is emitted in turn; Then spy flush count is 1 after `app_backgrounded` and unchanged after the other three; Edge: two `app_backgrounded` emissions give two calls.
- **AC-19**: Given a spy core; When the node is added to a test tree; Then `boot_load` count == 1 at the moment `_ready` finishes and before a sibling's `_ready` can run.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/save_persistence/save_persistence_save_service_test.gd`
**Evidence**: `tests/unit/save_persistence/save_persistence_save_service_test.gd` (7 tests: AC-7 x3, AC-18 x2, AC-19, clock conversion). `SaveService` (`src/core/persistence/save_service.gd`) boot-loads in `_init`, so the load precedes any `_ready`; doubles in `tests/support/save_core_spy.gd` and `platform_signal_stub.gd`.
**Status**: [x] Created and passing

## Dependencies
- Depends on: Story 003, Story 004, Story 005
- Unlocks: Story 009, Story 015; composition-root (SaveService step 2)
