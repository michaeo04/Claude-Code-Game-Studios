# Story 005: Seeded PRNG, Fisher-Yates and tiered shuffled bags

> **Epic**: Pattern & Difficulty
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (Core Rule 3; Formula F4; AC-4, AC-5, AC-6, AC-15, AC-23, AC-31)
**Requirement**: `TR-pattern-difficulty-005`, `TR-pattern-difficulty-006`, `TR-pattern-difficulty-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (primary, Decision 8); ADR-0009: Test framework and CI
**ADR Decision Summary**: `PatternCore` uses a `RandomNumberGenerator` instance with an explicit `seed` set from `run_id` before the first draw, never `randomize()`, and its own Fisher-Yates; the integer path (`randi_range`) only; only `seed` is set, never `state`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION (item 4): a seeded `RandomNumberGenerator` gives the same sequence on Android ARM64 and desktop; the engine does not promise stable sequences across engine versions, so the golden sequence is re-run on every engine upgrade (Story 013).
**Control Manifest Rules (this layer)**:
- Required: own Fisher-Yates using the seeded instance; `randi_range` only; reshuffled first draw differs from the previous last draw (waived at N=1); `min_gap` 2 and `max_gap` `2N-1` for N >= 3, 2 at N=2, 1 at N=1.
- Forbidden: `randomize()`, `randf`, global `Array.shuffle()`; setting `state`; seeding from time.
- Guardrail: draw cost is a bag pop; no per-draw allocation beyond the bag array.

## Acceptance Criteria
- [ ] **AC-4** At FULL (N=8) the first 8 draws after a reset are a permutation of {1..8}.
- [ ] **AC-5** A single-chunk pool: 10 draws all return chunk_id 1; accepted (N=1 waiver).
- [ ] **AC-6** With a fixed-order RNG stub producing bag 1 = [3,1,4,2] and naive bag 2 = [2,4,1,3], the real code corrects the back-to-back collision so the observed gap is >= 2; a mutation returning the naive bag 2 fails with a gap of exactly 1.
- [ ] **AC-15** INTRO (N=4): a 20-draw sequence from a fixed `run_id` has every same-chunk gap in [2, 7]; the same seed witnesses gap = 2 and a 40-draw run witnesses gap = 7. The N=1 fixture does not check `min_gap`.
- [ ] **AC-31** A 2-chunk pool, 20 draws from a fixed `run_id`: strict alternation, gap always exactly 2, never 3.
- [ ] **AC-23 (ADVISORY, statistical)** Over a fixed hardcoded list of 500 `run_id`s the first FULL-tier draw (N=8) passes chi-square (expected 62.5 each) with p > 0.01; a low-id-biased shuffle fails.

## Implementation Notes
`PatternCore` (or an extracted `TierBag` helper in `src/core/pattern_difficulty/`) holds three bags (one per `ChunkDef.Tier`), each shuffled independently with the single seeded RNG, so a given `run_id` reproduces the sequence. On bag empty: reshuffle, and if the new first draw equals the previous last draw (and N > 1) swap it with another position using the same RNG (deterministic). The RNG is injected via a factory so AC-6 can stub the permutation source. Seeds come from `run_id`; the 500-seed list is a hardcoded constant file under `tests/support/data/`, not generated at test time. No consumer of `Engine.*`/`Time.*`.

## Out of Scope
- Story 006: tier selection from `run_time` and chunk delivery.
- Story 007: `run_reset` reseed and discard.
- Story 013: the golden-sequence test and the Android device run.

## QA Test Cases
- **AC-4**: permutation
  - Given: fixture, fixed `run_id`, FULL. When: 8 draws. Then: a permutation of {1..8}.
- **AC-5**: N=1
  - Given: pool {W1}. When: 10 draws. Then: all 1, no violation.
- **AC-6**: reshuffle constraint is load-bearing
  - Given: stubbed permutation source. When: two bags drawn. Then: gap >= 2; naive mutation gives gap 1.
- **AC-15**: gap bounds both reached
  - Given: INTRO, fixed seed. When: 20 and 40 draws. Then: gaps in [2,7]; 2 and 7 each observed.
- **AC-31**: N=2 alternation
  - Given: two-chunk pool. When: 20 draws. Then: A,B,A,B...; general-formula mutation fails.
- **AC-23**: chi-square
  - Given: 500 fixed seeds. When: first FULL draw tallied. Then: p > 0.01 (ADVISORY, may not block CI).

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_bag_test.gd` (AC-4, 5, 6, 15, 31) and `tests/unit/pattern_difficulty/pattern_difficulty_shuffle_fairness_test.gd` (AC-23, advisory)
**Evidence**: tests/unit/pattern_difficulty/pattern_difficulty_bag_test.gd (7 tests: AC-4, 5, 6, 15, 31) and pattern_difficulty_shuffle_fairness_test.gd (AC-23, advisory, passes)
**Status**: [x] Created and passing

## Dependencies
- Depends on: Stories 001, 003
- Unlocks: Stories 006, 007, 013
