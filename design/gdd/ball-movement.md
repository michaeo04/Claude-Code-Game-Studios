# Ball Movement

> **Status**: Designed (all sections written 2026-09-22, lean mode: creative-director not consulted for CD-GDD-ALIGN or Player Fantasy framing beyond the framing question; pending an independent `/design-review` in a fresh session and the device spike BM-1..BM-6)
> **Author**: user + agents
> **Last Updated**: 2026-09-22
> **Implements Pillar**: Pillar 4 (One-Thumb Simplicity); Pillar 2 (Fair but Merciless Difficulty)

## Overview

Ball Movement owns the ball, the one thing the player controls, and moves it every frame while a run is in progress. The ball's state is where it sits on the tube: an angle around the tube (`theta`), the distance travelled along it (`s`) and a fixed height above the surface (`h = D/2`, with the ball diameter `D` = 0.8 owned here). Each Running frame the ball advances forward at a speed that rises over the run, and turns around the tube according to Tilt Input's `steer`. The distance `s` it integrates from Run State's `dt_eff` is what drives Tube Track's `advance(s)`, and `(theta, s)` plus the speed are what Camera follows and what obstacle, near-miss and scoring systems measure against. The player never touches the ball: they tilt the phone and it follows, on one axis, continuously, with no taps or lane snapping (Pillar 4). The ball is inert whenever the run is not Running (Hit, Paused, Resuming, Menu) and returns to a clean start on every new run. It decides nothing about what hurts (who detects contact is an open decision), what the phone reads (Tilt Input), when a run starts or ends (Run State), how the tube is laid out (Tube Track) or how the camera follows (Camera). It exists because the control feel, the dodge budget that Pattern & Difficulty designs against, and the sense of speed all live here; without it the game has no avatar. How `steer` becomes motion (angular position or rate, and how much inertia), the speed ramp, and contact ownership are settled in Detailed Design and Open Questions.

## Player Fantasy

**The fantasy.** I am steering a small, weighty ball with my wrist. I tilt the phone and the ball rolls around the tube where my hand points; I hold still and it holds still. It has a little weight, so it settles instead of snapping and the control feels physical rather than mechanical, but the weight is small, the same every time, and I have learned it within a run or two.

**What the player feels.**
- **The ball is an extension of my wrist.** The ball answers the first real tilt right away and never seems to be listening to something else: no delay I can feel, no jitter from the sensor, no correction I did not ask for. After a restart or a resume it feels the same as before, so nothing needs relearning (*Pillar 4: "the game is playable one-handed in any normal holding posture"*).
- **Weight without lag.** The ball has slight inertia, "physical rather than snappy/mechanical" (game concept), yet it never makes me fight it: it does not skate past where I aimed and it does not trail so far behind that I have to steer ahead of my own hand.
- **Threading a gap at speed.** The run gets faster and the ball keeps up. A gap that is just wide enough is threaded by small, precise motions, and the closer the dodge the more it feels like mine (*Pillar 3: "every close dodge must feel immediately rewarding"*).
- **Every death was my hand, not the ball.** When I die I can say what I did: I tilted too late, too far, or not enough. The ball never drifts on its own, sticks, jumps at a restart or a resume, or answers the same tilt two different ways (*Pillar 2: "every death traces back to the player's own choice or reaction, never to randomness or bad luck"*).

**Feelings to avoid.** A rubbery, late ball; a ball that slides on like ice (a "slippery ball" is an Alpha mode, so the default must not read as one); a ball that twitches with sensor noise or moves while I hold still; a jolt when a run starts or resumes; a speed ramp so steep that I never adapt.

**Where the promise holds.** Only as far as Tilt Input's signal is clean: the feel comes from that signal plus this system's response, and it is unverified until the on-device tuning session (Tilt Input Open Questions 2 and 20). A phone with no motion sensor uses the touch fallback (a held half-screen, bang-bang), which feels different by design and is not this fantasy.

**Serves the pillars.** *Pillar 4, One-Thumb Simplicity*: one axis, one continuous control, no taps. *Pillar 2, Fair but Merciless Difficulty*: a ball that is predictable and never the cause of a death. *Pillar 3* through the response that makes a close dodge feel earned.

## Detailed Design

### Core Rules

1. **State.** The ball has a tracked angle `phi` (unwrapped radians, a 64-bit float), the published `theta = wrap_angle(phi)` in `[-PI, PI)`, the distance `s >= 0` since the run started, the fixed height `h = BALL_DIAMETER / 2`, the current `speed`, an accumulated run time `t_run`, and `phi_anchor` (Rule 5). `BALL_DIAMETER` (`D`) is 0.8 and is owned here; the ball rides the circle of radius `R + D/2` (Tube Track rule 3). Ball Movement never computes world coordinates: the driver places the ball mesh with Tube Track's `P(theta, s, h)` (Tube Track rule 1).
2. **One step per frame.** The driver calls `step(dt_eff, steer, valid, input_source)` once per rendered frame after Run State's `tick()` returns, in every phase (poll order: tilt poll, adapter flush, `tick`, ball step; Tilt Input rule 6). `dt_eff` comes from `tick()` and is already clamped by Run State; Ball Movement never reads the engine delta or a clock. A step with `dt_eff <= 0` or not finite changes nothing except setting the previous values equal to the current ones (Rule 8). The driver reads Tilt's `steer`, `valid` and `input_source` once per frame, after the poll, and passes them in; when `valid` is false the last accepted `steer` is held instead of steering toward 0 (Edge Cases). The core holds no reference to Tilt Input, Run State or Tube Track.
3. **Sign.** `steer > 0` (right edge lowered) increases `phi` and `theta`, clockwise seen from behind (Tube Track's frame). Tilt Input AC-40 is the gate for the sign.
4. **Turning, position mapping (default).** `phi_target = phi_anchor + STEER_ARC * steer`, with `STEER_ARC` = PI so that `steer` in `[-1, 1]` spans one full turn and every point of the tube is reachable from any anchor. The ball follows the target with a first-order lag (`BALL_LAG_TAU`), and the angular speed of that follow is capped by `OMEGA_MAX` (F1). The lag never overshoots, so the same tilt always gives the same motion (Pillar 2), and `OMEGA_MAX` keeps Tube Track's dodge assumption (a 180 degree turn takes at least PI / `OMEGA_MAX` seconds, 1.05 s at 3.0 rad/s; Tube Track F9). Ball Movement adds no dead zone, recentering or filtering: Tilt Input owns those (Tilt Input rule 2 and F1 to F4).
5. **Anchor.** `phi_anchor` is 0 with `phi` at `run_reset`: this is intentional asymmetry, not an omission. At a reset the ball is placed at the top of the tube and `steer` is measured from the neutral Tilt Input just (re)captured, so a run that starts with `steer` not 0 glides from the top toward its target (at most PI / `OMEGA_MAX` seconds) rather than skip there. At a resume the ball's pose must be preserved (Player Fantasy: no jolt), so after `run_resumed` Tilt Input captures a new neutral (`steer` is 0 while the capture is pending) and the first moving step (`dt_eff > 0`) after `run_resumed` re-bases the anchor: `phi_anchor = phi - STEER_ARC * steer`. The target then equals the current pose and the ball does not slide because the neutral moved. `phi` and `phi_anchor` are shifted together by the same multiple of 2 PI whenever `|phi| > 2 PI`; `theta` is unaffected.
6. **Rate mode (`MAPPING_MODE` = RATE).** The angular velocity `w` follows `OMEGA_MAX * steer` through the same first-order lag and `phi += w * dt_eff`; the anchor is unused. RATE is the spike's comparison configuration for Tilt Input Open Question 10 and is **forced for a run whose `input_source` is `FALLBACK`**: with position mapping, releasing the held half-screen would slide the ball back to the anchor, which is not "hold to turn, release to stay". The mode is latched, from `MAPPING_MODE` and the `input_source` of the first step with `dt_eff > 0` after `reset()` (the core has no `run_started` event; any `input_source` other than `FALLBACK` counts as `SENSOR`), and holds for the run; a no-op step does not latch, and a mid-run change of `input_source` is ignored.
7. **Forward speed.** `speed` is a monotone non-decreasing function of `t_run`, from `V_START` to at most `V_MAX` (F2). Ball Movement integrates `t_run += dt_eff` itself (identical to Run State's `run_time` by construction; a conformance AC checks it) and advances `s` by the exact integral of the speed curve over the step (`s += S(t_run_new) - S(t_run)`, F2). Speed does not depend on `steer`, on how far the ball turns, or on anything the player does. Ball Movement owns `V_MAX` and re-points the registry entry; the value 25 u/s is an unvalidated contract and stays until the spike. `DT_MAX` stays with Run State (its registry source): Ball Movement only ever sees the clamped `dt_eff`.
8. **Published state.** After every step Ball Movement exposes read-only `theta`, `theta_prev`, `s`, `s_prev`, `speed`, `omega` (the applied angular step divided by `dt_eff`, F4; 0 when the step moved nothing) and `radius` (`D/2`). The previous values are the values before this step (equal to the current ones on a no-op step), so a consumer can test the swept segment from `(theta_prev, s_prev)` to `(theta, s)`: one step is at most `V_MAX * DT_MAX` = 2.5 u forward and `OMEGA_MAX * DT_MAX` = 0.3 rad around, which the contact ADR must sweep rather than sample (Run State Open Question 3). Consumers read it after the step in the same frame.
9. **Reset.** `run_reset` resets synchronously: `phi`, `phi_anchor`, `theta`, `theta_prev` = 0, `s`, `s_prev`, `t_run` = 0, `speed` = `speed(0)` (F2; `V_START`, or `V_MAX` when `T_RAMP` is 0 or less), the last accepted `steer` is 0, and the mapping-mode latch is cleared. The budget is about 1 ms, verified as a structural check (no loop or allocation in the reset body) plus a device measurement, not a wall-clock unit test (Run State F2). The ball is at the top of the tube at `s` = 0 in Boot and Menu.
10. **Inert outside Running.** Ball Movement has no phase logic: it moves only in a step with `dt_eff > 0`, and Run State returns 0 in Hit, Paused, Resuming, on every settling tick and on any tick where the phase changes. So the ball is frozen at its last pose in Hit, Paused and Resuming, and nothing moves on the first tick after `run_started` and `run_resumed`. After `run_resumed` the anchor re-base is armed (Rule 5).
11. **Contact is not detected here.** Ball Movement owns no collider, physics body or `CharacterBody3D` (Tube Track rule 12, AC-24) and never sends `hit_reported`. Obstacle System detects overlap against the published state and sends level-triggered `hit_reported(hazard_id, run_id)` (Run State rule 7). Provisional, pending the collision ADR (Open Questions).
12. **No side effects, deterministic.** Ball Movement sends no requests to Run State (Run State rule 3), reads no raw world Z (Tube Track AC-25), uses no randomness, and gives the same output for the same input sequence.
13. **Testing seam.** `BallCore` is a `RefCounted` with no engine calls; `BallMath` is a stateless static class holding the pure functions (F1's step, F2's `speed` and `S`, `wrap`, F5); `BallConfig` is a `Resource` with every value in Tuning Knobs and a `validated(log_sink)` method that returns a clamped copy (a NaN, infinite or out-of-range `dt_max` given to the core falls back to 0.1 with one `KNOB_CLAMPED`; an unrecognized `MAPPING_MODE` falls back to POSITION with one). `BallCore` takes the validated `BallConfig`, the injected `dt_max` (Run State's `DT_MAX`) and a `log_sink` (a `Callable(level, code, message)`; the driver's sink rate-limits). Events in: `reset()`, `on_resumed()`, `step(dt_eff, steer, valid, input_source)`. Read-only test getters include `phi`, `phi_anchor`, `w` and `t_run` in addition to the published state of Rule 8. Tests build a fresh core each.

### States and Transitions

Ball Movement has no phase of its own; its behavior is a function of `dt_eff`. What it holds at each point:

| Situation | Event / `dt_eff` | Ball does |
|-----------|------------------|-----------|
| Boot, Menu | none | Parked at the start pose (`theta` 0, `s` 0, `speed` `V_START`) |
| New run | `run_reset` | Reset (Rule 9); `phi_anchor` 0 |
| First tick after `run_started`, and after `run_resumed` | `dt_eff` = 0 (settling tick) | Nothing moves (Rule 10) |
| Second tick and later, Running | `dt_eff` > 0 | Every step moves the ball (Rules 4 to 7); the first step after a resume re-bases the anchor (Rule 5) |
| Hit, Paused, Resuming | `dt_eff` = 0 | Frozen at the last pose; previous values equal current |
| Resume | `run_resumed` | Anchor re-base armed; frozen through the countdown and the settling tick |

### Interactions with Other Systems

| System | Direction | Data / events | Note |
|--------|-----------|---------------|------|
| Tilt Input | in | `steer`, `input_source`, once per frame after the poll | Hard dependency; the mapping is Rule 4 (position, anchored) and Rule 6 (rate, forced for `FALLBACK`); sign gate Tilt AC-40; Tilt's neutral capture at resume is matched by the anchor re-base |
| Run State & Restart | in | `dt_eff` from `tick()`; `run_reset`; `run_resumed` | Ball Movement sends nothing to Run State |
| Tube Track | out | `s` (the driver calls `advance(s)` once per frame, only in Running); `theta`, `h` for `P(theta, s, h)` | Tube Track reads `V_MAX` (its F3, F5, F9) |
| Obstacle System | out | published state (Rule 8) | New dependency edge for the index: Obstacle System depends on Ball Movement; it owns contact detection (Rule 11) |
| Near-Miss Detection | out | `theta`, `s`, `radius`, `speed`, `omega` | Provisional |
| Camera | out | `theta`, `omega`, `speed`, `s` | Provisional; Camera owns its own lag |
| Scoring & Personal Best | out | `s`, `speed` | Provisional; Scoring decides what it uses |
| Pattern & Difficulty | out | `speed(t_run)` curve, `V_MAX`, `OMEGA_MAX`, `STEER_ARC` | Its dodge budget (`T_dodge_worst`) is built from these |
| Environment & Theming, Juice & Feedback | out | `speed` | Provisional |

**Provisional assumptions:** the driver, not Ball Movement, calls Tube Track's `advance(s)` (Tube Track rule 4 names the "traveller owner" as the caller, Run State rule 3 says the frame owner; the driver acts for Ball Movement, to be confirmed by the game-loop ADR); the collision ownership above; the published-state names; `mapping_mode` values until the on-device spike.

## Formulas

Every default is a guess pending the on-device spike. Times are seconds, angles radians, distances world units. Oracles below were recomputed in a Node script (the values are exact to the digits shown).

**F1. Angular tracking step (position mode)**

```
phi_target = phi_anchor + STEER_ARC * clamp(steer, -1, 1)
e          = phi_target - phi
alpha      = 1 - exp(-dt / BALL_LAG_TAU)        (alpha = 1 when BALL_LAG_TAU < 1e-4)
step       = clamp(e * alpha, -OMEGA_MAX * dt, +OMEGA_MAX * dt)
phi        = phi + step;  if |phi_target - phi| < 1e-6 then phi = phi_target
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Step time | `dt` | float | 0 to 0.1 | `dt_eff`; `dt <= 0` or non-finite is a no-op, tested before `alpha` |
| Lag constant | `BALL_LAG_TAU` | float | 0 to 0.12 | 0 means no lag (cap only) |
| Speed cap | `OMEGA_MAX` | float | 2.75 to 4.0 | rad/s |
| Steer arc | `STEER_ARC` | float | 2.09 to PI | rad per unit `steer` |
| Error | `e` | float | (-2 PI, 2 PI) | target minus tracked angle, unwrapped |
| Step | `step` | float | `[-OMEGA_MAX*dt, +OMEGA_MAX*dt]` | radians applied this frame |

**Output range:** `|step| <= min(|e|, OMEGA_MAX * dt)`: it never overshoots or reverses; at most 0.3 rad per step at `DT_MAX`. A non-finite `steer`, or `valid` false, keeps the last accepted target.
**Frame-rate independence:** exact while uncapped (`e_n = e_0 * exp(-t / tau)` at any rate); the capped form differs only in the frame where the cap releases (a time shift of about `dt^2 / (8 tau)`: 0.58 ms at 60 Hz, 2.3 ms at 30 Hz, a position error of at most 0.007 rad at 30 Hz). Tolerance across rates: 0.05 rad for a sampled 1 Hz, 0.5 rad sine.
**Example** (`tau` 0.06, `OMEGA_MAX` 3.0): `dt` 1/60, `e` 1.0 gives `alpha` 0.242535, uncapped 0.2425, capped step 0.05; `e` 0.1 gives 0.0242535. A 0.1 rad target held 0.1 s gives `phi` = 0.0811124 at 30, 60 and 120 Hz. A step of PI first has `|e| <= 0.05` after 32 / 64 / 128 frames = 1.0667 s at 30 / 60 / 120 Hz.
**Extremes:** `dt` 0 gives 0; `tau` 0 gives `step = clamp(e, +-OMEGA_MAX*dt)`, a pure rate limit that still lands on the target (`e` 0.03 gives 0.03, `e` 0.1 gives 0.05 at 60 Hz); a full-lock reversal at `STEER_ARC` = PI is a full lap (2 PI / `OMEGA_MAX` = 2.09 s), because `steer` +1 and -1 are the same point.

**F2. Forward speed and distance**

```
speed(t) = V_START + (V_MAX - V_START) * min(t / T_RAMP, 1)
S(t)     = V_START*t + (V_MAX - V_START) * t^2 / (2 * T_RAMP)                   for t <= T_RAMP
S(t)     = T_RAMP * (V_START + V_MAX) / 2 + V_MAX * (t - T_RAMP)                 for t >  T_RAMP
per step: t_run_new = t_run + dt;  s += S(t_run_new) - S(t_run);  publish speed(t_run_new)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Run time | `t` | float64 | >= 0 | `t_run` |
| Start speed | `V_START` | float | 6 to `V_MAX` | u/s, must be > 0 |
| Max speed | `V_MAX` | float | 18 to 30 | u/s, the value Tube Track validates |
| Ramp time | `T_RAMP` | float | 45 to 240 | s; 0 or less means `V_MAX` from the start |

**Output range:** `speed` in `[V_START, V_MAX]`, monotone non-decreasing; one step advances `s` by at most `V_MAX * DT_MAX` = 2.5 u. `V_START > V_MAX` is rejected at load; `V_START = V_MAX` is legal (constant speed). The exact integral replaces a left-Riemann `speed * dt`, which under-counts by `a * dt * t / 2` (0.125 u after 90 s at 60 Hz).
**Example** (10 / 25 / 90): `speed(0)` = 10, `speed(45)` = 17.5, `speed(90)` = 25; `S(45)` = 618.75, `S(90)` = 1575, `S(120)` = 2325; `s` reaches Tube Track's `S_PRECISION_LIMIT` 16384 at t = 682.36 s.
**Readability at `V_MAX`:** 25 u/s is 31 ball widths per second and a segment every 0.48 s; Tube Track F9 gives `T_vis` 1.52 s, a margin of only 0.02 s over its 1.5 s minimum with its default segments.

**F3. Angular tracking, RATE mode**

```
w_ss = OMEGA_MAX * clamp(steer, -1, 1)
dphi = w_ss * dt + (w - w_ss) * BALL_LAG_TAU * alpha           (alpha as in F1)
w    = w_ss + (w - w_ss) * (1 - alpha);   phi = phi + dphi
```

`w` is the angular velocity in `[-OMEGA_MAX, OMEGA_MAX]` (a convex combination keeps it there), 0 at `run_reset` and `run_resumed`; this is the exact integral for a constant `steer`, so it is frame-rate independent. **Output range:** `|dphi| <= OMEGA_MAX * dt`. **Example** (`steer` 1, `tau` 0.06, from rest, `dt` 1/60): `w` after one frame 0.727605, `dphi` 0.0063437; `phi` after 0.1 s = 0.153998 at any rate. **Extremes:** `dt` 0 changes nothing; `tau` 0 gives `w = w_ss`. On release rate mode coasts `OMEGA_MAX * tau * |steer|` = 0.18 rad (10 degrees, 0.61 u), position mode does not. A residual `steer` of 0.02 (a 1.97 degree neutral error) drifts at 0.06 rad/s (3.44 degrees/s, 0.204 u/s, one ball width per 3.9 s) in rate mode and gives a fixed offset of 0.0628 rad in position mode; Tilt Input's dead zone makes `steer` exactly 0 inside 1.5 degrees.

**F4. Published angular velocity**

`omega = (phi_new - phi_old) / dt`, the applied angular change divided by `dt`, taken before any 2 PI re-base (`phi_old` and `phi_new` are the tracked angle before and after this step's motion, including a snap when F1 applies one); equal to `wrap(theta - theta_prev) / dt` since `|step| <= 0.3 < PI`, with `wrap(x) = x - 2 PI * floor((x + PI) / (2 PI))`; 0 when `dt <= 0`. **Range:** `[-OMEGA_MAX, OMEGA_MAX]` (within about 1e-4 on a snap frame, where the snap can add a small residual). **Example** (`dt` 1/60): `theta_prev` 3.12 and `theta = wrap(3.12 + 0.05)` give `omega` = +3.0 within 1e-6; the mirror gives -3.0; `dt` 0 gives 0.

**F5. Dodge time, latency budget and resolution**

(a) *Time to move an arc `X` from rest to within `eps` of the target* (cap then lag; `K = OMEGA_MAX * BALL_LAG_TAU` = 0.18 rad): `T(X, eps) = (X - K) / OMEGA_MAX + tau * ln(K / eps)` when `eps < K`, else `(X - eps) / OMEGA_MAX`. Pattern & Difficulty and Tube Track F9 consume `T_DODGE_180 = T(PI, 0.05)` = **1.064 s**, the authoritative value (the 1.05 s assumption plus 0.017 s of lag; with `eps` 0.1 it is 1.022 s). This continuous value, not F1's frame-quantized example (1.0667 s at 60 Hz), is what other GDDs read. `T(PI/2, 0.1 * PI/2)` = 0.4718 s. F9 (`T_dodge_180` + 0.25 reaction + about 0.083 latency = 1.40 s against 1.5 s) stays valid while `T_dodge_180 <= 1.167 s`, that is `OMEGA_MAX >= 2.75` at `tau` 0.06 or `tau <= 0.12` at `OMEGA_MAX` 3.0.

(b) *Latency budget.* Tilt Input's filter (0.05 s) in series with `BALL_LAG_TAU` has a 63% response time of 0.118 s at `tau` 0.06 (0.138 s at 0.08). Budget: software response at most 0.13 s, end to end (adding about 0.01 s sensor, one poll frame and about two display frames) at most 0.20 s at 60 Hz (0.178 s at `tau` 0.06; 0.228 s at 30 Hz, over budget). The budget is a guess pending the spike and stays under the 0.25 s human reaction time.

(c) *Resolution* (position mode, Tilt Input `CURVE_EXP` 1): `ball_deg_per_tilt_deg = (STEER_ARC / (TILT_FULL_SCALE - DEAD_ZONE)) * 180 / PI` and `widths_per_tilt_deg = (STEER_ARC / (TILT_FULL_SCALE - DEAD_ZONE)) * (R + D/2) / D`. At the defaults (`STEER_ARC` PI, `TILT_FULL_SCALE` 25, `DEAD_ZONE` 1.5): 7.66 degrees of ball per degree of wrist, 0.568 ball widths per degree (one ball width is 1.76 degrees of wrist); the dead zone spans 0.85 ball widths (it hides rest tremor; the ball is sticky at rest); a 10 Hz tremor is attenuated to 0.078 by the two lags, a 2 Hz drift only to 0.68. Fine positioning is feasible for gaps of about 2.5 ball widths or more; a 2-width gap leaves about +-0.9 degrees of wrist. `TILT_FULL_SCALE` 35 gives 5.37 degrees per degree. `STEER_ARC` and `TILT_FULL_SCALE` are one joint tuning surface for the spike (Tilt Input Open Question 20).

**F6. Distance accumulation.** `t_run` and `s` are 64-bit floats; the worst rounding error over 40,942 frames (one full ramp at 60 Hz to `s` = `S_PRECISION_LIMIT`, t = 682.36 s) is about 7.5e-8 u. Conformance: `|s - S(t_run)| <= 1e-6 u` after 100,000 frames, and `t_run` equals Run State's `run_time`.

## Edge Cases

**Step input**
- **If `dt_eff` is 0 (a settling tick, Hit, Paused, Resuming, or a tick where the phase changed)**: the step changes nothing except `theta_prev`, `s_prev` = the current values and `omega` = 0 (Rule 2).
- **If `dt_eff` is negative, NaN or infinite**: treated as 0 with one `BAD_DT` error to the injected `log_sink` (the driver's sink rate-limits).
- **If `dt_eff` exceeds the injected `dt_max` (a Run State contract violation)**: clamped to `dt_max` with one `DT_OVER_MAX` error, so one step is still at most 2.5 u forward and 0.3 rad around.
- **If `steer` is NaN or infinite, or `valid` is false**: the last accepted `steer` (the clamped value from the last step it was accepted) is held (F1); a non-finite `steer` logs one `BAD_STEER`, `valid` false alone logs nothing, and `valid` false with a non-finite `steer` also logs nothing (`valid` wins). A no-op step (`dt_eff <= 0`) never updates the held value regardless of `steer` or `valid`. The ball does not slide toward the anchor. Under Tilt Input's contract a lost sensor pauses the run before the step, so this is a backstop. **If `steer` is outside `[-1, 1]`**: clamped (F1). **If the re-base step itself carries a bad `steer`**: the held value from before the step is used for both the re-base and the motion.
- **If `input_source` changes during a run**: ignored; the mapping mode is latched on the first step with `dt_eff > 0` after `reset()` (Rule 6) and holds for the run.
- **If a hitch makes the driver's frame long**: Run State clamps `dt_eff` to `DT_MAX` (0.1 s), so the ball advances at most 2.5 u once; a stall of 0.5 s or more pauses the run (Run State).
- **If the frame rate is 30 or 120 Hz**: speed is exact (the integral of F2) and tracking is exact while uncapped (F1); for a continuously varying `steer` (the 1 Hz, 0.5 rad sine of F5) the trajectory differs by at most 0.05 rad across rates. A discrete step input reaches a given error within about one frame at any rate (F1's example), which is not the same claim.
- **If time is scaled (a future hitstop or slow motion)**: `world_dt` scales inside Run State and `dt_eff` follows; Ball Movement uses only `dt_eff`, so nothing else changes.

**Start, hit, pause, resume**
- **If a run starts with `steer` not 0 (Tilt Input inherited an unsteady pose at a restart)**: `phi_anchor` = 0 and the ball glides from the top toward `STEER_ARC * steer` at up to `OMEGA_MAX` (at most PI / `OMEGA_MAX` = 1.05 s); Tilt Input owns the neutral and Pattern & Difficulty owes a hazard-free start (Run State Open Questions 11 and 17).
- **If a hit happens on a frame**: Run State returns `dt_eff` 0 for that frame, so the ball is frozen at the pose of the last moving step, the pose the contact was tested at; the collision owner keeps reporting until accepted (Run State rule 7).
- **If the run is paused while the ball is still catching up to its target**: the ball stays where it is. After `run_resumed` the first moving step re-bases the anchor (`phi_anchor = phi - STEER_ARC * steer`), so the target equals the pose and the leftover lag is discarded; in RATE mode `w` is 0 after a resume.
- **If a `run_reset` arrives after a Hit or from Paused**: everything resets synchronously (Rule 9); a `run_reset` never arrives from inside a step (Run State rule 3).
- **If the sensor is lost mid-run**: Tilt Input's adapter pauses the run before the step (Tilt Input rule 10); the ball is inert until resume.

**Angles and speed**
- **If `theta` is exactly PI**: `wrap_angle` gives -PI; consumers compare angles with Tube Track's `delta_theta`, never by subtracting (Tube Track rule 2).
- **If `|phi|` exceeds 2 PI**: `phi` and `phi_anchor` shift together by a multiple of 2 PI (Rule 5); `e` and the target are unchanged and `omega` is computed before the shift (F4).
- **If a full-lock reversal is made at `STEER_ARC` = PI**: `steer` +1 and -1 are the same tube point, so the ball makes a full lap of 2.09 s; this is the worst-case dodge for Pattern & Difficulty.
- **If `t_run` passes `T_RAMP`**: `speed` stays at `V_MAX` (F2).
- **If `s` approaches Tube Track's `S_PRECISION_LIMIT` (16384, at 682 s with the defaults)**: Ball Movement keeps integrating in 64-bit floats and does not cap or re-base `s`; a run cap or re-base is an Open Question for Tube Track and Run State.
- **If `T_RAMP` is 0 or less**: it is an accepted sentinel, not a clamp: `speed` is `V_MAX` from `t_run` 0 and no `KNOB_CLAMPED` is logged; a value strictly between 0 and 45 clamps to 45 with one error.

**Control feel and degenerate play**
- **If the phone is tilted beyond `TILT_FULL_SCALE`**: Tilt Input clamps `steer` at +-1; the ball reaches the anchor +-PI and stays.
- **If the player shakes the phone**: the two lags and `OMEGA_MAX` bound the ball's angular speed at 3.0 rad/s, so at worst it laps the tube; there is no faster or teleporting move.
- **If `input_source` is `FALLBACK` (touch hold)**: RATE mode (Rule 6); the ball turns while the half-screen is held, coasts about 10 degrees after release and stops.
- **If a heavier or slippery ball mode is added (Alpha)**: it changes `BALL_LAG_TAU` and `OMEGA_MAX` through `BallConfig`; the default must not read as slippery (Player Fantasy).

**Contact and consumers**
- **If a step is 2.5 u long and a hazard is thinner**: the contact ADR must test the swept segment from `(theta_prev, s_prev)` to `(theta, s)`; Ball Movement supplies both ends (Rule 8).
- **If a consumer reads the published state before the step in a frame**: it gets the previous frame's values; consumers read after the step (Rule 8), a driver-order rule tested by Acceptance Criteria AC-30 (Tilt Input AC-27 only covers steer-after-poll and the poll count, not consumer order).

## Dependencies

**Upstream (Ball Movement needs these)**

| System | Type | What it needs | Note |
|--------|------|---------------|------|
| Tilt Input (In Review) | Hard | `steer` in `[-1, 1]`, `valid`, `input_source`, once per frame after the poll; the neutral it captures at Menu-to-Play, at a restart and at `run_resumed` | Ball Movement states the mapping (Core Rules 4 to 6). Sign gate Tilt AC-40; loop stories AC-27 and AC-41 are owned by the Ball Movement epic. Tuning locks only after the on-device spike |
| Run State & Restart (Approved) | Hard | `dt_eff` from `tick()`, `run_reset`, `run_resumed`; the injected `DT_MAX` | `DT_MAX` and the phase logic stay with Run State; Ball Movement sends no requests |
| Tube Track (Approved) | Hard (contract, no code call) | The coordinate frame (`theta` clockwise from behind, `[-PI, PI)`, `wrap_angle`), `R` = 3.0, the ring radius `R + D/2` | The driver, not Ball Movement, calls `advance(s)` and places the mesh; only `wrap_angle` is shared code |

**Downstream (these need Ball Movement)**

| System | Type | What it needs |
|--------|------|---------------|
| Obstacle System | Hard | The published state with previous values, to detect contact by a swept test and send `hit_reported` (Core Rules 8 and 11) |
| Near-Miss Detection | Hard | `theta`, `s`, `radius`, `speed`, `omega` |
| Camera | Hard | `theta`, `omega`, `speed`, `s` |
| Pattern & Difficulty | Hard | `speed(t_run)`, `V_MAX`, `OMEGA_MAX`, `STEER_ARC`, `T_DODGE_180` (F5) for its dodge budget |
| Scoring & Personal Best | Soft | `s` (distance), `speed` |
| Environment & Theming, Juice & Feedback | Soft | `speed` |
| Pickups & Boosters (Content Expansion) | Hard | The published state |
| Game Modes (Alpha) | Soft | `BallConfig` overrides (`BALL_LAG_TAU`, `OMEGA_MAX`) for heavier or slippery balls |

**Bidirectional consistency (checked against the existing GDDs)**
- **Tube Track:** it already says Ball Movement owns speed, `V_MAX` and `s`, and expects the value to be confirmed (Open Question 12). Confirmed here (25 u/s kept). Its F9 should now consume `T_DODGE_180` = 1.064 s and the latency from this GDD (margin 0.10 s, not 0.15 s), and its `v_max` registry source is re-pointed. Edits pending approval.
- **Tilt Input:** it lists Ball Movement as consumer and defers the mapping (Overview, Open Questions 10 and 20). Answered here: position mapping, anchored, with RATE for `FALLBACK`; `CURVE_EXP` and `TILT_FULL_SCALE` stay in Tilt Input (one joint tuning surface with `STEER_ARC`, F5c); the latency budget is defined here (F5b). Its Open Questions 10 and 20 and its interface note need updating. Edits pending approval.
- **Run State:** Open Question 3 (collision owner) is answered provisionally (Obstacle System) and Open Question 9 (`DT_MAX` owner) is answered (stays with Run State); the registry `dt_max` note ("Owner to be settled in the Ball Movement GDD") is stale. Edits pending approval.
- **Systems index:** add the edge Obstacle System depends on Ball Movement (row 4); the note for GDD authors should record the Ball Movement decisions. Pending approval.
- **Entity registry:** `v_max` re-points to this GDD and gains the confirmed value; new entries for `ball_diameter`, `omega_max`, `steer_arc`, `ball_lag_tau`, `v_start`, `t_ramp`.
- **Obstacle System, Near-Miss, Camera, Pattern & Difficulty, Scoring, Environment, Juice, Pickups and Game Modes have no GDD yet:** each must list Ball Movement when authored.

**Provisional assumptions:** the collision ownership, the published-state names, the driver calling `advance(s)`, the `mapping_mode` values until the spike, and every default in Tuning Knobs.

## Tuning Knobs

All defaults are guesses pending the on-device spike (Tilt Input V-1 and the joint tuning session); none comes from the keyboard prototype. Every knob lives in `BallConfig` (a `Resource`), never in code. Validation at load: each value is clamped to its safe range; a NaN or infinite value takes its default; one `KNOB_CLAMPED` error per value changed. `V_START`'s range (6 to 14) is always below `V_MAX`'s (18 to 30), so the two ranges cannot cross and no run-time comparison between them is needed.

| Knob | Default | Safe range | Affects | Too low | Too high |
|------|---------|------------|---------|---------|----------|
| `STEER_ARC` | PI rad | 2.09 to PI | Ball degrees per degree of wrist (F5c): 7.66 at PI; the unreachable arc is `2 PI - 2 * STEER_ARC` (0 at PI, 120 degrees at 2.09) | Part of the tube (opposite the anchor) cannot be reached; Pattern & Difficulty must keep hazards off it | Coarse positioning: one ball width per 1.76 degrees of wrist, dead zone 0.85 widths; above PI the two ends overlap and add nothing |
| `BALL_LAG_TAU` | 0.06 s | 0 to 0.12 | The "slight inertia" and the software response time (F1, F5b): 63% response 0.118 s with Tilt Input's filter | Mechanical, passes sensor noise through | Mushy, breaks the 0.13 s software budget and Tube Track F9 above 0.12 |
| `OMEGA_MAX` | 3.0 rad/s | 2.75 to 4.0 | The fastest the ball can turn: `T_DODGE_180` 1.064 s (F5a), the sweep per step (0.3 rad at `DT_MAX`) | A 180 degree dodge is too slow, F9's `T_VIS_MIN` fails (below 2.75 at `tau` 0.06) | Dodges too easy, sweep per step 0.4 rad, harder contact tests |
| `MAPPING_MODE` | POSITION | POSITION, RATE | The steer-to-motion mapping (Core Rules 4 and 6); RATE is forced for `input_source` `FALLBACK` | | RATE drifts on a neutral error (F3); it is the spike's comparison, not an MVP default |
| `V_START` | 10 u/s | 6 to 14 | Speed at the start of a run (F2); 12.5 ball widths/s | Dull start | A beginner cannot survive the first seconds |
| `V_MAX` | 25 u/s | 18 to 30 | Speed ceiling (F2) and Tube Track's F3, F5, F9 | Little sense of rush | Tube Track `T_vis` under 1.5 s (1.52 s at 25 with default segments), seam frequency above its cap |
| `T_RAMP` | 90 s | 0 (sentinel: `V_MAX` from the start) or 45 to 240 | How fast speed rises (F2): 0.167 u/s^2 at the defaults | A value between 0 (exclusive) and 45 clamps to 45; below 45 the ramp is steep and the player never adapts | No ramp; most runs never reach `V_MAX`; `s` reaches Tube Track's 16384 limit later |
| `BALL_DIAMETER` (`D`) | 0.8 u | 0.6 to 1.0 | The ball and its ring radius `R + D/2`; Tube Track's lane capacity (about 26 widths at `R` 3.0) and every contact test | Hard to read, gaps feel too loose | Gaps become infeasible, Tube Track F6 capacity drops |

**Not knobs (fixed constants):** the snap threshold 1e-6 rad, the `alpha` guard 1e-4 s, the 2 PI re-base, the sign convention (`steer` > 0 increases `theta`), the exact-integral speed form. **Verification targets, not knobs:** software response at most 0.13 s and end to end at most 0.20 s at 60 Hz (F5b), checked in the spike.

**Knob interactions**
- `STEER_ARC` and Tilt Input's `TILT_FULL_SCALE` (and `DEAD_ZONE`, `CURVE_EXP` 1) form one resolution surface (F5c): the spike tunes them together, keeping reach (`STEER_ARC` PI) and raising `TILT_FULL_SCALE` first (35 degrees gives 5.37 degrees per degree).
- `OMEGA_MAX` and `BALL_LAG_TAU` together set `T_DODGE_180`; F9 stays valid while it is at most 1.167 s (`OMEGA_MAX` 2.75 or more at `tau` 0.06, or `tau` 0.12 or less at 3.0). `BALL_LAG_TAU` and Tilt Input's `FILTER_TAU` add in series to the latency budget.
- `V_MAX` and Tube Track: `T_vis` needs `F_read >= 1.5 * V_MAX + d_cam`; `V_MAX` and `T_RAMP` decide when `s` reaches `S_PRECISION_LIMIT` (682 s at 10 / 25 / 90).
- `V_START` and `T_RAMP` set the early-run difficulty that Pattern & Difficulty designs its telegraphs against (it reads the curve).
- `BALL_DIAMETER` changes Tube Track's lane capacity and every gap width; a change needs Tube Track F6 re-checked.

**Sources of truth elsewhere:** `DT_MAX` (Run State), `FILTER_TAU`, `DEAD_ZONE`, `TILT_FULL_SCALE`, `CURVE_EXP`, `sensitivity` (Tilt Input), `S_PRECISION_LIMIT`, `TUBE_RADIUS` (Tube Track), the camera's lag (Camera).

## Visual/Audio Requirements

**Ball body.** A solid, smooth-shaded sphere, the only solid sphere in the game (art bible: "It is the only solid sphere in the game"), with a permanent cool-white rim; chroma 0.08-0.12, contrast against the tube at least 4:1 ("Ball and pickup chroma" and "Hazard / tube contrast", art bible Numbers). No angular detail, ever, and no warm hue: this is the readability contract against "danger is the loudest thing on screen... everything else stays a step quieter" (art bible §1) and "shape before color... obstacle types must be recognizable by silhouette alone" (§1, principle 2) — the ball must never be mistaken for a hazard.

**Speed (F2, `V_START` to `V_MAX`).** The ball carries no speed VFX of its own (no stretch, no trail that scales with `speed`). Readability of speed is carried elsewhere: the tube's seam frequency and the environment's high-speed treatment (cool-white edge streaks, a chroma drop, capped FOV widening; art bible's mood table, "Run, high speed") and Juice & Feedback's cues. Giving the ball its own competing speed cue risks muddying the hazard-loudest hierarchy. **This is an open decision, not a closed one** (Open Questions): revisit once Juice & Feedback and Environment & Theming exist, in case the ball needs a light cue (for example a spin-rate change, still in the cool/white channel, keeping the 4:1 contrast floor) before those systems are built.

**Lag and weight (Core Rule 4).** No separate weight VFX. The positional lag of F1 is the entire visual carrier: the ball visibly trailing its target as it eases in reads as weight, with no added geometry or particles.

**Restart glide (Edge Cases: `steer` not 0 at run start, up to 1.05 s).** No extra VFX; the glide is plain continuous motion under F1, at the same visual weight as ordinary steering, so it does not read as a correction.

**Resume re-anchor.** No flash, fade or pop. **If a run resumes**: the ball renders every frame at a visually continuous position (Core Rule 5 guarantees the target never jumps), so no visual event marks it; a resume indicator (the countdown) is a UI Requirements concern, not this one.

**RATE-mode fallback (Core Rule 6).** No change to the ball's model, skin or rim: skins "may not change silhouette or scale" (art bible §3a), and a different look here would wrongly imply RATE mode is a different hazard-risk state. **If** the touch fallback needs an affordance (highlighting the held half-screen): that is a Tilt Input or UI Requirements concern.

**Rolling animation.** Stateless and view-layer only; Core Rule 8's published contract (`theta`, `s`, `speed`, `omega`, `radius`, no rotation state) does not change. The view layer derives cosmetic spin every frame: a forward roll rate of `speed / radius` (rad/s, roll-without-slip along the direction of travel) driven by the change in `s`, and a small, capped lean or bank driven by `omega` to sell the turn. Both are continuous functions of already-published values, so there is no jitter risk and no new consumer coupling. `radius` = 0.4 and the ring radius `R + D/2` = 3.4 are the only scale constants this needs.

**Applicable art bible principles.** "Danger is the loudest thing on screen" (§1); "shape before color... silhouette alone" (§1, principle 2); "juice never speaks in danger's voice... near-miss and speed effects use the ball's cool/white channel and stay off the hazard" (§1, principle 3) governs any future skin or lag-echo; skin constraints in §3a (no silhouette or scale change, no red or black striping, the cool-white rim is kept on every skin); the numeric floors in the Numbers table (ball chroma 0.08-0.12, ball/tube contrast at least 4:1) bind any skin variant Game Modes exposes through `BallConfig`.

**Out of scope here (owned elsewhere, per Core Rule 1 and Interactions).** Juice & Feedback owns the near-miss rim pulse, high-speed screen edge streaks, the hit grey-out, hitstop and white flash, the death burst and the personal-best sweep; Ball Movement only guarantees the continuous `theta`, `s`, `speed` and `omega` those triggers consume, and never designs their timing. Camera owns its own lag and following (Interactions table). Any screen shake, if ever added, is Juice & Feedback's effect applied to the render transform, not a Ball Movement state (art bible: "no screen shake... any shake must be tiny and carried by the ball, not the tube"). Near-Miss Detection is a separate, unauthored system that reads the published state and nothing more.

**Audio.** None of its own; audio cues for near-misses, hits and speed are Juice & Feedback and Audio Director concerns, reading the same published state.

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved and this GDD passes review, run `/asset-spec system:ball-movement` to produce the per-asset visual description, dimensions and generation prompt for the ball model.

## UI Requirements

No player-facing UI of its own; the ball is not a menu, HUD or settings surface. Requests to other systems:

1. **HUD:** none required by this system. If Pattern & Difficulty or Scoring wants a speed readout, it reads `speed` directly; this GDD does not request one.
2. **Settings & Accessibility:** if the on-device spike (BM-5) keeps RATE as an alternative rather than replacing POSITION, `MAPPING_MODE` could become a player-facing control-scheme setting; not requested for the MVP (Open Questions).
3. **Menus & Screen Flow:** none.

No UX Flag: there is no screen or HUD element of its own to specify.

## Acceptance Criteria

**Targets:** **[M]** `BallMath` static pure functions (F1 step, F2 `speed` and `S`, `wrap`, F5); **[C]** `BallCore` with an injected `dt_max` and a recording `log_sink` (no rate limiter); **[K]** `BallConfig.validated(log_sink)`; **[L]** CI lint; **[I]** integration; **[V]** device or playtest. Tests live in `tests/unit/ball_movement/` and `tests/integration/ball_movement/`, named `ball_movement_[feature]_test.gd`. **Fixture:** `make_ball_fixture()` returns `STEER_ARC` PI, `BALL_LAG_TAU` 0.06, `OMEGA_MAX` 3.0, `MAPPING_MODE` POSITION, `V_START` 10, `V_MAX` 25, `T_RAMP` 90, `BALL_DIAMETER` 0.8; `make_core(cfg, dt_max=0.1)` and `make_sink()` are companions. Steer tables live in one constants file; pseudo-random tables use a fixed LCG. Because the shipped defaults equal the fixture, an AC that depends on a knob uses an asymmetric override (for example `tau` 0.03). Exact `==` for log codes, counts, snapped poses and integers; 1e-6 for other floats; 0.05 rad only for the cross-rate sine. Each table row is its own test with a fresh core. Poses are reached only by driving `step()`; `phi`, `phi_anchor`, `w` and `t_run` are test-readable getters. Oracles were recomputed in a Node reference simulation.

**Logic, BLOCKING**
- **AC-1 [C]** (R1, R9) A fresh core has `theta`, `theta_prev`, `s`, `s_prev`, `t_run`, `omega`, `phi_anchor`, `w` and the held steer at 0, `speed` 10 and `radius` 0.4. After 100 mixed steps, an armed re-base and a latched mode, `reset()` equals a fresh core field for field (the latch cleared, the re-base disarmed).
- **AC-2 [C]** (R2, R10) After a moving step (1/60, steer 0.5), one row per `dt_eff` in {0, -0.001, -inf, NaN, +inf}: `theta`, `s`, `speed`, `t_run` unchanged; `theta_prev == theta`, `s_prev == s`, `omega == 0`. 0 logs nothing; each other value logs exactly one `BAD_DT` (+inf is `BAD_DT`, not `DT_OVER_MAX`); a no-op step with steer NaN logs no `BAD_STEER`.
- **AC-3 [C]** (edge) `dt_max` 0.1, steer 1, from rest: `dt` 0.1 gives no log, `phi` 0.3, `omega` 3.0, `s` = S(0.1) = 1.0008333; `dt` 0.5 gives the identical state plus one `DT_OVER_MAX`; `dt` 1e-9 still moves the ball.
- **AC-4 [C]** (R10) 10 steps of 1/60, then 300 steps of `dt` 0 with changing steer, then 10 steps of 1/60: pose, `t_run` and `speed` are bit-identical across the zeros and the moving frames continue as if they were absent; `on_resumed()` then `dt` 0 moves nothing and does not consume the re-base.
- **AC-5 [M]** (F1) `(e, dt, tau)` gives `step`: (1.0, 1/60, 0.06) 0.05; (0.1, 1/60, 0.06) 0.0242535; (-1.0, ...) -0.05; `tau` 0: `e` 0.03 gives 0.03, `e` 0.1 gives 0.05; guard: `dt` 1e-5 with `tau` 9.99e-5 gives `alpha` 1 and `tau` 1e-4 gives 0.095163; snap: a residual of 9.9e-7 gives `phi == target` and 1.01e-6 does not.
- **AC-6 [C]** (R3) Steer +0.5 for 60 steps gives `theta` strictly increasing and > 0; steer -0.5 gives the exact negation.
- **AC-7 [C]** (R4, F1) From rest at 60 Hz with steer 1, frame 1 gives `phi` 0.05 and `omega` 3.0; over a 10 s sweep table `|step| <= OMEGA_MAX * dt` every step, no overshoot, no reversal.
- **AC-8 [C]** (F1) Steer to 1: the first frame with `|e| <= 0.05` is 32 / 64 / 128 at 30 / 60 / 120 Hz (frames 31 / 63 / 127 are above); a 0.1 rad target held 0.1 s gives `phi` 0.0811124 at all three rates.
- **AC-9 [C]** (F1, ADVISORY tolerance) Steer = (0.5 / PI) * sin(2 PI t_k) with `t_k` the end-of-frame time, 5 s at 30 / 60 / 120 Hz: at common instants (multiples of 1/30 s) the maximum pairwise `|delta phi|` is at most 0.05 (0.0324 measured; 0.0410 with start-of-frame sampling, so the convention is frozen). Mutation: a step with a fixed `alpha` per frame must fail AC-8 and AC-9.
- **AC-10 [C]** (R5) After `reset()`, steer 0.5 from the first moving step: frame 1 `theta` 0.05, monotone, per-frame move at most 0.05, `phi == PI/2` exactly at frame 72; after a prior run with a non-zero anchor and a `reset()`, `phi_anchor == 0` (no re-base at reset).
- **AC-11 [C]** (R5) Steer 1 to snap (`phi` PI), then `on_resumed()`, `step(0, 0.3)` (no re-base), `step(1/60, 0.5)`: `phi_anchor == PI/2`, `phi` unchanged, `omega == 0`; the next step uses that anchor and the re-base does not repeat until another `on_resumed()`; `on_resumed()` then `reset()` then a step with steer 0.5 targets `STEER_ARC * 0.5` (no re-base at reset).
- **AC-12 [C]** (R5) Steer 1 to snap, then three times {`on_resumed()`, step 0.5, steer 1 to snap}: after chain 1 `phi` is 3 PI / 2, after chain 2 `phi` is 2 PI (1e-12) with no shift (the boundary `|phi| > 2 PI`); in chain 3 the shift fires on the first frame past 2 PI, `theta` equals `wrap(unshifted)` to 1e-9, `omega` is computed before the shift, and `phi_anchor - phi` is unchanged; end state `theta` 1.5707963, `phi_anchor` -PI/2 (1e-9).
- **AC-13 [C]** (edge) Steer +1 and -1 each end with `theta == -PI` and `theta` stays in `[-PI, PI)`; seam frame: steer 0.95 to snap, `on_resumed()`, step 0.5, then steer 1: the 4th step crosses with `theta_prev` 3.134513, `theta` -3.098672, `omega` 3.0 (1e-6) and `wrap(theta - theta_prev) / dt == omega`; the mirror gives -3.0.
- **AC-14 [C]** (F3) RATE: steer 1 from rest at 1/60 gives `w` 0.727605 and `phi` 0.0063437 (1e-7); 0.1 s at 30 / 60 / 120 Hz gives 0.153998 (1e-6); steer 1 for 1 s then 0 coasts 0.18 rad (+-1e-3); `on_resumed()` sets `w` 0; `tau` 0 gives `w = OMEGA_MAX * steer`; a held 0.5 ends at 1.5 rad/s.
- **AC-15 [C]** (R6) Mode truth table with the discriminator 120 steps of steer 0.5 then 240 of 0: (POSITION, SENSOR) returns `theta` to exactly 0; (POSITION, FALLBACK), (RATE, SENSOR) and (RATE, FALLBACK) leave it non-zero (RATE).
- **AC-16 [C]** (R6) The mode latches on the first step with `dt_eff > 0` after `reset()`: a no-op step carrying FALLBACK does not latch (no-op(FALLBACK), moving(SENSOR) gives POSITION); a mid-run flip is ignored either way and `on_resumed()` does not re-latch; `reset()` re-arms it (FALLBACK run, `reset()`, SENSOR run gives POSITION); any value other than FALLBACK counts as SENSOR.
- **AC-17 [C]** (R2, edge) `valid` false with steer 0 after an accepted 0.5 holds the target for 60 steps, no log; steer NaN, +inf and -inf each hold the last steer with one `BAD_STEER`; steer 5 and -5 give a trajectory equal to steer 1 and -1, no log; NaN on the first moving step holds 0; `valid` false with NaN logs nothing.
- **AC-18 [C]** (R13) The log codes are exactly `BAD_DT`, `DT_OVER_MAX`, `BAD_STEER`, `KNOB_CLAMPED`, all error level; a 60-frame NaN stream gives 60 lines (the limiter is the driver's); the sine run and the AC-22 run give zero lines.
- **AC-19 [K]** (R13) One row per knob, just outside gives one `KNOB_CLAMPED` and the boundary gives none: `STEER_ARC` 2.0 to 2.09 and 3.2 to PI; `tau` -0.01 to 0 and 0.13 to 0.12; `OMEGA_MAX` 2.7 to 2.75 and 4.1 to 4.0; `V_START` 5.9 to 6 and 14.1 to 14; `V_MAX` 17.9 to 18 and 30.1 to 30; `T_RAMP` 44 to 45 and 241 to 240, while `T_RAMP` 0 or less is accepted with no log; `D` 0.59 to 0.6 and 1.01 to 1.0; NaN or infinite on any knob takes the default with one line; `MAPPING_MODE` 7 becomes POSITION with one line; an injected `dt_max` of 0, negative or NaN becomes 0.1 with one line; validation returns a copy and leaves the shipped resource unchanged.
- **AC-20 [M]** (F2) `S(0, 45, 90, 120)` = 0, 618.75, 1575, 2325; `speed` = 10, 17.5, 25, 25; `S(682.36) == 16384` (1e-9); continuity at `T_RAMP`; `T_RAMP` 0 or less gives `speed` 25 from `t` 0 and `S(t) = 25 t`; `speed` is monotone over 0 to 200 s.
- **AC-21 [C]** (R7) `s` after 45 / 90 / 120 s is 618.75 / 1575 / 2325 (1e-6) at 30, 60 and 120 Hz and `speed` 17.5 / 25 / 25; the first 1/60 step gives `s` 0.1666898 and `speed` 10.0027778; `s` is equal across a steer table of +1, -1, 0, NaN and `valid` false (speed and distance ignore steer). Mutation: a left-Riemann `speed * dt` under-counts 0.125 u at 90 s and must fail.
- **AC-22 [C]** (F6) 100,000 frames at 1/60 with a varied steer table: `|s - S(t_run)| <= 1e-6` and `t_run` equals an independently summed `dt`.
- **AC-23 [C]** (R8) `theta_prev`, `s_prev` at step k equal `theta`, `s` at step k-1 over 300 steps including a seam; at `dt` 0.1 from `t` >= 90, `|s - s_prev|` = 2.5 (1e-9) and `|wrap(delta theta)| <= 0.3`; `radius` 0.4; `omega` at `dt` 0 is 0; `omega` on a snap frame is `(phi_after_snap - phi_before) / dt` (1e-4).
- **AC-24 [C]** (R12) Two fresh cores fed the same 1000-step table (NaN, invalid, `dt` 0, resumes, resets) are bit-identical after every step; a third core interleaved changes nothing (no shared static state).
- **AC-25 [L]** (R11 to R13) Fixture self-tests (a violation reports file and line, one in a comment passes) over `BallCore`, `BallConfig`, `BallMath`: each extends `RefCounted` (`Resource` for the config) and contains none of `Node`, `CollisionObject3D`, `CharacterBody3D`, `Area3D`, `RayCast3D`, `ShapeCast3D`, `PhysicsServer`, `hit_reported`, `request_`, `RunState`, Tilt or Tube Track type references (except the shared static `wrap_angle`), `Input.`, `Engine.`, `Time.`, `OS.`, `DisplayServer.`, `get_tree`, the process-delta getters, `_process`, `_physics_process`, `randi`, `randf`, `randomize`, `RandomNumberGenerator`; Tube Track AC-25's regex (`position.z`, `global_position.z`, `global_transform.origin`) also runs over the ball driver and view scripts (this epic adds the paths).
- **AC-26 [I/static], deferred** (R11, Tube Track AC-24) the instantiated ball scene has no `CollisionObject3D`; owner: the ball view story.
- **AC-27 [C + V]** (R9) 1000 `reset()` calls leave `OBJECT_COUNT` unchanged and the reset body has no loop, `.new()` or `load(` (lint); the device part [V], ADVISORY: the maximum over 1000 calls is at most 1 ms on the mid-tier Android target.
- **AC-28 [C]** (R13, Config smoke, ADVISORY) the shipped `BallConfig.tres` equals the Tuning Knobs table and validates with zero `KNOB_CLAMPED`.

**Integration [I]** (deferred ACs never count toward Done; blocked-by stated)
- **AC-29 [I]** (Tilt AC-40 gate, **the epic cannot close without it**; owner: the epic's "sign and driver order" story; blocked by the TiltCore story, the Run State core story and the game-loop ADR with its driver) A test-only driver assembles the real order (tilt poll, flush, `tick`, ball step) with real TiltCore, Run State core and BallCore: with the right edge lowered 20 degrees for 60 ticks after capture, `steer` > 0, `theta` strictly increases and Tube Track's `P(theta, s, h).x` increases; the left edge mirrors it. It proves neither the production driver's order nor the phone's physical sign (the loop story and Tilt V-1).
- **AC-30 [I], deferred** (Tilt AC-27; owner: the loop story, blocked by the game-loop ADR) exactly 2 polls between a capture and the first `dt_eff > 0` tick; a spy records the order poll, flush, tick, ball step, consumers, `advance(s)`, mesh, which also proves consumers read after `step()`.
- **AC-31 [I]** (R2, R10, F6; blocked by the Run State core) over a scripted Running, Hit, Paused, Resuming and settling-tick sequence: `theta`, `s`, `t_run` are bit-identical across every `dt_eff == 0` tick with previous equal to current; nothing moves on the first tick after `run_started` and `run_resumed`; `t_run == Run State run_time` after every tick.
- **AC-32 [I], deferred until the spike** (Tilt AC-41 companion) recorded V-2 rest traces through TiltCore and BallCore: POSITION `max |theta|` at most 0.1 rad over 30 s and RATE within the F3 drift bound (thresholds frozen after V-2).

**Device and playtest checks** (evidence in `production/qa/evidence/ball-movement/bm-N.md`: device, build, date, raw log, result; mid-tier 60 Hz Android target, an iPhone for BM-1 where feasible)
- **BM-1 Latency** (BLOCKING for first playable, signed by qa-lead and technical-director): software, a synthetic 10 degree gravity step through the adapter with per-frame `theta` logged, time to 63% interpolated: median of 20 at most 0.13 s at 60 Hz (nominal 0.118 s); end to end, a 240 fps camera on a jig, median of 20 at most 0.20 s and worst at most 0.25 s; 30 Hz is recorded, not failed.
- **BM-2 Dodge 180** (BLOCKING): a synthetic steer step reaches `|e| <= 0.05` in 1.0667 s +-1 frame at 60 Hz; at least 3 testers, 20 cued 180 degree turns at `V_MAX`: cue to `|e| <= 0.05` p90 at most 1.5 s and median at most 1.40 s (a miss is a tuning finding for `OMEGA_MAX` and `tau`).
- **BM-3 No jolt at start and resume** (BLOCKING): 10 restarts and 10 resumes held still and 10 of each with a 10 degree held tilt; still: `|theta|` stays 0 for the first 1 s; tilted: per-frame move at most 0.05 rad (a glide); zero unasked movements reported (10 of 10 supports only p >= 0.74 at 95%).
- **BM-4 Resolution feel** (ADVISORY): `STEER_ARC` PI with `TILT_FULL_SCALE` 25 versus 35, counterbalanced, 5 testers x 10 trials on a 2.5-width gap hold and a 180 degree reach; exploratory, no p value.
- **BM-5 POSITION versus RATE** (Tilt Open Question 10; blocks locking the default, not the first playable): 10 testers, crossover, counterbalanced, a fixed 20-gate course, 3 runs per mode; an exact one-sided binomial gives 9 of 10 p = 0.0107 and 8 of 10 p = 0.0547; switch to RATE only if at least 9 of 10 prefer it and it clears no fewer gates, otherwise keep POSITION as a design default, not a statistical claim.
- **BM-6 Speed ramp** (ADVISORY; blocked by Pattern & Difficulty hazards): 10 novice runs; provisional pass: at least 7 of 10 reach `t_run` 30 s (15 u/s), the mean "too fast" rating at most 2 of 5, `speed` at death logged.

**Gate policy.** AC-1..24 are Logic, BLOCKING. AC-25 is a CI-lint gate whose scripts and self-tests exist before the first Ball Movement story is Done. AC-27's static part is BLOCKING; AC-28 is ADVISORY. AC-29 is BLOCKING for the epic; AC-31 is BLOCKING for its story once the harness exists; AC-26, AC-30 and AC-32 are deferred. BM-1 to BM-3 are the first-playable gate (qa-lead and technical-director; the coding-standards table rates Visual/Feel ADVISORY, so this needs producer ratification), BM-4 and BM-6 are ADVISORY, BM-5 blocks locking the default. Owners: the epic's stories (AC-29, AC-30), Run State (`run_time` conformance), Tube Track (the AC-25 script), Tilt Input (AC-41 fixtures).

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | **On-device spike**: `TILT_FULL_SCALE`/`STEER_ARC` joint resolution tuning (F5c), `BALL_LAG_TAU`/`OMEGA_MAX` feel (BM-1, BM-2), no-jolt check (BM-3), `V_START`/`T_RAMP` novice playtests (BM-6). BM-1..BM-3 block the first playable | user (needs phones), game-designer | Before the first playable |
| 2 | **POSITION versus RATE** (Tilt Input Open Question 10): BM-5's crossover protocol decides whether RATE ever becomes the shipped default; POSITION ships for the first playable regardless | user, game-designer | After the spike |
| 3 | Whether the ball needs its own speed cue (a light, cool/white-channel signal such as a capped spin-rate change) before Juice & Feedback and Environment & Theming exist, or whether the environment carries all speed readability (Visual/Audio Requirements) | art-director, technical-artist | When Juice & Feedback or Environment & Theming is authored |
| 4 | **Collision ownership** (provisional: Obstacle System detects, reading the published state with previous values for a swept test) needs the collision ADR, including whether a `DT_MAX * V_MAX` = 2.5 u step can tunnel through the thinnest hazard | technical-director, godot-specialist | Technical Setup |
| 5 | **Game-loop ADR**: which loop calls `step()` and Tube Track's `advance(s)` (Tube Track Open Question 4), and the composition root that wires the driver, Tilt Input and Run State | technical-director | Technical Setup |
| 6 | **`S_PRECISION_LIMIT` at 682 s**: at the default ramp the ball reaches Tube Track's `s` limit (16384) in about 11 minutes 22 seconds; needs a run cap, an `s` re-base, or a documented non-issue (most runs end well before this) | technical-director, Tube Track, Run State | Technical Setup |
| 7 | **Full-lock reversal**: at `STEER_ARC` = PI, `steer` = +1 and -1 are the same tube point, so a full reversal takes a full lap (2.09 s); Pattern & Difficulty must treat this as the worst-case dodge, not assume a direct half-turn is always faster | Pattern & Difficulty GDD | When authored |
| 8 | **Angular-acceleration limit** (`ALPHA_MAX`): the capped first-order lag jumps `omega` to `OMEGA_MAX` in one frame on a large tilt, which can read as a snap rather than weight; deferred as a spike option, not adopted now | game-designer, systems-designer | After the spike, if BM-2/BM-3 show a problem |
| 9 | **Cross-file edits pending approval**: `tube-track.md` Open Question 12 (confirm `V_MAX` = 25, re-point the `v_max` registry source here) and its F9 derivation (consume `T_DODGE_180` = 1.064 s and this GDD's latency instead of the 1.05 s assumption, margin 0.10 s not 0.15 s); `tilt-input.md` Open Questions 10 and 20 (mapping decided: position, anchored, RATE for `FALLBACK`; `CURVE_EXP`/`TILT_FULL_SCALE` stay in Tilt Input as one resolution surface with `STEER_ARC`; the latency budget is F5b) and its AC-27, AC-40, AC-41 owner notes; `run-state-restart.md` Open Question 9 (`DT_MAX` stays with Run State) and Open Question 3 (collision owner answered provisionally); `systems-index.md` row 2 status and the new dependency edge (Obstacle System depends on Ball Movement, row 4) | this GDD's follow-up | End of this session |
| 10 | Whether `MAPPING_MODE` should become a player-facing Settings toggle if the spike keeps both modes viable, rather than a single locked default | ux-designer, Settings & Accessibility GDD | When authored, after Open Question 2 |
| 11 | Game Modes (Alpha): a heavier or slippery ball changes `BALL_LAG_TAU` and `OMEGA_MAX` through `BallConfig`; no new mechanic is needed, but the safe ranges above may not cover those modes' intended extremes | game-designer | When Game Modes is authored |
| 12 | Test framework GUT versus gdUnit4 (shared with Tilt Input and Platform Services); `tools/ci/` script language for the AC-25 lint | `/test-setup`, technical-director | Technical Setup |
