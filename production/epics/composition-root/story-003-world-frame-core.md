# Story 003: WorldFrame, WorldFrameConfig and the render-origin math

> **Epic**: Composition Root & Game Loop
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: none, defined by ADR-0013
**Requirement**: `TR-tube-track-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0013: Distance precision and the render origin (WorldFrame)
**ADR Decision Summary**: `s` stays unbounded float64; one engine-free `WorldFrame` holds `origin_s` (a whole number of segments) and maps `render_z(s) = -(s - origin_s)`, rebasing when `s - origin_s >= REBASE_SEGMENTS * L`.
**Engine**: Godot 4.7.2 | **Risk**: HIGH (float32 error model is an assumption until PRC-1)
**Engine Notes**: Pure GDScript `RefCounted` plus a `Resource`; only `floor`, `absf` and asserts. Not in the engine reference: the 2-ulp or 8-ulp model (Story 012, PRC-1). Declare float fields as floats (a `.tres` coerces ints).
**Control Manifest Rules (this layer)**:
- Required: `WorldFrame` pure `RefCounted`, `origin_s` float64 exact multiple of `L`, 0 at run start; `render_z(s)` computed in float64; `maybe_rebase` sets `origin_s += floor((s - origin_s) / L) * L` and returns true once; `WorldFrameConfig` validated Resource, `REBASE_SEGMENTS` 84 range [24, 128], `Z_RENDER_MAX` 2048 a constant; in debug `render_z` asserts `abs(result) <= 2 * Z_RENDER_MAX`; `on_run_reset(run_id)` and `reset()` set `origin_s = 0`.
- Forbidden: capping, wrapping or reducing `s`; evaluating `-s` outside `WorldFrame` and `TubeMath`; a double-precision build.
- Guardrail: `(REBASE_SEGMENTS + A + 1) * L <= Z_RENDER_MAX` (default 1128 <= 2048).

## Acceptance Criteria
- [ ] `render_z(s)` equals `-(s - origin_s)` in float64 for fixture values including `s` beyond 9e9 (ADR-0013 VC-1)
- [ ] `maybe_rebase` keeps `origin_s` a multiple of `L`, leaves `s - origin_s` in `[0, L)` after a rebase, returns true once per crossing and false below the threshold (VC-1)
- [ ] The boundary case: `s - origin_s` one ulp below a multiple of `L` (literal 11.999999999999998 at `L` = 12) rebases to the correct segment, remainder in `[0, L)` (VC-1, Risks)
- [ ] `on_run_reset(run_id)` and `reset()` both zero `origin_s` (VC-1, Decision 2)
- [ ] `WorldFrameConfig.validated(log_sink)` clamps `REBASE_SEGMENTS` to [24, 128] and returns a copy without mutating the loaded resource (Key Interfaces)
- [ ] Validation `(REBASE_SEGMENTS + A + 1) * L <= Z_RENDER_MAX` returns `REBASE_Z_EXCEEDS_BUDGET` for `REBASE_SEGMENTS` 128 at `L` 24, and passes for 84/9/12 (VC-1, Decision 4)
- [ ] In a debug build `render_z` asserts `abs(result) <= 2 * Z_RENDER_MAX`; a stale-origin call with raw `s` far from `origin_s` trips it (Decision 4)

## Implementation Notes
Files `src/core/world_frame.gd`, `src/core/world_frame_config.gd`. `WorldFrame._init(config, geometry)` takes the immutable `WorldGeometry` (ADR-0004, built by `GameRoot`; use a fake with `L` and `A` in tests until the map-loader epic delivers it). The validation lives next to `WorldFrame` as a pure function returning an `Array[String]` of codes; `GameRoot` treats a non-empty result as fatal (Story 006). `render_z` is the only place a world distance is cast to 32 bits. No engine calls.

## Out of Scope
- Story 004: `TubeMath.local_point`
- Story 005: rebase propagation to views, soak run
- Story 006: calling the validation at boot

## QA Test Cases
- **AC-1**: `render_z` identity
  - Given: `origin_s` 0, 12, 1008; `s` fixtures
  - When: `render_z(s)`
  - Then: exactly `-(s - origin_s)`
  - Edge cases: s = 0; s = 9e9
- **AC-2/3**: rebase threshold and boundary
  - Given: `s - origin_s` = 1007.999..., 1008.0, 1019.999999999999
  - When: `maybe_rebase`
  - Then: false, true (origin 1008), true with remainder under `L`; second call same tick false
- **AC-4**: reset
  - Given: origin 1008
  - When: `on_run_reset(7)` then `reset()`
  - Then: origin 0 each time
- **AC-5/6**: config
  - Given: `REBASE_SEGMENTS` 10 and 200; 128 at `L` 24
  - When: `validated` / budget check
  - Then: clamps to 24 and 128; code `REBASE_Z_EXCEEDS_BUDGET` for the last
- **AC-7**: debug assert (assert behaviour checked only in debug runs; otherwise pure bound test of the guard predicate)

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/composition_root/world_frame_core_test.gd`
**Status**: [x] Created, passing
**Evidence**: tests/unit/composition_root/world_frame_core_test.gd (16 tests; AC-7 proven by the guard predicate and the violation counter, not by a real assert(), which would abort the run). WorldGeometry is a minimal placeholder in src/core/world/world_geometry.gd.

## Dependencies
- Depends on: Story 001; map-loader epic (`WorldGeometry`; fake until then)
- Unlocks: Story 005, Story 006; tube-track, ball-movement and every view epic story that places a node
