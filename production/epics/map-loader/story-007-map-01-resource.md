# Story 007: Author map_01.tres and its round-trip test

> **Epic**: Map Loader & MapConfig
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-05

## Context
**GDD**: none, defined by ADR-0004
**Requirement**: `TR-map-loader-???` (related: `TR-environment-theming-001`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary); ADR-0008: content format (`chunk_library` typed `ChunkLibrary`); ADR-0014 (`hazard_style`)
**ADR Decision Summary**: One authored `MapDefinition` at `assets/data/maps/map_01.tres` holds `env`, `chunk_library` and `hazard_style`; `env` and the library stay inline, or loading uses the deep-ignore cache mode, so Retry sees fresh sub-resources.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Declare floats and write `1.0` in the file (an int written into a float field is coerced, verification item 5). `PackedFloat64Array` and exported enums must round-trip (ADR-0008 items 2, 3, 8). `@export var chunk_library: ChunkLibrary` typed arrays need the class cache.
**Control Manifest Rules (this layer)**:
- Required: gameplay values data-driven in the `.tres`, not hardcoded; `.gitattributes` forces `eol=lf` for `*.tres`
- Required: unit tests build with `.new()`; exactly one round-trip test loads `map_01.tres`
- Forbidden: Camera values in the map file; a Resource/Array/Dictionary field in `EnvConfig` or `HazardStyle`
- Guardrail: integration tests may read shipped `.tres` but never write outside a per-test temp dir

## Acceptance Criteria
- [ ] `assets/data/maps/map_01.tres` exists with `map_id`, an inline `EnvConfig` carrying the Map 1 values (fog end 84, others from the environment-theming GDD, not invented), a `HazardStyle` with the ADR-0014 defaults, and a reference to the chunk library (ADR-0004 Decision 1)
- [ ] A round-trip integration test loads `map_01.tres` and asserts `env`, `hazard_style` and `chunk_library` are non-null and of the expected classes (ADR-0004 Validation)
- [ ] `MapDefinition.chunk_library` is typed `ChunkLibrary` once the Pattern epic provides the class (ADR-0004 Ordering Note); until then the field stays `Resource` and the test notes it
- [ ] The loaded definition passes Phase A end to end with the real `EnvConfig`/`TubeConfig` (no codes), proving the shipped map satisfies `TubeConfig.validate()` (ADR-0004 risk: a new map breaking a cross-field constraint)
- [ ] Float fields in the file are written as floats and compare equal to the intended values after load (for example `1.0`, `PI/2` where used)

## Implementation Notes
Do not author the chunk library here; reference `assets/data/chunks/chunk_library_01.tres` from the Pattern epic. If it does not exist yet, the story can complete the file with a minimal valid placeholder library flagged as temporary in the report, or be finished after the Pattern content story. `rear_extent`, `camera_distance`, `visible_arc_half_width` must not appear in the file.

## Out of Scope
- Story 008: the real `ResourceLoader` driver
- Pattern epic: authoring `chunk_library_01.tres` and its preflight
- Story 010: the same file loaded from an Android export

## QA Test Cases
- **AC-1/2**: round-trip
  - Given: `ResourceLoader.load("res://assets/data/maps/map_01.tres")` in an integration test
  - When: properties are read
  - Then: `env is EnvConfig`, `hazard_style is HazardStyle`, `chunk_library != null`, `map_id` non-empty
- **AC-3**: library type
  - Given: the loaded definition
  - When: `chunk_library` is inspected
  - Then: instance of `ChunkLibrary` (once available)
- **AC-4**: Phase A passes
  - Given: the loaded definition and real base configs
  - When: Phase A runs with fake apply seams
  - Then: empty code set
- **AC-5**: float fidelity
  - Given: the loaded `env`
  - When: float fields compared to the documented values
  - Then: exact equality for exact literals, 1e-6 otherwise
  - Edge cases: no Camera key in the raw text of the file

## Test Evidence
**Story Type**: Config/Data
**Required evidence**: `tests/integration/map_loader/map_loader_map_01_roundtrip_test.gd` plus smoke check pass noted in `production/qa/smoke-[date].md`
**Status**: [x] Created and passing
**Evidence**: `tests/integration/map_loader/map_loader_map_01_roundtrip_test.gd` (6 tests: classes, ChunkLibrary type, env values, HazardStyle defaults, Phase A passes with real EnvConfig/TubeConfig, no Camera keys). Library in the file is an EMPTY inline `ChunkLibrary` (temporary placeholder until the Pattern epic ships `chunk_library_01.tres`). `MapDefinition.chunk_library` is now typed `ChunkLibrary`. Smoke-check note not written (no `/smoke-check` run).

## Dependencies
- Depends on: Story 004; environment-theming epic (`EnvConfig` fields and Map 1 values); pattern-difficulty epic (library class and `chunk_library_01.tres`)
- Unlocks: Story 008, Story 010
