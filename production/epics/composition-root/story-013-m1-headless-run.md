# Story 013: M1 headless run through the real cores

> **Epic**: Composition Root & Game Loop
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-05

## Context
**GDD**: none, milestone M1 "headless simulation complete" (ADR-0002 Decisions 6 and 7)
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Control Manifest Rules**: no `_process` outside `GameRoot`; immediate connections only; no randomness.

## Acceptance Criteria
- [x] `_wire()` connects the real rows (Tube, Tilt, Ball, Obstacle, Near-Miss, Scoring) and every row is typed and valid
- [x] A scripted run (scripted gravity source) dodges a hazard, passes a second in the near zone and hits a third; Run State goes Hit
- [x] Scoring's final score equals floor(s) at the hit; the personal best is written once through a fake Save seam
- [x] The near-miss hazard yields exactly one `near_miss_detected`; the dodged hazard never reports a hit
- [x] After restart: score 0, WorldFrame origin 0, ball at 0, window re-primed, hazards re-bound, run ids updated, best kept
- [x] Two identical scripted runs give bit-identical traces and events
- [x] A stored best above the run is not overwritten

## Implementation Notes
Hazards come from a fake provider table (the Pattern provider does not exist; the chunk library fixture is not compiled).
`GameRoot._tick` now calls `Obstacle.step(ball)`, `NearMiss.step(ball)`, `Scoring.step()`. `BallCore.on_run_reset/on_run_resumed` and an optional run id on `ScoreCore.on_run_reset` were added so they connect directly.

## Test Evidence
**Story Type**: Integration
**Evidence**: `tests/integration/composition_root/composition_root_m1_headless_run_test.gd` (6 tests, passing)

## Dependencies
- Depends on: Stories 002, 006, 007 (partial); Run State, Tilt, Ball, Tube Track, Obstacle, Near-Miss, Scoring cores
