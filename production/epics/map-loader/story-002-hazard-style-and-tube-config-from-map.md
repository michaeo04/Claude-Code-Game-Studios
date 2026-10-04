# Story 002: HazardStyle validation and TubeConfig.from_map

> **Epic**: Map Loader & MapConfig
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: none, defined by ADR-0004
**Requirement**: `TR-map-loader-???` (related: `TR-tube-track-001`..`TR-tube-track-024` family for `TubeConfig`, `TR-environment-theming-001` for `EnvConfig.validated`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary); ADR-0014: Hazard render route (`HazardStyle`)
**ADR Decision Summary**: `HazardStyle` is a scalar-only Resource validated in Phase A step A3b into a clamped copy; `TubeConfig.from_map` returns a shallow `duplicate()` of the base with map-supplied fields set; loaded resources are never written.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `Resource.duplicate()` is shallow and enough for a scalar-only config (verification item 5); a `.tres` coerces an `int` written into a `float` field, so declare floats and write `1.0` in files.
**Control Manifest Rules (this layer)**:
- Required: `EnvConfig.validated(log_sink)` and `HazardStyle.validated(log_sink)` return a clamped copy via `duplicate()`; Phase B keeps only the validated copy, never `def.env`
- Required: every `@export` field of `EnvConfig` and `TubeConfig` is a scalar, an enum or a `Color`
- Forbidden: writing to the loaded `MapDefinition`/`EnvConfig`/`HazardStyle`; `duplicate_deep`
- Guardrail: tolerance `1e-6` for floats unless stated

## Acceptance Criteria
- [ ] `HazardStyle` has the ADR-0014 fields (`height_d_wall`, `height_d_double_gate`, `height_d_near_ring` default 1.0 range 1.0 to 3.0; `height_d_spike` default 1.6 range 1.5 to 3.0; `face_color`, `shade_color`) and `validated(log_sink)` returns a clamped copy
- [ ] `HazardStyle.validated` reports a fatal problem (null result) for `face_color == shade_color` or a non-finite height; an out-of-range height is clamped into its range and logged; the input instance is not modified
- [ ] `TubeConfig.from_map(base, map)` returns a copy with the fog, seam and `readable_distance` fields from `map.env`, plus `rear_extent` and `camera_distance` from the map; the base instance is unchanged
- [ ] A unit test fails if a `Resource`, `Array` or `Dictionary` property is added to `TubeConfig` (shallow duplicate would share state); the same scalar-only check applies to `EnvConfig` and `HazardStyle`
- [ ] `EnvConfig.validated` called twice on the same loaded instance leaves that instance byte-identical (ADR-0004: never reassign fields on the loaded instance)

## Implementation Notes
Files: `src/core/map/hazard_style.gd`, additions to `tube_config.gd` (`from_map`, owned by the tube-track epic; coordinate) and tests. Safe ranges and defaults are the ADR-0014 Decision 3 table; keep them as `@export` fields with range hints, not hardcoded in the validator. Luminance of `face_color`/`shade_color` is read by Environment, never changed here. `EnvConfig.validated` itself belongs to the environment-theming epic; this story only tests the loader's contract on it.

## Out of Scope
- Story 003: Camera values and `camera_far`
- Story 004: how Phase A maps failures to `HAZARD_STYLE_INVALID`

## QA Test Cases
- **AC-1**: HazardStyle fields and clamp
  - Given: `HazardStyle.new()` with `height_d_spike = 9.0`
  - When: `validated(sink)` is called
  - Then: the copy has `height_d_spike = 3.0` and one log entry; the input still reads 9.0
  - Edge cases: value at exactly the range bounds is unchanged
- **AC-2**: fatal style
  - Given: equal colours; and a `NAN` height
  - When: `validated` is called
  - Then: returns null in both cases
- **AC-3**: `from_map`
  - Given: a base `TubeConfig` and a `MapConfig` with distinct sentinel values
  - When: `from_map(base, map)` runs
  - Then: the copy carries the sentinel values; `base` is unchanged; the copy is a different object
- **AC-4**: scalar-only guard
  - Given: `get_property_list()` of the three config classes
  - When: scanned for `TYPE_OBJECT`, `TYPE_ARRAY`, `TYPE_DICTIONARY` on stored properties
  - Then: none found
- **AC-5**: loaded instance untouched
  - Given: an `EnvConfig` with an out-of-range fog value
  - When: `validated` is called twice
  - Then: the original keeps the out-of-range value; both copies are equal

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/map_loader/map_loader_style_and_tube_config_test.gd`
**Status**: [x] Created and passing
**Evidence**: `tests/unit/map_loader/map_loader_style_and_tube_config_test.gd`

## Dependencies
- Depends on: Story 001; tube-track epic (`TubeConfig`); environment-theming epic (`EnvConfig.validated`)
- Unlocks: Story 003, 004
