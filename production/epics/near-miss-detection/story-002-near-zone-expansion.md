# Story 002: NearMissMath near-zone expansion (F1-NM)

> **Epic**: Near-Miss Detection
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-001`, `TR-near-miss-detection-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format; ADR-0009: Test framework and CI
**ADR Decision Summary**: `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array; there is no offset arithmetic outside the bind (ADR-0008 Decision 3).
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Static pure functions over `PackedFloat64Array`; no engine call. Reuse `ObstacleMath.effective_footprint` for the hit zone (`src/core/obstacle/obstacle_math.gd`); never re-derive the ball-size expansion.
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [ ] AC-1 [M]: for Graze 701, `theta_near = [-0.5358, 0.5358]` and `s_near = [99.2, 102.3]` to 1e-4; the near zone's angular span is exactly `w` (0.2358) wider than the hit zone's and its `s` span exactly `D` (0.8) wider, both asserted.
- [ ] AC-2 [M]: for Graze and every piece of Spike cluster 101 and Double Gate 202, `theta_near_min < theta_eff_min`, `theta_near_max > theta_eff_max`, `s_near_start < s_eff_start`, `s_near_end > s_eff_end`, all strict at defaults; a row at the safe-range floor (both coefficients 0.5) stays strict.

## Implementation Notes
- `NearMissMath.near_footprint(raw, half_angle, d, angle_margin, s_margin) -> PackedFloat64Array` (4 floats per piece, same layout as `effective_footprint_array`): hit zone from `ObstacleMath`, then add the margins. `NEAR_MISS_ANGLE_MARGIN = ANGLE_COEFF * BALL_HALF_ANGLE`, `NEAR_MISS_S_MARGIN = S_COEFF * D / 2` (neither depends on `v_max`).
- Doc comment on every public function with a worked example. A theta width reaching 2*PI is F3-NM's concern (Story 004), not this formula's.

## Out of Scope
- Story 003: the swept test.
- Story 004: adjacency validator.

## QA Test Cases
- **AC-1**: see criterion above
  - Given: Graze 701 raw (-0.3, 0.3, 100.0, 101.5), defaults
  - When: near footprint computed
  - Then: bounds match the GDD example to 1e-4; widths differ from hit zone by 0.2358 and 0.8
  - Edge cases: compare widths, not only bounds
- **AC-2**: see criterion above
  - Given: Graze, 101 (3 pieces), 202 (2 pieces), defaults then coefficients 0.5
  - When: near and hit footprints compared per piece
  - Then: four strict inequalities hold for every piece
  - Edge cases: a mutation using `<=` or margin 0 must fail

## Test Evidence
**Story Type**: Logic
**Required evidence**: tests/unit/near_miss_detection/near_miss_detection_near_zone_test.gd
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001; obstacle-system `ObstacleMath` F1/F2 (already in `src/core/obstacle/obstacle_math.gd`)
- Unlocks: Stories 003, 004, 005
