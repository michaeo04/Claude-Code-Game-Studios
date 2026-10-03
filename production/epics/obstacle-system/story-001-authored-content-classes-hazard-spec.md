# Story 001: Authored content classes, HazardSpec and HazardContentProvider

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/obstacle-system.md` (Core Rules 1, 7; Formulas F1 range table)
**Requirement**: `TR-obstacle-system-002`, `TR-obstacle-system-009`, `TR-obstacle-system-010` (superseded mechanism), `TR-obstacle-system-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (primary); ADR-0009: Test framework and CI (secondary)
**ADR Decision Summary**: Authored content is a typed Resource tree (`ChunkLibrary` > `ChunkDef` > `HazardPlacement` > `HazardPiece`, `.tres`), compiled at map load into immutable `RefCounted` `HazardSpec` objects with flat `PackedFloat64Array` footprints. Nothing is copied at run time.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION (ADR-0008 items 1, 2, 3, 8): typed arrays of custom Resources round-trip in a `.tres` and in an Android export; `PackedFloat64Array` and `float` exports keep float64 precision (for example `1.0472`, `PI/2`); exported enums store and load as int. A non-`@tool` Resource loads as a placeholder in the editor (properties readable, methods not callable).
**Control Manifest Rules (this layer)**:
- Required: authored classes are data only and not `@tool`; `Tier` (INTRO | RAMP | FULL) and `HazardType` (WALL | SPIKE | DOUBLE_GATE | NEAR_RING) are enums with explicit integer values; `HazardSpec` has no setters; the `HazardContentProvider` base is a plain `RefCounted` returning an empty array (no `@abstract`).
- Forbidden: `duplicate()` / `duplicate_deep()` on hazard Resources; reordering enum values; mutating a loaded (cached) Resource; `Vector2/3/4` for footprints; JSON or GDScript constant tables for content.
- Guardrail: `segment_count` 1..3; compiled library resident for the session (a few KB).

## Acceptance Criteria
No GDD acceptance criterion maps here (data shape only). Criteria come from ADR-0008 Validation Criteria and Decision 1 to 2:
- [ ] `HazardPiece` (`theta_min`, `theta_max`, `s_start`, `s_end`), `HazardPlacement` (`hazard_type`, `local_segment_index`, `pieces: Array[HazardPiece]`, `solution_angles: PackedFloat64Array`), `ChunkDef` (`chunk_id: StringName`, `tier`, `segment_count`, `placements`) and `ChunkLibrary` (`chunks: Array[ChunkDef]`) exist as non-`@tool` Resources; enums carry explicit integer values.
- [ ] `HazardSpec` (RefCounted) holds `hazard_type: int`, `local_segment_index: int`, `pieces: PackedFloat64Array` (4 floats per piece, chunk-local), `solution_angles: PackedFloat64Array`; built once, never mutated (a test freezes and compares).
- [ ] `HazardContentProvider.hazards_for_segment(_segment_index: int) -> Array[HazardSpec]` base returns `[]`; a faked provider returns the same shared `HazardSpec` instances on repeat reads (no copy).
- [ ] A small `.tres` library written with typed arrays, a seam-crossing piece (`theta_max > PI`) and `1.0472` / `PI/2` values loads from disk with exact float64 values and enum ints (verification items 1, 2, 3, 8).

## Implementation Notes
Seam-crossing pieces are authored unwrapped (`theta_max > PI` or `theta_min < -PI`, TR-011); `s_start` / `s_end` are chunk-local inside `[k*L, (k+1)*L)`. `solution_angles`: one for Wall and Near-Ring, two for Double Gate, none for Spike. TR-010 ("owned deep copy") is superseded by ADR-0008 Decision 3: the spec is shared and immutable, per-hazard state lives in the Obstacle record (Story 007). Library path `assets/data/chunks/chunk_library_01.tres`, one external file per ChunkDef; only a tiny test fixture library is needed here. The android export smoke (library loads in the exported package) is a later gate.

## Out of Scope
- Story 007: building the world-space footprint at bind.
- `ChunkLibraryCompiler`, `CompiledLibrary` and the structural compile checks (Pattern & Difficulty epic).
- Real chunk authoring; `ContentPreflight` (Story 011).

## QA Test Cases
- **AC-1**: Resource tree and enums
  - Given: the four authored classes. When: a library with 2 chunks is built with `.new()`. Then: typed arrays accept only the right element types; enum members equal their documented ints.
  - Edge cases: reordered enum fails the explicit-int assertion.
- **AC-2**: HazardSpec immutability
  - Given: a `HazardSpec` built from fixture values. When: the test snapshots then re-reads all fields after a provider round. Then: values are identical (`==`), no setter exists.
- **AC-3**: Shared instances
  - Given: a fake provider with a table. When: `hazards_for_segment(4)` is called twice. Then: both calls return the same `HazardSpec` object references; base provider returns an empty array.
- **AC-4**: `.tres` round trip (disk)
  - Given: a fixture `.tres` with a seam piece. When: loaded via `load()` in an integration test. Then: `theta_max` equals the authored value exactly, `PI/2` equals `PI/2`, enum ints preserved.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/unit/obstacle_system/obstacle_system_hazard_spec_test.gd` (AC-2, AC-3) and `tests/integration/obstacle_system/obstacle_system_resource_roundtrip_test.gd` (AC-1, AC-4; loads real files)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: test-harness-ci epic (GUT runner), composition-root epic (project scaffold)
- Unlocks: Story 002, Story 007, Story 011; Pattern & Difficulty compiler
