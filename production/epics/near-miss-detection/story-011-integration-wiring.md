# Story 011: Wire NearMissCore to real Ball, Obstacle, Run State and Juice

> **Epic**: Near-Miss Detection
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-004`, `TR-near-miss-detection-005`, `TR-near-miss-detection-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; ADR-0008: Hazard, collision and content format; ADR-0009: Test framework and CI
**ADR Decision Summary**: `GameRoot` builds the system under `&"near_miss"` and calls `NearMiss.step` after `Obstacle.test` each tick; the three Obstacle signals and `run_reset` are connected immediately in the `_wire()` rows.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Add rows to the `_wire()` table in `src/core/game_root.gd` with a rank (no `CONNECT_DEFERRED`). Verify with the real `BallCore`, `RunStateCore` and Obstacle once their stories land. TR-near-miss-detection-019 (Juice coalescing, Open Question 8) is Partial and owned by the juice epic; it is not implemented here.
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [ ] AC-23 [I]: wiring to the real `BallCore` published `theta`, `theta_prev`, `s`, `s_prev` (all four already exposed by `src/core/ball_movement/ball_core.gd`).
- [ ] AC-24 [I]: wiring to the real Obstacle `hazard_bound`/`hazard_released(hazard_id, released_by_reset)` and `hit_reported`; a real graze produces one `near_miss_detected`, a real hit produces none.
- [ ] AC-25 [I]: wiring to Run State's `run_reset`/`run_id`; a `window_primed` re-prime with a hazard in its near zone emits nothing.
- [ ] AC-26 [I]: the Juice & Feedback consumption contract (every `near_miss_detected` gets the identical fixed-magnitude presentation) is exercised through the real tick once the Juice core exists; until then record the deferral in the evidence.

## Implementation Notes
- The integration test under `tests/integration/near_miss_detection/` drives the `GameRoot._tick` order with the real cores (see `tests/integration/composition_root/` for the pattern). Do not weaken any unit test to make wiring pass.
- Needs `ObstacleCore` (obstacle-system stories 006-007) and the Juice core; AC-23 to AC-25 can land first, AC-26 last.

## Out of Scope
- Story 012: the on-device NM-1 measurement.
- Juice-side coalescing (Open Question 8).

## QA Test Cases
- **AC-23**: see criterion above
  - Given: real BallCore driven on a scripted path
  - When: ticks
  - Then: NearMissCore reads the same four values the ball published that tick
  - Edge cases: no stale `theta_prev`
- **AC-24**: see criterion above
  - Given: real ObstacleCore binding Graze and Double Gate
  - When: graze pose vs hit pose
  - Then: 1 emit vs 0 emit
  - Edge cases: hit applied before the exit check
- **AC-25**: see criterion above
  - Given: hazard in near zone
  - When: re-prime via `window_primed`
  - Then: 0 emits, state cleared
  - Edge cases: next run starts clean
- **AC-26**: see criterion above
  - Given: real Juice consumer
  - When: one emit
  - Then: one presentation event
  - Edge cases: deferred if the Juice core is absent

## Test Evidence
**Story Type**: Integration
**Required evidence**: tests/integration/near_miss_detection/near_miss_detection_wiring_test.gd
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 005-008; cross-epic: ball-movement, obstacle-system stories 006-007, run-state-restart, composition-root `_wire()` story, juice-feedback
- Unlocks: Story 012
