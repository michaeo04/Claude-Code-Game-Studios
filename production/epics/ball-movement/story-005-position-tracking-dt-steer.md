# Story 005: Position-mode tracking, dt_eff guards and held-steer semantics

> **Epic**: Ball Movement
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/ball-movement.md`
**Requirement**: `TR-ball-movement-005`, `TR-ball-movement-006`, `TR-ball-movement-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `step()` is called once per rendered frame after `RunState.tick` in every phase; `dt_eff` comes from `tick()` already clamped and is 0 outside Running. Ball Movement never reads the engine delta or a clock.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `exp()` and `clamp()` double precision; verified through AC-5/AC-8 oracles. No post-cutoff API.
**Control Manifest Rules (this layer)**:
- Required: POSITION mapping `phi_target = phi_anchor + STEER_ARC * clamp(steer)`; `e = wrap_angle(target - phi)`; `dt_eff <= 0` or non-finite is a no-op (prev = current, `omega` = 0) tested before `alpha`; `dt_eff > dt_max` clamps with `DT_OVER_MAX`; held steer.
- Forbidden: any dead zone, recentering or filtering here (Tilt Input owns them); reading the engine delta; `wrapf(`.
- Guardrail: `|step| <= OMEGA_MAX * dt` every step; no overshoot or reversal.

## Acceptance Criteria
- [ ] **AC-2 [C]** (R1, R10) After a moving step (1/60, steer 0.5), one row per `dt_eff` in {0, -0.001, -inf, NaN, +inf}: `theta`, `s`, `speed`, `t_run` unchanged; `theta_prev == theta`, `s_prev == s`, `omega == 0`. 0 logs nothing; each other value logs exactly one `BAD_DT` (+inf is `BAD_DT`, not `DT_OVER_MAX`); a no-op step with steer NaN logs no `BAD_STEER`.
- [ ] **AC-3 [C]** (edge) `dt_max` 0.1, steer 1, from rest: `dt` 0.1 gives no log, `phi` 0.3, `omega` 3.0, `s` = S(0.1) = 1.0008333; `dt` 0.5 gives the identical state plus one `DT_OVER_MAX`; `dt` 1e-9 still moves the ball.
- [ ] **AC-6 [C]** (R3) Steer +0.5 for 60 steps gives `theta` strictly increasing and > 0; steer -0.5 gives the exact negation.
- [ ] **AC-7 [C]** (R4, F1) From rest at 60 Hz with steer 1, frame 1 gives `phi` 0.05 and `omega` 3.0; over a 10 s sweep table `|step| <= OMEGA_MAX * dt` every step, no overshoot, no reversal.
- [ ] **AC-8 [C]** (F1) Steer to 1: the first frame with `|e| <= 0.05` is 32 / 64 / 128 at 30 / 60 / 120 Hz (frames 31 / 63 / 127 are above); a 0.1 rad target held 0.1 s gives `phi` 0.0811124 at all three rates.
- [ ] **AC-9 [C]** (F1, 0.05 rad tolerance, BLOCKING) Steer = (0.5 / PI) * sin(2 PI t_k), `t_k` the end-of-frame time, 5 s at 30 / 60 / 120 Hz: at common instants (multiples of 1/30 s) the maximum pairwise `|delta phi|` is at most 0.05 (0.0324 measured). Mutation: a fixed `alpha` per frame must fail AC-8 and AC-9. Note: reasoned-confirmed, not yet machine-verified in the reference sim; extend the sim if cheap.
- [ ] **AC-17 [C]** (R2, edge) `valid` false with steer 0 after an accepted 0.5 holds the target for 60 steps, no log; steer NaN, +inf and -inf each hold the last steer with one `BAD_STEER`; steer 5 and -5 equal steer 1 and -1, no log; NaN on the first moving step holds 0; `valid` false with NaN logs nothing.

## Implementation Notes
In `BallCore.step`: guard `dt_eff` first (no-op path sets prev = current, `omega` = 0, never touches the held steer), clamp to `dt_max`, accept/hold `steer`, run `BallMath` F1, publish `omega = (phi_new - phi_old)/dt` before any 2 PI shift (shift itself is Story 006). Held-steer rule: `valid` false wins over a non-finite steer (no log); a non-finite steer with `valid` true logs one `BAD_STEER`. Tests: `tests/unit/ball_movement/ball_movement_tracking_test.gd`, each table row its own test with a fresh core. Use the asymmetric override (`tau` 0.03) wherever a knob matters.

## Out of Scope
- Story 006: anchor re-base, resume, `|phi| > 2 PI` shift, seam chain
- Story 007: RATE mode and latch
- Story 008: determinism replay and the log-code census

## QA Test Cases
- **AC-2**: no-op rows (each `dt_eff` value its own test)
  - Given: a core after one moving step
  - When: `step(dt_eff, 0.5, true, SENSOR)`
  - Then: pose unchanged, prev == current, `omega` 0; logs as stated
  - Edge cases: steer NaN on a no-op step; +inf is `BAD_DT`
- **AC-3**: clamp
  - Given: `dt_max` 0.1
  - When: dt 0.1, 0.5, 1e-9
  - Then: as listed, one `DT_OVER_MAX` only for 0.5
  - Edge cases: tiny dt still moves
- **AC-6/7/8/9**: trajectories
  - Given: fixture core, steer tables
  - When: stepped at 30/60/120 Hz
  - Then: listed frames and values; sine pairwise bound 0.05
  - Edge cases: frames 31/63/127 above threshold
- **AC-17**: held steer
  - Given: accepted 0.5 first
  - When: invalid/non-finite/out-of-range inputs
  - Then: held target, correct `BAD_STEER` counts
  - Edge cases: NaN first moving step holds 0

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/ball_movement/ball_movement_tracking_test.gd` (must pass)
**Evidence**: tests/unit/ball_movement/ball_movement_tracking_test.gd (29 tests: AC-2 test_noop_*, AC-3 test_dt_*/test_tiny_dt_*, AC-6 test_steer_*_half_*, AC-7 test_first_frame_*/test_sweep_table_*, AC-8 test_arrival_frame_*/test_small_target_*, AC-9 test_sine_tracking_*, AC-17 held-steer tests)
**Status**: [x] Passing (CI green 2026-10-04)

## Dependencies
- Depends on: Story 004
- Unlocks: Story 006, Story 007, Story 008, Story 010
