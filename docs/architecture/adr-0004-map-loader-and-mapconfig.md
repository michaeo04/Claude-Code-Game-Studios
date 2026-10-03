# ADR-0004: Map Loader and MapConfig

## Status

Accepted (2026-10-03)

## Date

2026-10-02

## Last Verified

2026-10-02

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

Run State, Tube Track and Menus all rely on a **map loader** that has no GDD: it must load the map, hand each Core system the values it needs from Camera and Environment & Theming (without Core calling up), validate, call Tube Track `load_map`, send `map_ready` only on success, and support Retry. This ADR defines it. An authored `MapDefinition` resource (`.tres`) holds the Environment values and the chunk library; `GameRoot` derives the three Camera values with pure `CameraMath`, and the `MapLoader` builds an immutable `MapConfig`, **validates everything before applying anything**, applies it in a fixed order with Tube Track last, and then calls `map_ready`. A failure emits `map_load_failed(codes)` at once, so the Menus failure screen no longer waits for the timeout. The load is synchronous, in one frame at boot (and again on Retry). The Godot specialist found no blocker; its notes are folded in below.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (resource loading) |
| **Knowledge Risk** | MEDIUM: the engine reference has no module for `ResourceLoader`; export behavior of `.tres` files and typed exported resources on Android is unverified |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `design/gdd/tube-track.md`, `run-state-restart.md`, `menus-screen-flow.md`, `camera.md`, `environment-theming.md` |
| **Post-Cutoff APIs Used** | None. `ResourceLoader.load`, `ResourceLoader.exists`, `Resource.duplicate` (shallow) all predate the cutoff; `duplicate_deep()` (4.5) is **not** used |
| **Verification Required** | **NEEDS VERIFICATION, none of it in the reference:** (1) that `ResourceLoader.load("res://.../map_01.tres")` works in an Android export, where text resources are converted to binary and reached through a remap (so the file is never opened with `FileAccess` or listed with `DirAccess`); (2) the name and effect of the cache modes that force a re-read: `ResourceLoader.CACHE_MODE_IGNORE` does not carry into external sub-resources, `CACHE_MODE_IGNORE_DEEP` may exist for that (confirm both in the 4.7 class reference); a Retry re-read has low value because a failure is deterministic, so this stays low priority; (3) that a missing or corrupt resource returns `null` (with an engine error) and does not crash, and that `as MapDefinition` yields `null` for a wrong type; (4) that typed exported properties (`@export var env: EnvConfig`) round-trip in an export, which needs the `class_name` cache (see `architecture.md`); (5) that `Resource.duplicate()` is shallow and enough for a scalar-only `TubeConfig`, and how a `.tres` coerces an `int` written into a `float` field (declare floats and write `1.0` in the file); (6) the load, validate and prime time on a mid-tier phone (spike MS-1) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (construction order, `MapLoader` runs after `_wire()`, no autoload), ADR-0003 (the fog fields, the tube meshes created at `load_map`) |
| **Enables** | ADR-0008 (the `chunk_library` field and the `ChunkLibrary` type), the Tube Track, Camera, Environment and Menus epics |
| **Blocks** | Map Loader epic (new, no GDD); first playable (MS-1 is a measurement, not a blocker) |
| **Ordering Note** | ADR-0008 must replace the placeholder type of `MapDefinition.chunk_library` before the Pattern epic starts |

## Context

### Problem Statement

Tube Track and Obstacle (Core) need values owned by Camera and Environment (Presentation); the architecture forbids Core calling up, so these travel as configuration at map load. Run State leaves Boot only on `map_ready`, Tube Track accepts `load_map` only from Uninitialized and allows Retry, and Menus shows a failure screen with Retry. Nothing defines who assembles that configuration, in what order it is validated and applied, what a failure looks like to Menus, or how Retry behaves. Pattern & Difficulty also needs a field that selects the chunk library, which no document names.

### Constraints

- Dependencies point down only; the only upward data is load-time configuration (architecture principle).
- No autoload; `GameRoot` owns construction and wiring (ADR-0002); `MapLoader` runs after `_wire()` and before the first `_process`.
- Every owner keeps its own fields and validation (`EnvConfig` owns the fog and color fields, `TubeConfig.validate()` owns the Tube Track derived constraints, Camera owns its geometry).
- `HazardSpec`, `HazardPiece` and the chunk library are immutable shared resources, never copied (architecture Phase 4).
- Run State and Tube Track contracts are fixed: `map_ready` only after a successful `load_map`; a failed load keeps Boot and Uninitialized with no events; Retry is accepted.

### Requirements

- One immutable object carries everything a map gives the Core systems.
- All validation happens **before** any system is configured; a failed load leaves no half-applied state that matters.
- A failure reaches the player at once with a plain-language screen; Retry works.
- The whole loader is testable with no engine calls.

## Decision

### 1. Data: `MapDefinition`, `MapConfig`

```text
MapDefinition (Resource, .tres, authored)        assets/data/maps/map_01.tres
   map_id: StringName
   env: EnvConfig                 owns seam_pattern_id, fog_mode, fog_depth_begin, fog_end_distance (F),
                                  fog_depth_curve, fog_density, fog_color, readable_distance (F_read),
                                  tube_color, sky_top_color, sky_bottom_color, prop_set_id
   chunk_library: Resource        typed as ChunkLibrary by ADR-0008 (placeholder type until then)

MapConfig (RefCounted, built at load, read-only after build)
   map_id, env (the validated, clamped copy), chunk_library (the shared resource, never copied)
   rear_extent, camera_distance, visible_arc_half_width     derived by CameraMath, see below
```

- Per-run and per-build knobs (`TubeConfig` A, N, B and the rest, `CameraConfig`, `PatternConfig`) stay in their own `.tres` files; a map contributes only what varies per map.
- **Camera values** (`rear_extent`, `camera_distance`, `visible_arc_half_width`) are pure functions of `CameraConfig` and the immutable `WorldGeometry` value (`R`, `D`, `N_F`, `L`, plus `OMEGA_MAX` from `BallConfig`; `CameraMath.published`, static; `camera_far` is not among them: it depends on the map's resting fog end and is derived in Phase A step A5). `WorldGeometry` is built once by `GameRoot` at composition from the base `TubeConfig` and `BallConfig` (so `D` has one owner, Ball Movement, and `TubeConfig` gains no copy of it) and is validated before the first `MapLoader.attempt`. `camera_distance` is the derived worst case (about 7.84), not a hand-copied 8, so a retune of `D` or `OMEGA_MAX` cannot silently invert Camera F9. `GameRoot` calls `CameraMath.published` at composition and passes the result to the loader, so no Camera node or instance is consulted and nothing flows up. They are published "at map load" in the sense that `MapConfig` carries them.
- `TubeConfig.from_map(base: TubeConfig, map: MapConfig) -> TubeConfig` returns a `base.duplicate()` (shallow; the config holds scalars only) with the map-supplied fields set (the fog, seam and `readable_distance` fields from `map.env`, `rear_extent`, `camera_distance`). The cached resources are never mutated.
- `EnvConfig.validated(log_sink)` returns a clamped **copy**; the loaded resource, which `ResourceLoader` may cache and share, is never written.
- **Dependency rules:** the graph is `MapDefinition -> EnvConfig` with no back-edge (`EnvConfig` never references `MapDefinition` or `MapConfig`); `MapConfig` is never an `@export` type; every `@export` field of `EnvConfig` and `TubeConfig` is a scalar, an enum or a `Color`. A unit test fails if a `Resource`, `Array` or `Dictionary` field is added to `TubeConfig` (a shallow `duplicate()` would then share state). `EnvConfig.validated()` copies with `duplicate()` of a scalar-only resource and never reassigns fields on the loaded instance; Phase B keeps only the validated copy, never `def.env`. Keep `env` and the library inline in `map_01.tres`, or load with the deep-ignore cache mode, so a Retry sees fresh sub-resources.
- Map selection: `MapLoader.attempt(path)` takes the path. The MVP passes one constant from a boot config (`res://assets/data/maps/map_01.tres`); a future Maps & Levels system chooses the path. `unload_map` is not used in the MVP.

### 2. The load sequence

`MapLoaderCore` (RefCounted, no engine calls) runs `attempt(path)`. Phase A has no side effects; Phase B is applied only if Phase A passed entirely.

```text
Phase A: validate (pure; any failure returns the whole code set, nothing is applied)
  A1  def = load_definition(path)            seam; real: ResourceLoader.load, re-read on Retry
        `ResourceLoader.exists(path)` false or a null result -> MAP_RESOURCE_MISSING; `def is MapDefinition` false -> MAP_RESOURCE_TYPE
        (a corrupt file also prints an engine error that the rate-limited log cannot suppress; the smoke test tolerates it)
  A2  env = def.env.validated(log_sink)      clamped copy; a null `env` or fatal problems -> MAP_ENV_INVALID (never a crash)
  A3  cam = camera geometry from the seam    finite and in range, else MAP_CAMERA_INVALID
  A3b hazard_style = def.hazard_style.validated(log_sink)   scalar-only Resource (ADR-0014), clamped copy; null or fatal -> HAZARD_STYLE_INVALID
  A4  def.chunk_library not null             else MAP_LIBRARY_MISSING (content checked by ADR-0008's own validator)
  A5  map = MapConfig.build(...); tube_cfg = TubeConfig.from_map(base, map)   MapConfig.build also derives camera_far = F_rest + L from the validated env (the resting fog end is per map, so it cannot come from CameraMath.published at composition); `L <= 0` or a non-finite `camera_far` -> MAP_CAMERA_INVALID
  A6  codes = tube_cfg.validate()            Tube Track's own set (FOG_BEFORE_READ, ...), passed through unchanged

Phase B: apply (fixed order)
  B1  apply_env(map)         Environment.apply_map           (bool)
  B2  apply_obstacle(map)    Obstacle.apply_map              visible_arc_half_width (bool)
  B3  apply_pattern(map)     Pattern.apply_map               chunk_library (bool)
  B4  apply_hazard_view(map)  HazardView.apply_map            builds inert hidden nodes and meshes (ADR-0014; bool)
  B5  tube_load(tube_cfg)     TubeTrack.load_map              primes the window; emits window_primed, state_changed
  B6  send_map_ready()        RunState.map_ready()            Boot -> Menu
```

- Tube Track is **last** because `load_map` primes the window and emits `window_primed`, to which Obstacle and the view react; Environment, Obstacle, Pattern and the hazard view must already hold their values. B1 to B4 are idempotent: B1 to B3 are setters, and B4 may build inert hidden nodes and resources (no signal, no visible change, no tick effect; Retry clears the cache and rebuilds), so a failed attempt leaves nothing that a Retry cannot overwrite.
- `apply_map` on Environment, Obstacle and Pattern is **configuration only**: it emits no signal and starts nothing (Pattern does not begin generating, Environment makes no visible change before the Menu exists), so what a failed attempt leaves behind is inert.
- A false from B1 to B5 gives `MAP_APPLY_FAILED` plus the system name, or `TUBE_LOAD_REJECTED` for B5 (a rejected `load_map` after a passing `validate()` means a state problem, not a data problem). `map_ready` is sent **only** after B5 returned true; on any failure nothing is sent and Run State stays in Boot with no events.
- The sequence runs synchronously in one frame: the first time in `GameRoot` after `_wire()` and before the first `_process` (ADR-0002 step 5), and again inside `retry()`.

### 3. Failure and Retry

- On failure the core sets `status = FAILED`, stores `last_codes`, logs each code (rate limited by the reused `RateLimitedLog`) and emits **`map_load_failed(codes: PackedStringArray)`** once per attempt. Menus subscribes in `_wire()` (a Presentation view on a Foundation signal: downward) and shows the map-load-failure screen in the same tick. The player sees plain language only; codes go to the log (and a debug label in debug builds).
- **`MAP_LOAD_TIMEOUT` stays as a backup** for a loader that never reports (a wiring bug). With a synchronous loader it should never trigger. Menus' Boot sub-state "after the timeout" becomes "after `map_load_failed` or after the timeout" (GDD follow-up).
- **Retry:** Menus' Retry control calls an injected `request_map_retry: Callable` bound to `MapLoader.retry()`. `retry()` is valid only in `FAILED`: it re-runs the whole sequence, including a fresh re-read of the resource. In `READY` it is ignored with one log line (Tube Track accepts `load_map` only from Uninitialized); in `NOT_LOADED` it behaves as the first attempt. A single `_attempting` flag makes `attempt()` and `retry()` non-reentrant. A Retry never frees and recreates Tube Track's slots: a failure before B4 never reaches creation, and a rejected `load_map` creates nothing. Menus' "phase becomes Menu hides the failure screen" must not depend on in-emission ordering of a deferred connection (connections are immediate, ADR-0002). There is no attempt cap and no debounce: each attempt is the same cheap, deterministic sequence, so repeated Retry on bad data repeats the same failure, which the screen already states. A successful Retry sends `map_ready` from the button handler, like `start_requested` (a direct call on Run State), and the failure screen disappears when `phase` becomes Menu (Menus rule, unchanged).
- Run State's own contract is unchanged: while in Boot it emits nothing and rejects `start_requested` (AC-22).

### 4. Where the engine call lives

`ResourceLoader` appears only in `map_loader.gd` (the thin driver that builds the real `load_definition` seam); `MapLoaderCore`, `MapConfig` and the tests hold no engine calls. The path is always loaded with `ResourceLoader.load` and never opened with `FileAccess` or listed with `DirAccess` (export remaps and binary conversion hide the file). A lint extends the existing allowlist: `ResourceLoader` only in `map_loader.gd`.

### Architecture Diagram

```text
GameRoot (composition)
  CameraMath.published(CameraConfig, WorldGeometry) ──┐
  base TubeConfig, appliers, clock, log   │
                                          v
MapLoader (driver) ── ResourceLoader.load(map_01.tres) ──> MapDefinition {env, chunk_library}
   │                                          │
   v                                          v
MapLoaderCore.attempt(path)        Phase A  validate ──fail──> map_load_failed(codes) ──> Menus failure screen
   │ ok                                                                                       │ Retry
   v                                                                                          v
Phase B  Environment.apply_map -> Obstacle.apply_map -> Pattern.apply_map -> HazardView.apply_map -> TubeTrack.load_map   retry() re-runs all
   │ ok
   v
RunState.map_ready()   (Boot -> Menu)
```

### Key Interfaces

```gdscript
# map_definition.gd
class_name MapDefinition
extends Resource

@export var map_id: StringName
@export var env: EnvConfig
@export var chunk_library: Resource   # becomes ChunkLibrary in ADR-0008
@export var hazard_style: Resource    # HazardStyle, scalar-only (ADR-0014); validated in Phase A step A3b

# map_config.gd
class_name MapConfig
extends RefCounted

var map_id: StringName
var env: EnvConfig                    # validated copy
var chunk_library: Resource           # shared, immutable
var rear_extent: float
var camera_distance: float
var visible_arc_half_width: float
var hazard_style: Resource           # validated copy (ADR-0014)
var camera_far: float                 # F_rest + L, derived in Phase A step A5 from env (ADR-0014)

# map_loader_core.gd
class_name MapLoaderCore
extends RefCounted

enum Status { NOT_LOADED, READY, FAILED }

signal map_load_failed(codes: PackedStringArray)

var status: Status
var last_codes: PackedStringArray

func _init(seams: MapLoaderSeams, config: MapLoaderConfig) -> void
func attempt(path: String) -> bool
func retry() -> bool                  # FAILED only; READY is ignored with one log line

# MapLoaderSeams: load_definition(path) -> Variant, camera_geometry() -> Dictionary,
# apply_env/apply_obstacle/apply_pattern/apply_hazard_view(map: MapConfig) -> bool, tube_load(cfg: TubeConfig) -> bool,
# send_map_ready() -> void, base_tube_config() -> TubeConfig, log_sink(level, code, key, message)
```

## Alternatives Considered

### Alternative 1: One flat `MapConfig` Resource with every field, Camera values stored in the file

- **Pros**: one file, no builder.
- **Cons**: Camera values stored twice (`CameraConfig` and the map) and free to drift; Environment no longer owns its fog fields.
- **Rejection Reason**: one owner per field; the Camera values are derivable.

### Alternative 2: No shared object; every consumer gets an `apply_map` setter with raw values

- **Pros**: fewer new types.
- **Cons**: application order is hard to pin and test; no single place validates the combination.
- **Rejection Reason**: not rejected for the setters (Phase B uses them) but for having no shared, immutable `MapConfig` and no validate-first phase.

### Alternative 3: Threaded loading (`load_threaded_request`, polled each tick)

- **Pros**: never blocks a frame.
- **Cons**: adds a Loading state, cancellation and asynchronous errors for one file of a few KB, in a boot that is not part of the restart budget.
- **Rejection Reason**: not needed at this size. **Pre-committed response** if MS-1 shows the sequence is too slow on a target device: switch only the `load_definition` seam to the threaded API, keeping Phase A and B unchanged.

### Alternative 4: Failure screen on timeout only (the Menus GDD as written)

- **Rejection Reason**: a synchronous failure is known at once; waiting ten seconds shows a blank Boot screen for no reason. The timeout stays as the backup.

## Consequences

### Positive

- One owner per field, one immutable object, one place that validates the combination.
- Validate-first: a bad map never leaves Tube Track primed or `map_ready` sent.
- The failure screen shows immediately, and Retry is a plain re-run.
- The whole loader is a unit test with fake seams.

### Negative

- New types (`MapDefinition`, `MapConfig`, `MapLoaderCore`, seams, `MapLoaderConfig`) and three new `apply_map` entry points on Environment, Obstacle and Pattern.
- Menus Rule 8 and TR-menus-009 change (failure shown on the signal; the timeout becomes a backup); a new `request_map_retry` Callable and a `map_load_failed` row in `_wire()`.
- `architecture.md` section 6 (the `MapConfig` sketch with `tube` and `env`) is replaced; Camera's "published at map load" wording changes to "derived by `CameraMath` at composition".
- Phase B has no rollback of the Environment, Obstacle, Pattern and hazard view steps after a Tube Track failure; this is acceptable because they are idempotent and Retry overwrites them.

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `.tres` does not load in an Android export (remap, binary conversion, class cache) | Medium | High (no game) | load only through `ResourceLoader`; verification items 1 and 4; first export smoke test |
| A Retry returns the cached resource instead of re-reading | Medium | Low | cache mode that forces a re-read (verification item 2); the failure is deterministic anyway |
| Boot takes too long on a slow phone | Low | Medium | MS-1; threaded `load_definition` pre-committed |
| A new map breaks a cross-field constraint no validator owns | Medium | Medium | A6 reuses `TubeConfig.validate()`; ADR-0008 validates the library; a per-map smoke test |
| The loader runs before a subscriber is wired, losing `map_load_failed` | Low | Medium | `MapLoader` runs after `_wire()` (ADR-0002); a spy test of the order |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| run-state-restart.md | Boot to Menu only on `map_ready`, sent only after a successful load; failure keeps Boot with no events (D9, OQ8, AC-22) | Decisions 2 and 3: validate first, `map_ready` only after B5, nothing sent on failure |
| tube-track.md | `load_map` accepted only from Uninitialized; a failed validation keeps it and allows Retry; the loader owns the call and `map_ready`; Tube Track owns validation | Decisions 2 and 3 (A6 reuses `validate()`; B5 is last; Retry re-runs the sequence) |
| menus-screen-flow.md | Rule 8 failure screen, Retry, `MAP_LOAD_TIMEOUT` (TR-menus-009) | Decision 3 (`map_load_failed` signal, `request_map_retry`, timeout as backup) |
| camera.md | `rear_extent`, `camera_distance`, `VISIBLE_ARC_HALF_WIDTH` published at map load | Decision 1 (derived by `CameraMath` from `WorldGeometry` and `OMEGA_MAX`, carried in `MapConfig`) |
| environment-theming.md | `MapConfig` fields it owns, validated at map load | Decision 1 (`MapDefinition.env`, `EnvConfig.validated` copy) |
| pattern-difficulty.md | OQ4: the `MapConfig` field that selects the chunk library | Decision 1 (`chunk_library`, typed by ADR-0008) |
| obstacle-system.md | OQ7: `VISIBLE_ARC_HALF_WIDTH` supplied from outside | Decision 1 and B2 |

## Performance Implications

- **CPU**: one `ResourceLoader.load`, a few validations, 12 slot binds at `load_map`; expected tens of milliseconds, once per boot (and per Retry); to be measured (MS-1). The hazard view prewarm (ADR-0014 HV-1) shares the MS-1 budget.
- **Memory**: a `MapDefinition`, `EnvConfig` and the chunk library resident for the session; small.
- **Load Time**: part of cold start; not part of the restart budget.
- **Network**: none.

## Migration Plan

New code. After this ADR is Accepted: Menus GDD Rule 8 and TR-menus-009 (signal plus backup timeout, `request_map_retry`), `architecture.md` section 6, Camera and Environment wording, `design/gdd/systems-index.md` rows for the Composition Root and Map Loader, three `apply_map` entry points listed in the Environment, Obstacle and Pattern GDDs' interfaces.

## Validation Criteria

- [ ] Unit tests with fake seams: success sends `map_ready` once and applies in the order B1..B5 (env, obstacle, pattern, hazard view, tube load) before B6; each Phase A failure sends nothing, applies nothing and emits `map_load_failed` once with the right code; a B-step failure sends nothing; `retry()` in `FAILED` re-runs including the re-read; in `READY` it is a logged no-op.
- [ ] Tests build resources with `MapDefinition.new()` and `EnvConfig.new()`, not by loading `.tres` (headless GUT needs `godot --headless --import` first, or `class_name` types do not resolve); one round-trip test loads `map_01.tres` and asserts `env` and the library are non-null; a null `env` yields `MAP_ENV_INVALID`.
- [ ] A spy test: `map_load_failed` reaches Menus because the loader runs after `_wire()`.
- [ ] Android export smoke test: `map_01.tres` loads, and a corrupted copy gives the failure screen and not a crash.
- [ ] MS-1: boot sequence time recorded on a mid-tier phone (target at most 100 ms; threaded load only if exceeded).
- [ ] A lint: `ResourceLoader` appears only in `map_loader.gd`; no `duplicate_deep`.

## Related Decisions

- ADR-0002 Game loop and Composition Root; ADR-0003 Renderer and tube render route; ADR-0008 (to be written: hazard, collision and content format, the `ChunkLibrary` type)
- `design/gdd/tube-track.md`, `run-state-restart.md`, `menus-screen-flow.md`, `camera.md`, `environment-theming.md`, `pattern-difficulty.md`, `obstacle-system.md`
- `docs/architecture/tr-baseline/foundation.md` (TR-run-state-restart-020), `world-movement.md` (TR-tube-track-024), `presentation-ui.md` (TR-menus-screen-flow-009)
