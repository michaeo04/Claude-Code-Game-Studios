# Platform Services

> **Status**: Designed (all sections written 2026-09-21; pending an independent `/design-review` in a fresh session and the device spike PS-1..PS-12)
> **Author**: user + agents
> **Last Updated**: 2026-09-21
> **Implements Pillar**: Pillar 4 (One-Thumb Simplicity); supports Pillar 2 (Fair but Merciless Difficulty) by keeping app interruptions out of deaths

## Overview

Platform Services is the Core-layer system that owns what the game needs from the phone's operating system, so that no other system touches the OS directly. It turns raw OS events into a few game-level signals: the app going to the background or coming back, a phone call or other interruption, and the Android Back button (provisional signals `app_interrupted`, `app_returned`, `app_backgrounded`, `app_foregrounded` and `back_pressed`, consumed by Tilt Input and Run State). It also owns the platform settings the other systems assume rather than check: the locked portrait orientation, the Android sensor project settings that Tilt Input needs, and the display facts Camera and HUD read (viewport size, safe area, refresh rate). A haptic call for Juice & Feedback and the lifecycle hook Save & Persistence uses before the OS can terminate the app are also expected here (both provisional, to be settled in Detailed Design). It is fully automatic: the player never interacts with it and it has no UI. It exists because a phone game is interrupted constantly, and a call, a swipe home or a locked screen must never cost the player a run (Pillar 2), and a phone that rotates or drops its sensors must never make the one control unreliable (Pillar 4). It decides nothing about what the game does in response: Run State decides to pause, Tilt Input decides how a lost sensor is handled, Juice & Feedback decides which haptic patterns play, and Save & Persistence decides what is written. Which devices are supported and what thermal or load budget applies are not decided here (Technical Setup, Open Questions).

## Player Fantasy

**The fantasy.** None of its own. The player never sees this system, and its best result is that they never think of it. What they feel is what it makes possible: the phone is a reliable controller, and the game survives real life.

**What the player feels (indirectly).**
- **An interruption never costs me a run.** A call, a pulled-down notification shade, a swipe home or a locked screen leaves the run exactly where it was. This is Run State's "the run only ends when I lose"; Platform Services is how the game learns that the interruption happened.
- **The phone never fights me.** The screen stays in portrait however the phone is held or turned (*Pillar 4: "the game is playable one-handed in any normal holding posture: seated, standing, reclined, or commuting"*), the motion sensors are on before the first tap, and nothing interrupts a run with a prompt (that no permission prompt appears is UNVERIFIED until a device test, Open Question).
- **A near-miss can be felt in the hand.** A short haptic pulse joins the white-juice channel of the art bible ("ring motion, whoosh, haptic"; *Pillar 3: "every close dodge must feel immediately rewarding"*). It is an extra channel, never the only cue: what happened must be readable without it (*Pillar 1*), and Juice & Feedback owns the patterns.
- **Back and home behave as I expect.** Android Back and a swipe home pause the run; they never quit the game in the middle of a run (Run State rule 11).

**Feelings to avoid.** A run lost to a phone call; the layout turning or jumping under the thumb; a permission prompt in the middle of play; a vibration that is long, strong, or fires when nothing happened; the game quitting on a stray Back press.

**Where the promise holds.** Only where the OS tells the app what is happening. If the OS terminates the app while it is in the background, the run is lost (Run State Open Question 6: nothing is saved mid-run in the MVP). A phone with no usable motion sensor is Tilt Input's touch fallback, not this system's job.

**Serves the pillars.** *Pillar 2, "every death traces back to the player's own choice or reaction, never to randomness or bad luck"*: an interruption is never a death. Pillar 4 as quoted above. Pillar 3 through the haptic channel.

## Detailed Design

### Core Rules

1. **One owner of OS-facing calls.** Only Platform Services handles the application lifecycle notifications (`NOTIFICATION_APPLICATION_FOCUS_IN/OUT`, `_PAUSED/_RESUMED`) and `NOTIFICATION_WM_GO_BACK_REQUEST`, calls `Input.vibrate_handheld`, and reads the `DisplayServer` display facts. No other system does; a CI lint enforces it (AC-12). Motion sensors are the exception and belong to Tilt Input (its rule 1).
2. **Shape.** `PlatformCore` (`RefCounted`, no Node, no engine calls) holds the logic; a thin `PlatformServices` node in the main scene forwards notifications to it and calls the OS; `HapticsConfig` (a `Resource`) holds the haptic values; `PlatformSettings` is the manifest of required project settings (rule 8). No autoload: the composition root creates the node and passes it to the systems that need it (coding standards: dependency injection over singletons).
3. **Lifecycle model.** The core keeps two flags, `focused` (starts true) and `paused` (starts false), and takes a construction parameter `focus_implies_suspend` (true on Android, false on iOS). Derived: `attentive = focused and not paused`; `suspended = paused or (focus_implies_suspend and not focused)`. Why: on Android `onPause` is the only source of `FOCUS_OUT` (source-verified, 4.7.2) and is also when the OS unregisters the sensors and pauses rendering, while `APPLICATION_PAUSED/_RESUMED` are called only from the GL renderer and may never fire under Vulkan (Vulkan path UNVERIFIED). On iOS `FOCUS_OUT` also fires for Control Center, banners and call interruptions with nothing suspended, and `PAUSED` fires only on a true background (source-verified). So the model must not depend on the order or the presence of the four notifications.
4. **Signals, on edges only.** After every event the core re-evaluates and emits: `app_interrupted` when `attentive` turns false; `app_backgrounded` when `suspended` turns true; `app_foregrounded` when `suspended` turns false; `app_returned` when `attentive` turns true. On losing, `app_interrupted` comes before `app_backgrounded`; on regaining, `app_foregrounded` comes before `app_returned`. A repeated or reordered notification changes nothing and emits nothing. Nothing is emitted at construction. Signals are emitted synchronously inside the notification handler, which the engine delivers between frames (UNVERIFIED on Android, whose lifecycle calls originate on another thread), so a receiver should not run inside another system's tick (Run State rule 3 rejects a request sent from inside one).
5. **Back.** `NOTIFICATION_WM_GO_BACK_REQUEST` becomes the signal `back_pressed`, one per notification (source-verified: it reaches every node through the scene tree). Platform Services decides nothing about what Back means: Run State's adapter turns it into `pause_requested(back)` in Running and Resuming (Run State rule 11), Menus & Screen Flow decides every other phase (Run State Open Question 16). `application/config/quit_on_go_back` must be false, otherwise the engine quits before the game sees it. Platform Services exposes `quit()` for Menus and never quits on its own. iOS has no Back.
6. **Haptics.** `haptic(kind)` with kinds `NEAR_MISS`, `HIT` and `UI_TAP` (provisional; Juice & Feedback may add kinds through the config). `HapticsConfig` holds, per kind, `duration_ms` and `amplitude`, plus a global minimum interval. A call is dropped when haptics are disabled (a setter fed by Settings & Accessibility), when the app is not `attentive`, when the kind's duration is 0 or less, or when it comes within the minimum interval of the last pulse played (measured on the injected clock; the caller owns priority). Otherwise it calls `Input.vibrate_handheld(duration_ms, amplitude)`. Source-verified facts: Android needs the export permission `VIBRATE` enabled or the call silently does nothing, an amplitude of -1 is the default level and otherwise it maps to 1-255; iOS uses a CoreHaptics pulse that honors duration and amplitude, except on old or unsupported hardware where it plays a fixed system vibration and ignores both. Haptics are an extra channel and never the only cue (Player Fantasy).
7. **Display facts.** The core reads, through an injected `display_source` (the node implements it with `DisplayServer.get_display_safe_area()`, a `Rect2i` in screen pixels, `screen_get_refresh_rate()`, `screen_get_size()` and the viewport size), at construction and once per event that has a regaining edge (`app_foregrounded` or `app_returned`, before those signals are emitted), and exposes them as read-only values (they can change: iOS forces the refresh rate to 60 in Low Power Mode, which can be toggled from Control Center without suspending the app). Camera and HUD read them at layout time; Platform Services does not interpret them. An empty safe area (`not has_area()`) is replaced by the full screen rectangle `Rect2i(Vector2i.ZERO, screen size)` in pixels; the viewport size stays in stretch units and is a separate value. Cutouts on iOS are UNVERIFIED.
8. **Project settings manifest.** `PlatformSettings` lists every setting the game requires, and a CI lint checks it against `project.godot` and the export presets: `display/window/handheld/orientation` = 1 (portrait; value verified), `application/config/quit_on_go_back` = false, `application/run/max_fps` = 60, `input_devices/sensors/enable_gravity` = true (and `enable_accelerometer` if the sensor-source ADR keeps that fallback), and the Android export permission `VIBRATE` enabled. The lint extends Tilt Input AC-37d, which checks the same orientation and sensor keys, so the two checks share one implementation (or one delegates to the other).
9. **Frame cap.** `application/run/max_fps` is 60 for the MVP (technical preferences: 60 FPS; Tilt Input's noise filter is a 60 Hz claim). iOS already defaults to a preferred 60 fps (source-verified); whether a 60 cap holds on a 120 Hz Android device is UNVERIFIED (device check).
10. **Lifecycle hook for saving.** `app_backgrounded` is the only "flush now" signal Save & Persistence uses. Platform Services does no saving and does not wait for it.
11. **Testing seam.** `PlatformCore` takes `focus_implies_suspend`, a `clock: Callable() -> int` (microseconds), a `log_sink`, a `vibrate: Callable(duration_ms, amplitude)`, a `display_source: Callable() -> Dictionary` (safe area, screen size, viewport size, refresh rate) and a validated `HapticsConfig`; its events in are `on_focus_out()`, `on_focus_in()`, `on_paused()`, `on_resumed()` and `on_back_requested()`, plus `haptic(kind)` and `set_haptics_enabled(enabled)`; read-only getters `attentive`, `suspended`, `safe_area`, `screen_size`, `viewport_size` and `refresh_rate`. The haptic gate is a pure function of (enabled, attentive, duration, now, last_played, min_interval). Tests build a fresh core each.

### States and Transitions

The lifecycle state is derived from the two flags (`FIS` = `focus_implies_suspend`):

| `focused` | `paused` | State | `attentive` | `suspended` (Android FIS true / iOS FIS false) |
|-----------|----------|-------|-------------|------|
| true | false | Active | true | false / false |
| false | false | Unfocused (iOS: Control Center, banner, call) | false | true / **false** |
| true | true | Resuming (iOS: between `FOCUS_IN` and `RESUMED`) | false | true / true |
| false | true | Backgrounded | false | true / true |

Every event that changes neither `attentive` nor `suspended` emits nothing. Example, iOS Home then return: `FOCUS_OUT` gives `app_interrupted`; `PAUSED` gives `app_backgrounded`; `FOCUS_IN` gives nothing (still paused); `RESUMED` gives `app_foregrounded` then `app_returned`. Example, Android Home: `FOCUS_OUT` gives `app_interrupted` then `app_backgrounded`; `FOCUS_IN` gives `app_foregrounded` then `app_returned`.

### Interactions with Other Systems

All interfaces are **provisional** (only Run State and Tilt Input have GDDs).

| System | Direction | Data / events | Note |
|--------|-----------|---------------|------|
| Run State & Restart | out | `app_interrupted` (pause, applied when sent), `app_returned` (re-anchors the Paused guard, its Open Question 17), `back_pressed` through an adapter as `pause_requested(back)` | Run State does not know Platform Services |
| Tilt Input | out | `app_backgrounded` and `app_foregrounded` (buffer clear, settle) | Replaces its reliance on `APPLICATION_PAUSED/_RESUMED`; Tilt rule 9 and Open Question 24 need this correction |
| Save & Persistence | out | `app_backgrounded` (flush) | |
| Juice & Feedback | in | `haptic(kind)` | |
| Camera, HUD | out | safe area, refresh rate, viewport size | |
| Menus & Screen Flow | out / in | `back_pressed`; calls `quit()` | |
| Settings & Accessibility | in (soft) | `haptics_enabled` | |

## Formulas

Durations are converted once at load with `roundi(x * 1e6)` and compared as integer microseconds (same rule as Tilt Input rule 8). Every default is a guess until a device test.

**F1. Lifecycle derivation and edge signals**

`attentive = focused and not paused`
`suspended = paused or (focus_implies_suspend and not focused)`

After each event, with `(a0, s0)` the values before and `(a1, s1)` after: emit `app_interrupted` iff `a0 and not a1`; `app_backgrounded` iff `not s0 and s1`; `app_foregrounded` iff `s0 and not s1`; `app_returned` iff `not a0 and a1`. Emission order: interrupted, backgrounded, foregrounded, returned (a single event never has both a losing and a regaining edge).

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Focus flag | `focused` | bool | {false, true} | true at construction; set by `FOCUS_IN`, cleared by `FOCUS_OUT` |
| Pause flag | `paused` | bool | {false, true} | false at construction; set by `PAUSED`, cleared by `RESUMED` |
| Focus implies suspend | `FIS` | bool | {false, true} | fixed per platform: Android true, iOS false |
| Attentive | `attentive` | bool | | the app is in front and receiving input |
| Suspended | `suspended` | bool | | the OS has stopped sensors and rendering |

**Output range:** 0, 1 or 2 signals per event (a losing pair or a regaining pair, never a mix); exactly 0 for a duplicate or reordered event.
**Example (iOS, FIS false):** `FOCUS_OUT` gives `app_interrupted` (attentive false, suspended false); `PAUSED` gives `app_backgrounded`; `FOCUS_IN` gives nothing (`paused` still true); `RESUMED` gives `app_foregrounded` then `app_returned`.
**Example (Android, FIS true):** `FOCUS_OUT` gives `app_interrupted` then `app_backgrounded`; a later `PAUSED` gives nothing; `FOCUS_IN` gives `app_foregrounded` then `app_returned` if `PAUSED` never arrived, and gives nothing until `RESUMED` if it did.
**Extremes:** `RESUMED` without a prior `PAUSED` and `FOCUS_IN` without a prior `FOCUS_OUT` are no-ops; `PAUSED` twice is a no-op.

**F2. Haptic gate**

`play = enabled and attentive and dur_eff > 0 and (last_played_us is none or now_us - last_played_us >= MIN_INTERVAL_us)`

When `play`, `last_played_us = now_us` and `Input.vibrate_handheld(dur_eff, amp_eff)` is called; a dropped call does not change `last_played_us`.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Haptics enabled | `enabled` | bool | | Settings switch, default true |
| Now | `now_us` | int (us) | >= 0 | injected monotonic clock |
| Last pulse | `last_played_us` | int (us) or none | | stamp of the last pulse played |
| Minimum interval | `MIN_INTERVAL_us` | int (us) | 0 to `HAPTIC_MIN_INTERVAL` max | `roundi(HAPTIC_MIN_INTERVAL * 1e6)` |
| Effective duration | `dur_eff` | int (ms) | 0 to `HAPTIC_MAX_MS` | F3 |

**Output range:** call or no call. The comparison is inclusive: exactly `MIN_INTERVAL_us` after the last pulse plays.
**Example** (`MIN_INTERVAL` 0.05 s for the example only): a pulse at 0 plays; a call at 49999 us is dropped; a call at 50000 us plays.
**Extremes:** if `now_us < last_played_us` (a clock anomaly; the clock is monotonic so this is defensive) the call plays and `last_played_us` is set to `now_us`. A `MIN_INTERVAL` of 0 never drops on time.

**F3. Effective duration and amplitude**

`dur_eff = clamp(duration_ms, 0, HAPTIC_MAX_MS)`; `amp_eff = -1` if `amplitude < 0`, `1.0` if `amplitude > 1`, else `amplitude`. A NaN or infinite value takes the kind's default (one `KNOB_CLAMPED` error per value, as in Tilt Input's log codes). The engine maps `amp_eff` to the OS: Android level `clamp(int(amp_eff * 255), 1, 255)` (source-verified), `-1` is the OS default level; iOS passes an intensity clamped to 0-1 and on old hardware ignores it. `effective()` is a defensive pure function that accepts any input; a loaded config is validated by the narrower ranges of Tuning Knobs, so an amplitude of -1 and a duration of 0 or less arise only from direct calls (and from `UI_TAP` 0), and the Android level mapping is engine behavior, not tested here.

**Output range:** `dur_eff` in `[0, HAPTIC_MAX_MS]`, `amp_eff` in `{-1}` and `[0, 1]`.
**Example** (`HAPTIC_MAX_MS` 200 for the example only): `duration_ms` 500 gives 200; `duration_ms` -5 gives 0 (dropped by F2); `amplitude` 0.5 gives Android level 127.

**F4. Effective frame rate (informational)**

`fps_eff = min(max_fps, refresh_rate)` when both are positive, `max_fps` when the refresh rate is unknown (0, negative or NaN), `refresh_rate` when `max_fps` is 0 or less (the engine's "unlimited"), and 0 (unknown, no frame time) when neither is known; frame time is `1 / fps_eff` when `fps_eff > 0`. With `max_fps` 60: a 60 Hz screen gives 16.667 ms, a 120 Hz screen gives 16.667 ms if the cap holds (UNVERIFIED on Android), a 30 Hz screen gives 33.333 ms. Consumers (Tilt Input's noise rejection, Run State's `DT_MAX` clamp) work from the injected clock, not from this value; it only tells a tester what to expect.

## Edge Cases

**Lifecycle**
- **If `FOCUS_OUT` arrives twice (iOS `willResignActive` then `didEnterBackground`)**: the second changes nothing and emits nothing, so one `app_interrupted`.
- **If `PAUSED` arrives while already unfocused (iOS true background: `FOCUS_OUT` then `PAUSED`)**: only `app_backgrounded` is emitted; `app_interrupted` was already sent.
- **If `RESUMED` arrives without a prior `PAUSED`, `FOCUS_IN` without a prior `FOCUS_OUT`, or `PAUSED` twice**: a no-op with one `LIFECYCLE_NOOP` debug log; nothing is emitted (F1).
- **If iOS returns in the order `FOCUS_IN` then `RESUMED`**: `FOCUS_IN` emits nothing (still paused); `RESUMED` emits `app_foregrounded` then `app_returned` together. Consumers must not assume the two arrive in separate frames.
- **If a banner or Control Center on iOS takes focus for a moment**: `app_interrupted` then, when it closes, `app_returned`; no `app_backgrounded` (`FIS` false). Run State pauses on the first and stays Paused; `app_returned` only re-anchors its Paused guard.
- **If the Android notification shade is pulled down**: expected to emit nothing (UNVERIFIED: no `onWindowFocusChanged` handling was found in the source), so the run continues under the shade with tilt still live. If a device does emit `FOCUS_OUT`, it is treated as an interruption. Device check.
- **If Android under Vulkan never sends `PAUSED/RESUMED`**: nothing changes; with `FIS` true the model uses `FOCUS_OUT/IN` alone (F1).
- **If `FOCUS_IN` arrives but `RESUMED` never does (an OS violation; iOS pairs them)**: the app stays not `attentive` and `suspended`; Tilt Input never leaves Acquiring, and its timeout and Menu path are the recovery (Tilt Input rule 10 and edge cases). Not handled here.
- **If a lifecycle event arrives before the composition root has connected the receivers (boot)**: the core still tracks the flags; a signal with no listener is lost and never replayed. Every receiver reads `attentive` and `suspended` when it connects.
- **If the OS terminates the app while it is suspended**: no code runs and no signal is sent (Run State Open Question 6).
- **If Android puts the app in Picture-in-Picture (the export manifest template sets `supportsPictureInPicture` true)**: treated as an interruption if `FOCUS_OUT` fires; the run pauses in a small window. UNVERIFIED (Open Question).

**Back**
- **If Back arrives twice in a frame**: two `back_pressed` signals; consumers are idempotent (Run State treats the second in Paused as a silent no-op).
- **If `application/config/quit_on_go_back` is left true**: the engine quits before the game sees Back; the settings lint fails the build (Acceptance Criteria) and the boot check logs `SETTINGS_MISMATCH`.
- **If Back arrives in Menu, Hit, Paused or Boot and Menus & Screen Flow has not connected**: nothing happens (with `quit_on_go_back` false the engine ignores it), so the app cannot be left by Back. Menus must handle it (Run State Open Question 16).
- **If the Android 13+ predictive back gesture behaves differently from the classic button**: UNVERIFIED (no manifest opt-in was found in the export template); device check.

**Haptics**
- **If `haptic(kind)` is called while the app is not `attentive`**: dropped, never queued, no log.
- **If `kind` is not in `HapticsConfig`**: dropped with one `UNKNOWN_HAPTIC_KIND` error (rate limited: one message per code and detail key per 1.0 s of the injected clock).
- **If two haptic calls arrive within `HAPTIC_MIN_INTERVAL`**: the second is dropped (F2); the caller owns priority, so Juice & Feedback must not rely on a later call preempting a running pulse.
- **If haptics are disabled while a pulse is running**: the pulse finishes; nothing cancels it.
- **If the Android export permission `VIBRATE` is unchecked**: the OS call silently does nothing and nothing detects it at runtime; the settings lint on the export preset is the guard.
- **If the device has no vibration hardware, or an old iPhone plays the fixed system vibration**: accepted; the old-iOS pulse ignores duration and amplitude (device matrix, spike).
- **If a config value is NaN or infinite**: it takes the kind's default with one `KNOB_CLAMPED` error (F3).

**Display facts and settings**
- **If `get_display_safe_area()` returns an empty rectangle (no cutout information, desktop, or a platform without an override)**: the safe area is the full screen rectangle in pixels (rule 7).
- **If `screen_get_refresh_rate()` returns 0 or a negative value (unknown)**: `fps_eff` is `max_fps` (F4).
- **If the refresh rate changes without the app suspending (iOS Low Power Mode toggled from Control Center)**: the values are re-read on `app_returned` as well as on `app_foregrounded` (rule 7), before the signals are emitted.
- **If a required project setting differs at runtime (orientation not portrait, `max_fps` not 60, `quit_on_go_back` true, a sensor setting off)**: the node logs one `SETTINGS_MISMATCH` error per key at boot. It is a diagnostic; the lint is the gate. Tilt Input's own `NOT_PORTRAIT` remains as it is.
- **If two systems both handle a lifecycle notification (a lint miss)**: duplicate signals from the second owner; all receivers are idempotent on the four signals.
- **If a receiver of `app_backgrounded` (Save & Persistence) is slow**: Platform Services does not wait; how much time the OS grants before suspending is not measured (Open Question); Save & Persistence must keep its flush short.

## Dependencies

Platform Services has **no hard upstream dependencies** (Foundation layer; the systems index lists none). It has soft data inputs, which are contracts and not code dependencies, and several dependents.

**Inputs (soft)**

| Input | Supplied by | Used for | Note |
|-------|-------------|----------|------|
| Lifecycle notifications (`APPLICATION_FOCUS_IN/OUT`, `_PAUSED/_RESUMED`), `WM_GO_BACK_REQUEST` | The engine (Godot 4.7.2) from Android and iOS | F1, Back | Order and presence differ per platform (Core Rules 3) |
| `DisplayServer` safe area and refresh rate; viewport size | The engine | Rule 7, F4 | iOS cutouts UNVERIFIED |
| `Input.vibrate_handheld` | The engine | F2, F3 | Android needs the export permission `VIBRATE` |
| `haptics_enabled` | Settings & Accessibility | F2 | Optional, default true |
| The game clock in microseconds | The game loop (game-loop ADR, not yet written) | F2 throttle, log rate limit | Same clock as Run State and Tilt Input |
| `project.godot` and the export presets | The project files | Rule 8 lint, boot check | Owned by Platform Services as a manifest |

**Dependents**

| System | Type | What it needs from Platform Services |
|--------|------|--------------------------------------|
| Tilt Input | Hard (correctness) | `app_backgrounded` and `app_foregrounded` (buffer clear and settle; without them a stale sensor vector survives a background on Android); the portrait lock and the Android sensor settings from the manifest |
| Run State & Restart | Hard for release | `app_interrupted` (pause), `back_pressed` (as `pause_requested(back)`), `app_returned` (re-anchors its Paused guard, Open Question 17), through an adapter |
| Save & Persistence | Hard (index) | `app_backgrounded` as the flush signal |
| Juice & Feedback | Soft | `haptic(kind)` |
| Camera, HUD | Soft | safe area, refresh rate, viewport size |
| Menus & Screen Flow | Soft | `back_pressed`, `quit()` |
| Settings & Accessibility | Soft | receives `haptics_enabled` |

**Bidirectional consistency**
- Run State & Restart lists Platform Services (rule 11 and its interfaces table) but expects Platform Services itself to send `pause_requested(app_interrupted)` and `pause_requested(back)`. With this GDD Platform Services only emits signals and an adapter sends the requests, so Run State's wording needs a documentation edit (its table row and Open Questions 16 and 17). Consistent in behavior.
- Tilt Input rule 9 and Open Question 24 say Platform Services owns `NOTIFICATION_APPLICATION_PAUSED/_RESUMED` and exposes `app_backgrounded` / `app_foregrounded`. The signals match, but on Android those two notifications may never fire under Vulkan, so the source of the signals changes (F1). Tilt Input needs a wording edit.
- Systems index: row 20 (this system) status to Designed. Camera and HUD are not listed as dependents in the index (data inputs are not listed, as with Tilt Input and Tube Track).
- To do when those GDDs are written: Save & Persistence connects `app_backgrounded` and keeps its flush short; Juice & Feedback calls `haptic(kind)` and never makes haptics the only cue; Menus & Screen Flow handles `back_pressed` in every non-Running phase and owns the quit decision; Settings & Accessibility supplies `haptics_enabled`; Camera and HUD read the display facts; the sensor-source ADR fixes which Android sensor settings the manifest requires.

**Provisional assumptions:** the signal names, the adapter that converts them to Run State requests, the composition root that wires them, the `haptic(kind)` interface, and the game-loop clock.

## Tuning Knobs

All defaults are guesses until a device test; none comes from a keyboard or an emulator. Every knob lives in `HapticsConfig` (a `Resource`) or in the project settings manifest, never in code. Validation at load: each value is clamped to its safe range; a NaN or infinite value takes its default; one `KNOB_CLAMPED` error per value changed.

| Knob | Default | Safe range | Affects | Too low | Too high |
|------|---------|------------|---------|---------|----------|
| `HAPTIC_MIN_INTERVAL` | 0.08 s | 0-0.5 | Minimum time between two played pulses (F2) | A burst of events buzzes continuously | A distinct near-miss is dropped after a hit or a tap |
| `HAPTIC_MAX_MS` | 200 ms | 50-500 | Cap on any pulse duration (F3) | Long effects are cut | A config error produces a long vibration that drains the battery |
| `NEAR_MISS` duration / amplitude | 30 ms / 0.5 | 10-`HAPTIC_MAX_MS` / 0-1 | The near-miss pulse (Juice & Feedback owns the feel) | Not felt; some Android devices ignore very short effects | Reads as a hit, tiring on frequent near-misses |
| `HIT` duration / amplitude | 80 ms / 1.0 | 10-`HAPTIC_MAX_MS` / 0-1 | The death pulse | Weak sting | Unpleasant; must stay short so restart is not felt as delayed |
| `UI_TAP` duration / amplitude | 15 ms / 0.3 | 0-`HAPTIC_MAX_MS` / 0-1 | Menu taps (0 disables) | Not felt | Annoying on every tap |
| `haptics_enabled` | true | true / false | Master switch, supplied by Settings & Accessibility | | |
| `max_fps` (project setting) | 60 | 30-60 | The frame cap (Core Rules 9, F4) | Lower Tilt Input noise rejection (30 Hz passes twice the alternating noise of 60 Hz, Tilt Input F3) and more input lag | Heat and battery on 120 Hz devices |

**Fixed constants (not tuning knobs):** the log rate limit of 1.0 s per code and detail key (Tilt Input limits per code; here two different knobs or keys reported at the same stamp both pass), with the log codes `UNKNOWN_HAPTIC_KIND`, `KNOB_CLAMPED`, `SETTINGS_MISMATCH` and `LIFECYCLE_NOOP` (debug level); `focus_implies_suspend` per platform (Android true, iOS false); the required project settings of the manifest (orientation 1, `quit_on_go_back` false, sensor settings, `VIBRATE` permission): these are correctness requirements checked by the lint, not values to tune.

**Knob interactions**
- `HAPTIC_MIN_INTERVAL` decides which of two close events is heard: the first one wins, so Juice & Feedback should call the higher-priority kind first or space events itself (F2).
- `max_fps` interacts with Tilt Input (its filter is a 60 Hz claim; its lowest supported rate `F_MIN` is 20 Hz) and with Run State's `DT_MAX` (0.1 s): any value from 30 to 60 stays inside both, a value below 20 would not.
- A per-kind duration above `HAPTIC_MAX_MS` is clamped, so `HAPTIC_MAX_MS` bounds every kind.
- Old iPhones and devices without a haptic engine ignore amplitude and duration (fixed pulse), so per-kind tuning only matters on capable devices.

**Sources of truth elsewhere:** `haptics_enabled` (Settings & Accessibility), `DT_MAX` and `RESUME_COUNTDOWN` (Run State), `F_MIN` (Tilt Input), the feel and priority of haptic events (Juice & Feedback).

## Visual/Audio Requirements

**Visual:** none. Platform Services has no visuals; what the player sees of a lifecycle event (the pause screen) belongs to Run State and HUD. **Audio:** no audio of its own. The engine already stops or pauses audio when the app loses focus (source-verified: iOS stops rendering and audio on `FOCUS_OUT`, Android pauses audio on `onPause` unless in Picture-in-Picture), so this system adds no audio handling. **Haptics** are the one output channel it owns: three provisional kinds (`NEAR_MISS`, `HIT`, `UI_TAP`) with values in `HapticsConfig`; Juice & Feedback owns when they fire and how they feel. Haptics have no assets, so no `/asset-spec` is needed.

## UI Requirements

No player-facing UI of its own. Requests to other systems:

1. **Settings & Accessibility:** a haptics on/off switch that feeds `haptics_enabled` (default on).
2. **Menus & Screen Flow:** handle `back_pressed` in every phase except Running and Resuming (Menu, Paused, Hit, Boot) and own the quit decision, using `quit()` (Run State Open Question 16); the app cannot be left by Back otherwise.
3. **HUD and Camera:** keep interactive and important elements inside the safe area (notch, rounded corners, the gesture bar) and read it after each `app_foregrounded` / `app_returned`.

No UX Flag: there is no screen or HUD element of its own to specify.

## Acceptance Criteria

**Targets:** **[M]** `PlatformMath` static functions; **[C]** `PlatformCore` with injected `fis`, `clock` (us), `log_sink`, `vibrate` and `display_source`; **[I]** integration; **[L]** CI lint in `tools/ci/`. Tests live in `tests/unit/platform_services/` and `tests/integration/platform_services/`. **Fixture:** `HAPTIC_MIN_INTERVAL` 0.05 s, `HAPTIC_MAX_MS` 200, NEAR_MISS 30/0.5, HIT 80/1.0, UI_TAP 15/0.3, screen and viewport 1080x1920. Events FO, FI, P, R = FOCUS_OUT, FOCUS_IN, PAUSED, RESUMED; signals INT, BG, FG, RET = `app_interrupted`, `app_backgrounded`, `app_foregrounded`, `app_returned`; BACK = `back_pressed`. Integer microsecond stamps; exact for integers and lists, 1e-6 for floats; a fresh core per case.

**Lifecycle (F1, R3, R4)**
- **AC-1 [C]** signals emitted per event (`-` = none, `|` separates events). iOS (`fis` false): `FO,P,FI,R` gives INT | BG | - | FG,RET; `FO,P,R,FI` gives INT | BG | FG | RET; `FO,FI` gives INT | RET; `FO,FO,P,FI,R` gives INT | - | BG | - | FG,RET; `P,P` gives INT,BG | -. Android (`fis` true): `FO,FI` gives INT,BG | FG,RET; `FO,P,FI,R` and `P,FO,R,FI` give INT,BG | - | - | FG,RET; `FO,P,FI` gives INT,BG | - | - (`suspended` stays true). Both: `R` or `FI` on a fresh core emits nothing and logs one `LIFECYCLE_NOOP`; construction emits nothing (`attentive` true, `suspended` false); each signal is recorded before the `on_*` call returns.
- **AC-2 [C]** exhaustive, both `fis`: every sequence of 1-6 events (4+16+64+256+1024+4096 = 5460): at most 2 signals per event, never a losing and a regaining signal together, fixed order INT, BG, FG, RET; the running count of INT minus RET and of BG minus FG stays in {0, 1} and equals 1 iff not `attentive` (respectively iff `suspended`); with `fis` true, INT and BG (and FG and RET) always share an event.

**Haptics (F2, F3, R6)**
- **AC-3 [M]** `haptic_gate(enabled, attentive, dur, now, last, min_us)`, `min_us` 50000: last none and now 0 plays; last 0: now 49999 drops, 50000 and 50001 play; last 100000 and now 99999 plays (clock anomaly); `min_us` 0 with (100, 100) plays; `enabled` false, `attentive` false, `dur` 0 and `dur` -1 each drop. `interval_us(0.05, 0.08, 0.5, 0)` = 50000, 80000, 500000, 0.
- **AC-4 [C]** HIT at stamp 0 plays (`vibrate` receives 80, 1.0); NEAR_MISS at 30000 drops and at 50000 plays (a drop leaves `last_played_us` unchanged); after each other drop cause (disabled, not attentive, duration 0, unknown kind) an allowed call at the same stamp plays; disabled and not-attentive drops log nothing; an unknown kind logs one `UNKNOWN_HAPTIC_KIND` error and does not call `vibrate`.
- **AC-5 [M]** `effective(dur, amp, max)`: `dur` 500, 201, 200, 1, 0, -5 gives 200, 200, 200, 1, 0, 0; `amp` 0.5, 0, 1, 1.0000001, 2, -0.0001, -1 gives 0.5, 0, 1, 1, 1, -1, -1; `max` 50 with `dur` 80 gives 50. **[C]** a NaN or infinite config value takes the kind's default with one `KNOB_CLAMPED` error each.
- **AC-6 [C]** log codes are exactly `UNKNOWN_HAPTIC_KIND`, `KNOB_CLAMPED`, `SETTINGS_MISMATCH` (error level) and `LIFECYCLE_NOOP` (debug). The production sink passes one message per code and detail key per 1.0 s of the injected clock: a message at 0 passes; the same key at 999999 us does not; at 1000000 us it does; two different keys (or codes) at one stamp both pass; the level is preserved.
- **AC-7 [C]** (config validation) one row per knob, an out-of-range value gives one `KNOB_CLAMPED` and the boundary gives none: `HAPTIC_MIN_INTERVAL` -0.01 and 0.51 become 0 and 0.5; `HAPTIC_MAX_MS` 49 and 501 become 50 and 500; NEAR_MISS and HIT duration 9 and 201 become 10 and 200; UI_TAP duration -1 becomes 0 (0 is valid); an amplitude of 1.1 becomes 1; a NaN or infinite value takes its default. With `HAPTIC_MAX_MS` 50 and HIT 80: HIT becomes 50, one error, and `vibrate` receives 50.
- The Android amplitude-to-level mapping (F3) is engine behavior and is not an AC; PS-6 observes it.

**Other rules**
- **AC-8 [M]** F4 `fps_eff(max, hz)`: (60, 60) gives 60; (60, 120) gives 60; (60, 30) gives 30 (33.333 ms); (60, 0), (60, -1) and (60, NaN) give 60; (60, 59.94) gives 59.94 (16.683 ms); (0, 120) gives 120; (0, 0) gives 0 (no frame time, no division).
- **AC-9 [C]** (R5) each `on_back_requested()` emits exactly one BACK in all four lifecycle states, changes no getter and no later emission; two calls give two BACK.
- **AC-10 [C]** (R7) `display_source` is read once at construction with no signal. An event with no regaining edge reads nothing; one with a regaining edge reads once, before its first signal (recorded order `read, FG, RET`; an iOS `FI` after a banner gives `read, RET`), and a handler sees the new values (iOS Low Power 120 then 60: the RET handler sees 60). An empty safe area (`Rect2i()`) with screen 1080x1920 is exposed as `Rect2i(0, 0, 1080, 1920)`; `Rect2i(0, 132, 1080, 1788)` is exposed unchanged; a refresh rate of 0 or -1 is exposed raw and F4 gives `max_fps`.
- **AC-11 [C]** (R8) N mismatched runtime-readable keys at boot (orientation, `max_fps`, `quit_on_go_back`, a sensor setting) give N `SETTINGS_MISMATCH` errors, one per key.

**Lints [L]** (on `src/` only, comments and strings stripped, best-effort; each has a fixture self-test: a violation reports file and line, one inside a comment passes)
- **AC-12 [L]** (R1, R2) **12a** `NOTIFICATION_APPLICATION_(FOCUS_IN|FOCUS_OUT|PAUSED|RESUMED)`, `NOTIFICATION_WM_GO_BACK_REQUEST`, `Input\.vibrate_handheld` and `DisplayServer\.(get_display_safe_area|screen_get_refresh_rate|screen_get_size)` match only the `PlatformServices` node file (Tilt Input rule 9 is edited first so both agree). **12b** `PlatformCore` and `PlatformMath` extend `RefCounted`, not Node, and contain no `Input.`, `DisplayServer.`, `Engine.`, `Time.` or `OS.`.
- **AC-13 [L]** (R8) manifest lint, **owner: Platform Services** (`tools/ci/check_project_settings`, driven by the `PlatformSettings` entries: section, key, expected value, owner tag). A missing key fails (the defaults are orientation 0, `quit_on_go_back` true, `max_fps` 0, sensors off). By INI section: `[display]` `window/handheld/orientation` = 1; `[application]` `config/quit_on_go_back` = false and `run/max_fps` = 60; `[input_devices]` `sensors/enable_gravity` = true (`enable_accelerometer` if the sensor-source ADR keeps it); `export_presets.cfg`: each Android preset has `permissions/vibrate=true` (skipped until an export preset exists, BLOCKING from the first Android build). Self-test: 5 keys x {missing, wrong} = 10 failures, a right key in the wrong section fails, a valid file passes. **Tilt Input AC-37d delegates** to this script for the entries tagged `tilt` and keeps only its own `steer_left` / `steer_right` action check.

**Integration [I]** (harness: Run State's real SceneTree-free core (its AC-8), a real `PlatformCore` and a test-only adapter: INT becomes `pause_requested(app_interrupted)`, BACK becomes `pause_requested(back)`)
- **AC-14 [I]** (R4, R5) INT or BACK in Running or Resuming gives Paused with one `run_paused` whose source is `app_interrupted` or `back`, applied before the `on_*` call returns; in Menu, Boot, Hit and Paused: no phase change, zero log lines, and a second BACK listener still receives it; two BACK in Running give one pause; an iOS Home sequence leaves Paused with `run_id` unchanged and no `run_ended`.
- **AC-15 [I]** (Run State rule 3) events delivered between ticks: all 340 sequences of 1-4 events (4+16+64+256), both `fis`, from Running: zero Run State Error logs, and the run is Paused iff the sequence contains FO or P.
- **AC-16 [I], deferred** `app_returned` re-anchors the Paused guard: a restart 299999 us after RET is rejected and one at 300000 us accepted (Run State's guard, 0.3 s); RET in any other phase is silent. Owner: Run State (it must add the request, its Open Question 17), then the adapter story.
- **AC-17 [I], deferred** recorded PS-1..PS-3 traces replay to the expected signals (owner: the spike story); BG and FG reach Tilt Input (an Android Home without PAUSED clears its buffer) and Save & Persistence (one flush per BG); BACK reaches Menus (owners: those epics; the wiring is a composition-root story, unassigned, for the producer).

**Device checks** (spike items, provisional hypotheses; one file each `production/qa/evidence/platform-services/ps-N.md`: device, OS, date, raw log, result). Matrix: a notched ProMotion iPhone; an older iPhone without CoreHaptics (iPhone 7 or older, if the minimum iOS allows); an Android 13+ mid-tier target; a second Android vendor on Android 12 or lower; a 120 Hz Android. Sequence items: 10 trials per scenario per device, 10 of 10 required (weak: 0.74^10 = 0.049, so it only supports p >= 0.74 at 95%), every trial reported. Reliability claims: 59 trials, zero failures (0.95^59 = 0.0485), per device. Raw traces become AC-17 fixtures.
- **PS-1** Android Home, notification shade, screen lock, heads-up call, full-screen call, app switcher: hypothesis the shade and heads-up emit nothing, the others INT,BG then FG,RET.
- **PS-2** Android Vulkan: count PAUSED/RESUMED over 10 Home cycles (hypothesis 0); the replay must equal AC-1's Home row either way.
- **PS-3** iOS Control Center, banner, call, lock, Home: log the order; hypothesis Control Center gives `FO,FI` only, lock gives `FO,P` then `FI,R`.
- **PS-4** Back on 3-button and gesture navigation, predictive back on (Android 16 too if targeted): 10 presses give 10 BACK, 10 cancelled gestures give 0, the Menu is not closed.
- **PS-5** Picture-in-Picture: 10 Home presses during a run; hypothesis 0 enter PiP.
- **PS-6** `VIBRATE` checked versus unchecked, HIT x10 (vibrator dump, or 3 testers): 10/10 versus 0/10; also observe the amplitude levels 0.5, 0 and 1 (expected 127, 1, 255).
- **PS-7** iOS haptics, 10 pulses per kind: an old iPhone plays the fixed vibration (accepted); a capable iPhone: NEAR_MISS and HIT felt 10/10.
- **PS-8** Safe area: raw `Rect2i` and pixels; a notched iPhone has top and bottom insets above 0; an Android cutout is excluded (screenshot).
- **PS-9** 120 Hz Android and ProMotion iPhone, 3600 frames (60 s at 60): mean 58.2-61.8 fps (60 +/- 3%), no interval under 8.5 ms (120 Hz is 8.33 ms); Low Power Mode toggled 10 times: the exposed rate equals the OS rate at RET, 10 of 10.
- **PS-10** Background time: a 10 ms heartbeat after BG, 59 Home and 59 lock cases per platform; pass: the minimum is at least 5 x Save & Persistence's flush budget (provisional 100 ms, so 500 ms).
- **PS-11** 3 fresh installs per device, 60 s of play: zero permission prompts; the Android manifest lists only `VIBRATE`.
- **PS-12** Android: the thread id in each handler over 59 Home cycles is always the main thread and outside a tick; otherwise the node uses `call_deferred`.

**Gate policy.** AC-1..11, 14 and 15 are Logic and Integration evidence, BLOCKING. AC-12 and AC-13 are a blocking CI gate and must exist before the first Platform Services story is Done; the `project.godot` settings themselves are a Config/Data smoke check (ADVISORY). PS-1..PS-4 are BLOCKING for the first playable (signed by the qa-lead and the technical-director, the Tilt Input V-1 precedent); PS-5..PS-12 are ADVISORY. Deferred owners: AC-16 Run State, then the adapter story; AC-17 the spike story and the epics named above.

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | **Device spike PS-1..PS-12** (lifecycle sequences, Vulkan `PAUSED/RESUMED`, Back, PiP, haptics, safe area, 60 fps cap, background time, permissions, thread). PS-1..PS-4 block the first playable | user (needs phones) | Before the first playable |
| 2 | **The Android notification shade and heads-up calls are expected to emit no lifecycle event**, so the run would continue under a shade that covers part of the play area: a possible unfair death (Pillar 2). PS-1 measures it; if confirmed, options are a pause on shade (needs a native signal), accepting it, or a design answer from Run State | game-designer, godot-specialist | After PS-1 |
| 3 | Does Android Vulkan send `APPLICATION_PAUSED/_RESUMED`? The model works either way (F1); the answer only fixes the documentation | spike (PS-2) | After Q1 |
| 4 | Are Android lifecycle notifications delivered on the main thread and outside a tick? If not, the node defers them with `call_deferred` (Core Rules 4; Run State rule 3) | godot-specialist, spike (PS-12) | After Q1 |
| 5 | Game-loop ADR: the injected clock, the composition root that creates and wires `PlatformServices`, and the adapters to Run State and Tilt Input (shared with Tilt Input Open Question 4 and Run State Open Question 4) | technical-director | Technical Setup |
| 6 | Sensor-source ADR: which Android sensor settings the manifest requires (`enable_gravity` only, or also `enable_accelerometer`) | technical-director, godot-specialist | Technical Setup |
| 7 | **Cross-file edits pending approval:** `tilt-input.md` rule 9, Open Question 24, its Interactions row and AC-37d (delegates to AC-13) must stop relying on `APPLICATION_PAUSED/_RESUMED`; `run-state-restart.md` rule 11, its interfaces row and Open Questions 16 and 17 must say Platform Services emits signals and an adapter sends the requests; `systems-index.md` row 20 | this GDD's follow-up | End of this session |
| 8 | What Back does in Menu, Paused, Hit and Boot, and whether the app confirms before quitting | Menus & Screen Flow GDD (Run State Open Question 16) | When authored |
| 9 | Android 13+ and 16 predictive back and gesture navigation: no manifest opt-in was found in the export template | spike (PS-4), godot-specialist | After Q1 |
| 10 | Picture-in-Picture: the export manifest template sets `supportsPictureInPicture` true; disable it if the game must not run in a small window | godot-specialist, technical-director | Technical Setup |
| 11 | iOS display cutouts: no iOS override of `get_display_cutouts` was found (`get_display_safe_area` exists) | spike (PS-8) | After Q1 |
| 12 | Does a 60 fps cap hold on a 120 Hz Android device? If not, `Engine.max_fps` or a frame-pacing option | spike (PS-9), godot-specialist | After Q1 |
| 13 | How long the OS lets the app run after `app_backgrounded`, so Save & Persistence can size its flush | Save & Persistence GDD, spike (PS-10) | When authored |
| 14 | Target devices, minimum OS versions and the thermal and load budget are not decided here (systems index risk) | technical-director, producer | Technical Setup |
| 15 | No runtime permission prompt is expected for motion sensors or vibration on either platform; iOS motion usage string (Tilt Input Open Question 9) | spike (PS-11), Platform Services export | Technical Setup |
| 16 | Which haptic kinds Juice & Feedback needs beyond the three provisional ones, and the final values; a reduced-haptics setting for accessibility | Juice & Feedback GDD, accessibility-specialist | When authored |
| 17 | Export presets do not exist yet: the `VIBRATE` check in the manifest lint (AC-13) waits for them, BLOCKING from the first Android build | Technical Setup | First Android build |
| 18 | Test framework GUT versus gdUnit4 (shared with Tilt Input Open Question 16); the lint scripts live in `tools/ci/` | `/test-setup`, technical-director | Technical Setup |
