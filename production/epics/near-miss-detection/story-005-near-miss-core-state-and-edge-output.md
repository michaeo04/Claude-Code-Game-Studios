# Story 005: NearMissCore per-hazard state and edge-triggered output

> **Epic**: Near-Miss Detection
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-001`, `TR-near-miss-detection-002`, `TR-near-miss-detection-004`, `TR-near-miss-detection-007`, `TR-near-miss-detection-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; ADR-0008: Hazard, collision and content format; ADR-0009: Test framework and CI
**ADR Decision Summary**: Cores are RefCounted with no engine call, built and wired by `GameRoot` (no autoload); `NearMiss.step` runs after `Obstacle.test` in the fixed tick order (ADR-0002 Decision 6).
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Signal `near_miss_detected(hazard_id: int, run_id: int)` declared on the core with typed arguments, connected immediately (never `CONNECT_DEFERRED`). Tests count events through an `Array` (closures capture primitives by value). Inject `log_sink` per `LogLevel`.
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [ ] AC-13 [C]: a hazard held in the near zone (not hit zone) for 5 stationary ticks (`dt_eff` 0) emits zero `near_miss_detected`; on tick 6, with the pose outside the near zone, exactly one fires (output is edge-triggered, unlike level-triggered `hit_reported`).
- [ ] AC-14 [C]: `was_in_near_zone` true, `hit_ever_true` false, then `hazard_released(hazard_id, false)` before any natural exit tick: exactly one `near_miss_detected` at release.
- [ ] AC-15 [C]: Spike cluster 101 (3 pieces, one `hazard_id`), each piece's near zone active on a different tick, yields one `was_in_near_zone` true transition for the hazard and exactly one `near_miss_detected(101, run_id)` on exit.
- [ ] AC-16 [C]: the `near_miss_detected` payload is exactly `{hazard_id, run_id}`, asserted field by field as a strict allowlist; any third field must fail.

## Implementation Notes
- `src/core/near_miss/near_miss_core.gd` (`class_name NearMissCore`): state `{hit_ever_true, was_in_near_zone}` keyed by `hazard_id`, created on `hazard_bound(hazard_id, footprint_pieces)`, discarded on `hazard_released`. It receives the raw footprint, builds hit and near footprints once at bind (Story 002), and each `step()` reads `theta`, `theta_prev`, `s`, `s_prev` from the injected ball source (`BallCore` exposes all four) and runs the Story 003 test per piece, OR-ing pieces into the hazard-level flag.
- Exit edge: `was_in_near_zone` true and this tick's `NEAR_MISS_CANDIDATE` false (and not hit) emits once, then clears. `run_id` is the last `run_reset` seen. Read-only accessors for tests; no mutation of any other system.
- `make_core(cfg, log_sink)`, `make_ball_state_stub` and `make_hazard_bound_stub` are added to the fixture.

## Out of Scope
- Story 006: hit override.
- Story 007: reset release and same-tick bind/release.
- Story 008: non-finite input.

## QA Test Cases
- **AC-13**: see criterion above
  - Given: Graze bound; stub poses: 5 ticks in near zone, then outside
  - When: 6 ticks stepped
  - Then: 0 emits over ticks 1-5, 1 on tick 6
  - Edge cases: exit-edge only, never entry
- **AC-14**: see criterion above
  - Given: Graze in near zone
  - When: `hazard_released(701, false)`
  - Then: 1 emit
  - Edge cases: no second emit on the next step
- **AC-15**: see criterion above
  - Given: hazard 101, pieces active on ticks 2, 4, 6
  - When: then exit
  - Then: exactly 1 emit with id 101
  - Edge cases: never 3
- **AC-16**: see criterion above
  - Given: any emit
  - When: payload inspected
  - Then: keys exactly {hazard_id, run_id}
  - Edge cases: mutant adding a field fails

## Test Evidence
**Story Type**: Logic
**Required evidence**: tests/unit/near_miss_detection/near_miss_detection_edge_output_test.gd
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 001, 002, 003; cross-epic: obstacle-system story 007 (signal shapes), run-state-restart (`run_reset`)
- Unlocks: Stories 006-009, 011
