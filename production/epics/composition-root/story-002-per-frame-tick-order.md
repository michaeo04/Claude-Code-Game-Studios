# Story 002: Fixed per-frame order in `_tick()` (spy test)

> **Epic**: Composition Root & Game Loop
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: none, defined by ADR-0002
**Requirement**: `TR-composition-root-???` (ADR-0002 Decision 6, amended by ADR-0013 Decision 2 and ADR-0012 Decision 1)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; secondary ADR-0013 (WorldFrame step)
**ADR Decision Summary**: `_tick()` is the only place the per-frame order is written, and a spy test records the call log. Other documents cite steps by name.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None post-cutoff. The test uses fake systems (RefCounted spies); no engine tick needed.
**Control Manifest Rules (this layer)**:
- Required: order is `TiltInput.poll`, `TiltRunAdapter.flush`, `RunState.tick`, `Ball.step`, `TubeTrack.advance` (Running only), `WorldFrame step` (`maybe_rebase(s)`, then `TubeView.rebase()` and `HazardView.rebase()` when true; Running only), `Obstacle.test`, `NearMiss.step`, `Scoring.step`, `TubeView.idle_step(real_dt)` (Menu only), `Camera.step`, `BallView.tick`, `Environment.tick`, then `Juice.tick`, `HUD.tick`, `Menus.tick`.
- Forbidden: a second place that writes the order; a system added without a `_tick()` line; view `_process`.
- Guardrail: a handler reads another system by accessor after that system's step, never calls its mutators.

## Acceptance Criteria
- [ ] The spy call log of one Running tick equals the section 6 order exactly, with `WorldFrame step` immediately after `TubeTrack.advance` and before `Obstacle.test` (ADR-0002 VC-2, ADR-0013 VC-3)
- [ ] `BallView.tick` is called immediately after `Camera.step` (VC-2)
- [ ] `TubeView.idle_step` is called only when the phase is Menu, never in Paused, Hit or Resuming (VC-2)
- [ ] `TubeTrack.advance` and `WorldFrame step` are called only when Run State reports Running; no rebase happens in Pause, Hit or Resuming (ADR-0013 VC-3)
- [ ] When `maybe_rebase` returns true, `TubeView.rebase()` then `HazardView.rebase()` are called in that order, once, in the same tick; when false neither is called (ADR-0013 Decision 2)
- [ ] `Juice.tick`, `HUD.tick`, `Menus.tick` run last in that order, in every phase (Decision 6)
- [ ] The log is identical across 100 ticks with a scripted phase sequence (deterministic)

## Implementation Notes
Write `_tick(real_dt, world_dt)` once, calling systems through the injected references. Systems are typed variables so tests can pass spies (dependency injection; the spy records `"name"` into a shared `Array[String]`). The Run State phase is read by accessor after `RunState.tick`. A later system adds one line here and one `_wire()` row (Story 007). Cite steps by name in comments, never by number.

## Out of Scope
- Story 001: clock and `_process`
- Story 003: `WorldFrame` internals
- Story 006: construction order (its own spy)

## QA Test Cases
- **AC-1/2**: order in Running
  - Given: spies for every system, phase Running, `maybe_rebase` false
  - When: one `_tick` runs
  - Then: log equals the expected list
  - Edge cases: adding a spy out of order fails the test
- **AC-3/4**: phase gating
  - Given: phases Menu, Paused, Hit, Resuming
  - When: ticked
  - Then: `idle_step` only in Menu; no `advance`, no `maybe_rebase` in the other three
- **AC-5**: rebase calls
  - Given: Running with `maybe_rebase` true
  - When: ticked
  - Then: `rebase` of tube then hazard, once, between `advance` and `Obstacle.test`
- **AC-6/7**: tail order and determinism
  - Given: scripted 100-tick phase sequence
  - When: logs compared across two runs
  - Then: equal

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/composition_root/composition_root_tick_order_test.gd`
**Status**: [x] Created, passing
**Evidence**: tests/unit/composition_root/composition_root_tick_order_test.gd (test_running_tick_log_matches_adr_order_exactly, test_world_frame_step_between_advance_and_obstacle, test_ball_view_immediately_after_camera, test_idle_step_only_in_menu, test_advance_and_rebase_only_when_running, test_rebase_true_calls_tube_then_hazard_once, test_tail_runs_last_in_every_phase, test_hundred_ticks_with_scripted_phases_are_deterministic)

## Dependencies
- Depends on: Story 001
- Unlocks: Story 005, Story 010; every system story adds a `_tick()` line through this story's spy
