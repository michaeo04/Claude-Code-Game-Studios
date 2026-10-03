# Epic: Platform Services

> **Layer**: Foundation
> **GDD**: design/gdd/platform-services.md
> **Architecture Module**: Platform Services
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: Not yet created. Run `/create-stories platform-services`

## Overview

Platform Services owns every OS call: the lifecycle model (`FOCUS_OUT` as the primary pause signal, thread rule), Back handling on SDK 36, haptics gate, display facts (safe area, size, refresh rate, dpi), keep-screen-on, the frame cap and the Android export manifest (ADR-0006). It exposes five signals and getters; nothing else touches `OS`, `DisplayServer` or `Input.vibrate_handheld`.

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0006: Android platform integration | This ADR keeps one GDScript `PlatformServices` node as the only owner of OS calls, fixes the lifecycle and Back policy, sets the device floor (Android 9+, Vulkan 1.1) and defines the export preset (Gradle build, AAB,... | Accepted | HIGH |
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |

**Engine risk of the epic: HIGH** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

20 requirements registered for this system: 17 covered by an ADR, 1 partial, 0 gap, 2 GDD-owned (specified fully by the GDD, no ADR needed).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-platform-services-001 | Only the PlatformServices node handles lifecycle notifications, WM_GO_BACK_REQUEST, Input.vibrate_handheld, DisplayServer display calls and ProjectSettings reads; enforced by a CI lint allowlist | ADR-0006 ✅ Covered |
| TR-platform-services-002 | Shape: PlatformCore (RefCounted, no engine calls), PlatformMath (static: haptic_gate, effective, interval_us, fps_eff, frame_time, fis_for_platform), RateLimitedLog (RefCounted), PlatformServices node, HapticsConfig (Resource),... | ADR-0006 ✅ Covered |
| TR-platform-services-003 | Lifecycle model: flags focused (true at start) and paused (false); FIS=focus_implies_suspend true on Android; under FIS, PAUSED/RESUMED are ignored; attentive = focused and not paused; suspended = paused or (FIS and not focused) | ADR-0006 ✅ Covered |
| TR-platform-services-004 | Signals emitted on edges only, synchronously in the handler, order app_interrupted, app_backgrounded, app_foregrounded, app_returned; repeated events log one LIFECYCLE_NOOP debug and emit nothing; nothing emitted at construction | ADR-0006 ✅ Covered |
| TR-platform-services-005 | Lifecycle callbacks may originate on another thread on Android; handlers must run on main thread outside a tick, otherwise node defers with call_deferred | ADR-0006 ✅ Covered |
| TR-platform-services-006 | Android Back: NOTIFICATION_WM_GO_BACK_REQUEST -> back_pressed, one per notification, decides nothing; application/config/quit_on_go_back = false (manifest lint plus node sets get_tree().quit_on_go_back = false at boot); quit()... | ADR-0006 ⚠️ Partial |
| TR-platform-services-007 | haptic(kind) with NEAR_MISS, HIT, UI_TAP; drop causes in fixed order UNKNOWN_KIND, DISABLED, NOT_ATTENTIVE, ZERO_DURATION, THROTTLED, each with a counter haptic_drops(cause); otherwise calls Input.vibrate_handheld(duration_ms,... | ADR-0006 ✅ Covered |
| TR-platform-services-008 | Haptic gate: plays if enabled, attentive, dur_eff>0 and (gate_open or prio > last_prio); gate_open = none played, or clock anomaly, or (elapsed >= MIN_INTERVAL_us and now >= last_end_us); HIT outranks NEAR_MISS and UI_TAP; drop... | ADR-0006 ✅ Covered |
| TR-platform-services-009 | effective(): dur_eff = clamp(duration_ms,0,HAPTIC_MAX_MS); amp_eff = -1 if amplitude<0 else clamp(amp,0,1) x haptics_intensity; Android level clamp(int(amp x 255),1,255) | ADR-0006 ✅ Covered |
| TR-platform-services-010 | HapticsConfig validated at load in order HAPTIC_MAX_MS first then per-kind; clamp to safe range with one KNOB_CLAMPED error per value; NaN/inf take default; shipped defaults must equal TK table; MIN_INTERVAL converted once with... | ADR-0006 ✅ Covered |
| TR-platform-services-011 | Lifecycle hook for saving: app_backgrounded is the only flush signal; PS does no saving and never waits | ADR-0006 ✅ Covered |
| TR-platform-services-012 | Display facts read through injected display_source Callable (Dictionary keys safe_area, screen_size, viewport_size, refresh_rate) at construction and once per regaining edge before signals; empty safe area replaced by Rect2i(Ve... | ADR-0006 ✅ Covered |
| TR-platform-services-013 | Keep screen on: DisplayServer.screen_set_keep_on(true) called once at boot, never turned off | ADR-0006 ✅ Covered |
| TR-platform-services-014 | Project settings manifest (data: section, key, expected, owner tag) linted in CI and checked at boot via read_setting: orientation=1, quit_on_go_back=false, max_fps=60, input_devices/sensors/enable_gravity=true (enable_accelero... | ADR-0006 ✅ Covered |
| TR-platform-services-015 | Frame cap application/run/max_fps = 60 for MVP; fps_eff = min(max_fps, refresh) with fallbacks (refresh unknown -> max_fps, max_fps<=0 -> refresh, neither -> 0); 60 cap on 120 Hz UNVERIFIED | ADR-0006 ✅ Covered |
| TR-platform-services-016 | RateLimitedLog passes one message per (code, key) per 1.0 s on injected real-time clock (window from last passed message); codes UNKNOWN_HAPTIC_KIND, KNOB_CLAMPED, SETTINGS_MISMATCH (error) and LIFECYCLE_NOOP (debug); backwards... | GDD-owned |
| TR-platform-services-017 | PlatformCore takes injected focus_implies_suspend, clock (int microseconds, real-time monotonic), log_sink(level,code,key,message), vibrate(duration_ms,amplitude), display_source, validated HapticsConfig; use method Callables n... | GDD-owned |
| TR-platform-services-018 | Device spike PS-1..PS-12 (PS-3, PS-7 removed): PS-1 lifecycle sequences, PS-2 Vulkan PAUSED/RESUMED, PS-4 Back on Android 16 are BLOCKING for first playable; others advisory (PS-10 blocks Save epic); 10/10 trials per scenario | ADR-0009 ✅ Covered |
| TR-platform-services-019 | Integration harness uses Run State's real SceneTree-free core plus a test-only adapter (INT -> pause_requested(app_interrupted), BACK -> pause_requested(back)); 340 sequences of 1-4 events give zero RS Error logs | ADR-0009 ✅ Covered |
| TR-platform-services-020 | Node tested via node.notification(X) against a spy core: each of the 5 notifications calls exactly its on_* method once; fis_for_platform("Android") true, others false | ADR-0009 ✅ Covered |

**Partial or gap requirements:** stories for these carry the open point named in `docs/architecture/architecture-traceability.md` (Partial Coverage) and are marked Blocked until it is closed.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/platform-services.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Next Step

Run `/create-stories platform-services` to break this epic into implementable stories.
