# Control Manifest

> **Engine**: Godot 4.7.2 (GDScript, Mobile renderer on Android)
> **Last Updated**: 2026-10-03
> **Manifest Version**: 2026-10-03
> **ADRs Covered**: ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0012, ADR-0013, ADR-0014 (all Accepted 2026-10-03); ADR-0001 (Accepted, platform scope)
> **Status**: Active. Regenerate with `/create-control-manifest update` when an ADR is accepted or revised.

`Manifest Version` is the date this manifest was generated. Story files embed this
date when created; `/story-readiness` compares a story's embedded version to this
field to detect stories written against stale rules.

This manifest is a programmer's quick reference extracted from the Accepted ADRs,
`.claude/docs/technical-preferences.md` and `docs/engine-reference/godot/`. For the
reasoning behind a rule, open the ADR named in its `source`. Where the ADR and this
sheet differ, the ADR wins; fix the sheet. Spike names (R-1, T-1, PS-*, SP-*, PT-*,
HV-1, UI-*, PRC-1, MS-1, OB-1) are validation gates on the first dependent story
(P-1, `architecture.md`); "unverified" means not yet proven on 4.7.2.

**How to read the layers.** A rule appears once, under the layer it governs most;
rules that bind every layer are in "Global Rules" at the end. Rules were extracted
mechanically from the ADRs (duplicates merged, sources combined) and have not been
independently re-read against every ADR.

---

## Foundation Layer Rules

*Applies to: composition root, per-frame order, subscriber order, Map Loader, persistence, platform, settings, run state, WorldFrame/WorldGeometry, test and CI*

### Required Patterns

- Construct in this fixed order, each step finishing before the next: `PlatformServices`, `SaveService` (synchronous load, connect `app_backgrounded`), `SettingsCore` (push `haptics_*` to Platform Services), `RunStateCore` and `ScoreService` (construction emits nothing), immutable `WorldGeometry` (ADR-0004) and `WorldFrame` (ADR-0013) validated together before any view is built (`REBASE_Z_EXCEEDS_BUDGET` is fatal), then every other system (ADR-0012 Decision 4, ADR-0014 Decision 5 order: Environment view, `WorldChroma`, `BallView`, `HazardView`, Environment, Juice, then HUD and Menus views), then `wire()`, then `MapLoader` calls `load_map` and sends `map_ready` on success, then the loop starts. — source: ADR-0002 Decision 5
- Run the per-frame order in `GameRoot._tick()` (the only place it is written): `TiltInput.poll`, `TiltRunAdapter.flush`, `RunState.tick`, `Ball.step`, `TubeTrack.advance` (Running only), `WorldFrame step` (`maybe_rebase(s)`, then `TubeView.rebase()` and `HazardView.rebase()` when it returns true; Running only), `Obstacle.test`, `NearMiss.step`, `Scoring.step`, `TubeView.idle_step(real_dt)` (only in Menu), `Camera.step`, `BallView.tick`, `Environment.tick`, then `Juice.tick`, `HUD.tick`, `Menus.tick`. — source: ADR-0002 Decision 6
- Cite per-frame steps by name, not number, in other documents. — source: ADR-0002 Decision 6
- Build `GameRoot._wire()` as an array of rows `[signal: Signal, handler: Callable, rank: int]`, sort by rank with the row index as tie-break (the sort is not stable), then call `signal.connect(handler)` in that order. Typed handlers are mandatory (signal arguments are coerced to the handler's declared types). — source: ADR-0002 Decision 7
- Declare signals on the owning core (`RunStateCore` declares `run_reset`, `run_ended`, `run_abandoned`). — source: ADR-0002 Decision 7
- Use the Run State ranks: `run_reset` (Pattern and `WorldFrame`, tie by row order; Tube Track adapter and Obstacle, tie by row order; Ball; Camera; the rest), `run_ended` (Juice; Scoring; HUD; the rest), `run_abandoned` (Juice; Scoring; the rest). — source: ADR-0002 Decision 7
- A system added later gets one row in `_wire()` and one line in `_tick()`. — source: ADR-0002 Implementation Guidelines
- Platform Services turns `NOTIFICATION_APPLICATION_FOCUS_OUT` into `app_interrupted`, applied by Run State when sent: this is the primary pause signal; Run State's stall guard is only the backup. — source: ADR-0002 Decision 9
- Add a spy test that records the `_tick()` call log and asserts the per-frame order, including `WorldFrame step` right after `TubeTrack.advance`, `TubeView.idle_step` only in Menu, `BallView.tick` right after `Camera.step`, and the construction order. — source: ADR-0002 Validation Criteria
- Add a test that no row Callable is invalid after `_wire()` and that the connect order equals the table order, including after disconnect and reconnect. — source: ADR-0002 Risks / Validation Criteria
- Keep `GameRoot` free of rules (wiring only); guard with a lint on rule keywords and code review. — source: ADR-0002 Risks
- Use a single `MapDefinition` resource (`assets/data/maps/map_01.tres`, `.tres`) holding `map_id`, `env: EnvConfig`, `chunk_library: Resource` (typed `ChunkLibrary` by ADR-0008) and `hazard_style: Resource` (scalar-only, ADR-0014). — source: ADR-0004 Decision 1
- `MapConfig` is a `RefCounted` built at load and read-only after build, carrying `map_id`, validated `env` copy, shared `chunk_library` (never copied), `rear_extent`, `camera_distance`, `visible_arc_half_width`, validated `hazard_style` copy and `camera_far`. — source: ADR-0004 Decision 1
- Per-run and per-build knobs (`TubeConfig` A, N, B etc., `CameraConfig`, `PatternConfig`) stay in their own `.tres` files; a map contributes only what varies per map. — source: ADR-0004 Decision 1
- Derive the Camera values (`rear_extent`, `camera_distance`, `visible_arc_half_width`) with static pure `CameraMath.published` from `CameraConfig` and the immutable `WorldGeometry` (`R`, `D`, `N_F`, `L`, `OMEGA_MAX` from `BallConfig`); `GameRoot` calls it at composition and passes the result to the loader. `camera_distance` is the derived worst case (about 7.84), not a hand-copied 8. — source: ADR-0004 Decision 1
- Build `WorldGeometry` once in `GameRoot` at composition from the base `TubeConfig` and `BallConfig` (`D` has one owner, Ball Movement) and validate it before the first `MapLoader.attempt`. — source: ADR-0004 Decision 1
- `TubeConfig.from_map(base, map)` returns `base.duplicate()` (shallow) with the map-supplied fields set (fog, seam, `readable_distance` from `map.env`, `rear_extent`, `camera_distance`); cached resources are never mutated. — source: ADR-0004 Decision 1
- `EnvConfig.validated(log_sink)` returns a clamped copy via `duplicate()` of a scalar-only resource and never reassigns fields on the loaded instance; Phase B keeps only the validated copy, never `def.env`. — source: ADR-0004 Decision 1
- Keep every `@export` field of `EnvConfig` and `TubeConfig` a scalar, an enum or a `Color`; `MapDefinition -> EnvConfig` has no back-edge; `MapConfig` is never an `@export` type. — source: ADR-0004 Decision 1
- Keep `env` and the library inline in `map_01.tres`, or load with the deep-ignore cache mode, so a Retry sees fresh sub-resources. — source: ADR-0004 Decision 1
- `MapLoader.attempt(path)` takes the path; the MVP passes one constant from a boot config (`res://assets/data/maps/map_01.tres`). — source: ADR-0004 Decision 1
- Run `MapLoaderCore.attempt(path)` as Phase A (pure validation, no side effects: A1 load_definition, A2 `def.env.validated`, A3 camera geometry, A3b `hazard_style.validated`, A4 `chunk_library` not null, A5 `MapConfig.build` + `TubeConfig.from_map` (derive `camera_far = F_rest + L`), A6 `tube_cfg.validate()` passed through unchanged); apply Phase B only if Phase A passed entirely. — source: ADR-0004 Decision 2
- Phase A codes: `MAP_RESOURCE_MISSING` (`ResourceLoader.exists` false or null), `MAP_RESOURCE_TYPE` (`def is MapDefinition` false), `MAP_ENV_INVALID` (null env or fatal), `MAP_CAMERA_INVALID` (non-finite/out of range, `L <= 0`, non-finite `camera_far`), `HAZARD_STYLE_INVALID`, `MAP_LIBRARY_MISSING`. — source: ADR-0004 Decision 2
- Apply Phase B in this fixed order: B1 `Environment.apply_map`, B2 `Obstacle.apply_map` (`visible_arc_half_width`), B3 `Pattern.apply_map` (`chunk_library`), B4 `HazardView.apply_map` (inert hidden nodes and meshes), B5 `TubeTrack.load_map` (primes the window; emits `window_primed`, `state_changed`), B6 `RunState.map_ready()` (Boot -> Menu). — source: ADR-0004 Decision 2
- Tube Track `load_map` must be last because it primes the window and emits `window_primed`; B1 to B4 must be idempotent so Retry can overwrite. — source: ADR-0004 Decision 2
- `apply_map` on Environment, Obstacle and Pattern is configuration only: it emits no signal and starts nothing. — source: ADR-0004 Decision 2
- A false from B1 to B4 gives `MAP_APPLY_FAILED` plus the system name; a rejected B5 gives `TUBE_LOAD_REJECTED`. `map_ready` is sent only after B5 returned true; on any failure send nothing and keep Run State in Boot with no events. — source: ADR-0004 Decision 2
- Run the load sequence synchronously in one frame: first in `GameRoot` after `_wire()` and before the first `_process`, and again inside `retry()`. — source: ADR-0004 Decision 2
- On failure the core sets `status = FAILED`, stores `last_codes`, logs each code (rate limited by the reused `RateLimitedLog`) and emits `map_load_failed(codes: PackedStringArray)` once per attempt; Menus subscribes in `_wire()` and shows the map-load-failure screen in the same tick; the player sees plain language only, codes go to the log (and a debug label in debug builds). — source: ADR-0004 Decision 3
- Keep `MAP_LOAD_TIMEOUT` as a backup for a loader that never reports; Menus' Boot sub-state becomes "after `map_load_failed` or after the timeout". — source: ADR-0004 Decision 3
- Retry: Menus calls an injected `request_map_retry: Callable` bound to `MapLoader.retry()`; `retry()` is valid only in `FAILED` and re-runs the whole sequence including a fresh re-read; in `READY` ignore with one log line; in `NOT_LOADED` behave as the first attempt. A single `_attempting` flag makes `attempt()` and `retry()` non-reentrant. — source: ADR-0004 Decision 3
- A successful Retry sends `map_ready` from the button handler (direct call on Run State); the failure screen disappears when `phase` becomes Menu. — source: ADR-0004 Decision 3
- Run State's contract is unchanged: in Boot it emits nothing and rejects `start_requested` (AC-22). — source: ADR-0004 Decision 3
- Wire `MapLoader` after `_wire()` so `map_load_failed` reaches Menus (add the `map_load_failed` row in `_wire()`). — source: ADR-0004 Risks
- Android settings required (checked at boot and linted in CI by Platform Services' manifest; ADR-0006 owns the export side): `input_devices/sensors/enable_gravity = true`; `display/window/handheld/orientation = 1` (portrait); `input_devices/pointing/emulate_mouse_from_touch = true`; `input_devices/pointing/emulate_touch_from_mouse = true`. — source: ADR-0005 Decision 2
- The boot manifest check (Platform Services) must confirm `enable_gravity` is true first, so a missing flag is reported as a settings error, not as a missing sensor. — source: ADR-0005 Decision 1
- `GameRoot` checks `RenderingServer.get_current_rendering_method()` at boot through the injectable `rendering_method_getter` seam and refuses to run if it is not `mobile`; headless test runs inject a fake. — source: ADR-0003 Decision 1
- Editor-only steering: only when `OS.has_feature("editor")` is true, `GameRoot` replaces the `TiltInput` `sample_source` with a synthetic one turning left/right arrow keys into a gravity vector of a fixed roll angle; `TiltCore`, `valid` and `input_source` (still `SENSOR`) stay unchanged. — source: ADR-0005 Decision 6
- CI lint (ADR-0005 Decision 7): fail if any file other than `tilt_input.gd` calls `Input.get_gravity`, `get_accelerometer`, `get_gyroscope` or `get_magnetometer`; if the tap catcher reads `InputEventMouseButton`; if gameplay reads `Input.is_action_*`; if the editor-only source is reachable without the `has_feature("editor")` check; or if the manifest shows any sensor flag other than `enable_gravity` set to true. — source: ADR-0005 Decision 7
- CI: `godot --headless --import` must parse every shader (SPIR-V compilation is verified on device only), and no shader may use unsupported preprocessor patterns. — source: ADR-0003 Validation Criteria
- Unit tests build resources with `MapDefinition.new()` and `EnvConfig.new()`, not by loading `.tres`; one round-trip test loads `map_01.tres` and asserts `env` and the library are non-null; a null `env` yields `MAP_ENV_INVALID`; a unit test fails if a `Resource`, `Array` or `Dictionary` field is added to `TubeConfig`. — source: ADR-0004 Validation Criteria / Decision 1
- Fake-seam unit tests: success sends `map_ready` once in order B1..B5 before B6; each Phase A failure sends nothing, applies nothing and emits `map_load_failed` once with the right code; a B-step failure sends nothing; `retry()` in `FAILED` re-runs including the re-read; in `READY` it is a logged no-op. — source: ADR-0004 Validation Criteria
- Android export smoke test: `map_01.tres` loads, and a corrupted copy gives the failure screen and not a crash. — source: ADR-0004 Validation Criteria
- Lint: `ResourceLoader` appears only in `map_loader.gd`; no `duplicate_deep`. — source: ADR-0004 Validation Criteria
- One `PlatformServices` node owns every OS call, written in GDScript with a `PlatformCore` (RefCounted) taking injected `clock`, `display_source`, `vibrate`, `keep_on`, `read_setting`. — source: ADR-0006 Decision 1
- `PlatformServices` is created first in the ADR-0002 construction order; signals are not replayed, so a consumer must read `attentive` and `suspended` on connect. — source: ADR-0006 Implementation Guidelines
- `focus_implies_suspend` is true on Android: `NOTIFICATION_APPLICATION_FOCUS_OUT` emits `app_interrupted` then `app_backgrounded`; `FOCUS_IN` emits `app_foregrounded` then `app_returned`. — source: ADR-0006 Decision 2
- `FOCUS_OUT` is the primary pause signal (ADR-0002); Run State's stall guard is the backup. — source: ADR-0006 Decision 2
- Keep `NOTIFICATION_APPLICATION_PAUSED/RESUMED` handlers as no-ops that log at debug level. — source: ADR-0006 Decision 2 / Implementation Guidelines
- Every lifecycle notification handler checks `OS.get_thread_caller_id() == OS.get_main_thread_id()`: on the main thread call the core synchronously (so the `app_backgrounded` flush runs before the OS can suspend), on any other thread marshal with `call_deferred` (via `_marshal`). — source: ADR-0006 Decision 3
- The `app_backgrounded` flush stays small and synchronous (a few KB, no thread, explicit flush and close). — source: ADR-0006 Decision 3
- Set `application/config/quit_on_go_back = false` in the project and `get_tree().quit_on_go_back = false` at boot. — source: ADR-0006 Decision 4
- Handle Back only through `NOTIFICATION_WM_GO_BACK_REQUEST`, which emits `back_pressed` and decides nothing. — source: ADR-0006 Decision 4
- If spike PS-4 shows `BACK` is not delivered (Android 13+ predictive back, or Android 16 targeting SDK 36), Back must send the app to the background (pause, no run lost) and the missing `back_pressed` is a release blocker. — source: ADR-0006 Decision 4
- Run spike PS-4 with target SDK 36 and predictive back both on and off; the `android:enableOnBackInvokedCallback` value is part of the manifest check. — source: ADR-0006 Decision 4
- `haptic(kind)` goes through the Platform Services gate (enabled, attentive, not zero, throttled, priority) and calls `Input.vibrate_handheld(duration_ms, amplitude)`; devices without amplitude control play a fixed pulse. — source: ADR-0006 Decision 5
- Read `DisplayServer.get_display_safe_area()`, `screen_get_size()`, `screen_get_refresh_rate()`, `screen_get_dpi()` (carried as `DisplayFacts.screen_dpi: int`) at construction, on each regaining edge (`app_foregrounded`, `app_returned`) and on window size change. — source: ADR-0006 Decision 6
- An empty safe area becomes the full screen rectangle in pixels; system gesture insets are not exposed; the UI keeps the 40 dp and 16 dp starting margins. — source: ADR-0006 Decision 6
- Call `DisplayServer.screen_set_keep_on(true)` once at boot, never turn it off; set `application/run/max_fps = 60`. — source: ADR-0006 Decision 7
- Android export preset: Gradle build on (custom build template); AAB for Google Play, APK for sideload tests; architecture `arm64-v8a` only. — source: ADR-0006 Decision 8
- Set minimum SDK 28 (Android 9) and target SDK explicitly in the preset (target = the level Google Play requires at release, 36 expected, to be confirmed); keep SDK values in the preset only. — source: ADR-0006 Decision 8
- Confirm 16 KB page alignment for the 4.7.2 templates and packaged libraries (`zipalign -c -P 16` and an ELF alignment check on the `.so` files). — source: ADR-0006 Decision 8 / Validation
- Declare `uses-feature android.hardware.vulkan.version` with `android:version="0x401000"` (Vulkan 1.1), `required = true`, replacing Godot's default Vulkan entry (exactly one entry); declare `uses-feature android.hardware.sensor.accelerometer` `required = true`. — source: ADR-0006 Decision 8
- Permissions: `VIBRATE` only. — source: ADR-0006 Decision 8
- Orientation portrait (preset and `display/window/handheld/orientation = 1`); immersive mode on; picture-in-picture off. — source: ADR-0006 Decision 8
- Restrict distribution to phones via the Play Console device catalog; if a foldable still runs the game, keep the portrait layout centred (letterbox). — source: ADR-0006 Decision 8
- Commit `export_presets.cfg` in the same commit that removes it from `.gitignore`; keystore, alias and passwords live outside the repository. — source: ADR-0006 Decision 8
- Release signing: CI decodes the keystore from a secret to a temporary path and passes it through the Godot Android keystore environment variables; use Play App Signing with an upload key. — source: ADR-0006 Decision 8
- Platform Services' `PlatformSettings` manifest covers `project.godot` keys (orientation, `quit_on_go_back`, `max_fps`, `enable_gravity`, the ADR-0005 touch-emulation keys) and the preset keys; CI lints them. — source: ADR-0006 Decision 9
- For release builds the CI lint reads the merged `AndroidManifest.xml` (e.g. `aapt2 dump`), not only the preset; only release builds are linted for permissions. Until the first preset exists the preset part is skipped with a warning. — source: ADR-0006 Decision 9
- Handlers never send requests from inside a Run State tick or handler. — source: ADR-0006 Decision 3 / Implementation Guidelines
- Persistence module shape: `PersistMath` (static), `SaveCore` (RefCounted), `SaveFs` (RefCounted facade), `SaveService` (Node); `SaveCore` is constructed with `(fs: SaveFs, clock: Callable, wall_clock: Callable, log_sink: Callable, config: SaveConfig)`. — source: ADR-0007 Decision 1
- The GDD's eight seams are replaced by one `SaveFs` facade (`read_config`, `write_config`, `exists`, `size`, `rename`, `delete`, `list_backups`) plus three Callables (`clock`, `wall_clock`, `log_sink`). — source: ADR-0007 Decision 1
- `SaveFs` is a plain base class whose methods return failure values (`false`, `-1`, empty result with status `"PARSE_ERROR"`); the real implementation is an inner class of `SaveService`; test fakes extend `SaveFs`, record calls in order and script return values. — source: ADR-0007 Decision 1
- Save file is one `ConfigFile` at `user://save.cfg` with sections `[scoring]` (`personal_best` int), `[settings]`, reserved `[cosmetics]`, `[_meta]` (`schema_version` int, 1 at MVP); temp file `user://save.cfg.tmp`; corrupt backups `user://save.cfg.corrupt-<wall_clock>-<n>`. — source: ADR-0007 Decision 2
- `SaveCore.boot_load()` runs once at boot (ADR-0002 step 2), before Scoring and Settings exist; it is named `boot_load`, not `load`. — source: ADR-0007 Decision 3 / Key Interfaces
- Boot load order: missing file gives `MISSING` plus defaults plus one INFO `FILE_MISSING`; `fs.size(REAL) > SAVE_FILE_SIZE_MAX` is treated as `PARSE_ERROR` (`FILE_UNREADABLE`, "oversized") without calling `read_config`; otherwise `fs.read_config(REAL)`. — source: ADR-0007 Decision 3
- The real `read_config` builds a fresh `ConfigFile` per read and discards it on error; `ERR_FILE_NOT_FOUND` maps to `MISSING`, every other non-`OK` `Error` maps to `PARSE_ERROR`. — source: ADR-0007 Decision 3
- `PARSE_ERROR` gives `FILE_UNREADABLE`; incompatible `[_meta].schema_version` gives `SCHEMA_INCOMPATIBLE` (an empty file therefore counts as incompatible); either invalidates the whole file (every `get_value` returns the caller's default) and is logged once per load (ERROR), not once per key. — source: ADR-0007 Decision 3
- `TYPE_MISMATCH` stays per key, logged when the key is first read; keys failing the type check are carried forward byte for byte. — source: ADR-0007 Decision 3
- On a file-level failure rename the old file to `save.cfg.corrupt-<wall_clock()>-<n>` (n zero-based, incremented while the name exists), then `list_backups`, sort by name and delete the oldest until at most `CORRUPT_BACKUP_RETENTION` remain; in-memory state is then empty and the first `set_value` creates a fresh file. — source: ADR-0007 Decision 3
- `type_matches` compares `typeof(stored) == typeof(default)` with the caller's own default; callers wanting a float must declare a float default (a stored int where a float is declared is `TYPE_MISMATCH`). — source: ADR-0007 Decision 3
- `set_value(section, key, value) -> bool` is synchronous: reject non-serializable values (`UNSERIALIZABLE_VALUE`, no memory update, no seam call, return false); update memory; delete an existing TMP; `write_config(TMP, complete_sections)` then `size(TMP) > 0`; `rename(TMP, REAL)`; return true. — source: ADR-0007 Decision 4
- `complete_sections` is always the whole map; a failed write/rename logs `WRITE_FAILED` (rate limited per section and key by the reused `RateLimitedLog`), returns false and keeps the in-memory value. — source: ADR-0007 Decision 4
- `flush()` (called by `SaveService` on `app_backgrounded`) is a no-op because every write is already synchronous; it exists so a future change cannot add a race silently. — source: ADR-0007 Decision 4
- The personal-best write stays inside `set_value` so it is on disk before the tick ends; measure it with spike SP-3. — source: ADR-0007 Decision 5
- Pre-committed SP-3 failure response: `set_value` only marks the core dirty and `GameRoot` calls `save.flush_dirty()` as the last step of the same tick (after `Menus.tick`, before the next frame). — source: ADR-0007 Decision 5
- Settings and Menus must call `set_value` for a slider on drag end (`drag_ended`), never on every `value_changed`; SP-3 includes a 10-second slider-drag run as negative control. — source: ADR-0007 Decision 5
- Set `android:allowBackup="false"` via the export preset / merged manifest (likely a custom Gradle build template manifest edit); the ADR-0006 manifest lint gains an assertion for it, and also covers Android 12+ data extraction. — source: ADR-0007 Decision 7
- `SaveConfig` (a `Resource`, `validated(log_sink)`) holds `SAVE_LOG_RATE_LIMIT`, `CORRUPT_BACKUP_RETENTION`, `SAVE_FILE_SIZE_MAX`; `CURRENT_SCHEMA_VERSION` is a constant. — source: ADR-0007 Decision 8
- SP-1 must run its Windows `rename_absolute` prerequisite check before any CI run of SP-1; SP-3 runs in the same device session as SP-1. — source: ADR-0007 Ordering Note
- Pre-committed response if `rename_absolute` is delete-then-rename: at boot, if `REAL` is missing and `TMP` parses and is compatible, rename `TMP` to `REAL` after the same parse/schema checks and log INFO; if SP-1 still fails, adopt the GDD's A/B-slot scheme. — source: ADR-0007 Decision 6
- Pre-committed response for SP-2 parsing side effects: pre-parse content sniff (reject the file before `ConfigFile.load`). — source: ADR-0007 Decision 6
- GDScript framework: GUT 9.x vendored under `addons/gut/` at a pinned release tag; tag and archive checksum recorded in `tools/ci/versions.json`; GUT is the only allowed addon in the MVP. — source: ADR-0009 Decision 1
- `.gutconfig.json` sets `"prefix": ""` and `"suffix": "_test.gd"`; the runner fails on zero tests executed and on an executed count lower than the number of `*_test.gd` files. — source: ADR-0009 Decision 1
- Test files are `[system]_[feature]_test.gd`, classes `extends GutTest`, functions `test_[scenario]_[expected]`. — source: ADR-0009 Decision 1
- Factories and fakes live in `tests/support/` as plain `RefCounted` classes/functions with no GUT base class and no GUT call; only `*_test.gd` files touch GUT. — source: ADR-0009 Decision 1
- Test files reference support code with `const X = preload("res://tests/support/x.gd")`; `class_name` in `tests/support/` only with a unique prefix and not used by tests. — source: ADR-0009 Decision 1
- Spike T-1 (blocking, before the first story): run one passing, one failing and one `[N]` SceneTree test headless on Windows and Linux with 4.7.2; record `RenderingServer.get_current_rendering_method()` under the headless driver. — source: ADR-0009 Decision 1
- Pre-committed T-1 failure response: if GUT cannot meet verification items 1 to 5 on 4.7.2, switch to gdUnit4, keep `tests/support/` unchanged, port the test files, and amend this ADR. — source: ADR-0009 Decision 1
- Test layout: `tests/unit/<system>/` (Logic, BLOCKING; fakes only, no file I/O, no SceneTree except `[N]` node tests), `tests/integration/<system>/` (Integration/Content, BLOCKING; real `.tres`, per-test temp files, content preflight), `tests/advisory/<system>/` (ADVISORY; shipped-default smoke, statistical), `tests/support/`, `production/qa/evidence/` (Visual/Feel and device evidence), `tools/ci/`. — source: ADR-0009 Decision 2
- Unit tests never touch the real file system, `ResourceLoader` or `Time`; integration tests may read shipped `.tres` and write only under a unique per-test temporary directory (including `user://`) deleted in `after_each`. — source: ADR-0009 Decision 2
- A test that needs a real device is not written as a GUT test; it is device evidence in `production/qa/evidence/`, blocking at its named gate. — source: ADR-0009 Decision 2
- A node test touching rendering classes runs under the dummy headless renderer and asserts structure only. — source: ADR-0009 Decision 2
- One entry command `python tools/ci/run_ci.py [--only unit|integration|advisory|lint|all]`: (1) `godot --headless --path . --import` (twice as a build step if T-1 shows a second pass is needed), (2) GUT over `tests/unit/` then `tests/integration/` with committed `.gutconfig.json` (`-gexit`, JUnit XML under `build/test-reports/`), (3) GUT over `tests/advisory/` (failure is a warning), (4) `python tools/ci/lint_runner.py` (Python unit tests of the lints as step 4a). — source: ADR-0009 Decision 3
- Mandatory result checks: every Godot call runs under a timeout wrapper; JUnit XML must exist, report more than zero tests and at least as many as `*_test.gd` files, with zero failures and errors; fail the step on `SCRIPT ERROR` or `Parse Error` in captured output even when exit code is 0. — source: ADR-0009 Decision 3
- Godot binary path comes from `GODOT` env var or `tools/ci/versions.json`; the script prints the engine version and fails if it is not exactly `4.7.2`. — source: ADR-0009 Decision 3
- `/smoke-check` calls `python tools/ci/run_ci.py --only unit`; the `coding-standards.md` CI line is replaced by it. — source: ADR-0009 Decision 3
- CI workflow `.github/workflows/ci.yml`, job named `ci`: `actions/checkout` with `persist-credentials: false`; `concurrency` group cancelling superseded runs; `timeout-minutes` on the job; SHA-pinned `actions/setup-python`; workflow-level `permissions: contents: read`; no secrets. — source: ADR-0009 Decision 4
- Triggers: `push` to `dev` and `main`, and `pull_request` into `main` (and `dev`); runner `ubuntu-latest`. — source: ADR-0009 Decision 4
- Download the official Godot 4.7.2-stable Linux archive and verify its SHA-512 against the value committed by hand in `tools/ci/versions.json` (never fetch the checksum file from the same release at run time) before unpacking. — source: ADR-0009 Decision 4
- Pin every third-party action to a commit SHA; vendor GUT (committed `addons/gut` is the source of truth; `versions.json` records release tag, upstream commit SHA and licence file); upload `build/test-reports/` as an artifact. — source: ADR-0009 Decision 4
- `.gitattributes` forces `eol=lf` for `*.gd`, `*.tres`, `*.tscn`, `*.json`, `*.py`; add it with the first scaffold commit. — source: ADR-0009 Decision 4 / Migration Plan
- Enabling the `ci` job as a required status check on `main` is a repository setting that needs the owner's explicit approval. — source: ADR-0009 Decision 4
- Lint runner: `tools/ci/lint_runner.py` (Python 3, stdlib only) reads `tools/ci/lint_rules.json`; each rule has `id`, `source`, `severity` (BLOCKING/ADVISORY), `kind`, `scope` (globs), pattern fields, `message`. — source: ADR-0009 Decision 5
- GDScript is scanned after comments and string literals are stripped by one left-to-right state machine (not sequential regex passes): handles `#`/`##`, `#` inside strings, triple-quoted strings, escapes, raw `r"..."`, `&"name"`, `^"path"`, `$Node/Path`, `%Unique`; keeps quotes (`""`), preserves newlines, accepts CRLF and LF. — source: ADR-0009 Decision 5
- `_process` is matched as `func\s+_(physics_)?process\b`; a scene-file rule scans `.tscn` `[connection ...]` entries for the deferred flag. — source: ADR-0009 Decision 5
- Lint rule kinds: `forbid` (regex must not match in scope), `only_in` (match only in listed files), `project_setting` (required `project.godot` value), `manifest` (`export_presets.cfg` and merged release manifest), `secret` (no keystore/alias/password in repo), `custom` (named Python function). — source: ADR-0009 Decision 5
- `forbid` rules registered: `_process`/`_physics_process` outside `game_root.gd`; `CONNECT_DEFERRED` on control signals; `Engine.time_scale` writes; `SceneTree.paused`; `duplicate_deep`; `Vector4` in hazard code; `randf`, `randomize`, global `shuffle` in Pattern; `CollisionObject3D`, `Area3D`, `RayCast3D`, `PhysicsServer`; `OS.is_debug_build()` in dev-input code; `Input.is_action_*` in gameplay; ADR-0010 presentation-time rules (`TIME` in `assets/shaders/**` and particle process materials; `create_tween`/`AnimationPlayer` outside ADR-0011 UI motion views; a presentation timer adding `real_dt`; `call_deferred`, Tween callback or `await` that moves the tube); ADR-0013 `Vector3(` built from `s`, `s_offset` or `snapshot.s` outside `world_frame.gd` in view code (ADVISORY, `forbidden:raw_s_in_vector3`). — source: ADR-0009 Decision 5
- `only_in` rules registered: `ConfigFile`/`FileAccess`/`DirAccess` only in `save_service.gd`; `ResourceLoader` only in `map_loader.gd`; `get_gravity`/`get_accelerometer`/`get_gyroscope`/`get_magnetometer` only in `tilt_input.gd`; `RenderingServer.global_shader_parameter_set` only in `render_globals.gd` (ADR-0012). — source: ADR-0009 Decision 5
- `project_setting` rules registered: no `[autoload]` entries for game systems; `emulate_mouse_from_touch` and `emulate_touch_from_mouse` true; only `enable_gravity` among sensor flags; `quit_on_go_back` false; handheld orientation 1; `physics/common/physics_interpolation` false (ADR-0013). — source: ADR-0009 Decision 5
- `manifest` rules registered: one Vulkan 1.1 `uses-feature`, VIBRATE only, `allowBackup=false`, and `exclude_filter` covering `tests/*`, `addons/gut/*`, `tools/*`, `build/*`; skipped with a warning until the first preset exists. — source: ADR-0009 Decision 5
- `custom` rules registered: Pattern seeds the `RandomNumberGenerator` before its first draw; typed method references (no string-built `Callable`) at the composition root; Scoring's reflection check. — source: ADR-0009 Decision 5
- Fixtures that are deliberately invalid GDScript live as `.txt` files or under a folder with a `.gdignore`; `build/` and `tools/` carry a `.gdignore`. — source: ADR-0009 Decision 5
- Registry coverage meta-rule (ADVISORY): the runner reads `docs/registry/architecture.yaml` and reports every `forbidden_patterns` entry with no rule `forbidden:<pattern>` and not marked `review_only`. — source: ADR-0009 Decision 5
- Lint rules apply to `src/` and, where stated, `tests/` and `tools/`; a rule whose scope has no file yet passes with a note. — source: ADR-0009 Decision 5
- The lints are tested: `tools/ci/tests/` holds Python `unittest` cases with one passing and one failing fixture per rule; a rule without both fixtures fails the runner's self-check. Use an explicit `allow` list field per rule. — source: ADR-0009 Decision 5 / Risks
- No line-coverage gate; the gate is: every Logic story has automated tests mapped to its GDD acceptance criteria (checked by `/story-done`, `/test-evidence-review`), unit + integration suites and lints pass, advisory tests are reported. — source: ADR-0009 Decision 6
- Add `exclude_filter="tests/*, addons/gut/*, tools/*, build/*"` when the first export preset is created; `addons/gut` and `tests/` are excluded from exports. — source: ADR-0009 Migration Plan / Performance
- Android export in CI (templates, keystore from secret) is a separate later workflow with its own review. — source: ADR-0009 Decision 4
- After acceptance, sync docs/skills: `coding-standards.md` CI line replaced with `python tools/ci/run_ci.py`; `technical-preferences.md` updated (GUT allowed, coverage policy); `/test-setup`, `/smoke-check`, `/test-helpers`, `/test-flakiness` switched from gdUnit4 to GUT. — source: ADR-0009 Decision 8
- `WorldFrame` is a pure engine-free `RefCounted` built by `GameRoot` at composition and injected into every view that places a node; it holds `origin_s` (float64, always an exact multiple of `L`, 0 at run start), `render_z(s) = -(s - origin_s)` computed in float64 (the only place world distance is cast to 32 bits), and `maybe_rebase(s)`. — source: ADR-0013 Decision 1
- `maybe_rebase(s)`: if `s - origin_s >= REBASE_SEGMENTS * L`, set `origin_s += floor((s - origin_s) / L) * L` (remainder in `[0, L)`) and return `true` once for that tick, else `false`. — source: ADR-0013 Decision 1
- `GameRoot._tick` runs a named `WorldFrame step` immediately after `TubeTrack.advance` and before `Obstacle.test`: `if _world_frame.maybe_rebase(ball.s): _tube_view.rebase(); _hazard_view.rebase()`. It runs only when `advance` ran (Running); Pause, Hit, Resuming and Menu never rebase. — source: ADR-0013 Decision 2
- `TubeView.rebase()` re-binds all N slots with `render_z`; `HazardView.rebase()` re-places every bound node through `render_z(its stored s_offset)` then calls `reset_physics_interpolation()`. — source: ADR-0013 Decision 2 / ADR-0014 Key Interfaces
- Project setting `physics/common/physics_interpolation` is pinned to `false`; the `project_setting` lint (ADR-0009) asserts it stays false. — source: ADR-0013 Decision 2
- `WorldFrame.on_run_reset(run_id)` sets `origin_s = 0` as a `_wire()` row at rank 1 (before Tube Track's adapter at rank 2 re-primes the window). — source: ADR-0013 Decision 2
- `WorldFrame.reset()` is called by the Tube Track adapter immediately before `to_idle()` (Paused to Menu, Hit to Menu), at the same call site; no new rank row. — source: ADR-0013 Decision 2
- `GameRoot` validates the `WorldFrame` config together with `WorldGeometry` at composition: `(REBASE_SEGMENTS + A + 1) * L <= Z_RENDER_MAX` else `REBASE_Z_EXCEEDS_BUDGET` (fatal at boot). — source: ADR-0013 Decision 4
- In debug builds `render_z` asserts `abs(result) <= 2 * Z_RENDER_MAX`. — source: ADR-0013 Decision 4
- `TubeMath.local_point(theta, h) -> Vector2` returns the x and y of the GDD frame `P` (no `s`); a view builds `Vector3(p.x, p.y, world_frame.render_z(s))`. The logical `P` with `z = -s` exists only as a test reference function. — source: ADR-0013 Decision 3
- The Camera core publishes only the angle and ball-relative offsets; `CameraView` places the eye at `local_point(phi_cam, CAMERA_RADIUS - R)` with z = `render_z(s_ball) + CAMERA_BACK_DISTANCE` and the look-at on the axis with z = `render_z(s_ball) - CAMERA_LOOK_AHEAD`. — source: ADR-0013 Decision 3
- Environment props use chunked `MultiMeshInstance3D` nodes with chunk-local instance transforms, each chunk placed through `render_z` and re-placed in a `rebase()` hook. — source: ADR-0013 Decision 3
- A future effect living across ticks decides explicitly in its own story: move with the ball (`GPUParticles3D` parented to the ball, `local_coords = true`) or anchor to the world (`local_coords = false`, must `restart()` on the rebase tick or accept one lifetime of gap); an effect with a stored anchor stores `s` (float64) and converts through `render_z` every tick, never a stored render position. — source: ADR-0013 Decision 3
- No shader reads world-space z (`WORLD_POSITION`, `MODEL_MATRIX[3]`, world-space noise, triplanar, dissolve) unless its period divides `REBASE_SEGMENTS * L`; keep such math in view or model space. — source: ADR-0013 Decision 3
- `WorldFrameConfig` is a validated Resource: `REBASE_SEGMENTS` default 84, range [24, 128]; `Z_RENDER_MAX` 2048 is a constant, not a knob. — source: ADR-0013 Key Interfaces
- `GameRoot` builds the one immutable `WorldGeometry` (`R`, `D`, `N_F`, `L`) at composition from the base `TubeConfig` and `BallConfig`, validates it before the first `MapLoader.attempt`, and passes the same value to `BallView.build`, `CameraMath.published` and `HazardView.apply_map`; `D` has one owner (Ball Movement) and `TubeConfig` holds no copy. — source: ADR-0014 Decision 4 / ADR-0012 Key Interfaces
- Composition/construction order: the Environment view node owning `WorldEnvironment` (fog sink target), then `WorldChroma`, then `BallView` and `HazardView`, then Environment and Juice (with injected sinks), then `_wire()`, then `MapLoader`. `BallView` is built before `MapLoader` runs. `GameRoot` keeps strong references to `WorldChroma` and `BallView`. — source: ADR-0012 Decision 4 / Decision 1
- A boot check asserts `ProjectSettings.has_setting("shader_globals/world_chroma")` and the same for `hit_grey`. — source: ADR-0012 Decision 4
- `GameRoot._wire()` gains the row `[_run_state.phase_changed, _ink_core.on_phase_changed, 5]`, with `_ink_core = InkCoverCore.new(clock_us, ink_config, settings.reduced_motion_getter, _juice.register_flash)`; `GameRoot._tick` is otherwise unchanged. — source: ADR-0010 Decision 6
- `GameRoot._tick` per-frame order gains `BallView.tick` right after `Camera.step` (the spy test of the order is updated), plus the `WorldFrame step` above. — source: ADR-0012 Decision 1 / ADR-0013 Decision 2
- All world changes happen inside `GameRoot._tick`; `GameRoot` calls `view.tick(real_dt)` at the Juice, HUD and Menus tick steps (cited by name). — source: ADR-0010 Decision 5 / ADR-0011 Decision 3
- Run State remains the sole owner of phase; a phase change is never delayed by presentation. — source: ADR-0010 Requirements
- `HazardView` handlers are `_wire()` rows ranked after Obstacle's emit and before `Juice.tick`, immediate connections; the phase rule hiding the hazard pool is wired from `phase_changed`. — source: ADR-0014 Decision 4
- `UiScaler` (a thin `Node`, no `_process`) sets `get_window().content_scale_factor` at construction and on every display-facts re-read (`app_foregrounded`, `app_returned`, window size change), only when the value differs and never while the phase is Running; `f = UiMetrics.dp_scale(screen_dpi) = clamp(dpi / 160.0, 0.75, 4.0)`; missing/non-positive dpi returns 1.0 and logs once. — source: ADR-0011 Decision 1
- `DisplayFacts` carries `screen_dpi: int`; the safe area is converted once by `UiMetrics.safe_area_dp(safe_px, window_px, f, max_width_dp)` (intersect with the window rect, divide by `f`, round to whole units, cap width at `UI_MAX_CONTENT_WIDTH_DP` and centre). — source: ADR-0011 Decision 1
- Any code reading the viewport size as pixels (ADR-0003, ADR-0006 display facts) is audited and uses `DisplayServer` pixel sizes, because `content_scale_factor` makes `get_visible_rect()` return dp. — source: ADR-0011 Decision 1
- `project.godot`: `display/window/stretch/mode = "canvas_items"`, `display/window/stretch/scale_mode = "fractional"`, `content_scale_size` left at `(0, 0)`, `display/window/stretch/scale` set to a first-frame value (2.625). Fonts are imported as dynamic (TTF or OTF). — source: ADR-0011 Decision 1
- `project.godot` declares `[shader_globals]` entries `world_chroma` (default 1.0) and `hit_grey` (default 0.0). — source: ADR-0012 Decision 3
- `WorldChroma` writes the two globals through an injected `globals_sink: Callable` whose real implementation (`render_globals.gd`, on the engine-call allowlist) is the only call site of `RenderingServer.global_shader_parameter_set`. — source: ADR-0012 Decision 4
- `input_devices/pointing/emulate_touch_from_mouse` stays on for editor runs. — source: ADR-0011 Decision 5

### Forbidden Approaches

- Never read `Input.get_accelerometer()`, the gyroscope or the magnetometer, and never set `input_devices/sensors/enable_accelerometer` (or gyroscope/magnetometer flags) true — one sensor source only; accelerometer fallback and plugin route rejected for the MVP — source: ADR-0005 Decision 1
- Never set `emulate_mouse_from_touch` false — stock `Button`s handle mouse/key events, not `InputEventScreenTouch`, so Pause/Menu/Restart/Resume/Play buttons would be dead on a phone — source: ADR-0005 Decision 2
- Never reference the editor-only synthetic sensor source outside an `OS.has_feature("editor")` check, and never gate it with `OS.is_debug_build()` — a debug APK sent to testers must not contain it — source: ADR-0005 Decision 6
- Never write to the loaded `MapDefinition`/`EnvConfig` resource (the cache may share it); always use the validated copy — source: ADR-0004 Decision 1
- Never add a back-edge from `EnvConfig` to `MapDefinition` or `MapConfig` — source: ADR-0004 Decision 1
- Never apply any Phase B step before Phase A passed entirely, and never send `map_ready` on failure or before B5 returned true — validate-first — source: ADR-0004 Decision 2
- Never free and recreate Tube Track's slots on Retry — source: ADR-0004 Decision 3
- Never rely on in-emission ordering of a deferred connection for hiding the failure screen — connections are immediate — source: ADR-0004 Decision 3
- Never use `unload_map` in the MVP — source: ADR-0004 Decision 1
- Never use threaded loading (`load_threaded_request`) for the MVP map load — adds Loading state, cancellation and async errors for a few KB file (pre-committed response only if MS-1 is too slow: switch only the `load_definition` seam) — source: ADR-0004 Alternatives 3
- Never wait for the timeout alone to show the map-load failure screen — a synchronous failure is known at once — source: ADR-0004 Alternatives 4
- Never store Camera values (`rear_extent`, `camera_distance`, `visible_arc_half_width`) in the map file — they are derivable; one owner per field — source: ADR-0004 Alternatives 1
- Never turn emulation off and write a custom `TouchButton` Control — more code, loses stock Button behavior, only testable on device — source: ADR-0005 Alternatives 5
- Never use a global `_input` with `Time.get_ticks_usec()` to stamp — breaks `mouse_filter` precedence and the injected-clock rule; use `_gui_input` — source: ADR-0005 Alternatives 4
- Never use `PAUSED/RESUMED` as the primary lifecycle signal or read them on Android — their reliability under Vulkan is unverified, a pause could be missed — source: ADR-0006 (Decision 2, Alternative 2)
- Never `call_deferred` lifecycle handlers on the main thread — a deferred flush may not run before the OS suspends the process — source: ADR-0006 (Alternative 3)
- Never run a lifecycle handler inside a Run State tick or handler (never send requests from there) — source: ADR-0006 (Implementation Guidelines)
- Never add a `ui_cancel` or `KEY_BACK` mapping for Back — one press could arrive twice — source: ADR-0006 Decision 4
- Never write an Android plugin (Kotlin) or GDExtension to work around Back in the MVP — second toolchain; only the escalation path if PS-4 proves Godot cannot deliver Back — source: ADR-0006 (Decision 1, 4, Alternative 1)
- Never ship a default Android export with no manifest management — no Vulkan Play filter, extra permissions, no AAB, no CI check — source: ADR-0006 (Alternative 4)
- Never declare two Vulkan `uses-feature` entries — Godot's default Vulkan 1.0 entry must be replaced — source: ADR-0006 Decision 8
- Never declare `INTERNET` or storage permissions in release builds — manifest must stay VIBRATE only (debug exports may add `INTERNET`) — source: ADR-0006 Decision 8 / 9
- Never package an OBB — removed in Godot 4.7 — source: ADR-0006 Decision 8
- Never commit a keystore, alias, password or debug keystore; release builds must not contain a debug keystore — signing lives outside the repository — source: ADR-0006 Decision 8 / Guidelines
- Never turn `screen_set_keep_on` off after boot — source: ADR-0006 Decision 7
- Never design a landscape layout and never stretch the UI on foldables/large screens — Android 16 ignores the portrait lock at 600 dp+ — source: ADR-0006 Decision 8
- Never use the Android Auto Backup (leave `android:allowBackup` true) — would restore an old/other-schema save or half-written `.tmp`/`.corrupt-*` file — source: ADR-0007 Decision 7
- Never call `ConfigFile`, `FileAccess`, `DirAccess`, `Time.`, `OS.` in `SaveCore` or `PersistMath` (or `SaveFs` base class) — pure core must be testable with a fake; real calls only in `save_service.gd` (AC-16/AC-17) — source: ADR-0007 Decision 8
- Never use `@abstract` (4.5) for `SaveFs` — plain base class with failing defaults — source: ADR-0007 Decision 1
- Never name the boot method `load` — shadows the global `load()` — source: ADR-0007 Key Interfaces
- Never reuse a `ConfigFile` instance across reads — a failed parse may leave partial sections — source: ADR-0007 Decision 3
- Never write a raw `Object`, or a NaN/infinite `float`, via `set_value` — round-trips badly (`UNSERIALIZABLE_VALUE`) — source: ADR-0007 Decision 4
- Never write the save with write-behind to `app_backgrounded` — a process killed without a callback would lose the best — source: ADR-0007 Decision 5 / Alternative 2
- Never call `set_value` on every slider `value_changed` — 60 writes per second wears the flash; commit on `drag_ended` — source: ADR-0007 Decision 5
- Never read any `.cfg` from another path or write any other file type for the save — source: ADR-0007 Decision 2
- Never replace `ConfigFile` with a custom JSON writer, SQLite or a GDExtension store without superseding the ADR — GDD/ACs written for `ConfigFile`, JSON turns numbers into floats, native dependency is unjustified — source: ADR-0007 Alternatives 1, 4
- Never rely on `fsync` from GDScript; guarantee is app-termination only, not power loss — source: ADR-0007 Context/Decision 6
- Never hardcode a separate GDD seam count (the "seven seams" wording is corrected to one facade plus three Callables) — source: ADR-0007 Decision 1
- Never use gdUnit4 unless spike T-1 fails (it is only the pre-committed fallback) — contradicts technical-preferences and six GDDs — source: ADR-0009 Alternative 1
- Never write a custom SceneTree test runner — reinvents assertions, reports, discovery — source: ADR-0009 Alternative 2
- Never use a Windows runner, third-party Godot Docker image, or local-only scripts for CI — slower/costlier, version lag and supply-chain surface, cannot gate a merge — source: ADR-0009 Alternative 3
- Never write lints in GDScript or shell — comment/string stripping is fragile and untestable; use Python 3 stdlib — source: ADR-0009 Alternative 4
- Never add a line-coverage gate — needs an unverified third-party tool and yields line-touching tests — source: ADR-0009 Alternative 5
- Never download GUT in CI, never fetch the Godot checksum file from the same release at run time, never use a moving action tag, never cache `.godot/` in the MVP — supply-chain and stale class-cache risk — source: ADR-0009 Decision 4
- Never trust a green Godot exit code alone — run can print `SCRIPT ERROR`/`Parse Error` and exit 0, or skip a broken test file — source: ADR-0009 Decision 3
- Never retry, skip, mark `pending`, or disable a failing test to get a green run — fix it, or delete it with a written reason — source: ADR-0009 Decision 7
- Never use inline ignore comments for lints — use the rule's explicit allowlist field — source: ADR-0009 Risks
- Never have unit tests touch the real file system, `ResourceLoader` or `Time`; never use generated seeds or time-dependent assertions; never assert visual fidelity, feel or shader output — source: ADR-0009 Decision 2 / 7
- Never make `tests/support/` depend on GUT or name fakes like GUT classes (`Double`, `Spy`); never add an `[editor_plugins]` entry unless the editor panel is wanted — source: ADR-0009 Decision 1
- Never let Godot import `build/` or `tools/` — they carry a `.gdignore` — source: ADR-0009 Decision 5
- Never put secrets in the CI workflow — none are used or needed (Android export CI is a separate later workflow) — source: ADR-0009 Decision 4
- Never create effect nodes that outlive a rebase (Hit shards are created in Hit where no rebase runs, and cleared by `run_reset`) — source: ADR-0013
- Never call `global_shader_parameter_add` for `world_chroma` or `hit_grey` — would error and break the editor preview — source: ADR-0012
- Never write `content_scale_factor` while the phase is Running or on every `size_changed` burst — glyph re-rasterization and hitch — source: ADR-0011
- Never evaluate `-s` outside `WorldFrame` and `TubeMath`; `TubeMath` has no function returning a `Vector3` built from `s` — source: ADR-0013

### Performance Guardrails

- Boot map-load sequence (load, validate, prime): target at most 100 ms on a mid-tier phone (spike MS-1); threaded `load_definition` only if exceeded. — source: ADR-0004 Validation Criteria
- `SENSOR_START_TIMEOUT` = 2.0 s. — source: ADR-0005 Decision 1
- `poll()` p95 at most 0.1 ms over 1000 frames (P-1); end-to-end input latency budget 100 ms (P-2). — source: ADR-0005 Validation Criteria / Risks
- 10-minute run on a mid-tier Android phone shows no dropped frames attributable to orchestration, at 60 Hz and on a 120 Hz device. — source: ADR-0002 Validation Criteria
- Frame cap `application/run/max_fps = 60`; frame time 16.6 ms; memory ceiling 512 MB. — source: ADR-0006 Decision 7 / Performance
- Minimum SDK 28 (Android 9); Vulkan 1.1 (`0x401000`); arm64-v8a only; 16 KB page alignment; target SDK 36 expected (confirm at release). — source: ADR-0006 Decision 8
- UI starting margins 40 dp and 16 dp; large-screen threshold 600 dp. — source: ADR-0006 Decision 6 / 8
- `app_backgrounded` flush is a few KB; Android gives roughly a few seconds before a cached process may be killed. — source: ADR-0006 Decision 3
- Save file holds a few hundred bytes; `SAVE_FILE_SIZE_MAX` caps a hostile file at 64 KB before parsing. — source: ADR-0007 Context / Performance
- SP-3: `set_value` p95 at most 3 ms over at least 1000 writes (maximum reported, at most 8 ms), measured idle and during a hit-frame replay on a mid-tier phone; expected 1 to 3 ms. — source: ADR-0007 Decision 5
- SP-1: zero corrupted `save.cfg` over 3 kill points and 20 repetitions each on a real device. — source: ADR-0007 Validation
- A 10-second slider drag with commit on drag end writes exactly once. — source: ADR-0007 Validation
- Numeric test tolerances: exact `==` for integers/codes/counts; `1e-6` for floats unless an AC states otherwise. — source: ADR-0009 Decision 7
- Full CI run at most 5 minutes after cache is warm. — source: ADR-0009 Decision 4
- Engine version must be exactly `4.7.2` in CI. — source: ADR-0009 Decision 3
- `REBASE_SEGMENTS` default 84 (range 24 to 128), `Z_RENDER_MAX` = 2048 u; defaults give `(84 + 9 + 1) * 12 = 1128 <= 2048`, render z never exceeds about 1130 u; rebase about every 40 s at `V_MAX`. — source: ADR-0013 Decision 4
- 8-ulp error at 2048 is 0.00195 u, inside the 0.0024 u requirement. — source: ADR-0013 Decision 4
- `UiMetrics.dp_scale` clamp 0.75 to 4.0; `UI_MAX_CONTENT_WIDTH_DP` proposal 480. — source: ADR-0011
- Boot: hazard prewarm shares ADR-0004's MS-1 boot budget (100 ms for load, validate, apply and Tube Track prime). — source: ADR-0014 Decision 4
- Rebase tick cost is negligible (about 12 slots + 10 to 17 hazard nodes, microseconds). — source: ADR-0013 Performance

### Engine API Constraints

- NEEDS VERIFICATION (ADR-0004; spike MS-1 for item 6): `ResourceLoader.load("res://.../map_01.tres")` works in an Android export (text resources converted to binary and remapped); cache-mode names/effects (`CACHE_MODE_IGNORE` does not carry into external sub-resources; `CACHE_MODE_IGNORE_DEEP` may exist; confirm in 4.7 class reference); missing/corrupt resource returns `null` with an engine error and does not crash, and `as MapDefinition` yields `null` for a wrong type; typed exported properties (`@export var env: EnvConfig`) round-trip in an export (needs the `class_name` cache); `Resource.duplicate()` is shallow and enough for a scalar-only `TubeConfig`, and a `.tres` coerces an `int` written into a `float` field (declare floats and write `1.0` in the file); load, validate and prime time on a mid-tier phone (MS-1). — source: ADR-0004 Verification Required
- `ResourceLoader.load`, `ResourceLoader.exists`, `Resource.duplicate` (shallow) predate the cutoff; `duplicate_deep()` (4.5) is not used. — source: ADR-0004
- NEEDS VERIFICATION (ADR-0005; spike V-1 for sensor sign and units): `Input.get_gravity()` on Android 4.7.2 returns the gravity vector in m/s^2 and the zero vector when no gravity sensor; ProjectSettings names/defaults (`enable_gravity` default false and baked into an export; sibling sensor flags false; `display/window/handheld/orientation` portrait = 1; `emulate_mouse_from_touch` default true; `emulate_touch_from_mouse` default false, project-wide); `get_gravity()` believed ~50 Hz so some 60 fps frames read stale (spikes V-1, P-1, P-2); stock Buttons fire on a real phone with emulation on, one tap gives exactly one catcher action, and order of emulated mouse press vs `ScreenTouch` (recorded as mouse first then ScreenTouch on 4.7.2, re-check on a phone); `InputEventScreenTouch.canceled` handling; touch events reach `Control._gui_input` and respect `mouse_filter`, a second finger arrives with `index >= 1`; stamp lag at most ~one frame plus OS-to-engine queue delay (60 fps video capture); touch focus on Buttons under the 4.6 dual-focus change (ADR-0011); the boot manifest check can tell "sensor flag missing" from "no sensor"; `application/config/quit_on_go_back` and predictive back (ADR-0006). — source: ADR-0005 Verification Required
- Knowledge risk HIGH: 4.7 renumbered keyboard/mouse device IDs; 4.6 split touch focus from keyboard focus. — source: ADR-0005
- NEEDS VERIFICATION (spikes PS-1, PS-2 on device): order/presence of `NOTIFICATION_APPLICATION_FOCUS_OUT/IN` and `PAUSED/RESUMED` under Vulkan for Home, lock, call, notification shade, app switcher, split-screen; Home/lock/switcher expected `FOCUS_OUT` then `PAUSED`, shade/banner `FOCUS_OUT` only. — source: ADR-0006
- NEEDS VERIFICATION (spike PS-12): the thread on which Android lifecycle callbacks arrive. — source: ADR-0006
- NEEDS VERIFICATION (spike PS-4, release blocker if failing): `NOTIFICATION_WM_GO_BACK_REQUEST` delivery on Android 13+ predictive back and Android 16 / SDK 36; `quit_on_go_back` semantics; predictive back opt-in/out (`android:enableOnBackInvokedCallback`); the same press never arrives twice. — source: ADR-0006
- NEEDS VERIFICATION: `Input.vibrate_handheld(duration_ms, amplitude)` amplitude behavior and VIBRATE permission; `DisplayServer.get_display_safe_area()` under edge-to-edge (asynchronous insets) and `screen_get_refresh_rate()`; `DisplayServer.screen_set_keep_on(true)` with battery saver; `NOTIFICATION_OS_MEMORY_WARNING`. — source: ADR-0006
- NEEDS VERIFICATION: export preset key names (Gradle, AAB, min/target SDK, architectures, immersive, orientation, permissions) until the first preset exists; `uses-feature` keys/values; 4.7.2 templates 16 KB aligned; Android 16 large-screen `screenOrientation` override; Godot 4.7 supports `minSdk 28`. — source: ADR-0006
- Post-cutoff APIs used: 16 KB page support (4.5), edge-to-edge (4.5), OBB removed (4.7); `DisplayServer` safe-area/refresh-rate queries unverified on 4.7.2. — source: ADR-0006
- 60 fps cap on a 90/120 Hz panel may judder: pacing test on a 120 Hz device (PS-9). — source: ADR-0006 Risks
- Open (out of scope): OS audio policy owner (Platform Services OQ20) and `NOTIFICATION_OS_MEMORY_WARNING` handling against the 512 MB ceiling. — source: ADR-0006 Decision 10
- NEEDS VERIFICATION (SP-1 prerequisite, Android and Windows CI host): whether `DirAccess.rename_absolute(from, to)` replaces an existing destination in one filesystem step. — source: ADR-0007
- NEEDS VERIFICATION (SP-2, BLOCKING): `ConfigFile.load` Error/typing on truncated, binary, oversized or hand-crafted files, and whether `VariantParser` can instantiate objects while parsing. — source: ADR-0007
- NEEDS VERIFICATION: `ConfigFile.save` returns non-`OK` on disk full/permission failure (may return `OK` with truncated file, hence the `size(TMP) > 0` check); `FileAccess.open(READ).get_length()` is cheap; `DirAccess.open("user://").get_files()` lists backups; `user://` resolves to app-private storage (`OS.get_user_data_dir()`); `ConfigFile` preserves `int` vs `float` on round trip; stable section order; empty file loads `OK` with no sections. — source: ADR-0007
- NEEDS VERIFICATION (SP-3, new, blocking): write latency of the full `set_value` path on a mid-tier Android phone. — source: ADR-0007
- NEEDS VERIFICATION: how `android:allowBackup="false"` is applied (preset key unknown; check merged manifest of first export; Android 12+ data-extraction rules). — source: ADR-0007
- Post-cutoff: `FileAccess.store_*` returns `bool` since 4.4 (relevant only if `ConfigFile.save()` is ever replaced by a hand-written writer). — source: ADR-0007
- NEEDS VERIFICATION (spike T-1, Windows and Linux, 4.7.2): GUT release loads without parse errors under 4.5 to 4.7 GDScript changes; exact headless command options (`-s addons/gut/gut_cmdln.gd`, `-gdir`, `-ginclude_subdirs`, `-gexit`, `-gjunit_xml_file` or `.gutconfig.json`); non-zero exit code on failing test; JUnit XML written and readable by `/test-flakiness`; SceneTree `[N]` tests run under `--headless`; `class_name` fixtures resolve after `--import` (class cache; `godot --headless --import` required before headless test runs); GUT discovers `*_test.gd` with prefix empty/suffix `_test.gd`; GUT CLI works without enabling the plugin; whether `--import` needs a second pass; whether `SCRIPT ERROR`/`Parse Error` still exit 0; `--import` time and whether caching `.godot/` is safe; Linux 4.7.2 binary runs headless on Ubuntu without a display; official download URL and checksum for `Godot_v4.7.2-stable_linux.x86_64.zip` (`godotengine/godot-builds`, `4.7.2-stable`). — source: ADR-0009
- GUT release choice: newest release whose notes name Godot 4.5 or later, otherwise the latest tested on 4.7.2. — source: ADR-0009 Decision 1
- PRC-1 (device spike): frame capture across a rebase at 60 and 120 Hz shows no pop; measure the 8-ulp model at the largest placed z just before a rebase; assert shadow-off and physics-interpolation-off; unverified: default Godot builds use 32-bit transforms, whether Mobile computes camera-relative transforms in 32 or 64 bit. — source: ADR-0013 Verification
- `reset_physics_interpolation()` (available since 4.3) is called in `rebase()` as belt and braces. — source: ADR-0013 Decision 2
- Spike UI-1 (device): `canvas_items` with `content_scale_size = (0, 0)` and `content_scale_factor = dpi / 160` gives one viewport unit per dp; `DisplayServer.screen_get_dpi()` on Android returns OS density (log raw value next to `displayMetrics.density * 160`, test smallest and largest Display size); run-time `content_scale_factor` change re-lays out within one frame without disturbing the 3D viewport or `scaling_3d`; fallback `stretch/mode = disabled` plus `content_scale_factor`, then manual `dp()`. — source: ADR-0011 Verification
- Global shader parameters on Mobile/Forward+ (declaration in `project.godot`, defaults on first frame, per-frame cost, effect same frame, headless no-ops) are unverified on 4.7.2; R-1 checks 1, 2 and 7; fallback is per-material writes behind the same `globals_sink`. — source: ADR-0012 Verification
- `CanvasLayer.visible = false` blocking GUI input is NEEDS VERIFICATION (add one assertion to the ADR-0011 integration test). — source: ADR-0010 / ADR-0011

---

## Core Layer Rules

*Applies to: tube track, ball movement, obstacle system, tilt input, hazard compile/bind/collision*

### Required Patterns

- `TiltInput.poll()` is called by `GameRoot` once per rendered frame in every phase (including Paused), before Ball Movement steps; `TiltInput` has no `_process`. — source: ADR-0002 Decision 6 / ADR-0005 Constraints
- `TiltInput.poll()` reads `Input.get_gravity()` once per frame and passes the raw `Vector3` (m/s^2, float32) to `TiltCore`; it guards non-finite and oversized vectors (Tilt F1: `G_MIN` 3 m/s^2). — source: ADR-0005 Decision 1 / Implementation Guidelines
- Do not smooth or filter in the `TiltInput` node; `TiltCore` owns the pipeline (neutral, dead zone, filter). — source: ADR-0005 Implementation Guidelines
- If no valid sample (zero vector or non-finite) arrives within `SENSOR_START_TIMEOUT` (2.0 s) after boot, `TiltCore` goes Unavailable (`valid` false); Menus gates Play and shows `No motion sensor` ("device not supported"). — source: ADR-0005 Decision 1
- Only the `TiltInput` node may read motion sensors. — source: ADR-0005 Constraints
- The `TiltInput` interface: `poll()`, read-only `steer`, `valid`, `input_source`. — source: ADR-0005 Key Interfaces
- Tube Track: `TubeTrack.advance` runs in Running only; `TubeView.idle_step(real_dt)` is called only when the phase is Menu (Paused, Hit and Resuming keep the tube still). — source: ADR-0002 Decision 6
- Tube Track view creates `N` (= 12) `MeshInstance3D` slots once at `load_map`, all referencing one `ArrayMesh` and one `ShaderMaterial`; keep every slot on the same Mesh and Material resource. — source: ADR-0003 Decision 2 / Implementation Guidelines
- `slot_binder(slot_index, segment_index)` only sets the slot's transform (z from `WorldFrame.render_z(segment_index * L)`, ADR-0013) and calls `reset_physics_interpolation()` on recycle (or slots set `physics_interpolation_mode = OFF`). — source: ADR-0003 Decision 2
- Tube Track set `cast_shadow = OFF` on slots. — source: ADR-0003 Decision 2
- Tube Track pulls the Settings `seam_contrast_scale` getter every frame in every state and writes the material only when the value changed. — source: ADR-0003 Decision 2
- Tube mesh: 32-facet cylinder, axis along Z, flat normals from duplicated vertices; build the `ArrayMesh` from raw arrays with explicit analytic facet normals. — source: ADR-0003 Decision 2 / Implementation Guidelines
- The seam is a segment-local analytic shader pattern (identical in every segment) with no per-frame `s` uniform; no `CollisionObject3D` on the tube. — source: ADR-0003 Decision 2 / Constraints
- Dynamic shared inputs on the tube material are limited to: `seam_contrast_scale`, the per-event progress uniform in [0, 1] of the event shaders (ring pulse, PB bloom and sweep), the two global shader parameters of ADR-0012 (written only through `render_globals.gd`), and the near-miss ball-position uniform. — source: ADR-0003 Decision 2
- `TubeView` interface: `build(cfg, mesh, mat)`, `bind_slot(slot_index, segment_index)` (transform only), `idle_step(dt)`, `set_seam_contrast_scale(v)`, `rebase()`; no `_process`. — source: ADR-0003 Key Interfaces
- Tube Track `load_map` is accepted only from Uninitialized; `TubeConfig.validate()` owns the Tube Track derived constraints (e.g. `FOG_BEFORE_READ`). — source: ADR-0004 Constraints / Decision 2
- Obstacle `apply_map` receives `visible_arc_half_width` (B2); Obstacle swept hit test runs in the same tick domain as Ball Movement's publish, with no physics catch-up. — source: ADR-0004 Decision 2 / ADR-0002 Constraints
- The Hit tap catcher is a `Control` whose `_gui_input(event)` reads `var press_us: int = clock_us.call()` on its first line and reacts only to `InputEventScreenTouch` with `pressed == true` on any touch index. — source: ADR-0005 Decision 3
- Stock `Button`s (Pause, Menu, Restart, Resume, Play, Settings, Retry, Back, QUIT, Cancel): the `button_down` handler reads `clock_us` on its first line to stamp `press_us`; activation happens on `pressed` (release inside). — source: ADR-0005 Decision 3
- Use `mouse_filter` to decide which Control receives the touch, so Pause and Menu buttons win over the Hit tap catcher. — source: ADR-0005 Decision 3
- Game buttons set `focus_mode = FOCUS_NONE`; Pause and Menu stay out of the screen-edge band. — source: ADR-0005 Decision 3
- Stamp `press_us` in the same microsecond clock domain as Run State (injected `clock_us`); one stamp per tap, one tap gives one action. — source: ADR-0005 Constraints / Validation Criteria
- A press that starts outside a button and slides in does not activate it (release-inside rule); a cancelled touch gives no activation. — source: ADR-0005 Implementation Guidelines
- Test that one tap gives exactly one catcher action, a second finger produces its own stamped press and cancels nothing, and a cancelled touch activates no Button. — source: ADR-0005 Validation Criteria
- Authored hazard content is a typed Resource tree: `ChunkLibrary` (`chunks: Array[ChunkDef]`) > `ChunkDef` (`chunk_id: StringName`, `tier`, `segment_count` 1..3, `placements`) > `HazardPlacement` (`hazard_type`, `local_segment_index`, `pieces`, `solution_angles: PackedFloat64Array`) > `HazardPiece` (`theta_min`, `theta_max`, `s_start`, `s_end`), stored as `.tres` (library `assets/data/chunks/chunk_library_01.tres`, each ChunkDef its own file `assets/data/chunks/<chunk_id>.tres`). — source: ADR-0008 Decision 1
- `HazardPiece` angles are unwrapped (a seam-crossing piece has `theta_max > PI` or `theta_min < -PI`); `s_start`/`s_end` are chunk-local inside `[k*L, (k+1)*L)` for its segment k. — source: ADR-0008 Decision 1
- `solution_angles` is stored explicitly (one for Wall and Near-Ring, two for Double Gate, none for Spike); the preflight checks each lies inside a real safe gap. — source: ADR-0008 Decision 1
- `Tier` (INTRO | RAMP | FULL) and `HazardType` (WALL | SPIKE | DOUBLE_GATE | NEAR_RING) are enums with explicit integer values (`WALL = 0`, `SPIKE = 1`, ...); authored classes are data only and not `@tool`. — source: ADR-0008 Decision 1
- Tier pools are supersets (RAMP includes INTRO, FULL includes all); a chunk's `tier` is the first tier that may draw it. — source: ADR-0008 Decision 1
- Authored Resources are read once at compile and never mutated or copied at run time. — source: ADR-0008 Decision 1
- `Pattern.apply_map(map)` calls `ChunkLibraryCompiler.compile(map.chunk_library, ...)` which runs structural checks and builds a `CompiledLibrary` (RefCounted) of per-tier pools of `CompiledChunk`, each placement an immutable runtime `HazardSpec` (RefCounted: `hazard_type`, `local_segment_index`, `pieces` as 4 floats per piece in a `PackedFloat64Array`, `solution_angles`); no setters. — source: ADR-0008 Decision 2
- Structural compile checks (always run, O(pieces)): finite values; `theta_min <= theta_max` with width `< 2*PI`; `s_start <= s_end` inside the owning segment; `segment_count` 1 to 3; `local_segment_index` in range; at most `MAX_PIECES_PER_SEGMENT` per segment; non-empty pool per tier; at least `GRACE_POOL_MIN_SIZE` grace-compliant INTRO chunks. Failure returns the code set and `Pattern.apply_map` returns false (`MAP_APPLY_FAILED`). — source: ADR-0008 Decision 2
- In debug builds the full preflight also runs at map load as an assertion; in release builds only structural compile checks run on the device. — source: ADR-0008 Decisions 2, 5
- `PatternCore` is the `HazardContentProvider`: `hazards_for_segment(segment_index) -> Array[HazardSpec]` returns shared specs (no copy); the base class is a plain `RefCounted` returning an empty array (no `@abstract`), faked in tests; it is called once per index in increasing order. — source: ADR-0008 Decisions 2, 8
- When a segment enters the window, `ObstacleCore` calls `hazards_for_segment(i)` once and per spec assigns `hazard_id` and builds a world-space footprint: `s_offset = (i - spec.local_segment_index) * L`, 4 values per piece (`theta_min`, `theta_max`, `s_start + s_offset`, `s_end + s_offset`); record `{hazard_id, home_segment = i, hazard_type, footprint, s_lo, s_hi}`. — source: ADR-0008 Decision 3
- `ObstacleMath` and `NearMissMath` keep their approved world-space float64 formulas (F1 to F5, Near-Miss reuse) on the flat array; no offset arithmetic outside the bind. — source: ADR-0008 Decision 3
- `hazard_bound(hazard_id: int, footprint: PackedFloat64Array)` carries the world-space array; `hazard_released(hazard_id, released_by_reset: bool)` unchanged; Juice reads `ObstacleCore.footprint_of(hazard_id)` and `hazard_type_of(hazard_id)`. — source: ADR-0008 Decision 3
- Collision is fully analytic (swept AABB: `s_hit`, `theta_hit` with one `fposmod`, expanded by `BALL_HALF_ANGLE` and `D/2`), float64, run once per tick in `GameRoot._tick` right after `TubeTrack.advance` (order: `Ball.step`, `TubeTrack.advance`, `Obstacle.test`, `NearMiss.step`) on the published `(theta_prev, theta, s_prev, s)`. — source: ADR-0008 Decision 4
- Broad phase: compare per-hazard `s_lo`/`s_hi` (expanded by `D/2`) with the tick's swept `s` range first and skip non-intersecting hazards without touching pieces; Near-Miss reuses the same early-out. — source: ADR-0008 Decision 4
- `hit_reported(hazard_id, run_id)` is emitted by `ObstacleCore` and connected to Run State's handler in the `_wire()` rows, immediately (never deferred); `Obstacle.test` runs before `NearMiss.step` so a hit is applied before Near-Miss's exit-edge check. — source: ADR-0008 Decision 4
- Compile and preflight run on the main thread; if the library is ever loaded with `load_threaded_request`, compile only after the load completes. — source: ADR-0008 Decision 4
- `MapDefinition.chunk_library: ChunkLibrary` (replaces ADR-0004's placeholder type). — source: ADR-0008 Decision 7
- Key interfaces: `HazardContentProvider.hazards_for_segment`, `ChunkLibraryCompiler.compile(library, config, segment_length, log_sink) -> CompiledLibrary` (null on structural failure), `ContentPreflight.run(library, cfg) -> Array[Dictionary]`, `ObstacleCore` signals/accessors above. — source: ADR-0008 Key Interfaces
- Export smoke test: the library loads from the exported package and compiles. — source: ADR-0008 Validation
- `BallView` `set_luminance_target` is the only Environment entry point to the ball material; `ObstacleCore` emits `hazard_bound(hazard_id, footprint)` unchanged (ADR-0008) and gains read accessors `spec_of(hazard_id) -> HazardSpec` and `s_offset_of(hazard_id) -> float`, valid during the emission (Obstacle records state before it emits; tested). — source: ADR-0012 Decision 1 / ADR-0014 Decision 4
- `CameraCore.step(theta, s, dt_eff)` is unchanged and stays a frozen no-op at `dt_eff <= 0`, leaving `phi_cam`, position and `d_cam` bit-identical (TR-camera-009). — source: ADR-0010 Decision 4
- `CameraCore` gains an injected `clock_us`; `apply_fov_punch(amount, duration)` stamps `punch_us`; `fov_offset_deg()` returns `PresentationMath.ease_out_linear(amount, duration, elapsed)`; a new call replaces the previous punch; `on_run_reset(run_id)` clears the punch. — source: ADR-0010 Decision 4
- Camera reads the Ball snapshot or core, never `BallView`'s transform. — source: ADR-0012 Decision 1
- `ObstacleCore` and `CameraCore` keep `s` as float64 and publish offsets, never a world-z `Vector3`. — source: ADR-0013 Decision 3

### Forbidden Approaches

- Never let the Hit tap catcher react to `InputEventMouseButton` (the emulated duplicate) — one tap must give one action — source: ADR-0005 Decision 3
- Never filter touch by index or cancel anything on a second finger — a second finger is a legal restart tap; Run State's lock and idempotence absorb duplicates — source: ADR-0005 Decision 3
- Never have both a tap catcher and a Button act for one tap — source: ADR-0005 Decision 3
- Never use multi-touch or gestures — Pillar 4 anti-pillar, one input axis, one-handed — source: ADR-0005 Constraints
- Never use `mouse_behavior_recursive` (4.5) for hidden HUD subtrees in the MVP (use `visible = false` plus full-screen STOP blockers, ADR-0011 Decision 5) — source: ADR-0005 Implementation Guidelines
- Never assume a hardware event timestamp for `press_us`; the handler time can lag the touch by about one frame — source: ADR-0005 Decision 4
- Never use MultiMesh (R2) or a scrolling seam shader (R3) for the tube in the MVP — R2 is only the escalation path; R3 forces a treadmill rebase and couples rendering to the precision decision — source: ADR-0003 Alternatives 3 and 4
- Never allocate or free tube slots during a run — source: ADR-0003 Decision 2
- Never use real-time shadows — flat-shaded look comes from the material — source: ADR-0003 Decision 5
- Never use `CollisionObject3D`, `Area3D`, `RayCast3D` or `PhysicsServer3D` for hazard hit tests — analytic swept test is exact, deterministic, physics-sub-step independent — source: ADR-0008 (Decision 4, Alternative 5)
- Never call `duplicate()` or `duplicate_deep()` on hazard Resources (supersedes TR-obstacle-system-010) — HIGH-risk 4.7 API and many small allocations; share immutable specs — source: ADR-0008 Decision 3 / Alternative 3
- Never mutate a loaded (cached) Resource anywhere in the content path — source: ADR-0008 Decision 1 / Validation lint
- Never use `Vector2`, `Vector3`, `Vector4` for footprints — single precision in default builds; use float64 `PackedFloat64Array` — source: ADR-0008 Verification item 7 / Validation lint
- Never add a driver node, `process_priority` or physics catch-up for the hit test — the test runs in `GameRoot._tick` — source: ADR-0008 Decision 4
- Never defer the `hit_reported` connection — must be immediate — source: ADR-0008 Decision 4
- Never call `Obstacle.test` after `NearMiss.step` — hit must be applied before the exit-edge check — source: ADR-0008 Decision 4
- Never store hazard content as JSON parsed into RefCounted objects or as GDScript constant tables — no inspector/editor tooling, hand-written parser, content mixed with code against the data-driven rule — source: ADR-0008 Alternatives 1, 2
- Never use content guard bands or preflight-only pair rejection instead of generalized sequencer padding — constrains chunk design or removes legal chunks — source: ADR-0008 Alternative 4
- Never make authored classes `@tool` or add methods tooling must call — a non-`@tool` Resource loads as a placeholder in the editor (data only) — source: ADR-0008 Decision 1 / Verification item 9
- Never reorder enum values — silently changes every stored `.tres` — source: ADR-0008 Decision 1
- Never run the full preflight (P1 to P3) on the device in release builds — source: ADR-0008 Decision 5
- Never put a `CollisionObject3D` on the ball (Ball Movement AC-26) — source: ADR-0012
- Never put cosmetic roll/lean state in the Ball core — they are stateless view functions (Ball Movement TR-019) — source: ADR-0012
- Never extend the `hazard_bound` signal payload — keeps ADR-0008's contract — source: ADR-0014
- Never call Obstacle's `spec_of` / `s_offset_of` accessors outside the `hazard_bound` emission — HazardView stores `s_offset` in its own per-node record — source: ADR-0014

### Performance Guardrails

- Tube Track: 12 draw calls (provisional, measured in R-1 as a delta). — source: ADR-0003 Decision 7
- Obstacle test: 1 swept hit test per published pair. — source: ADR-0002 Context
- Tilt ring buffer of 256 samples (about 4 KB). — source: ADR-0005 Performance
- `poll()` p95 at most 0.1 ms. — source: ADR-0005 Performance
- `press_us` lag at most about one frame plus the OS-to-engine queue delay, measured against 60 fps capture. — source: ADR-0005 Decision 4 / Validation Criteria
- Sensor refresh believed ~50 Hz, so some 60 fps frames reuse the previous sample (counted in the P-1/P-2 latency budget). — source: ADR-0005 Decision 1
- At most 192 pieces tested bound (12 pieces per segment x 16 segments in window); broad phase leaves about 24 pieces tested at once. — source: ADR-0008 Constraints / Decision 4
- `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case on a mid-tier phone (spike OB-1, advisory until the first-playable profiling pass). — source: ADR-0008 Decision 4
- `segment_count` 1..3; at most `MAX_PIECES_PER_SEGMENT` pieces per segment; at most 16 window segments live. — source: ADR-0008 Decisions 1, 2 / Performance
- Compiled library resident for the session (tens of chunks, a few KB). — source: ADR-0008 Performance
- Footprint is a rectangle in `(theta, s)` expanded by `BALL_HALF_ANGLE` and D/2; a sphere at riding radius touching a radial plane has centre distance `(R + D/2) * sin(delta_theta)` (the silhouette must match this). — source: ADR-0014 Decision 2

### Engine API Constraints

- `Input.get_gravity()` unverified on 4.7.2: spike V-1 (sensor sign `SENSOR_SIGN` expected -1, units m/s^2, no zero vector) on at least two Android makers is blocking for the first playable and must run before any tilt tuning value is locked. — source: ADR-0005 Validation Criteria / Ordering Note
- Spikes P-1 and P-2 for poll cost and end-to-end latency. — source: ADR-0005 Risks
- `Node3D`/`MeshInstance3D` `custom_aabb`: slots need none (the mesh AABB follows the node transform); required only if a vertex shader ever moves vertices. — source: ADR-0003 Decision 2
- `SurfaceTool.set_smooth_group(-1)` is unconfirmed; do not rely on it. Fallbacks for flat shading: a `flat` varying, or a derivative normal (`dFdx`/`dFdy`, per-pixel cost, 2x2-quad artifacts). — source: ADR-0003 Implementation Guidelines
- Gate R-1 (flat shading faceted, no smoothing seams, on device) — source: ADR-0003 Verification Required
- NEEDS VERIFICATION: typed arrays of custom Resources (`Array[HazardPiece]`, `Array[HazardPlacement]`, `Array[ChunkDef]`) round-trip in a `.tres` and in an Android export; `PackedFloat64Array` and `float` exports keep float64 precision in text and binary resources; exported enums store/load as int with explicit values. — source: ADR-0008
- NEEDS VERIFICATION: GDScript `float` arithmetic is 64-bit end to end. — source: ADR-0008
- Spike OB-1: per-tick cost of the 192-piece worst case on a mid-tier phone. — source: ADR-0008
- `duplicate_deep()` (4.5) and `@abstract` (4.5) are not used; no post-cutoff APIs used. — source: ADR-0008 Engine Compatibility
- `docs/engine-reference/godot/modules/physics.md` is verified only to 4.6 and is not needed (no physics node used). — source: ADR-0008

---

## Feature Layer Rules

*Applies to: pattern and difficulty, near-miss detection, scoring and personal best*

### Required Patterns

- Pattern reseeds before Tube Track primes: `run_reset` rank 1 (Pattern and `WorldFrame`) precedes rank 2 (Tube Track adapter and Obstacle). — source: ADR-0002 Context / Decision 7
- Per-frame order for feature systems: `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, all after `TubeTrack.advance` and `WorldFrame step`. — source: ADR-0002 Decision 6
- Obstacle reports before Near-Miss reads; Juice latches before Scoring emits (`run_ended` rank: Juice; Scoring; HUD; the rest; `run_abandoned`: Juice; Scoring; the rest). — source: ADR-0002 Context / Decision 7
- Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload. — source: ADR-0002 Decision 5 / GDD Requirements Addressed
- Pattern `apply_map` (B3) receives the shared `chunk_library`; the library is immutable and never copied. — source: ADR-0004 Decision 2 / Constraints
- `HazardSpec`, `HazardPiece` and the chunk library are immutable shared resources, never copied. — source: ADR-0004 Constraints
- The `ChunkLibrary` type is defined by ADR-0008, which must replace the placeholder type of `MapDefinition.chunk_library` before the Pattern epic starts; the library content is checked by ADR-0008's own validator. — source: ADR-0004 Ordering Note / A4
- The Pattern sequencer read history is every read, Spikes included: entry `(s_start, s_end, solution_angles)` with `s_start` = earliest piece s, `solution_angles` empty for SPIKE. — source: ADR-0008 Decision 6
- Sequencer spacing: `opposing(p,q)` = any angle pair with abs(delta_theta) > `ANGULAR_REVERSAL_THRESHOLD` (false if either set empty), using the wrapped angular difference (at most PI); `req_spacing = max(S_MIN_SPACING, DODGE_RECOVERY_S if opposing else 0)`; `req_clear = D` (`q.s_start - p.s_end >= D`); `shortfall = max(0, req_spacing - (q.s_start - p.s_start), req_clear - (q.s_start - p.s_end))`; `padding_segments = ceil(max shortfall / L)`. — source: ADR-0008 Decision 6
- The `ceil` uses a documented epsilon constant `PADDING_EPSILON`; history is pruned to `s_start >= frontier - max(DODGE_RECOVERY_S, S_MIN_SPACING)`. — source: ADR-0008 Decision 6
- `PatternConfig.validated` must assert `DODGE_RECOVERY_S - L >= D` (14.6 u vs D 0.8 u at defaults). — source: ADR-0008 Decision 6
- The sequencer only pads: it never redraws, reorders or rejects a chunk at run time; worst case stays `ceil(1.4 * 3.0)` = 5 segments at shipped defaults. — source: ADR-0008 Decision 6 / Constraints
- `PatternCore` uses a `RandomNumberGenerator` instance with an explicit `seed` set from `run_id` before the first draw, its own Fisher-Yates, integer path only for layout decisions (`randi_range`), only `seed` set (never `state`). — source: ADR-0008 Decision 8
- Golden-sequence unit test fixes the expected chunk order for a hardcoded seed list, reloads the library from disk, is re-run on every engine upgrade, and runs once on an Android device build. — source: ADR-0008 Decision 8
- `ContentPreflight` is a pure `RefCounted` in `src/` composing `ObstacleMath`, `PatternMath`, `NearMissMath` validators and the real `PatternCore` sequencer; it returns every violation (exhaustive, deterministic order) as stable codes with structured records `{code, chunk_id, other_chunk_id, detail}`, never partial application. — source: ADR-0008 Decision 5
- P1 (each chunk alone) codes: `FOOTPRINT_NOT_FINITE`, `FOOTPRINT_INVALID_ORDER`, `FOOTPRINT_TOO_WIDE`, `FOOTPRINT_EFF_TOO_WIDE`, `HOME_SEGMENT_MISMATCH`, `NO_SAFE_GAP`, `TOO_MANY_PIECES`, `TOO_DENSE`, `HAZARD_OVERLAP`, `HIDDEN_CONTENT_FORBIDDEN`, `EXIT_BEYOND_VISIBLE_ARC`, `HIDDEN_UNFAIR`, `SWEEP_INVARIANT_VIOLATED`, `NEAR_ZONE_OVERLAP`, `DODGE_RECOVERY_VIOLATION`, `GRACE_ZONE_VIOLATION`, `SOLUTION_NOT_IN_GAP` (and `PIECE_SPAN_TOO_LONG`). — source: ADR-0008 Decision 5 / Risks
- P2: every ordered adjacent pair `(A,B)` (`A != B`, `A == B` only when a tier pool has one chunk) run through the real sequencer with actual padding, checking `NO_SAFE_GAP`, `HAZARD_OVERLAP`, `TOO_DENSE`, `NEAR_ZONE_OVERLAP` across the boundary; also run each pair behind a synthetic worst-case predecessor. P2 is a boundary-geometry check, not the proof for chains. — source: ADR-0008 Decision 5
- P3: fixed hardcoded list of 500 seeds, 200 segments each, through the real sequencer and validators; failure reported as `CHAIN_VIOLATION` with seed and segment; runs in CI only. — source: ADR-0008 Decision 5
- Blocking CI test `tests/integration/pattern_difficulty/pattern_difficulty_content_preflight_test.gd` runs P1 to P3 over shipped `chunk_library_01.tres`; it must pass for any merge touching `assets/data/chunks/` or the validators; an `EditorScript` calls the same `ContentPreflight` for designers. — source: ADR-0008 Decision 5
- The content test loads real `.tres` from disk (Integration/Content evidence) and asserts exact values such as `PI/2`; validator unit tests build fixtures with `.new()`. — source: ADR-0008 Decision 5
- Run `ContentPreflight` headless in CI after `godot --headless --import` (class cache). — source: ADR-0008 Verification item 5
- Test fixtures: micro-fixtures `TWOHOP`, `TOO_CLOSE`, `TWIN_WALL`, `CLUSTERED` plus new `SPIKE_AFTER_WALL` and `LONG_OVERLAP`; sequencer tests: non-opposing pair under 6.25 u gets padding, Spike after Wall gets padding, worst case 5 segments, no chunk redrawn. — source: ADR-0008 Validation
- Revise Pattern CR9, F2c and its acceptance criteria and Obstacle F5 wording (design review) before the Pattern epic starts; update the Near-Miss and Juice GDDs for the typed `footprint` payload. — source: ADR-0008 Ordering Note / Migration
- Fairness constraint validated at the composition root next to the Juice validators: `INK_HOLD_S + INK_FADE_REDUCED_S <= s_first / V_START - T_REACT` (0.35 <= 11/10 - 0.25 = 0.85 at defaults), else `INK_COVER_EXCEEDS_BUDGET`; pre-committed response: shorten the fade, never raise `s_first`'s dependents. — source: ADR-0010 Decision 5
- Each Ink cut registers one entry in the shared Juice flash ledger through the injected `flash_sink` (`JuiceCore.register_flash(now_us)`); the cut itself is never throttled. — source: ADR-0010 Decision 7
- Pre-committed response if PT-4 exceeds 3 flashes per second: Menus and HUD ignore a Play or Menu tap within `INK_MIN_INTERVAL_S` = 0.35 s of the last cut start. — source: ADR-0010 Decision 7
- `JuiceConfig` additions validated and clamped: `HIT_FLASH_S` 0.033 [0.016, 0.050], `GREY_CROSSFADE_S` 0.033 [0.016, 0.050], in seconds on the stamp clock; `hitstop_actual` validated by `validate_hitstop` (at most `HITSTOP_MAX`); `RESTART_LOCK - hitstop_actual >= T_READ` stays Run State's check. — source: ADR-0010 Decision 3
- Hazard Double Gate/Spike clusters are one hazard each (pieces merged into one surface), so the single killer isolate works per hazard. — source: ADR-0014 Decision 1

### Forbidden Approaches

- Never make Scoring an autoload — GDD Scoring AC lint and ADR-0002 — source: ADR-0002
- Never use `randomize()`, `randf` or the global `Array.shuffle()` in Pattern — unseeded/fragile float conversion breaks determinism; use seeded `RandomNumberGenerator`, `randi_range` and own Fisher-Yates — source: ADR-0008 Decision 8
- Never let the sequencer redraw, reorder or reject a chunk at run time — it only pads — source: ADR-0008 Constraints / Decision 6
- Never compare opposing angles with a raw `abs` — use the wrapped difference so seam-crossing angles compare correctly — source: ADR-0008 Decision 6
- Never rely on P2 alone as the proof for chains of chunks — P3 is the proof for chains, the sequencer rule makes cross-chunk spacing correct by construction — source: ADR-0008 Decision 5
- Never use the opposing-only history for cross-chunk spacing — adjacent non-opposing chunks could violate `S_MIN_SPACING` and footprint clearance — source: ADR-0008 Decision 6
- Never include the 500-seed P3 soak in the debug-build boot (if ever run there, MS-1 measures it) — source: ADR-0008 Decision 5
- Never let Run State call Juice — source: ADR-0010 Constraints
- Never let reduced motion change hit-stop (Juice Rule 10); the personal-best bloom and sweep are not gated by the hold — source: ADR-0010

### Performance Guardrails

- `S_MIN_SPACING` 6.25 u, `DODGE_RECOVERY_S` 26.6 u, `D` 0.8 u, segment length L 12 u (0.48 s at 25 u/s) at shipped defaults; worst-case padding 5 segments. — source: ADR-0008 Decision 6
- P2 pair count at most N^2 for N chunks (a few hundred); P3 is 500 seeds x 200 segments. — source: ADR-0008 Decision 5
- Hit-stop `HITSTOP_ACTUAL` = 0.20 s presentation hold, at most `HITSTOP_MAX`; at most 3 flashes per second system-wide (Juice Rule 11); Hit flash at most 30% opacity (`HIT_FLASH_OPACITY` 0.30), `HIT_FLASH_S` about 0.033 s. — source: ADR-0010 Decision 3
- Structural flash bound: a cut is at least 0.5 s after the Hit flash (`RESTART_LOCK` >= 0.45 s lock), Play needs a gated tap, Menu to Running to Menu needs two taps. — source: ADR-0010 Decision 7

### Engine API Constraints

- NEEDS VERIFICATION (verification item 4): a `RandomNumberGenerator` with explicit `seed` produces the same sequence on Android ARM64 and desktop (golden-sequence test on both); the engine does not promise stable sequences across engine versions. — source: ADR-0008
- Padding frequency to be measured at first playable (Pattern OQ11). — source: ADR-0008

---

## Presentation Layer Rules

*Applies to: rendering, camera, environment, juice, HUD and menus, UI, shaders, hazard and ball views*

### Required Patterns

- Renderer: Mobile (Vulkan) for the Android build, gated by R-1. Set `rendering/renderer/rendering_method="mobile"` and `rendering/renderer/rendering_method.mobile="mobile"` (Android override), with `rendering/rendering_device/fallback_to_opengl3` off. — source: ADR-0003 Decision 1
- On the Windows dev host pin `rendering/rendering_device/driver.windows` to `"vulkan"` (4.6 made D3D12 the default there), so fog checks and screenshots use the device's graphics API. — source: ADR-0003 Decision 1
- Run fog and contrast checks on the device or with `--rendering-method mobile`; a desktop screenshot does not represent the device. — source: ADR-0003 Constraints
- Gate R-1 must pass on at least two Android makers before the first Tube Track story is Done, and R-1 runs first once `project.godot` exists: no Environment, Hazard view or Ball view story starts until R-1 is recorded. — source: ADR-0003 Decision 1 / Ordering Note
- If R-1 fails (fog or contrast off by more than the F9 margin, draw calls over budget, or frame rate under 60 FPS), switch to Forward+ by setting `rendering/renderer/rendering_method.mobile="forward_plus"` (and keep `rendering_method` equal for desktop previews; restart the editor) and amend ADR-0003; Environment F1 is used as derived. — source: ADR-0003 Decision 1 / Rollback plan
- Fog: `Environment` depth mode with `fog_mode` depth, `fog_density = 1.0`, `fog_depth_begin` and `fog_depth_end` from MapConfig, `fog_depth_curve` 1.0; the speed pull moves only `fog_depth_end` (Environment F2). — source: ADR-0003 Decision 3
- Fog colour equals the sky horizon colour (ADR-0012 Decision 4, asserted by `EnvConfig.validated`); ADR-0012 pins `fog_sky_affect = 0`, `fog_aerial_perspective = 0`, `fog_sun_scatter = 0`; `fog_light_color` is written on every change through `WorldChroma`. — source: ADR-0003 Decision 3
- Pin the tonemapper to linear on every renderer; check fog banding (`use_debanding`). — source: ADR-0003 Decision 3
- `WorldEnvironment` glow is off in the MVP; personal-best bloom and near-miss ring are shader terms or overlay opacity, not engine glow. — source: ADR-0003 Decision 4
- Hit flash is a full-screen `CanvasLayer` `ColorRect` (one blend pass, `visible = false` when idle). — source: ADR-0003 Decision 4
- Near-miss ring is an additive Rim White term on the tube material driven by a world-space ball-position uniform (correct across all 12 shared slots, faded by fog with distance). — source: ADR-0003 Decision 4
- Antialiasing: MSAA 2x is the default; 4x is measured as a quality option; the seam uses `smoothstep` with `fwidth()` (MSAA does not smooth shader stripes); `scaling_3d/scale` is the lever if 60 FPS fails; the AA choice is part of R-1. — source: ADR-0003 Decision 5
- Spatial shaders avoid the preprocessor beyond simple `#define` constants; the seam is analytic and uses no texture uniforms (if one is ever added, declare it `sampler2D` in shader code). — source: ADR-0003 Decision 6
- Android export uses Shader Baker (4.5) and a mandatory warm-up scene that renders every material once before a run starts (tube, hazards, plinth material, killer-override material, ball, shard `GPUParticles3D`, Menu preview node; ADR-0014 Decision 5, ADR-0012 Decision 5). — source: ADR-0003 Decision 6
- Measure draw calls as the delta with and without a group, read via `RenderingServer.viewport_get_render_info` (`VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME`) after `frame_post_draw`; cross-check on device with Android GPU Inspector or Snapdragon Profiler. — source: ADR-0003 Implementation Guidelines
- Keep UI pills small and never stack full-screen translucent panels (fill rate is their cost). — source: ADR-0003 Implementation Guidelines
- Escalation path: if R1 exceeds its share, move the tube to R2 (one `MultiMeshInstance3D`, `custom_aabb` set); the `slot_binder` contract and Tube Track logic do not change. — source: ADR-0003 Decision 8
- Presentation tick order in `_tick()`: `Camera.step`, `BallView.tick` (right after `Camera.step`), `Environment.tick` (Idle and Menu resting values included), then `Juice.tick`, `HUD.tick`, `Menus.tick` (pull seams, then draw). — source: ADR-0002 Decision 6
- `run_reset` rank 3 Ball, rank 4 Camera; `phase_changed` rank 5 rows for `_ink_core.on_phase_changed` and `_hazard_view.on_phase_changed`; `map_load_failed` row for `_menus.on_map_load_failed` (rank 5). — source: ADR-0002 Key Interfaces
- Menus Boot failure screen shown on `map_load_failed` (plain language) with a Retry control; `HazardView.apply_map` (B4) builds inert hidden nodes and meshes. — source: ADR-0004 Decisions 2 and 3
- Camera's `camera_far` is derived in `MapConfig.build` as `F_rest + L` from the validated env (per map). — source: ADR-0004 Decision 1 / A5
- Juice reads `ObstacleCore.footprint_of(hazard_id)` and `hazard_type_of(hazard_id)` for the killer-isolate effect (read-only; same for Near-Miss via `hazard_bound`). — source: ADR-0008 Decision 3
- Safe area, `screen_get_size()`, `screen_get_refresh_rate()` facts feed HUD, Menus and Camera; the HUD/Menus keep the 40 dp / 16 dp starting margins; on foldables keep the portrait layout centred (letterbox). — source: ADR-0006 Decision 6 / 8
- Hazard draw-call allocation follows ADR-0003. — source: ADR-0008 ADR Dependencies
- `PresentationMath` is pure static (`class_name PresentationMath extends RefCounted`): `NOT_STARTED := -1`; `elapsed_s(start_us, now_us)` (NOT_STARTED -> -1.0, else max(0, now-start)/1e6); `hold_released(start_us, now_us, hold_s)`; `fade_out(elapsed_s, hold_s, fade_s)`; `ease_out_linear(amount, duration_s, elapsed_s)`. — source: ADR-0010 Decision 2
- Clock classification: ball/tube scroll/hazards/run time/score run on `dt_eff` (frozen by `dt_eff = 0`); hit hold, shard release, Hit flash, grey-out crossfade (stamp `hit_us`), near-miss rim, ring pulse, PB bloom and sweep (stamp per event) in `JuiceCore`, FOV punch in `CameraCore` (`punch_us`), Ink cover in `InkCoverCore` (`cut_us`), resume countdown ring in Run State (`resume_us`) are NOT frozen. — source: ADR-0010 Decision 1
- Seam stripes, fog, sky are functions of `s` and uniforms with no `TIME`. HUD and Menus pill press feedback has no animation (set on `button_down` / release). — source: ADR-0010 Decision 1
- Cosmetic UI `Tween`s use `create_tween()` on the view node, are killed on `run_reset`, and read no game state. — source: ADR-0010 Decision 1
- Event-effect shaders get a progress uniform in [0, 1] written by their core only when changed. — source: ADR-0010 Decision 1
- Shard `GPUParticles3D` setup: `visible = true` and `emitting = false` in the scene, `one_shot = true`, a `visibility_aabb` covering the burst, `global_transform` set before `restart()`, completion read from the `finished` signal (never `emitting`), default `keep_seed = false`, `fixed_fps` set deliberately (0 follows the display); PT-2 also checks `interpolate`. — source: ADR-0010 Decision 1 / Decision 3
- The shader lint covers particle process materials as well as `assets/shaders/**`. — source: ADR-0010 Decision 1
- Hit sequence: `JuiceCore.on_run_ended` (rank 1) stamps `hit_us` and the killer `hazard_id`, requests the Hit flash and sets `hit_grey` crossfade at the same tick (both at t = 0). `JuiceCore.tick()` sets a one-shot `shards_release` edge the first time `hold_released(hit_us, now, hitstop_actual)` is true; `JuiceView` consumes it: `ball_visible_sink(false)` and `shards.restart()` at the BallView global transform (render space). — source: ADR-0010 Decision 3
- `run_reset` (rank 5) clears `hit_us`, the edge, the shards and ball visibility (restored true via the same sink) unconditionally (Juice Rules 7 and 8). — source: ADR-0010 Decision 3 / ADR-0012 Decision 1
- `CameraView` writes `Camera3D.fov = CAMERA_FOV + fov_offset_deg()` in the Camera step, only when changed. — source: ADR-0010 Decision 4
- Ink cover: `InkCoverCore` (RefCounted) lives in the Menus module and is ticked unconditionally by `Menus.tick` (also when no Menus screen is visible); driven by `phase_changed`, never a request. Route predicate (only place written): `is_cut_route(new, old) = (new == MENU and old != BOOT) or (old == MENU and new == RUNNING)`. — source: ADR-0010 Decision 5
- Ink cut timeline: on a cut route `on_phase_changed` (rank 5, same tick) stamps `cut_us`, samples `reduced_motion_enabled` once, calls `flash_sink(now_us)`; `alpha() = fade_out(elapsed, INK_HOLD_S, fade_s)`; a new cut route during a cut re-stamps (no stacking); `covering() = alpha() > 0` is Menus AC-13 `transition_covering`. — source: ADR-0010 Decision 5
- Ink hold is time only (no tick-count rule; `InkCoverCore` has no `tick()`); the cover is written opaque in the tick that stamps it. — source: ADR-0010 Decision 5
- Ink cover view: `CanvasLayer` layer `UiLayers.INK_COVER` (30) with one full-rect `ColorRect` in an Ink palette colour of `ui_theme.tres`, `mouse_filter = STOP`; `visible = false` when `alpha() == 0`; writes `modulate.a` (not `color.a`) only when changed. In the cut tick Menus swaps its screens so a Paused backdrop or modal scrim is hidden before the fade. — source: ADR-0010 Decision 5
- `run_reset` does not touch `InkCoverCore` (Play fires `run_reset`, `run_started` and `phase_changed` in one tick). — source: ADR-0010 Decision 5
- `InkCoverConfig` (validated, clamped): `INK_HOLD_S` 0.05 [0.034, 0.10]; `INK_FADE_S` 0.18 [0.10, 0.30]; `INK_FADE_REDUCED_S` 0.30 [INK_FADE_S, 0.40]. — source: ADR-0010 Key Interfaces
- Layer stack: 5 Hit flash `ColorRect` (`visible = false` when idle, below the HUD), 10 HUD (pills, Hit tap catcher as first child), 20 Menus (screens, modal cards and scrim, Paused screen content below the top 92 dp), 30 Ink cover, 100 editor-only debug overlays (`OS.has_feature("editor")`, never in an export). — source: ADR-0011 Decision 2
- Each presentation system is `XCore` (RefCounted) plus a scene-based view with no `_process`: `HudView.tscn` (layer 10), `MenusView.tscn` (20), `InkCover.tscn` (30), `HitFlash.tscn` (5); one `Theme` resource (`assets/ui/ui_theme.tres`) assigned at each view root and as project default theme (`gui/theme/custom`); a test asserts it uses only the three palette colours (Ink, Rim White, Lagoon). — source: ADR-0011 Decision 3 / Decision 8
- Each view root has a `SafeAreaFrame` (`Control`) holding every positioned element; only full-bleed elements (Hit tap catcher, scrims, Ink cover, Hit flash, backgrounds) anchor to the whole root. Bottom 96 dp stays clear; no interactive element within 40 dp of side edges (checked by a test). `UiScaler` emits `ui_scale_changed(scale)` and views re-run layout in their next `tick`, not in the handler stack. — source: ADR-0011 Decision 1 / Decision 4
- Hidden means `visible = false`; blocked means a full-screen `Control` with `mouse_filter = STOP` (modal scrim, Paused/modal backdrops, Ink cover, Hit tap catcher). — source: ADR-0011 Decision 5
- Handlers (`button_down`, `pressed`, `_gui_input`) only stamp `press_us` and enqueue a request to the core, never change simulation state. — source: ADR-0011 Decision 5
- Pause/Menu buttons win over the Hit tap catcher by tree order (catcher first, buttons after, STOP on the buttons). Press feedback (scale 0.94 while held) is applied to a child pill visual with centred `pivot_offset`, not the Button; no per-frame code. — source: ADR-0011 Decision 5
- A gated control uses own `is_gated`, `modulate.a` about 0.45 and a reason `Label`; its `pressed` handler asks the core and ignores the tap while gated. — source: ADR-0011 Decision 5
- Slider in scroll list: every row/container/label is IGNORE or PASS; a stock Button inside the list uses `mouse_filter = PASS`; `scroll_deadzone` tuned above finger jitter; `UiSlider extends HSlider` overrides `_has_point` to accept only a hit rectangle of at least 48 x 48 dp centred on the thumb (pure function `UiMetrics.slider_thumb_rect`); slider at least 48 dp tall with horizontal margin, STOP; `follow_focus = false`, horizontal scroll off; commits once on `drag_ended` (ADR-0007). Fallback: PASS `Control` wrapper per row. — source: ADR-0011 Decision 6
- `UiAccess` (static, only file touching accessibility properties) with `name_control`, `set_gated`, `announce`, `set_live`; toggles are stock `CheckButton`, sliders stock `HSlider` (roles come from node type); score not announced per tick; no acceptance criterion depends on it until UI-A1. — source: ADR-0011 Decision 7
- `reduced_motion_enabled` and `colorblind_safe_enabled` toggles are shown only once wired to their consumers (three UI motions and the Ink cut; Environment F3), else hidden. — source: ADR-0011 Decision 7
- Interim accessibility baseline recorded in `design/accessibility-requirements.md` before the pre-production gate: Ink on pills contrast 7:1, targets >= 48 dp with >= 8 dp between, no colour-only cue, no haptic-only/audio-only critical info, WCAG 2.3.1 flash safety (Hit flash at most 30% opacity, at most 2 frames, plus Ink cut named), instant phase changes, hardware Back as exit path. — source: ADR-0011 Decision 7
- Pill UI rules: `StyleBoxFlat` panels with no shadow and no border, theme assigned once per view root, no per-control `add_theme_*_override`, no `clip_contents` on pills, one font (engine font atlas), budget about 2 draws per pill with text. — source: ADR-0011 Decision 8
- `BallView` (`BallView.tscn`, root `Node3D`, no `_process`) owns one `MeshInstance3D` (`SphereMesh` `radius = D/2`, `height = D`, `radial_segments = 24`, `rings = 12`, `is_hemisphere` false, smooth normals, `cast_shadow` OFF, no collision node) and one `ShaderMaterial` (`ball.gdshader`); no other system holds the material. Environment and Juice reach it through Callable seams `ball_luminance_sink` and `rim_glow_sink`. — source: ADR-0012 Decision 1
- `BallView` setters: `set_luminance_target(l)` (Environment only, any phase, albedo via `BallMath.albedo_for_luminance(base_color, l_base, l)`, written only on change); `set_rim_glow(v)` (Juice only, v in [0,1]); `set_ball_visible(v)` (Juice only, writes `visible` only on change; `BallView.tick` and Environment never write visibility; test asserts visible true after `run_reset`). — source: ADR-0012 Decision 1
- Environment's first `set_luminance_target` is in `Environment.apply_map` and the `setting_changed` handler, using the `base_luminance` value injected from `BallView.base_luminance()` read once by `GameRoot` (`ChromaMath.luma_srgb(style.base_color)`); Environment never calls `BallView` at construction. — source: ADR-0012 Decision 1
- `BallView.tick(snapshot)` places the node at riding radius `R + D/2` using `WorldFrame.render_z(s)` for z and `TubeMath.local_point(theta, h)` for x/y, float64 cast to float32 in one place; roll is stateless `fposmod(s / (D/2), TAU)`; lean is a capped function of `omega`; both live in the view. — source: ADR-0012 Decision 1
- Ball material is `unshaded`, opaque, depth fog on; body colour is uniform `albedo` with linear luminance exactly `L_ball` and no lighting; form from a cool-white fresnel rim `pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power)` mixed toward `rim_color`; Juice rim glow raises strength and adds Lagoon `edge_color` on the same term (no extra pass/material). The ball declares no chroma or grey uniform. A skin pattern, if any, must be luminance-preserving. — source: ADR-0012 Decision 2
- `BallStyle` is a scalar-only Resource (`assets/data/ball_style.tres`: `base_color`, `rim_color`, `edge_color`, `rim_power`, `rim_strength`, `rim_glow_max`, `roll_scale`, `lean_max`), loaded at composition and validated; a player cosmetic, not per-map. — source: ADR-0012 Decision 2
- Shaders read `world_chroma` / `hit_grey` only in `fragment()` or the sky shader. Tube, sky, prop and plinth shaders declare both globals; the hazard body shader declares only `hit_grey`; ball, shard particles, pickups and HUD declare neither. — source: ADR-0012 Decision 3
- Chroma operation on linear albedo before fog and before additive effect terms: `luma(c) = dot(c, vec3(0.2126, 0.7152, 0.0722))`; `chroma_eff = world_chroma * (1 - hit_grey)` for world elements, `(1 - hit_grey)` for hazard bodies; `albedo' = luma + (c - luma) * chroma_eff`. Additive effect terms (near-miss ring, PB sweep) go into `ALBEDO`, not `EMISSION`, on unshaded materials. — source: ADR-0012 Decision 3
- `world_chroma` in [0.88, 1.0] written by Environment (every frame while Running from `u(speed)`, resting 1.0 in Menu); `hit_grey` in [0, 1] written by Juice (crossfade at Hit, 0 on `run_reset`). — source: ADR-0012 Decision 3
- `ChromaMath` (pure): `luma`, `apply`, `luma_srgb`, `apply_srgb`, `effective`; `BallMath.albedo_for_luminance` returns its input unchanged when `l_target == l_base` (Environment AC-9 bit identity); art-bible L values are linear Rec.709 relative luminance (unit test against the hex values). — source: ADR-0012 Decision 3
- `WorldChroma` (RefCounted, built by `GameRoot`, injected into Environment and Juice): `set_world_chroma` (Environment only), `set_hit_grey` (Juice only), `set_base_fog_color` (called by `Environment.apply_map`); writes globals only when changed; in the same call recomputes `ChromaMath.apply_srgb(base_fog_color, chroma_eff)` and passes it to `fog_sink`, which writes only `fog_light_color` (and `background_color` if flat). `Environment.apply_map` never writes `fog_light_color` itself. — source: ADR-0012 Decision 4
- Sky/fog pins: the sky is drawn by a sky shader (or background gradient) that reads both globals itself (CPU sky base colours are not also chroma-adjusted); `fog_sky_affect = 0`, `fog_aerial_perspective = 0`, `fog_sun_scatter = 0`, `fog_light_energy = 1.0`, ambient and reflected light sources disabled; `EnvConfig.fog_color` must equal the sky horizon colour (`EnvConfig.validated` asserts it, with a test). — source: ADR-0012 Decision 4
- Killer isolate: `HazardView` owns `_isolated_node`; `isolate_killer(hazard_id)` finds the node itself and sets `set_surface_override_material(0, killer_material)`; `clear_isolation()` restores `null`; both idempotent, guard missing node/null mesh (log once). `release`, `release_all` and `bind` clear the override defensively. `killer_material = body_material.duplicate()` with `grey_exempt = 1.0` (shader multiplies `hit_grey` by `1 - grey_exempt`), built at `HazardView.apply_map`; every uniform write goes through one helper that writes both materials. Juice calls `isolate_killer` at `run_ended` and `clear_isolation` on `run_reset`, passing only the id. Surface 1 (plinth) is untouched. — source: ADR-0012 Decision 5
- Hazard geometry: `HazardMeshBuilder` (pure `RefCounted`, no Node, no ArrayMesh) turns `HazardSpec` + `HazardStyle` + `WorldGeometry` into `HazardMeshData` (chunk-local coordinates, tube axis along Z, `z = -s`); `HazardView` creates the `ArrayMesh` once and caches it in `Dictionary[HazardSpec, ArrayMesh]` keyed by spec identity; one node per hazard, all pieces merged into one surface. — source: ADR-0014 Decision 1
- Geometry: `delta = 2*PI/N_F`, `r_apothem = R*cos(PI/N_F)`, `r_base = r_apothem - HAZARD_BASE_SINK` with `HAZARD_BASE_SINK = 0.05 * D` (builder constant); per piece `k = ceil((theta_max - theta_min)/delta)` subdivisions with vertices exactly at `theta_min` and `theta_max` (unwrapped angles, no seam special case); every radial level from `r_base` to `r_solid = R + D` has the full footprint cross-section. — source: ADR-0014 Decision 2
- Tops: BLOCK, WALL, DOUBLE_GATE, NEAR_RING end in a flat top at `r_top = R + height_d(type)*D` with top vertices at `r_top / cos(dsub/2)` (chord midpoint at `r_top`); SPIKE rises from `r_solid` in two planar slopes to a ridge line along `s` at the piece centre angle and `r_top = R + height_d(SPIKE)*D`. No bottom face. — source: ADR-0014 Decision 2
- Winding: Godot front face is clockwise; every triangle satisfies `cross(b - a, c - a) . outward_normal < 0` so `cull_back` shows every face (tested per face on `HazardMeshData`, checked on device against `cull_disabled`). — source: ADR-0014 Decision 2
- Vertices are duplicated per face; `HazardMeshData` carries `body_normals`/`plinth_normals` for tests but `HazardView` adds no `ARRAY_NORMAL` unless the lit fallback is taken; `ARRAY_FLAG_COMPRESS_ATTRIBUTES` not set (flags 0). — source: ADR-0014 Decision 2
- Vertex colour: `COLOR.r` is the shade flag, exactly 0 or 1 (face colour on the start cap and top; shade colour on side walls, end cap and spike slopes); colour array length equals vertex count (asserted); real colours never stored in vertex colour. — source: ADR-0014 Decision 2
- Silhouette-covers-footprint invariants I1 to I4 tested on `HazardMeshData`: I1 at `r_base` extents equal piece bounds to 1e-6; I2 for every radius in `[r_base, R + D]` including top-polyline chord midpoints, extents equal piece bounds; I3 `r_top >= R + D` at chord midpoints and SPIKE slopes start at `r_solid`; I4 (plinth reach, resolved form) no raised plinth geometry within `sqrt(h*(D-h))` of any point outside the hit-expanded footprint (piece bounds expanded by D/2 along `s` and the ball's angular half-width), equivalently footing `s` extension at most `D/2 - sqrt(h*(D-h))`, and no footing covers any part of a gap. — source: ADR-0014 Decision 2 / Open Question 1
- Plinth (resolved OQ1): the builder emits per-piece footings (never one span across the gap), angularly inset by a small epsilon inside the hazard footprint (avoid z-fight), with `s` extension capped at `e_max = D/2 - sqrt(h*(D-h))` = 0.114 u (`PLINTH_S_EXTENSION` default 0, safe range 0 to 0.11 u); the gap is never narrowed or covered. The Environment GDD revision (Rule 10, TR-environment-theming-012, AC-14) must land before Environment plinth stories. — source: ADR-0014 Open Question 1 / Risks
- `HazardStyle` is a scalar-only Resource (floats and Colors, no nested Resource) in `MapDefinition.hazard_style`, validated by MapLoader Phase A (`HAZARD_STYLE_INVALID`) and carried as a validated copy in `MapConfig.hazard_style`: `height_d_wall`/`height_d_double_gate`/`height_d_near_ring` 1.0 [1.0, 3.0]; `height_d_spike` 1.6 [1.5, 3.0]; `face_color != shade_color`. — source: ADR-0014 Decision 3
- Node tree: `WorldRoot > TubeView, HazardView (Node3D, no _process; owns pool, mesh cache, two materials) > pool[0..191] MeshInstance3D (P = N_MAX * MAX_PIECES_PER_SEGMENT = 192, created once, visible = false, mesh kept, cast_shadow OFF, physics_interpolation_mode OFF) + one reserved preview MeshInstance3D`, BallView. — source: ADR-0014 Decision 4
- `HazardView.apply_map(cfg, geometry, library, plinth_material) -> bool` is Phase B step B4 (after `Pattern.apply_map`, before `TubeTrack.load_map`; `MapLoaderSeams.apply_hazard_view`): creates the pool (first call only), builds every mesh of the library, sets per-surface materials on each ArrayMesh, returns false on failure (codes such as `HAZARD_MESH_FAILED` to the log sink, loader reports `MAP_APPLY_FAILED`); creates only inert hidden nodes/resources; idempotent (Retry clears the cache and rebuilds). Environment `apply_map` (B1) creates the plinth material first; Environment mutates that material's uniforms and never replaces the object. Pattern gains a read-only `compiled_library()` getter. — source: ADR-0014 Decision 4
- Bind: `HazardView._on_hazard_bound` takes a free node, stores `s_offset` in its own per-node record, looks up `cache.get(spec)` (asserted non-null), sets `position = Vector3(0, 0, world_frame.render_z(s_offset))`, clears any surface override, calls `reset_physics_interpolation()`, and sets `visible = true` last (transform before visible, same tick). Release: hide, clear override, return to free list, keep mesh; `release_all()` used by `window_primed`, Retry and reset before rebinding in the same tick. — source: ADR-0014 Decision 4
- `HazardView` hides the whole pool (`pool_root.visible = false`) outside phases that show gameplay; the Menu shows only the `preview` node; lookup is `Dictionary[int, MeshInstance3D]` of at most 192 entries; `node_of` is test-only; pool exhaustion asserts in debug and logs and skips the bind in release. — source: ADR-0014 Decision 4
- Materials: one body `ShaderMaterial` (`hazard_body.gdshader`), `unshaded`, opaque, depth fog on (no `fog_disabled`, no `skip_vertex_transform`), `cull_back`, no shadows, nodes `cast_shadow` OFF and `gi_mode` disabled; `face_color`/`shade_color` are `source_color` uniforms; colour `mix(face_color, shade_color, step(0.5, COLOR.r))`; no preprocessor; no world-chroma uniform. Plinth: second `ShaderMaterial` owned by Environment (chroma at most 0.05, never the Signal Red or Ember value, subject to world chroma shift) as surface 1 of Double Gate meshes. Both set on ArrayMesh surfaces (shared), and rendered once in the ADR-0003 warm-up scene together with the killer-override material and the Menu `preview` node. — source: ADR-0014 Decision 5
- Culling: `MapConfig.camera_far = F_rest + L` (derived/validated by the loader ADR-0004 A5, applied to `Camera3D.far`), where `F_rest` is the resting fog end (84 u at Map 1) and constant (the speed pull of `fog_depth_end` never changes the projection); fog colour equals the background. — source: ADR-0014 Decision 6
- If R-1 measures hazard draw calls above 40, escalate to mesh per segment (route B); the `HazardView` interface (`bind`, `release`, `node_of`) does not change. — source: ADR-0014 Decision 6
- Menu preview: `HazardView.show_preview(spec)` / `hide_preview()` fill the reserved node from the same mesh cache (Environment owns screen anchor and transform); the effective-footprint overlay is a separate editor-only tool gated on `OS.has_feature("editor")`. — source: ADR-0014 Decision 7
- Hazard bodies keep full silhouette and chroma the instant they enter view: no fade, alpha ramp or LOD pop-in (TR-obstacle-system-023). — source: ADR-0014 Constraints
- Hazard height at least one ball diameter (art bible 3b); Spike single apex with defining feature in the top third. — source: ADR-0014 Constraints / Decision 3

### Forbidden Approaches

- Never use the Compatibility (OpenGL) renderer and never leave `fallback_to_opengl3` on — fog, glow and Compositor differ and are unverified; invalidates Environment F1; a non-Vulkan device must be blocked, not downgraded — source: ADR-0003
- Never change only `rendering_method` for an Android rollback — the `.mobile` override wins on Android — source: ADR-0003 Decision 1
- Never use real-time shadows (no light casts shadows) — source: ADR-0003 Decision 5
- Never use engine glow or `Compositor` effects in the MVP — glow ordering changed in 4.6 and Mobile glow cost is unmeasured — source: ADR-0003 Decisions 3 and 4
- Never use FXAA (it blurs); SMAA (4.5) is unverified on Mobile; TAA is not available — source: ADR-0003 Decision 5
- Never use a filmic tonemapper — it changes the 4:1 contrast — source: ADR-0003 Decision 3
- Never use screen shake; hazards remain the loudest element; juice stays in the cool/white channel — art bible constraint cited in ADR-0003 Constraints — source: ADR-0003 (Constraints)
- Never rely on the absolute `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` for budgeting — it counts all passes and reads the previous frame — source: ADR-0003 Implementation Guidelines
- Never use preprocessor patterns beyond simple `#define` constants in spatial shaders — 4.7 restrictions — source: ADR-0003 Decision 6
- Never rely on Shader Baker alone for hitching — it does not remove driver Vulkan pipeline creation; the warm-up scene is mandatory — source: ADR-0003 Decision 6
- Never read game state from Tween, particles or shader time — source: ADR-0002 Decision 10
- Never add a view `_process` (the menu tube idles via `TubeView.idle_step`) — source: ADR-0002 Decision 6
- Never design a landscape layout — no landscape layout is designed (Android 16 large-screen override handled by phones-only distribution and letterbox). — source: ADR-0006 Decision 8
- Never use `TIME` in `assets/shaders/**` or particle process materials; never use `create_tween`/`AnimationPlayer` outside ADR-0011 UI motion views; never add `real_dt` to a presentation timer; never `call_deferred`, Tween callback or `await` that moves the tube; never build `Vector3(` from `s`, `s_offset` or `snapshot.s` outside `world_frame.gd` in view code (ADVISORY). — lint rules registered for ADR-0010/0013 — source: ADR-0009 Decision 5
- Never write `RenderingServer.global_shader_parameter_set` outside `render_globals.gd` — source: ADR-0009 Decision 5 (ADR-0012)
- Never enable `physics/common/physics_interpolation` — source: ADR-0009 Decision 5 (ADR-0013)
- Never animate the HUD/Menus pill press with a Tween or code — set on `button_down`/release, scale applied to a child — source: ADR-0010 / ADR-0011
- Never apply the press scale to the Button itself — a scaled Control also scales its picking rectangle and could flip release-inside — source: ADR-0011
- Never let a `GPUParticles3D` shard rely on `emitting` for completion or start hidden — a hidden node is not simulated; read `finished` — source: ADR-0010
- Never delay the Ink cover behind the phase change or fade it in before the phase change — presentation must never gate gameplay (Alternative 4) — source: ADR-0010
- Never add Restart (Hit to Running), Resuming to Running, Running to Paused or Boot to Menu to `is_cut_route` (user decision 2026-10-03) — Restart is the instant-retry path; response only if PT-1 shows a visible jump — source: ADR-0010
- Never stack full-screen translucent layers other than the one Hit flash or the one modal scrim, and never together with the Ink cover — source: ADR-0011 Decision 8
- Never use blur, `BackBufferCopy` or `SubViewport` UI — source: ADR-0011 Decision 8
- Never assign a literal to `CanvasLayer.layer` — lint — source: ADR-0011
- Never use `color.a` for the Ink cover fade — would re-record the item — source: ADR-0010
- Never use a lit ball or give the ball a chroma/grey uniform — body luminance variation breaks Environment F3 — source: ADR-0012
- Never make Environment own or write the ball material directly, and never write the ball `visible` from Environment or `BallView.tick` — single writer — source: ADR-0012
- Never name the ball method `set_visible` — already exists on `Node3D` — source: ADR-0012
- Never read a global shader parameter in a vertex stage — storage-buffer limit on some mobile GPUs — source: ADR-0012
- Never write `fog_light_color` outside the `WorldChroma` fog sink — second writer causes a one-frame horizon line — source: ADR-0012
- Never chroma-adjust the CPU sky base colours when the sky shader reads the globals — would apply chroma twice — source: ADR-0012
- Never put `mouse_filter` STOP on non-interactive Controls; never call `grab_focus()`; never make interactive targets under 48 x 48 dp — source: ADR-0011
- Never use `Engine.time_scale`, `SceneTree.paused` or `Tween` for hit-stop — source: ADR-0010
- Never use `Dictionary` growth or node creation per hazard bind — pool only — source: ADR-0014
- Never read the shade flag with raw float interpolation compared exactly — use the threshold `step(0.5, COLOR.r)` (Mobile varyings are mediump) — source: ADR-0014
- Never apply the world chroma shift to hazard bodies, the ball, shard particles or pickups — exempt by construction — source: ADR-0012

### Performance Guardrails

- Draw-call allocation (provisional, measured in R-1): tube 12, hazards 34 (17 bodies plus 17 plinth surfaces in the AABB window), ball and rim 4, props 6 (MultiMesh), sky 2, shards 2, HUD 20 (UX-16), Hit flash 1, Menus 25 (never concurrent with gameplay). — source: ADR-0003 Decision 7
- Concurrent gameplay worst case on Mobile about 81 (84 with full ball allocation), plus the Paused overlay; headroom about 65 against 150. On Forward+ fallback the hazard figure may double to about 68; escalation is one mesh per segment (ADR-0014). — source: ADR-0003 Decision 7
- Fairness budget: `T_VIS_MIN` has only a 0.02 s margin against `F_read` at `v_max` (46.00 u); a fog or contrast shift of 0.5 u on device breaks Pillar 2. — source: ADR-0003 Constraints
- R-1 criteria: derived `F_read` at `v_max` at least 45.5 u (legacy floor) and `T_vis` at least 1.5 s; hazard-to-tube contrast at `F_read` at least 4:1 on screen; tube draw-call delta +12 (or measured) with the full scene at most 150 and engine baseline recorded; 60 FPS sustained for 10 minutes; first-use shader hitching under one frame with Shader Baker (or warm-up). — source: ADR-0003 Validation Criteria
- Environment fog reference: `F_read` 46.22 u, 4:1 contrast floor (`MAP_VISIBILITY_UNSAFE`). — source: ADR-0003 Problem Statement
- Tube draw-call delta on Mobile +12; on Forward+ a depth pre-pass may make it about 24. — source: ADR-0003 Verification Required
- Engine baseline draw calls unknown (the earlier "68" was not reproduced) and must be measured before figures are trusted. — source: ADR-0003 Decision 7
- Fog and contrast measured after tonemapping with the tonemapper pinned linear, sampled at several distances and on pixels mid-segment (per-vertex vs per-pixel). — source: ADR-0003 Validation Criteria
- 60 FPS / 16.6 ms frame; 512 MB memory ceiling. — source: ADR-0006 Performance
- Ink timing: `INK_HOLD_S` 0.05 s (3 presented frames at 60 Hz), `INK_FADE_S` 0.18 s, `INK_FADE_REDUCED_S` 0.30 s; totals 0.23 s (UX envelope 150 to 250 ms) and 0.35 s. — source: ADR-0010 Decision 5
- Hit hold 0.20 s; release at `hit_us + 0.20 s` or first tick after a stall; `RESTART_LOCK` >= 0.45 s always follows release. — source: ADR-0010 Decision 3
- Ink cover costs 1 draw call while visible (inside Menus 25 / HUD 20); no allocation during a run. — source: ADR-0010 Performance
- Touch targets >= 48 x 48 dp, >= 8 dp between adjacent targets, none within 40 dp of side edges or in the bottom 96 dp; minimum safe area 360x560 dp; Paused content clear of the top 92 dp. — source: ADR-0011
- Ball: 1 draw call (allocation 4), shard burst keeps its 2; `radial_segments = 24`, `rings = 12`. — source: ADR-0012 Decision 1 / Decision 6
- Chroma: `world_chroma` in [0.88, 1.0]; luminance preserved to 1e-6; ball/hazard contrast 1.4:1 target and 0.01 ember margin depend on rendered body luminance. — source: ADR-0012
- Hazard mesh: `MAX_HAZARD_TRIANGLES = 512` per mesh (asserted at build; Near-Ring of 5.4 rad about 170); about `6k + 4` triangles per piece; pool P = 192; at most 12 pieces per segment. — source: ADR-0014 Decision 2 / Decision 4
- Hazard draw calls: at most `floor((camera_far + max_hazard_s_length) / S_MIN_SPACING) + 1` = about 17 hazards drawn (`S_MIN_SPACING` 6.25 u), 34 worst case (17 bodies + 17 plinths) under the 40 allocation; Menu preview adds 1 to 2; Forward+ may double (about 68). — source: ADR-0014 Decision 6
- `HAZARD_BASE_SINK = 0.05 * D`; plinth height 0.15 D (0.12 u); plinth chroma at most 0.05; body-mesh memory about 4 MB at a few hundred specs (to be measured). — source: ADR-0014
- Hit flash at most 30% opacity, at most 2 frames, at most 3 flashes per second. — source: ADR-0011 Decision 7 / ADR-0010

### Engine API Constraints

- Knowledge risk HIGH for rendering: glow before tonemapping (4.6), shader preprocessor restrictions (4.7), Shader Baker (4.5), `Texture` uniform type (4.4); fog and draw-call accounting on Mobile unverified. — source: ADR-0003
- Post-cutoff APIs used: depth fog on `Environment` (properties verified on 4.7.2, Forward+ only); Shader Baker (4.5, export-time). `Compositor` is not used. — source: ADR-0003
- Verified on Forward+ 4.7.2: depth fog formula and radial `d`; default fog mode exponential; default `fog_density` 0.01. — source: ADR-0003
- Gate R-1 NEEDS VERIFICATION on the Mobile renderer, on device (two Android makers): (1) depth fog factor vs F1 and derived `F_read`; (2) tube draw-call delta (+12 expected) and engine baseline; (3) flat shading from duplicated vertices (derivative-normal fallback); (4) `rendering/renderer/rendering_method.mobile` is the per-platform override, defaults to `mobile`, wins over `rendering_method` on Android; (5) default of `rendering/rendering_device/fallback_to_opengl3` and `RenderingServer.get_current_rendering_method()` at boot; (6) Shader Baker on an Android export; (7) depth fog computed per fragment, not per vertex, on Mobile; (8) fog/contrast after tonemapping with linear tonemapper, fog gradient banding (`use_debanding`); (9) draw-call delta on Forward+ vs Mobile; (10) glow, MSAA 2x/4x, FXAA and SMAA (4.5) support and cost on Mobile; (11) 60 FPS on the reference devices. — source: ADR-0003 Verification Required
- Godot 4.4+ carry their own pipeline-compilation work (not in the engine reference, unverified); R-1 measures first-run hitching with and without the baker and the warm-up. — source: ADR-0003 Decision 6
- A renderer change needs an editor restart. — source: ADR-0003 Decision 1
- `godot --headless --import` parses shaders only (no RenderingDevice headless); T-1 records what the headless driver returns for `get_current_rendering_method()`. — source: ADR-0003 Decision 1 / Validation Criteria
- 4.6 split touch focus from keyboard focus; touch focus on Buttons under dual-focus to be verified (ADR-0011). — source: ADR-0005 Verification Required (also listed under Foundation)
- NEEDS VERIFICATION: safe-area insets may arrive asynchronously under edge-to-edge; re-read at regain edges and size change; empty falls back to full screen. — source: ADR-0006 Decision 6
- PT-1 (device): first presented frame after the tick of `phase_changed` is fully opaque (frame capture) at 60 and 120 Hz, including a Restart frame capture. — source: ADR-0010
- PT-2 (device): a hidden, non-emitting one-shot `GPUParticles3D` bursts on the frame after `restart()` on Mobile with no first-frame pop; 4.7 particle angular-velocity change visually acceptable. `restart()` gained optional `keep_seed` in 4.4 and is called without arguments. — source: ADR-0010
- PT-3 (device): a 5 s stall during Hit releases the hold at the first tick back, no stale alpha. PT-4 (device): tap spam Play/Pause/Menu/Play reaches at most 3 ledger entries per second. — source: ADR-0010
- NEEDS VERIFICATION: whether a `ColorRect` with `visible = false` costs nothing on Mobile; tween delta cap is unverified (acceptable for cosmetics). — source: ADR-0010
- Spike UI-1 checks (device): (4) `Control._has_point()` override decides GUI picking for emulated touch and a drag begun on the thumb stays with the slider; (5) `ScrollContainer` scrolls by touch drag on a Control that passes the press (5b stock Button drag scrolls); (6) invisible Control and full-screen STOP blocker stop taps, Pause/Menu win over the Hit tap catcher by tree order; (7) `StyleBoxFlat` pills cost one draw call each with no shadows (R-1 delta); (8) `emulate_touch_from_mouse` on in editor; (9) `ScrollContainer` clips the slider thumb rect at the row edge. — source: ADR-0011
- Spike UI-A1 (device; criteria written before the run; tiers full/partial/none): property names (`accessibility_name`, `accessibility_description`, `accessibility_live` believed) and `accessibility/general/accessibility_support`; TalkBack on Button/CheckButton/HSlider; `FOCUS_NONE` vs `FOCUS_CLICK`; Switch/Voice Access; live regions; gated reason; TalkBack impact on gestures/Hit catcher/tilt; ScrollContainer two-finger scroll and `UiSlider`; frame cost; node bounds with `content_scale_factor` != 1. Read the 4.7 release notes and `Control` class reference first. AccessKit may be desktop-only. — source: ADR-0011
- Post-cutoff UI facts: dual focus (4.6), AccessKit (4.5), recursive Control behaviour (4.5), Android edge-to-edge (4.5); `ui.md`/`input.md` verified to 4.6 only; `content_scale_factor` and Window stretch semantics not in the reference. — source: ADR-0011
- Global shader parameters: `global uniform float world_chroma;` / `hit_grey` in spatial and sky shaders on Mobile and Forward+ unverified; R-1 checks 1 to 15 include: fog colour CPU path matches tube and sky pixels within 1 LSB (8), pinned fog properties behave on Mobile and the sky follows a changed global live not via the radiance cubemap (9), additive terms via `ALBEDO` on unshaded (10), depth fog applies to the unshaded ball on Mobile (11), ball luminance measured at disc centre (12), globals read only in `fragment()`/sky (13), pooled node released while isolated and rebound carries no override (14), `SphereMesh` radius+height round at `D` (15). — source: ADR-0012
- Tonemap pins for luminance checks: `tonemap_exposure` 1.0, camera exposure multiplier 1.0, auto-exposure off, adjustments off; linear tonemapper. — source: ADR-0014 Verification / ADR-0012
- Hazard R-1 rows (device): (1) draw-call delta = surfaces x instances in frustum (including a straddling hazard) on Mobile and Forward+; (2) unshaded material gets depth fog on Mobile and unfogged luminances equal face 0.079 / shade 0.03; (3) every face visible under `cull_back`; (4) `Camera3D.far` culls a fully fogged hazard without a pop and does not wrongly clip tube/props/sky; (5) `set_surface_override_material(0, ...)` replaces only the body surface, cleared by `null`; (6) per-surface materials on the ArrayMesh are shared by every node; (7) spike HV-1 prewarm time and memory; (8) transform set before `visible = true`; (9) `add_surface_from_arrays` AABB for chunk-local negative-z geometry incl. 5.4 rad Near-Ring; (10) headless ArrayMesh read-back may be empty so tests assert on `HazardMeshData`; (11) 192 pooled hidden nodes leave no residual cost; (12) Retry leaves no stale spec identity in the cache. A surface without `ARRAY_NORMAL` on Mobile is not covered by the reference and is included in R-1; 60 FPS at 16 visible hazards. — source: ADR-0014
- Typed `Dictionary[HazardSpec, ArrayMesh]` (4.4) is used; `duplicate_deep()` is not used. — source: ADR-0014
- Lit-fallback path: if unshaded hazard material loses depth fog on Mobile, fall back to a lit material with fixed lights and re-derive luminances. — source: ADR-0014 Risks

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController` |
| Variables | snake_case | `move_speed` |
| Signals/Events | snake_case, past tense | `health_changed` |
| Files | snake_case matching class | `player_controller.gd` |
| Scenes/Prefabs | PascalCase matching root node | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH` |

Source: `.claude/docs/technical-preferences.md`. Test files: `[system]_[feature]_test.gd`, functions `test_[scenario]_[expected]` (`coding-standards.md`, ADR-0009).

### Performance Budgets
| Target | Value |
|--------|-------|
| Framerate | 60 FPS |
| Frame budget | 16.6 ms |
| Draw calls | at most 150 per frame (about 81 concurrent expected on Mobile, measured in R-1; ADR-0003 Decision 7) |
| Memory ceiling | 512 MB (mid-tier Android) |

Source: `technical-preferences.md`, ADR-0003.

### Approved Libraries / Addons
- GUT (MIT), pinned by exact release and `godot.sha512` in `tools/ci/versions.json` after spike T-1; gdUnit4 is the pre-committed fallback if T-1 fails — source: ADR-0009, `technical-preferences.md`
- No other addon is approved.

### Forbidden APIs (Godot 4.7.2)
These are deprecated, replaced, or forbidden by an ADR. Source: `docs/engine-reference/godot/deprecated-apis.md` unless an ADR is named.
- `yield()` — use `await signal`
- String-based `connect("signal", obj, "method")` — use `signal.connect(callable)`; typed handlers are mandatory in `_wire()` (ADR-0002)
- `instance()` / `PackedScene.instance()` — use `instantiate()`
- `get_world()` — use `get_world_3d()`
- `OS.get_ticks_msec()` — use `Time.get_ticks_msec()`; game code gets time only through the injected `clock_us` (ADR-0002)
- `TileMap`, `VisibilityNotifier2D/3D`, `YSort`, `Navigation2D/3D` — use the replacements in the engine reference
- `$NodePath` lookups inside `_process()` — cache with `@onready`
- Untyped `Array` / `Dictionary` — use typed collections
- Manual post-process viewport chains — use `Compositor` if ever needed (the MVP uses no Compositor effects, ADR-0003)
- GodotPhysics3D / any physics node for collision — collision here is analytic (ADR-0008)
- **Project override:** the engine reference lists `duplicate_deep()` (4.5) as the replacement for `duplicate()` on nested resources; this project forbids `duplicate_deep()` because specs are immutable shared resources and configs hold scalars only (ADR-0008, ADR-0004).
- `Texture2D` as an API parameter or return type (GDScript/C++ signatures) — use `Texture` (4.4); shader source still declares `sampler2D` (unverified on 4.7.2)
- Post-cutoff APIs with no entry in the engine reference modules (they stop at 4.6) are unverified until the named spike passes.

### Cross-Cutting Constraints

#### Global Required Patterns

- Use `GameRoot` (scene-root `Node`, `class_name GameRoot`) as the Composition Root and the only node that runs `_process` for game logic. — source: ADR-0002 Decision 1
- `GameRoot._process(_engine_delta)` ignores the engine delta; it computes `real_dt = (now_us - prev_us) / 1e6` (raw, unclamped) from the injected clock and uses `world_dt = real_dt`. — source: ADR-0002 Decision 1
- Set `GameRoot` `process_mode = PROCESS_MODE_ALWAYS` in the scene file (a guard against future pausing). — source: ADR-0002 Decision 1
- Every view Node (Camera3D rig, Tube Track view, ball view, HUD, Menus, Environment) must call `set_process(false)` and `set_physics_process(false)` and be driven by method calls from `GameRoot`. — source: ADR-0002 Decision 1
- Inject one `clock_us: Callable` wrapping `Time.get_ticks_usec()` into every system that needs time; Cores never call `Time.`. — source: ADR-0002 Decision 4
- Inject the boot rendering-method check the same way (`rendering_method_getter: Callable`). — source: ADR-0002 Decision 4 / ADR-0003 Decision 1
- `TiltInput` and the touch Controls receive `clock_us` by injection; they never call `Time.` themselves. — source: ADR-0005 Implementation Guidelines
- `GameRoot` keeps a strong reference to every core for the whole session (a connection does not keep a RefCounted alive). — source: ADR-0002 Decision 7
- A handler that needs state from another system reads it by accessor after that system's step in the same tick; it never calls a mutating method of another system. — source: ADR-0002 Implementation Guidelines
- Pause, Hit and Resuming freeze the world through `dt_eff = 0` (Run State returns `dt_eff = 0` outside Running); `GameRoot` keeps ticking in every phase. — source: ADR-0002 Decision 8
- Engine-driven effects (Tween, GPUParticles3D, shaders, AnimationPlayer) are allowed but must never read game state; they keep advancing while `dt_eff = 0` (intended, decided in ADR-0010). — source: ADR-0002 Decisions 1 and 10
- Use `ResourceLoader` only in `map_loader.gd`; always load the map path with `ResourceLoader.load`. — source: ADR-0004 Decision 4
- CI lint: no `_process`/`_physics_process` outside `GameRoot`, no autoload entry, no `CONNECT_DEFERRED` on control signals, no `Engine.time_scale` write. — source: ADR-0002 Implementation Guidelines
- Run `godot --headless --import` before the GUT run (class cache for `class_name GameRoot` and the cores; also needed for `class_name` types like `MapDefinition`). — source: ADR-0002 Validation Criteria / ADR-0004 Validation Criteria
- `MapLoaderCore`, `MapConfig` and map-loader tests hold no engine calls. — source: ADR-0004 Decision 4
- No autoload for game systems; `GameRoot` builds systems in the ADR-0002 order (PlatformServices first, SaveService second). — source: ADR-0006 Guidelines / ADR-0007 Decision 3 / ADR-0009 Decision 5
- Cores are `RefCounted` with injected seams; no SceneTree needed for unit tests. — source: ADR-0009 Context/Constraints
- Gameplay values are data-driven (e.g. `SaveConfig`, `PatternConfig`, `ContentPreflightConfig`); content authored in the editor, no hardcoded gameplay values. — source: ADR-0007 Decision 8 / ADR-0008 Constraints
- Determinism: same `run_id` and call script give bit-identical output; tests use hardcoded seed lists, `==` for integers/codes, `1e-6` for floats. — source: ADR-0008 Constraints / ADR-0009 Decision 7
- Closures that capture a counter in tests use an `Array` or a member (a closure captures a primitive by value). — source: ADR-0009 Decision 7
- Fixtures use distinct non-shipped values where a GDD says so (e.g. schema version 3, retention 3) with an advisory smoke test asserting shipped defaults. — source: ADR-0009 Decision 7
- Evidence mapping: Logic -> `tests/unit` BLOCKING; Integration headless-capable -> `tests/integration` BLOCKING; device-needing integration (SP-1, SP-2, SP-3, PS-1.., BM-1, NM-1, OB-1, MS-1) -> `production/qa/evidence/` blocking at named gate (`designated-gates.md`); lints BLOCKING unless rule says ADVISORY; Config/Data smoke and statistical -> `tests/advisory` ADVISORY. — source: ADR-0009 Decision 2
- Behavior that differs by OS (rename semantics, paths) is proven on a device (ADR-0007 SP-1), not by CI alone; Linux CI also catches wrong-case `res://` paths. — source: ADR-0009 Context / Decision 4
- Stay within CI/test conventions: pinned inputs, `contents: read`, public repository means no secret or unpinned third-party code. — source: ADR-0009 Constraints
- Every presentation effect is a pure function of a microsecond stamp taken from the injected `clock_us` and the current `clock_us`: the owning core stores `start_us` in the event handler and computes `elapsed_s = PresentationMath.elapsed_s(start_us, clock_us.call())` at its tick or on query. — source: ADR-0010 Decision 1
- Gameplay distance `s` is float64 and is never reduced, wrapped or capped; only the render origin shifts. — source: ADR-0013 Decision 1
- Every node whose position depends on `s` is placed through `WorldFrame.render_z`, and has a `rebase()` hook or is parented to the ball-relative frame. Nothing outside `WorldFrame` and `TubeMath` evaluates `-s`. — source: ADR-0013 Decision 3
- Cores never store a world z in a `Vector3`; `CameraCore` and `ObstacleCore` keep `s` as float64 and publish offsets, and Tube Track keeps the segment index as an `int`. — source: ADR-0013 Decision 3
- Use the sRGB wrappers (`ChromaMath.luma_srgb`, `apply_srgb`) on every CPU path that writes `fog_light_color` or a `source_color` uniform, because authored `Color` values are sRGB. — source: ADR-0012 Decision 3
- Every non-interactive Control (pill backgrounds, rows, containers, the Hit flash `ColorRect`) sets `mouse_filter = IGNORE`; only buttons, sliders, scrims, the tap catcher and the Ink cover are STOP. An integration test walks each view tree and asserts it. — source: ADR-0011 Decision 5
- Layer indices come only from the `UiLayers` constants class (FLASH 5, HUD 10, MENUS 20, INK_COVER 30, DEBUG 100). — source: ADR-0011 Decision 2
- Views create no nodes while a run is going: all elements exist in the scene and toggle `visible`; views write a property only when the value changed (dirty compare). — source: ADR-0011 Decision 3
- Hazard meshes, `ArrayMesh` creation and pools are built at map load (Phase B), never inside the tick: no allocation during a run. — source: ADR-0014 Decision 4
- Validation tests use a fixed fixture table, not random colours, with a 1e-6 tolerance (float32) for chroma/luma maths. — source: ADR-0012 Decision 3
- The ADR-0009 lint list gains: stretch settings, `CanvasLayer.layer` only from `UiLayers`, `accessibility_*` only in `ui_access.gd`, no `mouse_behavior_recursive`, no `Button.disabled` assignment in view code. — source: ADR-0011 Migration Plan
- The ADR-0009 lint list gains: every `global uniform` name and type in a shader matches a `[shader_globals]` entry and every declared global is used; the marked chroma function block is textually identical in all shaders; `world_chroma` and `hit_grey` appear only in shaders under the ADR-0012 Decision 3 rules; `RenderingServer.global_shader_parameter_set` appears only in `render_globals.gd`. — source: ADR-0012 Migration Plan
- Lint (ADR-0010): no `Engine.time_scale` write, no `TIME` in `assets/shaders/**`, no `create_tween` / `AnimationPlayer` outside the ADR-0011 UI motion views, no presentation timer that adds `real_dt`. — source: ADR-0010 Validation Criteria
- Lint (ADR-0013, ADVISORY, registered in `tools/ci/lint_rules.json`): no `Vector3(` built from `s`, `s_offset` or `snapshot.s` outside `world_frame.gd` in view code. — source: ADR-0013 Validation Criteria

#### Global Forbidden Approaches

- Never use autoloads or a global event bus — hidden coupling, no explicit construction order, hard to inject doubles; GDDs forbid them — source: ADR-0002
- Never use `_physics_process` in any game-logic code — polling must be per rendered frame; analytic collision needs no physics step — source: ADR-0002
- Never use `SceneTree.paused` — Pause is `dt_eff = 0` — source: ADR-0002
- Never write `Engine.time_scale` (`time_scale` is never changed; a lint bans writes) — source: ADR-0002
- Never let a view Node or any system outside `GameRoot` run its own `_process` with `process_priority` for ordering — orderings are correctness requirements and would depend on scene-tree accident — source: ADR-0002
- Never connect control signals with `CONNECT_DEFERRED` (handlers are immediate connections only); `CONNECT_ONE_SHOT` only on connections outside the `_wire()` table — source: ADR-0002
- Never `await` in a `run_reset` handler or send requests from handlers — source: ADR-0002 Context constraints (Run State rules 3 and 4)
- Never call `Time.` from a Core (use the injected `clock_us`) — source: ADR-0002
- Never rely on a fixed `16.6 ms` frame in tuning (`real_dt` follows the display refresh rate, vsync and `Engine.max_fps`) — source: ADR-0002 Consequences
- Never open the map file with `FileAccess` or list it with `DirAccess` — export remaps and binary conversion hide the file — source: ADR-0004 Decision 4
- Never use `duplicate_deep()` (4.5) in the map loader — source: ADR-0004
- Never hard-code input device IDs and never read a gamepad — 4.7 device ID renumbering; no gamepad — source: ADR-0005 Decision 5
- Never read gameplay touch through `Input.is_action_*` — source: ADR-0005 Decision 3
- Never use autoload entries for game systems in `project.godot` — source: ADR-0002 lint (ADR-0009 `project_setting`) — ADR-0009 Decision 5
- Never introduce `_process`/`_physics_process` outside `game_root.gd`, `CONNECT_DEFERRED` on control signals, `Engine.time_scale` writes, or `SceneTree.paused` — registered lint rules — source: ADR-0009 Decision 5
- Never read sensors (`get_gravity`, `get_accelerometer`, `get_gyroscope`, `get_magnetometer`) outside `tilt_input.gd`; never use `Input.is_action_*` in gameplay; never use `OS.is_debug_build()` in dev-input code — source: ADR-0009 Decision 5
- Never use `ResourceLoader` outside `map_loader.gd`; never use `ConfigFile`/`FileAccess`/`DirAccess` outside `save_service.gd` — source: ADR-0009 Decision 5 (ADR-0004, ADR-0007)
- Never commit secrets, keystores, credentials — public repository — source: ADR-0006 / ADR-0009 `secret` rule
- Never merge with failing tests or disable/skip a failing test to pass CI — source: ADR-0009 Decision 7 / Context
- Never accumulate `dt` in a presentation timer — drifts with dropped frames, a stall inflates or skips, needs extra tick args (Alternative 3) — source: ADR-0010
- Never use `Engine.time_scale` or `SceneTree.paused` for hit-stop — forbidden by ADR-0002 (`engine_time_scale_writes`, `scene_tree_paused_for_pause`); Run State derives time from the real clock — source: ADR-0010
- Never read `TIME` in a shader — event effects get a progress uniform in [0, 1] written by their core, world shaders read none — source: ADR-0010
- Never use `Tween` or `AnimationPlayer` for hit presentation, FOV punch, Ink cover or any effect in the ADR-0010 classification table — not testable with a fake clock, follows engine delta; they are allowed only for cosmetic UI motions of ADR-0011 — source: ADR-0010
- Never place a node with raw `s` in a `Vector3` (`z = -s`) — float32 precision loss at large `s`; use `WorldFrame.render_z` — source: ADR-0013
- Never cap, wrap or end a run at `S_PRECISION_LIMIT`, and never use a double-precision engine build — breaks Pillar 2 / cost on every build and device — source: ADR-0013
- Never use `mouse_behavior_recursive` in the MVP — unverified 4.5 API; `visible` and STOP blockers do the same — source: ADR-0011
- Never use `Button.disabled` for gated controls — use an own `is_gated` flag, `modulate.a` about 0.45 and a reason `Label` — source: ADR-0011
- Never call `grab_focus()`; every Button is `FOCUS_NONE` — source: ADR-0011 (ADR-0005)
- Never use `MultiMesh` / `MultiMeshInstance3D` for hazards, never use vertex-shader deformation or `custom_aabb`, never use `material_override` in steady state, never use instance uniforms for hazards — variable arc width cannot be a linear instance transform; fairness-critical silhouette; Mobile instance uniforms unverified — source: ADR-0014 / ADR-0012
- Never use `CollisionObject3D` in hazard code or on the ball view — source: ADR-0014 / ADR-0012
- Never use `#include` in shaders (copy the canonical chroma function block per shader) — 4.7 shader preprocessor restrictions — source: ADR-0012
- Never create an `ArrayMesh` outside `HazardView.apply_map` — source: ADR-0014 Validation Criteria
- Never use an object-flag-gated shared uniform for chroma exemption — exemption must be structural — source: ADR-0012
- Never use a full-screen post-process or a `Compositor` for the grey-out — cannot isolate the killer hazard; forbidden by ADR-0003 — source: ADR-0012
- Never use `call_deferred`, a Tween callback or `await` to move the tube or change the seam phase — breaks the Ink cover same-frame guarantee — source: ADR-0010

#### Global Performance Guardrails

- Target 60 FPS, 16.6 ms frame, mid-tier Android, 512 MB memory ceiling. — source: ADR-0002 Constraints / ADR-0003 Constraints
- `GameRoot` orchestration under 0.1 ms per frame (a dozen method calls); simulation steps 1 to 10 provisional 3 ms. — source: ADR-0002 Performance
- At most 150 draw calls total. — source: ADR-0003 Constraints
- Target 60 FPS / 16.6 ms frame budget; 512 MB memory ceiling (mid-tier Android). — source: ADR-0006 Performance
- CI full run at most 5 minutes after warm cache. — source: ADR-0009 Decision 4
- Draw calls: HUD 20 and Menus 25 (never concurrent except the Paused screen over the frozen HUD Z1); hazards 40 allocated (34 worst case, 10 to 14 typical); ball 1 call under allocation 4; total 150. — source: ADR-0011 / ADR-0014 / ADR-0012
- Per-tick CPU: HUD 1.0 ms and Menus 1.0 ms worst case; presentation cores well under 0.05 ms in total; 3 ms simulation tick; memory ceiling 512 MB. — source: ADR-0011 / ADR-0010
- Render error at the ball's distance: at most 0.0024 u (0.5 px) for any run length, valid under the 8-ulp model. — source: ADR-0013 Requirements

#### Global Engine API Constraints

- Behavior not in the engine reference, NEEDS VERIFICATION: handlers run in connection order (Run State AC-30 spy test on 4.7.2, including disconnect and reconnect). — source: ADR-0002 Verification Required
- Verified by the engine reference (4.7.2): `CONNECT_DEFERRED` handlers run after `emit()` returns; signal argument coercion depends on the handler's typing; lambdas capture primitives by value; `class_name` needs the class cache. — source: ADR-0002
- Spikes PS-1 and PS-2 (device): whether `_process` keeps running through FOCUS_OUT / FOCUS_IN or while backgrounded on Android. — source: ADR-0002
- Run State Open Question 5 (device): whether `Time.get_ticks_usec()` stands still across deep sleep. — source: ADR-0002
- ADR-0010 (device): behavior of `Tween`, `AnimationPlayer`, `GPUParticles3D` and shader time while `dt_eff = 0`. — source: ADR-0002
- `@abstract` (4.5) is optional for interfaces and not required. — source: ADR-0002
- Godot 4.7.2 pinned; `class_name` types need the class cache, so `godot --headless --import` must run before any headless test run. — source: ADR-0009 Engine Compatibility
- `FileAccess.store_*` returns `bool` since 4.4; `duplicate_deep()` and `@abstract` (4.5) are not used in these ADRs' designs. — source: ADR-0007 / ADR-0008
- Spikes and gates carried by this batch: PT-1 to PT-4 (ADR-0010), UI-1 and UI-A1 (ADR-0011), R-1 checks 1 to 15 (ADR-0012), PRC-1 (ADR-0013), HV-1 and R-1 hazard rows (ADR-0014). Behaviours not in `docs/engine-reference` (verified to 4.6 only for ui.md/input.md) must not be relied on for gameplay-critical input. — source: ADR-0010..0014

### GDScript gotchas verified on the 4.7.2 binary
Source: `docs/engine-reference/godot/current-best-practices.md` (verified 2026-09-20).
- No `nextafter`; use a literal double one ulp below a boundary in tests.
- Never name a function `wrap`; an unqualified call resolves to the global `wrap(value, min, max)`. Use `wrap_angle`.
- A static and an instance function cannot share a name.
- `fposmod(a + PI, TAU) - PI` can return `+PI`; an angle wrap needs a `>= PI` guard, and `fposmod(-1e-20, 5.0)` returns exactly `5.0`.
- `Vector3` is 32-bit: keep long-running distances in `float` (64-bit) and cast only when building the vector (ADR-0013: through `WorldFrame.render_z`).
- Signal argument coercion depends on the handler's declared types; use typed handlers.
- A lambda captures a primitive by value and a container by reference; count events through an `Array`.
- `Callable().call()` on an unset Callable is a script error; default to `Callable()` and guard with `is_valid()`.
- `CONNECT_DEFERRED` handlers run after `emit()` returns, escaping any re-entrancy guard.
- `class_name` needs a class cache: run `godot --headless --import` before a headless test run.
