# Story 007: run_reset reseed, determinism and no side effects

> **Epic**: Pattern & Difficulty
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (Core Rule 11; States and Transitions; Edge Cases on mid-chunk `run_reset`)
**Requirement**: `TR-pattern-difficulty-007`, `TR-pattern-difficulty-015`, `TR-pattern-difficulty-016`, `TR-pattern-difficulty-020`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (primary); ADR-0002: Game loop and Composition Root (`run_reset` rank 1)
**ADR Decision Summary**: Same `run_id` plus same call script gives bit-identical output; Pattern reseeds on `run_reset` and runs first among subscribers (rank 1, with `WorldFrame`), before Tube Track primes the window.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: The subscriber order is registered by the composition root `_wire()` table (composition-root epic); this story implements only the handler and its tests.
**Control Manifest Rules (this layer)**:
- Required: `run_reset(run_id)` reseeds the PRNG, reshuffles all three bags, discards in-progress chunk state and clears the read history; Pattern reseeds before Tube Track primes; no persistence (per-run, in-memory).
- Forbidden: connecting with `CONNECT_DEFERRED`; mutating Run State or Tube Track; state kept across runs.
- Guardrail: handler is O(pool size).

## Acceptance Criteria
- [ ] **AC-17** Two fresh `PatternCore` instances with the same `run_id` and an identical 40-call scripted sequence (including a mid-sequence `run_reset` with the same `run_id`) are bit-identical (chunk_id order, footprints, tick for tick). A third instance with a different `run_id` differs in the first draw in at least one of 10 tested seed pairs.
- [ ] **AC-18** Test doubles for Run State (`run_time`, `run_id`) and Tube Track (`SEGMENT_LENGTH`) record every call; across the AC-2/3/9/17 scripts neither receives anything beyond the read-only accessors.
- [ ] **AC-20** REV2 mid-delivery (indices 0 and 1 returned, index 2 not queried) then `run_reset(new_run_id)`: the next call draws freshly from INTRO's reshuffled bag seeded from `new_run_id`; no partial-REV2 state leaks. The read-history-empty assertion of this AC is completed by Story 010 once the history exists.

## Implementation Notes
Add `on_run_reset(run_id: int)` to `PatternCore` (register in the composition root's `_wire()` table only if the composition-root epic has not already; otherwise only add the method and a test via `wire_spy`). Clear: three bags, current chunk, mid-chunk cursor, remaining padding. Store `run_id` and call `rng.seed = run_id` before the first draw (never `randomize()`). A scripted-call recorder lives in `tests/support/`. Increasing-index, once-each call order (TR-016) is documented in the doc comment and asserted by a test that feeds a repeated index and expects state not to advance twice (document the chosen behaviour; Obstacle never repeats).

## Out of Scope
- Story 010: history clearing. Composition-root epic: the rank table (`run_reset` order test lives there).
- Story 013: wiring to the real Run State.

## QA Test Cases
- **AC-17**: determinism
  - Given: two cores, same seed; one core, different seed. When: 40 scripted calls. Then: identical sequences; different first draw in at least one of 10 pairs.
  - Edge cases: the mid-sequence reset with the same id reproduces the opening.
- **AC-18**: no side effects
  - Given: recording doubles. When: AC-2/3/9/17 scripts replay. Then: only read accessors called.
- **AC-20**: reset mid-chunk
  - Given: REV2 mid-delivery. When: `run_reset`. Then: fresh INTRO draw from the new seed; no REV2 residue.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_reset_determinism_test.gd`
**Evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_reset_determinism_test.gd` (AC-17, AC-18, AC-20 reseed part, repeated index). Gap: the AC-20 read-history-empty assertion waits for Story 010.

## Dependencies
- Depends on: Stories 005, 006
- Unlocks: Stories 010, 013
