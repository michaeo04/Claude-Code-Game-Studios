# Story 005: Phase B apply order and map_ready

> **Epic**: Map Loader & MapConfig
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0004
**Requirement**: `TR-map-loader-???` (related: `TR-tube-track-024`, `TR-run-state-restart-020`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary); ADR-0014 (B4 `apply_hazard_view`)
**ADR Decision Summary**: Phase B applies in a fixed order with Tube Track last because `load_map` primes the window; `map_ready` is sent only after `tube_load` returned true, and nothing is sent on failure.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: none (pure logic with fake seams).
**Control Manifest Rules (this layer)**:
- Required: order B1 env, B2 obstacle, B3 pattern, B4 hazard view, B5 `tube_load`, B6 `send_map_ready`; B1 to B4 idempotent
- Required: a false from B1 to B4 gives `MAP_APPLY_FAILED` plus the system name; a rejected B5 gives `TUBE_LOAD_REJECTED`
- Forbidden: `map_ready` on failure or before B5 returned true; Phase B before Phase A passed; `apply_map` emitting a signal
- Guardrail: the whole sequence is synchronous, one frame

## Acceptance Criteria
- [ ] On success the seams are called exactly in the order env, obstacle, pattern, hazard view, tube load, then `send_map_ready` once, and `attempt()` returns true with `status == READY` (ADR-0004 Validation)
- [ ] Each apply seam receives the validated `MapConfig` (not `def.env`); `tube_load` receives the `TubeConfig` from `from_map`
- [ ] A false from any of B1 to B4 stops the sequence, gives `MAP_APPLY_FAILED` with the system name in the code detail, and sends no `map_ready` and calls no later seam
- [ ] A false from `tube_load` gives `TUBE_LOAD_REJECTED` and sends no `map_ready`
- [ ] A Phase A failure calls no Phase B seam (re-asserted end to end)
- [ ] After any failure the loader has not freed or recreated Tube Track slots (no such seam exists; the test asserts the seam list is closed)

## Implementation Notes
Seam names and order are the ADR-0004 Key Interfaces. The "system name" detail goes in the code record sent to the log sink, while the code string in `last_codes` stays one of the stable set; document the exact form in the doc comment so Story 006 and Menus' debug label agree. Do not wrap B-steps in try/catch: seams return bool. `send_map_ready()` returns void; a throw there is out of scope.

## Out of Scope
- Story 004: Phase A
- Story 006: failure signal, logging, Retry
- The `apply_map` implementations on Environment, Obstacle, Pattern, HazardView (their epics)

## QA Test Cases
- **AC-1**: success order
  - Given: recording fake seams all returning true
  - When: `attempt(path)` runs
  - Then: call log is `[env, obstacle, pattern, hazard_view, tube_load, map_ready]`; returns true; `READY`
- **AC-2**: payloads
  - Given: a definition with a distinguishable `env`
  - When: `attempt` runs
  - Then: apply seams got the validated copy (`!=` identity of `def.env`), `tube_load` got the `from_map` result
- **AC-3**: B1..B4 failure (one case per step)
  - Given: step N returns false
  - When: `attempt` runs
  - Then: later seams uncalled; `MAP_APPLY_FAILED` with the system name; no `map_ready`
- **AC-4**: B5 rejection
  - Given: `tube_load` returns false
  - When: `attempt` runs
  - Then: `TUBE_LOAD_REJECTED`; no `map_ready`
- **AC-5**: Phase A failure
  - Given: a null library
  - When: `attempt` runs
  - Then: call log empty
- **AC-6**: closed seam list
  - Given: `MapLoaderSeams` property/method list
  - When: scanned
  - Then: no seam that unloads or frees slots

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/map_loader/map_loader_phase_b_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 004
- Unlocks: Story 006
