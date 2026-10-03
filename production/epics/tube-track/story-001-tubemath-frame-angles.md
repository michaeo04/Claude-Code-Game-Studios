# Story 001: TubeMath frame, angle wrap and lane/facet formulas

> **Epic**: Tube Track
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-001`, `TR-tube-track-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0013: Distance precision and the render origin (primary, Decision 3 `local_point`); ADR-0009: Test framework and CI; ADR-0002: Game loop and Composition Root
**ADR Decision Summary**: `TubeMath.local_point(theta, h) -> Vector2` returns the x and y of the GDD frame `P` (no `s`); no `TubeMath` function returns a `Vector3` built from `s`. The logical `P` with `z = -s` exists only as a test reference function.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `fposmod(a + PI, TAU) - PI` can return `+PI`; the wrap needs a `>= PI` guard (verified on 4.7.2). Never name a function `wrap`. Every function that can log takes a `log_sink: Callable` (the GDD says `log`, which shadows a global; rename to `log_sink`).
**Control Manifest Rules (this layer)**:
- Required: `TubeMath.local_point(theta, h) -> Vector2`; a view builds `Vector3(p.x, p.y, world_frame.render_z(s))`; cores are `RefCounted` with injected seams, no SceneTree; floats compared with 1e-6 unless an AC states otherwise.
- Forbidden: evaluating `-s` outside `WorldFrame` and `TubeMath`; any `TubeMath` function returning a `Vector3` built from `s`; calling `Time.` from a core.
- Guardrail: tests deterministic, fixed grids and literals, no seeds.

## Acceptance Criteria
- [ ] **AC-1** `P` evaluated at (0,0,0), (PI/2,0,0), (PI,0,0.5), (0,50,0) gives (0,3,0), (3,0,0), (0,-3.5,0), (0,3,-50) (x and y from `local_point`, z from the test reference `P`).
- [ ] **AC-2** `h = -0.5` equals the `h = 0` result with exactly one warning at the log sink; `h = 0` logs nothing; `h = NaN` clamps to 0 with exactly one error.
- [ ] **AC-3** `wrap_angle(PI) = -PI`, `wrap_angle(-PI) = -PI`, `wrap_angle(3*PI/2) = -PI/2`, the literal `-3.141592653589793 - 4.44e-16` lies in [-PI, PI), `delta_theta(0, PI) = -PI` exactly, `delta_theta(-3, 3) = +0.2832` (+/- 1e-4).
- [ ] **AC-4** On the grid `x_i = -100 + 0.02 * i`, i = 0..10000, `wrap_angle(x_i)` and `delta_theta(x_i, x_i + PI)` lie in [-PI, PI), the wrap keeps `sin`, and `abs(delta)` is PI within 1e-9 (sign not asserted).
- [ ] **AC-5** `delta_theta(PI - 0.05, -PI + 0.05) = -0.1` and the reversed call `+0.1`, within 1e-9.
- [ ] **AC-6** NaN or infinite theta: `wrap_angle` returns 0 with one error; `P(NaN, s, h)` has finite components equal to `P(0, s, h)`; NaN or infinite `s` in `P` gives finite components and one error.
- [ ] **AC-16** F6/F7: R = 3 gives w = 13.5 deg (+/- 0.05) and 26 lanes, R = 2.5 gives 22 lanes; `gap(R) <= 0.02 * D` for R = 2.5, 3.0, 3.3 and above it for R = 3.4.

## Implementation Notes
Suggested path `src/core/tube_track/tube_math.gd`, `class_name TubeMath extends RefCounted`, static functions. `wrap_angle(a) = fposmod(a + PI, TAU) - PI`, then subtract TAU if the result is at least PI; non-finite input returns 0 and logs an error. `delta_theta(a, b) = wrap_angle(a - b)`. Implement F6 (`w`, `N_lanes`) and F7 (`gap`) as static functions. Add the test-only reference `P_reference(theta, s, h) -> Vector3` under `tests/support/`, not in `src/`. AC-1 also checks `local_point` plus `-s` against the reference to 1e-6 (rounding noise about 4e-16). Typed signatures, doc comments on public functions.

## Out of Scope
- Story 002: segment index, window sizes, seam spacing (F2, F3, F5)
- Story 003: `TubeConfig.validate()` use of F7/R range
- Story 004: `WorldFrame.render_z`

## QA Test Cases
- **AC-1**: frame points
  - Given: R = 3, D = 0.8 defaults. When: `local_point` at the four inputs. Then: x,y as listed; reference z = -s. Edge cases: 1e-6 tolerance for sin/cos noise.
- **AC-2**: negative and NaN `h`
  - Given: injected counting log sink. When: h = -0.5, 0, NaN. Then: warning count 1, 0, error count 1; values equal h = 0. Edge cases: h = +INF (clamped, logged).
- **AC-3**: wrap constants
  - Given: the listed literals. When: wrap and delta evaluated. Then: exact results. Edge cases: double just below -PI must not return +PI.
- **AC-4**: grid
  - Given: 10001-point grid. When: evaluated. Then: range and sine invariants hold. Edge cases: sign at opposite angles not asserted.
- **AC-5**: seam straddle
  - Given: angles across the range seam. When: delta both ways. Then: -0.1 / +0.1.
- **AC-6**: non-finite
  - Given: NaN, INF, -INF theta and s. When: wrap and P. Then: 0 / finite, one error each.
- **AC-16**: lanes and gap
  - Given: R in {2.5, 3, 3.3, 3.4}. When: F6/F7. Then: values listed. Edge cases: R <= 0 not defined (validated elsewhere).

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tube_track/tube_math_frame_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: test-harness-ci (GUT runner and `project.godot` scaffold)
- Unlocks: Story 003, Story 004, Story 008, Story 011
