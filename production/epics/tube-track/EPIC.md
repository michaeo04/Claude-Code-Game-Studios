# Epic: Tube Track

> **Layer**: Core
> **GDD**: design/gdd/tube-track.md
> **Architecture Module**: Tube Track
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 14 stories (see table)

## Overview

Tube Track owns the world frame `(theta, s, h)`, the segment window (`TubeWindow` state machine, 12 recycled slots), the seam pattern, map validation (`TubeConfig.validate()`) and `TubeMath` (`wrap_angle`, `delta_theta`, `local_point`, `idle_step` and the F-formulas). `TubeView` renders the slots from one shared mesh and material, re-binds them on a `WorldFrame` rebase and idles the menu tube (ADR-0003, ADR-0013). `advance(s)` has exactly one caller, once per frame, in Running only.

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0002: Game loop, Composition Root and tick order | This ADR makes one scene-root node, `GameRoot`, the Composition Root and the **only** node that runs a per-frame `_process`; it calls every system in one fixed order, builds them in one fixed order, and registers the... | Accepted | LOW |
| ADR-0003: Renderer choice and tube render route | This ADR picks the **Mobile renderer** for the Android build behind a measured device gate (R-1) with **Forward+ as the fallback**, renders the tube as **one `MeshInstance3D` per segment slot sharing one Mesh and one... | Accepted | HIGH |
| ADR-0004: Map Loader and MapConfig | This ADR defines it. An authored `MapDefinition` resource (`.tres`) holds the Environment values and the chunk library; `GameRoot` derives the three Camera values with pure `CameraMath`, and the `MapLoader` builds an... | Accepted | MEDIUM |
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |
| ADR-0013: Distance precision and the render origin (WorldFrame) | A 32-bit render position is not: world z = `-s` loses precision as a run gets long (0.0024 u, half a pixel at the ball's distance, is exceeded at `s` = 16384 under the 2-ulp model and at 4096 under the 8-ulp model). T... | Accepted | HIGH |

**Engine risk of the epic: HIGH** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

24 requirements registered for this system: 12 covered by an ADR, 1 partial, 0 gap, 11 GDD-owned (specified fully by the GDD, no ADR needed).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-tube-track-001 | Define the frame: theta=0 at top (+Y), theta grows clockwise from behind, s grows along -Z, P(theta,s,h)=((R+h)sin t,(R+h)cos t,-s); only Tube Track converts to world space | GDD-owned |
| TR-tube-track-002 | TubeMath static RefCounted functions: wrap_angle (fposmod(a+PI,TAU)-PI plus a guard returning [-PI,PI)), delta_theta, F2-F9, idle_step, local_point(theta, h) -> Vector2 (x, y of the GDD's P; the z part is WorldFrame.render_z, A... | GDD-owned |
| TR-tube-track-003 | TubeConfig (Resource) holds every knob plus the MapConfig fields it reads; validate() returns a SET of stable failure codes | GDD-owned |
| TR-tube-track-004 | TubeWindow (RefCounted, not an autoload) is the state machine: it owns the window, emits the signals, and takes TubeConfig, a log_sink Callable and slot_binder Callable(slot_index:int, segment_index:int) | ADR-0002 ✅ Covered |
| TR-tube-track-005 | State machine of 5 states and 8 events: exactly 16 of 40 (state,event) pairs are accepted; the rest give no state change, no signal and one logged error; load_map is accepted only from Uninitialized and a failed validation keep... | GDD-owned |
| TR-tube-track-006 | advance(s) has exactly one caller, once per frame, valid only in Running; s never decreases (max(s,prev)); equal s is a silent no-op; NaN/INF s is ignored with an error | ADR-0002 ✅ Covered |
| TR-tube-track-007 | Recycling is synchronous inside advance: left(rearmost) then entered(new far) per boundary, in increasing index order; a jump of >=N segments re-primes with window_primed and no segment_* signals | GDD-owned |
| TR-tube-track-008 | Signals carry integers only and re-entrancy is guarded: a mutating call from any handler is rejected with an error; immediate connections only (CONNECT_DEFERRED bypasses the guard) | ADR-0002 ✅ Covered |
| TR-tube-track-009 | Signal order: load_map, to_idle and begin_run emit window_primed, then state_changed (only if the state changed); begin_run from Running re-primes and emits window_primed only; every prime calls the binder N times | GDD-owned |
| TR-tube-track-010 | Window sizing validated at load: A>=ceil((F+v_max*t_lat)/L)+1, B>=ceil((C_b+M_cam)/L); the far edge stays >= F+v_max*t_lat ahead after any call; a slot is recycled only when it is entirely out of view | GDD-owned |
| TR-tube-track-011 | Visibility budget at load: T_vis=(F_read-d_cam)/v_max>=T_VIS_MIN; an empty F range reports only NO_VALID_F | GDD-owned |
| TR-tube-track-012 | Fog must be depth mode with fog_density=1.0 and fog_depth_begin<fog_depth_end=F; F and F_read are radial distances from the eye | ADR-0003 ⚠️ Partial |
| TR-tube-track-013 | Tube is a 32-facet flat-shaded cylinder with vertex radius R, a shared Mesh+Material per slot, no CollisionObject3D; the render route (node per slot, MultiMesh with custom_aabb, or a scrolling shader) is left to an ADR | ADR-0003 ✅ Covered |
| TR-tube-track-014 | SeamPattern resource (n_seams per segment) drives a flat shading band with no geometric relief; seams at (j+0.5)*SP, SP=L/n_seams; f_seam=v_max/SP<=3 Hz; L>=ceil(v_max/3) | GDD-owned |
| TR-tube-track-015 | seam_contrast_scale in [0,1] is sampled EVERY frame in every state (and on setting_changed); a mutation that samples only at load/begin_run must fail | ADR-0003 ✅ Covered |
| TR-tube-track-016 | Idle scroll is the internal step idle_step(dt) driven by the view node's own dt, clamped to t_lat; s_idle=fposmod(...,L) stays in [0,L); no segment_* or window_primed signals in Idle | ADR-0003, ADR-0002 ✅ Covered |
| TR-tube-track-017 | Precision: s is 64-bit and unbounded; world z is placed only through WorldFrame.render_z(s) = -(s - origin_s), with origin_s a whole number of segments rebased when s - origin_s >= REBASE_SEGMENTS * L; no run cap, no precision... | ADR-0013 ✅ Covered |
| TR-tube-track-018 | Segment content is a pure function of (config, absolute index); no randomness; compare by absolute index in segment-local space | GDD-owned |
| TR-tube-track-019 | Core is headless and GUT-testable with test doubles for Camera/Ball/Obstacle; the log sink counts warnings; getters s, first_index, last_index, far_end_s and an ordered signal recorder are needed; the production sink rate-limit... | ADR-0009 ✅ Covered |
| TR-tube-track-020 | A 300 s deterministic simulation at dt=1/64 asserts the far-edge bound, exactly one left+entered pair per boundary (625 total) and slot_index range | ADR-0009 ✅ Covered |
| TR-tube-track-021 | Performance budget: total draw calls<=150, the tube sharing one Mesh+Material | ADR-0003 ✅ Covered |
| TR-tube-track-022 | Memory and allocation: nothing is allocated or freed during a run (slots re-targeted); object/node/resource counts differ by 0 after warm-up; recycle p99 provisionally <=0.2 ms, begin_run <=2 ms | ADR-0003 ✅ Covered |
| TR-tube-track-023 | No persistent state; per-run state is s, s_idle and the window | GDD-owned |
| TR-tube-track-024 | Run State events map through a Tube Track-owned thin adapter to begin_run/pause/resume/end_run/to_idle; the map loader calls load_map and sends map_ready only on success | ADR-0004 ✅ Covered |

**Partial or gap requirements:** stories for these carry the open point named in `docs/architecture/architecture-traceability.md` (Partial Coverage) and are marked Blocked until it is closed.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/tube-track.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [TubeMath frame, angle wrap, lane/facet formulas](story-001-tubemath-frame-angles.md) | Logic | Complete | ADR-0013 |
| 002 | [TubeMath segment index, window sizes, seam spacing](story-002-tubemath-segments-window-seams.md) | Logic | Complete | ADR-0009 |
| 003 | [TubeConfig resource and validate() code set](story-003-tubeconfig-validation.md) | Logic | Complete | ADR-0004 |
| 004 | [WorldFrame render origin and rebase lint](story-004-worldframe-render-origin.md) | Logic | Ready | ADR-0013 |
| 005 | [TubeWindow state machine, priming, load_map](story-005-tubewindow-state-machine.md) | Logic | Complete | ADR-0002 |
| 006 | [advance(s) and synchronous recycling](story-006-tubewindow-advance-recycling.md) | Logic | Complete | ADR-0002 |
| 007 | [Re-entrancy guard, binder contract](story-007-tubewindow-reentrancy-guard.md) | Logic | Complete | ADR-0002 |
| 008 | [Idle scroll step and deterministic content](story-008-idle-scroll-and-content-determinism.md) | Logic | Complete | ADR-0003 |
| 009 | [300 s deterministic window simulation](story-009-window-simulation-300s.md) | Logic | Complete | ADR-0009 |
| 010 | [Run State adapter and map-load integration](story-010-run-state-adapter.md) | Integration | Complete | ADR-0004 |
| 011 | [TubeView mesh, shared material, slots, rebase](story-011-tubeview-mesh-slots.md) | Integration | Ready | ADR-0003 |
| 012 | [Seam shader band and per-frame seam_contrast_scale](story-012-seam-shader-contrast-scale.md) | Logic | Ready | ADR-0003 |
| 013 | [R-1 renderer gate and device performance evidence](story-013-r1-gate-device-performance.md) | Integration | Ready | ADR-0003 |
| 014 | [Seam visual checks and speed-cue playtest](story-014-seam-visual-feel-evidence.md) | Visual/Feel | Ready | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/tube-track/story-001-tubemath-frame-angles.md`, then `/dev-story`.
