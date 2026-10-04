# Story 004: Within-chunk validators (hidden side, exit rule, dodge-recovery)

> **Epic**: Pattern & Difficulty
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (Core Rules 7, 8; Formula F2)
**Requirement**: `TR-pattern-difficulty-009`, `TR-pattern-difficulty-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: P1 checks each chunk alone and returns every violation (exhaustive, deterministic order); `SOLUTION_NOT_IN_GAP` checks each stored `solution_angles` entry lies inside a real safe gap. Within-chunk spacing is enforced by the P1 preflight.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Pure math over compiled `HazardSpec`; no post-cutoff API.
**Control Manifest Rules (this layer)**:
- Required: `HIDDEN_CONTENT_FORBIDDEN` per piece and `EXIT_BEYOND_VISIBLE_ARC` per `theta_solution` (a PI-symmetric type such as Near-Ring passes); `DODGE_RECOVERY_VIOLATION` for an opposing within-chunk pair below `DODGE_RECOVERY_S`; Spike has no `theta_solution` and is exempt from the opposing check within the GDD pair rule; use the wrapped angular difference.
- Forbidden: a centre-based `hidden` classifier; a raw `abs` on angles; rejecting a chunk for a specific neighbour.
- Guardrail: `DODGE_RECOVERY_S` 26.6 u and `S_MIN_SPACING` 6.25 u at defaults.

## Acceptance Criteria
- [ ] **AC-10** With `THETA_REF` 0 and `VISIBLE_ARC_HALF_WIDTH_TEST` PI/2: (a) piece `(2.9, 3.4)` rejected with `HIDDEN_CONTENT_FORBIDDEN`; (b) the fixture Wall `(0.4127, 5.8705)` and every shipped fixture chunk is not rejected; (c) `(1.2, 2.2)` not rejected; (d) a two-piece hazard with `(-0.3, 0.3)` and `(2.9, 3.4)` rejected (per piece); mutation with a centre-based classifier fails rows (b) and (c); (e) with half width 1.0472, a Wall with its gap centred at 1.2 is rejected with `EXIT_BEYOND_VISIBLE_ARC` although not hidden; Near-Ring at PI passes.
- [ ] **AC-11** REV2 (Wall `s_start` 0.5 theta 0; Near-Ring `s_start` 27.1 theta PI, distance 26.6 = `DODGE_RECOVERY_S`) accepted at the `>=` boundary. `TOO_CLOSE` (Near-Ring at `s_start` 20.5, 20.0 u) rejected with `DODGE_RECOVERY_VIOLATION`. `TWIN_WALL` (two Walls theta 0, `s_start` 2.0 and 8.5, 6.5 u) accepted (floor applies only to opposing pairs).
- [ ] **AC-12b** (within-chunk rows) DG1 solution angles -0.8 and 0.8; a second read at theta 1.0, 26.6 u later: opposing via the first gap, accepted at the boundary; at 26.5 u rejected with `DODGE_RECOVERY_VIOLATION`. A one-representative-angle mutation (average 0) must fail. The cross-chunk rows (26.5 u needs exactly 1 padding segment) are asserted in Story 010.

## Implementation Notes
`PatternConfig.validated()`-level chunk checks live in a `PatternMath`/`ChunkLibraryCompiler` validator (P1 entry used by Obstacle epic's `ContentPreflight`, stories 011 to 012). Delegate `hidden`, `EXIT_BEYOND_VISIBLE_ARC` and gap checks to the existing Obstacle F4 validators in `src/core/obstacle/`; do not reimplement. The read of a placement is its `HazardSpec`: `s_start` = earliest piece `s` in chunk-local coordinates plus the segment offset, `solution_angles` from the spec. Record shape: `{code, chunk_id, other_chunk_id, detail}`. Emit the pair in the record naming the offending reads.

## Out of Scope
- Story 010: cross-chunk padding. Obstacle epic: the owning F4 / `EXIT_BEYOND_VISIBLE_ARC` implementations.
- Story 008: pool-wide clustering.

## QA Test Cases
- **AC-10**: hidden and exit gates
  - Given: pieces per rows (a)-(e) and the full fixture library. When: validated. Then: expected codes, none for shipped chunks.
  - Edge cases: centre-based mutation fails (b) and (c).
- **AC-11**: boundary and companions
  - Given: REV2, `TOO_CLOSE`, `TWIN_WALL`. When: validated. Then: accept, `DODGE_RECOVERY_VIOLATION` naming chunk and pair, accept.
  - Edge cases: exact `>=` at 26.6 (compare with 1e-6 tolerance).
- **AC-12b**: Double Gate any-pair rule
  - Given: DG1 plus a read at theta 1.0 at 26.6 and 26.5 u. When: validated. Then: accept; reject.
  - Edge cases: average-angle mutation accepts 26.5 u wrongly.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_chunk_validator_test.gd` (AC-10, AC-11, AC-12b)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 001, 002, 003; obstacle-system story 006 (hidden and exit validators)
- Unlocks: Story 010, Story 014; obstacle-system story 011
