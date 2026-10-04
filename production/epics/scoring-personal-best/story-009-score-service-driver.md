# Story 009: ScoreService driver and Run State wiring against a fake source

> **Epic**: Scoring & Personal Best
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-013` (callback type), `TR-scoring-personal-best-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `GameRoot` is the only per-frame caller; a thin `ScoreService` node connects Run State signals to `ScoreCore` non-deferred during composition-root construction, in the order Run State pins.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `ScoreService` must not declare `_process` or `_physics_process` (only `GameRoot` may); `GameRoot` calls its `step()` once per tick after Ball Movement. Mirror `src/core/persistence/save_service.gd` (a thin Node built by the composition root, not an autoload). Godot drops a signal emitted before `connect()`.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [ ] **AC-19** A fake Run State source (`make_fake_run_state()` with only `run_reset(run_id)`, `run_ended(run_id, hazard_id, run_time_ms)`, `run_abandoned(run_id, run_time_ms)`) and a spy-fitted `ScoreService` (not in the scene tree) connected to it: each emit reaches the matching `ScoreCore` handler with arguments intact and before `emit()` returns (catches a deferred or `_ready()`-based connect). BLOCKING companion: `project.godot` has no `[autoload]` entry for `ScoreService` or `ScoreCore`. ADVISORY companion: neither file declares a `static var` of its own class type or calls `Engine.register_singleton()`.

## Implementation Notes
- Create `src/core/scoring_personal_best/score_service.gd` (`class_name ScoreService`, `extends Node`): `_init(core: ScoreCore, source: Object)`, connect with plain `connect` (never `CONNECT_DEFERRED`), and a public `step()` that calls `core.step()`; no per-frame callback of its own.
- Typed handlers (`run_id: int`, `hazard_id: int`, `run_time_ms: int`), because signal arguments are coerced to the handler types. The rank-ordered connection itself is one row per signal in `GameRoot._wire()` (story 011); this story proves the node's wiring in isolation.
- Fixtures: `make_fake_run_state()` and `make_score_service(core, source) -> ScoreService`.

## Out of Scope
- Story 011: `GameRoot` construction order, rows, ranks and the tick call. Story 013: the real Run State.

## QA Test Cases
- **AC-19**: wiring
  - Given: fake source, spy core, `ScoreService` built around them
  - When: each of the three signals is emitted in turn
  - Then: the matching handler ran with the same arguments before `emit()` returned
  - Edge cases: emit with no scene tree; the autoload and `static var` lint companions

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/scoring_personal_best/scoring_personal_best_service_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 003, 005; `RunStateCore` signal shapes (exist in `src/core/run_state/run_state_core.gd`)
- Unlocks: Story 011
