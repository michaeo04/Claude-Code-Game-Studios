# Story 005: Footprint, grace-zone, piece-count and spacing validators

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/obstacle-system.md` (Edge Cases footprint validation; Formulas F5)
**Requirement**: `TR-obstacle-system-001`, `TR-obstacle-system-002`, `TR-obstacle-system-012`, `TR-obstacle-system-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 5 P1 code list)
**ADR Decision Summary**: P1 checks each chunk alone and emits stable codes with structured records, exhaustively and in deterministic order.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Detect NaN with `is_nan` / `is_inf` (or `is_finite`), never `==`.
**Control Manifest Rules (this layer)**:
- Required: stable failure codes; exhaustive reporting; no partial application of a failing segment.
- Forbidden: validators with engine coupling or randomness.
- Guardrail: at most `MAX_PIECES_PER_SEGMENT` (12) pieces per segment; at most 192 pieces held (12 x 16 window segments).

## Acceptance Criteria
- [ ] **AC-7 [K]** `FOOTPRINT_NOT_FINITE`: one row per field (`theta_min`, `theta_max`, `s_start`, `s_end`) x (`NaN`, `+inf`, `-inf`); each yields exactly one code and the whole segment call is rejected.
- [ ] **AC-8 [K]** `FOOTPRINT_INVALID_ORDER`: `theta_max < theta_min` (0.1, -0.1) and `s_end < s_start` (101, 100) each give one code; equal bounds (zero-width) pass.
- [ ] **AC-9 [K]** `HOME_SEGMENT_MISMATCH`: piece `s 190..193` declared for segment 16 (`[192, 204)`) rejected; declared for segment 15 passes this check.
- [ ] **AC-12 [K]** `GRACE_ZONE_VIOLATION`: segment 0 piece with `s_start` 10.999 rejected; 11.0 accepted (`< 11`, not `<=`).
- [ ] **AC-31 [K]** `TOO_MANY_PIECES`: exactly 12 pieces accepted, 13 rejected; four 3-piece hazards (12) accepted, a fifth (15) rejected (count sums across hazards bound to the segment).
- [ ] **AC-35 [K]** `TOO_DENSE`: `S_MIN_SPACING` 6.25 u; reads at `s_start` 50 and 56.25 accepted, 50 and 56.24 rejected; a non-adjacent-segment row still fires (whole library); Spike cluster 101 vs a hazard at 55.0 is rejected once, using the cluster's earliest raw `s_start`.

## Implementation Notes
`FOOTPRINT_TOO_WIDE` / `FOOTPRINT_EFF_TOO_WIDE` are covered by Story 003 (AC-2). F5: `S_MIN_SPACING = T_REACT * v_max` (`T_REACT` 0.25 s from Run State registry, `v_max` injected); distinct `hazard_id`s sorted by earliest raw `s_start` across the whole library, consecutive distance `>= S_MIN_SPACING`; a multi-piece hazard is one read. `N_reads_max(L)` stays informational (not enforced). The grace zone: segment 0 pieces need raw `s_start >= 11` u (Ball Movement Rule 5). Report every offending pair, not the first.

## Out of Scope
- Story 003: width codes. Story 004: `NO_SAFE_GAP`, `HAZARD_OVERLAP`. Story 006: hidden rules.
- Story 007: `DUPLICATE_SEGMENT_QUERY` (a runtime guard, AC-14).

## QA Test Cases
- **AC-7**: Given twelve bad-field rows. When validated. Then exactly one `FOOTPRINT_NOT_FINITE` each and no partial binding.
- **AC-8**: Given reversed and equal bounds. Then code only for reversed.
- **AC-9**: Given index 15/16 declaration. Then mismatch only for 16.
- **AC-12**: Given 10.999 and 11.0. Then reject / accept.
- **AC-31**: Given 12/13 and 4x3 / 5x3 pieces. Then boundary behaviour as listed.
- **AC-35**: Given the four rows. Then accept at exactly 6.25, reject 0.01 short, one code for the cluster.
  - Edge cases: float noise at exactly `S_MIN_SPACING` (use the documented boundary values).

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/obstacle_system/obstacle_system_footprint_validators_test.gd`
**Status**: [~] Created and passing; AC-9 gap open
**Evidence**: `obstacle_system_footprint_validators_test.gd` (17 tests for AC-7, 8, 12, 31, 35 and the home-segment validator).
**Gap (stays Ready)**: AC-9 says piece `s 190..193` declared for segment 15 passes, but the GDD Edge Cases rule requires the whole raw range inside `[i*L, (i+1)*L)` and 193 >= 192. Implemented the Edge Cases rule (full containment); the test uses `190..191.5` for the passing row and asserts `190..193` is rejected for 15. Needs a GDD/AC decision (fix AC-9 wording, or relax to `s_start`-only).

## Dependencies
- Depends on: Story 003
- Unlocks: Story 011
