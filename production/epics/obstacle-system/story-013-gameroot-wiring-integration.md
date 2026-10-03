# Story 013: GameRoot wiring and real-system integration

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/obstacle-system.md` (Core Rules 2, 3, 5; AC-25 to AC-28; Open Question 16)
**Requirement**: `TR-obstacle-system-004`, `TR-obstacle-system-005`, `TR-obstacle-system-006`, `TR-obstacle-system-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0008: Hazard, collision and content format (Decision 4)
**ADR Decision Summary**: `GameRoot` is the only node that runs `_process`; per frame it calls `Ball.step`, `TubeTrack.advance` (Running only), `Obstacle.test`, `NearMiss.step` in a fixed order, and `_wire()` connects handlers from one sorted table of `[Signal, Callable, rank]` rows with immediate connections.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Handler order within a rank relies on connection order (NEEDS VERIFICATION on 4.7.2, Run State AC-30 spy test). `class_name` types need `godot --headless --import` before the headless run. The sort of rows is not stable, so ties use row index.
**Control Manifest Rules (this layer)**:
- Required: `Obstacle.test` runs in `GameRoot._tick` right after `TubeTrack.advance`, before `NearMiss.step`; `hit_reported` connected to Run State's handler immediately; `run_reset` rank 2 shared with the Tube Track adapter (tie by row order); `GameRoot` holds a strong reference to every core.
- Forbidden: driver node, `process_priority`, physics catch-up for the hit test; `CONNECT_DEFERRED`; `_physics_process`; autoloads.
- Guardrail: `GameRoot` orchestration under 0.1 ms per frame.

## Acceptance Criteria
- [ ] **AC-25 [I]** with the real `BallCore` published state, the test runs exactly once per published pair, including after a large `real_dt` hitch (no catch-up substeps, one `_tick`).
- [ ] **AC-26 [I]** with the real `TubeWindow`, `segment_entered_window`, `segment_left_window` and `window_primed` drive bind and release through the `_wire()` rows.
- [ ] **AC-27 [I]** `hit_reported` reaches the real Run State: a stale `run_id` is discarded and Run State's own phase gating is respected; a hazard that hit the ball stays bound through the Hit freeze (recycling only inside `advance()` in Running, TR-022).
- [ ] **AC-28 [I]** the real `PatternCore` `HazardContentProvider` replaces the placeholder table with no change to `ObstacleCore` (runs once the pattern-difficulty epic provides it).

## Implementation Notes
Rows: `[run_state.run_reset, obstacle.on_run_reset, 2]`, the tube window signals to Obstacle's handlers, `obstacle.hit_reported` to Run State. Never an `await` in a `run_reset` handler or a request from a handler. Ball Movement publishes `(theta_prev, theta, s_prev, s)` once per tick and `dt_eff == 0` outside Running, so Paused, Hit and Resuming still test as point-in-footprint (level-triggered). OQ16 (one pair per tick vs Godot physics catch-up) is resolved by running in `_process` with no physics step; this story is its device-independent proof. The Android behaviour of `_process` through focus loss is spike PS-1/PS-2 (platform-services epic).

## Out of Scope
- OB-1 cost measurement (Story 014).
- AC-29 (real Camera `VISIBLE_ARC_HALF_WIDTH`) and AC-33 (`REVEAL_BUDGET`), deferred Open Gaps.
- HazardView and Near-Miss wiring rows.

## QA Test Cases
- **AC-25**: Given real BallCore and a `GameRoot` with a fake clock. When a 0.5 s `real_dt` hitch occurs. Then one `Obstacle.test` call with that tick's pair.
- **AC-26**: Given a real window advancing. Then bind/release counts match segment events.
- **AC-27**: Given a hit then a reset. Then the old `run_id` report is discarded; before reset the hazard is still bound.
  - Edge cases: `run_reset` and `window_primed` in either rank-2 order.
- **AC-28**: Given PatternCore. Then identical lifecycle behaviour as with the table provider.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/obstacle_system/obstacle_system_wiring_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 008, 009, 010; composition-root, ball-movement, tube-track, run-state-restart epics; pattern-difficulty epic (AC-28 only)
- Unlocks: Stories 014, 016
