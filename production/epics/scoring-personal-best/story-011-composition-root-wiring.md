# Story 011: Composition Root: construct, wire rows, tick call and milestone preflight

> **Epic**: Scoring & Personal Best
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-012` (startup refusal), `TR-scoring-personal-best-013`, `TR-scoring-personal-best-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `GameRoot` builds `RunStateCore` and `ScoreService` early (construction emits nothing), connects Scoring through the sorted `[signal, handler, rank]` table (`run_ended`: Juice; Scoring; HUD; the rest), and calls `step()` once per tick after `NearMiss.step`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Read `src/core/game_root.gd` first: `CONSTRUCTION_ORDER`, `_construct()`, `_build_rows()`, `add_wire_row()`, the rank constants and `_juice_scoring_codes()` (which already rejects Juice ranked after Scoring). Handlers must be typed. The tick order is fixed by ADR-0002 Decision 6; `Ball.step` and `Scoring.step` must use the same callback type.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [ ] Covers GDD Rules 11 and 7 (no standalone AC id): `_construct()` builds `ScoreCore`/`ScoreService` after `SaveService` and `SettingsCore` and together with `RunStateCore`, with the three seams bound from typed method references and the milestones taken from `ScoringConfig`.
- [ ] `_build_rows()` adds `run_reset` (rank `RANK_REST`), `run_ended` (the Scoring rank, after Juice and before HUD) and `run_abandoned` (Scoring rank) rows; `_wire()` returns `OK` and the sorted order places Scoring second on `run_ended` and `run_abandoned`.
- [ ] `GameRoot` calls the `ScoreService` step once per tick strictly after the Ball Movement step and after `NearMiss.step` (or in its place while Near-Miss has not landed), with no per-frame callback on `ScoreService`.
- [ ] **AC-25 wiring half**: a `ScoringConfig` whose `validate_milestones` is non-empty makes construction refuse to build `ScoreCore` (fatal, nothing connected); a valid or empty config constructs.

## Implementation Notes
- Prefer the existing mechanism: a new system adds one row in `_build_rows()` and one entry in the construction factory; do not add a second connection site.
- `ScoreCore` construction emits nothing; Run State emits only after `map_ready`, which follows `wire()`, so no signal is missed (GDD Rule 11).
- Log refusals through the single contract: `LogLevel` and the 4-argument sink `(level, code, key, message)` from `src/core/log/log_level.gd`; add a stable code constant such as `SCORING_MILESTONES_INVALID` for the refusal.

## Out of Scope
- Story 013: behavior against the real Ball Movement and Run State lifecycle. Juice and HUD handlers (other epics).

## QA Test Cases
- **Construction and rows**
  - Given: a `GameRoot` test fixture like `tests/integration/composition_root/composition_root_construction_test.gd`
  - When: construction and `_wire()` run
  - Then: `construction_trace` shows Scoring after Save and Settings and before views; Scoring's rank rows sit second on `run_ended` and `run_abandoned`
  - Edge cases: a Juice row ranked after Scoring is rejected with the existing code
- **Tick order**
  - Given: a recording stand-in for Ball Movement and `ScoreService`
  - When: one `GameRoot` tick runs
  - Then: Ball step precedes the Scoring step; `ScoreService` has no `_process`
  - Edge cases: none
- **Milestone preflight**
  - Given: configs `[250, 100]`, `[]`, `[100, 250]`
  - When: construction runs
  - Then: refused, built, built

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/scoring_personal_best/scoring_personal_best_wiring_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 007, 009; composition-root epic stories (`_construct`, `_wire`, rank constants already in `src/core/game_root.gd`)
- Unlocks: Stories 010 (typed-binding row), 012, 013
