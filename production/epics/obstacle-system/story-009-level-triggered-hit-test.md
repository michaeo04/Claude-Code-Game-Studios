# Story 009: Level-triggered hit test with broad phase

> **Epic**: Obstacle System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/obstacle-system.md` (Core Rules 2, 3, 4; Edge Cases collision test)
**Requirement**: `TR-obstacle-system-003`, `TR-obstacle-system-005`, `TR-obstacle-system-015`, `TR-obstacle-system-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 4); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: The hit test is the approved swept AABB, run once per tick right after `TubeTrack.advance` on the published `(theta_prev, theta, s_prev, s)`, with a per-hazard `s_lo` / `s_hi` broad phase; `hit_reported(hazard_id, run_id)` is a signal on `ObstacleCore`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No driver node, `process_priority` or physics catch-up exists; the core makes no engine-callback choice. Per-tick cost of the 192-piece worst case is measured in spike OB-1 (Story 014).
**Control Manifest Rules (this layer)**:
- Required: broad phase compares `s_lo` / `s_hi` (expanded by `D/2`) with the tick's swept `s` range first and skips non-intersecting hazards; one `hit_reported` per overlapped hazard per tick, in every phase, no phase awareness; `Obstacle.test` before `NearMiss.step`.
- Forbidden: `CollisionObject3D` / `Area3D` / `PhysicsServer3D`; deferred `hit_reported` connection; raw world Z.
- Guardrail: at most 192 pieces held, about 24 tested; `Obstacle.test` + `NearMiss.step` at most 0.4 ms per tick (OB-1, advisory until measured).

## Acceptance Criteria
- [ ] **AC-16 [C]** Wall 301 bound, ball held at a stationary point inside its effective footprint (`theta_prev == theta`, `s_prev == s`, `dt_eff == 0`) for 5 ticks: `hit_reported(301, run_id)` fires once per tick, 5 times; a sixth tick outside stops reports with no special "clear" event.
- [ ] **AC-17 [C]** Double Gate 202, tick `theta_prev -0.35, theta 0.35, s_prev 100.5, s 100.6`: both pieces satisfy F2 but exactly one `hit_reported(202, run_id)` is sent.
- [ ] **AC-18 [C]** two independent hazards co-located (fixture bypassing `HAZARD_OVERLAP`) both overlapped on one tick: both reports sent; no unilateral choice.
- [ ] **AC-22 [C]** scripted tick with `theta = NaN` (or `s = +inf`): treated as a no-op (last known-good swept endpoint held), exactly one error logged, no `hit_reported` from a NaN comparison; the next valid tick resumes normally.

## Implementation Notes
`hit_reported` is emitted by `ObstacleCore` and connected in `_wire()` immediately (Story 013). The test reads the injected ball-state seam (`theta`, `theta_prev`, `s`, `s_prev`) once per tick; it never calls a mutating Ball Movement method and never reads raw world Z. `run_id` comes from the last `run_reset` (Story 008). A no-op frame (Paused, Hit, settling) degenerates to a point-in-footprint check because Ball Movement publishes `prev == current`. Non-finite guard happens before any comparison. Report by `hazard_id` (a piece-level hit sets a per-hazard flag). The ball-state stub is scripted tick by tick; never a real `BallCore`.

## Out of Scope
- Story 013: wiring to the real BallCore, TubeTrack and Run State (AC-25 to AC-27) and Godot physics-substep behaviour.
- Run State's tie-break (lowest `hazard_id`) and stale-`run_id` discard.

## QA Test Cases
- **AC-16**: Given Wall 301 and a stationary stub inside it. When 6 ticks run. Then 5 reports then none.
  - Edge cases: `dt_eff == 0` on every tick.
- **AC-17**: Given Double Gate 202. When the straddling step runs. Then one report.
- **AC-18**: Given two co-located hazards. Then two reports, ids both present.
- **AC-22**: Given NaN then a valid tick. Then one error log, zero reports on the NaN tick, normal result next.
  - Edge cases: `+inf` and `-inf` on `s`; NaN in only `theta`.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/obstacle_system/obstacle_system_hit_test_test.gd`
**Evidence**: `tests/unit/obstacle_system/obstacle_system_hit_test_test.gd` (4 tests, AC-16, AC-17, AC-18, AC-22). Non-finite tick is a full no-op with log code `BALL_STATE_NOT_FINITE` (GDD names no code).

## Dependencies
- Depends on: Stories 003, 007 (and 008 for `run_id` capture)
- Unlocks: Stories 010, 013, 014, 016
