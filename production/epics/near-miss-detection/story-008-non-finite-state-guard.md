# Story 008: Non-finite ball state is a no-op frame

> **Epic**: Near-Miss Detection
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1-2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format; ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: The test runs every tick in every phase (the stationary degenerate case); a non-finite `theta` or `s` holds the last good swept endpoint.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Check finiteness on all four published values; log once per bad tick at `LogLevel.ERROR` through the injected sink, with a stable code constant defined by the core.
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [ ] AC-17 [C]: a tick with `theta = NaN` or `s = +inf` is a no-op (last known-good swept endpoint held), logs exactly one error, produces no `near_miss_detected` from the NaN/inf comparison; the next valid tick resumes with no residual effect.

## Implementation Notes
- Do not propagate NaN into `NEAR_MISS_CANDIDATE`. The GDD names no log code for this case; choose one constant in the core and record it in the story when implemented. Frozen ticks (`dt_eff` 0) rely on Ball Movement's no-op contract (`theta_prev == theta`) and need no special case (covered by Story 005, AC-13).

## Out of Scope
- Story 005: stationary-tick emission behaviour.

## QA Test Cases
- **AC-17**: see criterion above
  - Given: hazard in near zone, then a tick with NaN theta, then a valid tick
  - When: stepped
  - Then: one error log, no emit on the NaN tick, normal edge behaviour afterwards
  - Edge cases: repeat with `s = +inf`

## Test Evidence
**Story Type**: Logic
**Required evidence**: tests/unit/near_miss_detection/near_miss_detection_non_finite_test.gd
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 005
- Unlocks: Story 011
