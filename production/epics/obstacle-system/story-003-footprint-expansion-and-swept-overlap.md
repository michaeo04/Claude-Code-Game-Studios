# Story 003: Effective footprint (F1) and swept-rectangle overlap (F2)

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/obstacle-system.md` (Formulas F1, F2; Core Rule 2)
**Requirement**: `TR-obstacle-system-001`, `TR-obstacle-system-003`, `TR-obstacle-system-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 3, 4)
**ADR Decision Summary**: `ObstacleMath` keeps the approved world-space float64 formulas (F1 expansion, F2 swept overlap and `arc_overlap`) and operates on the flat footprint array; collision is fully analytic.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: GDScript `float` is expected to be 64-bit end to end (NEEDS VERIFICATION, ADR-0008 item 7). `fposmod(a + PI, TAU) - PI` can return `+PI`; `fposmod(-1e-20, 5.0)` returns exactly `5.0`. Never name a function `wrap` (use `wrap_angle`); a static and an instance function cannot share a name.
**Control Manifest Rules (this layer)**:
- Required: swept AABB (`s_hit`, `theta_hit` with one `fposmod`, expanded by `BALL_HALF_ANGLE` and `D/2`), float64; `ObstacleMath` is static and pure.
- Forbidden: `CollisionObject3D` / `Area3D` / `RayCast3D` / `PhysicsServer3D`; `wrapf` for arcs; `Vector2/3/4` for footprints.
- Guardrail: one swept hit test per published pair.

## Acceptance Criteria
- [ ] **AC-1 [M]** Picket piece `(-0.05, 0.05, 200.0, 200.3)`: `theta_eff = [-0.1679, 0.1679]`, `s_eff = [199.6, 200.7]` (1e-4). Wall raw span 5.4578 gives effective span 5.6936, under `2*PI`.
- [ ] **AC-2 [M]** raw spans 6.0 (passes both checks), 6.05 (passes `FOOTPRINT_TOO_WIDE`, fails `FOOTPRINT_EFF_TOO_WIDE`, eff 6.2858) and `2*PI` exactly (fails `FOOTPRINT_TOO_WIDE` only, checked before expansion).
- [ ] **AC-3 [M]** Picket at `theta_prev -0.2, theta 0.2, s_prev 199.0, s 202.0`: `theta_hit`, `s_hit`, `HIT` all true; clean miss at `s_prev 150, s 153` gives `HIT` false. An endpoint-only mutation must fail the first row.
- [ ] **AC-4 [M]** seam piece `(2.9, 3.6)` and swept `theta_prev 3.05 -> theta -3.05` gives `HIT` true via the single-`fposmod` `arc_overlap`, no seam branch.
- [ ] **AC-5 [M]** (scope: two numeric facts for one worked case, not a sweep) Picket at `theta -0.3 -> 0.3`, `s 199.0 -> 199.7`: `HIT` true, true closest approach 0.054 u (strictly outside box, `<= ds` 0.7). Second row, joint corner `theta -0.5 -> 0.5`, `s 197.0 -> 204.5`: `HIT` true.

## Implementation Notes
F1: `theta_eff = raw -/+ BALL_HALF_ANGLE`, `s_eff = raw -/+ D/2`, `BALL_HALF_ANGLE = asin(D / (2*(R + D/2)))`. F2: `dtheta = delta_theta(theta, theta_prev)` (Tube Track F1), `swept_start = theta_prev if dtheta >= 0 else theta`, `swept_width = abs(dtheta)`; `arc_overlap(a_start, a_width, b_start, b_width)`: `d = fposmod(b_start - a_start, 2*PI)`; true if `d <= a_width` or `(2*PI - d) <= b_width`; `s_hit = s_prev <= s_eff_end and s >= s_eff_start`. The no-tunnel proof relies on `OMEGA_MAX * DT_MAX < PI` (Story 002). The AABB bias (corner-cut false positive, up to one frame of travel) is deliberate. Footprint bounds are never wrapped at authoring, only compared.

## Out of Scope
- Story 004: F3 gap sweep-line. Story 005: finiteness, order and home-segment codes.
- Story 009: per-tick reporting and the broad phase.

## QA Test Cases
- **AC-1**: Given Picket and R 3.0 / D 0.8. When F1 runs. Then values match to 1e-4; Wall span 5.4578 -> 5.6936.
- **AC-2**: Given three raw spans. When both width checks run. Then codes are none / `FOOTPRINT_EFF_TOO_WIDE` / `FOOTPRINT_TOO_WIDE` only.
  - Edge cases: exactly `2*PI` is not also reported as EFF_TOO_WIDE.
- **AC-3**: Given the step above. When F2 runs. Then HIT true; mutation (independent endpoints) fails.
  - Edge cases: zero-width swept step reduces to point-in-box.
- **AC-4**: Given seam piece and seam-crossing step. When F2 runs. Then HIT true.
  - Edge cases: same piece shifted by `2*PI` classifies identically.
- **AC-5**: Given the two rows. When F2 runs. Then HIT true both; closest approach 0.054 u asserted for row 1.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/obstacle_system/obstacle_system_swept_overlap_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002 (fixture); tube-track epic (`delta_theta` F1)
- Unlocks: Stories 004, 005, 009
