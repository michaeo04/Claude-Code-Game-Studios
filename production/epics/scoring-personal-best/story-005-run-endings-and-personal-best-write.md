# Story 005: Run endings: finalize, new-best write and personal_best_updated

> **Epic**: Scoring & Personal Best
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-007`, `TR-scoring-personal-best-008` (write part), `TR-scoring-personal-best-009`, `TR-scoring-personal-best-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: The best is written synchronously inside `set_value` so it is on disk before the tick ends (budget measured by spike SP-3, fallback `flush_dirty()` as the last step of the tick); Scoring finalizes inside its `run_ended` handler, after Juice and before HUD.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Spike SP-3 (p95 <= 3 ms for the whole `set_value` path on a mid-tier Android phone) gates this module's first on-device use of the write; if it fails, `set_value` only marks dirty and `GameRoot` calls `save.flush_dirty()` last in the tick, which changes only the timing wording of AC-8, not Scoring's code. Real API: `SaveCore.get_value(section: String, key: String, default: Variant) -> Variant` and `set_value(section: String, key: String, value: Variant) -> bool` in `src/core/persistence/save_core.gd`.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [ ] **AC-7** Two parallel scenarios with an identical `s` script, one ending with `on_run_ended(run_id, hazard_id, run_time_ms)`, one with `on_run_abandoned(run_id, run_time_ms)`: identical `final_score`, `is_new_best`, `set_value_seam` call count and argument, and `personal_best_updated` count. Companion rows: only `on_run_abandoned` is called and a score is still produced; varying `hazard_id` and `run_time_ms` never changes the outcome; the non-new-best branch is identical for both (zero writes, zero events).
- [ ] **AC-8** Against `PERSONAL_BEST_FIXTURE_DEFAULT` 500: (a) final 600 gives exactly one `set_value_seam("scoring","personal_best",600)`, in-memory best 600 already readable when `personal_best_updated(600)` fires once; (b) final 500 (tie) gives zero writes, no event, best still 500; (c) final 400 gives zero writes, no event, best still 500.
- [ ] **AC-14** `make_save_stub(500, write_succeeds := false)` with a 600 ending still updates the in-memory best to 600 (a later comparison uses 600) and `personal_best_updated` still fires; a rollback mutation fails.
- [ ] **AC-16** `on_run_reset()` then an immediate `on_run_ended`/`on_run_abandoned` with zero `step()` calls gives `final_score` 0 and `is_new_best` false for stored bests 0, 500 and -5 (clamped), each on its own fresh core.
- [ ] **SCORE-1** `on_run_ended` setting a new best, then `on_run_abandoned` for the same un-reset run: no second `set_value_seam` call and no second `personal_best_updated`.

## Implementation Notes
- Both handlers finalize from the stored `current_score`, never re-read `s_seam`, and never read `hazard_id` or `run_time_ms` (they exist in the signatures only).
- Order inside a new best: update the in-memory best, call `set_value_seam("scoring", "personal_best", final_score)`, then emit `personal_best_updated(final_score)`, all synchronously in the handler. No re-entrancy guard: the strict `>` makes a duplicate ending idempotent.
- On `WRITE_FAILED` (`set_value` returns `false`) do not retry, roll back or branch; Save & Persistence logs and rate-limits.
- Signals declare typed parameters (`personal_best_updated(final_score: int)`); Godot does not enforce them, so the composition root types its handlers `int`.

## Out of Scope
- Story 006: `personal_best_passed`. Story 009: connecting Run State signals. Story 012: the real `SaveCore` round trip.

## QA Test Cases
- **AC-7**: both endings identical
  - Given: two fresh cores, same `s` script and starting best
  - When: one ends via `run_ended`, the other via `run_abandoned`
  - Then: the four observables match in both new-best and non-new-best branches
  - Edge cases: abandon-only call; varied `hazard_id` and `run_time_ms`
- **AC-8**: write only on a strict new best
  - Given: best 500
  - When: endings of 600, 500, 400 on fresh cores
  - Then: one write and one event; zero and zero; zero and zero
  - Edge cases: `get_personal_best()` is 600 at the moment the event fires
- **AC-14**: failed write
  - Given: write-failing stub, best 500
  - When: a 600 ending, then a 550 ending in the same session
  - Then: best 600, event fired once, the 550 is not a new best
  - Edge cases: none
- **AC-16**: zero-distance ending
  - Given: stored bests 0, 500, -5
  - When: reset then immediate ending
  - Then: `final_score` 0, `is_new_best` false
  - Edge cases: -5 is clamped to 0 at construction
- **SCORE-1**: double ending
  - Given: a new-best run already ended
  - When: `on_run_abandoned` is called for the same run
  - Then: write count stays 1, event count stays 1
  - Edge cases: none

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/scoring_personal_best/scoring_personal_best_endings_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 001, 002, 003; spike SP-3 (save-persistence epic) for the on-device write timing
- Unlocks: Stories 006, 009, 012, 013
