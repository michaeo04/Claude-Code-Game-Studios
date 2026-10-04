# Story 001: MapDefinition, MapConfig and loader seam types

> **Epic**: Map Loader & MapConfig
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: none, defined by ADR-0004
**Requirement**: `TR-map-loader-???` (no id registered for this module; related: `TR-environment-theming-001`, `TR-camera-016`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary); ADR-0014 (`hazard_style`, `camera_far` fields); ADR-0008 (`chunk_library` type)
**ADR Decision Summary**: An authored `MapDefinition` resource holds the per-map data; the loader builds an immutable `MapConfig` and runs through injected seams so the whole loader is testable with no engine calls.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Typed exported properties (`@export var env: EnvConfig`) need the `class_name` cache; unit tests run after `godot --headless --import`. `duplicate_deep()` (4.5) is not used.
**Control Manifest Rules (this layer)**:
- Required: `MapDefinition` (Resource) has `map_id`, `env: EnvConfig`, `chunk_library: Resource` (typed `ChunkLibrary` by ADR-0008) and `hazard_style: Resource`; `MapConfig` is a `RefCounted` read-only after build
- Required: `MapLoaderSeams` exposes `load_definition`, `camera_geometry`, `apply_env`, `apply_obstacle`, `apply_pattern`, `apply_hazard_view`, `tube_load`, `send_map_ready`, `base_tube_config`, `log_sink`
- Forbidden: `MapConfig` as an `@export` type; any back-edge from `EnvConfig` to `MapDefinition` or `MapConfig`; storing Camera values in the map file
- Guardrail: core types hold no engine calls (no `ResourceLoader`, `Time`, `OS`)

## Acceptance Criteria
- [ ] `MapDefinition`, `MapConfig` (all eight fields of ADR-0004 Key Interfaces), `MapLoaderCore.Status` (`NOT_LOADED`, `READY`, `FAILED`), `MapLoaderSeams` (overridable base class with failing/neutral defaults, no `@abstract`) and `MapLoaderConfig` exist with the declared field names and types (ADR-0004 Validation: fake-seam unit tests need them)
- [ ] `MapDefinition.new()` and `EnvConfig.new()` can be built in a test without loading any `.tres` (ADR-0004 Validation)
- [ ] `MapDefinition` exports no `Camera` field (`rear_extent`, `camera_distance`, `visible_arc_half_width` are absent); `EnvConfig` has no reference to `MapDefinition` or `MapConfig` (ADR-0004 Decision 1)
- [ ] `MapConfig` is not used as an `@export` type anywhere in `src/`

## Implementation Notes
Files: `src/core/map/map_definition.gd`, `map_config.gd`, `map_loader_seams.gd`, `map_loader_config.gd`, `map_loader_core.gd` (skeleton: `status`, `last_codes`, signal declaration only). `MapLoaderSeams` follows the plain-base-class-with-defaults pattern used for `SaveFs` (ADR-0007), not `@abstract`. `MapLoaderConfig` is a `Resource` for any loader knob (the log rate limit reuse of `RateLimitedLog`); no gameplay value hardcoded. Doc comments on the public API. The `chunk_library` field stays `Resource` here until the ADR-0008 `ChunkLibrary` type exists (Pattern epic); ADR-0004 Ordering Note requires the swap before the Pattern epic starts.

## Out of Scope
- Story 002: `HazardStyle` and `TubeConfig.from_map`
- Story 003: derivation of Camera values and `camera_far`
- Story 004: Phase A behaviour

## QA Test Cases
- **AC-1**: types and seams exist with the declared members
  - Given: the types loaded after `--import`
  - When: a test instantiates each and reads each declared field
  - Then: defaults are as declared; `MapLoaderSeams` defaults return failure/neutral values
  - Edge cases: `status` starts `NOT_LOADED`; `last_codes` starts empty
- **AC-2**: resources built with `.new()`
  - Given: `MapDefinition.new()` with `EnvConfig.new()` assigned
  - When: fields are read back
  - Then: no file I/O occurs and the objects are usable
- **AC-3**: no Camera fields in the map; no back-edge
  - Given: `MapDefinition.new().get_property_list()` and `EnvConfig` properties
  - When: names and types are scanned
  - Then: none of the three Camera names appear; no property of `EnvConfig` is of class `MapDefinition`/`MapConfig`
- **AC-4**: `MapConfig` never an export type
  - Given: all `.gd` files under `src/`
  - When: scanned for `@export var .*: MapConfig`
  - Then: no match

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/map_loader/map_loader_types_test.gd`
**Status**: [x] Created and passing
**Evidence**: `tests/unit/map_loader/map_loader_types_test.gd` (AC-1 to AC-3), `tests/integration/map_loader/map_loader_export_scan_test.gd` (AC-4, moved out of unit tests because the lint forbids file access there)

## Dependencies
- Depends on: test-harness-ci epic (GUT runnable); `EnvConfig` class from the environment-theming epic (or a minimal stand-in scalar-only class owned there)
- Unlocks: Story 002, 003, 004, 005, 006
