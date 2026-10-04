# Story 003: step(): live score, frozen score and run reset

> **Epic**: Scoring & Personal Best
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-004`, `TR-scoring-personal-best-006`, `TR-scoring-personal-best-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `GameRoot` is the only node that runs a per-frame callback and calls systems in one fixed order; cores are RefCounted with injected seams, no autoloads. GUT 9.x runs the Logic tests.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `step()` takes no phase argument; freezing is inherited from a frozen `s`. `on_run_reset()` must be non-deferred and runs before `run_started`.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [ ] **AC-4** Feeding a scripted advancing `s` through `step()` once per tick publishes `current_score = floor(s)` on every tick, matching AC-1 per value; an accumulating mutation fails once a tick's `s` delta and its floor delta disagree.
- [ ] **AC-5** A sequence where `s` repeats the same value for several consecutive `step()` calls (Hit, Paused, Resuming, settling tick) holds `current_score` across every tick; `step()` has no phase parameter.
- [ ] **AC-6** After a prior run left `current_score` nonzero, `on_run_reset()` makes it read 0 immediately with no `step()`. Reset clears the guards' memory: run to `s` 1575, reset, then `s` 0, 0.5, 3.0, 12.0 publishes 0, 0, 3, 12; a NaN first step after reset holds 0, never 1575.

## Implementation Notes
- `step()`: one `s_seam` read per call, `current_score = ScoreMath.score(s)`; no accumulator and no separate `last_s` (hold-on-decrease compares against `current_score` itself, story 004).
- `on_run_reset()` zeroes `current_score`, the `has_passed_this_run` latch and `next_milestone_index` synchronously and makes no `s_seam` call (GDD Rule 3, AC-12). The latch and index are declared here and used by stories 006 and 007.
- Add `make_signal_log(core)` to the fixtures (records `(name, payload)` in emission order); stories 005 to 007 reuse it.

## Out of Scope
- Story 004: non-finite, negative, over-range and decreasing `s`.
- Stories 006, 007: the signals that `step()` later emits.

## QA Test Cases
- **AC-4**: live recompute
  - Given: `make_s_stub([0.4, 9.999, 10.5, 1574.991, 1575.008])`
  - When: `step()` runs once per value
  - Then: scores 0, 9, 10, 1574, 1575
  - Edge cases: a delta-accumulating mutation diverges at the fractional rows
- **AC-5**: frozen
  - Given: stub `[42.7, 42.7, 42.7, 42.7]`
  - When: four `step()` calls
  - Then: 42 on every tick
  - Edge cases: stub exhaustion holds the last value
- **AC-6**: reset
  - Given: a core at `current_score` 1575
  - When: `on_run_reset()`, then the stub `[0, 0.5, 3.0, 12.0]` and a NaN-first variant
  - Then: 0 immediately; 0, 0, 3, 12; NaN run holds 0
  - Edge cases: two consecutive resets with no step

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/scoring_personal_best/scoring_personal_best_step_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 001, 002
- Unlocks: Stories 004 to 009
