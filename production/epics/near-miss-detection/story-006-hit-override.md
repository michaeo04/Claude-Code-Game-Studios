# Story 006: Hit overrides near-miss and same-tick order

> **Epic**: Near-Miss Detection
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; ADR-0008: Hazard, collision and content format
**ADR Decision Summary**: `Obstacle.test` runs before `NearMiss.step`, so a `hit_reported` is always applied before the exit-edge check (ADR-0008 Decision 4); `hit_reported` is a read-only signal here.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `hit_reported(hazard_id, run_id)` is emitted by `ObstacleCore`; Near-Miss only listens. The core's internal order is contracted: apply pending hits, then the exit-edge check, whatever order the driver delivers them.
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [ ] AC-11 [C]: tick 1 near zone (`was_in_near_zone` true), tick 2 `hit_reported`, tick 3 exit or release: no `near_miss_detected`. Multi-piece row (Spike cluster 101): near zone via piece A, `hit_reported(101, run_id)` from piece C, exit: no emit (override keyed on `hazard_id`).
- [ ] AC-12 [C]: `hit_reported` and a near-zone exit edge landing on the same tick give no `near_miss_detected`, regardless of the order the driver delivers the two inputs to the core's API.

## Implementation Notes
- `on_hit_reported(hazard_id, run_id)` sets `hit_ever_true` for that id only if the id is bound; an unknown id is ignored without error. The exit-edge check in `step()` reads `hit_ever_true` after pending hits are applied.
- Open Question 9 (does the multi-piece override read as fair) is a first-playable playtest finding, not tested here.

## Out of Scope
- Story 005: the base edge output.
- Open Question 9: playtest.

## QA Test Cases
- **AC-11**: see criterion above
  - Given: Graze, then Spike cluster 101
  - When: scripted ticks as above
  - Then: no emit in either row
  - Edge cases: hit from a different piece than the graze
- **AC-12**: see criterion above
  - Given: hit and exit on one tick, delivered hit-first then exit-first
  - When: step
  - Then: no emit in both orders
  - Edge cases: call-site order irrelevant

## Test Evidence
**Story Type**: Logic
**Required evidence**: tests/unit/near_miss_detection/near_miss_detection_hit_override_test.gd
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 005
- Unlocks: Story 011
