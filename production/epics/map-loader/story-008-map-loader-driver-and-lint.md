# Story 008: map_loader.gd driver and ResourceLoader lint

> **Epic**: Map Loader & MapConfig
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: none, defined by ADR-0004
**Requirement**: `TR-map-loader-???` (related: `TR-tube-track-024`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary); ADR-0009 (lint runner)
**ADR Decision Summary**: `ResourceLoader` appears only in `map_loader.gd`, the thin driver that builds the real `load_definition` seam; the path is always loaded with `ResourceLoader.load`, never opened with `FileAccess` or listed with `DirAccess`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION: `ResourceLoader.exists`/`load` behaviour with remapped text resources; cache-mode names (`CACHE_MODE_IGNORE` does not carry into external sub-resources; `CACHE_MODE_IGNORE_DEEP` may exist, confirm in the 4.7 class reference); null on missing/corrupt without a crash; `as MapDefinition` null for a wrong type.
**Control Manifest Rules (this layer)**:
- Required: lint `only_in` `ResourceLoader` -> `map_loader.gd`; lint forbid `duplicate_deep`
- Required: synchronous load; `MapLoader.attempt(path)` takes the path, MVP passes `res://assets/data/maps/map_01.tres` from a boot config
- Forbidden: `load_threaded_request`; `FileAccess`/`DirAccess` on the map path; `unload_map`
- Guardrail: lints are tested with one passing and one failing fixture per rule

## Acceptance Criteria
- [ ] `src/core/map/map_loader.gd` (a thin driver, `RefCounted` or `Node` per the composition-root story) builds the real `load_definition` seam: `ResourceLoader.exists(path)` false or a null load returns null; a load that is not a `MapDefinition` is handed to the core as-is for `MAP_RESOURCE_TYPE`
- [ ] The driver exposes `attempt(path)` and `retry()` delegating to `MapLoaderCore`, and holds the MVP map path constant in a boot config, not in code
- [ ] A Retry re-reads: the driver requests a fresh read (cache-mode choice recorded after verifying the 4.7 class reference); if no mode reaches external sub-resources, `env` and the library stay inline in `map_01.tres` (ADR-0004 Decision 1)
- [ ] Integration test: the real driver on a missing path gives `MAP_RESOURCE_MISSING`; on a wrong-type `.tres` gives `MAP_RESOURCE_TYPE`; on `map_01.tres` loads non-null parts (ADR-0004 Validation)
- [ ] Lint rules `only_in: ResourceLoader` (allow `map_loader.gd`) and `forbid: duplicate_deep` exist in `tools/ci/lint_rules.json` with a passing and a failing fixture each and are green on `src/`
- [ ] The driver contains no `load_threaded_request`, `FileAccess` or `DirAccess` (lint or test)

## Implementation Notes
Only this file may name `ResourceLoader`. Corrupt-file engine errors are tolerated by the smoke test (ADR-0004 A1 note). Wrong-type fixture: a small valid `.tres` of another Resource class under `tests/integration/map_loader/fixtures/` (excluded from export). Keep the MS-1 pre-commitment in a comment: if too slow, switch only the `load_definition` seam to the threaded API.

## Out of Scope
- Story 009: instantiation order and wiring in `GameRoot`
- Story 010: the Android export check
- Threaded loading (only if MS-1 fails, Story 011)

## QA Test Cases
- **AC-1**: seam behaviour
  - Given: paths `res://nope.tres`, a wrong-type fixture, `map_01.tres`
  - When: `attempt(path)` runs with fake apply seams
  - Then: `MAP_RESOURCE_MISSING`; `MAP_RESOURCE_TYPE`; success
- **AC-3**: re-read
  - Given: a fixture rewritten between attempt and retry (temp dir, per-test)
  - When: `retry()` runs
  - Then: the second result reflects the new content (or the documented limitation is asserted)
- **AC-5**: lints
  - Given: the lint runner and fixtures
  - When: run
  - Then: failing fixtures fail, passing fixtures pass, `src/` is clean

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/map_loader/map_loader_driver_test.gd` and `tools/ci/tests/` lint cases
**Evidence**: `tests/integration/map_loader/map_loader_driver_test.gd` (7 tests) and the `forbidden:duplicate_deep` / `forbidden:map_content_file_io` lint fixtures in `tools/ci/tests/fixtures/`.

## Dependencies
- Depends on: Story 006, Story 007; test-harness-ci epic (lint runner)
- Unlocks: Story 009, Story 010
