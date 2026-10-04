# Story 008: Angular clustering fraction and pool advisories

> **Epic**: Pattern & Difficulty
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (Core Rule 12; Formula F5; Edge Cases on small INTRO pool)
**Requirement**: `TR-pattern-difficulty-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: Content checks return stable codes through the injected sink; load never fails on an advisory. (No ADR changes F5; ADR-0008 Decision 6 adds Spikes to the sequencer history but F5 stays defined over non-Spike chunks.)
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Pure math; no post-cutoff API.
**Control Manifest Rules (this layer)**:
- Required: `opposing_pair_fraction` per tier pool over non-Spike chunks; above `MAX_OPPOSING_FRACTION` logs ADVISORY `EXCESSIVE_ANGULAR_CLUSTERING` (WARNING level) and load succeeds; 0.0, never NaN, when fewer than 2 non-Spike chunks.
- Forbidden: rejecting a pool for clustering; dividing by zero pairs.
- Guardrail: O(n^2) pairs over a few chunks, content-load time only.

## Acceptance Criteria
- [ ] **AC-28** The fixture FULL pool (N=8, 7 non-Spike chunks) yields exactly `11/21` (approx 0.524, 1e-6) and is accepted; INTRO and RAMP each yield exactly 0.0. Load always succeeds.
- [ ] **AC-29b** An all-Spike INTRO pool and a pool with exactly one non-Spike chunk are accepted with `opposing_pair_fraction` exactly 0.0, no crash, no NaN; a no-zero-guard mutation fails.
- [ ] **AC-29 (ADVISORY)** `CLUSTERED` (A theta 0, B PI, C PI): fraction 2/3 logs `EXCESSIVE_ANGULAR_CLUSTERING` at default 0.6 naming the tier and 0.667, load still accepted; at `MAX_OPPOSING_FRACTION` 0.7 no advisory for the same pool.
- [ ] **AC-21 (ADVISORY)** A 1-chunk INTRO pool against `TIER_INTRO_DURATION` 15 logs a non-blocking advisory ("INTRO pool size 1 may repeat every draw for up to 15s of a run"); the library is accepted.

## Implementation Notes
Add `PatternMath.opposing_pair_fraction(pool_angles: Array)` (each entry the chunk's solution-angle set; chunks with no non-Spike read excluded) using `PatternMath.opposing` (Story 002), and hook it in the library validation per tier (pool sets from the compiled library). Log through `log_sink(LogLevel.WARNING, &"EXCESSIVE_ANGULAR_CLUSTERING", tier_name, message)`. Use the `ChunkLibrary` tier supersets (RAMP includes INTRO). `MAX_OPPOSING_FRACTION` read from `PatternConfig`.

## Out of Scope
- Story 010: runtime padding frequency (Open Question 11, measured at first playable).
- Story 004: per-chunk gates.

## QA Test Cases
- **AC-28**: exact fraction
  - Given: fixture pools. When: fraction computed. Then: 0.0, 0.0, 11/21.
  - Edge cases: REV2's `{0, PI}` set opposes through any-pair rule.
- **AC-29b**: vacuous zero
  - Given: all-Spike pool; one non-Spike pool. When: computed. Then: 0.0 and accepted.
- **AC-29**: advisory only
  - Given: `CLUSTERED`, knob 0.6 and 0.7. When: validated. Then: one advisory then none; accepted both times.
- **AC-21**: small pool
  - Given: 1-chunk INTRO pool. When: validated. Then: advisory logged; accepted.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_clustering_test.gd` (AC-28, AC-29b, AC-29, AC-21)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 001, 002, 003
- Unlocks: Story 009
