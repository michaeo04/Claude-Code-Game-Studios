# ADR-0006: Android platform integration

## Status

Accepted (2026-10-03)

## Date

2026-10-02

## Last Verified

2026-10-02

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

Platform Services, Save & Persistence, Run State, Menus and three earlier ADRs hand every Android-specific question to this ADR: the lifecycle model and its threading, Back handling, haptics, display facts, keep-screen-on, and the whole **Android export manifest**. This ADR keeps one GDScript `PlatformServices` node as the only owner of OS calls, fixes the lifecycle and Back policy, sets the device floor (Android 9+, Vulkan 1.1) and defines the export preset (Gradle build, AAB, arm64, 16 KB pages, VIBRATE only), and restricts distribution to phones because Android 16 ignores portrait locks on large screens. The Godot specialist approved it with notes and no blocker.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (platform and export) |
| **Knowledge Risk** | HIGH: Android lifecycle under Vulkan, Back on Android 16 / SDK 36, the export preset keys and the threading of OS callbacks are not covered by the engine reference |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.5 Android 16 KB page support; 4.7 OBB support removed), `current-best-practices.md` (Android edge-to-edge, camera feed, 16 KB pages), `deprecated-apis.md` |
| **Post-Cutoff APIs Used** | 16 KB page support (4.5), edge-to-edge display (4.5), OBB removed (4.7); `DisplayServer` safe-area and refresh-rate queries are used as documented before 4.4 but unverified on 4.7.2 |
| **Verification Required** | **NEEDS VERIFICATION, none of it in the reference:** (1) the order and presence of `NOTIFICATION_APPLICATION_FOCUS_OUT/IN` and `PAUSED/RESUMED` under Vulkan on Home, lock, call, notification shade, app switcher (spikes PS-1, PS-2, device); (2) the thread on which Android lifecycle callbacks arrive (PS-12); (3) whether `NOTIFICATION_WM_GO_BACK_REQUEST` is delivered on Android 13+ with predictive back and on Android 16 targeting SDK 36 (PS-4); (4) the semantics of `application/config/quit_on_go_back`; (5) `Input.vibrate_handheld(duration_ms, amplitude)` amplitude behavior and the VIBRATE permission; (6) `DisplayServer.get_display_safe_area()` under edge-to-edge, whether insets arrive asynchronously, and `screen_get_refresh_rate()`; (7) `DisplayServer.screen_set_keep_on(true)` and battery saver; (8) the export preset key names (Gradle build, AAB, min and target SDK, architectures, immersive mode, orientation, permissions) until the first preset exists; (9) that the 4.7.2 Android export templates are 16 KB page aligned; (10) the `uses-feature` keys and values for Vulkan 1.1 (`android:version=0x401000`) and the accelerometer, and that Godot's own template already declares a Vulkan 1.0 entry that must be **replaced**, not duplicated; (11) `NOTIFICATION_OS_MEMORY_WARNING`; (12) predictive back opt-in versus opt-out (`android:enableOnBackInvokedCallback`) with target SDK 36, and that the same Back press never arrives twice (`WM_GO_BACK_REQUEST` and `ui_cancel` or `KEY_BACK`); (13) the Android 16 large-screen override of `screenOrientation`; (14) that Godot 4.7 supports the decided `minSdk 28` (Decision 8; the earlier assumption of 24 is dropped); (15) the notifications that fire for Home, lock, app switcher, call banner, notification shade, split-screen, pop-up windows (Home, lock and switcher expected to give `FOCUS_OUT` then `PAUSED`; shade and banner `FOCUS_OUT` only) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Android only), ADR-0002 (`FOCUS_OUT` is the primary pause signal; no view `_process`), ADR-0003 (Vulkan and the mobile renderer), ADR-0005 (`required_input_settings` manifest) |
| **Enables** | ADR-0007 (the `app_backgrounded` flush), ADR-0011 (safe area for the UI), the release pipeline |
| **Blocks** | Platform Services epic; the first playable (PS-1, PS-2 and PS-4 are blocking) |
| **Ordering Note** | The first Android export preset and the spikes PS-1, PS-2, PS-4, PS-12 should run before any Platform Services story is Done |

## Context

### Problem Statement

Platform Services owns every OS call, but its GDD left the thread model (PS-12), the Back behavior on Android 16 (PS-4), the project and export settings, and the device floor unresolved, and ADR-0003 and ADR-0005 forwarded their Android items here (Vulkan requirement, `quit_on_go_back`, immersive mode). Run State needs a reliable pause signal; Save & Persistence needs a flush that runs before the OS suspends the process; the HUD and Menus need the safe area.

### Constraints

- Android only; Vulkan renderer (mobile) with no OpenGL fallback (ADR-0003); portrait locked.
- No network, no ads, no accounts in the MVP: the manifest must stay minimal (only VIBRATE).
- `export_presets.cfg` is gitignored today; Platform Services AC-13 lints it, so the line is removed in the same commit as the first preset. Signing keystores and passwords never enter the repository.
- Google Play requires an AAB, 64-bit code, a current target SDK and 16 KB page alignment for Android 15+.

### Requirements

- One owner of OS calls, testable through injected seams.
- A pause signal that fires even if the process stops being scheduled right after focus loss.
- A defined behavior when Back is not delivered.
- A manifest that the CI can check.

## Decision

1. **One `PlatformServices` node owns every OS call** (Platform Services CR1), written in GDScript with a `PlatformCore` (RefCounted, injected `clock`, `display_source`, `vibrate`, `keep_on`, `read_setting`). No Android plugin and no GDExtension in the MVP.
2. **Lifecycle model.** `focus_implies_suspend` is true on Android. `NOTIFICATION_APPLICATION_FOCUS_OUT` emits `app_interrupted` then `app_backgrounded`; `FOCUS_IN` emits `app_foregrounded` then `app_returned`; `PAUSED/RESUMED` are ignored (not needed; their reliability under Vulkan is unverified). `FOCUS_OUT` is the **primary** pause signal (ADR-0002); Run State's stall guard is the backup.
3. **Thread rule.** Each notification handler checks `OS.get_thread_caller_id() == OS.get_main_thread_id()`. On the main thread it calls the core synchronously (so the `app_backgrounded` flush runs before the OS can suspend the process); on any other thread it marshals with `call_deferred`. A handler never runs inside a Run State tick or handler. The check is defensive: callbacks are expected on the main thread, and spike PS-12 records which case occurs. The `app_backgrounded` flush stays small and synchronous (a few KB, no thread, explicit flush and close); Android gives roughly a few seconds before a cached process may be killed, and process death with no callback is always possible, so Save & Persistence must tolerate it (ADR-0007).
4. **Back.** `application/config/quit_on_go_back = false` in the project and `get_tree().quit_on_go_back = false` set at boot. `NOTIFICATION_WM_GO_BACK_REQUEST` emits `back_pressed` and decides nothing. If spike PS-4 shows that `BACK` is not delivered on Android 13+ with predictive back, or on Android 16 targeting SDK 36, then Back must send the app to the background (pause, no run lost) and the missing `back_pressed` is a **release blocker**. No Android plugin is written to work around it. Back is handled **only** through `NOTIFICATION_WM_GO_BACK_REQUEST`: no `ui_cancel` or `KEY_BACK` mapping is added, so one press cannot arrive twice. Spike PS-4 runs with target SDK 36 and predictive back both on and off; the `android:enableOnBackInvokedCallback` value is part of the manifest check.
5. **Haptics.** `haptic(kind)` goes through the Platform Services gate (enabled, attentive, not zero, throttled, priority) and calls `Input.vibrate_handheld(duration_ms, amplitude)`. The manifest declares `android.permission.VIBRATE` (a normal permission, no prompt). Devices without amplitude control play a fixed pulse.
6. **Display facts.** `DisplayServer.get_display_safe_area()`, `screen_get_size()`, `screen_get_refresh_rate()` and `screen_get_dpi()` (carried as `DisplayFacts.screen_dpi: int`, ADR-0011) are read at construction, on each regaining edge (`app_foregrounded` and `app_returned`) and when the window size changes, because insets can arrive asynchronously under edge-to-edge. An empty safe area becomes the full screen rectangle in pixels. System gesture insets are not exposed; the UI keeps the 40 dp and 16 dp starting margins (HUD Open Question 11).
7. **Keep screen on.** `DisplayServer.screen_set_keep_on(true)` once at boot, never turned off. **Frame cap:** `application/run/max_fps = 60`.
8. **Android export preset** (`export_presets.cfg`, committed in the same commit that removes it from `.gitignore`; keystore, alias and passwords live outside the repository):
   - Gradle build **on** (custom build template; required for AAB and manifest control); AAB for Google Play, APK for sideload tests.
   - Architecture `arm64-v8a` only.
   - Minimum SDK **28** (Android 9) and target SDK both set **explicitly** in the preset (the string keys are empty by default). Target SDK = the level Google Play requires at release (36 expected, to be confirmed).
   - 16 KB page alignment confirmed for the 4.7.2 templates and the packaged libraries.
   - `uses-feature android.hardware.vulkan.version` with `android:version="0x401000"` (Vulkan 1.1) and `required = true`, **replacing** Godot's default Vulkan entry (never two entries), so Play filters devices; `uses-feature android.hardware.sensor.accelerometer` `required = true` (the closest Play filter; a device with an accelerometer but no gravity sensor installs and then shows "device not supported", ADR-0005).
   - Permissions: `VIBRATE` only; no `INTERNET`, no storage permissions.
   - Orientation portrait (preset and `display/window/handheld/orientation = 1`); immersive mode on; picture-in-picture off; no OBB (removed in 4.7).
   - **Large screens (user decision 2026-10-02):** Android 16 with target SDK 36 ignores the portrait lock on screens of 600 dp or more (tablets, foldables). Distribution is restricted to **phones** through the Play Console device catalog. If a foldable still runs the game, the UI keeps the portrait layout centred (letterbox) instead of stretching; no landscape layout is designed.
   - Signing: the release keystore never enters the repository; CI decodes it from a secret to a temporary path and passes it through the Godot Android keystore environment variables; Play App Signing with an upload key.
9. **Manifest check.** Platform Services' `PlatformSettings` manifest covers both `project.godot` keys (orientation, `quit_on_go_back`, `max_fps`, `enable_gravity`, the touch-emulation keys of ADR-0005) and the preset keys above. CI lints them and, for release builds, reads the **merged** `AndroidManifest.xml` (for example with `aapt2 dump`), not only the preset (debug exports may add `INTERNET` for remote debugging, so only release builds are linted for permissions). Until the first preset exists the preset part is skipped with a warning.
10. **Out of scope here:** the OS audio policy owner (Platform Services Open Question 20) and `NOTIFICATION_OS_MEMORY_WARNING` handling (against the 512 MB ceiling) stay open.

### Architecture Diagram

```
Android OS --FOCUS_OUT/IN (main thread? PS-12)--> PlatformServices node
   thread check: main -> core.on_* (sync, flush before suspend) | other -> call_deferred
   WM_GO_BACK_REQUEST --> back_pressed        (quit_on_go_back = false)
PlatformCore --signals--> RunState adapter (app_interrupted), SaveService (app_backgrounded), Tilt (app_foregrounded)
PlatformCore --haptic(kind)--> gate --> Input.vibrate_handheld
DisplayServer --safe_area/size/refresh (construction, regain edges, size change)--> HUD, Menus, Camera
Export: Gradle + AAB, arm64, minSdk 28, Vulkan 1.1 feature, VIBRATE only, 16 KB pages
```

### Key Interfaces

```gdscript
# PlatformServices (Node, constructed by GameRoot; see architecture.md API Boundaries)
signal app_interrupted
signal app_backgrounded
signal app_foregrounded
signal app_returned
signal back_pressed
func haptic(kind: int) -> void
func set_haptics_enabled(on: bool) -> void
func set_haptics_intensity(v: float) -> void
func quit() -> void

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_FOCUS_OUT: _marshal(_core.on_focus_out)
        NOTIFICATION_APPLICATION_FOCUS_IN:  _marshal(_core.on_focus_in)
        NOTIFICATION_WM_GO_BACK_REQUEST:    _marshal(_core.on_back_requested)

func _marshal(fn: Callable) -> void:
    if OS.get_thread_caller_id() == OS.get_main_thread_id():
        fn.call()
    else:
        fn.call_deferred()
```

### Implementation Guidelines

- The `PlatformServices` node is created first (ADR-0002 construction order) so later systems can connect to its signals; signals are not replayed, so a consumer reads `attentive` and `suspended` on connect.
- Handlers never send requests from inside a Run State tick or handler (Run State rule 3).
- Do not read `PAUSED/RESUMED` on Android; keep their handlers as no-ops that log at debug level.
- Release builds must not contain a debug keystore; signing is configured outside the repository.

## Alternatives Considered

### Alternative 1: A custom Android plugin (Kotlin) for Back and gesture insets

- **Description**: add an `OnBackInvokedCallback`, system gesture insets and richer vibration effects in an Android plugin.
- **Pros**: reliable Back on SDK 36; real insets for Pause placement.
- **Cons**: a second toolchain, Kotlin code to test and maintain, outside the GDScript scope.
- **Rejection Reason**: not needed until spike PS-4 shows Godot cannot deliver Back; kept as the escalation path.

### Alternative 2: Use `PAUSED/RESUMED` as the primary lifecycle signals

- **Description**: pause on `NOTIFICATION_APPLICATION_PAUSED`.
- **Pros**: closer to the Android activity lifecycle.
- **Cons**: the notification may not fire under Vulkan (unverified), so a pause could be missed.
- **Rejection Reason**: Platform Services chose `FOCUS_OUT/IN` (focus implies suspend).

### Alternative 3: Always `call_deferred` lifecycle handlers

- **Description**: every notification is marshalled to idle time.
- **Pros**: simple.
- **Cons**: a deferred flush may not run before the OS suspends the process.
- **Rejection Reason**: synchronous on the main thread, deferred only off-thread.

### Alternative 4: Default export with no manifest management

- **Description**: use Godot's default Android export and edit nothing.
- **Pros**: least work.
- **Cons**: no Vulkan filter on Play, extra permissions, no AAB, no CI check.
- **Rejection Reason**: the device floor and the minimal manifest are requirements.

## Consequences

### Positive

- One owner of OS calls, a pause signal that survives an immediate suspend, and a manifest that CI can check.
- A small permission set (VIBRATE only) and Play-side device filtering by Vulkan and accelerometer features.

### Negative

- Android 9+ with Vulkan 1.1 excludes older and low-end devices (coverage traded for fewer driver risks).
- Back on SDK 36 may need work if Godot does not deliver it (release blocker).
- A Gradle build adds Android SDK and JDK toolchain requirements for every developer machine and CI.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| `FOCUS_OUT` does not fire for shade, split-screen or heads-up (UNVERIFIED) | Medium | Medium | stall guard backup; PS-1; record in the matrix |
| `PAUSED/RESUMED` are unreliable under Vulkan (surface recreated around them) | Medium | Low | they are not used |
| Android 16 ignores the portrait lock on large screens | Medium | Medium | phones-only distribution through the Play Console device catalog; portrait layout letterboxed on a foldable |
| A 60 fps cap on a 90 or 120 Hz panel gives pacing judder | Low | Medium | pacing test on a 120 Hz device (PS-9) |
| The `app_backgrounded` flush time is unbounded and the process can die without a callback | Low | High | small synchronous file, explicit flush and close, atomic write (ADR-0007) |
| Predictive back is on and `BACK` arrives twice or not at all | Medium | High | single hook `WM_GO_BACK_REQUEST`; PS-4 checks "exactly one" with predictive back on and off |
| Lifecycle callbacks on another thread | Medium | High | thread rule (decision 3); PS-12 |
| Back not delivered on SDK 36 or with predictive back | Medium | High | PS-4; release blocker; escalation to Alternative 1 |
| Safe-area insets arrive late or change (rotation of cutout, gesture bar) | Medium | Medium | re-read on regain edges and size change; empty fallback |
| 4.7.2 templates or libraries are not 16 KB aligned | Low | High | verify with the alignment checker before the first Play upload |
| Play target SDK or filter rules change | Medium | Medium | confirm at release; keep SDK values in the preset only |
| Preset key names differ from assumed | Medium | Low | the manifest lint skips with a warning until the first preset exists |
| Debug keystore or secrets committed | Low | High | keystore outside the repo; CI check; `git-workflow.md` rule |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | n/a | lifecycle and display reads are event-driven; negligible per frame | 16.6 ms frame |
| Memory | n/a | small (no plugin, no network stack) | 512 MB |
| Load Time | n/a | construction of Platform Services is first and synchronous | n/a |
| Battery | n/a | `screen_set_keep_on` keeps the display awake during play | n/a |

## Migration Plan

Greenfield. Create `PlatformServices` and `PlatformCore`, create the first Android export preset, remove `export_presets.cfg` from `.gitignore` in that commit, run the spikes PS-1, PS-2, PS-4, PS-12 and the 16 KB check, then wire the manifest lint.

**Rollback plan**: supersede with an ADR that adds the Android plugin (Alternative 1) or changes the device floor; the `PlatformCore` seams do not change.

## Validation Criteria

- [ ] PS-1 and PS-2: lifecycle sequences logged on at least two Android makers; `app_interrupted` precedes `app_backgrounded` and no pause is missed.
- [ ] PS-4: Back delivers exactly one `back_pressed` per press on Android 13+ and on Android 16 with the target SDK in use; otherwise the fallback behavior and the release-blocker flag apply.
- [ ] PS-12: the thread of each callback is recorded; the thread rule passes both cases in a test.
- [ ] The `app_backgrounded` flush completes before the process is suspended (Save SP-1 kill test).
- [ ] The exported AAB passes the 16 KB alignment check (`zipalign -c -P 16` and an ELF alignment check on the `.so` files), the merged manifest declares only `VIBRATE`, one Vulkan 1.1 entry and the accelerometer feature, and Play shows the Vulkan and accelerometer device filters and no tablets.
- [ ] The manifest lint passes in CI for `project.godot` and, once it exists, `export_presets.cfg`.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/platform-services.md` | Platform Services | lifecycle model with focus implies suspend (CR3, F1); threads (CR4, PS-12); Back (CR5, PS-4); haptics (CR6); display facts (CR7); manifest (CR8); keep-screen-on (CR12) | decisions 2 to 9 |
| `design/gdd/run-state-restart.md` | Run State | `app_interrupted` applied when sent; Back pauses in Running and Resuming (R11) | `FOCUS_OUT` primary; Back policy |
| `design/gdd/save-persistence.md` | Save & Persistence | flush on `app_backgrounded` only (CR5) | synchronous main-thread handler (decision 3) |
| `design/gdd/menus-screen-flow.md` | Menus | `back_pressed` routing and `quit()` ownership (Rules 5 and 6) | `back_pressed`, `quit_on_go_back = false`, `quit()` |
| `design/gdd/tilt-input.md` | Tilt Input | lifecycle signals for buffer clear and settle (R9) | `app_backgrounded` and `app_foregrounded` |
| `design/gdd/hud.md`, `design/ux/hud.md` | HUD | safe area and gesture edges (Platform UI Requirement 3) | display facts, re-read points |
| `design/gdd/juice-feedback.md` | Juice | `haptic(kind)` | decision 5 |

## Related

- ADR-0001, ADR-0002, ADR-0003, ADR-0005; future ADR-0007, ADR-0011
- `docs/architecture/architecture.md` (Open Question 3)
- `.claude/docs/git-workflow.md` (`export_presets.cfg` decision)
