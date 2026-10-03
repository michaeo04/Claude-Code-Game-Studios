# Story 001: BallMath pure functions (wrap_angle, F1 step, F2 speed and S, F5 T)

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md`
**Requirement**: `TR-ball-movement-001`, `TR-ball-movement-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary, test rules); ADR-0002: Game loop, Composition Root and tick order (secondary, `dt_eff` contract)
**ADR Decision Summary**: GUT 9.x, `tests/unit/<system>/`, deterministic float tests at 1e-6 unless an AC says otherwise. `BallMath` is a stateless pure static class, no engine calls.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: "GDScript `float` is 64-bit end to end" is NEEDS VERIFICATION (ADR-0008); AC-5b's `T(PI, 0.05)` oracle doubles as the `ln()` precision check. `wrap` is a GDScript global and must not be used as a function name; use `wrap_angle`. Built-in `wrapf` is forbidden in `ball_math.gd` (GDD Rule 13).
**Control Manifest Rules (this layer)**:
- Required: pure engine-free static functions; `wrap_angle(x) = x - 2 PI * floor((x + PI) / (2 PI))` is the one canonical copy shared verbatim with Tube Track; oracles from `tools/reference-sim/ball_movement.js`.
- Forbidden: the token `wrapf(`; `const` container literals and top-level subscript assignment in `ball_math.gd`; `Input.`, `Time.`, `OS.`; randomness.
- Guardrail: 1e-6 float tolerance, exact `==` for integers; tests deterministic, no file I/O.

## Acceptance Criteria
- [ ] **AC-5 [M]** (F1) `step(e, dt, tau)`: (1.0, 1/60, 0.06) 0.05; (0.1, 1/60, 0.06) 0.0242535; (-1.0, ...) -0.05; `tau` 0: `e` 0.03 gives 0.03, `e` 0.1 gives 0.05; guard: `dt` 1e-5 with `tau` 9.99e-5 gives `alpha` 1 and `tau` 1e-4 gives 0.095163; snap: a residual of 9.9e-7 gives `phi == target`, 1.01e-6 does not.
- [ ] **AC-5b [M]** (F5a) `T(X, eps)` both branches and domain guard: `T(PI, 0.05)` = 1.064054; `T(PI/2, 0.1*PI/2)` = 0.471771; `eps == K` (X PI, eps 0.18) both branches 0.987198; `T(0, 0.1)` = 0, `T(0.1, 0.1)` = 0, `T(0.1 + 1e-6, 0.1)` = 0.008601; a sweep of `X` 0..PI in PI/8 steps at eps {0.01, 0.05, 0.1, 0.5} never negative; mutation: removing the `X <= eps` guard must fail a row.
- [ ] **AC-20 [M]** (F2) `S(0, 45, 90, 120)` = 0, 618.75, 1575, 2325; `speed` = 10, 17.5, 25, 25; `S(682.36) == 16384` (1e-9); continuity at `T_RAMP`; `T_RAMP <= 0` gives `speed` 25 from `t` 0 and `S(t) = 25 t` (sentinel checked first, no NaN at `t` 0); `speed` monotone over 0 to 200 s.

## Implementation Notes
Create `src/core/ball_movement/ball_math.gd` (`class_name BallMath extends RefCounted`) with static `wrap_angle`, the F1 step (shortest-arc `e`, `alpha = 1 - exp(-dt/tau)`, `alpha = 1` when `tau < 1e-4`, clamp to +-OMEGA_MAX*dt, snap when `|e - step| < 1e-6`), `speed(t, cfg)` and `S(t, cfg)` with the `T_RAMP <= 0` sentinel first, and `T(X, eps)` with the `X <= eps` guard. Parameters are passed in (no state, no config coupling beyond scalars). Test file `tests/unit/ball_movement/ball_movement_math_test.gd`; each table row is its own test. Oracle numbers come from `tools/reference-sim/ball_movement.js`; do not recompute them by hand.

## Out of Scope
- Story 002: `BallConfig` resource and shared fixtures
- Story 009: the `wrapf(` / const-container lint over this file
- Story 005: using the F1 step inside `BallCore`

## QA Test Cases
- **AC-5**: F1 step table
  - Given: `tau`/`OMEGA_MAX` 0.06/3.0 passed as scalars
  - When: `step` is called for each (e, dt, tau) row and the snap pair
  - Then: results equal the listed values to 1e-6; `alpha` guard rows give 1 and 0.095163
  - Edge cases: `dt` 1e-5 with `tau` just under and at 1e-4; residual 9.9e-7 vs 1.01e-6
- **AC-5b**: T(X, eps)
  - Given: defaults `OMEGA_MAX` 3.0, `tau` 0.06 (K = 0.18)
  - When: each table row and the swept grid are evaluated
  - Then: listed values to 1e-6; no swept value is negative
  - Edge cases: `eps == K` boundary, `X == eps`, `X = eps + 1e-6`, `X` 0
- **AC-20**: speed and S
  - Given: V_START 10, V_MAX 25, T_RAMP 90 and a `T_RAMP` 0 / -1 variant
  - When: `S` and `speed` are evaluated at the listed times
  - Then: values equal the listed oracle; sentinel yields 25 and `25 t`
  - Edge cases: `t` exactly `T_RAMP`; `t` 0 with sentinel (no NaN)

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/ball_movement/ball_movement_math_test.gd` (must pass)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: test-harness-ci (GUT vendored, spike T-1 passed)
- Unlocks: Story 003, Story 004, Story 005; tube-track epic (shares `wrap_angle` verbatim)
