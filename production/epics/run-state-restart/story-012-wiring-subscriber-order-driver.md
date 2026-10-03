# Story 012: Subscriber order and tick driver contract in GameRoot

> **Epic**: Run State & Restart
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-018`, `TR-run-state-restart-024`, `TR-run-state-restart-012`, `TR-run-state-restart-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0004: Map Loader and MapConfig (`map_ready` after `load_map`)
**ADR Decision Summary**: `GameRoot._wire()` builds rows `[signal, handler, rank]`, sorts by rank with the row index as tie-break, then connects in that order; `GameRoot._process` ignores the engine delta, reads the injected clock and computes `real_dt` raw; Tube Track `advance` runs only when the phase reads Running.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: ADR-0002 NEEDS VERIFICATION: handlers run in connection order on 4.7.2, including a handler disconnected and reconnected (AC-30 spy test is the verification). `_process` while unfocused on Android is a device spike (PS-1, PS-2), not this story.
**Control Manifest Rules (this layer)**:
- Required: ranks `run_reset` (Pattern and `WorldFrame`; Tube Track adapter and Obstacle; Ball; Camera; rest), `run_ended` (Juice; Scoring; HUD; rest), `run_abandoned` (Juice; Scoring; rest); `process_mode` ALWAYS; early `process_priority`
- Forbidden: `_process` outside `GameRoot`; `CONNECT_DEFERRED`; `Engine.time_scale` writes; string-built Callables at the composition root
- Guardrail: no row Callable invalid after `_wire()`; construction emits nothing

## Acceptance Criteria
- [ ] **AC-30**: spies registered by the composition root for Pattern & Difficulty, the Tube Track adapter (which appends the `window_primed` emission), Obstacle, Ball Movement, Camera and one rank-5 subscriber: on an accepted restart the log reads Pattern, then adapter and Obstacle (either order), then Ball, then Camera, then the rank-5 spy, all before `run_started`; for Juice, Scoring (emitting `personal_best_updated` inside its handler), HUD and another: the `run_ended` log reads Juice, Scoring, HUD, other with Juice's spy before `personal_best_updated`; on abandon from Paused the `run_abandoned` log reads Juice, Scoring, other with the same constraint; a root registering the adapter before Pattern, Camera before Ball or Scoring before Juice must fail
- [ ] **D4 driver (TR-024/012)**: a driver test with `Engine.time_scale` set to 0.1 shows `real_dt` and the stall guard are unaffected (computed from the clock, not the engine delta), the owner steps Ball by the returned `dt_eff`, and calls Tube Track `advance` only when the phase reads Running (zero rejected `advance()` calls over the lifecycle sequences of GDD D8)
- [ ] After `_wire()` no row Callable is invalid and the connect order equals the table order, including after a disconnect and reconnect (ADR-0002 Validation)

## Implementation Notes
Use the real `GameRoot._wire()` table (a partial sketch is in ADR-0002 Key Interfaces; the complete table is the one in `_wire()`), with spy cores substituting the other systems. Mutation-catching: add failing variants that swap the registration order and assert the test fails. The driver test is the GDD "D9" gap (known gaps, test-plan section 6); the Tube Track adapter integration (D8) is shared with the tube-track epic: coordinate, do not duplicate. Tests that need rendering classes run under the dummy headless renderer and assert structure only.

## Out of Scope
- Composition-root epic: the full construction order and per-frame spy test
- Platform Services epic: PS-1/PS-2 device spikes

## QA Test Cases
- **AC-30**: order spies
  - Given: spies wired through the real rows
  - When: restart, hit and abandon are driven through the core
  - Then: the three logs equal the pinned orders
  - Edge cases: mutated root fails; `personal_best_updated` emitted inside Scoring only after Juice latched
- **Driver**: time-scale independence
  - Given: `GameRoot` with a fake clock and `Engine.time_scale` 0.1 in the test
  - When: frames run, including a 0.6 s clock jump in Running
  - Then: stall pause fires from the clock; `advance` never called outside Running
  - Edge cases: disconnect/reconnect keeps order

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/run_state/run_state_wiring_order_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 003, 004, 008; composition-root (GameRoot `_wire()` and `_tick()` story), tube-track (adapter), spike T-1 recorded
- Unlocks: Story 013
