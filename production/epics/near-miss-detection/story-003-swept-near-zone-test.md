# Story 003: Two-invocation swept test: HIT_ZONE and NEAR_MISS_CANDIDATE (F2 reused)

> **Epic**: Near-Miss Detection
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-003`, `TR-near-miss-detection-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format; ADR-0009: Test framework and CI
**ADR Decision Summary**: Collision is analytic swept AABB (`s_hit`, `theta_hit` with one `fposmod`); Near-Miss reuses the same early-out and invokes `ObstacleMath` F2 against the hit zone and the near zone.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Call `ObstacleMath.theta_hit`/`s_hit`/`swept_hit` on both footprints; do not define a second `arc_overlap`. `dtheta`/`swept_start`/`swept_width` depend only on `(theta_prev, theta)`; compute once per frame and share (GDD F2) if the wrapper allows, otherwise call twice and note why.
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [x] AC-3 [M]: Graze at `theta_prev -0.5, theta -0.45, s_prev 100.5, s 100.6`: `HIT_ZONE` false, `NEAR_ZONE` true, `NEAR_MISS_CANDIDATE` true (pure angular graze).
- [x] AC-4 [M]: Graze at `theta_prev 0.0, theta 0.05, s_prev 99.3, s 99.5`: `HIT_ZONE` false (`s 99.5 < 99.6`), `NEAR_ZONE` true (`s >= 99.2`), `NEAR_MISS_CANDIDATE` true (pure along-track graze).
- [x] AC-5 [M]: mutation rows: (a) AC-3's pose with `NEAR_MISS_ANGLE_MARGIN` forced to 0 gives `NEAR_MISS_CANDIDATE` false; (b) AC-4's pose with `NEAR_MISS_S_MARGIN` forced to 0 gives false. A one-margin or shared-margin implementation must fail at least one row.
- [x] AC-6 [M]: over a fixed pose table (inside hit zone, AC-3 graze, AC-4 graze, clean miss) `HIT_ZONE => NEAR_ZONE` on every row and `HIT_ZONE and NEAR_MISS_CANDIDATE` never both true; no randomly generated rows.

## Implementation Notes
- `NearMissMath.zones(theta_prev, theta, s_prev, s, eff, near, piece)` returning the two booleans; `NEAR_MISS_CANDIDATE = NEAR_ZONE and not HIT_ZONE`. Containment (`HIT_ZONE => NEAR_ZONE`) is a consequence of Story 002's output, not a runtime check.
- Per-hazard `s` broad phase (ADR-0008 Decision 4): skip a hazard whose expanded `s_lo`/`s_hi` does not intersect the tick's swept `s` range before touching pieces; the near-zone range includes `NEAR_MISS_S_MARGIN`.

## Out of Scope
- Story 005: per-hazard state and edge output.
- Story 010: the lint and parity guard (AC-22).

## QA Test Cases
- **AC-3**: see criterion above
  - Given: Graze, the AC-3 pose
  - When: zones evaluated
  - Then: HIT false, NEAR true, CANDIDATE true
  - Edge cases: wrapped delta across the seam via `TubeMath.delta_theta`
- **AC-4**: see criterion above
  - Given: Graze, the AC-4 pose
  - When: zones evaluated
  - Then: HIT false, NEAR true, CANDIDATE true
  - Edge cases: theta term true for every zone on this row
- **AC-5**: see criterion above
  - Given: AC-3 and AC-4 poses with one margin forced to 0
  - When: zones evaluated
  - Then: CANDIDATE false in each row
  - Edge cases: single-margin mutant fails a row
- **AC-6**: see criterion above
  - Given: the 4-row pose table
  - When: every row evaluated
  - Then: implication and exclusion hold on all rows
  - Edge cases: table fixed, deterministic

## Test Evidence
**Story Type**: Logic
**Required evidence**: tests/unit/near_miss_detection/near_miss_detection_swept_zone_test.gd
**Evidence**: tests/unit/near_miss_detection/near_miss_detection_swept_zone_test.gd. Signature `NearMissMath.zones(theta_prev, theta, s_prev, s, eff, near, piece := 0) -> int` (bitmask `HIT_BIT`/`NEAR_BIT`) plus `is_candidate(mask)`; the log code for a non-finite ball state is left to Story 008. dtheta is computed twice (ObstacleMath.swept_hit takes whole footprints).

## Dependencies
- Depends on: Story 002
- Unlocks: Stories 004, 005, 010
