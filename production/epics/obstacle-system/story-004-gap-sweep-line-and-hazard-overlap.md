# Story 004: Safe-gap sweep-line (F3) and hazard overlap validation

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/obstacle-system.md` (Formulas F3; Edge Cases `NO_SAFE_GAP`, `HAZARD_OVERLAP`)
**Requirement**: `TR-obstacle-system-001`, `TR-obstacle-system-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 5, P1)
**ADR Decision Summary**: Validators are pure `ObstacleMath` functions returning stable codes with structured records; `ContentPreflight` composes them exhaustively and deterministically.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Float64 math; compute `BALL_HALF_ANGLE`, `w`, `GAP_MIN` from the injected `R`, `D`, `GAP_MARGIN`, never from fixture constants.
**Control Manifest Rules (this layer)**:
- Required: validators run exhaustively (not fail-fast) in deterministic order; a failing segment is never partially applied; records are structured (code, `s0`, active piece set), not message text.
- Forbidden: engine coupling in `ObstacleMath`; unordered hash-keyed traversal.
- Guardrail: preflight runs offline (CI, editor, debug build), never on the device in release.

## Acceptance Criteria
- [ ] **AC-6 [C]** boundary at `GAP_MIN`: Wall raw gap 0.8254 rad (47.3 degrees) accepted (`open(s0) = GAP_MIN` to 1e-4, check is `>=`); 0.8253 rejected with `NO_SAFE_GAP`; 0.8255 accepted; Near-Ring 40 degree raw gap rejected, 50 degree accepted.
- [ ] **AC-10 [K]** at `s0` = 200.5 Wall is the only active piece and sits exactly at `GAP_MIN` (accepted); a second hazard's piece consuming 0.001 rad more is rejected with a structured `NO_SAFE_GAP` record (`s0`, active piece set).
- [ ] **AC-11 [K]** pair 501/502 rejected with `HAZARD_OVERLAP`; 502 moved to `s_start` 401.6 / `s_end` 402.6 accepted; a row puts 501 and 502 in adjacent segments' home ranges and the check still fires.
- [ ] **AC-38 [K]** joint-extreme corner (`R` 2.5, `D` 1.0, `GAP_MARGIN` 3.5): `BALL_HALF_ANGLE` 0.1674, `w` 0.3349, `GAP_MIN` 1.1722; Near-Ring raw gap 1.507 rad accepted, 0.01 rad narrower rejected. A mutation hardcoding the default constants must fail.

## Implementation Notes
F3: critical `s0` are every piece's `s_eff_start` and `s_eff_end`; `occupied(s0) = sum(theta_eff_max - theta_eff_min)` over active pieces from any hazard; `open = 2*PI - occupied`; require `open >= GAP_MIN` where `GAP_MIN = GAP_MARGIN * w`, `w = 2*asin(D/(2*(R + D/2)))`. `HAZARD_OVERLAP`: effective footprints intersecting in both `theta` and `s`. Wording note: AC-11 says the check runs within a segment plus neighbours, while Edge Cases says pairwise across the whole preflighted library; implement the whole-library version (it satisfies the AC-11 rows). Library traversal order must be deterministic (sorted).

## Out of Scope
- Story 005: `TOO_DENSE`, `TOO_MANY_PIECES`, grace zone, footprint codes.
- Story 011: aggregating all codes (AC-32, AC-37).

## QA Test Cases
- **AC-6**: Given fixture gap values. When the sweep-line runs. Then accept/reject as listed.
  - Edge cases: 1e-4 tolerance at the boundary.
- **AC-10**: Given Wall + an added piece at `s0` 200.5. When validated. Then the record contains `s0` and the piece set.
- **AC-11**: Given 501/502 in same and adjacent segments. When validated. Then `HAZARD_OVERLAP` once per offending pair.
- **AC-38**: Given injected `R/D/GAP_MARGIN`. When validated. Then derived values equal the listed numbers.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/obstacle_system/obstacle_system_gap_overlap_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 003
- Unlocks: Story 011
