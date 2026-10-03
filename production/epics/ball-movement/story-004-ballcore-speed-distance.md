# Story 004: BallCore shell, reset and forward speed/distance integration

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md`
**Requirement**: `TR-ball-movement-002`, `TR-ball-movement-008`, `TR-ball-movement-017`, `TR-ball-movement-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0013: Distance precision and the render origin (`s` never reduced); ADR-0009: Test framework and CI
**ADR Decision Summary**: `GameRoot` calls `Ball.step` once per frame after `RunState.tick`; `BallCore` is an engine-free `RefCounted`. `s` is float64, never wrapped, capped or re-based; render precision is solved by `WorldFrame`.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: float64 arithmetic in GDScript is NEEDS VERIFICATION (ADR-0008); AC-22 (100,000 frames) is the evidence. No post-cutoff API.
**Control Manifest Rules (this layer)**:
- Required: `BallCore` takes the validated `BallConfig`, the injected `dt_max` and a `log_sink` `Callable(level, code, message)`; events `reset()`, `on_resumed()`, `step(dt_eff, steer, valid, input_source)`; `s += S(t_new) - S(t_old)`, `t_run` integrated internally.
- Forbidden: any engine call, `Time.`, `Input.`; a left-Riemann `speed * dt`; capping or wrapping `s`; persisted state (TR-022).
- Guardrail: `|s - S(t_run)| <= 1e-6` after 100,000 frames.

## Acceptance Criteria
- [ ] **AC-21 [C]** (R7) `s` after 45 / 90 / 120 s is 618.75 / 1575 / 2325 (1e-6) at 30, 60 and 120 Hz and `speed` 17.5 / 25 / 25; the first 1/60 step gives `s` 0.1666898 and `speed` 10.0027778; `s` is equal across a steer table of +1, -1, 0, NaN and `valid` false (speed and distance ignore steer). Mutation: a left-Riemann `speed * dt` under-counts 0.125 u at 90 s and must fail.
- [ ] **AC-22 [C]** (F6) 100,000 frames at 1/60 with a varied steer table: `|s - S(t_run)| <= 1e-6` and `t_run` equals an independently summed `dt`.
- [ ] Shape (supports AC-1/AC-24, asserted there): a fresh core exposes read-only `theta`, `theta_prev`, `s`, `s_prev`, `speed`, `omega`, `radius` (D/2) and test getters `phi`, `phi_anchor`, `w`, `t_run`; `reset()` is synchronous and sets everything to the Rule 9 values with `speed = speed(0)`; no save/persistence call exists (TR-022).

## Implementation Notes
`src/core/ball_movement/ball_core.gd` (`class_name BallCore extends RefCounted`). Constructor `(cfg: BallConfig, dt_max: float, log_sink: Callable)`. This story implements state, `reset()`, getters and the distance/speed part of `step()` using `BallMath.S`/`speed`; the angular part is Story 005 and later. Keep `reset()` free of loops, allocation, `.new()` and `load(` (Story 008 lints and measures it). Fill in `make_core` in `tests/support/ball_fixtures.gd`. Tests: `tests/unit/ball_movement/ball_movement_distance_test.gd`; the 100,000-frame test must stay well inside the CI time budget.

## Out of Scope
- Story 005: angular tracking, `dt_eff` guards, held steer
- Story 006: anchor, resume, published previous values
- Story 008: reset-equals-fresh (AC-1), log codes (AC-18)

## QA Test Cases
- **AC-21**: speed and distance
  - Given: fixture core, steer table constants
  - When: stepping to 45/90/120 s at 30, 60, 120 Hz; first step at 1/60
  - Then: `s` and `speed` match to 1e-6; `s` identical across the steer table
  - Edge cases: NaN steer and `valid` false do not change `s`; mutation with Riemann sum fails
- **AC-22**: long run
  - Given: 100,000 frames at 1/60, LCG steer
  - When: compared with `BallMath.S(sum of dt)`
  - Then: `|s - S(t_run)| <= 1e-6`; `t_run` equals the independently summed `dt`
  - Edge cases: summation done in float64 by the test

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/ball_movement/ball_movement_distance_test.gd` (must pass)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001, Story 002, Story 003
- Unlocks: Story 005, Story 006, Story 007, Story 008; tube-track (consumes `s`)
