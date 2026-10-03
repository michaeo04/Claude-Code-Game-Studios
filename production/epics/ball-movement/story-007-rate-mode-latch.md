# Story 007: RATE mapping (F3) and the mapping-mode latch

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md`
**Requirement**: `TR-ball-movement-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary); ADR-0002: Game loop, Composition Root and tick order (secondary)
**ADR Decision Summary**: Pure cores are tested with injected seams and deterministic tables. The MVP cut of FALLBACK is at the driver/game-flow level, not inside `BallCore`.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none post-cutoff.
**Control Manifest Rules (this layer)**:
- Required: RATE mode and the FALLBACK latch stay in `BallCore`; the latch is set on the first step with `dt_eff > 0` after `reset()` from `MAPPING_MODE` RATE or `input_source` FALLBACK; `on_resumed()` sets `w` to 0 and does not re-latch.
- Forbidden: the production driver passing FALLBACK in the MVP (a no-sensor device is blocked at HUD/Menus); removing the RATE code as dead.
- Guardrail: `|dphi| <= OMEGA_MAX * dt`; `w` in `[-OMEGA_MAX, OMEGA_MAX]`.

## Acceptance Criteria
- [ ] **AC-14 [C]** (F3) RATE: steer 1 from rest at 1/60 gives `w` 0.727605 and `phi` 0.0063437 (1e-7); 0.1 s at 30 / 60 / 120 Hz gives 0.153998 (1e-6); steer 1 for 1 s then 0 coasts 0.18 rad (+-1e-3); `on_resumed()` sets `w` 0; `tau` 0 gives `w = OMEGA_MAX * steer`; a held 0.5 ends at 1.5 rad/s.
- [ ] **AC-15 [C]** (R6) Mode truth table with the discriminator 120 steps of steer 0.5 then 240 of 0: (POSITION, SENSOR) returns `theta` to exactly 0; (POSITION, FALLBACK), (RATE, SENSOR) and (RATE, FALLBACK) leave it non-zero.
- [ ] **AC-16 [C]** (R6) The mode latches on the first step with `dt_eff > 0` after `reset()`: a no-op step carrying FALLBACK does not latch; a mid-run flip is ignored either way and `on_resumed()` does not re-latch; `reset()` re-arms it (FALLBACK run, `reset()`, SENSOR run gives POSITION); any value other than FALLBACK counts as SENSOR.

## Implementation Notes
F3: `w_ss = OMEGA_MAX * clamp(steer)`; `dphi = w_ss*dt + (w - w_ss)*tau*alpha`; `w = w_ss + (w - w_ss)*(1 - alpha)`; `phi += dphi`; anchor unused. Reuse the Story 005 `dt` guards and held-steer rules. The latch is a pure `BallCore` field cleared in `reset()`. Document in a code comment that the MVP driver never passes FALLBACK (GDD Rule 6, B9). Tests: `tests/unit/ball_movement/ball_movement_rate_mode_test.gd`.

## Out of Scope
- Wiring FALLBACK in the driver (post-MVP; BM-7 removed)
- BM-5 POSITION vs RATE comparison (Story 016)

## QA Test Cases
- **AC-14**: RATE oracles
  - Given: fixture with `MAPPING_MODE` RATE
  - When: the listed drives run at 30/60/120 Hz
  - Then: values as listed within tolerance
  - Edge cases: `tau` 0; release coast
- **AC-15**: truth table
  - Given: four (mode, source) combinations, fresh core each
  - When: 120 steps of 0.5 then 240 of 0
  - Then: POSITION/SENSOR returns to exactly 0, others non-zero
  - Edge cases: none
- **AC-16**: latch
  - Given: no-op FALLBACK step, mid-run flips, resume, reset
  - When: sequences run
  - Then: latch behaviour as listed
  - Edge cases: non-FALLBACK values treated as SENSOR

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/ball_movement/ball_movement_rate_mode_test.gd` (must pass)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 005, Story 006
- Unlocks: Story 008, Story 016 (BM-5 comparison configuration)
