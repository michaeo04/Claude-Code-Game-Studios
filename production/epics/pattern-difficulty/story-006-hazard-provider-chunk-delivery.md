# Story 006: PatternCore as HazardContentProvider (chunk delivery, tiers, grace first draw)

> **Epic**: Pattern & Difficulty
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (Core Rules 1, 2, 4, 5, 6; States and Transitions)
**Requirement**: `TR-pattern-difficulty-002`, `TR-pattern-difficulty-003`, `TR-pattern-difficulty-004`, `TR-pattern-difficulty-008`, `TR-pattern-difficulty-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (primary); ADR-0004: Map Loader and MapConfig (`Pattern.apply_map`)
**ADR Decision Summary**: `PatternCore` extends `HazardContentProvider` and `hazards_for_segment(i)` returns the shared specs of the chunk placed at that segment (no copy, no new pieces); Obstacle calls it once per index in increasing order.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: The base `HazardContentProvider` is a plain `RefCounted` (no `@abstract`); override with the exact signature `hazards_for_segment(_segment_index: int) -> Array[HazardSpec]`. Spec `pieces` are chunk-local; Obstacle applies the `s_offset` at bind (ADR-0008 Decision 3), so no extra translation exists in Pattern beyond selecting the spec for the segment.
**Control Manifest Rules (this layer)**:
- Required: tier sampled at window-entry time; a chunk in progress finishes when the tier changes; returns empty for `index < 0`, the next local segment mid-chunk, empty while padding; first draw of a run restricted to grace-compliant INTRO chunks, later draws unrestricted.
- Forbidden: copying specs; mutating a spec; reading real Run State or Tube Track (test doubles only); `Engine.*`/`Time.*`.
- Guardrail: `hazards_for_segment` is a lookup of shared specs (TR-017: no explicit budget, no allocation of pieces).

## Acceptance Criteria
- [ ] **AC-2** W3 at `base` 5: index 5 empty, index 6 returns its piece (`s` shifted by `base * L` = 60 to `(0.4127, 5.8705, 74.0, 75.0)` when viewed in world space); REV2 at `base` 10: index 10 the Wall (`120.5`-`121.5`), 11 empty, 12 the Near-Ring (`147.1`-`148.3`).
- [ ] **AC-3** At `run_time` 8 only ids {1..4} over 50 draws; at 47 only {1..6}; at 300 every id {1..8} appears within one 8-draw bag; a mutation dropping an INTRO chunk from RAMP fails.
- [ ] **AC-7** For every fixture chunk at `base` in {0, 1, 5, 100}, each returned piece satisfies `floor(s_start/L) == floor(s_end/L) == base + local_segment_index`; a piece at `local_segment_index` 1 with local `s_start` 11.5, `s_end` 12.5 is rejected by the compile step (Story 003) with `HOME_SEGMENT_MISMATCH`.
- [ ] **AC-8** `hazards_for_segment(-1)` and `(-50)` return empty; `(0)` returns the drawn chunk's content (non-empty; boundary is `< 0`).
- [ ] **AC-9** Across 30 fresh runs with a fixed hardcoded list of 30 `run_id`s the first `hazards_for_segment(0)` returns only W3 or W4 content (never W1/W2), both W3 and W4 appear at least once, no piece with translated `s_start < 11`; W1/W2 are freely drawable as the second chunk.
- [ ] **AC-19** A scripted `run_time` crossing `TIER_INTRO_DURATION` where INTRO ends on chunk 3 and RAMP's first draw is chunk 3 is accepted, no repeat rejection.

## Implementation Notes
Translation in AC-2/AC-7 is verified by composing the returned spec's chunk-local pieces with the chunk `base` the test knows (`base * L`), because the spec stays chunk-local per ADR-0008; if the implementation exposes a helper for world-space `s`, assert it there. Padding is a seam only: add a private `_padding_segments_for(chunk) -> int` returning 0 now; Story 010 (Blocked) replaces its body. Provide `apply_map(map: MapConfig) -> bool` (configuration only, stores the `CompiledLibrary`, emits nothing). Tier is read from an injected `run_time` provider callable (test double), never Run State directly.

## Out of Scope
- Story 005: bag and PRNG internals. Story 007: `run_reset`. Story 010: padding and read history.

## QA Test Cases
- **AC-2**: translation and empty segments, **AC-3**: superset pools, **AC-7**: whole-segment alignment property, **AC-8**: negative indices, **AC-9**: first-draw grace filter, **AC-19**: tier-transition near repeat.
  - Given: the 8-chunk fixture, run_time and run_id stubs. When: the scripted `hazards_for_segment` calls run. Then: exact chunk_ids/pieces as in the criteria.
  - Edge cases: AC-3 mutation; AC-9 hardcoded-answer mutation (both W3 and W4 must appear); mid-chunk tier change does not truncate.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_provider_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 001, 003, 005; obstacle-system story 001 (`HazardContentProvider`)
- Unlocks: Stories 007, 010, 013
