# Tilt Input

> **Status**: Revised after `/design-review` 2026-09-21 (verdict MAJOR REVISION NEEDED; 8 blocking items addressed); pending re-review in a fresh session
> **Author**: user + agents
> **Last Updated**: 2026-09-21
> **Implements Pillar**: Pillar 4 (One-Thumb Simplicity); supports Pillar 2 (Fair but Merciless Difficulty) by keeping sensor noise and sensor loss out of deaths
> **Revision 2026-09-21** (decisions by the user after the review): (1) the neutral pose is captured only at Menu-to-Play and at `run_resumed`; a restart from Hit or Paused inherits the previous neutral; (2) a sensor lost mid-run pauses the run through a new Run State pause source `sensor_lost` (no decay, no Dropout state); (3) machinery cut (F5 as runtime logic, `UNITS_SUSPECTED`, 9 log codes to 6, 5 states to 3, mid-ladder capture); (4) the "play anywhere" promise is scoped to postures where the roll formula works. Engine facts were checked against the 4.7 class reference and the 4.7.2 source (godot-specialist).

## Overview

Tilt Input is the Core-layer system that turns the phone's physical tilt into the single steering signal the whole game is played with. Every frame it reads the device's gravity vector, converts it into a signed left-right tilt for the game's portrait screen, removes the player's neutral pose, filters out noise and hand tremor, and publishes one steering value plus a validity flag. It owns everything between the sensor and that value: the sensor source and its availability, the axis and sign mapping, neutral-pose capture, dead zone, smoothing and sensitivity, handling of the app going to the background, a keyboard fallback for desktop development, and the signal that tells the game the sensor was lost. It captures the neutral only where the pre-tap pose is a genuine rest pose (Menu-to-Play and `run_resumed`) and keeps it across restarts. It does not own how the ball moves: Ball Movement turns the steering value into motion around the tube, and no other system reads the sensor. Because tilt is the game's only control, a wrong sign, a wrong neutral or a noisy sample is felt by the player as an unfair death (Pillar 2), and the phone must steer correctly in the postures the game supports (Pillar 4); players should feel their hand *is* the ball. Two technical decisions live outside this GDD and become ADRs, neither written yet: which loop polls the sensor (shared with the game-loop ADR that Run State also needs) and which sensor source is used (`get_gravity()` is the working choice, with the accelerometer as a fallback), both settled after the on-device spike. The published value is a normalized steering value; Ball Movement decides whether it drives a rate or a position.

## Player Fantasy

**The fantasy.** Your hand is the ball. The player holds the phone, tips it, and the ball answers right now, with no setup, no calibration screen and no sense of a sensor in between. It is the only control in the game (*Pillar 4: "Controls use a single input axis (left-right around the tube); the game is playable one-handed, anywhere."*), so the whole "flawless reflexes" fantasy of the concept rests on it: the player must feel their reactions getting sharper, and never that the phone got in the way.

**What it feels like.** Tilting is continuous and analog: a small tip nudges, a big tip sweeps, and holding still holds the ball still. The game adopts the pose the player is holding when they press Play (and when they come back from a pause), and it remembers it between restarts: restarting is a tap, not a chore, and the ball starts still when the phone is held the way it was held before. (The steadiness of the first second also rests on the hazard-free start that Pattern & Difficulty owes; see Open Question 11.)

**Where the promise holds.** Seated, standing, reclined against a backrest, or in a steady vehicle. It is **not** promised for lying flat on the back or on one's side, or for a vehicle that is braking or cornering hard: the roll formula cannot represent those postures (F1), and how far the OS-fused gravity vector resists vehicle acceleration is unmeasured (spike). Section B is scoped to what the spike can confirm; a wider promise needs the F1 rework named in Open Question 6.

**Serves the pillars.** *Pillar 2, "every death traces back to the player's own choice or reaction, never to randomness or bad luck"*: sensor noise, a wrong neutral, a swapped direction or a lost sensor must never be the cause of a death (a lost sensor pauses the run). Pillar 4 as quoted above.

**When feelings conflict.** Smoothing removes hand tremor but adds lag. Fairness comes first: a steady signal beats a raw one, but any lag the filter adds must stay under what the player can feel (a budget set on a device). "Never fights me" ranks above "my hand is the ball" only when the two cannot both be met.

**Feelings to avoid.** Sluggish or rubber-band steering; a neutral that creeps or that was taken from a moment the player did not choose (right after dying); left and right swapped; a lurch in the first frames because the tap that started the run jolted the phone; an awkward posture forced on the player; a calibration chore between runs; a control that goes dead while the run keeps going.

**Reference anchors (not measured, hypotheses):** Doodle Jump (continuous tilt with no calibration step), tilt-maze games (physical feel, inertia), Temple Run (auto-run plus tilt). None was tested against this game; feel is validated on a device (spike).

## Detailed Design

### Core Rules

1. **One owner of the sensors.** Only Tilt Input reads motion sensors (`Input.get_gravity()` and its siblings). No other system does; a CI grep lint enforces it (AC-37).
2. **Output contract.** Tilt Input publishes, pulled by consumers (no per-frame signal): `steer`, a finite float in `[-1, 1]`; `valid`, a bool; and `input_source` (`SENSOR` or `KEYS`). **`steer > 0` when the right edge of the phone, as the player sees it in portrait, is lowered**; Ball Movement moves `theta` in the positive direction for `steer > 0` (Tube Track: tilting right increases theta). `steer` is never NaN or infinite: a bad value becomes 0, the filter state resets to 0, and one `BAD_OUTPUT` error is logged. In Acquiring and Unavailable, `valid` is false and `steer` is 0. Consumers ignore `steer` outside Running.
3. **Orientation.** The game is **portrait, locked**: `display/window/handheld/orientation` must be `portrait` (value 1; the default 0 is landscape and does not swap the viewport size). Platform Services owns the setting and a CI project-settings lint checks it (AC-37). In portrait Godot applies **no** axis remap (verified in the 4.7.2 source: Android `ROTATION_0` is the identity, iOS uses the default portrait case), so the steering axis is the device x axis; reverse-portrait and sensor-driven orientations are unsupported (the axes flip) and log `NOT_PORTRAIT`. The tilt is how much the right edge is lower than the left, measured from gravity (F1).
4. **Sensor source and samples.** The working source is `Input.get_gravity()`, an OS-level virtual sensor (iOS `deviceMotion.gravity`, Android `TYPE_GRAVITY`); the sensor-source ADR settles it, with the accelerometer as a fallback where `TYPE_GRAVITY` is absent. Units are m/s^2 on both platforms (verified: iOS multiplies CoreMotion's g by 9.80665). The API has **no per-sample timestamp and no freshness flag**: it returns the last value the OS delivered. So a "sample" in this GDD is one poll-time read stamped with the poll clock; consecutive samples may repeat the same sensor value (Android delivers about 50 Hz, iOS refreshes once per rendered frame), and every count of samples counts frames. A sample is valid if the vector is finite and `|g| >= G_MIN`; a zero vector means no such sensor or a non-mobile platform (on Android the listener is only registered when the project setting is on). `SENSOR_SIGN` (+1 or -1, per platform, set from the spike) fixes the raw sign convention, which is unverified and may differ between iOS and Android; F1 uses only `g.x`.
5. **Pipeline, in this order:** validity check, roll angle (F1), subtract neutral, low-pass filter (F3), then dead zone, scale by `FS_eff`, clamp to `[-1, 1]` and response curve as one remap (F4). The dead zone acts on the filtered signal, so noise does not flicker across its edge.
6. **Polling.** `poll()` takes no argument. It is called **once per frame, in every phase (Menu, Running, Paused, Hit), by exactly one caller, before Ball Movement steps** (order fixed in the game-loop ADR; the recommended shape is one driver node that calls `tilt.poll()`, then Run State's tick, then the ball step, in one `_process` callback, not relying on `process_priority`; Run State already requires `_process` for its tick, Run State Open Question 4). Time comes from the injected clock (microseconds, the same clock as Run State's `press_us`): `dt = clamp((now - previous_now) / 1e6, 0, DT_MAX)` with the shared `DT_MAX` 0.1 s; the first poll has `dt = 0`. A poll whose stamp is not greater than the previous stamp (equal or going backwards) appends no sample and uses `dt = 0`. `dt` is not taken from the engine's frame delta (it is scaled by `Engine.time_scale` and capped by the engine).
7. **Neutral capture policy.** The neutral `phi0` is the roll angle the player holds as "level". It is **captured** on:
   - `run_reset` whose previous phase was Boot or Menu (the player pressed Play: a genuine rest pose);
   - `run_resumed` (the end of the resume countdown, when the player has re-gripped the phone);
   - `run_reset` from Hit or Paused **only while `neutral_stale` is true** (see below).
   On any other `run_reset` (restart from Hit or Paused) the previous `phi0` is **inherited** unchanged and the filter keeps running. Reason: before a restart the pose is the death pose or the pause pose, not a rest pose, and the capture window would fall inside the frozen Hit phase where the player gets no feedback. The neutral is otherwise **fixed** (no continuous recentering, no manual recalibration in the MVP). `neutral_stale` is true at construction, set when the app is paused (rule 9) or a sensor is lost (rule 10), and cleared by any capture. The adapter reports the previous phase of `run_reset` (from Run State's `phase_changed`; provisional).
8. **Capture mechanics.** Tilt Input keeps a ring buffer of roll angles stamped with the injected clock: capacity 128, a fixed `BUFFER_AGE` of 1.0 s, oldest overwritten, samples older than `BUFFER_AGE` dropped at every append and at every capture. A capture sets `phi0` to the **median of the samples in `[t - NEUTRAL_GUARD - NEUTRAL_WINDOW, t - NEUTRAL_GUARD]`** (F2), where `t` is the handler's time; the guard skips the jolt of the tap that caused the capture. If fewer than `NEUTRAL_MIN_SAMPLES` fall in the window, or Tilt Input is not Live, `neutral_pending` is set and the capture runs on the first valid sample (`phi0` = that sample). `phi0` is clamped to `+-L_eff` (F2). After a capture the filter starts at 0 (the relative angle is about 0 by construction, and the jolt of the tap is filtered instead of going straight into `steer`). On entering Live from Acquiring or Unavailable without a capture, the filter starts at the current relative angle. The settling tick (Run State rule 14) only gives the filter extra polls; nothing depends on it.
9. **Availability and the app lifecycle.** At boot the node reads `ProjectSettings` (`input_devices/sensors/enable_gravity`, `enable_accelerometer`; both default false and require a restart) and passes `sensors_enabled` to the core; if the chosen sensor is disabled it logs `SENSORS_DISABLED`. Tilt Input handles `NOTIFICATION_APPLICATION_PAUSED` and `NOTIFICATION_APPLICATION_RESUMED` itself (Platform Services still owns `app_interrupted` for Run State): on paused it clears the buffer, sets `neutral_stale` and returns to Acquiring; on resumed it discards samples for `SENSOR_RESUME_SETTLE`, because Android unregisters the listener when the app pauses while Godot keeps the last vector, which would pass the validity check with fresh poll stamps. The iOS behavior on resume is unverified (spike).
10. **Sensor loss.** If samples turn invalid while Live, `steer` holds its last value for `DROPOUT_HOLD` (measured as `t_i = now - last_valid`, in microseconds; `valid` stays true, so a one-frame blip is invisible). After that the state is Unavailable: `valid` false, `steer` 0, `neutral_stale` set, `availability_changed(false)` emitted. The thin adapter maps `availability_changed(false)` during Running or Resuming to `pause_requested(sensor_lost)` (a new Run State pause source, see Dependencies); a run is never played on with a dead control. Resume and Play must stay disabled while `valid` is false (UI Requirements). A valid sample brings the state back to Live (`availability_changed(true)`), and the next `run_resumed` captures a fresh neutral.
11. **Desktop fallback (development only).** In a debug build with the sensor disabled (or no valid sample within `SENSOR_START_TIMEOUT`), `input_source` becomes `KEYS`: Left/Right arrows (`steer_left`, `steer_right` actions, which must exist in `project.godot`) drive `steer` toward -1 or +1 at `KEY_SLEW` per second and back to 0 on release, `valid` is true, and the state is Live. It is terminal for the session and not part of the release feature set. While the source is `SENSOR` the keys are ignored. Mouse control is post-MVP (game concept).
12. **Testing seam.** `TiltMath` holds the pure functions (F1-F4) with no validation. `TiltCore` is a `RefCounted` with no Node and no `Input` call: it takes an injected `sample_source: Callable() -> Vector3`, a `clock: Callable() -> int`, a `log_sink: Callable(level, code, detail)`, a `key_source`, `is_debug`, `sensors_enabled`, `is_portrait` and a `TiltConfig`. `TiltConfig.validated()` applies rule 14; a test-only `TiltConfig.unvalidated()` bypasses it. Log codes (structured): `SENSORS_DISABLED`, `SENSOR_TIMEOUT`, `NOT_PORTRAIT`, `KNOB_CLAMPED`, `BAD_OUTPUT`, `POSTURE_UNSUPPORTED`. The core logs every rejected input; the production sink rate-limits to one message per code per 1.0 s of clock. Read-only getters: `steer`, `valid`, `input_source`, `state`, `phi0`, `phi_f`, `neutral_pending`, `neutral_stale`, `sample_count`. A thin `TiltInput` node reads the sensor, `ProjectSettings` and the lifecycle notifications and forwards them. GDScript pitfalls for the seam: Callables are untyped (guard with `is_valid()` at init), lambdas capture locals by value (tests mutate a member or a one-element Array), and `class_name` collisions can occur in headless runs. Tests build a fresh `TiltCore` each.
13. **No touch.** Tilt Input never reads touch or gestures (Pillar 4); touch belongs to HUD and Menus. Whether a touch-steering fallback exists for players without a usable sensor is Open Question 19.
14. **Config validation.** At load, in this order: (1) each knob is clamped to its own safe range; (2) `NEUTRAL_MIN_SAMPLES` is clamped to at most `floor(NEUTRAL_WINDOW * F_MIN)`; (3) `DEAD_ZONE` is clamped to at most `0.15 * TILT_FULL_SCALE`. One `KNOB_CLAMPED` error per knob changed (`CURVE_EXP < 1` becomes 1; a `FILTER_TAU` of 0 or less becomes 0.02). `NEUTRAL_GUARD + NEUTRAL_WINDOW` stays within 0.95 s by their ranges, inside the shortest resume countdown (1.0 s, Run State) and the buffer age.

### States and Transitions

| State | Meaning | `valid` | `steer` |
|-------|---------|---------|---------|
| Acquiring | Sensors enabled, waiting for the first valid sample (at boot, or after the app was paused) | false | 0 |
| Live | Valid samples flowing (or desktop keys, `input_source` = `KEYS`) | true | pipeline output, or key-driven |
| Unavailable | No usable sensor: none at boot, timeout, or lost mid-session | false | 0 |

| From | Event | To |
|------|-------|----|
| (construct) | sensors enabled | Acquiring |
| (construct) | sensors disabled, debug build | Live (`KEYS`) |
| (construct) | sensors disabled, release build | Unavailable |
| Acquiring | first valid sample (after any resume settle) | Live |
| Acquiring | no valid sample within `SENSOR_START_TIMEOUT` (counted from the first poll after the settle), debug build | Live (`KEYS`) |
| Acquiring | same timeout, release build | Unavailable |
| Live (`SENSOR`) | samples invalid for longer than `DROPOUT_HOLD` | Unavailable |
| Live, Unavailable | app paused (rule 9) | Acquiring |
| Unavailable | valid sample | Live |

Every other pair (including Live plus a valid sample, and anything from Live with `KEYS`) is ignored: no change, no error, no signal. `availability_changed(available: bool)` is emitted **whenever `valid` changes value**; the value at construction is not a change (so booting into `KEYS` or Unavailable emits nothing, and Acquiring to Live emits `true`). At construction `neutral_pending` and `neutral_stale` are true: the first valid sample captures the neutral from itself (so `steer` is 0 on that poll) and starts the filter at 0.

**Run lifecycle (events, not states):** `run_reset` and `run_resumed` are capture events under rule 7; `run_paused`, `run_ended` and `run_started` change nothing.

### Interactions with Other Systems

All interfaces are **provisional** (only Run State and Tube Track have GDDs).

| System | Direction | Data / events | Interface owner |
|--------|-----------|---------------|-----------------|
| Ball Movement | out | pulled `steer` in `[-1, 1]` and `valid`, once per step; Ball Movement owns rate versus position, gain, inertia and speed | Tilt Input owns the signal, Ball Movement the mapping |
| Run State & Restart | in / out | in: `run_reset` (with its previous phase), `run_resumed`, through a thin adapter owned by Tilt Input (Run State does not know Tilt Input); out: `availability_changed(false)` becomes `pause_requested(sensor_lost)` in Running or Resuming, through the same adapter | Run State defines the events and the pause source |
| Tube Track | convention | sign only: `steer > 0` raises `theta`; Tilt Input never calls Tube Track | Tube Track owns the frame |
| Platform Services | in | the portrait lock (project setting); `app_interrupted` for Run State stays with Platform Services, while Tilt Input handles the paused and resumed notifications for its own buffer | Platform Services |
| Menus & Screen Flow / Pause | out | `valid` gates the Play and Resume buttons | Menus |
| Settings & Accessibility | in (soft) | `sensitivity`, a divisor of `TILT_FULL_SCALE` (1 = default, larger = more sensitive), for players with limited wrist range | Settings owns the value |
| Pattern & Difficulty | indirect | the hazard-free start after a run begins covers a jolt that outlasts the settling tick (Run State Open Questions 11 and 17) | Pattern & Difficulty |

## Formulas

Tilt angles are in **degrees** (`asin` returns radians: convert when implementing). Every default value is in Tuning Knobs and is a guess until the on-device spike. Numbers were re-computed independently (Node) on 2026-09-21; nothing was run in Godot.

**Variables (shared)**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Gravity | g | Vector3 (m/s^2) | finite, `\|g\| >= G_MIN` | from `Input.get_gravity()`, device axes; the raw sign convention is unverified |
| Roll | phi | float (deg) | [-90, 90] | left-right tilt; the right edge lower than the left is positive |
| Neutral | phi0 | float (deg) | +-`L_eff` (at most 60) | the captured pose |
| Relative, filtered | phi_r = phi - phi0, phi_f | float (deg) | +-(90 + 60) | before and after the filter |
| Step | dt | float (s) | [0, `DT_MAX`] | clamped clock difference (`DT_MAX`, the shared 0.1 s) |
| Filter gain | alpha | float | [0, 1) | filter coefficient |
| Effective full scale | FS_eff | float (deg) | 6-50 | see F4 |
| Steer | s | float | [-1, 1] | the published value |

**F1. Roll angle**

`phi = SENSOR_SIGN * deg(asin(clamp(g.x / |g|, -1, 1)))`

- Output [-90, 90]. A zero, NaN, infinite or below-`G_MIN` vector is rejected **before** F1. The clamp is needed because rounding can push `g.x / |g|` slightly above 1 (it lives in a helper `clamp_ratio` so it can be tested, AC-1).
- Example (pitch 30 deg, twist 30 deg): `g = (4.248, -7.358, -4.905)` gives `phi = asin(0.433) = 25.66` deg.
- Noise gain is `1 / cos(phi)`: a 0.1 m/s^2 error is 0.58 deg at `phi` 0 but about 3.3 deg at `phi` 80, above the dead zone. Beyond about 70 deg the signal is unusable, and `asin` folds at 90 (tilting past it reads the same as tilting back): postures with `|phi|` above `PHI_MAX` are unsupported, which excludes lying on one's side.
- This is the geometric "right edge lower than the left" angle. A wrist twist about the screen normal loses gain as the phone is pitched back: a 50 deg twist reads 41.6, 22.5 and 3.8 deg at pitch 30, 60 and 85 (gravity cannot see the yaw part of a twist). Two fixes are deferred (Open Question 6): rotating `g` by `-phi0` about the screen normal before `asin`, and a blend with `atan2(g.x, -g.y)`.
- Vehicle acceleration adds an error of at most `asin(a / |g|)` to a raw accelerometer (11.8 deg at 2 m/s^2). `get_gravity()` is OS-fused, so the real figure is unknown, and fusion adds latency; the spike measures both.

**F2. Neutral capture**

`phi0 = clamp(median{phi_i : t - G - W <= t_i <= t - G}, -L_eff, +L_eff)`; for an even count, the mean of the two middle values. `N >= N_min` samples are required, otherwise `neutral_pending`. (`G` = `NEUTRAL_GUARD`, `W` = `NEUTRAL_WINDOW`, `N_min` = `NEUTRAL_MIN_SAMPLES`.)

`L_eff = clamp(PHI_MAX - FS_eff, 0, NEUTRAL_LIMIT)`; when the clamp is active, one `POSTURE_UNSUPPORTED` error is logged.

- Example: 18 samples in the window with median 3.4 gives `phi0 = 3.4`. The window is a closed interval: a 0.3 s window holds about 9, 18 and 30 samples at 30, 60 and 100 Hz (10, 19 and 31 when both ends align with a sample); every sample is a frame read (rule 4).
- The headroom keeps room to steer both ways: `phi0 + FS_eff` stays within `PHI_MAX` where `NEUTRAL_LIMIT` allows. A rest pose beyond `L_eff` leaves a permanent bias (rest 60 deg with `L_eff` 45 gives `steer` 0.574): that is the signal that the posture is unsupported.
- Constraints: `N_min <= floor(W * F_MIN)` (rule 14); `G + W <= 0.95` by the knob ranges, so the window fits inside the shortest resume countdown (1.0 s) and the buffer.

**F3. Low-pass filter**

`alpha = 1 - exp(-dt / max(tau, TAU_FLOOR))`, `phi_f = phi_f + alpha * (phi_r - phi_f)`, `TAU_FLOOR = 0.005`.

- Start: `phi_f = 0` after every capture; `phi_f = phi_r` on entering Live from Acquiring or Unavailable without a capture; unchanged on an inherited neutral. A loaded config never has `tau < 0.02`; the `TAU_FLOOR` guard is defense in depth for direct `TiltMath` calls.
- Example: `alpha = 0.2835` at dt = 1/60 with tau = 0.05; 0.8647 at dt = 0.1. Gain 0.954, 0.847 and 0.303 at 1, 2 and 10 Hz; phase lag 48, 45 and 20 ms (continuous-time approximations; the exact oracles are AC-5 and AC-9).
- Extremes: dt = 0 gives alpha = 0 (holds); a NaN in `phi_f` is reset to 0 by the `BAD_OUTPUT` rule.

**F4. Dead zone, scale, clamp, response curve**

`FS_eff = min(FS / sensitivity, FS_EFF_MAX)`; `dz_eff = min(DZ, 0.2 * FS_eff)`;
`u = clamp(sign(phi_f) * max(0, |phi_f| - dz_eff) / (FS_eff - dz_eff), -1, 1)`; `s = sign(u) * |u|^k`.
(`FS` = `TILT_FULL_SCALE`, `DZ` = `DEAD_ZONE`, `k` = `CURVE_EXP`, `FS_EFF_MAX` = 50.)

- Output [-1, 1], continuous at the dead-zone edge (no jump, no hysteresis needed) and monotone for `k >= 1`. The denominator is at least `0.8 * FS_eff`, so at least 4.8.
- Example: `FS = 25`, `DZ = 1.5`, `phi_f = 14`, `k = 1.5` gives `u = 0.532` and `s = 0.388`.
- Extremes: `FS = 12` with `sensitivity = 2` gives `FS_eff = 6` and the dead zone caps at 1.2. `FS = 45` with `sensitivity = 0.5` would need 90 deg for full lock; `FS_EFF_MAX` holds it at 50. `k >= 1` is required (`k < 1` amplifies noise).

**F5. Latency budget (design-time check, not runtime logic)**

`L_tilt ~ L_s + tau + T / 2` with `T` the frame time. A discrete filter with a zero-order hold lags a ramp by about `tau - T / 2`, so the sum is conservative by roughly half a frame; a sensor slower than the frame rate adds about half its period. `L_s` (sensor latency, including any OS fusion) is unmeasured: 30 ms is a placeholder and may be larger. The default `tau = 0.05` is checked against a target chosen after the spike (P-1); nothing in the running game evaluates this.

**F6. Sensor loss and desktop keys**

`t_i = now_us - last_valid_us` (microseconds, integer). For `t_i <= HOLD` (`DROPOUT_HOLD`): `steer` holds its last published value, `valid` stays true, the state stays Live. For `t_i > HOLD`: state Unavailable, `valid` false, `steer` 0. `HOLD = 0` is allowed, but one lost 60 Hz frame then pauses the run.

- Keys: `s = move_toward(s, R - L, KEY_SLEW * dt)` (`R`, `L` = 1 while the right or left key is pressed); both keys give a target of 0. At `KEY_SLEW = 4` per second, 0 to 1 takes 0.25 s.

## Edge Cases

**Sensor and samples**
- **If the chosen sensor's project setting is false**: log one `SENSORS_DISABLED` error at boot naming the settings; the state is Live with `KEYS` in a debug build and Unavailable in a release build. Tilt Input never silently steers 0 without that log line.
- **If the vector is zero, NaN or infinite**: the sample is invalid; nothing reaches F1. A finite but huge vector may overflow `|g|` and give `phi` 0 (wrong but finite; an upper bound is Open Question 7).
- **If `|g| < G_MIN` (free-fall, a thrown or dropped phone)**: the sample is invalid; rule 10 applies (hold, then Unavailable and a pause).
- **If the platform reports gravity in g units** (`|g|` near 1): every sample is invalid (`G_MIN` 3), so the state times out to Unavailable or `KEYS` with one `SENSOR_TIMEOUT` error; both platforms deliver m/s^2, so the spike (V-5) confirms this once.
- **If the phone is accelerating (a braking bus, cornering, shaking)**: F1 uses the direction only; the error is unmeasured for `get_gravity()` (F1). Nothing detects it in the MVP.
- **If the sensor returns the same vector for a long time (stuck)**: not detectable by comparing vectors (the API repeats the last value by design); Open Question 7.
- **If the chosen source returns zero but another sensor returns valid data (no `TYPE_GRAVITY`, accelerometer present)**: the fallback order is decided in the sensor-source ADR; until then the state times out to Unavailable.
- **If the screen is not in portrait at boot (the lock setting is missing, or reverse portrait)**: log one `NOT_PORTRAIT` error; F1 keeps using the device x axis, so the sign may be wrong (V-1 checks the shipped orientation).

**Neutral pose**
- **If the player restarts from Hit or Paused**: the previous `phi0` is inherited. If the phone was put down or the posture changed during a long Hit or pause, the ball steers toward the difference until the player levels the phone; a pause is followed by `run_resumed`, which recaptures, and Menu-to-Play recaptures (Open Question 21 measures how often this matters).
- **If the rest pose is beyond `+-L_eff`**: `phi0` is clamped with one `POSTURE_UNSUPPORTED` error and the relative angle is not 0 at the start; the ball steers toward that side until the player tilts back.
- **If fewer than `NEUTRAL_MIN_SAMPLES` fall in the window (the buffer was cleared by an app pause, or the run starts within about 0.55 s of launch)**: `neutral_pending` is set and the ball gets `steer = 0` until the first valid sample, which becomes `phi0`.
- **If `run_reset` from Menu or `run_resumed` arrives while the state is Acquiring or Unavailable**: `neutral_pending` is set; the capture runs on the first valid sample and the filter starts at 0.
- **If `run_reset` from Hit arrives while `neutral_stale` is true (the app was paused in Hit)**: it captures like a Menu-to-Play reset; if the player restarts soon after the settle, the window may hold post-resume samples from the Hit pose (rare; the spike measures it).
- **If the resume countdown is interrupted by a pause**: `run_resumed` is not emitted (Run State), so no capture happens; the next `run_resumed` captures.
- **If two `run_resumed` events come in quick succession**: each capture is independent and uses the buffer at its own time.
- **If the app is backgrounded**: the buffer is cleared, `neutral_stale` is set and samples are discarded for `SENSOR_RESUME_SETTLE` after the resume; the resume countdown (at least 1.0 s, above `G + W`) refills the window before `run_resumed`.

**Timing and polling**
- **If the clock stamp does not increase (equal, or going backwards)**: `dt = 0`, no sample is appended, the filter holds.
- **If a hitch is longer than `DT_MAX`**: `dt` is clamped for the filter; the ring buffer uses the real clock, so its windows are true time and samples older than `BUFFER_AGE` disappear.
- **If `poll` is called twice in one frame**: the second call carries the same clock stamp, so it appends nothing and uses `dt = 0` (rule 6 forbids it; this is the safe result).
- **If Ball Movement reads `steer` before `poll` in a frame (an ordering bug)**: it reads the previous frame's value, one frame stale; the game-loop ADR fixes the order and an integration test asserts it.
- **If the player taps the pause button and the phone jolts**: nothing special; Run State freezes the run on the same tick and the neutral is recaptured on resume.

**Mapping and settings**
- **If `phi_f` exceeds `FS_eff`**: `u` clamps to +-1 (full lock); there is no wrap and no overshoot.
- **If `sensitivity` from Settings is NaN, zero or negative**: it is replaced by 1; a finite value is clamped to `[SENSITIVITY_MIN, SENSITIVITY_MAX]`; each replacement logs one `KNOB_CLAMPED`.
- **If `DEAD_ZONE` is at least 0.2 of `FS_eff`**: it is capped at `0.2 * FS_eff` (F4) at run time, on top of the load-time cap of `0.15 * FS`.
- **If both desktop keys are pressed**: the target is 0.
- **If sensors are live in a debug build**: the keys are ignored (`input_source` `SENSOR`).

## Dependencies

Tilt Input has **no hard dependencies** (Core layer: no upstream system needs to exist for it to work). It has soft data inputs, which are contracts and not code dependencies, and one hard dependent.

**Inputs (soft)**

| Input | Supplied by | Used for | Note |
|-------|-------------|----------|------|
| Motion sensors (`get_gravity()`, `get_accelerometer()`) | The device through Godot | F1 | Android registration is gated by `input_devices/sensors/enable_*` (default false, restart required); the iOS driver starts CoreMotion regardless (whether the setting gates it is unverified); desktop returns zero |
| `NOTIFICATION_APPLICATION_PAUSED` / `_RESUMED` | Godot (mobile only) | Rule 9 | Handled by the `TiltInput` node itself |
| `run_reset(run_id)` with its previous phase, `run_resumed(run_id)` | Run State & Restart, through a thin adapter owned by Tilt Input | Neutral capture, filter start | Run State does not know Tilt Input (its rule 2); its rule 14 gives the ordering |
| The game clock in microseconds | The game loop (game-loop ADR, not yet written) | `dt`, ring buffer stamps | Shared `DT_MAX` clamp |
| Portrait lock (`display/window/handheld/orientation` = portrait) | Platform Services | Rule 3 | A project setting, not a runtime call |
| `sensitivity` | Settings & Accessibility | F4 | Optional; default 1 |

**Dependents**

| System | Type | What it needs from Tilt Input |
|--------|------|-------------------------------|
| Ball Movement | Hard | `steer` in `[-1, 1]` and `valid`, once per step; the sign convention (`steer > 0` raises `theta`) |
| Run State & Restart | Soft | `availability_changed(false)` as the source of `pause_requested(sensor_lost)`, through the adapter |
| Menus & Screen Flow | Soft | `valid`, to disable Play and Resume while the sensor is lost |
| Settings & Accessibility | Soft | The `sensitivity` hook |
| Playtest Telemetry | Soft (optional) | Possibly steer statistics; not specified here |

**Bidirectional consistency**
- Run State & Restart lists Tilt Input as a soft dependent (`run_reset`, `run_resumed`) and, since 2026-09-21, the `sensor_lost` pause source (rule 10, requests table, events, AC-29), the sensor-lost pause screen and the Resume and Start gating (UI Requirements), and a reworded rule 14. The adapter learns the previous phase of a `run_reset` from the last `phase_changed` it saw, so Run State needed no change for that. Consistent.
- Tube Track defines the `theta` sign and does not depend on Tilt Input: consistent.
- To update in the systems index: row 3 (Tilt Input) wording (the source is `get_gravity()` pending the spike ADR); row 19 (Settings & Accessibility) already lists Tilt Input (soft: `sensitivity`); the Platform Services GDD must provide the portrait lock (data inputs are not listed as dependencies in the index, as with Tube Track).
- Ball Movement's GDD must list Tilt Input as a hard dependency when it is written; Menus & Screen Flow must gate Play and Resume on `valid`.

**Provisional assumptions:** how Ball Movement uses `steer` (rate or position), the poll order in the game-loop ADR, and the adapter contract with Run State.

## Tuning Knobs

All defaults are guesses until the on-device spike; none comes from keyboard testing. Every knob lives in a `TiltConfig` resource (data-driven), not in code.

| Knob | Default | Safe range | Affects | Too low | Too high |
|------|---------|------------|---------|---------|----------|
| `TILT_FULL_SCALE` (FS) | 25 deg | 12-45 | Wrist range for full lock (F4) | Tremor amplified, twitchy steering | Full lock unreachable (a 50 deg twist at pitch 60 reads only 22 deg) |
| `DEAD_ZONE` (DZ) | 1.5 deg | 0-4 and at most 0.15 * FS | Rest steadiness (F4) | The ball never rests | Mushy fine control |
| `FILTER_TAU` (tau) | 0.05 s | 0.02-0.10 | Smoothness versus lag (F3, F5) | Tremor visible | Lag the player feels |
| `CURVE_EXP` (k) | 1.0 | 1-2 | Mid-range feel (F4); may move to Ball Movement (Open Question 20) | (below 1 is not allowed: amplifies noise) | Stiff mid-range, twitchy near full lock |
| `NEUTRAL_WINDOW` (W) | 0.3 s | 0.15-0.6 | Neutral robustness (F2) | One outlier decides | Window reaches earlier movement |
| `NEUTRAL_GUARD` (G) | 0.25 s | 0.05-0.35 | Skipping the tap jolt (F2); onset of a jolt precedes the handler time by the tap hold | Jolt leaks into the neutral | Window reaches earlier movement |
| `NEUTRAL_MIN_SAMPLES` | 5 | 3-6 and at most floor(W * `F_MIN`) | Minimum frames in the window (F2) | Outlier-prone | Always pending at low frame rates |
| `NEUTRAL_LIMIT` | 45 deg | 10-60 | Largest captured neutral, before the headroom `PHI_MAX - FS_eff` (F2) | The ball drifts when the phone is held tilted | Far side unreachable |
| `G_MIN` | 3.0 m/s^2 | 1-7 | Sample validity (rule 4) | Garbage direction in free-fall | Everything invalid (a platform reporting in g units is rejected entirely) |
| `SENSOR_START_TIMEOUT` | 2.0 s | 0.5-5 | Acquiring to Live (states) | False Unavailable or `KEYS` on a slow start | Slow debug start |
| `SENSOR_RESUME_SETTLE` | 0.3 s | 0.1-1.0 | Samples discarded after an app resume (rule 9) | A stale vector is accepted | Slow return to Live |
| `DROPOUT_HOLD` | 0.1 s | 0-0.3 | One-frame blips (F6) | A blip pauses the run | Ghost steering |
| `KEY_SLEW` | 4 per s | 1-20 (development only) | Desktop key response | Sluggish | Effectively digital |
| `SENSITIVITY_MIN` / `MAX` | 0.5 / 2.0 | fixed range of the Settings hook | `sensitivity` clamp (Edge Cases) | Very low sensitivity: `FS_eff` up to 50, harder full lock | High: `FS_eff` halves, twitchy |

**Fixed constants (not tuning knobs):** `TAU_FLOOR` = 0.005 s; `BUFFER_AGE` = 1.0 s and buffer capacity 128; `F_MIN` = 20 Hz (lowest supported frame rate); `PHI_MAX` = 70 deg (above it a posture is unsupported); `FS_EFF_MAX` = 50 deg. **Set by the spike, not tuned:** `SENSOR_SIGN` (+1 or -1 per platform) and `L_s`.

**Knob interactions**
- `NEUTRAL_GUARD + NEUTRAL_WINDOW <= 0.95` by the ranges: inside the shortest `RESUME_COUNTDOWN` (1.0 s, Run State) and the buffer. It no longer touches `RESTART_LOCK`, because a restart no longer captures.
- `NEUTRAL_MIN_SAMPLES <= floor(NEUTRAL_WINDOW * F_MIN)` (rule 14).
- `L_eff = clamp(PHI_MAX - FS_eff, 0, NEUTRAL_LIMIT)`: raising sensitivity shrinks `FS_eff` and widens `L_eff`; lowering it does the opposite.
- `DEAD_ZONE` and `sensitivity` interact through `FS_eff` (F4 caps the dead zone at `0.2 * FS_eff`).
- `NEUTRAL_LIMIT + FS_eff` must fit inside the wrist's comfortable range (not measured; about 60-70 deg is an unverified guess).

**Sources of truth elsewhere:** `DT_MAX` (Run State and registry `dt_max`, 0.1 s), `RESUME_COUNTDOWN` (Run State), `sensitivity` (Settings & Accessibility), speed and angular response of the ball (Ball Movement).

## Visual/Audio Requirements

**Visual:** none. Tilt Input has no visuals of its own. How the ball responds on screen belongs to Ball Movement, Camera and Juice & Feedback; how a lost or missing sensor is shown belongs to HUD and Menus & Screen Flow. **Audio:** none. Haptic or sound feedback for near-misses belongs to Juice & Feedback and Platform Services. No `/asset-spec` is needed.

## UI Requirements

No player-facing UI of its own in the MVP. Requests to other systems:

1. **Settings & Accessibility:** a tilt sensitivity control that feeds `sensitivity` (range `SENSITIVITY_MIN` to `SENSITIVITY_MAX`, 0.5 to 2.0, default 1), useful for players with limited wrist range.
2. **Menus & Screen Flow / HUD:** (a) a message when Tilt Input is Unavailable at boot in a release build ("This game needs motion sensors"); (b) a "sensor lost" pause message, shown when the run pauses with `sensor_lost`; (c) Play and Resume disabled while `valid` is false.
3. **No manual recalibrate control in the MVP.** If the spike shows posture drift needs one, it becomes a Pause screen or Settings action and a UX spec.

> **UX Flag:** this system has UI requirements. In Pre-Production, run `/ux-design` for the sensor-unavailable and sensor-lost messages and the sensitivity setting before writing epics.

## Acceptance Criteria

Oracle-exact ACs are locked now for the pure math (F1, F3, F4) and for the capture and state logic, which do not depend on device values (the fixtures inject the config). Everything that depends on measured device behavior is a **spike exit criterion** (below) with a provisional hypothesis, not an AC.

Test targets: **[M]** `TiltMath` called directly (no config validation); **[C]** `TiltCore` with a validated `TiltConfig`; **[C\*]** `TiltCore` with the test-only unvalidated config; **[I]** integration test (BLOCKING once its owner exists); **[L]** CI lint script (owner: a script in `tools/ci/`, not yet written; regex-based and best-effort). Unit tests live in `tests/unit/tilt_input/`; the framework (GUT or gdUnit4) is settled by the test-setup ADR (Open Question 16).

**Fixtures.** Config: FS 25, DZ 1.5, tau 0.05, k 1, W 0.3, G 0.25, N_min 5, `NEUTRAL_LIMIT` 45, `G_MIN` 3, timeout 2.0, settle 0.3, HOLD 0.1, KEY_SLEW 4, `SENSOR_SIGN` +1, release build, `PHI_MAX` 70, `FS_EFF_MAX` 50. `g(phi) = (9.81 sin phi, -9.81 cos phi, 0)`. Ticks at 60 Hz (clock +16667 us, so `dt` = 0.016667); loss tests at 50 Hz (+20000 us). Tolerance 1e-3 deg and 1e-4 steer, exact for 0, states and counts. Log assertions use structured codes and levels, not text. Timeouts count from the stamp of the first poll.

**Roll and validity**
- **AC-1 [M]** (F1): `roll_deg` of (6,-8,0) is 36.870; (3,0,-4) is 36.870 (pitch-independent); (0,-9.81,0) is 0; (+-9.81,0,0) is +-90; (4.248,-7.358,-4.905) is 25.66 (+-0.01); `clamp_ratio(1.0000001)` is 1.
- **AC-2 [C\*]** (R2, R4): `SENSOR_SIGN = -1` negates each AC-1 value; a pose 10 deg above neutral gives `steer > 0` with sign +1 and `< 0` with -1 (sign plumbing only; the end-to-end check is AC-40).
- **AC-3 [C]** (R4): zero, NaN, INF, (0,-2.99,0) and (0,-1,0) are invalid and never reach F1; (0,-3,0) is valid.

**Filter and mapping**
- **AC-4 [M]** (F3): alpha(1/60, .05) = 0.283469, alpha(.1, .05) = 0.864665, alpha(0, .05) = 0; tau 0 or -1 floors to `TAU_FLOOR`: alpha(1/60) = 0.964326 (1e-6). **[C]:** `FILTER_TAU` 0 or -1 in a loaded config is clamped to 0.02 with one `KNOB_CLAMPED` error.
- **AC-5 [C]** (F3, R5): neutral 0, constant phi 10: `phi_f` after 1, 3, 6 and 12 ticks is 2.8347, 6.3212, 8.6466 and 9.8168.
- **AC-6 [M]** (F4): k = 1: `phi_f` 1.5 gives 0 exactly; 0 gives 0; 14 gives 0.531915; 25 and 40 give 1; -14 gives -0.531915. k = 1.5: +-14 gives +-0.387939.
- **AC-7 [M]** (F4): sensitivity 2 with `phi_f` 7 gives 0.5; sensitivity 0.5 with `phi_f` 25.75 gives 0.5; FS 12, DZ 1.8, sensitivity 2 (`dz_eff` 1.2) with `phi_f` 3.6 gives 0.5; FS 12, DZ 4 (outside the config range, so `TiltMath` only), sensitivity 2 with `phi_f` 3.6 gives 0.5; FS 45, sensitivity 0.5 (`FS_eff` capped at 50) with `phi_f` 25.75 gives 0.5.
- **AC-8 [C]** (Edge): sensitivity NaN, 0 or -1 behaves as 1 (`phi_f` 14 gives 0.531915) with one `KNOB_CLAMPED` error each; 3 equals 2 and 0.1 equals 0.5, each with one `KNOB_CLAMPED` error.
- **AC-9 [C]** (R5): an alternating +-4 deg input from tick 0 gives `steer` exactly 0 on all 120 ticks (max `|phi_f|` 1.1339, below the dead zone; steady state `4 * alpha / (2 - alpha) = 0.66056`). A weak noise test: it passes largely by attenuation; see AC-41.
- **AC-10 [C]** (R2): after 1 s of steady 10 deg, `steer` is 0.361702; Acquiring and Unavailable give 0. **[C\*]:** with FS = 0 a NaN or INF output gives `steer` 0, `phi_f` reset to 0 and one `BAD_OUTPUT` error.

**Neutral**
- **AC-11 [M]** (F2): median of 7,1,3,80,5 is 5; of 1,2,3,4,5,80 is 3.5; nine samples at 2 and nine at 6 give 4.0.
- **AC-12 [C]** (R8): steady 5 deg until `t - 0.25`, then 30 deg samples in the last 0.25 s: `phi0 = 5.000`, and the next poll at 5 gives `steer` 0.
- **AC-13 [C]** (R8): a steady 15 deg for the whole window gives `phi0 = 15` and `steer` 0.
- **AC-14 [C]** (F2, closed interval): fillers in the window: four samples at 0 and four at 10 (median 5). A ninth sample at 10 stamped `t - 550000` us or `t - 250000` us gives `phi0 = 10` (included); stamped `t - 550001` or `t - 249999` gives `phi0 = 5` (excluded). Each case is separate.
- **AC-15 [C]** (F2, headroom): rest 35 deg gives `phi0 = 35`, `steer` 0 and no error; rest 60 gives `phi0 = 45`, one `POSTURE_UNSUPPORTED` error and a steady `steer` of 0.574468; rest 90 (g = (9.81, 0, 0)) gives `phi0 = 45`; with sensitivity 0.5 (`FS_eff` 50, `L_eff` 20) rest 35 gives `phi0 = 20` and a steady `steer` of 0.278351.
- **AC-16 [C]** (R7, capture policy): (a) `run_reset` from Menu at pose 5 gives `phi0 = 5`; then with the pose at 12, `run_reset` from Hit and separately from Paused leaves `phi0 = 5` (inherited) and a steady `steer` of 0.234043, and the filter is not reset; (b) `run_resumed` at pose 12 gives `phi0 = 12`, `phi_f` 0; (c) after an app pause and resume settle, `run_reset` from Hit captures (`neutral_stale` true), and the flag is false afterwards.
- **AC-17 [C]** (R8): fewer than `N_min` samples in the window (an empty buffer, only samples younger than 0.25 s, only samples older than 1.0 s, or four in the window) set `neutral_pending`; `steer` is 0; the first valid sample 7 then gives `phi0 = 7`, `steer` 0 and pending false.
- **AC-18 [C]** (Edge): a capture event while the state is Acquiring or Unavailable sets pending; the capture happens on the first valid sample (`steer` 0, `phi_f` 0, and exactly one `availability_changed(true)` from the state change).
- **AC-19 [C]** (R8): capture at 5, then N polls of 15 (dt = 1/60): N = 1 gives `phi_f` 2.8347 and `steer` 0.056795; N = 2 gives 4.8658 and 0.143227; N = 3 gives 6.3212 and 0.205158 (a raw pass-through would give 0.361702). No claim is made about how many polls fall before the first moving tick (AC-27, AC-39).
- **AC-20 [C]** (R7): after capture at 0, holding 12 deg gives `steer` 0.446809 at 2 s and at 30 s (difference below 1e-4: no recentering).
- **AC-21 [C]** (R8): two `run_resumed` events at `t` and `t + 1.5` s with the pose 5 until `t + 0.5` and 12 afterwards: the first `phi0 = 5`, the second `phi0 = 12` and `phi_f = 0`; two events at the same `t` give the same `phi0`.
- **AC-22 [C]** (lifecycle): `run_paused`, `run_ended` and `run_started` leave `phi0`, `phi_f`, state and sample count unchanged.
- **AC-23 [C]** (Edge): samples at 2 deg, a 10 s clock gap, then 0.6 s at 8 deg: `run_resumed` gives `phi0 = 8` and the buffer holds only post-gap samples (the age purge runs at every append).
- **AC-24 [C]** (R9): an app pause clears the buffer (`sample_count` 0), sets `neutral_stale`, moves to Acquiring and emits `availability_changed(false)`; stale vectors polled during the 0.3 s settle append nothing and the state stays Acquiring; the first valid poll at or after 0.3 s gives Live and `availability_changed(true)`.

**Polling**
- **AC-25 [C]** (R6): a poll 500000 us after the previous one uses `dt = 0.1` (`phi_f` 8.6466, not 9.9995); the first poll uses `dt = 0`; a second poll with the same stamp, and one whose stamp goes backwards, append nothing and leave `phi_f` unchanged.
- **AC-26 [C]** (R8): 300 samples at 240 Hz stamps (spanning 1.25 s) leave `sample_count` at 128, the oldest overwritten and the newest kept.
- **AC-27 [I], deferred** (R6): Ball Movement reads `steer` after `poll`, and the number of polls between a capture and the first `dt_eff > 0` tick is asserted (blocked on the game-loop ADR and the Ball Movement GDD; owner: the Ball Movement epic).

**Availability, loss, keys**
- **AC-28 [C]** (R9): `sensors_enabled = false` gives Live with `KEYS` (debug) or Unavailable (release), each with one `SENSORS_DISABLED` error and no `availability_changed`; `true` gives Acquiring with no error. **[I]:** the `TiltInput` node passes `sensors_enabled` from `ProjectSettings` (needs a SceneTree; deferred).
- **AC-29 [C]** (states): first poll at stamp 0; at 1.98 s with no valid sample the state is Acquiring, `valid` false, `steer` 0; a valid sample gives Live; with none at 2.0 s (inclusive) the state is Unavailable (release) or Live with `KEYS` (debug), with exactly one `SENSOR_TIMEOUT` error.
- **AC-30 [C]** (R10, F6): steady `steer` 0.8 (phi 20.3 for 1 s), then invalid samples: at `t_i` 0.10 `steer` stays 0.8, `valid` true, state Live, no signal (also for a single invalid frame); at `t_i` 0.12 the state is Unavailable, `valid` false, `steer` 0, `neutral_stale` true and exactly one `availability_changed(false)`, with no second signal on later polls.
- **AC-31 [C]** (R10): valid samples returning within the hold continue the filter (no restart, one clamped `dt`); from Unavailable, a valid sample gives Live, one `availability_changed(true)`, `phi_f = phi_r` and `neutral_stale` still true (no capture without a capture event).
- **AC-32 [C]** (states): table-driven over states {Acquiring, Live, Unavailable} and events {valid sample, invalid past the hold, start timeout, app paused}: every pair not in the transition table (including Live plus a valid sample, and Live with `KEYS`) gives no change, no error and no signal.
- **AC-33 [C]** (R11): `dt = 1/16`, right key held: `steer` 0.25, 0.5, 0.75, 1.0 then holds; release returns to 0 in 4 ticks; left gives -1; both keys give target 0; `valid` true.
- **AC-34 [C]** (R11): sensors live in a debug build: keys leave `steer` unchanged and `input_source` stays `SENSOR`.
- **AC-35 [C]** (Edge): a non-portrait boot logs one `NOT_PORTRAIT` error and leaves `roll_deg` unchanged.
- **AC-36 [C]** (R14): table-driven, one row per knob: a value below its range and above its range is clamped with one `KNOB_CLAMPED` error each; boundary values give none; cross-knob rows: W 0.15 with `N_min` 5 gives `N_min` 3, and DZ 4 with FS 12 gives DZ 1.8; `CURVE_EXP` 0.5 gives 1.
- **AC-37 [L]** (R1, R3, R12, R13): `TiltCore` and `TiltMath` are not Nodes; the pattern `\bInput\.get_(gravity|accelerometer|gyroscope|magnetometer)\b` matches only the `TiltInput` node file (comments and strings stripped, `tests/` excluded); no `Input.`, `Engine.`, `Time.` or `OS.` in `TiltCore` or `TiltMath`; no `InputEventScreen*` or `InputEventMouse*` in the tilt files; `project.godot` has `display/window/handheld/orientation` = 1 and the chosen sensor setting enabled. Best-effort: it cannot see aliasing such as `var i := Input`.
- **AC-38 [C]** (signals): `availability_changed` is emitted exactly when `valid` changes value: none at construction (including boot into `KEYS`, Unavailable or Acquiring); `true` on Acquiring to Live and Acquiring to `KEYS`; `false` and `true` around a loss.
- **AC-39 [I], deferred** (adapter): `run_reset` from Menu triggers the capture synchronously before `run_started`, from Hit or Paused it does not (unless stale); `run_resumed` likewise; a pause during the countdown emits no `run_resumed`; `availability_changed(false)` during Running or Resuming becomes `pause_requested(sensor_lost)` and does nothing in other phases; Play and Resume are disabled while `valid` is false (blocked on the real adapter and the Menus GDD; the Run State GDD already has the `sensor_lost` source, its AC-29).
- **AC-40 [I], deferred** (sign): with the right edge lowered, `steer > 0` and `theta` increases (blocked on the Ball Movement GDD; owner: the Ball Movement epic). This is the end-to-end gate for the "wrong sign" failure; V-1 is its device counterpart.
- **AC-41 [I], deferred until the spike** (Pillar 2): recorded rest traces per posture (from V-2) fed through `TiltCore` give `steer == 0` on at least 99% of ticks and `|theta|` drift below 1 deg over 60 s (provisional numbers); a posture-drift trace is added.
- **AC-42 [C]** (R12): the production sink lets at most one message per code through per 1.0 s of injected clock.

**Spike exit criteria (provisional hypotheses, not ACs; every threshold is unmeasured)**
- **V-1:** raw `g.x` sign per platform, at the shipped orientation and at the extremes: right edge lowered, the ball moves right in 10 of 10 trials on iOS and on Android (sets `SENSOR_SIGN`).
- **V-2:** rest noise (peak-to-peak and rms) per pitch at 0, 30, 60, 85 and above 90 deg, over 5 testers for 60 s each; hypothesis: peak-to-peak at most `2 * DZ` at every supported pitch. Include side-lying to record where the formula stops working.
- **V-3:** jolt amplitude and duration of the Menu-Play tap and the pause tap; hypothesis: below `DZ` within `G` plus one frame for at least 95% of taps.
- **V-4:** feel: at least 4 of 5 testers rate lag "not noticeable" at tau 0.05 s; full lock reached in at least 90% of trials at pitch 30 and 60.
- **V-5:** reported units and `|g|` at rest; hypothesis: within [9.0, 10.6] m/s^2 on both platforms.
- **V-6:** posture-change drift; the stale-vector behavior after backgrounding and resume; whether an iOS motion prompt appears (none expected).
- **V-7:** raw `get_accelerometer()` versus `get_gravity()`: vehicle acceleration error and latency, and whether `TYPE_GRAVITY` exists on the target Android devices.
- **P-1:** end-to-end latency (`L_s` plus tau plus a frame) on 3 devices, and whether gravity is pre-filtered; hypothesis: p95 at most 100 ms.
- **P-2:** sensor rate and `poll()` cost on the mid-tier Android target; hypothesis: p95 at most 0.1 ms.
- **P-3:** behavior with the app in the background for 30 s: no steer spike, exactly one `availability_changed(false)` and one `true`.
- Visual and feel items need lead sign-off in `production/qa/evidence/`.

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | (Resolved 2026-09-21) Pause on sensor loss is decided (`sensor_lost`) and the Run State GDD now has the source, the pause screen message and the Resume and Start gating; Menus & Screen Flow and HUD must implement the gating when authored | Menus & Screen Flow GDD | When authored |
| 2 | **On-device spike** (blocks locking every Tuning Knob): raw `g` and gyro log at full rate, postures at pitch 0 / 30 / 60 / 85 / above 90 and side-lying, several testers, iOS and Android; measure V-1..V-7 and P-1..P-3 | user (needs a phone) | Before the first playable and before Ball Movement tuning |
| 3 | Sensor-source ADR: `get_gravity()` versus accelerometer, the fallback order, whether `TYPE_GRAVITY` exists on target devices | technical-director, godot-specialist | Technical Setup |
| 4 | Game-loop ADR: one driver node in `_process` calling `tilt.poll()`, then Run State's tick, then the ball step (shared with Run State, its Open Question 4) | technical-director | Technical Setup |
| 5 | Measure how often `POSTURE_UNSUPPORTED` fires and whether the `NEUTRAL_LIMIT` clamp should be a pass-through up to `PHI_MAX` | spike | After Q2 |
| 6 | F1 rework for side-lying and twist gestures at high pitch: rotate `g` by `-phi0` about the screen normal before `asin`, or an `atan2` blend weighted by pitch (`smoothstep(0.5, 0.9, cos pitch)`); until then those postures are unsupported (Player Fantasy) | spike, sensor-source ADR | After Q2 |
| 7 | An upper bound `G_MAX` for overflow; stuck-sensor detection cannot use vector equality (the API repeats the last value); a check would need an independent signal | spike, godot-specialist | After Q2 |
| 8 | Axis remap in landscape and reverse portrait (closed for portrait: no remap, verified) | godot-specialist | Only if landscape is ever supported |
| 9 | iOS export: no motion-usage string exists in the 4.7.2 export options; confirm on a device that no prompt or crash occurs | Platform Services, export | Technical Setup |
| 10 | How Ball Movement maps `steer`: rate or position, angular speed, inertia (the prototype's 3.0 rad/s came from a keyboard); under a rate mapping a neutral error becomes continuous drift, which raises the cost of Open Question 21 | Ball Movement GDD | When that GDD is authored |
| 11 | How long the hazard-free start must be to cover a tap jolt that outlasts the settling tick (Run State Open Questions 11 and 17) | Pattern & Difficulty GDD | When authored |
| 12 | Manual recalibrate control, or re-anchoring of the neutral: add only if the spike shows posture drift | UX, Settings | After Q2 |
| 13 | `sensitivity` hook range and default; larger full scale for limited wrist range | Settings GDD, accessibility-specialist | When authored |
| 14 | The prototype's left/right sign flip was never visually re-confirmed; V-1 settles `SENSOR_SIGN` | spike | After Q2 |
| 15 | `L_s` and the latency target are guesses; the default `FILTER_TAU` is checked after measuring (F5) | spike | After Q2 |
| 16 | Test framework: GUT (technical-preferences, this GDD) versus gdUnit4 (coding-standards CI line, `/smoke-check`); the ADR picks one, updates the CI line and runs `godot --headless --import` first; both are recent, 4.7.2 compatibility unverified for either; the AC-37 lint needs a CI script in `tools/ci/` | `/test-setup`, technical-director | Technical Setup |
| 17 | (Resolved in this revision) the F1 clamp branch is testable through the `clamp_ratio` helper (AC-1) | | |
| 18 | Mouse and web control are post-MVP (game concept); the desktop key fallback is development only | user | Full Vision |
| 19 | Touch-steering fallback (hold the left or right half of the screen) for the automatic no-sensor path, and an opt-in setting for limited wrist range or tremor; single-axis, so within Pillar 4; must not clash with tap-anywhere restart | user, ux-designer, accessibility-specialist | Before MVP lock |
| 20 | Move `CURVE_EXP` (and possibly `TILT_FULL_SCALE`) to Ball Movement, and define one end-to-end latency budget in one place; do not lock defaults before a joint on-device tuning session | Ball Movement GDD, spike | When that GDD is authored |
| 21 | How often an inherited neutral is wrong after a long Hit or pause with a posture change; if it matters, add a re-anchor (for example a hold-still capture inside the hazard-free start) | spike, playtest | After Q2 |
