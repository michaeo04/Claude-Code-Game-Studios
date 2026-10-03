# Story 006: Anchor, resume re-base, 2 PI shift, published previous values and inertness

> **Epic**: Ball Movement
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/ball-movement.md`
**Requirement**: `TR-ball-movement-007`, `TR-ball-movement-009`, `TR-ball-movement-016`, `TR-ball-movement-023`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0008: Hazard, collision and content format (published swept pair); ADR-0013: Distance precision and the render origin
**ADR Decision Summary**: Run State returns `dt_eff = 0` in Hit, Paused, Resuming and on settling ticks, so the ball is inert by construction. Obstacle and Near-Miss test the swept segment `(theta_prev, s_prev)` to `(theta, s)` after the step; `s` is never reduced.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none post-cutoff.
**Control Manifest Rules (this layer)**:
- Required: `phi_anchor = 0` at reset (no re-base at reset); the first moving step after `on_resumed()` sets `phi_anchor = phi - STEER_ARC * steer`; `phi` and `phi_anchor` shift together by multiples of 2 PI when `|phi| > 2 PI`; `omega` taken before the shift; previous values are those before the step.
- Forbidden: a collider, `CharacterBody3D` or `hit_reported` in the ball (contact is Obstacle's); reading raw world Z.
- Guardrail: sweep per step is at most `V_MAX * dt_max` and `OMEGA_MAX * dt_max`, evaluated against the loaded config.

## Acceptance Criteria
- [x] **AC-4 [C]** (R10) 10 steps of 1/60, then 300 steps of `dt` 0 with changing steer, then 10 steps of 1/60: pose, `t_run` and `speed` are bit-identical across the zeros and the moving frames continue as if absent; `on_resumed()` then `dt` 0 moves nothing and does not consume the re-base.
- [x] **AC-10 [C]** (R5) After `reset()`, steer 0.5 from the first moving step: frame 1 `theta` 0.05, monotone, per-frame move at most 0.05, `phi == PI/2` exactly at frame 72; after a prior run with a non-zero anchor and `reset()`, `phi_anchor == 0`.
- [x] **AC-11 [C]** (R5) Steer 1 to snap (`phi` PI), `on_resumed()`, `step(0, 0.3)` (no re-base), `step(1/60, 0.5)`: `phi_anchor == PI/2`, `phi` unchanged, `omega == 0`; the next step uses that anchor and the re-base does not repeat until another `on_resumed()`; `on_resumed()` then `reset()` then steer 0.5 targets `STEER_ARC * 0.5`.
- [x] **AC-12a [C]** (R5) For any sequence making `|phi|` exceed 2 PI, at the shift step `phi` and `phi_anchor` are each replaced by `value - k * 2 PI` for the same integer `k` (congruent mod 2 PI within 1e-9, and `phi_new - phi_anchor_new == phi_old - phi_anchor_old` within 1e-9); `theta` and `e` bit-identical across the shift; `omega` uses pre-shift values. Asserted as an invariant.
- [x] **AC-13 [C]** (edge) Steer +1 and -1 each end with `theta == -PI` (single-target approach); seam chain "steer 0.95 to snap, `on_resumed()`, step 0.5, then steer 1" gives `theta_prev` 3.134513, `theta` -3.098672.
- [x] **AC-23 [C]** (R8) `theta_prev`, `s_prev` at step k equal `theta`, `s` at k-1 over 300 steps including a seam; at `dt` 0.1 from `t` >= 90, `|s - s_prev|` = 2.5 (1e-9) and `|wrap_angle(delta theta)| <= 0.3`; `radius` 0.4; `omega` at `dt` 0 is 0; `omega` on a snap frame is `(phi_after_snap - phi_before) / dt` (1e-4).

## Implementation Notes
Add `on_resumed()` arming a one-shot re-base consumed by the first step with `dt_eff > 0`; a `dt_eff = 0` step after `on_resumed()` must not consume it. The re-base uses the held steer when the re-base step carries a bad one. The 2 PI shift happens after `omega` is computed. AC-12 (the repeated-resume-reversal accumulation scenario) is an Open Gap in the GDD with no oracle; it is NOT implemented here. TR-023 (segments for `s` = 0..11 u hazard-free because of the up-to-1.064 s reset glide) is a constraint on Pattern & Difficulty content, not on this code; reference it in a code comment and verify it in the pattern epic. Tests: `tests/unit/ball_movement/ball_movement_anchor_test.gd`; AC-13 oracle values come from the reference sim chain (not yet scripted there; extend the sim or document the reasoning).

## Out of Scope
- Story 007: RATE mode `w` reset on resume
- Story 010: scripted Run State sequence (AC-31)
- GDD Open Gap AC-12 (positive accumulation test): no oracle yet

## QA Test Cases
- **AC-4 / AC-10 / AC-11**: inertness and anchor
  - Given: fixture core
  - When: the listed step sequences run
  - Then: bit-identical poses across zeros; `phi == PI/2` at frame 72; `phi_anchor == PI/2` after re-base
  - Edge cases: `on_resumed()` then `dt` 0 keeps the re-base armed; re-base does not repeat
- **AC-12a**: shift invariant
  - Given: a sequence driving `|phi|` past 2 PI
  - When: the shift step fires
  - Then: invariants hold within 1e-9; `theta` bit-identical
  - Edge cases: shift in both directions
- **AC-13 / AC-23**: seam and published state
  - Given: seam-crossing chain; 300-step run; `dt` 0.1 at `t` >= 90
  - When: stepped
  - Then: listed values; prev equals previous current
  - Edge cases: `theta` exactly +-PI

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/ball_movement/ball_movement_anchor_test.gd` (must pass)
**Status**: [x] Created and passing
**Evidence**: `tests/unit/ball_movement/ball_movement_anchor_test.gd` (AC-4, AC-10, AC-11, AC-12a, AC-13, AC-23); AC-12 accumulation stays a GDD Open Gap.

## Dependencies
- Depends on: Story 005
- Unlocks: Story 007, Story 008, Story 010; obstacle-system and camera epics (published pair)
