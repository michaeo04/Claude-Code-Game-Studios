# Story 007: milestone_crossed, ScoringConfig and validate_milestones

> **Epic**: Scoring & Personal Best
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-011`, `TR-scoring-personal-best-012` (resource and validator; the startup refusal is story 011)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `GameRoot` is the only node that runs a per-frame callback and calls systems in one fixed order; cores are RefCounted with injected seams, no autoloads. GUT 9.x runs the Logic tests.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Thresholds are data (`ScoringConfig`), validated by a pure function and passed to `ScoreCore` as its fourth constructor parameter; no gameplay value is hardcoded.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [ ] **AC-23** Thresholds `[100, 250]` with `s` 99, 101, 249, 251: `milestone_crossed(100)` once at the first tick the score reaches 100, `milestone_crossed(250)` once, none early, repeated or out of order. After `on_run_reset()` mid-run, both fire again. Boundary rows: `s` 100.0 fires, 99.999 does not, a first-step 100.0 after a reset fires (a `>` mutation fails). An empty array over a long run fires nothing and never indexes out of bounds.
- [ ] **AC-24** Thresholds `[100, 250, 500]` and one `step()` jumping `s` from 90 to 600: three events in one call in the order 100, 250, 500 (never batched, skipped or reordered).
- [ ] **AC-25** `ScoringConfig.validate_milestones(Array) -> Array[String]` returns one message per violation for non-ascending or duplicate (`[250, 100]`, `[100, 100]`), non-positive (0, negative) and non-integer (`100.5`); a valid or empty array returns `[]`.

## Implementation Notes
- Create `src/core/scoring_personal_best/scoring_config.gd` (`class_name ScoringConfig`, `extends Resource`, `@export var milestone_distances: Array[int]`, default `[100, 250, 500, 1000, 2000]`, a placeholder pending Open Question 9) and a pure `static func validate_milestones(values: Array) -> Array[String]` (no file I/O). Follow the Config pattern of `src/core/ball_movement/ball_config.gd`.
- In `step()` after the score update: `while next_milestone_index < milestone_distances.size() and current_score >= milestone_distances[next_milestone_index]:` emit `milestone_crossed(threshold)` and increment. A `while`, not an `if`.
- An empty array disables milestones. `milestone_crossed` has no near-miss coupling.
- The composition root refuses to build `ScoreCore` when `validate_milestones` returns a non-empty result (story 011).

## Out of Scope
- Story 011: the startup refusal wiring. Open Question 9 (final values) is a playtest decision.

## QA Test Cases
- **AC-23**: ordered once-per-run firing
  - Given: thresholds `[100, 250]`
  - When: the listed `s` sequence runs, then a reset and a replay
  - Then: events 100 then 250, once each, in both runs
  - Edge cases: 99.999 vs 100.0; first-step crossing after reset; empty array
- **AC-24**: multi-threshold jump
  - Given: thresholds `[100, 250, 500]`
  - When: `s` jumps 90 to 600 in one `step()`
  - Then: three events in ascending order
  - Edge cases: a highest-only mutation fails
- **AC-25**: validator
  - Given: arrays `[250,100]`, `[100,100]`, `[0]`, `[-5]`, `[100.5]`, `[100,250]`, `[]`
  - When: `validate_milestones` is called
  - Then: one message per violation; `[]` for the last two
  - Edge cases: mixed violations return one message each

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/scoring_personal_best/scoring_personal_best_milestones_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 002, 003
- Unlocks: Stories 008, 011
