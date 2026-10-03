# Technical Requirements Baseline: Tube Track, Ball Movement, Tilt Input, Camera (2026-10-02)

TECHNICAL REQUIREMENTS BASELINE: tube-track, ball-movement, tilt-input, camera
Source: the four GDDs read in full. Engine flags: H/M/L = post-cutoff risk. "GDD sect" cites the rule (R), formula (F), edge case (EC), acceptance criterion (AC) or open question (OQ).

=== TUBE TRACK ===
TR-tube-track-001 | Core | Define the frame: theta=0 at top (+Y), theta grows clockwise from behind, s grows along -Z, P(theta,s,h)=((R+h)sin t,(R+h)cos t,-s); only Tube Track converts to world space | R=3.0, h>=0; Vector3 float32 only at the build step | Core Rules/Coordinate frame R1
TR-tube-track-002 | Core | TubeMath static RefCounted functions: wrap_angle (fposmod(a+PI,TAU)-PI plus a guard returning [-PI,PI)), delta_theta, F2-F9, idle_step, P (rename to_world suggested in OQ18); non-finite input returns 0 and logs | Built-in wrapf is banned (collapses PI-1e-9 to -PI); GDScript `wrap` global does not parse unqualified; Godot 4.7.2 verified (H) | F1, R2
TR-tube-track-003 | Core | TubeConfig (Resource) holds every knob plus the MapConfig fields it reads; validate() returns a SET of stable failure codes | Codes: NOT_FINITE, NOT_POSITIVE, VISIBILITY, FOG_BEFORE_READ, FOG_DENSITY, FOG_MODE, FOG_RANGE, A_TOO_LARGE, A_TOO_SMALL, A_OUT_OF_RANGE, B_OUT_OF_RANGE, L_INVALID, SEAM_HZ, R_RANGE, NO_VALID_F | EC Map validation
TR-tube-track-004 | Core | TubeWindow (RefCounted, not an autoload) is the state machine: it owns the window, emits the signals, and takes TubeConfig, a log_sink Callable and slot_binder Callable(slot_index:int, segment_index:int) | slot_index=posmod(segment_index,N); N=A+B+1<=16 | Structure
TR-tube-track-005 | Core | State machine of 5 states and 8 events: exactly 16 of 40 (state,event) pairs are accepted; the rest give no state change, no signal and one logged error; load_map is accepted only from Uninitialized and a failed validation keeps Uninitialized (Retry allowed) | 16/40 pairs; AC-19 is table-driven | States and Transitions
TR-tube-track-006 | Timing | advance(s) has exactly one caller, once per frame, valid only in Running; s never decreases (max(s,prev)); equal s is a silent no-op; NaN/INF s is ignored with an error | s is 64-bit float; caller clamps dt to t_lat=0.1 | R4, EC
TR-tube-track-007 | Timing | Recycling is synchronous inside advance: left(rearmost) then entered(new far) per boundary, in increasing index order; a jump of >=N segments re-primes with window_primed and no segment_* signals | floori/posmod only (never int() or %); recycle rate v_max/L = 2.1/s | R6, F2
TR-tube-track-008 | Core | Signals carry integers only and re-entrancy is guarded: a mutating call from any handler is rejected with an error; immediate connections only (CONNECT_DEFERRED bypasses the guard) | state_changed(new,old); window_primed(first,last); segment_entered_window(i); segment_left_window(i) | Interactions, OQ18
TR-tube-track-009 | Core | Signal order: load_map, to_idle and begin_run emit window_primed, then state_changed (only if the state changed); begin_run from Running re-primes and emits window_primed only; every prime calls the binder N times | N=12, indices -2..9 | R11, AC-8, AC-20a
TR-tube-track-010 | Core | Window sizing validated at load: A>=ceil((F+v_max*t_lat)/L)+1, B>=ceil((C_b+M_cam)/L); the far edge stays >= F+v_max*t_lat ahead after any call; a slot is recycled only when it is entirely out of view | A=9, B=2, N=12 at L=12, F=84; A_MAX=12, B_MAX=3, N_MAX=16; C_b=6, M_cam=2 | F3, R6
TR-tube-track-011 | Rendering | Visibility budget at load: T_vis=(F_read-d_cam)/v_max>=T_VIS_MIN; an empty F range reports only NO_VALID_F | T_VIS_MIN=1.5 s (floor 1.43); F_read=46.00, d_cam=8, v_max=25 gives 1.52 s | F9
TR-tube-track-012 | Rendering | Fog must be depth mode with fog_density=1.0 and fog_depth_begin<fog_depth_end=F; F and F_read are radial distances from the eye | Environment fog_mode/fog_depth_begin/fog_depth_end/fog_depth_curve/fog_density; depth fog mode is post-cutoff (4.4+, M-H) and verified on Forward+ only, Mobile unverified | R7
TR-tube-track-013 | Rendering | Tube is a 32-facet flat-shaded cylinder with vertex radius R, a shared Mesh+Material per slot, no CollisionObject3D; the render route (node per slot, MultiMesh with custom_aabb, or a scrolling shader) is left to an ADR | 32 facets; facet gap<=0.02*D (0.0144 at R=3); R in [2.5,3.3]; CylinderMesh axis is Y (rotate 90 degrees) | R3, F7, OQ3, AC-24
TR-tube-track-014 | Rendering | SeamPattern resource (n_seams per segment) drives a flat shading band with no geometric relief; seams at (j+0.5)*SP, SP=L/n_seams; f_seam=v_max/SP<=3 Hz; L>=ceil(v_max/3) | Contrast band [1.15,1.25]; n_seams=1, f=2.08 Hz; seam shader uses fposmod(s,SP) computed in 64-bit and passed as a uniform, never TIME | R9, F5, OQ17
TR-tube-track-015 | Rendering | seam_contrast_scale in [0,1] is sampled EVERY frame in every state (and on setting_changed); a mutation that samples only at load/begin_run must fail | AC-23a | R9
TR-tube-track-016 | Timing | Idle scroll is the internal step idle_step(dt) driven by the view node's own dt, clamped to t_lat; s_idle=fposmod(...,L) stays in [0,L); no segment_* or window_primed signals in Idle | v_idle=1.5 u/s | R11, F8
TR-tube-track-017 | Core | Precision: s is 64-bit and unbounded; world z is placed only through WorldFrame.render_z(s) = -(s - origin_s), origin_s a whole number of segments rebased when s - origin_s >= REBASE_SEGMENTS * L; no run cap, no precision warning (ADR-0013) | z render max 2048 u; REBASE_SEGMENTS 84 (24-128) | R8, F4, ADR-0013
TR-tube-track-018 | Determinism | Segment content is a pure function of (config, absolute index); no randomness; compare by absolute index in segment-local space | AC-18; lint on randf/RandomNumberGenerator | R10
TR-tube-track-019 | Testing | Core is headless and GUT-testable with test doubles for Camera/Ball/Obstacle; the log sink counts warnings; getters s, first_index, last_index, far_end_s and an ordered signal recorder are needed; the production sink rate-limits to 1 per second | tests/unit/tube_track/; `class_name` needs `godot --headless --import` before GUT (Godot 4.7.2) | AC preamble
TR-tube-track-020 | Testing | A 300 s deterministic simulation at dt=1/64 asserts the far-edge bound, exactly one left+entered pair per boundary (625 total) and slot_index range | 19,200 frames; s=7500 | AC-21..23
TR-tube-track-021 | Rendering | Performance budget: total draw calls<=150, the tube sharing one Mesh+Material | Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME; +1 on Forward+, +N on Mobile per MeshInstance3D, MultiMesh +1 | AC-28
TR-tube-track-022 | Core | Memory and allocation: nothing is allocated or freed during a run (slots re-targeted); object/node/resource counts differ by 0 after warm-up; recycle p99 provisionally <=0.2 ms, begin_run <=2 ms | Performance.OBJECT_COUNT/OBJECT_NODE_COUNT/OBJECT_RESOURCE_COUNT; 12 live segments; 512 MB ceiling | R5, AC-29/30
TR-tube-track-023 | SaveLoad | No persistent state; per-run state is s, s_idle and the window | none | Overview
TR-tube-track-024 | Platform | Run State events map through a Tube Track-owned thin adapter to begin_run/pause/resume/end_run/to_idle; the map loader calls load_map and sends map_ready only on success | provisional event names | Interactions

ARCHITECTURE FACTS (tube-track)
- Modules: TubeConfig (Resource), TubeMath (static RefCounted), TubeWindow (RefCounted), SeamPattern (Resource), TubeTrack (Node3D view, injected into Ball Movement/Camera/Obstacle), a Run State adapter owned by Tube Track.
- Owns exclusively: the coordinate frame and the only theta/s/h to world conversion; wrap_angle/delta_theta (the canonical copy Ball Movement and Camera reuse); window and segment lifecycle; seam format and seam constraints; map validation (F3/F5/F9/F7); idle scroll.
- Exposes: advance(s), load_map, unload_map, begin_run, pause, resume, end_run, to_idle; P/to_world, R, surface normal, delta_theta, state; signals as in TR-008.
- Consumes: s (Ball Movement driver), v_max, rear_extent/camera_distance (Camera, published at map load), MapConfig (Environment & Theming), seam_contrast_scale (Settings), Run State events, T_dodge_worst (Pattern & Difficulty).
- Engine classes: Node3D, MeshInstance3D/MultiMesh, ShaderMaterial, Environment (fog).
- Order: init is load_map, then Idle. Per tick, advance(s) runs after Ball Movement's step, in Running only. Idle uses the view's own dt.

CONFLICTS OR GAPS (tube-track)
- Which loop calls advance (`_process` vs physics) is unresolved (game-loop ADR, OQ4).
- Render route is unresolved (OQ3), as are the renderer and the numeric draw-call limit (OQ1), so seam shader and S_PRECISION handling cannot be fixed.
- Run State event names for the adapter are "provisional" here and settled elsewhere. The adapter's skip rules (pause when already Paused, to_idle on Boot to Menu) are only in OQ6.
- d_cam is a fixed 8 here but a derived 6.54-7.84 in Camera; the GDD says "published at map load" without naming the publisher object or call.
- Unvalidated knobs: SEAM_HZ_MAX>3, T_VIS_MIN=0, IDLE_SCROLL_SPEED, t_lat, M_cam and S_PRECISION_LIMIT have no validation code (OQ18). There is no unknown seam_pattern_id handling.
- `log` is a bad parameter name (shadows a global), and the segment_content/tick_idle signatures are not listed in Structure.
- Tube Track does not say how it is told about a mid-run v_max change (assumed static).

=== BALL MOVEMENT ===
TR-ball-movement-001 | Core | BallMath static class holds F1 step, F2 speed and S, wrap_angle (shared verbatim with Tube Track) and F5 T(X,eps); the token wrapf( is forbidden in its file | Godot 4.7.2: wrapf(PI-1e-9) returns -PI (H); AC-25 lint | R13, AC-25
TR-ball-movement-002 | Core | BallCore (RefCounted, no engine calls) takes a validated BallConfig, injected dt_max and a log_sink Callable(level,code,message); events reset(), on_resumed(), step(dt_eff,steer,valid,input_source) | read-only getters phi, phi_anchor, w, t_run | R13
TR-ball-movement-003 | Data | BallConfig (Resource) holds every knob; validated(log_sink) returns a clamped copy and leaves the shipped resource untouched; NaN/INF takes the default; one KNOB_CLAMPED per change | STEER_ARC PI [2.09,PI]; BALL_LAG_TAU 0.06 [0,0.072]; OMEGA_MAX 3.0 [2.75,4]; V_START 10 [6,14]; V_MAX 25 [18,30]; T_RAMP 90 (0 or 45..240); D 0.8 [0.6,1] | Tuning Knobs, AC-19
TR-ball-movement-004 | Core | validated() also runs a derived check: if T(PI,0.05)>1.14 s it lowers BALL_LAG_TAU by bisection (|err|<=1e-9 or 60 iterations), never OMEGA_MAX, and logs one KNOB_CLAMPED | T_DODGE_180=1.064054 s; T_DODGE_180_MAX=1.14; example (2.75,0.072) corrects to 0.046964 | R13, AC-19b/c
TR-ball-movement-005 | Timing | step() is called once per rendered frame, after Run State tick() and Tilt poll/flush, in every phase; dt_eff<=0 or non-finite is a no-op (prev=current, omega=0); dt_eff>dt_max is clamped with DT_OVER_MAX | poll, flush, tick, ball step; log codes BAD_DT, DT_OVER_MAX, BAD_STEER, KNOB_CLAMPED | R2, EC
TR-ball-movement-006 | Physics | Position mapping (POSITION default): phi_target=phi_anchor+STEER_ARC*clamp(steer); e=wrap_angle(target-phi); alpha=1-exp(-dt/tau) (1 if tau<1e-4); step clamped to +-OMEGA_MAX*dt; snap when |e-step|<1e-6 | frame-rate independent when uncapped; 0.05 rad cross-rate tolerance | F1, R4
TR-ball-movement-007 | Physics | Anchor rules: phi_anchor=0 at reset; the first moving step after on_resumed re-bases phi_anchor=phi-STEER_ARC*steer; phi and anchor shift together by multiples of 2PI when |phi|>2PI | AC-10/11/12a | R5
TR-ball-movement-008 | Physics | Speed is the exact integral S(t) of the ramp, s+=S(t_new)-S(t_old), with the T_RAMP<=0 sentinel checked first; t_run is integrated internally and must equal Run State run_time | 10/25/90: S(45)=618.75, S(90)=1575; s hits 16384 at t=682.36 s | F2, R7
TR-ball-movement-009 | Core | Published read-only state after each step: theta, theta_prev, s, s_prev, speed, omega, radius (D/2); omega=(phi_new-phi_old)/dt taken before the 2PI shift; consumers read after the step | per-step bound V_MAX*DT_MAX=2.5 u, OMEGA_MAX*DT_MAX=0.3 rad (up to 3.0 u / 0.4 rad at knob maxima); omega range valid for dt>=1e-4 | R8, F4
TR-ball-movement-010 | Core | Held-steer semantics: valid=false or non-finite steer holds the last accepted steer (BAD_STEER for non-finite only); steer is clamped to [-1,1]; a no-op step never updates the held value | AC-17 | EC
TR-ball-movement-011 | Core | reset() is synchronous with no loop, allocation or .new()/load() in the body; it zeroes everything, clears the mode latch and held steer, and sets speed=speed(0) | budget about 1 ms on-device; structural lint plus OBJECT_COUNT | R9, AC-27
TR-ball-movement-012 | Core | RATE mode and the FALLBACK latch stay in BallCore (latched on the first dt>0 step after reset) but the MVP driver never passes FALLBACK; a no-sensor device is blocked at HUD/Menus | F3 coast 0.18 rad; MAPPING_MODE enum | R6, AC-15/16
TR-ball-movement-013 | Core | Contact is not detected here: no collider, CharacterBody3D or hit_reported; Obstacle System owns swept overlap using (theta_prev,s_prev)->(theta,s) and must derive bounds from the loaded config | Tube Track AC-24, AC-25 | R11, OQ4
TR-ball-movement-014 | Core | Ball placement is by the driver using Tube Track P(theta,s,h) with h=D/2 (ring radius R+D/2); Ball Movement never reads raw world Z (lint: position.z, global_position.z, global_transform.origin) | R+D/2=3.4 | R1, AC-25
TR-ball-movement-015 | Determinism | Same input sequence gives the same output, bit-identical; no randomness, no shared static state; no const container or top-level subscript assignment in BallMath | AC-24, AC-25 | R12
TR-ball-movement-016 | Timing | Phase-free inertness: dt_eff=0 on settling ticks (after run_started and run_resumed), Hit, Paused and Resuming freezes everything bit-identically | AC-4, AC-31 | R10
TR-ball-movement-017 | Timing | dt and angle are 64-bit; |s-S(t_run)|<=1e-6 after 100,000 frames | F6, AC-22
TR-ball-movement-018 | Timing | The 60 Hz fairness contract: software response<=0.13 s and end-to-end<=0.20 s at 60 Hz; 30 Hz is recorded but not fairness-gated; latency stack is 0.11 s on top of T_DODGE_180 | BM-1a/1b; F9 margin about 0.08 s | F5b, B10
TR-ball-movement-019 | Rendering | Ball view is a smooth-shaded sphere with a cool-white rim; cosmetic roll rate speed/radius and a capped lean from omega are derived in the view layer (no state in core); no speed VFX on the ball | radius 0.4; chroma 0.08-0.12; contrast>=4:1 | Visual/Audio
TR-ball-movement-020 | Testing | Oracles come from tools/reference-sim/ball_movement.js; fixture make_ball_fixture(), make_core(cfg,dt_max=0.1), make_sink(); steer tables in one constants file; LCG for pseudo-random tables; each row is its own test with a fresh core | tests/unit/ball_movement/ball_movement_[feature]_test.gd; 1e-6 tolerance; AC-5b pins GDScript ln() | AC preamble
TR-ball-movement-021 | Testing | Device gates need a measurable harness: per-frame theta logging, a 240 fps jig, evidence files under production/qa/evidence/ball-movement/bm-N.md; BM-1a, BM-1b, BM-3 BLOCK the first playable | BM-1a median<=0.13 s; BM-1b <=0.20 s (worst 0.25); BM-3 30/30 per condition | Gate policy
TR-ball-movement-022 | SaveLoad | No persisted state; per-run state only (reset each run) | none | R9
TR-ball-movement-023 | Core | Reset glide: segment(s) covering s=0..>=11 u must be hazard-free because reset glide is up to T(PI,0.05)=1.064 s | consumed by Pattern & Difficulty | R5

ARCHITECTURE FACTS (ball-movement)
- Modules: BallCore, BallMath, BallConfig, plus a ball driver and view (not named classes).
- Owns exclusively: ball state (phi, theta, s, h, speed, t_run, phi_anchor), D, V_MAX/V_START/T_RAMP/OMEGA_MAX/STEER_ARC/BALL_LAG_TAU, T_DODGE_180, the speed curve, the steer-to-motion mapping.
- Exposes: step/reset/on_resumed; theta, theta_prev, s, s_prev, speed, omega, radius; BallMath.T(), speed(t), S(t); consts for Pattern & Difficulty.
- Consumes: steer, valid, input_source (Tilt, pulled once per frame after the poll); dt_eff, run_reset, run_resumed (Run State); wrap_angle and R (Tube Track); injected dt_max.
- Engine classes: none in the core; the view uses Node3D/MeshInstance3D.
- Order: run_reset subscriber order is Pattern & Difficulty, Tube Track adapter / Obstacle System, Ball Movement, Camera, then the rest (set by Run State). Per frame: tilt.poll, adapter.flush, Run State tick, ball step, consumers read, advance(s), mesh placement.

CONFLICTS OR GAPS (ball-movement)
- The driver that calls step() and advance(s) is unnamed and has no owner (game-loop ADR). AC-29, AC-30 and AC-31 are unticketed.
- The collision method (analytic vs Jolt) is unresolved and the contact ADR is pending (OQ4). Obstacle System's swept test is described only as "provisional".
- The F5 latency stack (0.11 s) is a guess and its cascaded-lag approximation error is unbounded (deferred). The 30 Hz margin is not derived.
- AC-12 (resume/steer accumulation) has no oracle. AC-9 and AC-13 are only reasoned, not machine-verified.
- No run cap or s rebase exists, although s reaches the 16384 limit at 682 s (OQ6).
- The Game Modes BallConfig override ranges are not covered. There is no Settings exposure of MAPPING_MODE, TILT_FULL_SCALE or sensitivity (OQ10, 13).
- The registry (`entities.yaml`) was flagged stale in pass 4.

=== TILT INPUT ===
TR-tilt-input-001 | Core | Only the TiltInput node reads motion sensors (Input.get_gravity and siblings); CI lint enforces it on src/ | Input.get_gravity() (Android TYPE_GRAVITY, 4.x, M-H); regex lint AC-37a | R1
TR-tilt-input-002 | Core | Publish by pull (no per-frame signal): steer finite in [-1,1], valid bool, input_source (SENSOR/FALLBACK); steer>0 when the right edge is lowered; NaN/INF becomes 0 with one BAD_OUTPUT; reading twice without poll gives the same value | AC-46a | R2
TR-tilt-input-003 | Core | TiltMath static holds F1-F4, should_reanchor and sensor_lost_pause_needed; TiltCore (RefCounted, no Node, no Input) takes sample_source Callable()->Vector3, clock Callable()->int (us), log_sink Callable(level,code,detail), fallback_source Callable()->int, is_debug, sensors_enabled, is_portrait, TiltConfig | invalid Callable logs one error and leaves the core Unavailable (is_valid guard) | R12, AC-47c
TR-tilt-input-004 | Core | TiltRunAdapter (RefCounted) glues Run State: injected request_pause Callable(source) and phase_source Callable()->phase; caches the previous phase for run_reset; exposes flush() | built against Run State's SceneTree-free core; AC-39 BLOCKING | R12, AC-39
TR-tilt-input-005 | Data | TiltConfig (Resource) with validated() applying the rule 14 order; test-only unvalidated() not referenced from src/; PHI_MAX, FS_EFF_MAX, F_MIN, BUFFER_AGE, TAU_FLOOR, DROPOUT_MIN_POLLS and REANCHOR_FS_CAP are constants | FS 25 [12,45]; DZ 1.5 [0,4]; tau 0.05 [0.02,0.1]; k 1 [1,2]; W 0.3; G 0.25; N_min 5; sign -1 | R12, R14
TR-tilt-input-006 | Timing | poll() takes no argument, is called once per rendered frame in every phase by one caller, before ball step; polling from _physics_process is unsupported; the driver needs PROCESS_MODE_ALWAYS to poll while Paused | Node.process_mode=PROCESS_MODE_ALWAYS; physics interpolation moved to scene tree in 4.5 and 120 Hz can run 2 `_process` per tick (H) | R6, OQ4
TR-tilt-input-007 | Timing | Time comes from the injected microsecond clock (Time.get_ticks_usec, not engine delta); dt=clamp((now-prev)/1e6,0,0.1); an equal or backwards stamp appends no sample and uses dt=0; the first poll (even stamp 0) is accepted | DT_MAX 0.1 s; all durations converted with roundi(x*1e6) and compared as integer microseconds | R6, R8, AC-25
TR-tilt-input-008 | Core | Pipeline order: validity, roll F1, subtract neutral, low-pass F3, then dead zone+scale+clamp+curve F4 | phi=SENSOR_SIGN*deg(asin(clamp(g.x/|g|))); G_MIN 3 m/s^2; alpha=1-exp(-dt/max(tau,0.005)) | R5, F1-F4
TR-tilt-input-009 | Data | Ring buffer: PackedFloat64Array of angles plus PackedInt64Array of stamps with a head index, capacity 256, BUFFER_AGE 1.0 s, oldest overwritten, no getters exposing it (copies only) | AC-26 | R8
TR-tilt-input-010 | Core | Neutral capture is the median of samples in the closed window [t-G-W, t-G]; fewer than N_min sets neutral_pending (median of the first N_min valid samples after the event); a new capture while pending restarts the accumulator; filter starts at 0 after a capture | G+W<=0.9; SETTLE+G+W<=1.0; N_min<=floor(W*20) | R8, F2
TR-tilt-input-011 | Core | Capture policy: always capture on run_reset from Boot/Menu/unknown and on run_resumed; restart from Hit/Paused uses conditional re-anchor (should_reanchor needs N>=N_min, spread<=RA_S, known phi_stop, median differs from phi0 AND phi_stop by >RA_eff); else inherit | RA_eff=min(12, 0.5*FS_eff); spread<=3.0; on_run_stopped records stop_us and phi_stop | R7, F2
TR-tilt-input-012 | Core | Availability states Acquiring/Live/Unavailable with availability_changed(available:bool) emitted whenever valid changes (none at construction); SENSOR_START_TIMEOUT leads to FALLBACK only if sensor_ever_live is false, else Unavailable | timeout 2.0 s inclusive; SENSOR_TIMEOUT error | States, AC-29/38/49
TR-tilt-input-013 | Core | Dropout hold counts clamped poll time and consecutive invalid polls: held while invalid_us<=HOLD OR invalid_polls<3; then Unavailable (valid false, steer 0, neutral_stale set) | DROPOUT_HOLD 0.1 s; DROPOUT_MIN_POLLS 3 | R10, F6
TR-tilt-input-014 | Timing | Level-triggered pause evaluated by adapter.flush() once per frame, AFTER tilt.poll and BEFORE Run State tick (never inside a Run State handler): request pause_requested(sensor_lost) iff valid false and phase in {Running,Resuming}; at most one request per frame | order poll, flush, tick, ball step; AC-43/43b | R10, R6
TR-tilt-input-015 | Platform | App lifecycle comes from Platform Services signals app_backgrounded/app_foregrounded (provisional names), which on Android derive from FOCUS_OUT/IN (NOTIFICATION_APPLICATION_PAUSED/_RESUMED may never fire under Vulkan); on background: clear buffer, set neutral_stale, go Acquiring; on foreground discard samples for SENSOR_RESUME_SETTLE | settle 0.3 s; Notification FOCUS_OUT/IN (M) | R9, AC-24
TR-tilt-input-016 | Platform | ProjectSettings required: input_devices/sensors/enable_gravity (and enable_accelerometer if the accelerometer fallback is kept), both default false and need a restart; display/window/handheld/orientation=1 (portrait; default 0 is landscape); read with explicit get_setting default; steer_left/steer_right InputMap actions | Godot 4.7.2 portrait enum value 1 verified (H); manifest lint under Platform Services AC-13 | R3, R9, AC-37d
TR-tilt-input-017 | Platform | Gravity is screen-relative on Android in every orientation (x,y swapped/negated for ROTATION_90/180/270), so no axis remap and no sign flip in reverse portrait; NOT_PORTRAIT is diagnostic only; SENSOR_SIGN expected -1 (confirm by V-1) | Godot 4.7.2 source check; units m/s^2 (V-5) | R3, R4
TR-tilt-input-018 | Platform | Vector3 is float32: a (1e30,0,0) vector must give finite steer and (1e200,0,0) becomes INF and is rejected as invalid before F1 | AC-46b/c; double-precision builds tested separately | EC
TR-tilt-input-019 | Core | Fallback input (key+touch via fallback_source) is built and unit-tested in TiltCore but NOT wired by any MVP driver (no-sensor device is blocked "device not supported"); FALLBACK is terminal for the session; capture events are no-ops there | FALLBACK_SLEW 4/s; AC-33/48 | R11, R13
TR-tilt-input-020 | Core | Settings sensitivity hook: FS_eff=min(FS/sensitivity,50); sensitivity NaN/INF/<=0 becomes 1, finite clamps to [0.5,2.0] with one KNOB_CLAMPED each | SENSITIVITY_MIN 0.5 / MAX 2.0 | F4, EC
TR-tilt-input-021 | Core | Log codes SENSORS_DISABLED, SENSOR_TIMEOUT, NOT_PORTRAIT, KNOB_CLAMPED, BAD_OUTPUT, POSTURE_UNSUPPORTED; core logs every rejection; production sink allows <=1 message per code per 1.0 s of injected clock | AC-42 | R12
TR-tilt-input-022 | Performance | poll() cost on-device p95<=0.1 ms over >=1000 frames; end-to-end latency p95<=100 ms (P-1, P-2) | spike, ADVISORY | Spike
TR-tilt-input-023 | Testing | Pure fixtures: live_core(pose, step_us) helper; ticks of +16667 us (not 1/60); loss tests at 50 Hz (+20000 us); tolerance 1e-3 deg, 1e-4 steer; no test steps 60 Hz to reach a round second; GDScript seams: lambdas capture by value, self-capturing lambdas in RefCounted leak (use bound methods or dispose()), preload to avoid class_name cache collisions in headless | tests/unit/tilt_input/, tests/integration/tilt_input/; GUT vs gdUnit4 undecided (OQ16) | AC preamble, R12
TR-tilt-input-024 | Testing | CI lint script (tools/ci/, not yet written) is a blocking gate before the first Tilt story is Done: 37a-37f cover Input. calls, no Engine/Time/OS in core, no touch events, project.godot, unvalidated() use, poll() only in the driver | regex, best-effort | AC-37, Gate policy
TR-tilt-input-025 | SaveLoad | No persistence: phi0, phi_f, phi_stop and neutral_pending/stale are in-session only; neutral resets each launch | none | R7, R8
TR-tilt-input-026 | Testing | Device evidence V-1 (sensor sign, signed by qa-lead and technical-director) BLOCKS the first playable; AC-40 (end-to-end sign) is owned by a Ball Movement epic story | production/qa/evidence/tilt-input/v1-sign.md | Gate policy

ARCHITECTURE FACTS (tilt-input)
- Modules: TiltMath, TiltCore, TiltConfig, TiltRunAdapter, TiltInput (Node, reads sensor/ProjectSettings/keys and forwards).
- Owns exclusively: sensor reading and availability, axis/sign, neutral capture and policy, dead zone, filter, sensitivity, sensor-lost logic, fallback input, the poll clock.
- Exposes: steer, valid, input_source, state, phi0, phi_f, phi_stop, neutral_pending, neutral_stale, sensor_ever_live, sample_count (getters); poll(); on_run_reset(prev_phase), on_run_resumed(), on_run_stopped(), on_app_backgrounded(), on_app_foregrounded(); signal availability_changed(available:bool); adapter flush() and pause_requested(sensor_lost) via the injected request_pause.
- Consumes: Run State events (run_reset with previous phase, run_resumed, run_ended, run_paused, phase_changed, phase_source), Platform Services (lifecycle signals, portrait lock, sensor settings), Settings (sensitivity), HUD/Menus (touch hold into fallback_source), the game clock.
- Engine classes: Input (get_gravity), ProjectSettings, Time, InputMap, Node (process_mode).
- Order: construct (Acquiring or Live FALLBACK), then per frame in one `_process`: tilt.poll, adapter.flush, Run State tick, ball step. Capture happens synchronously in the run_reset handler before run_started.

CONFLICTS OR GAPS (tilt-input)
- Game-loop ADR and sensor-source ADR (get_gravity vs accelerometer) are unwritten; the driver and clock owner are unnamed.
- Platform Services signal names app_backgrounded/app_foregrounded are provisional; the Run State handler signatures (run_reset previous_phase, phase_changed) are pinned only in the Run State GDD, not here.
- Test framework: GUT (technical-preferences) vs gdUnit4 (CI line); the CI line itself is flagged unverified.
- tools/ci lint script is unwritten (a blocking gate). TiltRunAdapter ACs depend on Run State's core, which has no ticket.
- Low frame rates (<=20 Hz) can drop the neutral window below N_min (OQ28); no jolt guard on the inherit path; DT_MAX is not a validated knob.
- Whether TYPE_GRAVITY exists on target devices, its latency, and whether device sleep counts in the clock are all unmeasured.
- Touch fallback is dead code in the MVP (kept deliberately); Settings sensitivity UI has no GDD.

=== CAMERA ===
TR-camera-001 | Core | CameraMath static holds F1 lag step, F2 d_cam, F3 VISIBLE_ARC_HALF_WIDTH, F4 position/look-at, F5 FOV ease; wrap_angle reused verbatim, never reimplemented | AC-1..9 | R11
TR-camera-002 | Core | CameraCore (RefCounted, no engine calls) holds phi_cam and FOV-punch state; driven by injected read-only doubles for Ball Movement (theta,s), Tube Track (R), Run State (run_reset/run_paused/run_ended) plus a log_sink | AC-11..16 | R11
TR-camera-003 | Data | CameraConfig (Resource) holds all knobs; validated(log_sink) returns a clamped copy and enforces CAMERA_RADIUS>TUBE_RADIUS and CAMERA_RADIUS>=TUBE_RADIUS+MARGIN_MIN (CAMERA_RADIUS_TOO_CLOSE naming both values) | CAMERA_LAG_TAU 1/3 [0.15,0.6]; CAMERA_RADIUS 6.0 [4,8]; BACK_DISTANCE 6.0 [3,10]; LOOK_AHEAD 12 [6,20]; MARGIN_MIN 0.5 [0.25,1.5]; FOV 75 [60,90] | R10, AC-10, AC-17
TR-camera-004 | Physics | First-order lag on the orbit angle: e_cam=wrap_angle(theta-phi_cam); alpha=1-exp(-dt/tau) (alpha=1 if tau<1e-4); phi_cam=wrap_angle(phi_cam+e_cam*alpha); NO rate cap | tau=1/3 s exact (prototype CAMERA_FOLLOW_SPEED=3 is a rate); step 0.0487706 at 1/60; |e_cam|<=OMEGA_MAX*tau about 1.0 rad | F1, R1, AC-1..4
TR-camera-005 | Rendering | Camera up vector points radially outward at its own lagged angle phi_cam, so the camera rolls with its orbit and the tube stays static and centred | Camera3D look_at with up=(sin phi_cam, cos phi_cam, 0)-style vector from P | R1
TR-camera-006 | Rendering | camera_position=P(phi_cam, s_ball-CAMERA_BACK_DISTANCE, CAMERA_RADIUS-R) and look_at_point=P(any, s_ball+CAMERA_LOOK_AHEAD, -R) (on axis), both through Tube Track's P; Camera never computes world coordinates itself | AC-5 | F4, R3
TR-camera-007 | Core | d_cam is derived only (no setter): sqrt(r_ball^2+CAMERA_RADIUS^2-2*r_ball*CAMERA_RADIUS*cos(delta)+BACK^2) | 6.539 best, 7.843 worst (delta=1.0), 11.15 theoretical; r_ball=R+D/2=3.4 | F2, R2, AC-6/7
TR-camera-008 | Core | VISIBLE_ARC_HALF_WIDTH=acos(TUBE_RADIUS/CAMERA_RADIUS), a pure function of those two values only, bit-identical regardless of BACK_DISTANCE and phi_cam (mutation test) | 1.047198 rad (60 degrees); floor 0.505474 at margin 0.5 | F3, R4, AC-8/9
TR-camera-009 | Timing | dt_eff<=0 or non-finite is a frozen no-op (phi_cam, position, d_cam bit-identical; BAD_DT logged for non-zero invalid); non-finite theta is a no-op with one error | AC-12/13 | R5, EC
TR-camera-010 | Timing | run_reset snaps phi_cam to the ball's start angle (0.0 bit-identical) with no lag carryover; handler must run after Ball Movement's reset (subscriber order pinned by Run State) | R5 relies on order; no AC here | R5, AC-11
TR-camera-011 | Timing | Camera is inert on dt_eff=0 exactly as Ball Movement is (Hit, Paused, Resuming, settling tick), with no phase logic of its own | R5, States
TR-camera-012 | Rendering | apply_fov_punch(amount,duration) additively widens fov and eases linearly back; a new call REPLACES the in-progress ease (no stacking); fov_offset(t)=amount*max(0,1-t/duration) | CAMERA_FOV 75 deg; Juice values amount 1.125 deg, duration 0.08 s; Camera3D.fov | F5, R7, AC-15
TR-camera-013 | Rendering | No screen shake ever; the only camera-owned transform change besides orbit is the FOV punch | art bible | Visual/Audio
TR-camera-014 | Physics | No collision body; camera is outside the tube by construction (CAMERA_RADIUS>TUBE_RADIUS+0.5); static lint forbids CollisionObject3D, Area3D, PhysicsServer, RayCast3D | AC-17 | R6, R10
TR-camera-015 | Core | Camera is read-only and side-effect-free: no requests to Ball Movement, Tube Track or Run State; lint tokens include request_, hit_reported, Input., Engine., Time., OS., DisplayServer., get_tree, _process, randi/randf | AC-17 | R8
TR-camera-016 | Data | Publish rear_extent=C_b=CAMERA_BACK_DISTANCE=6.0 and camera_distance (worst-case 7.84, shipped 8) as map-load configuration values to Tube Track, and VISIBLE_ARC_HALF_WIDTH to Obstacle System | feeds Tube Track F3/F9 | Interactions, Dependencies
TR-camera-017 | Determinism | Identical (theta,dt_eff) sequences incl. resets, freezes and non-finite inputs give bit-identical phi_cam, position and d_cam | AC-16 | R9
TR-camera-018 | Testing | make_camera_fixture(): tau=1.0/3.0 full precision, radius 6, back 6, look-ahead 12, margin 0.5; doubles supply TUBE_RADIUS 3.0, D 0.8, OMEGA_MAX 3.0; make_core(cfg), make_sink(); tests in tests/unit/camera/camera_[feature]_test.gd; exact == for logs and snapped poses, 1e-6 otherwise | AC preamble
TR-camera-019 | Platform | Safe area is read from Platform Services (soft, provisional) | interface undefined | Interactions, OQ4
TR-camera-020 | Rendering | Perf: one Camera3D, per-frame transform update only; no draw cost of its own | within 150 draw calls | n/a
TR-camera-021 | SaveLoad | No persisted state; per-run state is phi_cam and the FOV ease | none | n/a

ARCHITECTURE FACTS (camera)
- Modules: CameraMath, CameraCore, CameraConfig, plus a Camera3D node/view (unnamed).
- Owns exclusively: the orbit lag, camera pose, d_cam derivation, VISIBLE_ARC_HALF_WIDTH, C_b/rear_extent, FOV baseline and the FOV punch mechanism.
- Exposes: step(theta,s,dt_eff), on_run_reset(), on_run_paused/ended (hold), apply_fov_punch(amount,duration); getters phi_cam, camera_position, look_at_point, d_cam, fov_offset; config values rear_extent, camera_distance, VISIBLE_ARC_HALF_WIDTH.
- Consumes: theta, s (omega, speed listed but unused by the formulas) from Ball Movement; R and P from Tube Track; run_reset/paused/ended from Run State; Juice calls apply_fov_punch.
- Engine classes: Camera3D (fov, look_at), Node3D.
- Order: after Ball Movement's step and after Tube Track's pose is known each frame; run_reset subscriber order ends with Camera after Ball Movement.

CONFLICTS OR GAPS (camera)
- Camera GDD is "pending independent /design-review"; the subscriber-order dependency for the snap is only in Run State (no AC here).
- Camera's step interface (name, args, who calls it, per-frame vs signal-driven) is not defined; "reads omega/speed" is listed but no formula uses them.
- The Camera3D node, its owner, and the up-vector construction are not specified (only the math).
- The VISIBLE_ARC centre is a proxy (THETA_REF=0) of live phi_cam; whether the error matters is open (OQ2). Safe-area interface is undefined (OQ4).
- Tube Track's d_cam=8 is a hand-copied constant, not a live subscription; a retune of CAMERA_RADIUS/BACK_DISTANCE/OMEGA_MAX can silently invert F9's safety margin. There is no automated cross-check.
- apply_fov_punch units (degrees) are only implied by the "same degree units" note, while the F5 example uses 0.05 (inconsistent with Juice's 1.125 degrees).
- Camera rendering of Camera3D under the Forward+/Mobile decision is untested.
