# Story 003: ChunkLibraryCompiler, CompiledLibrary and structural checks

> **Epic**: Pattern & Difficulty
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (Core Rules 1, 4, 6; Edge Cases on `GRACE_POOL_TOO_SMALL`)
**Requirement**: `TR-pattern-difficulty-002`, `TR-pattern-difficulty-008`, `TR-pattern-difficulty-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (primary); ADR-0004: Map Loader and MapConfig (`Pattern.apply_map`, Phase B3)
**ADR Decision Summary**: `Pattern.apply_map(map)` calls `ChunkLibraryCompiler.compile(map.chunk_library, ...)`, which runs the cheap structural checks and builds a `CompiledLibrary` of per-tier pools of `CompiledChunk` holding shared immutable `HazardSpec` objects. A failure returns false (`MAP_APPLY_FAILED`).
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Typed arrays of custom Resources must round-trip in a `.tres` and an export (ADR-0008 item 1); compile only after any threaded load completes. `MapConfig.chunk_library` is a `Resource` field set by `MapConfig.build`.
**Control Manifest Rules (this layer)**:
- Required: structural checks always run (finite values, `theta_min <= theta_max` width `< 2*PI`, `s_start <= s_end` inside the owning segment, `segment_count` 1 to 3, `local_segment_index` in range, at most `MAX_PIECES_PER_SEGMENT`, non-empty pool per tier, at least `GRACE_POOL_MIN_SIZE` (2) grace-compliant INTRO chunks); the library is immutable and never copied; `apply_map` is configuration only (emits no signal, starts nothing).
- Forbidden: `duplicate()`/`duplicate_deep()`; mutating a loaded Resource; writing to the library.
- Guardrail: compile is O(pieces); compiled library resident for the session (a few KB).

## Acceptance Criteria
- [ ] **AC-9b** An INTRO pool of 4 chunks with 1 grace-compliant chunk is rejected at validation with `GRACE_POOL_TOO_SMALL` naming the compliant count (1); 0 compliant is rejected too; exactly 2 compliant (the shipped fixture shape) is accepted. A mutation omitting the check fails by accepting the 1-compliant pool.

Also (from ADR-0008 Decision 2, no GDD AC): a failure returns the full code set and `apply_map` returns false; a valid library compiles to per-tier superset pools (RAMP includes INTRO, FULL includes all); `compile` returns `null` on a structural failure.

## Implementation Notes
Files in `src/core/pattern_difficulty/`: `chunk_library_compiler.gd` (`static func compile(library: ChunkLibrary, config: PatternConfig, segment_length: float, log_sink: Callable) -> CompiledLibrary`), `compiled_library.gd`, `compiled_chunk.gd`. Reuse the `ObstacleMath` validators (`validate_footprints`, `validate_home_segments`, `validate_piece_counts`, `validate_grace_zone`) rather than re-deriving them. A grace-compliant chunk has, at `base` 0, no `local_segment_index` 0 piece with raw `s_start` below the grace length (11 at defaults, `GRACE_ZONE_VIOLATION` rule). `GRACE_POOL_TOO_SMALL` is emitted through `log_sink` at ERROR with the count. `Pattern.apply_map(map)` stores the `CompiledLibrary` and emits nothing; wire it into the map-loader Phase B3 seam without changing Map Loader code (a thin adapter on `PatternCore`, Story 006).

## Out of Scope
- Story 004: semantic per-chunk checks (hidden side, exit, dodge-recovery).
- Obstacle epic stories 011 and 012: `ContentPreflight` P1 to P3 (composes this compiler and the real `PatternCore`).
- Story 006: using the compiled pools at run time.

## QA Test Cases
- **AC-9b**: grace pool floor
  - Given: micro-fixtures with 1, 0 and 2 grace-compliant INTRO chunks. When: compiled. Then: `GRACE_POOL_TOO_SMALL` for 1 and 0 (count named), success for 2.
  - Edge cases: a library whose INTRO pool is empty fails the non-empty-pool check first.
- **Structural**: invalid shapes
  - Given: a chunk with `segment_count` 4, a NaN piece, a `local_segment_index` out of range, 13 pieces in one segment. When: compiled. Then: each rejected with its stable code, `compile` returns `null`.
- **Pools**: supersets and sharing
  - Given: the 8-chunk fixture. When: compiled. Then: pool sizes 4, 6, 8; `HazardSpec` instances identical (same reference) across repeated reads.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_compiler_test.gd`
**Status**: [x] Created and passing
**Evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_compiler_test.gd`. AC-9b and structural/pool/sharing cases proven. `Pattern.apply_map` returning false is wired in Story 006.

## Dependencies
- Depends on: Story 001; obstacle-system stories 001, 005 (validators, `HazardSpec`), map-loader (`MapConfig.chunk_library`)
- Unlocks: Stories 004, 005, 006
