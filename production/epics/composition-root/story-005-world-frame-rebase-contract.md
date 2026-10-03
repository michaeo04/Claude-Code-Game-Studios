# Story 005: Rebase contract for views, reset wiring and soak

> **Epic**: Composition Root & Game Loop
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0013
**Requirement**: `TR-tube-track-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0013: Distance precision and the render origin (WorldFrame); secondary ADR-0002 (step order), ADR-0003 (`TubeView.rebase`)
**ADR Decision Summary**: The rebase happens in the same tick as the `s` change, before any placement reading the new origin; it re-places every bound node from stored `segment_index` or `s_offset`. A reset goes through `on_run_reset` (rank 1) or `reset()` before `to_idle()`.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Fake `Node3D`-like records stand in for slots and hazard nodes (no renderer). `reset_physics_interpolation()` (since 4.3) is a belt-and-braces call asserted on the fakes. Real-view behaviour is covered by the view epics and Story 012.
**Control Manifest Rules (this layer)**:
- Required: `TubeView.rebase()` re-binds all N slots with `render_z`; `HazardView.rebase()` re-places every bound node through `render_z(stored s_offset)` then `reset_physics_interpolation()`; `WorldFrame.reset()` is called by the Tube Track adapter immediately before `to_idle()`; `physics/common/physics_interpolation` stays `false`.
- Forbidden: effect nodes that outlive a rebase; placing a node with raw `s`; a new rank row for the idle reset.
- Guardrail: rebase tick re-places about 12 + 17 nodes (microseconds).

## Acceptance Criteria
- [ ] After a rebase every fake `TubeView` slot and `HazardView` node z equals a fresh placement with the new origin; the relative z between any two nodes is unchanged to 1e-9 in float64 (ADR-0013 VC-2)
- [ ] After a rebase (`origin_s` > 0), Paused to Menu and Hit to Menu reset the origin before `to_idle()` re-primes the idle slots, and every idle slot z equals a fresh placement at origin 0 (VC-4)
- [ ] Restart (Hit to Running) re-primes at origin 0 through `on_run_reset` (VC-4)
- [ ] Soak (host, float64): a simulated 3600 s run at `V_MAX` leaves every placed `abs(z)` below `Z_RENDER_MAX`, for nodes ahead of and behind the ball (VC-6)
- [ ] The `maybe_rebase` call in `_tick` happens only in Running and the `rebase()` hooks fire in the same tick, so no frame is drawn with a half-shifted world (the tick log of Story 002 shows the order; a fake renderer records z at "draw" time) (Decision 2)
- [ ] A fake effect node that stores `s` (float64) and converts through `render_z` each tick stays correct across a rebase (Decision 3 rule for future effects)

## Implementation Notes
Use the real `WorldFrame` (Story 003) and the real `_tick` (Story 002) with fake views that implement `bind_slot`, `rebase` and record their z. The reset calls are driven through a fake Tube Track adapter that mimics the call site (`reset()` then `to_idle()`); the real adapter is a tube-track epic story and must reuse this ordering. Soak step size is the simulated tick (1/60 s); no wall time. Add the fakes to `tests/support/`.

## Out of Scope
- Story 012: real device frame capture (PRC-1)
- tube-track / hazard epics: real `TubeView` and `HazardView` implementations
- Story 003: unit math of `WorldFrame`

## QA Test Cases
- **AC-1**: rebase propagation
  - Given: 12 fake slots, 17 fake hazard nodes, `s` crossing 1008
  - When: the tick with `maybe_rebase` true runs
  - Then: all z equal fresh placement; pairwise differences unchanged to 1e-9
  - Edge cases: node behind the ball (positive z)
- **AC-2/3**: reset order
  - Given: origin 1008, phase Paused then Hit
  - When: to Menu, and Restart
  - Then: `reset` strictly precedes `to_idle`; idle z equal fresh at origin 0; restart origin 0
- **AC-4**: soak
  - Given: 216 000 simulated ticks at `V_MAX`
  - When: running the loop with rebase
  - Then: max `abs(z)` < 2048 ahead and behind
- **AC-5/6**: same-tick and stored-s effect
  - Given: recording fake renderer
  - When: rebase tick
  - Then: no recorded draw sees old origin with new `s`; fake effect z consistent

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/composition_root/world_frame_rebase_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002, Story 003
- Unlocks: Story 012; tube-track and hazard-view stories (their `rebase()` tests reuse these fakes)
