# Story 013: Integration: real Ball Movement and Run State lifecycle (AC-22, AC-26)

> **Epic**: Scoring & Personal Best
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-020`, `TR-scoring-personal-best-013`, `TR-scoring-personal-best-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: Run State emits the ending in its Requests stage and forces that tick's `dt_eff` to 0, so `final_score == floori(ball.s)` holds only if the Scoring step runs after Ball Movement's; the pinned `run_ended` order is Juice, Scoring, then HUD.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Uses the real `RunStateCore` (`src/core/run_state/run_state_core.gd`) and `BallCore` (`src/core/ball_movement/ball_core.gd`) through the real `GameRoot` rows. Juice and HUD have not landed (Presentation epics): use recording spies registered at the Juice and HUD ranks.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [ ] **AC-22** With real Ball Movement and Run State: `current_score` tracks the real `s` through a full lifecycle (reset, start, running, hit, restart), proves connect-before-emit against the real Run State (not the AC-19 fake) and its reciprocal commitment (`run-state-restart.md` Core Rule 15), and asserts `final_score == floori(ball.s)` at ending time.
- [ ] **AC-26** With the real Run State and spies at the Juice and HUD ranks registered through the `_wire()` table, a hit that sets a new best logs: Juice's `run_ended` handler, then Scoring's `on_run_ended`, then `personal_best_updated` (emitted inside Scoring's handler), then HUD's `run_ended` handler. A spy that records `personal_best_updated` before its own `run_ended` is a failure of the composition root's order, not of Scoring. The same order is checked for `run_abandoned` (Juice; Scoring; the rest).

## Implementation Notes
- BLOCKING at the first-playable gate (owner: user). Shares the composition-root fixture with Run State AC-30.
- Drive ticks through `GameRoot`'s own tick, not by calling cores in test-chosen order, otherwise the step-order obligation is not exercised.
- A one-tick-late `final_score` (Scoring stepped before Ball) is the failure this story exists to catch.

## Out of Scope
- Real Juice and HUD behavior (Presentation epics); the real-device run (first-playable device evidence).

## QA Test Cases
- **AC-22**: lifecycle
  - Given: a `GameRoot` fixture with real Ball Movement, Run State, Scoring
  - When: a scripted run ends by hit, then another is abandoned
  - Then: `final_score == floori(ball.s)` in both; first frame of each new run reads 0
  - Edge cases: the first emission after construction is not dropped
- **AC-26**: subscriber order
  - Given: spies at the Juice and HUD ranks plus a log
  - When: a new-best hit occurs, then an abandon
  - Then: log order Juice, Scoring, `personal_best_updated`, HUD; and Juice, Scoring for abandon
  - Edge cases: a mis-ranked spy yields a composition-root failure

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/scoring_personal_best/scoring_personal_best_run_lifecycle_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 005, 011; ball-movement and run-state epics (real cores exist); Juice and HUD represented by spies
- Unlocks: First-playable gate
