# Story 002: TiltMath pure functions (roll, filter, mapping, median)

> **Epic**: Tilt Input
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-003`, `TR-tilt-input-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; ADR-0009: Test framework and CI (secondary)
**ADR Decision Summary**: Cores are `RefCounted` with injected seams and no engine singletons; `TiltMath` holds the pure static functions F1-F4 with no validation, so they are testable without a scene tree.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `asin` returns radians: convert to degrees. No `nextafter`; use a literal one-ulp-below double in boundary tests. A static and an instance function cannot share a name; never name a function `wrap`.
**Control Manifest Rules (this layer)**:
- Required: `TiltMath` is static, no Node, no `Input.`/`Engine.`/`Time.`/`OS.`; gameplay values come from `TiltConfig`, never hardcoded in code (constants `PHI_MAX` 70, `FS_EFF_MAX` 50, `TAU_FLOOR` 0.005 live in `TiltMath`).
- Forbidden: `_process`/`_physics_process` outside `GameRoot`; sensor reads.
- Guardrail: pure functions, no allocation in the per-frame path.

## Acceptance Criteria
- [ ] **AC-1 [M]**: `roll_deg` of (6,-8,0) is 36.870; (3,0,-4) is 36.870; (0,-9.81,0) is 0; (+-9.81,0,0) is +-90; (4.248,-7.358,-4.905) is 25.66 (+-0.01); `clamp_ratio(1.0000001)` is 1.
- [ ] **AC-2a [M]**: `sensor_sign = -1` negates each AC-1 value.
- [ ] **AC-4 [M]**: alpha(1/60, .05) = 0.283469, alpha(.1, .05) = 0.864665, alpha(0, .05) = 0; tau 0 or -1 floors to `TAU_FLOOR`: alpha(1/60) = 0.964326 (1e-6).
- [ ] **AC-6 [M]**: k = 1: `phi_f` 1.5 gives 0 exactly; 0 gives 0; 14 gives 0.531915; 25 and 40 give 1; -14 gives -0.531915. k = 1.5: +-14 gives +-0.387939.
- [ ] **AC-7 [M]**: 7a sensitivity 2, `phi_f` 7 gives 0.5; 7b sensitivity 0.5, `phi_f` 25.75 gives 0.5; 7c FS 12, DZ 1.8, sensitivity 2 (`dz_eff` 1.2), `phi_f` 3.6 gives 0.5; 7d FS 12, DZ 4, sensitivity 2, `phi_f` 3.6 gives 0.5; 7e FS 45, sensitivity 0.5 (`FS_eff` capped at 50), `phi_f` 25.75 gives 0.5.
- [ ] **AC-11 [M]**: median of 7,1,3,80,5 is 5; of 1,2,3,4,5,80 is 3.5; nine samples at 2 and nine at 6 give 4.0.

## Implementation Notes
F1: `phi = SENSOR_SIGN * deg(asin(clamp(g.x / |g|, -1, 1)))`, uses only `g.x`; `clamp_ratio` is its own helper. F3: `alpha = 1 - exp(-dt / max(tau, TAU_FLOOR))`, `phi_f += alpha * (phi_r - phi_f)`. F4: `FS_eff = min(FS / sensitivity, FS_EFF_MAX)`, `dz_eff = min(DZ, 0.2 * FS_eff)`, `u = clamp(sign(phi_f) * max(0, |phi_f| - dz_eff) / (FS_eff - dz_eff), -1, 1)`, `s = sign(u) * |u|^k`. Median of even counts is the mean of the two middle values. `TiltMath` does no validation (config validation is Story 003). Oracles use `dt = 0.016667`, not `1/60`; tolerance 1e-3 deg, 1e-4 steer, 1e-6 for alpha.

## Out of Scope
- Story 003: config clamping and `KNOB_CLAMPED` logging (AC-4 [C], AC-8).
- Story 005: using these functions inside the `TiltCore` pipeline.
- Story 007: `should_reanchor`; Story 012: `sensor_lost_pause_needed`.

## QA Test Cases
- **AC-1**: roll angle
  - Given: the listed vectors, `sensor_sign` +1
  - When: `TiltMath.roll_deg(g)` and `clamp_ratio(1.0000001)`
  - Then: values within 0.001 (0.01 for the last vector)
  - Edge cases: pitch independence ((3,0,-4) equals (6,-8,0)); ratio rounding above 1
- **AC-2a**: sign flip
  - Given: `sensor_sign = -1`; When: each AC-1 vector; Then: the negated values
- **AC-4**: alpha table incl. dt 0 and tau floor (1e-6)
- **AC-6**: F4 table incl. exact 0 at the dead-zone edge, saturation at 25 and 40, negative symmetry, k 1.5
- **AC-7**: five separate sub-cases 7a-7e, each asserting 0.5 (1e-4)
- **AC-11**: median with outlier, even count, and the two-level case

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tilt_input/tilt_math_pure_functions_test.gd`
**Status**: [x] Created and passing
**Evidence**: tests/unit/tilt_input/tilt_math_pure_functions_test.gd (19 tests: AC-1, AC-2a, AC-4, AC-6, AC-7a-e, AC-11)

## Dependencies
- Depends on: test-harness-ci (GUT runner, spike T-1)
- Unlocks: Story 003, Story 005, Story 006, Story 007
