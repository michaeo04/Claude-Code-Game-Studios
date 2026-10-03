# Story 002: TubeMath segment index, window sizes and seam spacing

> **Epic**: Tube Track
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-002`, `TR-tube-track-010`, `TR-tube-track-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary, test rules); ADR-0013: Distance precision and the render origin (segment index stays an `int`)
**ADR Decision Summary**: Tube Track keeps the segment index as an `int`; cores never store a world z in a `Vector3`. Tests are deterministic, fixed literals, 1e-6 float tolerance.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Use `floori` and `posmod`, never `int()` or `%` (off by one for s < 0). GDScript 4.7.2 has no `nextafter`: test the literal `11.999999999999998`.
**Control Manifest Rules (this layer)**:
- Required: pure static `TubeMath` functions, no engine calls; integer window indices; test with literal doubles one ulp below a boundary.
- Forbidden: `int()`/`%` for segment index; `Time.` in cores.
- Guardrail: `A_MAX` 12, `B_MAX` 3, `N_MAX` 16 are fixed caps.

## Acceptance Criteria
- [ ] **AC-7** (F2) L = 12, N = 12: s = -24, -1, 0, 11.999, 11.999999999999998, 12, 24 give i = -2, -1, 0, 0, 0, 1, 2 and `slot(-1) = posmod(-1, 12) = 11`.
- [ ] **AC-11** (F3) with v_max = 25, t_lat = 0.1, C_b = 6, M_cam = 2: required A and B match the F3 table (L=12: F = 37.5, 84, 129.5 give A = 5, 9, 12 with B >= 1; L=6, F=48 gives A = 10, B >= 2; L=24, F=37.5 gives A = 3; L=9, F=84 gives A = 11; L=6, F=100 gives 19 and is rejected as > A_MAX); the default (A=9, B=2) gives N = 12 <= N_MAX. Configured A = 8 at (L=12, F=84) yields `A_TOO_SMALL` data (required 9), A = 13 `A_OUT_OF_RANGE`, B = 4 `B_OUT_OF_RANGE` (the F3 function reports required and capped values; the code set itself is Story 003).
- [ ] **AC-14** (F5) n_seams = 1, L = 12: seam at 6, every gap over 100 segments is 12.0 (+/- 1e-9 in 64-bit s-space), `f_seam` at v_max = 2.0833 (+/- 1e-6); n_seams = 4, L = 12 (spacing test only): seams at 1.5, 4.5, 7.5, 10.5, every gap including across boundaries 3.0 (+/- 1e-9).

## Implementation Notes
`TubeMath` statics: `segment_index(s, L) = floori(s / L)`, `slot_of(i, N) = posmod(i, N)`, `required_a(F, v_max, t_lat, L) = ceil((F + v_max * t_lat) / L) + 1`, `required_b(C_b, M_cam, L) = ceil((C_b + M_cam) / L)`, `seam_s(i, j, L, n_seams) = i * L + (j + 0.5) * (L / n_seams)`, `f_seam`, `max_n_seams = floor(SEAM_HZ_MAX * L / v_max)`, `l_min = ceil(v_max / SEAM_HZ_MAX)`. `L` is integer-valued so `i * L` is exact. Use `float` (64-bit) for s; segment indices are `int`.

## Out of Scope
- Story 003: reporting codes and the full validator
- Story 005, Story 006: using the index in the window
- Story 008: `segment_content`

## QA Test Cases
- **AC-7**: index and slot
  - Given: L = 12, N = 12. When: index and slot for each s. Then: listed values. Edge cases: one-ulp-below-12 literal stays 0; negative s uses `floori`.
- **AC-11**: F3 table
  - Given: each table row. When: `required_a`, `required_b`. Then: A/B values; L=6,F=100 reports 19 (> A_MAX). Edge cases: F + 2.5 term; rows are F3-only (not loadable maps).
- **AC-14**: seam positions
  - Given: n_seams 1 and 4. When: seam positions over 100 segments. Then: gaps exact within 1e-9; f_seam 2.0833. Edge cases: gap across a segment boundary.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tube_track/tube_math_window_test.gd`
**Status**: [x] Created and passing
**Evidence**: tests/unit/tube_track/tube_math_window_test.gd (AC-7, AC-11, AC-14)

## Dependencies
- Depends on: Story 001 (`TubeMath` file exists)
- Unlocks: Story 003, Story 005, Story 006, Story 008
