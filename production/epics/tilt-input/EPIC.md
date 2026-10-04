# Epic: Tilt Input

> **Layer**: Core
> **GDD**: design/gdd/tilt-input.md
> **Architecture Module**: Tilt Input
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 16 stories (see table)

## Overview

Tilt Input turns the device gravity vector (`Input.get_gravity()`, read once per rendered frame) into `steer`, `valid` and `input_source`: neutral capture, dead zone, curve, filter and sensitivity (`TiltMath`, `TiltCore`, `TiltConfig`). The only file allowed to read a sensor; the touch pipeline (Hit tap catcher, stock Buttons, `press_us` stamps) is specified in ADR-0005.

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0002: Game loop, Composition Root and tick order | This ADR makes one scene-root node, `GameRoot`, the Composition Root and the **only** node that runs a per-frame `_process`; it calls every system in one fixed order, builds them in one fixed order, and registers the... | Accepted | LOW |
| ADR-0005: Sensor source and input pipeline | This ADR fixes one sensor source (**`Input.get_gravity()` only**, a device without it is "device not supported"), the required ProjectSettings, and one touch pipeline (the Hit tap catcher reacts to `InputEventScreenTo... | Accepted | HIGH |
| ADR-0006: Android platform integration | This ADR keeps one GDScript `PlatformServices` node as the only owner of OS calls, fixes the lifecycle and Back policy, sets the device floor (Android 9+, Vulkan 1.1) and defines the export preset (Gradle build, AAB,... | Accepted | HIGH |
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |

**Engine risk of the epic: HIGH** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

26 requirements registered for this system: 13 covered by an ADR, 0 partial, 0 gap, 13 GDD-owned (specified fully by the GDD, no ADR needed).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-tilt-input-001 | Only the TiltInput node reads motion sensors (Input.get_gravity and siblings); CI lint enforces it on src/ | ADR-0005 ✅ Covered |
| TR-tilt-input-002 | Publish by pull (no per-frame signal): steer finite in [-1,1], valid bool, input_source (SENSOR/FALLBACK); steer>0 when the right edge is lowered; NaN/INF becomes 0 with one BAD_OUTPUT; reading twice without poll gives the same... | GDD-owned |
| TR-tilt-input-003 | TiltMath static holds F1-F4, should_reanchor and sensor_lost_pause_needed; TiltCore (RefCounted, no Node, no Input) takes sample_source Callable()->Vector3, clock Callable()->int (us), log_sink Callable(level,code,detail), fall... | ADR-0002 ✅ Covered |
| TR-tilt-input-004 | TiltRunAdapter (RefCounted) glues Run State: injected request_pause Callable(source) and phase_source Callable()->phase; caches the previous phase for run_reset; exposes flush() | GDD-owned |
| TR-tilt-input-005 | TiltConfig (Resource) with validated() applying the rule 14 order; test-only unvalidated() not referenced from src/; PHI_MAX, FS_EFF_MAX, F_MIN, BUFFER_AGE, TAU_FLOOR, DROPOUT_MIN_POLLS and REANCHOR_FS_CAP are constants | GDD-owned |
| TR-tilt-input-006 | poll() takes no argument, is called once per rendered frame in every phase by one caller, before ball step; polling from _physics_process is unsupported; the driver needs PROCESS_MODE_ALWAYS to poll while Paused | ADR-0002 ✅ Covered |
| TR-tilt-input-007 | Time comes from the injected microsecond clock (Time.get_ticks_usec, not engine delta); dt=clamp((now-prev)/1e6,0,0.1); an equal or backwards stamp appends no sample and uses dt=0; the first poll (even stamp 0) is accepted | ADR-0002 ✅ Covered |
| TR-tilt-input-008 | Pipeline order: validity, roll F1, subtract neutral, low-pass F3, then dead zone+scale+clamp+curve F4 | GDD-owned |
| TR-tilt-input-009 | Ring buffer: PackedFloat64Array of angles plus PackedInt64Array of stamps with a head index, capacity 256, BUFFER_AGE 1.0 s, oldest overwritten, no getters exposing it (copies only) | GDD-owned |
| TR-tilt-input-010 | Neutral capture is the median of samples in the closed window [t-G-W, t-G]; fewer than N_min sets neutral_pending (median of the first N_min valid samples after the event); a new capture while pending restarts the accumulator;... | GDD-owned |
| TR-tilt-input-011 | Capture policy: always capture on run_reset from Boot/Menu/unknown and on run_resumed; restart from Hit/Paused uses conditional re-anchor (should_reanchor needs N>=N_min, spread<=RA_S, known phi_stop, median differs from phi0 A... | GDD-owned |
| TR-tilt-input-012 | Availability states Acquiring/Live/Unavailable with availability_changed(available:bool) emitted whenever valid changes (none at construction); SENSOR_START_TIMEOUT leads to FALLBACK only if sensor_ever_live is false, else Unav... | GDD-owned |
| TR-tilt-input-013 | Dropout hold counts clamped poll time and consecutive invalid polls: held while invalid_us<=HOLD OR invalid_polls<3; then Unavailable (valid false, steer 0, neutral_stale set) | GDD-owned |
| TR-tilt-input-014 | Level-triggered pause evaluated by adapter.flush() once per frame, AFTER tilt.poll and BEFORE Run State tick (never inside a Run State handler): request pause_requested(sensor_lost) iff valid false and phase in {Running,Resumin... | ADR-0002 ✅ Covered |
| TR-tilt-input-015 | App lifecycle comes from Platform Services signals app_backgrounded/app_foregrounded (provisional names), which on Android derive from FOCUS_OUT/IN (NOTIFICATION_APPLICATION_PAUSED/_RESUMED may never fire under Vulkan); on back... | ADR-0006 ✅ Covered |
| TR-tilt-input-016 | ProjectSettings required: input_devices/sensors/enable_gravity (and enable_accelerometer if the accelerometer fallback is kept), both default false and need a restart; display/window/handheld/orientation=1 (portrait; default 0... | ADR-0005 ✅ Covered |
| TR-tilt-input-017 | Gravity is screen-relative on Android in every orientation (x,y swapped/negated for ROTATION_90/180/270), so no axis remap and no sign flip in reverse portrait; NOT_PORTRAIT is diagnostic only; SENSOR_SIGN expected -1 (confirm... | ADR-0005 ✅ Covered |
| TR-tilt-input-018 | Vector3 is float32: a (1e30,0,0) vector must give finite steer and (1e200,0,0) becomes INF and is rejected as invalid before F1 | GDD-owned |
| TR-tilt-input-019 | Fallback input (key+touch via fallback_source) is built and unit-tested in TiltCore but NOT wired by any MVP driver (no-sensor device is blocked "device not supported"); FALLBACK is terminal for the session; capture events are... | ADR-0005 ✅ Covered |
| TR-tilt-input-020 | Settings sensitivity hook: FS_eff=min(FS/sensitivity,50); sensitivity NaN/INF/<=0 becomes 1, finite clamps to [0.5,2.0] with one KNOB_CLAMPED each | GDD-owned |
| TR-tilt-input-021 | Log codes SENSORS_DISABLED, SENSOR_TIMEOUT, NOT_PORTRAIT, KNOB_CLAMPED, BAD_OUTPUT, POSTURE_UNSUPPORTED; core logs every rejection; production sink allows <=1 message per code per 1.0 s of injected clock | GDD-owned |
| TR-tilt-input-022 | poll() cost on-device p95<=0.1 ms over >=1000 frames; end-to-end latency p95<=100 ms (P-1, P-2) | ADR-0005 ✅ Covered |
| TR-tilt-input-023 | Pure fixtures: live_core(pose, step_us) helper; ticks of +16667 us (not 1/60); loss tests at 50 Hz (+20000 us); tolerance 1e-3 deg, 1e-4 steer; no test steps 60 Hz to reach a round second; GDScript seams: lambdas capture by val... | ADR-0009 ✅ Covered |
| TR-tilt-input-024 | CI lint script (tools/ci/, not yet written) is a blocking gate before the first Tilt story is Done: 37a-37f cover Input. calls, no Engine/Time/OS in core, no touch events, project.godot, unvalidated() use, poll() only in the dr... | ADR-0009 ✅ Covered |
| TR-tilt-input-025 | No persistence: phi0, phi_f, phi_stop and neutral_pending/stale are in-session only; neutral resets each launch | GDD-owned |
| TR-tilt-input-026 | Device evidence V-1 (sensor sign, signed by qa-lead and technical-director) BLOCKS the first playable; AC-40 (end-to-end sign) is owned by a Ball Movement epic story | ADR-0005 ✅ Covered |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/tilt-input.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Tilt Input CI lint gate (AC-37)](story-001-tilt-lint-gate.md) | Integration | Ready | ADR-0009, ADR-0005 |
| 002 | [TiltMath pure functions](story-002-tilt-math.md) | Logic | Complete | ADR-0002 |
| 003 | [TiltConfig, validation, sensitivity](story-003-tilt-config.md) | Logic | Complete | ADR-0009 |
| 004 | [TiltCore poll, stamps, ring buffer](story-004-tilt-core-poll-buffer.md) | Logic | Complete | ADR-0002 |
| 005 | [Neutral capture mechanics](story-005-neutral-capture.md) | Logic | Ready | ADR-0002 |
| 006 | [Pipeline order and output contract](story-006-pipeline-output-contract.md) | Logic | Complete | ADR-0005 |
| 007 | [Capture policy and re-anchor](story-007-capture-policy-reanchor.md) | Logic | Ready | ADR-0002 |
| 008 | [Availability states and timeout](story-008-availability-states.md) | Logic | Ready | ADR-0005 |
| 009 | [Sensor-loss dropout hold](story-009-sensor-loss-hold.md) | Logic | Ready | ADR-0005 |
| 010 | [App lifecycle handling](story-010-app-lifecycle.md) | Logic | Ready | ADR-0006 |
| 011 | [Fallback input and transition table](story-011-fallback-input.md) | Logic | Ready | ADR-0005 |
| 012 | [TiltRunAdapter and sensor-lost pause](story-012-tilt-run-adapter.md) | Integration | Ready | ADR-0002 |
| 013 | [TiltInput node, settings, log sink](story-013-tilt-input-node.md) | Integration | Ready | ADR-0005 |
| 014 | [Spike V-1 / V-5 on devices](story-014-v1-sensor-sign-device.md) | Integration | Ready | ADR-0005 |
| 015 | [Spikes P-1 / P-2 / P-3](story-015-p1-p2-p3-device-performance.md) | Integration | Ready | ADR-0005 |
| 016 | [Spikes V-2..V-9 and AC-41](story-016-feel-posture-tuning-spikes.md) | Visual/Feel | Ready | ADR-0005 |

## Next Step

Run `/story-readiness production/epics/tilt-input/story-001-tilt-lint-gate.md`, then `/dev-story`.
