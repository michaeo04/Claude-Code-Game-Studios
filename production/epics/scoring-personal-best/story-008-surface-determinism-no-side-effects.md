# Story 008: Public surface, determinism and no side effects

> **Epic**: Scoring & Personal Best
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-003` (Partial), `TR-scoring-personal-best-015`, `TR-scoring-personal-best-016`, `TR-scoring-personal-best-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: Tests are deterministic and isolated; reflection-based checks that a regex cannot express are `custom` lint rules, with the reflection behavior verified on the pinned binary first.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: TR-scoring-personal-best-003 is Partial in `docs/architecture/architecture-traceability.md`: `Script.get_script_method_list()` behavior is unverified on 4.7.2. The implementing step is a throwaway one-line check of the call; the scan must filter any inherited `RefCounted`/`Object` member that appears. If the call proves unusable, the fallback is a source parse of top-level `func` declarations (static included) whose name does not start with `_`. This does not block the story because the fallback is pre-committed.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [ ] **AC-11b** `ScoreCore`'s non-underscore script-defined methods are exactly `step`, `on_run_reset`, `on_run_ended`, `on_run_abandoned`, `get_current_score`, `get_personal_best` (plus the static `validate_seams`, listed explicitly as the documented seam check); no near-miss-shaped method exists even if unused. `get_script_signal_list()` returns exactly `personal_best_updated(final_score: int)`, `personal_best_passed(personal_best: int)`, `milestone_crossed(threshold: int)`.
- [ ] **AC-12** Over a full scripted session (boot, several run cycles, new bests and non-bests) the only seam calls are `s_seam` (exactly one per `step()`, none from reset or ending handlers), `get_value_seam` (exactly once) and `set_value_seam` (only on new-best endings).
- [ ] **AC-13** Two independently constructed cores run the identical `s` and event script from the identical starting best: the full `current_score` sequences and both final `is_new_best` verdicts are bit-identical.

## Implementation Notes
- First step: run a throwaway check of `ScoreCore.get_script().get_script_method_list()` on the 4.7.2 binary (`GODOT` per memory note `reference_godot_binary_and_ci`), record the result in the story file, and pick the reflection or source-parse mechanism. Update the traceability Partial note when closed.
- The whitelist note: `validate_seams` is a static method that is part of the construction contract (GDD Rule 7); reconcile with TR-003's "exactly six" wording by asserting the six instance methods and naming `validate_seams` as the one allowed static helper.
- Spies count calls per seam with container-held counters; no randomness anywhere.

## Out of Scope
- Story 010: source-text lints (identifier scan, deny-list scan, autoload scan).

## QA Test Cases
- **AC-11b**: surface
  - Given: the loaded `ScoreCore` script
  - When: its method and signal lists are read (mechanism per the first step)
  - Then: the closed sets above, inherited members filtered
  - Edge cases: a mutation adding an unused `on_near_miss_detected()` must fail
- **AC-12**: seam budget
  - Given: spies on all three seams
  - When: a mixed multi-run session runs
  - Then: the counts above
  - Edge cases: a reset or ending that reads `s_seam` desyncs the stub and fails
- **AC-13**: determinism
  - Given: two cores, same scripts
  - When: both run the session
  - Then: identical score sequences and verdicts
  - Edge cases: none

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/scoring_personal_best/scoring_personal_best_surface_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 004, 005, 006, 007
- Unlocks: Story 010
