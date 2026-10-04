# Story 002: ScoreCore construction, seams, boot read and accessors

> **Epic**: Scoring & Personal Best
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-002`, `TR-scoring-personal-best-008` (boot read and clamp), `TR-scoring-personal-best-016` (seam-call budget at construction), `TR-scoring-personal-best-018` (fixtures)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0002: Game loop, Composition Root and tick order; ADR-0009: Test framework and CI
**ADR Decision Summary**: `[scoring].personal_best` is read through `SaveCore.get_value` once at construction and written through `SaveCore.set_value`; `ScoreCore` receives them as injected Callable seams, never a singleton.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `Callable.is_valid()` checks liveness and method existence only, never arity or return type; an `assert` in `_init` is stripped from release exports and is not catchable in GUT, so the testable surface is `validate_seams`. `get_value` returns a Variant. Real API: `SaveCore.get_value(section: String, key: String, default: Variant) -> Variant` and `set_value(section: String, key: String, value: Variant) -> bool` in `src/core/persistence/save_core.gd`.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [x] **AC-9** Constructed against `make_save_stub(500)`, across N cycles of `on_run_reset()`, several `step()`s and a new-best ending, `get_value_seam` is called exactly once (count 1 immediately after construction); a companion row with two or more consecutive `on_run_reset()` calls and no `step()` keeps the count at 1 and `current_score` at 0.
- [x] **AC-11a** (arity and behavioral rows) a static scan of `ScoreCore._init` finds exactly 4 parameters (`s_seam`, `get_value_seam`, `set_value_seam`, `milestone_distances`), none near-miss-shaped; `ScoreCore.validate_seams(s, g, s2)` returns `false` with one unset `Callable()` in each slot in turn and `true` for three valid seams. (The typed-binding lint row is in story 010.)
- [x] **AC-17** `get_value_seam` returning the caller default 0: construction completes without error, `get_current_score()` is 0 before the first `on_run_reset()`, and the first ending compares against `personal_best` 0 with no first-launch branching.
- [x] **AC-18** `make_save_stub(-5)` clamps the in-memory best to 0 (a zero-distance ending is not a new best); `make_save_stub(-1)` then an ending of 1 is a new best; `make_save_stub(9223372036854775806)` is NOT clamped (an ending of 5000 is not a new best, no crash); a stub returning Variant `500.7` yields an int best of 500.

## Implementation Notes
- Create `src/core/scoring_personal_best/score_core.gd` (`class_name ScoreCore`, `extends RefCounted`). `_init(s_seam: Callable, get_value_seam: Callable, set_value_seam: Callable, milestone_distances: Array[int])`; `_init` calls `assert(validate_seams(...))`. `static func validate_seams(s: Callable, g: Callable, s2: Callable) -> bool`.
- Rule 7: `personal_best = maxi(0, int(get_value_seam.call("scoring", "personal_best", 0)))`, read once, never again. An oversized value is deliberately not clamped.
- Add the accessors as explicit methods `get_current_score()` and `get_personal_best()`, never computed properties.
- Seams are bound by the composition root from typed method references (story 011), never `Callable(obj, "name")`. `BallCore.s` is a property (`src/core/ball_movement/ball_core.gd`), so story 011 decides the typed getter that the `s_seam` binds.
- Fixtures in `tests/support/scoring_fixtures.gd`: `PERSONAL_BEST_FIXTURE_DEFAULT = 500`; `make_s_stub(sequence)` (index kept in a member, because GDScript closures capture primitives by value; empty sequence returns 0.0; holds the last value); `make_save_stub(initial_best, write_succeeds := true)` with call-count and argument spies; `make_core(...)`; `make_score_fixture()`.
- If `ScoreCore` logs, use the 4-argument sink `(level, code, key, message)` with `LogLevel` from `src/core/log/log_level.gd`; the GDD requires no logging here.

## Out of Scope
- Story 004: `step()`. Story 005: ending handlers. Story 007: milestone firing.

## QA Test Cases
- **AC-9**: read once
  - Given: `make_core` with `make_save_stub(500)`
  - When: scripted reset, step and new-best-ending cycles run
  - Then: `get_value_seam` call count is exactly 1 throughout
  - Edge cases: repeated `on_run_reset()` with no step; a lazy first read must fail the count-after-construction check
- **AC-11a**: arity and seam validity
  - Given: the `ScoreCore` source and four seam combinations
  - When: `_init` parameters are parsed and `validate_seams` is called
  - Then: 4 parameters; `false` for each unset slot; `true` for all valid
  - Edge cases: an added fifth near-miss-shaped parameter must fail
- **AC-17**: no save file
  - Given: stub returning default 0
  - When: core is constructed and one ending runs
  - Then: no error, score 0, comparison against 0
  - Edge cases: none beyond the default
- **AC-18**: domain clamp
  - Given: stubs -5, -1, int64 max minus 1, and 500.7
  - When: constructed and ended as described
  - Then: best 0, 0, unchanged, 500 with the listed verdicts
  - Edge cases: each case uses a fresh core (AC-9 forbids a second read)

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/scoring_personal_best/scoring_personal_best_construction_test.gd`
**Status**: [x] Created
**Evidence**: scoring_personal_best_construction_test.gd (all rows incl. AC-9 new-best-ending leg test_read_once_holds_across_new_best_ending_cycles)

## Dependencies
- Depends on: Story 001; `SaveCore` (exists in `src/core/persistence/save_core.gd`)
- Unlocks: Stories 003 to 010
