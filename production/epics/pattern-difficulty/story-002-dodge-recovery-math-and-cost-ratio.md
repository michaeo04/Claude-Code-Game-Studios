# Story 002: Dodge-recovery math, opposing test and cost ratio

> **Epic**: Pattern & Difficulty
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (Core Rule 8; Formulas F2, F3)
**Requirement**: `TR-pattern-difficulty-010`, `TR-pattern-difficulty-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `opposing` uses the wrapped angular difference (at most PI), never a raw `abs`; spacing math lives in the pure `PatternMath`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Pure float64 math; no post-cutoff API.
**Control Manifest Rules (this layer)**:
- Required: `opposing(p,q)` = any angle pair with wrapped `abs(delta_theta) > ANGULAR_REVERSAL_THRESHOLD` (strict `>`), false if either set is empty; `DODGE_RECOVERY_S = T_DODGE_180 * v_max`; F3 delegates to Ball Movement's `BallMath.T`.
- Forbidden: raw `abs` on angles; restating only the middle branch of F5a; `randf`/`randomize`.
- Guardrail: `DODGE_RECOVERY_S` 26.6 u at defaults, always at least 3.76x `S_MIN_SPACING`.

## Acceptance Criteria
- [ ] **AC-14** At the default threshold (PI/2), a 100 deg pair classifies opposing. Threshold PI/6 wrongly flags a 40 deg pair 10 u apart (rejected where the default accepts); threshold 5*PI/6 wrongly accepts a 140 deg pair 10 u apart (where the default rejects with `DODGE_RECOVERY_VIOLATION`). Both mutations give a different verdict than the default on the same fixture pair.
- [ ] **AC-30** At `BALL_LAG_TAU` = 0, `cost_ratio(PI/2)` = `(1.5708 - 0.05) / (3.1416 - 0.05)` approx 0.492 (not 0.500, not NaN). At `BALL_LAG_TAU` = 0.015 (`OMEGA_MAX` = 3.0) the third-branch formula `(X-eps)/OMEGA_MAX` applies, not the `ln(K/eps)` branch. A middle-branch-only restatement must fail both rows.

## Implementation Notes
Add to `PatternMath`: `opposing(angles_a, angles_b, threshold)` using `BallMath.wrap_angle` for the delta; `dodge_recovery_s(t_dodge_180, v_max)`; `cost_ratio(x, eps, omega_max, tau)` = `BallMath.T(x, eps, ...) / BallMath.T(PI, eps, ...)` (delegation, never a local copy of F5a). `eps` is 0.05 rad. The `DODGE_RECOVERY_VIOLATION` verdict in the mutation rows is produced by the within-chunk validator (Story 004); here assert the classification and required spacing numbers (the mutation proof compares `opposing()` and the required floor on a fixture pair).

## Out of Scope
- Story 004: the within-chunk validator that emits `DODGE_RECOVERY_VIOLATION`.
- Story 010: cross-chunk padding use of these functions.
- Open Question 1 (`STEER_ARC` crossover) is not resolved here.

## QA Test Cases
- **AC-14**: threshold placement is load-bearing
  - Given: pair at 100 deg, pair at 40 deg / 10 u, pair at 140 deg / 10 u; thresholds PI/2, PI/6, 5*PI/6. When: `opposing` and the required floor are evaluated. Then: default flags 100 deg and 140 deg, not 40 deg; PI/6 flags 40 deg; 5*PI/6 does not flag 140 deg.
  - Edge cases: strict `>` at exactly the threshold (not opposing); a pair across the +-PI seam is classified by the wrapped delta.
- **AC-30**: three-branch delegation
  - Given: `OMEGA_MAX` 3.0, tau 0 and 0.015, eps 0.05. When: `cost_ratio(PI/2)` runs. Then: approx 0.492 at tau 0 (1e-3); third branch at 0.015; finite in all rows.
  - Edge cases: tau at `eps/OMEGA_MAX` boundary (about 0.0167) resolves through the correct branch.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_math_test.gd` (AC-14, AC-30)
**Status**: [x] Created and passing
**Evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_math_test.gd`. AC-14, AC-30 proven; the DODGE_RECOVERY_VIOLATION verdict itself is Story 004.

## Dependencies
- Depends on: Story 001; ball-movement `BallMath.T` and `wrap_angle` (exist in `src/core/ball_movement/ball_math.gd`)
- Unlocks: Stories 004, 008, 010
