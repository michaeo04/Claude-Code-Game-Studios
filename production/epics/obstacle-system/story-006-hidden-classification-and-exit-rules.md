# Story 006: hidden() classification, hidden-content gate and exit rule (F4)

> **Epic**: Obstacle System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/obstacle-system.md` (Core Rule 8; Formulas F4, F4b; Edge Cases)
**Requirement**: `TR-obstacle-system-012`, `TR-obstacle-system-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 5 P1: `HIDDEN_CONTENT_FORBIDDEN`, `EXIT_BEYOND_VISIBLE_ARC`, `HIDDEN_UNFAIR`)
**ADR Decision Summary**: `ObstacleMath` keeps F4 `hidden()` as written; the preflight emits the hidden-side codes; `VISIBLE_ARC_HALF_WIDTH` is injected from Camera.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Use `fposmod`, never `wrapf` (`wrapf` is a known wrong tool for arcs). Strict `>` comparisons.
**Control Manifest Rules (this layer)**:
- Required: `ObstacleMath` static and pure; `VISIBLE_ARC_HALF_WIDTH` injected, not owned; deterministic order.
- Forbidden: `wrapf` for arc distance; centre-based classification; lifting the hidden ban in code before OQ2 / OQ15 resolve.
- Guardrail: preflight offline only.

## Acceptance Criteria
- [ ] **AC-34 [M]** `hidden()` rows with `THETA_REF` 0 and `VISIBLE_ARC_HALF_WIDTH_TEST` PI/2: `(-0.3, 0.3)` not hidden; `(PI/2, 2.5)` not hidden (strict `>`) and `(PI/2 + 1e-4, 2.5)` hidden; `(-2.5, -PI/2 - 1e-4)` hidden; `(2.9, 3.4)` hidden; seam `(2.9, 3.6)` and shifted `(-3.3832, -2.6832)` identical; Wall `(0.4127, 5.8705)` not hidden; `(1.2, 2.2)` not hidden; `(5.8, 7.0)` not hidden; Near-Ring not hidden. Centre-based and `theta_min`-only mutations must fail.
- [ ] **AC-15 [C]** `HIDDEN_UNFAIR` frequency only, with every piece `(2.9, 3.4)`: `s_start` 48 and 60 rejected (same or adjacent segment); 48 and 84 (36 u = `HIDDEN_SPAN_MIN_S`) accepted; 48 and 83.999 rejected; 48 and 72 rejected.
- [ ] **AC-36 [K]** `HIDDEN_CONTENT_FORBIDDEN`: `(2.9, 3.4)` rejected despite generous spacing; Wall, `(1.2, 2.2)` and Near-Ring not rejected for this reason; a two-piece hazard with one hidden piece is rejected (per piece).
- [ ] **AC-42 [K]** `EXIT_BEYOND_VISIBLE_ARC` with `VISIBLE_ARC_HALF_WIDTH` 1.0472 injected: Wall gap 0 passes; gap 1.2 and -1.2 rejected (and not also `HIDDEN_CONTENT_FORBIDDEN`); Near-Ring gap PI passes; gap 3.0 rejected; gap 1.0472 passes, 1.0473 rejected; Double Gate gaps -0.8/0.8 pass, 0.8/1.2 rejected once naming the 1.2 gap; Spike exempt.

## Implementation Notes
F4: `W = theta_max - theta_min`, `o = fposmod(THETA_REF - theta_min, 2*PI)`, `d_min = 0 if o <= W else min(o - W, 2*PI - o)`, `hidden := d_min > VISIBLE_ARC_HALF_WIDTH`. F4b: `HIDDEN_SPAN_MIN_S = HIDDEN_SPAN_MIN_TIME * v_max` (36 u); consecutive hidden pieces' `s_start` distance `>=` it, plus the absolute "never two in a row" same-or-adjacent-segment floor. Exit rule: for a type with `theta_solution`, `e = fposmod(theta_solution - THETA_REF, 2*PI)`, `d_exit = min(e, 2*PI - e)`; if `d_exit > VISIBLE_ARC_HALF_WIDTH` the type must be PI-symmetric (`d_exit = PI` within 1e-6), else reject; per solution angle, exhaustive, independent of `HIDDEN_CONTENT_FORBIDDEN`. The ban stays active until OQ2 and OQ15 resolve. The live `T_reveal` (`REVEAL_BUDGET`, AC-33) is an Open Gap with no oracle; do not implement it.

## Out of Scope
- AC-29 (real Camera value plug-in) and AC-33 (`REVEAL_BUDGET`): deferred Open Gaps.
- Story 017: OS-1 playtest.

## QA Test Cases
- **AC-34**: Given the row table. When `hidden()` runs. Then each row classifies as listed; mutations fail.
- **AC-15**: Given hidden narrow pieces at the listed `s_start`. Then accept/reject by distance floor.
  - Edge cases: exactly 36 u accepted.
- **AC-36**: Given the five fixtures. Then only the hidden-piece cases are rejected.
- **AC-42**: Given the gap table. Then each row passes or fails as listed; `>=`, signed-comparison, exempt-all and accept-any mutations fail.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/obstacle_system/obstacle_system_hidden_rules_test.gd`
**Evidence**: `tests/unit/obstacle_system/obstacle_system_hidden_rules_test.gd` (16 tests: AC-34, AC-15, AC-36, AC-42)
**Status**: [x] Passing (CI 2026-10-04)

## Dependencies
- Depends on: Story 003
- Unlocks: Story 011
