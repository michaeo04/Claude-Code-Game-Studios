# Story 010: Run State adapter and map-load integration

> **Epic**: Tube Track
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/tube-track.md` (Dependencies, Open Question 6; no numbered AC, criteria below come from the ADRs)
**Requirement**: `TR-tube-track-024`, `TR-tube-track-006`, `TR-tube-track-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary, B5 `TubeTrack.load_map`, `map_ready` only after B5); ADR-0002: Game loop, Composition Root and tick order (`_wire()` rank 2 for the adapter); ADR-0013: Distance precision and the render origin (`WorldFrame.reset()` before `to_idle()`)
**ADR Decision Summary**: Run State events map through a Tube Track-owned thin adapter to `begin_run`, `pause`, `resume`, `end_run`, `to_idle`. The adapter never calls `load_map`: the map loader does, and `map_ready` is sent only on success. `WorldFrame.on_run_reset` is rank 1, the adapter's `on_run_reset` rank 2; `WorldFrame.reset()` is called by the adapter immediately before `to_idle()` (Paused to Menu, Hit to Menu).
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Handler order within a rank is the `_wire()` row index (the sort is not stable); the connect-order spy test on 4.7.2 belongs to the composition-root epic. Use typed handlers and immediate connections.
**Control Manifest Rules (this layer)**:
- Required: adapter skips `pause()` when Tube Track is already Paused and skips `to_idle()` on Boot to Menu; `TubeTrack.advance` is called by `GameRoot` in Running only; `load_map` is Phase B step B5 (last) and returns a bool.
- Forbidden: `unload_map` in the MVP; a handler sending requests from inside a Run State tick or handler; `CONNECT_DEFERRED`.
- Guardrail: `TUBE_LOAD_REJECTED` when B5 returns false; no `map_ready` then.

## Acceptance Criteria
- [ ] (TR-024) With a real `TubeWindow` and a real `RunStateCore` (or its approved test double from the run-state-restart epic): `run_reset` leads to `begin_run`, pause to `pause`, resume to `resume`, run end to `end_run`, return to Menu to `to_idle`, and the adapter state tracks the GDD transition table; pause when already Paused and Boot to Menu `to_idle` are skipped without an error.
- [ ] (ADR-0013) After a rebase (`origin_s` > 0), Paused to Menu and Hit to Menu reset the origin before `to_idle()` re-primes the idle slots (every idle slot z equals a fresh placement at origin 0); Restart (Hit to Running) re-primes at origin 0 through `on_run_reset` (rank 1 before rank 2).
- [ ] (ADR-0004) `load_map` is called by the map loader double only; success leads to `map_ready` after B5; a validation failure leaves Tube Track Uninitialized, sends no `map_ready`, and a Retry `load_map` succeeds without re-creating slots.

## Implementation Notes
`src/core/tube_track/tube_run_adapter.gd` (RefCounted, injected `TubeWindow`, `WorldFrame`). Handlers: `on_run_reset(run_id)`, `on_phase_changed(new, old)` or the Run State signals named in `run-state-restart.md`; read that GDD for exact signal names. The `_wire()` rows themselves are written by the composition-root epic; this story provides the handler methods and tests them by calling handlers in the rank order. The adapter does nothing during Idle ticks beyond forwarding. Use the real `WorldFrame` from Story 004.

## Out of Scope
- Story 011: view slot placement (idle slot z uses a recording binder here)
- composition-root epic: `_wire()` table and spy tests
- map-loader epic: Phase A/B implementation

## QA Test Cases
- **(TR-024)** Given: real core and adapter, recording sinks. When: replay a phase sequence Boot, Menu, Running, Paused, Running, Hit, Menu. Then: window state follows the table, no rejected-event errors for skipped events. Edge cases: Hit to Running (Restart) skips Idle.
- **(ADR-0013)** Given: `origin_s` advanced past one rebase. When: Paused to Menu, Hit to Menu, Hit to Running. Then: origin 0 at each re-prime; idle slot z equal a fresh placement. Edge cases: order rank 1 then 2.
- **(ADR-0004)** Given: a loader double with an invalid then a valid config. When: attempt then Retry. Then: no `map_ready` first, one after; binder spy shows no slot re-creation.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/tube_track/tube_run_adapter_test.gd`
**Evidence**: `tests/integration/tube_track/tube_run_adapter_test.gd` (4 tests: real RunStateCore phase sequence, origin reset before to_idle with idle binds equal to a fresh placement, Restart re-prime, loader double B5 and Retry); unit coverage in `tests/unit/tube_track/tube_run_adapter_test.gd`.

## Dependencies
- Depends on: Story 004, Story 005, Story 006; run-state-restart epic (core and event names); map-loader epic (B5 sequence)
- Unlocks: composition-root epic wiring, Story 013
