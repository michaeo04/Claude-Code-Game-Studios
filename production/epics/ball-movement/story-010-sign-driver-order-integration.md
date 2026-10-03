# Story 010: Sign and driver-order integration with Tilt and Run State (AC-29, AC-31)

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md`
**Requirement**: `TR-ball-movement-005`, `TR-ball-movement-008`, `TR-ball-movement-014`, `TR-ball-movement-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: Per-frame order is `TiltInput.poll`, `TiltRunAdapter.flush`, `RunState.tick`, `Ball.step`, `TubeTrack.advance`, ...; `run_reset` row rank 3 for Ball; Pause/Hit/Resuming freeze through `dt_eff = 0`.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: a test-only driver, not the production `GameRoot`; no `_process` outside `GameRoot` (lint), so the driver is stepped manually by the test.
**Control Manifest Rules (this layer)**:
- Required: the test-only driver assembles the real order with real `TiltCore`, `RunStateCore` and `BallCore`; consumers read the published state after `step()`; `t_run` equals Run State `run_time`.
- Forbidden: `_process` in the driver; reading raw world Z; the ball sending any request to Run State.
- Guardrail: integration tests use real `.tres`, per-test temp files only.

## Acceptance Criteria
- [ ] **AC-29 [I]** (Tilt AC-40 gate; **the epic cannot close without it**) A test-only driver assembles tilt poll, flush, `tick`, ball step with real TiltCore, Run State core and BallCore: right edge lowered 20 degrees for 60 ticks after capture gives `steer` > 0, `theta` strictly increases and Tube Track `P(theta, s, h).x` increases; the left edge mirrors it. It proves neither the production driver's order nor the phone's physical sign (Tilt V-1).
- [ ] **AC-31 [I]** (R2, R10, F6) Over a scripted Running, Hit, Paused, Resuming and settling-tick sequence: `theta`, `s`, `t_run` are bit-identical across every `dt_eff == 0` tick with previous equal to current; nothing moves on the first tick after `run_started` and `run_resumed`; `t_run == Run State run_time` after every tick.

## Implementation Notes
Test file `tests/integration/ball_movement/ball_movement_driver_order_test.gd`, support driver in `tests/support/ball_test_driver.gd` (plain RefCounted). The 20 degree gravity vector comes from a synthetic sample source feeding `TiltCore`. Tube Track `P` is called through `TubeMath.local_point(theta, h)` plus the `render_z` reference (ADR-0013 Decision 3), not a Vector3 built from `s`. AC-30 (exactly 2 polls between capture and first moving tick; spy order including consumers) is deferred to the composition-root loop story and is not placed here.

## Out of Scope
- AC-30 (owner: composition-root loop spy story)
- Production `GameRoot._tick` (composition-root epic)
- The physical phone sign (Tilt V-1)

## QA Test Cases
- **AC-29**: sign
  - Given: real TiltCore after neutral capture, RunState Running, BallCore
  - When: right edge lowered 20 degrees for 60 ticks; then left edge
  - Then: `steer` > 0 and `theta` strictly increasing; `P.x` increases; mirror for left
  - Edge cases: poll order violated in a mutation run must fail the sign test
- **AC-31**: inertness sequence
  - Given: scripted Running -> Hit -> restart/pause -> Resuming
  - When: ticks run including settling ticks
  - Then: bit-identical `theta`, `s`, `t_run` over zero ticks; `t_run == run_time` every tick
  - Edge cases: first tick after `run_started` and after `run_resumed`

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/ball_movement/ball_movement_driver_order_test.gd` (must pass)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 006, Story 008, Story 009; tilt-input (TiltCore + adapter stories); run-state-restart (core story); tube-track (`TubeMath.local_point`); composition-root (WorldFrame story for `render_z` reference)
- Unlocks: Story 013 (spike readiness); epic close
