# Story 001: NearMissConfig, validation and test fixtures

> **Epic**: Near-Miss Detection
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-001`, `TR-near-miss-detection-009`, `TR-near-miss-detection-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format; ADR-0009: Test framework and CI
**ADR Decision Summary**: ADR-0008 keeps `NearMissMath` on the approved world-space formulas; the knobs live in a data-driven Resource validated at load. ADR-0009 fixes GUT and the `_test.gd` naming.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Resource subclass with typed `@export` knobs and `validated(log_sink)`; log through `LogLevel` and the 4-argument sink `(level, code, key, message)` in `src/core/log/log_level.gd`. Follow `src/core/obstacle/obstacle_config.gd`. GUT discovery needs `*_test.gd` (ADR-0009, spike T-1).
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [ ] AC-7 [K]: `NEAR_MISS_ANGLE_COEFF` = 0 or negative, and separately `NEAR_MISS_S_COEFF` = 0 or negative, each reject config load with one `NEAR_MISS_MARGIN_NONPOSITIVE` log per offending value; both coefficients at the safe-range floor 0.5 pass with zero log lines.
- [ ] AC-27 [K, ADVISORY]: the shipped `NearMissConfig.tres` equals the Tuning Knobs table (`NEAR_MISS_ANGLE_COEFF` 1.0, `NEAR_MISS_S_COEFF` 1.0) and validates with zero log lines.
- [ ] Fixtures (GDD AC preamble): `make_near_miss_fixture()` (registry defaults R 3.0, D 0.8, v_max 25, BALL_HALF_ANGLE 0.1179, w 0.2358, GAP_MARGIN 2.5, GAP_MIN 0.5896 plus both coefficients 1.0; derived `NEAR_MISS_ANGLE_MARGIN` 0.1179 and `NEAR_MISS_S_MARGIN` 0.4) and the three worked hazards Graze 701, Spike cluster 101, Double Gate 202.

## Implementation Notes
- `src/core/near_miss/near_miss_config.gd` (`class_name NearMissConfig`), shipped values in `assets/data/` as `NearMissConfig.tres`. Derived margins are computed from the coefficients, never stored as knobs: `NEAR_MISS_ANGLE_MARGIN = ANGLE_COEFF * BALL_HALF_ANGLE`, `NEAR_MISS_S_MARGIN = S_COEFF * (D / 2)`.
- The safe range 0.5-1.5 is documentation; the only rejection code the GDD defines is `NEAR_MISS_MARGIN_NONPOSITIVE`. Do not invent a code for an out-of-range positive value.
- Fixtures go in `tests/support/near_miss_fixture.gd` (framework-free, like `tests/support/obstacle_fixture.gd`); `make_ball_state_stub`, `make_hazard_bound_stub` and `make_core` are added by Stories 002-005 as their subjects appear.

## Out of Scope
- Story 002: the F1-NM expansion itself.
- Story 005: `NearMissCore` and `make_core`.

## QA Test Cases
- **AC-7**: see criterion above
  - Given: a config with ANGLE_COEFF = 0, then -0.1, then S_COEFF = 0, then -0.1, then both 0.5
  - When: `validated(sink)` runs
  - Then: exactly one `NEAR_MISS_MARGIN_NONPOSITIVE` per offending coefficient (key names the knob); the floor row logs nothing
  - Edge cases: both coefficients bad: two logs, not one
- **AC-27**: see criterion above
  - Given: the shipped `.tres` loaded from disk
  - When: validated
  - Then: values equal 1.0 / 1.0 and zero log lines
  - Edge cases: ADVISORY: a miss is a finding, not a block

## Test Evidence
**Story Type**: Logic
**Required evidence**: tests/unit/near_miss_detection/near_miss_detection_config_test.gd
**Status**: [ ] Not yet created

## Dependencies
- Depends on: None (cross-epic: test-harness-ci for GUT; obstacle-system story 002 fixture pattern)
- Unlocks: Stories 002-012
