# Story 001: ScoreMath: floor score and strict new-best comparison

> **Epic**: Scoring & Personal Best
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-001`, `TR-scoring-personal-best-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `GameRoot` is the only node that runs a per-frame callback and calls systems in one fixed order; cores are RefCounted with injected seams, no autoloads. GUT 9.x runs the Logic tests.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `floori(s)` returns an `int` directly (the global `floor()` returns a float). Pure static functions only; no `Engine.`, `OS.`, `get_tree`.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [ ] **AC-1** `ScoreMath.score(s)`: `0 -> 0`; `9.999 -> 9`; `10.0 -> 10`; `10.5 -> 10`; `1574.991 -> 1574`; `1575.008 -> 1575`; `777.3 -> 777`. A `round()` mutation fails the `9.999` and `10.5` rows.
- [ ] **AC-2** Monotonicity over at least three scripted non-decreasing `s` sequences (flat runs, fractional-to-integer crossings): the score sequence is non-decreasing and `score[i] - score[i-1] <= ceil(s[i] - s[i-1])` at every step.
- [ ] **AC-3** `ScoreMath.is_new_best(final_score, personal_best)`: `(0,0) -> false`; `(342,0) -> true`; `(200,342) -> false`; `(342,342) -> false`; `(343,342) -> true`; `(9001,9000) -> true`. A `>=` mutation fails the tie row.

## Implementation Notes
- Create `src/core/scoring_personal_best/score_math.gd` (`class_name ScoreMath`, `extends RefCounted`, static functions only), following `src/core/ball_movement/ball_math.gd`.
- F1 is `current_score = floori(s)` for `s >= 0`; F2 is `final_score > personal_best` (strict, a tie is false). No `DISTANCE_SCALE` knob exists (GDD Formulas).
- The NaN, negative and over-range guards belong to `ScoreCore.step()` (story 004); `ScoreMath.score` assumes a valid `s`.
- Doc comments with an example on each public function (coding standards).

## Out of Scope
- Story 004: the `is_finite`, `>= 0`, `<= 9.2e18` guards and the hold-on-decrease rule.
- Story 002: `ScoreCore` and its state.

## QA Test Cases
- **AC-1**: floor table
  - Given: the seven `(s, expected)` rows
  - When: `ScoreMath.score(s)` is called for each
  - Then: result `==` expected and `typeof(result) == TYPE_INT`
  - Edge cases: `9.999` and `10.5` distinguish `floor` from `round`
- **AC-2**: monotone property
  - Given: three constant sequence fixtures (flat, fractional, integer boundary)
  - When: scores are computed in order
  - Then: non-decreasing and the per-step delta bound holds
  - Edge cases: duplicate values give delta 0
- **AC-3**: comparison table
  - Given: the six `(final, best, expected)` rows
  - When: `is_new_best` is called
  - Then: result `==` expected
  - Edge cases: `(0,0)` and the tie are false

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/scoring_personal_best/scoring_personal_best_score_math_test.gd`
**Status**: [x] Created
**Evidence**: scoring_personal_best_score_math_test.gd (test_score_floor_table_matches_expected, three monotone tests, test_is_new_best_table_matches_expected)

## Dependencies
- Depends on: None (the GUT framework, spike T-1, is owned by the test-framework work)
- Unlocks: Stories 002, 003, 005
