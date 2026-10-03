# ADR-0002: Game loop, Composition Root and tick order

## Status

Proposed

## Date

2026-10-02

## Last Verified

2026-10-02

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

Eight GDDs defer "who owns the tick, the construction order and the handler order" to a game-loop ADR that did not exist. This ADR makes one scene-root node, `GameRoot`, the Composition Root and the **only** node that runs a per-frame `_process`; it calls every system in one fixed order, builds them in one fixed order, and registers the pinned subscriber order from one data table. No autoloads.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting, timing) |
| **Knowledge Risk** | LOW for the APIs used (`Node._process`, `process_mode`, `Time.get_ticks_usec`, `Signal.connect`); MEDIUM for behaviors not covered by the engine reference (connection order, `_process` while unfocused, clock across sleep) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` (GDScript gotchas verified on 4.7.2) |
| **Post-Cutoff APIs Used** | None. `@abstract` (4.5) is optional for interfaces and not required by this ADR |
| **Verification Required** | **Verified by the engine reference** (`current-best-practices.md`, binary 4.7.2): `CONNECT_DEFERRED` handlers run after `emit()` returns; signal argument coercion depends on the handler's typing; lambdas capture primitives by value; `class_name` needs the class cache. **NEEDS VERIFICATION, not in the reference:** (1) handlers run in connection order (Run State AC-30 spy test on 4.7.2, including a handler that is disconnected and reconnected); (2) on Android, whether `_process` keeps running through FOCUS_OUT / FOCUS_IN or while backgrounded (spikes PS-1, PS-2, device); (3) whether `Time.get_ticks_usec()` stands still across deep sleep (Run State Open Question 5, device); (4) the behavior of `Tween`, `AnimationPlayer`, `GPUParticles3D` and shader time while `dt_eff = 0` (ADR-0010, device) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Android only; the lifecycle model assumes it) |
| **Enables** | ADR-0003 (render route), ADR-0004 (Map Loader), ADR-0005 (input pipeline), ADR-0007 (persistence), ADR-0009 (test framework), ADR-0010 (presentation time) |
| **Blocks** | Every epic (Foundation layer) |
| **Ordering Note** | Should be Accepted first among the Foundation ADRs |

## Context

### Problem Statement

Run State, Tilt Input, Ball Movement, Obstacle System, Scoring, Save & Persistence, Settings and the HUD each state a tick-order or construction-order requirement and name the "game-loop ADR" as its owner. Without one decision, each system would pick its own callback (`_process` or `_physics_process`), its own `process_priority`, and its own `connect()` site, and cross-system orderings (Pattern reseeds before Tube Track primes; Juice latches before Scoring emits; Obstacle reports before Near-Miss reads) would depend on scene-tree accident.

### Constraints

- 60 FPS target, 16.6 ms; mid-tier Android; Android only.
- The engine delta is scaled by `time_scale` and capped near 0.133 s, so Run State needs its own real clock (Run State Core Rule 3).
- Tilt Input must poll once per rendered frame in every phase, including Paused, and before Ball Movement steps (Tilt Input rule 6).
- Obstacle's swept hit test must run in the same tick domain as Ball Movement's publish (Obstacle Core Rule 2), with no physics catch-up.
- Handlers must not send requests, must not `await` in `run_reset`, and must be connected without `CONNECT_DEFERRED` (Run State rules 3 and 4).
- Core logic classes (`XCore`) are RefCounted with no engine calls and are tested headless with GUT.
- `Time.get_ticks_usec()` is the OS monotonic clock and ignores the engine's delta cap: reading it directly is a deliberate choice, not an accident.

### Requirements

- One owner of the tick, one construction order, one subscriber order, all testable by spy.
- No autoload, no global event bus.
- Pause, Hit and Resuming freeze the world through `dt_eff = 0`, not through `SceneTree.paused` or `Engine.time_scale`.

## Decision

`GameRoot` is the scene-root `Node` (`class_name GameRoot`). It is the Composition Root and the only node that runs `_process` for game logic.

1. **Single tick driver.** `GameRoot._process(_engine_delta)` ignores the engine delta. It reads the injected clock, computes `real_dt = (now_us - prev_us) / 1e6` (raw, unclamped, because Run State's stall guard needs the raw value) and `world_dt = real_dt` (`time_scale` is never changed; a lint bans writes to `Engine.time_scale`). `process_mode = PROCESS_MODE_ALWAYS` (set in the scene file; redundant while `SceneTree.paused` is never used, kept as a guard against future pausing). Every view Node (Camera3D rig, Tube Track view, ball view, HUD, Menus, Environment) sets `set_process(false)` and `set_physics_process(false)` and is driven by method calls from `GameRoot`. Engine-driven effects (Tween, GPUParticles3D, shaders) are allowed but never read game state.
2. **No autoloads.** Systems are constructed and owned by `GameRoot`.
3. **No `_physics_process`** in any game-logic code.
4. **Clock.** One `clock_us: Callable` wrapping `Time.get_ticks_usec()` is injected into every system that needs time. Cores never call `Time.`.
5. **Construction order** (each step finishes before the next): `PlatformServices`, `SaveService` (synchronous load, connect `app_backgrounded`), `SettingsCore` (push `haptics_*` to Platform Services), `RunStateCore` and `ScoreService` (construction emits nothing), the immutable `WorldGeometry` (ADR-0004) and `WorldFrame` (ADR-0013), validated together before any view is built (`REBASE_Z_EXCEEDS_BUDGET` is fatal), every other system in this order (ADR-0012 Decision 4, ADR-0014 Decision 5: the Environment view, `WorldChroma`, `BallView`, `HazardView`, Environment, Juice, then the HUD and Menus views), then `wire()`, then `MapLoader` calls `load_map` and sends `map_ready` on success, then the loop starts.
6. **Per-frame order** (fixed): `TiltInput.poll`, `TiltRunAdapter.flush`, `RunState.tick`, `Ball.step`, `TubeTrack.advance` (Running only), `WorldFrame step` (ADR-0013: `maybe_rebase(s)`, then `TubeView.rebase()` and `HazardView.rebase()` when it returns true; Running only, so Pause, Hit and Resuming never rebase), `Obstacle.test`, `NearMiss.step`, `Scoring.step`, `TubeView.idle_step(real_dt)` (only when the phase is Menu, which is Tube Track's Idle state; Paused, Hit and Resuming keep the tube still (Tube Track States), so the menu tube idles without a view `_process`), `Camera.step`, `BallView.tick` (ADR-0012 Decision 1), `Environment.tick` (Idle and Menu resting values included), then `Juice.tick`, `HUD.tick`, `Menus.tick` (pull seams, then draw). Other documents cite these steps by name, not by number, because the numbers shift when a step is inserted (ADR-0010, ADR-0011).
7. **Pinned subscriber order from one table of Callables.** `GameRoot._wire()` builds an array of rows `[signal: Signal, handler: Callable, rank: int]` (typed handlers are mandatory, because signal arguments are coerced to the handler's declared types), sorts by rank with the row index as the tie-break (the sort is not stable), and calls `signal.connect(handler)` in that order. Immediate connections only; `CONNECT_ONE_SHOT` is allowed only on connections outside the table. The signals are declared on the owning core (`RunStateCore` declares `run_reset`, `run_ended`, `run_abandoned`); `GameRoot` holds a strong reference to every core for the whole session (a connection does not keep a RefCounted alive). The ranks are the ones Run State owns: `run_reset` (Pattern and `WorldFrame` (ADR-0013), tie broken by row order; Tube Track adapter and Obstacle, tie broken by row order; Ball; Camera; the rest), `run_ended` (Juice; Scoring; HUD; the rest), `run_abandoned` (Juice; Scoring; the rest).
8. **Pause model.** `GameRoot` keeps ticking in every phase; Run State returns `dt_eff = 0` outside Running. `SceneTree.paused` is never used.
9. **Android focus and resume gap.** Platform Services turns `NOTIFICATION_APPLICATION_FOCUS_OUT` into `app_interrupted`, applied by Run State when sent: this is the **primary** pause signal (which PAUSED/RESUMED notifications Platform Services also reads is ADR-0006's decision). Run State's stall guard is only the **backup**: if the engine stops calling `_process` while unfocused, the first tick after return produces a large `real_dt` and the guard pauses the run. Because `CLOCK_MONOTONIC` may stand still during deep sleep, the gap can read as small and the guard then does not fire; the focus notification is what protects that case.
10. **Presentation time.** Tween, AnimationPlayer, GPUParticles3D and shader time are engine-driven and keep advancing while `dt_eff = 0` (Pause, Hit, Resuming). That is intended and decided in ADR-0010; no game state may be read from them.

### Architecture Diagram

```
                     GameRoot (scene root, PROCESS_MODE_ALWAYS, only _process)
                       |  clock_us, _wire() rows, MapConfig
   ┌───────────────────┼─────────────────────────────────────────────────────────┐
   | construct:  Platform -> Save -> Settings -> RunState+Score -> others -> _wire() -> MapLoader
   | per frame:  Tilt.poll -> flush -> RunState.tick -> Ball.step -> Tube.advance -> WorldFrame.step -> Obstacle.test
   |             -> NearMiss.step -> Scoring.step -> Tube.idle_step -> Camera.step -> BallView.tick -> Env.tick -> Juice/HUD/Menus.tick
   └─────────────────────────────────────────────────────────────────────────────┘
   view Nodes: set_process(false); engine-driven Tween/particles/shaders read no game state
```

### Key Interfaces

```gdscript
class_name GameRoot extends Node

var _rows: Array = []   # rows of [Signal, Callable, rank: int], built in _wire()

func _ready() -> void:
    _construct()    # fixed order, each step finishes; GameRoot keeps a strong ref to every core
    _wire()         # build _rows, sort by (rank, row index), connect() in that order
    _map_loader.start()

func _wire() -> void:
    _rows = [
        [_run_state.run_reset, _pattern.on_run_reset, 1],
        [_run_state.run_reset, _tube_adapter.on_run_reset, 2],
        [_run_state.run_reset, _obstacle.on_run_reset, 2],
        [_run_state.run_reset, _ball.on_run_reset, 3],
        [_run_state.run_reset, _camera.on_run_reset, 4],
        # rank 5 handlers, then the run_ended and run_abandoned rows
    ]
    # sort by rank, row index as tie-break; then for each row: row[0].connect(row[1])

func _process(_engine_delta: float) -> void:
    var now_us: int = clock_us.call()
    var real_dt: float = float(now_us - _prev_us) / 1e6
    _prev_us = now_us
    _tick(real_dt, real_dt)   # world_dt == real_dt; the fixed per-frame order lives in _tick()
```

### Implementation Guidelines

- `_tick()` is the only place the per-frame order is written; a spy test records the call log.
- A lint rejects `_process`/`_physics_process` overrides outside `GameRoot`, `autoload` entries, `CONNECT_DEFERRED` on control signals, and `Engine.time_scale` writes.
- A handler that needs state from another system reads it by accessor after that system's step in the same tick; it never calls a mutating method of another system.
- A system added later gets one row in the `_wire()` rows and one line in `_tick()`.

## Alternatives Considered

### Alternative 1: Each system's Node runs its own `_process` with `process_priority`

- **Description**: Godot's priority decides the order.
- **Pros**: little wiring code.
- **Cons**: order lives in numbers scattered across scenes; hard to pin and to test; instance order breaks ties.
- **Rejection Reason**: the orderings are correctness requirements (Pattern before Tube Track, Juice before Scoring).

### Alternative 2: Autoload singletons and a global event bus

- **Description**: `RunState`, `Scoring` and others as autoloads; a bus for events.
- **Pros**: easy access from anywhere.
- **Cons**: hidden coupling, no explicit construction order, hard to inject test doubles, contradicts the injected-seam design of every GDD.
- **Rejection Reason**: GDDs (Scoring AC lint, Menus, HUD) already forbid autoloads.

### Alternative 3: `_physics_process` with a fixed timestep

- **Description**: tick all systems at the physics rate.
- **Pros**: reproducible step size.
- **Cons**: sensor polling and input drift against render frames; the engine may run several physics steps in one frame; contradicts Tilt Input rule 6 and Run State's owner contract.
- **Rejection Reason**: analytic collision needs no physics step, and polling per rendered frame is required.

## Consequences

### Positive

- One readable place for every ordering; spy-testable; GDD ordering requirements become ACs.
- No hidden tick or singleton; systems are testable headless.

### Negative

- `GameRoot` knows every system (a deliberate god-object for wiring only; it holds no rules).
- Adding a system needs two edits (a row in `_wire()` and a line in `_tick()`).
- One main-thread tick: if rendering drops below 60 FPS every system's step slows with it, because there is no fixed-step catch-up (accepted by design).
- `real_dt` equals the rendered-frame interval, so it follows the display refresh rate (60, 90 or 120 Hz), vsync and `Engine.max_fps`; tuning must not assume 16.6 ms.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| `_process` stops or stutters while unfocused on some Android makers | Medium | Medium | stall guard; spikes PS-1 and PS-2 |
| `connect()` order differs from call order for the pinned list | Low | High | Run State AC-30 spy test on 4.7.2 |
| `Time.get_ticks_usec()` stands still during deep sleep, so a long sleep can read as a small gap and the stall guard does not fire | Medium | Medium | the FOCUS_OUT notification is the primary pause signal (decision 9); Run State Open Question 5; device test |
| `real_dt` depends on refresh rate and vsync (60, 90, 120 Hz) | Medium | Medium | Platform Services `max_fps` 60 cap (UNVERIFIED on 120 Hz, PS-9); do not assume 16.6 ms in tuning; test at 60 and 120 Hz |
| Tween, particles and shader time keep running while `dt_eff = 0` and could read or imply state | Low | Low | no game state read from them; ADR-0010 decides which effects freeze |
| A Callable on a freed core is invalid (not a crash) and a freed emitter disconnects silently | Low | High | `GameRoot` keeps strong references to every core for the session; a test asserts no row Callable is invalid after `_wire()` |
| `GameRoot` grows into a logic holder | Medium | Medium | principle 1; a lint on rule keywords; code review |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | n/a | orchestration under 0.1 ms (a dozen method calls); simulation steps 1 to 10 provisional 3 ms | 16.6 ms frame (provisional figure, measured in the first playable) |
| Memory | n/a | negligible | 512 MB |
| Load Time | n/a | construction is synchronous and small | n/a |

## Migration Plan

Greenfield: no code exists. Create `GameRoot` first; each system story adds its construction line, its table rows and its `_tick()` call.

**Rollback plan**: supersede with an ADR that picks per-node ticking; the cores and seams do not change.

## Validation Criteria

- [ ] Run State AC-30 passes against the real `GameRoot._wire()` table.
- [ ] A spy test asserts the per-frame order of section 6, including `WorldFrame step` right after `TubeTrack.advance` (no rebase in Pause, Hit or Resuming), `TubeView.idle_step` (called only in Menu, never in Paused, Hit or Resuming) and `BallView.tick` right after `Camera.step`, and the construction order of section 5.
- [ ] CI lint finds no `_process`/`_physics_process` outside `GameRoot`, no autoload entry, no `CONNECT_DEFERRED`, no `Engine.time_scale` write.
- [ ] A 10-minute run on a mid-tier Android phone shows no dropped frames attributable to orchestration, at 60 Hz and on a 120 Hz device (vsync mode and refresh rate recorded).
- [ ] `godot --headless --import` runs before the GUT run (the class cache for `class_name GameRoot` and the cores).
- [ ] After `_wire()`, every row Callable is valid and the connect order equals the table order, including after a disconnect and reconnect.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/run-state-restart.md` | Run State | owner contract: `tick` in `_process`, `process_mode` ALWAYS, `real_dt` from the clock; pinned subscriber order; construction emits nothing (CR15) | single `_process`, clock-based `real_dt`, `_wire()` rows, construction order |
| `design/gdd/tilt-input.md` | Tilt Input | poll once per rendered frame in every phase, before Ball Movement (rule 6) | step 1 of the fixed order, `PROCESS_MODE_ALWAYS` |
| `design/gdd/ball-movement.md` | Ball Movement | step once per rendered frame after Run State tick (rule 2) | step 4 |
| `design/gdd/obstacle-system.md` | Obstacle System | hit test once per published pair in the same tick domain (CR2) | step 6 in the same `_process` |
| `design/gdd/scoring-personal-best.md` | Scoring | step after Ball Movement; connect before Run State emits; no autoload (CR11) | step 8, construction order, no autoload |
| `design/gdd/save-persistence.md` | Save & Persistence | synchronous load before Scoring and Settings are built (CR4) | construction order steps 2 to 4 |
| `design/gdd/settings-accessibility.md` | Settings | constructed after Save, before consumers read it | construction step 3 |
| `design/gdd/platform-services.md` | Platform Services | created early, no autoload; consumers read state on connect | construction step 1 |
| `design/gdd/hud.md`, `design/gdd/juice-feedback.md` | HUD, Juice | `tick` after `ScoreService.step()`; Juice `run_ended` handler first | steps 8 and 11, `_wire()` rows |

## Related

- `docs/architecture/architecture.md` (Data Flow, Module Ownership)
- ADR-0001 (Android only); ADR-0004, ADR-0005, ADR-0010
