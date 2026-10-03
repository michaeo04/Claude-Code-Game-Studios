# Epic: Run State & Restart

> **Layer**: Foundation
> **GDD**: design/gdd/run-state-restart.md
> **Architecture Module**: Run State & Restart
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 14 stories (see table)

## Overview

Run State & Restart is the single owner of the game phase (Boot, Menu, Running, Paused, Hit, Resuming), `run_id`, the run clock and the request queue. It turns `tick(world_dt, real_dt)` into `dt_eff` (0 outside Running), applies the pause, resume, restart and menu requests in a fixed order with a re-entrancy guard, and emits the nine phase and run signals in the subscriber order that `GameRoot._wire()` registers (ADR-0002). It has no engine calls.

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0002: Game loop, Composition Root and tick order | This ADR makes one scene-root node, `GameRoot`, the Composition Root and the **only** node that runs a per-frame `_process`; it calls every system in one fixed order, builds them in one fixed order, and registers the... | Accepted | LOW |
| ADR-0004: Map Loader and MapConfig | This ADR defines it. An authored `MapDefinition` resource (`.tres`) holds the Environment values and the chunk library; `GameRoot` derives the three Camera values with pure `CameraMath`, and the `MapLoader` builds an... | Accepted | MEDIUM |
| ADR-0005: Sensor source and input pipeline | This ADR fixes one sensor source (**`Input.get_gravity()` only**, a device without it is "device not supported"), the required ProjectSettings, and one touch pipeline (the Hit tap catcher reacts to `InputEventScreenTo... | Accepted | HIGH |
| ADR-0006: Android platform integration | This ADR keeps one GDScript `PlatformServices` node as the only owner of OS calls, fixes the lifecycle and Back policy, sets the device floor (Android 9+, Vulkan 1.1) and defines the export preset (Gradle build, AAB,... | Accepted | HIGH |
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |
| ADR-0010: Presentation time, hit-stop and the Ink cover | This ADR makes **one rule** for presentation time: every presentation effect is a pure function of a **microsecond stamp** taken from the injected `clock_us` and the current `clock_us` (`elapsed = (now_us - start_us)... | Accepted | LOW |

**Engine risk of the epic: HIGH** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

25 requirements registered for this system: 13 covered by an ADR, 1 partial, 0 gap, 11 GDD-owned (specified fully by the GDD, no ADR needed).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-run-state-restart-001 | RunStateCore is a RefCounted with no SceneTree, no Node, no autoload, no FileAccess/ConfigFile/user://, no Time./Engine. calls (clock injected); no references to other systems' classes | ADR-0002 ✅ Covered |
| TR-run-state-restart-002 | Exactly 6 phases (Boot, Menu, Running, Paused, Resuming, Hit); RunState is the sole owner of the phase; starts in Boot, run_id 0 | GDD-owned |
| TR-run-state-restart-003 | Requests are queued when sent and processed at the next tick; a request invalid for the current phase is ignored with one log line at a fixed level class (silent/debug/warning/error) via injected log_sink(level, message) | GDD-owned |
| TR-run-state-restart-004 | tick(world_dt, real_dt) -> dt_eff runs in this order with one now_us snapshot: stall guard, step candidate, requests in class priority (hit, pause, resume, menu, restart, map_ready, start), timers, commit | ADR-0002 ✅ Covered |
| TR-run-state-restart-005 | Same-tick hit selection: drop stale run_id first, then lowest non-negative hazard_id wins, -1 only if no known id; other negative ids treated as -1 with one warning | GDD-owned |
| TR-run-state-restart-006 | pause_requested(app_interrupted) is the only non-queued request: applied at send time (between ticks) in Running or Resuming; queued hits then meet Paused and are ignored | ADR-0006 ✅ Covered |
| TR-run-state-restart-007 | Requests sent from inside a RunState handler or tick are rejected with an Error log (no nesting); handlers must be connected directly (no CONNECT_DEFERRED) and must not await in run_reset | ADR-0002 ✅ Covered |
| TR-run-state-restart-008 | Two-step start: run_reset(run_id) then run_started(run_id) in the same tick; every run_reset handler returns before run_started; run_id +1 per run_reset, never reused; run_time resets to 0 | GDD-owned |
| TR-run-state-restart-009 | Run clock F1: step=min(dt,DT_MAX) if finite>0 else 0; dt_eff nonzero only if tick began and ended in Running, not settling, no stall; run_time is 64-bit float; run_time_ms=round(t*1000) | GDD-owned |
| TR-run-state-restart-010 | Settling tick: first tick after run_started and after run_resumed has dt_eff=0, no stall guard, all hit_reported ignored | GDD-owned |
| TR-run-state-restart-011 | Stall guard: real_dt >= STALL_PAUSE_THRESHOLD in Running/Resuming pauses with source app_interrupted and discards the tick's hits; real_dt NaN/inf/negative counts as 0 (warning max 1/s) | ADR-0002 ✅ Covered |
| TR-run-state-restart-012 | real_dt is computed by the driver from the injected monotonic clock (Time.get_ticks_usec), never from the engine delta (engine delta is time_scale-scaled and capped ~0.133 s) | ADR-0002 ✅ Covered |
| TR-run-state-restart-013 | Restart lock: restart/menu accepted in Hit only if press_us - hit_us >= RESTART_LOCK_us; press_us missing/non-positive replaced by now_us, future clamped to now_us, each with one error; restart_unlocked(run_id) emitted once per... | GDD-owned |
| TR-run-state-restart-014 | press_us is stamped with Time.get_ticks_usec() in the input handler, from InputEventScreenTouch pressed only (never also the emulated mouse event); no buffering of presses; resting-thumb press never counts | ADR-0005 ✅ Covered |
| TR-run-state-restart-015 | Pause guard: restart/menu from Paused accepted only if press_us - paused_us >= PAUSE_INPUT_GUARD_us; guard restarts at each entry to Paused; resume never guarded and wins same-tick ties; abandon emits run_abandoned(run_id, run_... | GDD-owned |
| TR-run-state-restart-016 | Resume countdown measured with timestamps (not deltas): remaining = max(0, RESUME_COUNTDOWN-(now_us-resume_us)/1e6); static helper progress_for(duration, elapsed) returns 1 if duration <= 0; run_resuming(duration_ms) emitted on... | GDD-owned |
| TR-run-state-restart-017 | Events (script signal list exactly 9): run_reset, run_started, run_paused(source), run_resuming(duration_ms), run_resumed(run_id), run_ended(run_id,hazard_id,run_time_ms), run_abandoned(run_id,run_time_ms), restart_unlocked(run... | ADR-0002 ✅ Covered |
| TR-run-state-restart-018 | Pinned subscriber order registered by the composition root: run_reset = Pattern, then (Tube Track adapter, Obstacle), then Ball Movement, then Camera, then rest; run_ended = Juice, Scoring, HUD, rest; run_abandoned = Juice, Sco... | ADR-0002 ✅ Covered |
| TR-run-state-restart-019 | Construction of RunState emits nothing; first possible emission is Boot->Menu on external map_ready, which arrives only after composition root finished construction | ADR-0002 ✅ Covered |
| TR-run-state-restart-020 | Boot->Menu only on map_ready, which the map loader sends only after a successful Tube Track load_map; failure keeps Boot with no events; Hit->Menu and Boot->Menu emit phase_changed only | ADR-0004 ✅ Covered |
| TR-run-state-restart-021 | RunConfig (config resource, validated at startup): NaN/inf -> default, then clamp to safe range with one error each; RESTART_LOCK clamped to [LOCK_MIN, LOCK_MAX] (LOCK_MIN wins on conflict) and raised to hitstop_actual + T_READ... | GDD-owned |
| TR-run-state-restart-022 | Restart budget: touch to first presented frame after run_started <= 1.0 s; sum t_in 0.050 + t_disp 0.001 + t_track 0.002 + t_reset 0.013 + N_present(3) x frame + t_var 0.100 = 0.216 s at 60 fps; engineering gate p95 <= 0.4 s | ADR-0002 ⚠️ Partial |
| TR-run-state-restart-023 | Hit contact reports must be level-triggered by the collision owner (keep reporting an overlap every tick until accepted or overlap ends); hit_reported carries run_id captured at last run_reset | GDD-owned |
| TR-run-state-restart-024 | Tick driver contract: owner calls tick() in _process (not _physics_process) with process_mode ALWAYS and early process_priority, steps Ball Movement by returned dt_eff, calls Tube Track advance(s) only when phase reads Running | ADR-0002 ✅ Covered |
| TR-run-state-restart-025 | GUT unit tests with injected clock starting well above 0, state factory core_in(phase), signal recorder; flash-bound bot test: at most 2 run_ended per closed 1.0 s window at default lock (3 at 0.45) | ADR-0009 ✅ Covered |

**Partial or gap requirements:** stories for these carry the open point named in `docs/architecture/architecture-traceability.md` (Partial Coverage) and are marked Blocked until it is closed.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/run-state-restart.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [RunStateCore skeleton, public API, signals and purity](story-001-core-skeleton-api.md) | Logic | Ready (AC-9 lint rule pending) | ADR-0002, ADR-0009 |
| 002 | [Phase machine, request queue and validation by phase](story-002-phase-machine-validation.md) | Logic | Complete | ADR-0002, ADR-0004 |
| 003 | [Event emission order, two-step start and re-entrancy guard](story-003-events-two-step-start.md) | Logic | Complete | ADR-0002, ADR-0006 |
| 004 | [tick(), run clock F1 and settling tick](story-004-tick-run-clock.md) | Logic | Complete | ADR-0002 |
| 005 | [Hit acceptance, stale run_id and same-tick tie-break](story-005-hit-handling.md) | Logic | Complete | ADR-0002 |
| 006 | [Restart lock, press_us handling and restart_unlocked](story-006-hit-lock-press-us.md) | Logic | Complete | ADR-0005, ADR-0002 |
| 007 | [Pause, resume countdown, Paused guard and abandon](story-007-pause-resume-abandon.md) | Logic | Complete | ADR-0006, ADR-0002 |
| 008 | [Timers, stall guard and clock robustness](story-008-timers-stall-guard.md) | Logic | Complete | ADR-0002 |
| 009 | [Same-tick request conflicts and order independence](story-009-same-tick-ordering.md) | Logic | Ready | ADR-0002 |
| 010 | [RunConfig validation and lock bounds](story-010-config-validation-lock-bounds.md) | Config/Data | Ready | ADR-0002, ADR-0009 |
| 011 | [Flash bound bot and contract doubles](story-011-flash-bound-contract-doubles.md) | Logic | Ready | ADR-0009, ADR-0002 |
| 012 | [Subscriber order and tick driver contract in GameRoot](story-012-wiring-subscriber-order-driver.md) | Integration | Ready | ADR-0002, ADR-0004 |
| 013 | [Restart budget measurement on device (AC-27)](story-013-restart-budget-device.md) | Integration | Blocked | ADR-0002, ADR-0005 |
| 014 | [Hit-restart flash rate on device (AC-26)](story-014-flash-rate-visual.md) | Visual/Feel | Ready | ADR-0010, ADR-0009 |

## Next Step

Run `/story-readiness production/epics/run-state-restart/story-001-core-skeleton-api.md`, then `/dev-story`.
