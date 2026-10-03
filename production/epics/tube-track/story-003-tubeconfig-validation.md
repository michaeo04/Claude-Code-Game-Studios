# Story 003: TubeConfig resource and validate() failure-code set

> **Epic**: Tube Track
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-003`, `TR-tube-track-010`, `TR-tube-track-011`, `TR-tube-track-012` (partial, see Engine Notes)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary, Decision 1 and 2); ADR-0003: Renderer choice (fog fields); ADR-0009: Test framework and CI
**ADR Decision Summary**: `TubeConfig` is a Resource of scalars, enums and Colors only; `TubeConfig.validate()` owns the Tube Track derived constraints and is passed through unchanged by the map loader (A6). `TubeConfig.from_map` (map-loader epic) returns `base.duplicate()` with map fields set.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: TR-tube-track-012 is Partial (depth fog verified on Forward+ only; Mobile is gated by R-1, Story 013). The failure-code logic here is pure and follows the GDD; Story 013 closes TR-012 on device. A typed `@export` int cannot hold 2.5, so `validate` takes Variant/Dictionary-style inputs for the not-an-integer checks. NaN load of `.tres` is unverified: unit tests build the resource with `TubeConfig.new()`.
**Control Manifest Rules (this layer)**:
- Required: every `@export` of `TubeConfig` is a scalar, enum or `Color`; `validate()` returns a SET of stable failure codes; `load_map` is accepted only from Uninitialized.
- Forbidden: `duplicate_deep()`; mutating a cached loaded Resource; a `Resource`/`Array`/`Dictionary` field on `TubeConfig`; `D` copy on `TubeConfig` (one owner, Ball Movement).
- Guardrail: tests build resources with `.new()`, not by loading `.tres`.

## Acceptance Criteria
- [ ] **AC-12** Base map (v_max 25, L 12, n_seams 1, t_lat 0.1, d_cam 8, depth fog, begin 44, curve 1.0, density 1.0, F_read = F, A required): F = 45.5 (A 5), 84 (A 9), 129.5 (A 12) load. Each one-change row of the GDD table returns exactly its code SET (`NOT_POSITIVE`, `NOT_FINITE`, `VISIBILITY`, `A_TOO_LARGE` with `A_TOO_SMALL` suppressed, `FOG_BEFORE_READ`, none for F_read 46.00, `FOG_DENSITY`, `FOG_MODE`, `FOG_RANGE`, `A_TOO_SMALL`, `A_OUT_OF_RANGE`, v_max rows, and `NO_VALID_F` with the range printed and `VISIBILITY`/`A_TOO_LARGE` suppressed); load failure leaves state Uninitialized.
- [ ] **AC-13** R = 2.4 and 3.4 rejected, 2.5/3.0/3.3 accepted (D 0.8); D = 0.6 with R = 2.5 rejected by `gap(R)`; `L_INVALID` for L = 5, 12.5, 25 and 8 (record prints `L_min` = 9, no `SEAM_HZ`), none for 9, 12, 24; default map loads, L = 9 with A = 11 loads; `n_seams` 0, -1, 2.5 rejected; n_seams = 2 at L 12 rejected with the largest allowed value 1 in a structured `{code, max_n_seams}` record, 1 accepted; B below required and B = 4 rejected.

## Implementation Notes
`TubeConfig extends Resource` holds R, L, A, B, n_seams, SEAM_HZ_MAX, IDLE_SCROLL_SPEED, T_VIS_MIN, REBASE inputs it reads, t_lat (`RECYCLE_STEP_MARGIN`), M_cam, A_MAX/B_MAX/N_MAX, fog fields (`fog_mode`, `fog_depth_begin`, `fog_end_distance`, `fog_depth_curve`, `fog_density`, `readable_distance`) and the Camera values it reads (`rear_extent`, `camera_distance`). `validate(v_max, d: ball diameter)` returns `Array[Dictionary]` records `{code, ...}`; tests compare the code set, not an ordered list. Check finiteness first, then `not (x >= lo and x <= hi)` so NaN fails. Apply the GDD reporting rules: non-finite gives `NOT_FINITE`, non-positive `NOT_POSITIVE` and skips derived checks; `A_TOO_SMALL` only when required A <= A_MAX; empty F range gives only `NO_VALID_F`; below `L_min` only `L_INVALID`. Codes: `NOT_FINITE`, `NOT_POSITIVE`, `VISIBILITY`, `FOG_BEFORE_READ`, `FOG_DENSITY`, `FOG_MODE`, `FOG_RANGE`, `A_TOO_LARGE`, `A_TOO_SMALL`, `A_OUT_OF_RANGE`, `B_OUT_OF_RANGE`, `L_INVALID`, `SEAM_HZ`, `R_RANGE`, `NO_VALID_F`. Add the ADR-0004 unit test that fails if a `Resource`, `Array` or `Dictionary` field is added to `TubeConfig`.

## Out of Scope
- Story 013: Mobile-renderer fog verification (closes TR-012)
- Story 005: `load_map` state behaviour
- map-loader epic: `TubeConfig.from_map`, Phase A/B ordering

## QA Test Cases
- **AC-12**: code sets
  - Given: base map built with `TubeConfig.new()`. When: each table change is applied. Then: returned code set equals the row. Edge cases: NaN/INF rows; the 45.49 and 129.51 boundaries; suppression rules.
- **AC-13**: ranges and records
  - Given: the listed R, D, L, n_seams, B values. When: `validate()`. Then: accept/reject as listed; the `L_INVALID` record carries 9; the `SEAM_HZ` record carries max_n_seams = 1. Edge cases: Variant input 2.5 for n_seams.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tube_track/tube_config_validation_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001 (F7 `gap`), Story 002 (F3, F5 functions)
- Unlocks: Story 005, map-loader epic (A6 pass-through), Story 013
