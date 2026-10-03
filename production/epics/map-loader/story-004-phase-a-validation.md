# Story 004: Phase A validation sequence

> **Epic**: Map Loader & MapConfig
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0004
**Requirement**: `TR-map-loader-???` (related: `TR-tube-track-024`, `TR-run-state-restart-020`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary); ADR-0008 (library content checked by its own validator); ADR-0014 (A3b)
**ADR Decision Summary**: Phase A is pure and side-effect free: any failure returns the whole code set and nothing is applied.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: A missing or corrupt resource returns `null` with an engine error and does not crash; `as MapDefinition` yields `null` for a wrong type (verification item 3). A corrupt file's engine error cannot be suppressed by the rate-limited log.
**Control Manifest Rules (this layer)**:
- Required: Phase A runs A1 `load_definition`, A2 `def.env.validated`, A3 camera geometry, A3b `hazard_style.validated`, A4 `chunk_library` not null, A5 `MapConfig.build` + `TubeConfig.from_map`, A6 `tube_cfg.validate()` passed through unchanged
- Required: codes `MAP_RESOURCE_MISSING`, `MAP_RESOURCE_TYPE`, `MAP_ENV_INVALID`, `MAP_CAMERA_INVALID`, `HAZARD_STYLE_INVALID`, `MAP_LIBRARY_MISSING`
- Forbidden: any Phase B step or `map_ready` before Phase A passed entirely; a crash on a null `env`
- Guardrail: exact `==` on codes

## Acceptance Criteria
- [ ] A null result or missing path from `load_definition` gives `MAP_RESOURCE_MISSING`; a result that is not a `MapDefinition` gives `MAP_RESOURCE_TYPE` (ADR-0004 A1)
- [ ] A null `env` or a fatal `EnvConfig.validated` result gives `MAP_ENV_INVALID`, never a crash (A2; ADR-0004 Validation)
- [ ] A null or fatal `hazard_style` gives `HAZARD_STYLE_INVALID` (A3b)
- [ ] A null `chunk_library` gives `MAP_LIBRARY_MISSING` (A4); library content is not checked here
- [ ] Camera geometry and `camera_far` failures give `MAP_CAMERA_INVALID` (A3, A5; from Story 003)
- [ ] `tube_cfg.validate()` codes (for example `FOG_BEFORE_READ`) appear in the result unchanged and unprefixed (A6)
- [ ] A map failing several checks returns the whole code set, in a deterministic order, in one result
- [ ] Phase A calls no `apply_*`, `tube_load` or `send_map_ready` seam, on success or failure (spy test)

## Implementation Notes
`MapLoaderCore._phase_a(path) -> Dictionary` (`ok`, `codes`, `map`, `tube_cfg`) kept private; `attempt()` (Story 005/006) composes it. "Any failure returns the whole code set": continue past independent failures where the later step has its inputs (for example A2 failure does not prevent A4), but skip steps whose input is missing (A5 and A6 need A2 to A4 results). Document the skip rule in a doc comment. `ResourceLoader.exists` lives in the real seam (Story 008), the core only sees null or a value.

## Out of Scope
- Story 005: Phase B and `map_ready`
- Story 006: signal emission, logging, Retry
- Story 008: the real `load_definition` seam

## QA Test Cases
- **AC-1**: missing / wrong type
  - Given: a fake seam returning `null`; then a `Resource.new()`
  - When: `attempt` runs Phase A
  - Then: `[MAP_RESOURCE_MISSING]`; then `[MAP_RESOURCE_TYPE]`
- **AC-2**: env
  - Given: `MapDefinition.new()` with `env = null`
  - When: Phase A runs
  - Then: codes contain `MAP_ENV_INVALID`; no error raised
- **AC-3/4**: style, library
  - Given: definitions with a null `hazard_style`, then a null library
  - When: Phase A runs
  - Then: `HAZARD_STYLE_INVALID`, then `MAP_LIBRARY_MISSING`
- **AC-5**: camera
  - Given: a seam camera dictionary with `NAN`
  - When: Phase A runs
  - Then: `MAP_CAMERA_INVALID`
- **AC-6**: passthrough
  - Given: a fog config that `TubeConfig.validate()` rejects
  - When: Phase A runs
  - Then: the Tube Track code is in the set exactly as returned
- **AC-7**: multiple failures
  - Given: null env and null library
  - When: Phase A runs
  - Then: both codes present, order stable across runs
- **AC-8**: no side effects
  - Given: spy seams counting apply/tube/ready calls
  - When: any failing Phase A runs
  - Then: all counters are 0

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/map_loader/map_loader_phase_a_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001, 002, 003
- Unlocks: Story 005, 006
