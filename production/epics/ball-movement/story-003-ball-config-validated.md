# Story 003: BallConfig.validated() clamps and the derived T_DODGE_180 check

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md`
**Requirement**: `TR-ball-movement-003`, `TR-ball-movement-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary); ADR-0004: Map Loader and MapConfig (secondary, `validated(log_sink)` copy pattern)
**ADR Decision Summary**: Validated copies are made with `duplicate()` of a scalar-only resource and never reassign fields on the loaded instance; the shipped resource is left untouched.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `Resource.duplicate()` (shallow) on a scalar-only resource; `duplicate_deep()` is forbidden in this project. No post-cutoff API.
**Control Manifest Rules (this layer)**:
- Required: `validated(log_sink)` returns a clamped copy; NaN or infinite takes the default; one `KNOB_CLAMPED` per value changed; the derived check lowers `BALL_LAG_TAU` by bisection (`|err| <= 1e-9` or 60 iterations), never `OMEGA_MAX`.
- Forbidden: writing to the loaded resource; `duplicate_deep`; raising `OMEGA_MAX` to satisfy the ceiling.
- Guardrail: log codes are exactly `BAD_DT`, `DT_OVER_MAX`, `BAD_STEER`, `KNOB_CLAMPED`, error level.

## Acceptance Criteria
- [ ] **AC-19 [K]** One row per knob, just outside gives one `KNOB_CLAMPED` and the boundary gives none: `STEER_ARC` 2.0 to 2.09 and 3.2 to PI; `tau` -0.01 to 0 and 0.073 to 0.072; `OMEGA_MAX` 2.7 to 2.75 and 4.1 to 4.0; `V_START` 5.9 to 6 and 14.1 to 14; `V_MAX` 17.9 to 18 and 30.1 to 30; `T_RAMP` 44 to 45 and 241 to 240, while `T_RAMP` 0 or less is accepted with no log; `D` 0.59 to 0.6 and 1.01 to 1.0; NaN or infinite on any knob takes the default with one line; `MAPPING_MODE` 7 becomes POSITION with one line; an injected `dt_max` of 0, negative or NaN becomes 0.1 with one line; validation returns a copy and leaves the shipped resource unchanged.
- [ ] **AC-19b [K]** Invariant (no fixed root): for any pre-clamp `(OMEGA_MAX, BALL_LAG_TAU)` with `T(PI, 0.05)` > `T_DODGE_180_MAX` (1.14 s) the corrected `BALL_LAG_TAU` satisfies `T(PI, 0.05) == 1.14 +- 1e-9` and is strictly smaller than before; `OMEGA_MAX` is bit-identical; exactly one `KNOB_CLAMPED`. A pair already within the ceiling triggers no correction and logs nothing. Worked example: (2.75, 0.072) gives 1.169487 s and corrects to 0.046964.
- [ ] **AC-19c [K]** At `OMEGA_MAX` 2.75 the pre-clamp `tau` landing exactly on the ceiling is 0.046964: that value minus 1e-6 (T = 1.139999) triggers no clamp; plus 1e-6 (T = 1.140001) triggers exactly one `KNOB_CLAMPED`.
- [ ] **AC-28 [K]** (ADVISORY) The shipped `assets/data/ball_config.tres` equals the Tuning Knobs table and validates with zero `KNOB_CLAMPED`.

## Implementation Notes
Add `validated(log_sink: Callable) -> BallConfig` and a validation for the injected `dt_max` (falls back to 0.1 with one `KNOB_CLAMPED`) to `ball_config.gd`. Order: individual knob clamps first, then the derived check using `BallMath.T(PI, 0.05)` on the already-clamped values; bisection over `[0, current clamped tau]`. `T_DODGE_180_MAX` is 1.14 s (derived from Tube Track `T_VIS_MIN` 1.5 minus 0.25 reaction minus 0.11 latency; re-derive if any changes). `T_RAMP <= 0` is a sentinel, not a clamp. Tests: `tests/unit/ball_movement/ball_movement_config_test.gd` (AC-19, 19b, 19c) and `tests/advisory/ball_movement/ball_movement_shipped_config_test.gd` (AC-28).

## Out of Scope
- Story 004: how `BallCore` consumes the validated config
- Story 013: F5b latency verification on device

## QA Test Cases
- **AC-19**: one row per knob boundary
  - Given: `make_ball_fixture()` with one knob overridden (asymmetric, e.g. `tau` 0.03 where the default would hide a bug)
  - When: `validated(sink)` runs
  - Then: out-of-range gives the boundary value and exactly one `KNOB_CLAMPED`; on-boundary gives none; the source resource is unchanged
  - Edge cases: NaN/INF on every knob; `MAPPING_MODE` 7; `dt_max` 0/-1/NaN; `T_RAMP` 0 and -5 accepted
- **AC-19b**: derived check invariant
  - Given: pairs including (2.75, 0.072) and an in-ceiling pair
  - When: validated
  - Then: corrected tau satisfies the 1e-9 invariant and is smaller; `OMEGA_MAX` bit-identical; one log
  - Edge cases: 60-iteration cap reached without error blowup
- **AC-19c**: boundary pair
  - Given: `OMEGA_MAX` 2.75, tau 0.046964 -/+ 1e-6
  - When: validated
  - Then: minus gives zero logs, plus gives exactly one
  - Edge cases: none
- **AC-28**: shipped file
  - Given: `ball_config.tres`
  - When: validated with a recording sink
  - Then: zero `KNOB_CLAMPED`, values equal the table
  - Edge cases: float64 round trip

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/ball_movement/ball_movement_config_test.gd` (must pass); AC-28 in `tests/advisory/ball_movement/`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001, Story 002
- Unlocks: Story 004; composition-root (validated config feeds `WorldGeometry` and `CameraMath.published`)
