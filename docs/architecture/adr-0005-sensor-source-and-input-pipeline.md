# ADR-0005: Sensor source and input pipeline

## Status

Proposed

## Date

2026-10-02

## Last Verified

2026-10-02

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

Tilt Input says the sensor source (gravity or accelerometer) is for a spike ADR to decide, and several GDDs scatter the ProjectSettings flags, the portrait lock, the `press_us` stamp and the touch-emulation rule. This ADR fixes one sensor source (**`Input.get_gravity()` only**, a device without it is "device not supported"), the required ProjectSettings, and one touch pipeline (the Hit tap catcher reacts to `InputEventScreenTouch` pressed in `Control._gui_input`; standard `Button`s stamp `press_us` in `button_down`; both read the injected `clock_us`; `emulate_mouse_from_touch` stays on). The Godot specialist found one blocker in the first draft (emulation off would leave stock Buttons dead on a phone); it is resolved here.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Input |
| **Knowledge Risk** | HIGH: 4.7 renumbered keyboard/mouse device IDs; 4.6 split touch focus from keyboard focus; the sensor API and the ProjectSettings below are **not covered** by the engine reference (`modules/input.md` stops at 4.6 and has no sensor content) |
| **References Consulted** | `docs/engine-reference/godot/modules/input.md`, `breaking-changes.md` (4.7 device IDs, 4.6 dual focus), `deprecated-apis.md`, `current-best-practices.md` |
| **Post-Cutoff APIs Used** | None known to be post-cutoff; `Input.get_gravity()` and the sensor flags exist from 4.x but are unverified on 4.7.2 |
| **Verification Required** | **NEEDS VERIFICATION, not in the reference:** (1) `Input.get_gravity()` on Android 4.7.2 returns the gravity vector in m/s^2 and the zero vector when the device has no gravity sensor; (2) ProjectSettings names and defaults: `input_devices/sensors/enable_gravity` (default false; in an export the flag is baked in, the restart caveat is editor-only), the sibling sensor flags default false, `display/window/handheld/orientation` (portrait = 1), `input_devices/pointing/emulate_mouse_from_touch` (default true) and `emulate_touch_from_mouse` (default false, project-wide); (3) the sensor source and rate: `get_gravity()` is believed to come from the Android gravity sensor at about 50 Hz, so some 60 fps frames read a stale sample (spikes V-1, P-1, P-2); (4) **stock Buttons fire on a real phone with emulation on**, one tap gives exactly one catcher action, and the order of the emulated mouse press and the `ScreenTouch` for one touch (Run State R8 records it as verified on 4.7.2: the `InputEventMouseButton` first, then the `InputEventScreenTouch`; re-check on a phone); (5) `InputEventScreenTouch.canceled` handling (cancel gives no activation); (6) that touch events reach `Control._gui_input` and respect `mouse_filter`, and that a second finger arrives with `index >= 1`; (7) the stamp lags the touch by at most about one frame plus the OS-to-engine queue delay (capture against 60 fps video); (8) touch focus on Buttons under the 4.6 dual-focus change (ADR-0011); (9) the boot manifest check can tell "sensor flag missing" from "no sensor" (both read as the zero vector); (10) `application/config/quit_on_go_back` and predictive back (ADR-0006) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Android only), ADR-0002 (`GameRoot` polls once per frame, injected `clock_us`) |
| **Enables** | ADR-0006 (manifest and export settings), ADR-0011 (UI input and focus), spike V-1 |
| **Blocks** | Tilt Input, HUD and Menus epics; the first playable (V-1 sensor sign is blocking) |
| **Ordering Note** | Spike V-1 (sensor sign, units) runs on a real device before any tilt tuning value is locked |

## Context

### Problem Statement

Tilt Input is the only control (Pillar 4) and has never run on a phone. Its GDD leaves the sensor source to "the spike ADR", the project settings that enable the sensor default to off and need a restart, and the touch path (tap anywhere in Hit, release-inside buttons, timestamped Restart and Menu) depends on a timestamp that `InputEventScreenTouch` does not carry. Without one decision, each system would read input its own way and in its own time domain.

### Constraints

- One input axis; one-handed; no multi-touch or gestures (Pillar 4, anti-pillar).
- Run State rejects a restart or menu press stamped before `hit_us + RESTART_LOCK` or `paused_us + PAUSE_INPUT_GUARD`; the stamp must be in the same microsecond clock domain as Run State (ADR-0002 `clock_us`).
- `TiltInput` has no `_process` (ADR-0002); `GameRoot` calls `poll()` once per rendered frame in every phase, before Ball Movement steps.
- Only the `TiltInput` node may read motion sensors (Tilt Input rule 1, CI lint).
- Android only; portrait locked; no gamepad.

### Requirements

- A single sensor source with a defined "no sensor" outcome.
- ProjectSettings that must be set, owned by Platform Services' manifest check.
- One touch pipeline with a documented timestamp accuracy.

## Decision

1. **Sensor source: `Input.get_gravity()` only.** `TiltInput.poll()` reads it once per rendered frame (called by `GameRoot`) and passes the raw `Vector3` (m/s^2, float32; believed to be refreshed at about 50 Hz, so some frames reuse the previous sample) to `TiltCore`. `Input.get_accelerometer()`, the gyroscope and the magnetometer are **not** read, and `input_devices/sensors/enable_accelerometer` stays off. If no valid sample (zero vector or non-finite) arrives within `SENSOR_START_TIMEOUT` (2.0 s) after boot, `TiltCore` goes Unavailable (`valid` false): Menus gates Play and shows `No motion sensor` ("device not supported"). The boot manifest check (Platform Services) confirms `enable_gravity` is true first, so a missing flag is reported as a settings error, not as a missing sensor (both read as the zero vector). The accelerometer fallback and the plugin route are rejected for the MVP; they return only through a new ADR if spike V-1 shows many target devices lack a gravity sensor.
2. **Required ProjectSettings** (checked at boot and linted in CI by Platform Services' manifest, ADR-0006 owns the export side): `input_devices/sensors/enable_gravity = true`; `display/window/handheld/orientation = 1` (portrait); `input_devices/pointing/emulate_mouse_from_touch = true` (the default, **required**: stock `Button` handles mouse and key events, not `InputEventScreenTouch`, so with emulation off the Pause, Menu, Restart, Resume and Play buttons would not fire on a phone); `input_devices/pointing/emulate_touch_from_mouse = true` (project-wide, harmless on Android, lets the editor mouse exercise the tap catcher); the other sensor flags (`enable_accelerometer`, `enable_gyroscope`, `enable_magnetometer`) stay false and the lint asserts it. `application/config/quit_on_go_back` and immersive mode belong to ADR-0006.
3. **Touch pipeline.** Two consumers, never both for one tap. (a) The **Hit tap catcher** is a `Control` whose `_gui_input(event)` reads `var press_us: int = clock_us.call()` on its **first line** and reacts only to `InputEventScreenTouch` with `pressed == true` on **any touch index** (a second finger while the first is down is not filtered: it is a legal restart tap, and Run State's lock and idempotence absorb duplicates; a second finger cancels nothing); it ignores `InputEventMouseButton` (the emulated duplicate). (b) The **buttons** (Pause, Menu, Restart, Resume, Play, Settings, Retry, Back, QUIT, Cancel) are stock `Button`s: the handler of `button_down` reads `clock_us` on its first line to stamp `press_us`, and activation happens on `pressed` (release inside, the built-in behavior); a cancelled touch gives no activation. `mouse_filter` decides which Control receives the touch, so the Pause and Menu buttons win over the Hit tap catcher (HUD rule). Game buttons set `focus_mode = FOCUS_NONE` (there is no gamepad or keyboard on device, and touch must not draw keyboard focus after 4.6), and Pause and Menu stay out of the screen-edge band (HUD gesture-edge rule). Gameplay never reads touch through `Input.is_action_*`.
4. **Timestamp accuracy.** `press_us` is the time the handler ran, which can lag the physical touch by up to about one frame; Run State's `T_READ` margin already absorbs that lag (F3/F4). No hardware event timestamp is assumed; the lag is up to one frame plus the OS-to-engine queue delay, to be measured against a 60 fps capture.
5. **No device IDs, no gamepad.** Code never hard-codes input device IDs (4.7 renumbering) and reads no gamepad. Desktop keyboard or mouse input exists only in the editor.
6. **Editor-only steering path.** Only when `OS.has_feature("editor")` is true (never in an exported APK, **including a debug APK sent to testers**, so `OS.is_debug_build()` is not used), `GameRoot` replaces the `TiltInput` `sample_source` with a synthetic one that turns the left and right arrow keys into a gravity vector of a fixed roll angle. `TiltCore`, `valid` and `input_source` (still `SENSOR`) are unchanged, so Menus' sensor-ready gate (`valid` and `input_source == SENSOR`) lets Play through in the editor without any bypass. The unwired `fallback_source` is not used. CI lint checks that the synthetic source is referenced only behind that feature check.
7. **Lint.** CI fails if any file other than `tilt_input.gd` calls `Input.get_gravity`, `get_accelerometer`, `get_gyroscope` or `get_magnetometer`; if the tap catcher reads `InputEventMouseButton`; if gameplay reads `Input.is_action_*`; if the editor-only source is reachable without the `has_feature("editor")` check; or if the manifest shows any sensor flag other than `enable_gravity` set to true.

### Architecture Diagram

```
Android sensor --(Godot, enable_gravity)--> Input.get_gravity()
GameRoot._tick: TiltInput.poll()  -> TiltCore (neutral, dead zone, filter) -> steer, valid, input_source
Touch: InputEventScreenTouch(pressed, any index) -> HUD tap catcher _gui_input: press_us = clock_us.call()
        -> restart_requested(press_us)                              [forwards on press]
       emulated mouse press -> stock Button: button_down stamps press_us, `pressed` activates (release inside)
emulate_mouse_from_touch = true; no gamepad; no device IDs; editor-only synthetic gravity from arrow keys
```

### Key Interfaces

```gdscript
class_name TiltInput extends Node            # no _process (ADR-0002)
func poll() -> void                          # GameRoot, once per rendered frame, every phase
var steer: float; var valid: bool; var input_source: int   # read-only getters

# Hit tap catcher (Control)
func _gui_input(event: InputEvent) -> void:
    var press_us: int = _clock_us.call()                   # first line
    if event is InputEventScreenTouch and event.pressed:   # any index; ignore InputEventMouseButton
        _on_press(press_us)

# every stock Button
func _on_button_down() -> void:
    _press_us = _clock_us.call()                           # first line; activation is the `pressed` signal
```

### Implementation Guidelines

- `poll()` guards non-finite and oversized vectors (Tilt F1: `G_MIN` 3 m/s^2).
- Do not smooth or filter in the node; `TiltCore` owns the pipeline.
- A press that starts outside a button and slides in does not activate it (release-inside rule); a cancelled touch gives no activation.
- Hidden HUD subtrees do not use `mouse_behavior_recursive` (4.5) in the MVP: ADR-0011 Decision 5 uses `visible = false` plus full-screen STOP blockers.
- `TiltInput` and the touch Controls receive `clock_us` by injection; they never call `Time.` themselves.

## Alternatives Considered

### Alternative 1: `get_gravity()` with an automatic `get_accelerometer()` fallback

- **Description**: gravity first; accelerometer if gravity is missing.
- **Pros**: covers devices without a gravity sensor.
- **Cons**: accelerometer includes linear acceleration (shake), needs separate filtering and a second tested path.
- **Rejection Reason**: not justified until V-1 shows the need.

### Alternative 2: `get_accelerometer()` only

- **Description**: the raw accelerometer on every device.
- **Pros**: works everywhere.
- **Cons**: noisier, more latency from filtering, no benefit when gravity exists.
- **Rejection Reason**: worse feel on the common case.

### Alternative 3: Native plugin for `TYPE_GAME_ROTATION_VECTOR`

- **Description**: an Android plugin or GDExtension exposes fused orientation.
- **Pros**: best fusion and rate control.
- **Cons**: native code, a second toolchain, outside the GDScript scope.
- **Rejection Reason**: too heavy for the MVP; keep as a future ADR if feel requires it.

### Alternative 4: Global `_input` with `Time.get_ticks_usec()`

- **Description**: stamp at the earliest hook.
- **Pros**: earliest event.
- **Cons**: breaks `mouse_filter` precedence (one handler must pick between overlapping controls) and the injected-clock rule.
- **Rejection Reason**: `_gui_input` keeps the HUD layering semantics.

### Alternative 5: Turn emulation off and write a custom `TouchButton` Control

- **Description**: handle `InputEventScreenTouch` press and release in a custom Control (hit test, release-inside, press feedback).
- **Pros**: matches the Run State wording "ScreenTouch only".
- **Cons**: more code, loses the stock Button behavior, and is only testable on a device; the editor hides the problem.
- **Rejection Reason**: stock Buttons with emulation on are simpler; Run State R8 only needs a clarifying sentence.

## Consequences

### Positive

- One sensor path and one touch path, both testable by injected seams.
- The `press_us` domain matches Run State; `mouse_filter` layering stays natural.

### Negative

- Devices without a gravity sensor are not supported.
- `press_us` carries up to about one frame of lag.
- The editor-only synthetic sensor is extra code that must never be reachable in an export.
- Run State R8 gets a one-sentence clarification and the Phase 4 note in `architecture.md` changes: stock Buttons stamp from the emulated mouse press of the same touch, the catcher from `ScreenTouch`.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| `get_gravity()` returns zero or is unavailable on some target devices | Medium | High | boot probe with `SENSOR_START_TIMEOUT`; spike V-1 on at least two makers; revisit with Alternative 1 |
| Sensor sign or units differ from the expected -1 and m/s^2 | Medium | High | V-1 (blocking for the first playable) |
| Once-per-frame polling shows jitter or latency at 60 Hz | Medium | Medium | spikes P-1 and P-2 (p95 poll cost 0.1 ms, end-to-end 100 ms) |
| Buttons do not fire on a device (emulation behavior differs on 4.7.2) | Low | High | verification (4) on a real phone before the first story is Done; the editor hides this because the mouse also clicks |
| One tap acts twice (catcher and a Button) | Low | Medium | `mouse_filter` precedence; the catcher ignores `InputEventMouseButton`; test that one tap gives one action |
| A holding finger produces a stray second press | Medium | Low | no index filter by design; Run State lock and idempotence absorb it |
| The editor-only synthetic sensor ships in an APK | Low | High | `OS.has_feature("editor")` gate plus lint |
| Android Back or the back gesture quits the app | Medium | High | ADR-0006 (`quit_on_go_back`, predictive back) |
| Sensor sampled at about 50 Hz reads stale on some 60 fps frames | Medium | Low | counted in the P-1 and P-2 latency budget |
| A project setting is reset or missing in an export | Low | High | Platform Services manifest check at boot and in CI |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | n/a | `poll()` p95 at most 0.1 ms | 16.6 ms frame |
| Memory | n/a | ring buffer of 256 samples (about 4 KB) | 512 MB |
| Load Time | n/a | none | n/a |

## Migration Plan

Greenfield. Add the settings to `project.godot` and to Platform Services' manifest, implement `TiltInput` and the touch Controls, then run V-1 on a device.

**Rollback plan**: supersede with Alternative 1 (accelerometer fallback) or 3 (native plugin); `TiltCore`'s `sample_source` seam does not change.

## Validation Criteria

- [ ] V-1 on at least two Android makers: sensor sign (`SENSOR_SIGN` expected -1), units m/s^2, no zero vector.
- [ ] A device without a gravity sensor reaches Unavailable within `SENSOR_START_TIMEOUT` and Menus shows `No motion sensor`.
- [ ] One tap gives exactly one catcher action (no mouse duplicate), stock Buttons work on a real phone with emulation on, and `press_us` lags the touch by at most about one frame plus the queue delay (60 fps capture).
- [ ] A second finger produces its own stamped press and cancels nothing; a cancelled touch activates no Button.
- [ ] CI lint of decision 7 passes; the manifest check confirms the four settings in an export.
- [ ] `poll()` p95 at most 0.1 ms over 1000 frames (P-1).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/tilt-input.md` | Tilt Input | only the node reads sensors (R1); portrait lock and gravity is screen-relative (R3); units and `SENSOR_SIGN` (R4); ProjectSettings sensor flags (R9); sensor-source ADR and spike V-1 | one source `get_gravity()`, settings fixed, V-1 gate, lint |
| `design/gdd/run-state-restart.md` | Run State | `press_us` stamped in the input handler, with no buffering and one stamp per tap (R8, D2) | the tap catcher stamps from `ScreenTouch` pressed, Buttons stamp in `button_down` (one stamp per tap); injected `clock_us`. R8 already says "a control that fires on release still forwards the press-down time" and that the tap owner handles `ScreenTouch` only; a one-sentence clarification is added that stock Buttons stamp in `button_down` (one stamp per tap) |
| `design/gdd/hud.md` | HUD | full-screen tap catcher in Hit; Pause and Menu win over it via `mouse_filter`; release-inside buttons (R14) | catcher `_gui_input`; stock Buttons `button_down` and `pressed`; `mouse_filter` precedence |
| `design/gdd/menus-screen-flow.md` | Menus | Restart and Menu stamp `press_us` on press-down; no gestures | same pipeline |
| `design/gdd/platform-services.md` | Platform Services | manifest: portrait, `enable_gravity` (CR8, AC-11, AC-13) | the four settings listed for the manifest |
| `design/gdd/settings-accessibility.md` | Settings | `tilt_sensitivity` feeds Tilt Input | unchanged; read through the getter |

## Related

- ADR-0001, ADR-0002, ADR-0003; ADR-0006 and ADR-0011 (both written, Proposed)
- `docs/architecture/architecture.md` (API Boundaries, Open Question 7)
