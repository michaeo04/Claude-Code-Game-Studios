# Story 009: Loader wiring order, map_load_failed to Menus, Retry Callable

> **Epic**: Map Loader & MapConfig
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0004
**Requirement**: `TR-map-loader-???` (related: `TR-menus-screen-flow-009`, `TR-run-state-restart-020`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary); ADR-0002 (construction order, `_wire()` rows, immediate connections)
**ADR Decision Summary**: `MapLoader` runs after `_wire()` and before the first `_process`, so `map_load_failed` reaches Menus; Menus' Retry calls an injected `request_map_retry` Callable bound to `MapLoader.retry()`.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: connections are immediate, never `CONNECT_DEFERRED` (lint).
**Control Manifest Rules (this layer)**:
- Required: order `... wire(), MapLoader load_map and map_ready, loop starts`; a `map_load_failed` row in `_wire()` for Menus; typed handlers; `GameRoot` stays free of rules
- Required: a successful Retry sends `map_ready` from the button handler (direct call on Run State); the failure screen disappears when `phase` becomes Menu
- Forbidden: relying on in-emission ordering of a deferred connection; sending requests from inside a Run State tick or handler
- Guardrail: Run State in Boot emits nothing and rejects `start_requested` (AC-22 of Run State)

## Acceptance Criteria
- [ ] A spy test records the `GameRoot` construction log and asserts the first `MapLoader.attempt` occurs after every `_wire()` row is connected and before the first `_tick` (ADR-0004 Validation spy test)
- [ ] With a failing map, `map_load_failed` reaches a spy Menus subscriber in the same tick as the attempt (no frame wait), because the loader runs after `_wire()`
- [ ] `GameRoot` passes `request_map_retry` (a typed Callable bound to `MapLoader.retry`) to Menus; calling it in `FAILED` re-runs the sequence, and on success Run State goes Boot to Menu with `phase_changed` emitted once
- [ ] While in Boot after a failure, Run State emitted no event and rejects `start_requested`
- [ ] The failure signal connection is immediate (not deferred) per the scene/lint check
- [ ] The Menus rule "after `map_load_failed` or after the timeout" is honoured: the `MAP_LOAD_TIMEOUT` backup is not required to show the screen when the signal fired

## Implementation Notes
Builds on the composition-root epic; the real `Menus` view may not exist yet, so use a spy subscriber with the same signature and a real `RunStateCore`. Add only the one `_wire()` row and the one `GameRoot` call; do not put rules in `GameRoot`. `request_map_retry` is a typed Callable (`Callable(map_loader, "retry")` is forbidden by the typed-method-reference lint; use `map_loader.retry`).

## Out of Scope
- Story 006: core Retry semantics
- Menus epic: the failure screen UI, timeout backup, plain-language text
- Composition-root epic: the full `GameRoot` build

## QA Test Cases
- **AC-1**: order
  - Given: a `GameRoot` spy log
  - When: composition runs with fake systems
  - Then: log order is `..., wire, map_load, tick`
- **AC-2**: delivery
  - Given: a spy Menus connected via `_wire()` and a failing seam set
  - When: composition completes
  - Then: spy received codes before the first tick
- **AC-3**: retry path
  - Given: failing then fixed seams
  - When: the injected Callable is invoked
  - Then: `map_ready` sent once; phase Menu; spy failure screen hidden on `phase_changed`
- **AC-4**: Boot silence
  - Given: failure state
  - When: `start_requested` sent
  - Then: rejected, no event
- **AC-5**: immediate connection
  - Given: the `_wire()` row table
  - When: connect flags inspected
  - Then: no deferred flag

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/map_loader/map_loader_wiring_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 008; composition-root epic (`GameRoot._wire()`); run-state-restart epic
- Unlocks: Story 010, Story 011
