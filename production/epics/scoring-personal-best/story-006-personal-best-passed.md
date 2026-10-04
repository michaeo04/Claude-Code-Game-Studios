# Story 006: personal_best_passed: once-per-run live crossing

> **Epic**: Scoring & Personal Best
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `GameRoot` is the only node that runs a per-frame callback and calls systems in one fixed order; cores are RefCounted with injected seams, no autoloads. GUT 9.x runs the Logic tests.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `personal_best_passed` carries no presentation of its own; a boolean latch (`has_passed_this_run`), cleared on reset, prevents a second fire.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [x] **AC-20a** `personal_best` 500, `s` 499.5, 500.4, 501.2, 700: no fire at score 500, exactly one `personal_best_passed(500)` at the tick the score becomes 501, none afterwards (a `>=` or every-tick mutation fails).
- [x] **AC-20b** A run that never reaches the best never fires.
- [x] **AC-20c** `on_run_reset()` mid-run after a crossing, then the same crossing again: it fires again (the latch is per run, not per session).
- [x] **AC-20d** `make_save_stub(500)` and a first `step()` with `s` 501.0: fires on that first call, exactly once.
- [x] **AC-20e** `make_save_stub(0)` and a first `step()` with `s` 1.0: does NOT fire. Companion: a full run to a best of 50, then a second run in the same session crossing 50 fires `personal_best_passed(50)`.
- [x] **AC-20f** Crossing on tick N and an ending on tick N+1: `personal_best_passed` once (tick N), `personal_best_updated` once (tick N+1), neither re-fires; a `step()` after the ending with frozen `s` fires nothing and changes nothing.

## Implementation Notes
- Fire condition inside `step()` after the score update: `not has_passed_this_run and personal_best > 0 and current_score > personal_best`, then set the latch and emit `personal_best_passed(personal_best)`.
- The `personal_best == 0` check reads the live in-memory value at crossing time, so it lifts the instant a real best is written (story 005).
- No haptic or visual decision here; that belongs to `juice-feedback.md` and `hud.md`.

## Out of Scope
- Story 007: milestones. HUD or Juice presentation of the signal (other epics).

## QA Test Cases
- **AC-20a to AC-20f**: one case each as worded above
  - Given: the stub and starting best named in the criterion
  - When: the listed `step()` and ending calls run, observed through `make_signal_log`
  - Then: the exact signal log in the criterion
  - Edge cases: strict `>` at score equal to best; first-tick crossing; fresh-install suppression lifting within one session

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/scoring_personal_best/scoring_personal_best_passed_test.gd`
**Status**: [x] Created
**Evidence**: scoring_personal_best_passed_test.gd (AC-20a to AC-20f)

## Dependencies
- Depends on: Stories 003, 005
- Unlocks: Story 008
