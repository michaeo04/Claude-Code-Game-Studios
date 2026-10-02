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

Approved 2026-10-02. Signatures are typed GDScript and match the GDDs; names the GDDs call "provisional" are fixed here. `@abstract` is GDScript 4.5 (H, NEEDS VERIFICATION); a plain base class is the fallback.

```gdscript
# 1. Run State (Foundation)
class_name RunStateCore extends RefCounted
signal run_reset(run_id: int)
signal run_started(run_id: int)
signal run_paused(source: int)                 # enum PauseSource {BUTTON, BACK, APP_INTERRUPTED, SENSOR_LOST}
signal run_resuming(duration_ms: int)
signal run_resumed(run_id: int)
signal run_ended(run_id: int, hazard_id: int, run_time_ms: int)
signal run_abandoned(run_id: int, run_time_ms: int)
signal restart_unlocked(run_id: int)
signal phase_changed(new_phase: int, old_phase: int)   # enum Phase {BOOT, MENU, RUNNING, PAUSED, RESUMING, HIT}
func tick(world_dt: float, real_dt: float) -> float    # returns dt_eff
func map_ready() -> void
func start_requested() -> void
func hit_reported(hazard_id: int, run_id: int) -> void
func pause_requested(source: int) -> void              # APP_INTERRUPTED applied at once, the rest queued
func resume_requested() -> void
func restart_requested(press_us: int) -> void
func menu_requested(press_us: int) -> void
var phase: int; var run_id: int; var run_time: float   # read-only
# Invariant: a request sent from inside a handler is rejected (no re-entrancy).

# 2. Tube Track and Ball state (Core)
class_name TubeWindow extends RefCounted
signal window_primed(first: int, last: int)
signal segment_entered_window(index: int)
signal segment_left_window(index: int)
signal state_changed(new_state: int, old_state: int)
func load_map(cfg: TubeConfig) -> bool                 # validates; a failure stays Uninitialized
func advance(s: float) -> void                         # one caller (GameRoot), Running only
func begin_run() -> void
func pause() -> void
func resume() -> void
func end_run() -> void
func to_idle() -> void
static func to_world(theta: float, s: float, h: float) -> Vector3   # the ONLY (theta, s, h) to world conversion
static func delta_theta(a: float, b: float) -> float   # canonical; never built-in wrapf()

class_name BallCore extends RefCounted
func step(dt_eff: float, steer: float, valid: bool, input_source: int) -> void
func reset() -> void
func on_resumed() -> void
var theta: float; var theta_prev: float; var s: float; var s_prev: float; var speed: float; var omega: float

# 3. Content seam and gameplay signals
@abstract class_name HazardContentProvider
func hazards_for_segment(segment_index: int) -> Array[HazardSpec]   # once per entering segment, increasing index
signal hit_reported(hazard_id: int, run_id: int)                    # Obstacle (to Run State)
signal hazard_bound(hazard_id: int, footprint_pieces: Array[HazardPiece])
signal hazard_released(hazard_id: int, released_by_reset: bool)
signal near_miss_detected(hazard_id: int, run_id: int)              # Near-Miss to Juice
signal personal_best_updated(final_score: int)                      # Scoring to HUD, Juice, Menus
signal personal_best_passed(personal_best: int)
signal milestone_crossed(threshold: int)                            # no consumer in the MVP

# 4. Persistence and settings
func get_value(section: String, key: String, default: Variant) -> Variant   # type check is typeof(default)
func set_value(section: String, key: String, value: Variant) -> bool        # false on WRITE_FAILED; memory still updated
signal setting_changed(key: String, new_value: Variant)

# 5. Platform Services
signal app_interrupted
signal app_backgrounded
signal app_foregrounded
signal app_returned
signal back_pressed
func haptic(kind: int) -> void                         # enum Haptic {NEAR_MISS, HIT, UI_TAP}
func set_haptics_enabled(on: bool) -> void
func set_haptics_intensity(v: float) -> void           # NEW: the GDD named no setter
func quit() -> void
var attentive: bool; var safe_area: Rect2i; var screen_size: Vector2i; var refresh_rate: float

# 6. Map-load data contract (built by GameRoot at load; consumers never call up)
class_name MapConfig extends Resource
@export var tube: TubeConfig
@export var env: EnvConfig
var rear_extent: float; var camera_distance: float; var visible_arc_half_width: float   # published by Camera at load
```

### Decisions taken (user, 2026-10-02)

- **`HazardSpec` and `HazardPiece` are immutable Resources shared by reference.** They are never mutated at run time, so no per-hazard copy and **no `duplicate_deep()`** (a HIGH risk API) is needed. Per-hazard state (`hazard_id`, `home_segment`) lives in `ObstacleCore` records, not in the spec. The chunk library is `.tres` content authored in the editor.
- **Touch input and `press_us`.** The view stamps `Time.get_ticks_usec()` in the handler, from `InputEventScreenTouch` `pressed` only. `input_devices/pointing/emulate_mouse_from_touch` is turned **off** (a tap would otherwise arrive as touch and mouse) and `emulate_touch_from_mouse` **on** for the editor only. Both settings are **NEEDS VERIFICATION on 4.7.2** (spike).
- **`get_value` type check** uses `typeof(default)`; a stored int is accepted for a float default (for example `tilt_sensitivity` 1 against 1.0) and coerced.

## ADR Audit

Approved 2026-10-02. One ADR exists.

| ADR | Engine Compat | Version | GDD linkage | Conflicts | Valid |
|-----|--------------|---------|-------------|-----------|-------|
| ADR-0001 Android only | upgraded to the template 2026-10-02 | Godot 4.7.2 | upgraded (7 GDDs listed) | none | yes |

**Traceability.** The Technical Requirements Baseline holds about 348 requirements (`docs/architecture/tr-baseline/`). ADR-0001 covers only the platform-scope requirements; the GDDs carry most of their internal decisions, so the real gaps are the **cross-system and engine-dependent decisions that no GDD owns**, listed below. `/architecture-review` turns the baseline into `docs/architecture/tr-registry.yaml` and the full requirement-to-ADR matrix once these ADRs exist.

## Required ADRs

Approved 2026-10-02. Write with `/architecture-decision`. Document conflicts to settle: renderer **Forward+** (technical preferences) versus **Mobile** (Environment Open Question 5); test framework **GUT** (CLAUDE.md, technical preferences) versus **gdUnit4** (some GDDs, CI line).

**Must have before coding starts (Foundation and Core):**

| ADR | Decision | Representative requirements |
|---|---|---|
| ADR-0002 Game loop, Composition Root, tick order | one `_process` in `GameRoot`, `process_mode`/priority, microsecond clock, construction tree, pinned subscriber order, no autoloads | run-state-restart-004/012/017/018/019/024, tilt-input-006/007/014, scoring-personal-best-013/014, ball-movement-005, tube-track-006 |
| ADR-0003 Renderer and tube render route | Forward+ or Mobile for Android; tube route (node per slot, MultiMesh, or scrolling shader); fog depth mode; draw-call budget; Shader Baker; glow policy | tube-track-012/013/021, environment-theming-004/015, juice-feedback-010/011/017, hud-017/018 |
| ADR-0004 Map Loader and MapConfig contract | load sequence, retry, `map_ready` only on success, config published by Camera and Environment at load | run-state-restart-020, tube-track-024, menus-screen-flow-009, camera-016 |
| ADR-0005 Sensor source and input pipeline | `get_gravity()` or accelerometer, ProjectSettings flags, portrait lock, touch emulation, `press_us` stamping | tilt-input-001/016/017, run-state-restart-014, hud-013 |
| ADR-0006 Android integration | lifecycle and threading, Back on SDK 36, haptics, safe area, export manifest, 16 KB pages, OBB | platform-services-003/005/006/012/014 |
| ADR-0007 Persistence implementation | ConfigFile with temp then rename, seam list (file size, backup listing), death-frame write cost, A/B-slot fallback | save-persistence-001..022 |
| ADR-0008 Hazard, collision and content format | immutable `HazardSpec` Resources, `.tres` chunk library, preflight tool owner, cross-chunk spacing hole | obstacle-system-002/009/012, pattern-difficulty-002/021 |
| ADR-0009 Test framework and CI | GUT or gdUnit4, `tools/ci` lint scripts, `godot --headless --import` | every Testing requirement |

**Should have before the relevant system is built:**

| ADR | Decision |
|---|---|
| ADR-0010 Presentation time, hit-stop, Ink cover | real-time effects, FOV ease, cover driven by `phase_changed` (decided in Data Flow) |
| ADR-0011 UI architecture | `CanvasLayer` indices, dp to viewport conversion and stretch mode, view and Control split, AccessKit scope, dual focus |
| ADR-0012 Ball material and world chroma | one owner for `L_ball_adjusted`, how Juice's rim glow layers on it, one chroma uniform |
| ADR-0013 Distance precision | run cap or rebase at s = 16384 (t = 682 s) |

**Can defer to implementation:** OS audio policy owner, AccessKit names and reading order, specific shader techniques.

## Architecture Principles

[To be designed]

## Open Questions

[To be designed]
