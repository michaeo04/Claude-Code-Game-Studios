# Story 012: ContentPreflight P2 pairs, P3 soak and the blocking CI test

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-05
> **Blocker (2026-10-05)**: not started. P2 and P3 need the real sequencer padding (`PatternCore._padding_segments_for` is a seam returning 0; pattern-difficulty Story 010 is Blocked) and the shipped `assets/data/chunks/chunk_library_01.tres` does not exist yet.

## Context
**GDD**: `design/gdd/obstacle-system.md` (Edge Cases validation; Formulas F3, F5); `design/gdd/pattern-difficulty.md` (sequencer)
**Requirement**: `TR-obstacle-system-012`, `TR-obstacle-system-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decisions 5, 6); ADR-0009: Test framework and CI (Integration layout)
**ADR Decision Summary**: P2 checks every ordered adjacent chunk pair through the real `PatternCore` sequencer (with the padding it actually inserts); P3 is the proof for chains: 500 hardcoded seeds x 200 segments through the real sequencer and validators, `CHAIN_VIOLATION` on failure. The GUT test is blocking in CI.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: The content test loads the real `.tres` files from disk (Integration evidence; unit tests must not do file I/O) and reloads from disk in the golden-sequence test. `RandomNumberGenerator` seeded sequences must match on Android ARM64 and desktop (ADR-0008 item 4, Pattern epic).
**Control Manifest Rules (this layer)**:
- Required: P2 per ordered pair `(A, B)`, `A != B` (and `A == B` only when a pool has one chunk), plus each pair behind a synthetic worst-case predecessor; the 500-seed soak runs in CI only.
- Forbidden: running P3 in a debug boot; content guard bands or pair-only rejection instead of generalized padding.
- Guardrail: CI full run at most 5 minutes.

## Acceptance Criteria
- [ ] P2 detects `NO_SAFE_GAP`, `HAZARD_OVERLAP`, `TOO_DENSE`, `NEAR_ZONE_OVERLAP` across a chunk boundary and names both chunks and the padding used.
- [ ] Micro-fixtures `TWOHOP`, `TOO_CLOSE`, `TWIN_WALL`, `CLUSTERED`, `SPIKE_AFTER_WALL`, `LONG_OVERLAP` produce their expected codes.
- [ ] P3 (500 seeds x 200 segments) passes on the shipped library; a deliberately broken fixture yields `CHAIN_VIOLATION` with seed and segment.
- [ ] `tests/integration/pattern_difficulty/pattern_difficulty_content_preflight_test.gd` runs P1 to P3 over `assets/data/chunks/chunk_library_01.tres` and blocks any merge touching `assets/data/chunks/` or the validators.

## Implementation Notes
The P2 and P3 enumeration, padding formula and the `PADDING_EPSILON` documented epsilon are Pattern & Difficulty's (ADR-0008 Decision 6); this story consumes the real sequencer and does not reimplement it. It is intentionally not claimed by any Obstacle GDD acceptance criterion (the GDD says only that preflight runs over the whole library). Share the test file path with the pattern-difficulty epic (coordinate ownership at /story-readiness). The shipped `chunk_library_01.tres` is produced by the Pattern epic's chunk authoring; until it exists, use the fixture libraries only.

## Out of Scope
- Story 011: P1. Sequencer implementation and golden-sequence test (Pattern epic).
- Chunk authoring.

## QA Test Cases
- **P2 fixtures**: Given each micro-fixture. When `ContentPreflight.run` executes. Then the expected code set appears with both chunk ids.
  - Edge cases: `A == B` pair only for single-chunk pools.
- **P3**: Given the fixed 500-seed list. When the soak runs. Then zero violations on the shipped library; broken fixture gives `CHAIN_VIOLATION` with seed.
- **CI gate**: Given the GUT test. When `python tools/ci/run_ci.py --only integration` runs. Then it passes and fails on a broken library.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/pattern_difficulty/pattern_difficulty_content_preflight_test.gd` (P1 to P3, GUT); fixtures under `tests/support/`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 011; pattern-difficulty epic (real `PatternCore` sequencer and compiled library); near-miss-detection epic (`NEAR_ZONE_OVERLAP`)
- Unlocks: chunk authoring; first-playable content gate
