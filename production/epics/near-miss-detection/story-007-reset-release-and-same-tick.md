# Story 007: Release by reset suppression and same-tick bind and release

> **Epic**: Near-Miss Detection
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-006`, `TR-near-miss-detection-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; ADR-0008: Hazard, collision and content format
**ADR Decision Summary**: `hazard_released(hazard_id, released_by_reset)` carries the release reason so suppression is at the source and Juice adds no stale-`run_id` filter; Obstacle releases before repopulating on a re-prime.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Handle both signal arguments typed (`int`, `bool`). Ordering of release before repopulate is Obstacle's and the Composition Root's; this core only honours the flag.
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [x] AC-28 [C]: two hazards in the near zone, not hit: `hazard_released(id, true)` emits nothing and discards the entry; `hazard_released(id, false)` emits exactly one `near_miss_detected(id, run_id)`. Third case: a hit on hazard A ends the run while B is in its near zone and the next `window_primed` releases B with `released_by_reset` true: nothing fires for B. A mutation ignoring the flag or suppressing ordinary releases must fail.
- [x] AC-18 [C]: `hazard_bound` and `hazard_released` for the same `hazard_id` in the same tick with no intervening test create and tear down the entry with no `near_miss_detected`; a release on the same tick as a natural exit emits exactly once.

## Implementation Notes
- Release logic: emit iff `released_by_reset` is false and `was_in_near_zone` and not `hit_ever_true`; discard the entry in all cases. If the natural exit edge already emitted this tick, the release must not emit again (clear `was_in_near_zone` on emit).

## Out of Scope
- Story 011: the real `window_primed` sequence through Run State and Obstacle.

## QA Test Cases
- **AC-28**: see criterion above
  - Given: three scripted hazards as above
  - When: releases delivered
  - Then: reset releases: 0 emits; ordinary: 1 emit
  - Edge cases: mutants fail
- **AC-18**: see criterion above
  - Given: bind and release in one tick; separately natural exit plus release in one tick
  - When: stepped
  - Then: 0 emits; exactly 1 emit
  - Edge cases: entry removed afterwards

## Test Evidence
**Story Type**: Logic
**Required evidence**: tests/unit/near_miss_detection/near_miss_detection_release_test.gd
**Evidence**: near_miss_detection_release_test.gd (6 tests, passing: AC-28 reset/ordinary/hit-then-prime, AC-18 bind+release, exit+release).
**Status**: [x] Complete

## Dependencies
- Depends on: Story 005
- Unlocks: Story 011
