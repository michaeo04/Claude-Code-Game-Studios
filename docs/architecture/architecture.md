# Tube Rush (working title): Master Architecture

## Document Status

- Version: 0.1 (in progress, written incrementally by `/create-architecture`)
- Last Updated: 2026-10-02
- Engine: Godot 4.7.2, GDScript; Android only (ADR-0001); review mode `lean`
- GDDs covered: tube-track, run-state-restart, tilt-input, platform-services, ball-movement, obstacle-system, pattern-difficulty, near-miss-detection, scoring-personal-best, save-persistence, settings-accessibility, camera, juice-feedback, environment-theming, hud, menus-screen-flow (16 system GDDs) plus `design/ux/hud.md`, `design/ux/menus-screen-flow.md`, `design/ux/interaction-patterns.md`
- Technical Requirements Baseline: about 348 requirements (`TR-[slug]-[NNN]`) in `docs/architecture/tr-baseline/` (world-movement, gameplay, foundation, presentation-ui)
- ADRs referenced: ADR-0001 (Android only)
- Technical Director Sign-Off: pending
- Lead Programmer Feasibility: skipped (lean mode)

## Engine Knowledge Gap Summary

The LLM's knowledge covers Godot up to about 4.3; the project pins 4.7.2. Every API below that was added or changed after 4.3 is **HIGH RISK** and must be checked against `docs/engine-reference/godot/` (or a device spike) before an ADR relies on it.

| Domain | Risk | What changed after 4.3 | Systems affected |
|---|---|---|---|
| Rendering | HIGH | glow before tonemapping (4.6), shader preprocessor restrictions (4.7), Shader Baker (4.5), fog depth mode verified on Forward+ only (Mobile unverified) | Environment & Theming, Juice, Tube Track |
| UI | HIGH | dual-focus touch/keyboard (4.6), AccessKit screen reader (4.5), recursive Control disable (4.5), Android edge-to-edge | HUD, Menus & Screen Flow |
| Platform / Android | HIGH | lifecycle notifications under Vulkan (`PAUSED/RESUMED` may not fire), Back on Android 16 / SDK 36, 16 KB pages, OBB removed (4.7), safe area and refresh rate | Platform Services, Save & Persistence |
| Input | HIGH | device ID renumbering (4.7), `Input.get_gravity()` on Android, touch emulates mouse by default, sensor flags off in ProjectSettings | Tilt Input, HUD, Menus |
| Particles | HIGH | angular velocity corrected (4.7) | Juice (shard burst) |
| Core / GDScript | HIGH | variadics and `@abstract` (4.5), `duplicate_deep()` (4.5), `FileAccess.store_*` returns `bool` (4.4), signal argument coercion, `class_name` needs a class cache, `wrapf` collapses PI | all (`Core` classes), Save, Obstacle, Scoring |
| Physics | MEDIUM | Jolt default (4.6); collision here is analytic, so exposure is low | Obstacle System |
| Storage | MEDIUM | `ConfigFile`, `FileAccess`, `DirAccess` behaviour unverified on 4.7.2 | Save & Persistence |
| Camera, RNG, Animation, Navigation, Networking | LOW or unused | none material | Camera, Pattern |

## System Layer Map

Approved 2026-10-02.

```
┌─────────────────────────────────────────────────────────────────┐
│ PRESENTATION   Camera · Environment & Theming · Juice & Feedback│
│                HUD · Menus & Screen Flow                        │
├─────────────────────────────────────────────────────────────────┤
│ FEATURE        Pattern & Difficulty · Near-Miss Detection ·     │
│                Scoring & Personal Best                          │
├─────────────────────────────────────────────────────────────────┤
│ CORE           Tube Track · Tilt Input · Ball Movement ·        │
│                Obstacle System                                  │
├─────────────────────────────────────────────────────────────────┤
│ FOUNDATION     Run State & Restart · Platform Services ·        │
│                Save & Persistence · Settings & Accessibility ·  │
│                Composition Root · Map Loader                    │
├─────────────────────────────────────────────────────────────────┤
│ PLATFORM       Godot 4.7.2: Input, DisplayServer, OS lifecycle, │
│                Camera3D, Environment, GPUParticles3D,           │
│                CanvasLayer/Control, ConfigFile/FileAccess       │
└─────────────────────────────────────────────────────────────────┘
```

Decisions taken while mapping (user, 2026-10-02):

1. **Dependencies point downward only.** Tube Track and Obstacle System (Core) need values owned by Camera and Environment & Theming (Presentation): `rear_extent`, `camera_distance`, `VISIBLE_ARC_HALF_WIDTH`, fog and `F_read`. These travel as **configuration published at map load** (a MapConfig / derived-config data contract in Foundation that the Composition Root passes to the consumers), never as a runtime call from Core up to Presentation.
2. **Two modules have no GDD and are defined here, with ADRs, not new GDDs:** the **Composition Root / Game Loop** (owns construction order, the per-frame tick order, the pinned subscriber order, `process_mode` and `process_priority`) and the **Map Loader** (calls Tube Track `load_map`, sends `map_ready` to Run State only on success, retries on request). They hold no game rules. A row is added to `design/gdd/systems-index.md` for each.
3. **Settings & Accessibility sits in Foundation** (it stores preferences and depends only on Save & Persistence); its consumers read it by getter plus `setting_changed`.

## Module Ownership

Approved 2026-10-02. Engine risk tags: **H** = post-cutoff, HIGH risk; M = medium; L = low. Every H API is **NEEDS VERIFICATION** (not covered by `docs/engine-reference/godot/modules/`, which only reaches 4.6 for Input, Physics, Rendering and UI) and becomes a spike or an ADR check.

**Standard module shape.** Every system is `XCore` (RefCounted, no engine calls) + `XMath` (static pure functions) + `XConfig` (Resource with `validated(log_sink)`) + one thin driver or view Node, the only place that touches the engine. Dependencies enter through injected seams (Callables) and signals, never through autoloads.

### Foundation

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| **Composition Root** (`GameRoot`, scene root, no autoload) | construction order, the single tick driver (`_process`), the pinned subscriber order, the injected clock, MapConfig distribution, composition-time preflight | nothing (wires only) | everything | `Node`, `process_mode`/`process_priority` (L), `Time.get_ticks_usec` (L) |
| **Run State & Restart** | phase, `run_id`, run clock, request queue | `tick(world_dt, real_dt)`, the requests, 9 signals | injected clock, log_sink | none |
| **Platform Services** | every OS call, lifecycle state, ProjectSettings manifest | 5 signals, `haptic(kind)`, `quit()`, safe area and refresh getters | `haptics_*` settings | `_notification` FOCUS_IN/OUT, PAUSED/RESUMED, `WM_GO_BACK_REQUEST` (H); `DisplayServer` safe area, refresh, keep_on (H); `Input.vibrate_handheld` (M) |
| **Save & Persistence** | `user://save.cfg`, schema, atomic write | `get_value`, `set_value` | `app_backgrounded` | `ConfigFile` (M), `FileAccess` (H, 4.4), `DirAccess` (M) |
| **Settings & Accessibility** | the 5 settings in memory | 6 getters, `set_value`, `setting_changed` | Save | none |
| **Map Loader** | the load and retry sequence | `retry()` | MapConfig, Tube Track | `ResourceLoader` (not chosen yet) |

### Core

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| **Tube Track** | frame `(theta, s, h)`, segment window, seam, map validation | `advance(s)`, `load_map`, `begin_run`, `P`, `delta_theta`; signals `window_primed`, `segment_entered/left_window` | `s`, MapConfig, `seam_contrast_scale` (every frame), Run State events via its adapter | `Node3D`, `MeshInstance3D`/MultiMesh, ShaderMaterial, Environment fog (H) |
| **Tilt Input** | sensor reading, neutral, `steer`, `valid` | `steer`/`valid`/`input_source` getters, `poll()` | Run State events, lifecycle, sensitivity | `Input.get_gravity()` (H), ProjectSettings sensor flags (H) |
| **Ball Movement** | ball state, speed curve | `step()`, `theta/theta_prev/s/s_prev/speed/omega` | steer, `dt_eff`, `wrap_angle` | view only: `Node3D` |
| **Obstacle System** | hazard instances, analytic collision, preflight | `hit_reported`, `hazard_bound`, `hazard_released(id, released_by_reset)` | ball state, Tube Track window signals, `VISIBLE_ARC_HALF_WIDTH` (config), Pattern provider | `Resource` HazardSpec, `duplicate_deep` (H) |

### Feature

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| **Pattern & Difficulty** | chunks, tier, bag and PRNG, read history | `hazards_for_segment(int)`, `t_dodge_worst` | `run_id`, `run_time`, Ball and Tube constants | `RandomNumberGenerator` (L, explicit seed) |
| **Near-Miss Detection** | near zone and per-hazard state | `near_miss_detected(hazard_id, run_id)` | ball state, the 3 Obstacle signals | none |
| **Scoring & Personal Best** | `current_score`, `personal_best` | getters, `personal_best_updated/passed`, `milestone_crossed` | `s`, Run State, Save | `Callable.is_valid` (L), script reflection (H, unverified) |

### Presentation

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| **Camera** | camera pose, `d_cam`, `VISIBLE_ARC_HALF_WIDTH`, FOV punch | `step`, `apply_fov_punch`; config `rear_extent`, `camera_distance`, visible arc | `theta`, `s`, `R`, `P`, Run State events | `Camera3D` fov, look_at (M) |
| **Environment & Theming** | palette, fog, ball material, plinth, `L_ball_adjusted` | fog and colour fields in MapConfig (at load) | `speed`, `colorblind_safe_enabled` + `setting_changed`, `R` | `WorldEnvironment` fog and glow (H), spatial shader (H), MultiMesh |
| **Juice & Feedback** | the two presentation tracks, run-end latch, flash ledger | none (calls Camera and Platform) | `near_miss_detected`, `run_ended/abandoned/reset`, `personal_best_updated`, hazard lookup | `GPUParticles3D` (H), shader (H), CanvasLayer, AudioStreamPlayer |
| **HUD** | display state, was-Live latch, banner | `snapshot()`, 3 requests to Run State | score pull, Run State events, `valid`/`state`, safe area | CanvasLayer, Control, `InputEventScreenTouch` (H, emulation), AccessKit (H) |
| **Menus & Screen Flow** | active screen, overlay flags, `transition_covering` | display-state snapshot, 7 outbound calls | phase, `valid`/`state`/`input_source`, `personal_best`, Settings getters, `back_pressed` | CanvasLayer, Control, ScrollContainer, AccessKit (H) |

### Dependency diagram

```
PRESENTATION   Camera  Env  Juice  HUD  Menus
                  ^      ^     ^     ^     ^          (read downward: state and events)
FEATURE        Pattern  Near-Miss  Scoring
                  ^        ^         ^
CORE           Tube Track  Tilt  Ball  Obstacle --- hit_reported ---+
                  ^          ^     ^      ^                         v
FOUNDATION     Run State  Platform  Save  Settings  Map Loader  <- Composition Root (wires all)
PLATFORM       Godot 4.7.2

Controlled exception: MapConfig (Camera and Environment to Tube Track and Obstacle) is loaded once at map load.
```

## Data Flow

Approved 2026-10-02.

**Conventions.** There is no global event bus. Systems talk through (a) direct signals connected immediately (never `CONNECT_DEFERRED`, whose handlers run after `emit()` returns and escape every re-entrancy guard), registered by the Composition Root in the pinned order; (b) per-tick pull seams (HUD, Menus and Scoring read state); (c) requests queued into Run State and applied at its next tick. Nothing crosses a thread boundary, **except** that Android lifecycle callbacks may arrive on another thread (UNVERIFIED, Platform Services PS-12, H): if the spike confirms it, Platform Services defers them to the main thread with `call_deferred`.

### 1. Frame update path

One tick driver: `GameRoot._process`. `real_dt` comes from the injected microsecond clock (`Time.get_ticks_usec`), never from the engine delta (which is `time_scale`-scaled and capped at about 0.133 s). No system uses `_physics_process`.

```
GameRoot._process(engine_delta)
 1  TiltInput.poll()                       sensor -> steer, valid
 2  TiltRunAdapter.flush()                 valid false in Running/Resuming -> pause_requested(sensor_lost)
 3  RunState.tick(world_dt, real_dt)       -> dt_eff (0 in Hit, Paused, Resuming and on settling ticks)
 4  Ball.step(dt_eff, steer, valid, src)   -> theta, s (and the previous pair)
 5  TubeTrack.advance(s)   [Running only]  -> segment_left/entered -> Obstacle (calls Pattern.hazards_for_segment)
 6  Obstacle.test(prev -> current)         -> hit_reported (queued into Run State, level-triggered every tick)
 7  NearMiss.step()                        runs AFTER Obstacle so that hit_reported is applied before the exit-edge check
 8  Scoring.step()                         current_score = floori(s)
 9  Camera.step(theta, s, dt_eff)          pose; FOV ease on real time
10  Environment.tick(speed)                fog end and chroma
11  Juice.tick(real_dt) / HUD.tick / Menus.tick    pull seams, then draw
```

### 2. Event path

Pinned subscriber order (owned by Run State, registered by the Composition Root, one list that every GDD cites):

| Event | Order |
|---|---|
| `run_reset` | 1 Pattern & Difficulty; 2 Tube Track adapter and Obstacle (either order; Obstacle only captures `run_id`); 3 Ball Movement; 4 Camera; 5 everything else |
| `run_ended` | 1 Juice; 2 Scoring (emits `personal_best_updated` inside its handler); 3 HUD; 4 everything else |
| `run_abandoned` | 1 Juice (latches `Abandon`); 2 Scoring; 3 everything else |

Death sequence: Obstacle `hit_reported` (tick N) -> Run State processes it at tick N+1 -> `run_ended` -> (Juice latch `Hit`) -> Scoring finalizes, writes the best, emits `personal_best_updated` -> HUD freezes the score -> `phase_changed` last.

### 3. Save and load path

`SaveService` is the only code that does file I/O. Boot: synchronous load of `user://save.cfg`, finished before Scoring and Settings are built; no "loaded" signal. Scoring writes `personal_best` synchronously inside its `run_ended`/`run_abandoned` handler (a file under 1 KB, temp file then rename); Settings writes on every change; `app_backgrounded` is a redundant safety flush. An in-progress run is never saved. Crash safety covers process kill only (spike SP-1), not power loss. The cost of the write on the death frame is an open risk (see Open Questions).

### 4. Initialisation order

1. `PlatformServices` (node and core; clock, display source, keep-screen-on, ProjectSettings check)
2. `SaveService` (load; connect `app_backgrounded`)
3. `SettingsCore` (read the 5 keys; push `haptics_*` to Platform Services)
4. `RunStateCore` and `ScoreService` (construction emits nothing)
5. every other system registers its handlers in the pinned order of section 2
6. `MapLoader` calls Tube Track `load_map`; only on success it sends `map_ready` (Boot to Menu)
7. `GameRoot._process` starts ticking

### Decisions taken (user, 2026-10-02)

- **Tick domain:** a single `_process` in `GameRoot` drives every system in the fixed order above; analytic collision needs no physics step.
- **Presentation clock:** hit-stop is a 0.20 s hold of effects on **real time**, no `Engine.time_scale` and no tree pause; the world is already frozen by `dt_eff = 0`. FOV punch, shards and the flash ledger run on `real_dt`.
- **Ink cut:** a cover layer driven by `phase_changed` (to or from Menu and Running): it turns opaque on the transition tick (hiding the seam jump) and fades out over about 180 ms. Every route into Menu or Running gets the cut, including HUD's Menu button and Back. **This differs from `design/ux/menus-screen-flow.md` (fade-in before the phase change) and `menus-screen-flow.md` Core Rule 9 wording; both need a follow-up edit.**

## API Boundaries

[To be designed]

## ADR Audit

[To be designed]

## Required ADRs

[To be designed]

## Architecture Principles

[To be designed]

## Open Questions

[To be designed]
