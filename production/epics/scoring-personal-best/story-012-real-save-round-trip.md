# Story 012: Integration: real SaveCore round trip (AC-21)

> **Epic**: Scoring & Personal Best
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-020`, `TR-scoring-personal-best-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: A real `SaveCore` over a fake `SaveFs` receives Scoring's `get_value`/`set_value` calls; a new best must round-trip a save/load cycle, and a failed write must revert on cold boot.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Use the fake `SaveFs` from the save-persistence tests (`tests/unit/save_persistence/`), not the real `user://`. Real API: `SaveCore.get_value(section: String, key: String, default: Variant) -> Variant` and `set_value(section: String, key: String, value: Variant) -> bool` in `src/core/persistence/save_core.gd`.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [ ] **AC-21** With a real `SaveCore` (not a stub) bound to `ScoreCore` through the actual seam implementation: a new best set by `on_run_ended` is read back by a second `SaveCore`/`ScoreCore` pair after `boot_load()` (the cold-boot round trip); and the cold-boot-reverts-a-failed-write case that AC-14 could only assert in session: with the fake `SaveFs` failing the write, the in-session best is the new value but a cold boot reads the old value.

## Implementation Notes
- BLOCKING at the first-playable gate (owner: user). Build on the story 002 fixtures but replace `make_save_stub` with the real `SaveCore`.
- The disk-format check (`[scoring].personal_best` int in `user://save.cfg`) is Save & Persistence's own; assert only that Scoring's value survives the cycle.
- If spike SP-3 fails and the `flush_dirty()` fallback is adopted, the cold-boot assertion must flush before the second boot.

## Out of Scope
- Story 013: real Ball Movement and Run State. Real-device file I/O (Save & Persistence device evidence).

## QA Test Cases
- **AC-21**: round trip
  - Given: real `SaveCore` over a fake `SaveFs`, starting best 500
  - When: a 600 ending, then a cold `boot_load()` of a new pair
  - Then: the new `ScoreCore` reads 600; with a write-failing `SaveFs`, in-session 600 and cold-boot 500
  - Edge cases: tie and lower endings leave the stored value untouched

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/scoring_personal_best/scoring_personal_best_save_round_trip_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 005, 011; save-persistence epic (`SaveCore`, fake `SaveFs`); spike SP-3 result
- Unlocks: First-playable gate
