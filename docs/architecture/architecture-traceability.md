# Architecture Traceability Index

Last Updated: 2026-10-03 (run 5, after the run 4 amendment pass 226c97c)
Engine: Godot 4.7.2 (Android only, ADR-0001)
Source: `/architecture-review` full mode, 2026-10-03, five runs (`architecture-review-2026-10-03.md`, `-rerun.md`, `-run3.md`, `-run4.md`, `-run5.md`). Registry: `docs/architecture/tr-registry.yaml` (runs 4 and 5: no new IDs; TR-tube-track-017 was revised by ADR-0013; TR-tube-track-002 needs a text revision once run 5 C-21 is decided).

## How to read this

A requirement is **architecture-relevant** when satisfying it needs a decision that crosses systems or depends on engine behaviour (tick order, renderer, file I/O, platform, content format, test harness). Pure core logic that a GDD fully specifies (formulas, state machines, per-system validation) is **➖ GDD-owned**: it needs no ADR beyond the module shape of ADR-0002 and the test framework of ADR-0009, and is excluded from the coverage percentages. All ADRs except ADR-0001 are still **Proposed**, so every ✅ means *addressed by a written decision*, not *a decision that is Accepted*.

## Coverage Summary

- Total requirements: 348
- Architecture-relevant: 191
- ✅ Covered: 179 (94%)
- ⚠️ Partial: 11 (6%)
- ❌ Gap: 1 (1%)
- ➖ GDD-owned (not counted): 157

| System | Total | ✅ | ⚠️ | ❌ | ➖ |
|---|---|---|---|---|---|
| tube-track | 24 | 12 | 1 | 0 | 11 |
| ball-movement | 23 | 5 | 0 | 0 | 18 |
| tilt-input | 26 | 13 | 0 | 0 | 13 |
| camera | 21 | 5 | 0 | 0 | 16 |
| obstacle-system | 24 | 18 | 1 | 0 | 5 |
| pattern-difficulty | 21 | 10 | 2 | 0 | 9 |
| near-miss-detection | 19 | 9 | 1 | 0 | 9 |
| scoring-personal-best | 20 | 5 | 1 | 0 | 14 |
| run-state-restart | 25 | 13 | 1 | 0 | 11 |
| platform-services | 20 | 17 | 1 | 0 | 2 |
| save-persistence | 22 | 21 | 1 | 0 | 0 |
| settings-accessibility | 15 | 5 | 1 | 0 | 9 |
| juice-feedback | 22 | 11 | 0 | 1 | 10 |
| environment-theming | 19 | 12 | 1 | 0 | 6 |
| hud | 23 | 8 | 0 | 0 | 15 |
| menus-screen-flow | 24 | 15 | 0 | 0 | 9 |
| **All** | **348** | **179** | **11** | **1** | **157** |

### History

| Date | Covered | Partial | Gap | Notes |
|---|---|---|---|---|
| 2026-10-03 | 157 (82%) | 17 | 17 | first run, ADR-0001 to ADR-0009 |
| 2026-10-03 | 172 (90%) | 17 | 2 | re-run, plus ADR-0011, ADR-0012, ADR-0014 |
| 2026-10-03 | 174 (91%) | 15 | 2 | run 3, plus ADR-0010 (TR-juice-feedback-007, TR-menus-screen-flow-012 now covered) |
| 2026-10-03 | 179 (94%) | 11 | 1 | run 4, plus ADR-0013; amendment pass closed C-1 to C-17 (TR-tube-track-015, -016, -017, TR-camera-016, TR-settings-accessibility-009 now covered); first engine-specialist run, no BLOCKER or HIGH |

## Known Gaps (❌)

| TR-ID | Requirement | Missing decision | Suggested ADR |
|---|---|---|---|
| TR-juice-feedback-016 | Three cues. Whoosh lasts 0.08 s from rim onset. The hit sting is a dry transient with decay at most 300-400 ms | three cues; bus layout and OS audio policy owner (ADR-0015, Proposed) | ADR-0015 |

## Partial Coverage (⚠️)

| TR-ID | ADR | Why partial |
|---|---|---|
| TR-tube-track-012 | ADR-0003 | depth fog verified on Forward+ only; Mobile gated by R-1 |
| TR-obstacle-system-010 | ADR-0008 | mechanism changed (shared immutable spec, no copy); GDD wording must be revised |
| TR-pattern-difficulty-011 | ADR-0008 | generalized padding changes CR9 and F2c; Pattern design review required |
| TR-pattern-difficulty-014 | ADR-0004 | t_dodge_worst supply to Tube Track is not in the MapConfig or from_map path |
| TR-near-miss-detection-019 | (Juice) | coalescing handed to Juice; no ADR owns it |
| TR-scoring-personal-best-003 | ADR-0009 | script reflection (get_script_method_list) unverified on 4.7.2 |
| TR-run-state-restart-022 | ADR-0002 | t_reset shares unverified for N=12; Environment, Settings, Near-Miss shares missing |
| TR-platform-services-006 | ADR-0006 | Back on Android 16 / SDK 36 unverified; release blocker if undelivered (PS-4) |
| TR-save-persistence-012 | ADR-0007 | ADR-0007 logs file-level failures once per load; GDD F2 and AC-10 say once per key |
| TR-settings-accessibility-005 | ADR-0007 | slider commit on drag_ended; Settings CR5 still says write on every change |
| TR-environment-theming-012 | ADR-0014 | plinth is surface 1 with an Environment material, but the GDD span (gate arc plus 0.5 D) covers the gap; per-piece footings need an Environment GDD revision (ADR-0014 OQ1) |

## Full Matrix (architecture-relevant requirements)

| TR-ID | Requirement | ADR | Status |
|---|---|---|---|
| TR-tube-track-004 | TubeWindow (RefCounted, not an autoload) is the state machine: it owns the window, emits the signals | ADR-0002 | ✅ Covered |
| TR-tube-track-006 | advance(s) has exactly one caller, once per frame, valid only in Running; s never decreases (max(s,p | ADR-0002 | ✅ Covered |
| TR-tube-track-008 | Signals carry integers only and re-entrancy is guarded: a mutating call from any handler is rejected | ADR-0002 | ✅ Covered |
| TR-tube-track-012 | Fog must be depth mode with fog_density=1.0 and fog_depth_begin<fog_depth_end=F; F and F_read are ra | ADR-0003 | ⚠️ Partial |
| TR-tube-track-013 | Tube is a 32-facet flat-shaded cylinder with vertex radius R, a shared Mesh+Material per slot, no Co | ADR-0003 | ✅ Covered |
| TR-tube-track-015 | seam_contrast_scale in [0,1] is sampled EVERY frame in every state (and on setting_changed); a mutat | ADR-0003 | ✅ Covered |
| TR-tube-track-016 | Idle scroll is the internal step idle_step(dt) driven by the view node's own dt, clamped to t_lat; s | ADR-0003, ADR-0002 | ✅ Covered |
| TR-tube-track-017 | Precision: s is 64-bit; z=-s is cast to 32-bit only when the Vector3 is built; no rebase; one debug  | ADR-0013 | ✅ Covered |
| TR-tube-track-019 | Core is headless and GUT-testable with test doubles for Camera/Ball/Obstacle; the log sink counts wa | ADR-0009 | ✅ Covered |
| TR-tube-track-020 | A 300 s deterministic simulation at dt=1/64 asserts the far-edge bound, exactly one left+entered pai | ADR-0009 | ✅ Covered |
| TR-tube-track-021 | Performance budget: total draw calls<=150, the tube sharing one Mesh+Material | ADR-0003 | ✅ Covered |
| TR-tube-track-022 | Memory and allocation: nothing is allocated or freed during a run (slots re-targeted); object/node/r | ADR-0003 | ✅ Covered |
| TR-tube-track-024 | Run State events map through a Tube Track-owned thin adapter to begin_run/pause/resume/end_run/to_id | ADR-0004 | ✅ Covered |
| TR-ball-movement-005 | step() is called once per rendered frame, after Run State tick() and Tilt poll/flush, in every phase | ADR-0002 | ✅ Covered |
| TR-ball-movement-013 | Contact is not detected here: no collider, CharacterBody3D or hit_reported; Obstacle System owns swe | ADR-0008 | ✅ Covered |
| TR-ball-movement-019 | Ball view is a smooth-shaded sphere with a cool-white rim; cosmetic roll rate speed/radius and a cap | ADR-0012 | ✅ Covered |
| TR-ball-movement-020 | Oracles come from tools/reference-sim/ball_movement.js; fixture make_ball_fixture(), make_core(cfg,d | ADR-0009 | ✅ Covered |
| TR-ball-movement-021 | Device gates need a measurable harness: per-frame theta logging, a 240 fps jig, evidence files under | ADR-0009 | ✅ Covered |
| TR-tilt-input-001 | Only the TiltInput node reads motion sensors (Input.get_gravity and siblings); CI lint enforces it o | ADR-0005 | ✅ Covered |
| TR-tilt-input-003 | TiltMath static holds F1-F4, should_reanchor and sensor_lost_pause_needed; TiltCore (RefCounted, no  | ADR-0002 | ✅ Covered |
| TR-tilt-input-006 | poll() takes no argument, is called once per rendered frame in every phase by one caller, before bal | ADR-0002 | ✅ Covered |
| TR-tilt-input-007 | Time comes from the injected microsecond clock (Time.get_ticks_usec, not engine delta); dt=clamp((no | ADR-0002 | ✅ Covered |
| TR-tilt-input-014 | Level-triggered pause evaluated by adapter.flush() once per frame, AFTER tilt.poll and BEFORE Run St | ADR-0002 | ✅ Covered |
| TR-tilt-input-015 | App lifecycle comes from Platform Services signals app_backgrounded/app_foregrounded (provisional na | ADR-0006 | ✅ Covered |
| TR-tilt-input-016 | ProjectSettings required: input_devices/sensors/enable_gravity (and enable_accelerometer if the acce | ADR-0005 | ✅ Covered |
| TR-tilt-input-017 | Gravity is screen-relative on Android in every orientation (x,y swapped/negated for ROTATION_90/180/ | ADR-0005 | ✅ Covered |
| TR-tilt-input-019 | Fallback input (key+touch via fallback_source) is built and unit-tested in TiltCore but NOT wired by | ADR-0005 | ✅ Covered |
| TR-tilt-input-022 | poll() cost on-device p95<=0.1 ms over >=1000 frames; end-to-end latency p95<=100 ms (P-1, P-2) | ADR-0005 | ✅ Covered |
| TR-tilt-input-023 | Pure fixtures: live_core(pose, step_us) helper; ticks of +16667 us (not 1/60); loss tests at 50 Hz ( | ADR-0009 | ✅ Covered |
| TR-tilt-input-024 | CI lint script (tools/ci/, not yet written) is a blocking gate before the first Tilt story is Done:  | ADR-0009 | ✅ Covered |
| TR-tilt-input-026 | Device evidence V-1 (sensor sign, signed by qa-lead and technical-director) BLOCKS the first playabl | ADR-0005 | ✅ Covered |
| TR-camera-014 | No collision body; camera is outside the tube by construction (CAMERA_RADIUS>TUBE_RADIUS+0.5); stati | ADR-0009 | ✅ Covered |
| TR-camera-015 | Camera is read-only and side-effect-free: no requests to Ball Movement, Tube Track or Run State; lin | ADR-0009 | ✅ Covered |
| TR-camera-016 | Publish rear_extent=C_b=CAMERA_BACK_DISTANCE=6.0 and camera_distance (worst-case 7.84, shipped 8) as | ADR-0004 | ✅ Covered |
| TR-camera-019 | Safe area is read from Platform Services (soft, provisional) | ADR-0006 | ✅ Covered |
| TR-camera-020 | Perf: one Camera3D, per-frame transform update only; no draw cost of its own | ADR-0003 | ✅ Covered |
| TR-obstacle-system-002 | A hazard is `{hazard_id:int>=0, footprint_pieces:[(theta_min,theta_max,s_start,s_end)], home_segment | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-003 | The hit test is analytic (no `CollisionObject3D`/`Area3D`/`PhysicsServer3D`). It is a swept AABB: `s | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-004 | The test runs exactly once per published `(theta_prev,theta,s_prev,s)` pair, in the same tick domain | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-005 | Reporting is level-triggered. One `hit_reported(hazard_id:int, run_id:int)` is sent per overlapped h | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-006 | Lifecycle follows Tube Track's signals. `segment_entered_window(i)` calls the provider once and spaw | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-007 | Obstacle System emits `hazard_bound(hazard_id, footprint_pieces)` on spawn and `hazard_released(haza | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-008 | The `run_reset(run_id)` handler only stores `run_id`. It must not clear, reseed or reset the id coun | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-009 | The content seam is `HazardContentProvider.hazards_for_segment(segment_index:int) -> Array[HazardSpe | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-010 | If `HazardSpec` is a Resource, each spawned hazard gets an owned deep copy. Plain `duplicate()` is s | ADR-0008 | ⚠️ Partial |
| TR-obstacle-system-011 | Footprint bounds are unwrapped reals with `theta_min<=theta_max` and width `<2*PI`. A seam-crossing  | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-012 | An offline preflight runs over the whole library, exhaustively (not fail-fast), in deterministic ord | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-013 | The live `hazards_for_segment` call may re-run the checks only as a debug-build assertion. It never  | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-015 | A non-finite published `theta` or `s` is a no-op frame (last good swept endpoint held) with one erro | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-017 | Per-tick work is bounded by `MAX_PIECES_PER_SEGMENT`=12 (safe range 6-20) times at most `N_MAX`=16 w | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-018 | No side effects: the only output is `hit_reported` (plus the two Near-Miss signals). Obstacle System | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-019 | A lint over ObstacleMath/Core/Config and their transitive dependencies bans `CollisionObject3D`, `Ch | ADR-0009 | ✅ Covered |
| TR-obstacle-system-021 | Determinism: no randomness; two instances fed the same 500-tick script give bit-identical `hit_repor | ADR-0008, ADR-0002 | ✅ Covered |
| TR-obstacle-system-022 | A hazard that hit the ball stays bound through the Hit freeze. Recycling happens only inside `advanc | ADR-0002 | ✅ Covered |
| TR-obstacle-system-023 | Hazards render at full silhouette and chroma the instant they enter the visible arc (no fade, alpha  | ADR-0014 | ✅ Covered |
| TR-pattern-difficulty-002 | Chunk record: `{chunk_id, tier, segment_count 1-3, hazard_placements:[(local_segment_index, hazard_t | ADR-0008 | ✅ Covered |
| TR-pattern-difficulty-003 | PatternCore is the `HazardContentProvider`: `hazards_for_segment(index)` returns empty for `index<0` | ADR-0008 | ✅ Covered |
| TR-pattern-difficulty-006 | The PRNG is a `RandomNumberGenerator` with an explicit `seed` set from `run_id` before the first dra | ADR-0008 | ✅ Covered |
| TR-pattern-difficulty-007 | On `run_reset(run_id)` Pattern reseeds, reshuffles all three bags, discards in-progress chunk state  | ADR-0008 | ✅ Covered |
| TR-pattern-difficulty-009 | The preflight inherits Obstacle's gates. Every authored piece must pass `HIDDEN_CONTENT_FORBIDDEN` ( | ADR-0008 | ✅ Covered |
| TR-pattern-difficulty-011 | Cross-chunk spacing is enforced by sequencer padding. A pruned read history holds `(s_start, theta_s | ADR-0008 | ⚠️ Partial |
| TR-pattern-difficulty-014 | Config guards: `TIER_ORDER_INVALID`, `TIER_DURATION_OUT_OF_RANGE` (intro 8-20, ramp 45-240, checked  | ADR-0004 | ⚠️ Partial |
| TR-pattern-difficulty-015 | Determinism: the same `run_id` and the same call script give bit-identical chunk sequences. A differ | ADR-0008 | ✅ Covered |
| TR-pattern-difficulty-016 | Obstacle must call `hazards_for_segment` in increasing index order, once each. PatternCore state (mi | ADR-0008 | ✅ Covered |
| TR-pattern-difficulty-018 | Lint bans the engine-coupling tokens except `RandomNumberGenerator` with an explicit seed (the lint  | ADR-0009 | ✅ Covered |
| TR-pattern-difficulty-019 | The statistical shuffle-fairness test is ADVISORY: chi-square over 500 `run_id`s, N=8, p>0.01. Use a | ADR-0009 | ✅ Covered |
| TR-pattern-difficulty-021 | The chunk-library data format is only logically specified (the record in TR-002). The on-disk format | ADR-0008 | ✅ Covered |
| TR-near-miss-detection-004 | Output is edge-triggered: exactly one `near_miss_detected(hazard_id:int, run_id:int)` on the near-zo | ADR-0008, ADR-0002 | ✅ Covered |
| TR-near-miss-detection-005 | A hit overrides: `hit_reported` sets `hit_ever_true`, and the hazard never emits a near-miss. Within | ADR-0008, ADR-0002 | ✅ Covered |
| TR-near-miss-detection-006 | A release with `released_by_reset==true` emits nothing (reset, re-prime, to-idle, Paused to Restart/ | ADR-0008, ADR-0002 | ✅ Covered |
| TR-near-miss-detection-008 | The `near_miss_detected` payload is exactly `{hazard_id, run_id}` (strict allowlist, no closeness va | ADR-0008, ADR-0002 | ✅ Covered |
| TR-near-miss-detection-010 | Preflight `NEAR_ZONE_OVERLAP` covers the 3+ pieces sharing a critical `s0` case. It is checked on an | ADR-0008, ADR-0002 | ✅ Covered |
| TR-near-miss-detection-011 | The test runs every tick in every phase (stationary degenerate case). A non-finite `theta` or `s` is | ADR-0008, ADR-0002 | ✅ Covered |
| TR-near-miss-detection-013 | Same-tick `hazard_bound` plus `hazard_released` creates then tears down with no emit. A release on t | ADR-0008, ADR-0002 | ✅ Covered |
| TR-near-miss-detection-016 | Lint (engine-coupling regex family, as Obstacle) plus a reuse-not-reimplement guard (no second `arc_ | ADR-0009 | ✅ Covered |
| TR-near-miss-detection-017 | NM-1 on-device check, BLOCKING at first-playable: near-miss-to-hazard-passed ratio within +/-20% bet | ADR-0009 | ✅ Covered |
| TR-near-miss-detection-019 | None owned. Juice owns the VFX/audio/haptic. A coalescing requirement is handed to Juice (two near-m | (Juice) | ⚠️ Partial |
| TR-scoring-personal-best-003 | The public surface is exactly six non-underscore methods: `step()`, `on_run_reset()`, `on_run_ended( | ADR-0009 | ✅ Covered (reflection verified on 4.7.2, story 008) |
| TR-scoring-personal-best-008 | The only persistence is `[scoring].personal_best` in `save.cfg` via Save & Persistence. It is read o | ADR-0007 | ✅ Covered |
| TR-scoring-personal-best-013 | `ScoreService.step()` runs once per tick strictly after Ball Movement's step, using the same callbac | ADR-0002 | ✅ Covered |
| TR-scoring-personal-best-014 | `ScoreService` connects at composition-root construction, before Run State's first emit (Godot drops | ADR-0002 | ✅ Covered |
| TR-scoring-personal-best-019 | CI lints. BLOCKING: no `[autoload]` entry for `ScoreService`/`ScoreCore`. ADVISORY: identifier-only  | ADR-0009 | ✅ Covered |
| TR-scoring-personal-best-020 | Integration, BLOCKING at first-playable (owner user): AC-21 real SaveCore round trip including cold- | ADR-0009 | ✅ Covered |
| TR-run-state-restart-001 | RunStateCore is a RefCounted with no SceneTree, no Node, no autoload, no FileAccess/ConfigFile/user: | ADR-0002 | ✅ Covered |
| TR-run-state-restart-004 | tick(world_dt, real_dt) -> dt_eff runs in this order with one now_us snapshot: stall guard, step can | ADR-0002 | ✅ Covered |
| TR-run-state-restart-006 | pause_requested(app_interrupted) is the only non-queued request: applied at send time (between ticks | ADR-0006 | ✅ Covered |
| TR-run-state-restart-007 | Requests sent from inside a RunState handler or tick are rejected with an Error log (no nesting); ha | ADR-0002 | ✅ Covered |
| TR-run-state-restart-011 | Stall guard: real_dt >= STALL_PAUSE_THRESHOLD in Running/Resuming pauses with source app_interrupted | ADR-0002 | ✅ Covered |
| TR-run-state-restart-012 | real_dt is computed by the driver from the injected monotonic clock (Time.get_ticks_usec), never fro | ADR-0002 | ✅ Covered |
| TR-run-state-restart-014 | press_us is stamped with Time.get_ticks_usec() in the input handler, from InputEventScreenTouch pres | ADR-0005 | ✅ Covered |
| TR-run-state-restart-017 | Events (script signal list exactly 9): run_reset, run_started, run_paused(source), run_resuming(dura | ADR-0002 | ✅ Covered |
| TR-run-state-restart-018 | Pinned subscriber order registered by the composition root: run_reset = Pattern, then (Tube Track ad | ADR-0002 | ✅ Covered |
| TR-run-state-restart-019 | Construction of RunState emits nothing; first possible emission is Boot->Menu on external map_ready, | ADR-0002 | ✅ Covered |
| TR-run-state-restart-020 | Boot->Menu only on map_ready, which the map loader sends only after a successful Tube Track load_map | ADR-0004 | ✅ Covered |
| TR-run-state-restart-022 | Restart budget: touch to first presented frame after run_started <= 1.0 s; sum t_in 0.050 + t_disp 0 | ADR-0002 | ⚠️ Partial |
| TR-run-state-restart-024 | Tick driver contract: owner calls tick() in _process (not _physics_process) with process_mode ALWAYS | ADR-0002 | ✅ Covered |
| TR-run-state-restart-025 | GUT unit tests with injected clock starting well above 0, state factory core_in(phase), signal recor | ADR-0009 | ✅ Covered |
| TR-platform-services-001 | Only the PlatformServices node handles lifecycle notifications, WM_GO_BACK_REQUEST, Input.vibrate_ha | ADR-0006 | ✅ Covered |
| TR-platform-services-002 | Shape: PlatformCore (RefCounted, no engine calls), PlatformMath (static: haptic_gate, effective, int | ADR-0006 | ✅ Covered |
| TR-platform-services-003 | Lifecycle model: flags focused (true at start) and paused (false); FIS=focus_implies_suspend true on | ADR-0006 | ✅ Covered |
| TR-platform-services-004 | Signals emitted on edges only, synchronously in the handler, order app_interrupted, app_backgrounded | ADR-0006 | ✅ Covered |
| TR-platform-services-005 | Lifecycle callbacks may originate on another thread on Android; handlers must run on main thread out | ADR-0006 | ✅ Covered |
| TR-platform-services-006 | Android Back: NOTIFICATION_WM_GO_BACK_REQUEST -> back_pressed, one per notification, decides nothing | ADR-0006 | ⚠️ Partial |
| TR-platform-services-007 | haptic(kind) with NEAR_MISS, HIT, UI_TAP; drop causes in fixed order UNKNOWN_KIND, DISABLED, NOT_ATT | ADR-0006 | ✅ Covered |
| TR-platform-services-008 | Haptic gate: plays if enabled, attentive, dur_eff>0 and (gate_open or prio > last_prio); gate_open = | ADR-0006 | ✅ Covered |
| TR-platform-services-009 | effective(): dur_eff = clamp(duration_ms,0,HAPTIC_MAX_MS); amp_eff = -1 if amplitude<0 else clamp(am | ADR-0006 | ✅ Covered |
| TR-platform-services-010 | HapticsConfig validated at load in order HAPTIC_MAX_MS first then per-kind; clamp to safe range with | ADR-0006 | ✅ Covered |
| TR-platform-services-011 | Lifecycle hook for saving: app_backgrounded is the only flush signal; PS does no saving and never wa | ADR-0006 | ✅ Covered |
| TR-platform-services-012 | Display facts read through injected display_source Callable (Dictionary keys safe_area, screen_size, | ADR-0006 | ✅ Covered |
| TR-platform-services-013 | Keep screen on: DisplayServer.screen_set_keep_on(true) called once at boot, never turned off | ADR-0006 | ✅ Covered |
| TR-platform-services-014 | Project settings manifest (data: section, key, expected, owner tag) linted in CI and checked at boot | ADR-0006 | ✅ Covered |
| TR-platform-services-015 | Frame cap application/run/max_fps = 60 for MVP; fps_eff = min(max_fps, refresh) with fallbacks (refr | ADR-0006 | ✅ Covered |
| TR-platform-services-018 | Device spike PS-1..PS-12 (PS-3, PS-7 removed): PS-1 lifecycle sequences, PS-2 Vulkan PAUSED/RESUMED, | ADR-0009 | ✅ Covered |
| TR-platform-services-019 | Integration harness uses Run State's real SceneTree-free core plus a test-only adapter (INT -> pause | ADR-0009 | ✅ Covered |
| TR-platform-services-020 | Node tested via node.notification(X) against a spy core: each of the 5 notifications calls exactly i | ADR-0009 | ✅ Covered |
| TR-save-persistence-001 | Single file user://save.cfg, ConfigFile format, sections [scoring] (personal_best int only), [settin | ADR-0007 | ✅ Covered |
| TR-save-persistence-002 | SaveCore (RefCounted) with 8 injected seams: config_reader(path)->{status:"OK"/"MISSING"/"PARSE_ERRO | ADR-0007 | ✅ Covered |
| TR-save-persistence-003 | PersistMath static functions: schema_compatible (F1), read_valid and read_error_code (F2), is_serial | ADR-0007 | ✅ Covered |
| TR-save-persistence-004 | API get_value(section, key, default) and set_value(section, key, value)->bool; getters return exactl | ADR-0007 | ✅ Covered |
| TR-save-persistence-005 | Boot read is synchronous and complete before Scoring, Settings, Cosmetics are constructed; no "loade | ADR-0007 | ✅ Covered |
| TR-save-persistence-006 | set_value writes immediately: in-memory update, then config_writer(TMP_PATH, complete sections map), | ADR-0007 | ✅ Covered |
| TR-save-persistence-007 | Every write serializes the complete in-memory section map (including untouched sections, [_meta], an | ADR-0007 | ✅ Covered |
| TR-save-persistence-008 | Real seams: rename via DirAccess.rename_absolute(), delete via DirAccess.remove_absolute(), save via | ADR-0007 | ✅ Covered |
| TR-save-persistence-009 | Orphaned user://save.cfg.tmp is deleted (path_exists then path_delete) before the next temp write | ADR-0007 | ✅ Covered |
| TR-save-persistence-010 | Crash guarantee scoped to app-termination (kill) only, not power loss (no fsync available from GDScr | ADR-0007 | ✅ Covered |
| TR-save-persistence-011 | F1 schema_compatible: is_int type guard first; non-int treated as 0; compatible iff 0 < v <= CURRENT | ADR-0007 | ✅ Covered |
| TR-save-persistence-012 | F2 per-key validity: parsed_ok and compatible and has_key and type_matches; error precedence FILE_UN | ADR-0007 | ⚠️ Partial |
| TR-save-persistence-013 | Corrupt or schema-incompatible file: whole file invalid (all defaults), old file renamed to save.cfg | ADR-0007 | ✅ Covered |
| TR-save-persistence-014 | Oversized file guard: files over SAVE_FILE_SIZE_MAX are rejected before config_reader, handled like  | ADR-0007 | ✅ Covered |
| TR-save-persistence-015 | First launch (status MISSING): all defaults, one INFO log (not error), first set_value creates the f | ADR-0007 | ✅ Covered |
| TR-save-persistence-016 | set_value rejects non-serializable values (raw Object/RefCounted) before any seam call: no memory up | ADR-0007 | ✅ Covered |
| TR-save-persistence-017 | Write-failure logging rate limited per section+key via reused PlatformServices RateLimitedLog on inj | ADR-0007 | ✅ Covered |
| TR-save-persistence-018 | SaveService node listens to PlatformServices app_backgrounded and calls the persist path once (redun | ADR-0007 | ✅ Covered |
| TR-save-persistence-019 | SaveCore and PersistMath contain no ConfigFile, FileAccess, DirAccess, Input., DisplayServer., Engin | ADR-0009 | ✅ Covered |
| TR-save-persistence-020 | SP-2 real-parser sweep on device or editor: hand-crafted files (non-int schema_version, typed-constr | ADR-0007 | ✅ Covered |
| TR-save-persistence-021 | No mid-run persistence and no interface to Run State; no signing/encryption (deliberate: single-play | ADR-0007 | ✅ Covered |
| TR-save-persistence-022 | Fixture uses distinct non-shipped values (schema 3, rate limit 0.05, retention 3) with a shipped-def | ADR-0009 | ✅ Covered |
| TR-settings-accessibility-002 | SettingsCore (RefCounted, no Node) built through three injected Callables get_value_seam(section,key | ADR-0002 | ✅ Covered |
| TR-settings-accessibility-003 | Boot read: exactly five get_value_seam calls (one per key, each with its own default), no batching,  | ADR-0002 | ✅ Covered |
| TR-settings-accessibility-005 | set_value(key,value): no-op if equal to current (no write, no event); else update memory, call set_v | ADR-0007 | ⚠️ Partial |
| TR-settings-accessibility-009 | setting_changed(key, value) signal plus getter are both REQUIRED for the two live consumers (Tube Tr | ADR-0003 | ✅ Covered |
| TR-settings-accessibility-012 | haptics_enabled and haptics_intensity are supplied to PlatformCore (set_haptics_enabled setter; inte | ADR-0006 | ✅ Covered |
| TR-settings-accessibility-015 | Fixture factories make_settings_fixture, make_get_value_stub, make_set_value_stub(succeeds), make_lo | ADR-0009 | ✅ Covered |
| TR-juice-feedback-006 | The run_ended handler order is Juice, then Scoring, then HUD. The run_abandoned handler order is Jui | ADR-0002 | ✅ Covered |
| TR-juice-feedback-007 | Hitstop is a fixed 0.20 s in every mode and never scaled by reduced motion. The composition root inj | ADR-0010 | ✅ |
| TR-juice-feedback-008 | Hit grey-out multiplies chroma toward 0 on all world elements with luminance preserved. The killer h | ADR-0012 | ✅ Covered |
| TR-juice-feedback-009 | Hit flash is a full-screen Rim White overlay, peak opacity at most 0.30, at most 2 frames, at hitsto | ADR-0003 | ✅ Covered |
| TR-juice-feedback-010 | Near-miss ring pulse and PB ring sweep are a shader term on the tube material, additive, Rim White c | ADR-0003 | ✅ Covered |
| TR-juice-feedback-011 | Shard burst is one GPUParticles3D with one mesh and one material. It is visual-only with no physics  | ADR-0003 | ✅ Covered |
| TR-juice-feedback-012 | Ball rim glow is a fresnel treatment layered on the ball's base material. Silhouette and scale are u | ADR-0012 | ✅ Covered |
| TR-juice-feedback-014 | Juice calls haptic(NEAR_MISS) and haptic(HIT) unconditionally, with no haptics_enabled check. There  | ADR-0006 | ✅ Covered |
| TR-juice-feedback-016 | Three cues. Whoosh lasts 0.08 s from rim onset. The hit sting is a dry transient with decay at most  | ADR-0015 (Proposed) | ✅ Covered |
| TR-juice-feedback-017 | Presentation fits the budget. Rings add zero draw calls and shards are batched, so Juice adds at mos | ADR-0003 | ✅ Covered |
| TR-juice-feedback-020 | Tests live in tests/unit/juice_feedback/ as juice_[feature]_test.gd. They use make_juice_fixture, ma | ADR-0009 | ✅ Covered |
| TR-juice-feedback-021 | Device evidence: the 3 flashes/s cap under real frame jitter, Lagoon-edge contrast on a real device, | ADR-0009 | ✅ Covered |
| TR-environment-theming-001 | `EnvConfig` is a Resource holding every MapConfig field it owns (seam_pattern_id, fog_mode, fog_dept | ADR-0004 | ✅ Covered |
| TR-environment-theming-004 | Fog uses a depth ramp with factor = smoothstep(begin, end, d)^curve * density. Density must be 1.0,  | ADR-0003 | ✅ Covered |
| TR-environment-theming-005 | Map load computes F_read from the 4:1 contrast crossing. It rejects with MAP_VISIBILITY_UNSAFE if F_ | ADR-0004 | ✅ Covered |
| TR-environment-theming-006 | Speed-driven fog pull moves only fog_depth_end (written each frame while Running). u = clamp((speed- | ADR-0003 | ✅ Covered |
| TR-environment-theming-007 | A world chroma multiplier of 0.88 at v_max applies to tube, sky and prop materials only. It is a sep | ADR-0012 | ✅ Covered |
| TR-environment-theming-009 | colorblind_safe_enabled applies L_ball_adjusted to the ball material itself. It is read from the get | ADR-0012 | ✅ Covered |
| TR-environment-theming-012 | The Double Gate plinth is environment-owned geometry. Height is 0.15D, the span is the gate arc plus | ADR-0014 | ⚠️ Partial |
| TR-environment-theming-013 | Background props are MultiMesh-instanced, 3-6 meshes. A palette-swap map is retinted material parame | ADR-0003 | ✅ Covered |
| TR-environment-theming-014 | The tube, sky and prop materials use a sky gradient of 2 stops. Sky hue is constant across states. M | ADR-0003 | ✅ Covered |
| TR-environment-theming-015 | Glow and tonemap behaviour on Forward+ (glow before tonemapping since 4.6) must not disturb the cont | ADR-0003 | ✅ Covered |
| TR-environment-theming-016 | Per-frame order is Ball speed read, then F2 evaluation, then the fog write and chroma uniform write. | ADR-0002 | ✅ Covered |
| TR-environment-theming-018 | Tests live in tests/unit/environment_theming/ as environment_theming_[feature]_test.gd. make_env_fix | ADR-0009 | ✅ Covered |
| TR-environment-theming-019 | Deferred checks: the integration driver with a real BallCore, and on-device Mobile-renderer contrast | ADR-0009 | ✅ Covered |
| TR-hud-013 | The view owns a full-screen tap catcher enabled only in Hit. Pause and Menu sit above it with mouse_ | ADR-0005 | ✅ Covered |
| TR-hud-014 | (UX) Layout is dp-based inside Platform Services safe_area. Zones: Z1 top-left, Z2 pause top-right ( | ADR-0006, ADR-0011 | ✅ Covered |
| TR-hud-015 | (UX) dp to viewport units: viewport_units_per_dp = (viewport_size.x/screen_size.x)*(screen_dpi/160). | ADR-0011 | ✅ Covered |
| TR-hud-016 | (UX) The HUD canvas sits above the world and below Menus screens. The Menu/Running Ink cut layer sit | ADR-0011 | ✅ Covered |
| TR-hud-018 | (UX) HUD performance: at most 20 draw calls and 1.0 ms per tick in the worst-case Hit state. No drop | ADR-0003 | ✅ Covered |
| TR-hud-019 | (UX) Touch targets are at least 48 dp and activate on release inside. Press feedback scales to 0.94  | ADR-0005 | ✅ Covered |
| TR-hud-021 | (UX) AccessKit names and reading order are proposals only until verified on 4.7.2. Live score is not | ADR-0011 | ✅ Covered |
| TR-hud-023 | Tests live in tests/unit/hud/ and tests/integration/hud/ as hud_[feature]_test.gd. Fixtures are make | ADR-0009 | ✅ Covered |
| TR-menus-screen-flow-007 | quit() is called exactly once, only from on_quit_confirm_tapped while confirm_quit_open. The dialog  | ADR-0006 | ✅ Covered |
| TR-menus-screen-flow-008 | haptic(UI_TAP) fires on every forwarded or committed on-screen tap. It does not fire on a gated tap  | ADR-0006 | ✅ Covered |
| TR-menus-screen-flow-009 | The map-load-failure screen shows when elapsed Boot time >= MAP_LOAD_TIMEOUT (comparison is >=). It  | ADR-0004 | ✅ Covered |
| TR-menus-screen-flow-011 | Settings is reachable only from Menu-base. Each change calls set_value at once. There is no revert,  | ADR-0007 | ✅ Covered |
| TR-menus-screen-flow-012 | `transition_covering` is true for at least one tick spanning Menu to Running and Running to Menu, an | ADR-0010 | ✅ |
| TR-menus-screen-flow-013 | Restart and Menu stamp press_us on press-down. The readying fill (PAUSE_INPUT_GUARD) is cosmetic and | ADR-0005 | ✅ Covered |
| TR-menus-screen-flow-014 | (UX) Gated controls are shown dimmed (about 45%) with a reason label, never hidden. The Lagoon outli | ADR-0011 | ✅ Covered |
| TR-menus-screen-flow-015 | (UX) Layout is dp-based and thumb-low. Play is 240x72 with centre at min(0.70H, H-232). The Paused R | ADR-0011 | ✅ Covered |
| TR-menus-screen-flow-016 | (UX) Settings is a vertical scroll list with fixed header and Back. A drag starting on a slider thum | ADR-0011 | ✅ Covered |
| TR-menus-screen-flow-018 | (UX) Menus add at most 25 draw calls and 1.0 ms per tick. Menu shows within 100 ms of phase Menu. Se | ADR-0003 | ✅ Covered |
| TR-menus-screen-flow-019 | (UX) The Ink cover sits above the HUD canvas. Menus screens sit above the HUD canvas. The ordinary P | ADR-0011 | ✅ Covered |
| TR-menus-screen-flow-020 | Android Back is delivered as back_pressed. Platform Services sets quit_on_go_back=false. Android-onl | ADR-0006 | ✅ Covered |
| TR-menus-screen-flow-021 | (UX) AccessKit names, roles and reading order are non-binding proposals. The dialog and failure mess | ADR-0011 | ✅ Covered |
| TR-menus-screen-flow-023 | Tests live in tests/unit/menus_screen_flow/ as menu_[feature]_test.gd. A fresh core per case. make_m | ADR-0009 | ✅ Covered |
| TR-menus-screen-flow-024 | Mutation-catching priority: AC-2, 3, 4 (Back bypassing Resume's gate), 5 and 27 are the highest prio | ADR-0009 | ✅ Covered |

## GDD-owned requirements

TR-tube-track-001, TR-tube-track-002, TR-tube-track-003, TR-tube-track-005, TR-tube-track-007, TR-tube-track-009, TR-tube-track-010, TR-tube-track-011, TR-tube-track-014, TR-tube-track-018, TR-tube-track-023, TR-ball-movement-001, TR-ball-movement-002, TR-ball-movement-003, TR-ball-movement-004, TR-ball-movement-006, TR-ball-movement-007, TR-ball-movement-008, TR-ball-movement-009, TR-ball-movement-010, TR-ball-movement-011, TR-ball-movement-012, TR-ball-movement-014, TR-ball-movement-015, TR-ball-movement-016, TR-ball-movement-017, TR-ball-movement-018, TR-ball-movement-022, TR-ball-movement-023, TR-tilt-input-002, TR-tilt-input-004, TR-tilt-input-005, TR-tilt-input-008, TR-tilt-input-009, TR-tilt-input-010, TR-tilt-input-011, TR-tilt-input-012, TR-tilt-input-013, TR-tilt-input-018, TR-tilt-input-020, TR-tilt-input-021, TR-tilt-input-025, TR-camera-001, TR-camera-002, TR-camera-003, TR-camera-004, TR-camera-005, TR-camera-006, TR-camera-007, TR-camera-008, TR-camera-009, TR-camera-010, TR-camera-011, TR-camera-012, TR-camera-013, TR-camera-017, TR-camera-018, TR-camera-021, TR-obstacle-system-001, TR-obstacle-system-014, TR-obstacle-system-016, TR-obstacle-system-020, TR-obstacle-system-024, TR-pattern-difficulty-001, TR-pattern-difficulty-004, TR-pattern-difficulty-005, TR-pattern-difficulty-008, TR-pattern-difficulty-010, TR-pattern-difficulty-012, TR-pattern-difficulty-013, TR-pattern-difficulty-017, TR-pattern-difficulty-020, TR-near-miss-detection-001, TR-near-miss-detection-002, TR-near-miss-detection-003, TR-near-miss-detection-007, TR-near-miss-detection-009, TR-near-miss-detection-012, TR-near-miss-detection-014, TR-near-miss-detection-015, TR-near-miss-detection-018, TR-scoring-personal-best-001, TR-scoring-personal-best-002, TR-scoring-personal-best-004, TR-scoring-personal-best-005, TR-scoring-personal-best-006, TR-scoring-personal-best-007, TR-scoring-personal-best-009, TR-scoring-personal-best-010, TR-scoring-personal-best-011, TR-scoring-personal-best-012, TR-scoring-personal-best-015, TR-scoring-personal-best-016, TR-scoring-personal-best-017, TR-scoring-personal-best-018, TR-run-state-restart-002, TR-run-state-restart-003, TR-run-state-restart-005, TR-run-state-restart-008, TR-run-state-restart-009, TR-run-state-restart-010, TR-run-state-restart-013, TR-run-state-restart-015, TR-run-state-restart-016, TR-run-state-restart-021, TR-run-state-restart-023, TR-platform-services-016, TR-platform-services-017, TR-settings-accessibility-001, TR-settings-accessibility-004, TR-settings-accessibility-006, TR-settings-accessibility-007, TR-settings-accessibility-008, TR-settings-accessibility-010, TR-settings-accessibility-011, TR-settings-accessibility-013, TR-settings-accessibility-014, TR-juice-feedback-001, TR-juice-feedback-002, TR-juice-feedback-003, TR-juice-feedback-004, TR-juice-feedback-005, TR-juice-feedback-013, TR-juice-feedback-013b, TR-juice-feedback-015, TR-juice-feedback-018, TR-juice-feedback-019, TR-environment-theming-002, TR-environment-theming-003, TR-environment-theming-008, TR-environment-theming-010, TR-environment-theming-011, TR-environment-theming-017, TR-hud-001, TR-hud-002, TR-hud-003, TR-hud-004, TR-hud-005, TR-hud-006, TR-hud-007, TR-hud-008, TR-hud-009, TR-hud-010, TR-hud-011, TR-hud-012, TR-hud-017, TR-hud-020, TR-hud-022, TR-menus-screen-flow-001, TR-menus-screen-flow-002, TR-menus-screen-flow-003, TR-menus-screen-flow-004, TR-menus-screen-flow-005, TR-menus-screen-flow-006, TR-menus-screen-flow-010, TR-menus-screen-flow-017, TR-menus-screen-flow-022

## Superseded Requirements

- TR-obstacle-system-010 (deep copy of `HazardSpec`): mechanism superseded by ADR-0008 (shared immutable spec). Still `active` in the registry until ADR-0008 is Accepted and the Obstacle GDD is revised.
