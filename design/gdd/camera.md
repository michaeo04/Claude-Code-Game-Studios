# Camera

> **Status**: Designed (2026-09-29), pending independent `/design-review`
> **Author**: user + agents
> **Last Updated**: 2026-09-29
> **Implements Pillar**: Pillar 1 (Instant Readability) — primary, the camera's own occlusion arc defines what "in view" means for every other system; Pillar 3 (Juice on Every Near-Miss) — secondary, through the FOV-punch hook.

## Overview

Camera owns the one thing every frame of the game passes through: where the player's eye sits relative to the ball, and what that vantage point does and doesn't let them see. Every frame it derives a transform from Ball Movement's current pose (`theta`, `s`) with a first-order lag — Ball Movement moves, the camera catches up, never instantly — orbiting around Tube Track's axis (`R`) and rolling with that orbit so the tube itself stays static and centered on screen while only the ball and hazards visibly travel around it. This specific model isn't a guess: it's what the concept prototype tested three variants of and shipped (`prototypes/ball-in-tube-movement-concept/REPORT.md`, PROCEED verdict) — a camera that orbits with the ball but does not roll made the tester dizzy (the ball pinned to screen center, the whole tube spinning), and game-concept.md's own original "does NOT roll" description was itself the assumption that build disproved. Camera decides one more thing besides how it moves: how far around the tube's far side is hidden by the geometry the camera itself can see — `VISIBLE_ARC_HALF_WIDTH`, the exact value Obstacle System's own hidden-side fairness rule and Tube Track's own visibility budget (F9) have both been carrying as an unfilled placeholder, waiting on this GDD. It decides nothing about what a hazard looks like (Obstacle System / the art bible), how fast the ball moves (Ball Movement), or what near-miss/hit juice looks like (Juice & Feedback, though it reads Camera's own FOV-punch hook) — it owns exactly the player's point of view and what that point of view can and cannot see.

## Player Fantasy

**The fantasy.** I'm not watching the tube move — I'm moving around it. The world holds still so I can read it, and every hazard I dodge, I dodge because I saw it, not because the camera got in my way or out of it.

**What the player feels.**
- **The world holds still so I can read it.** The tube itself never lurches, tilts, or spins on its own — only I move around it, exactly what the concept prototype validated after its first camera model made the tester dizzy (`prototypes/ball-in-tube-movement-concept/REPORT.md`).
- **My reactions feel like mine, not the camera's.** The camera catches up to me with a small, consistent lag — it never leads my hand, never fights it, never resets or snaps in a way that could be blamed for a death (*Pillar 2: "every death traces back to the player's own choice or reaction, never to randomness or bad luck"*).
- **The surprise on the far side is honest, not cheap.** When something appears from behind the tube, it's because I hadn't looked yet — not because the game hid it somewhere no amount of looking would have found.

**Feelings to avoid.** Dizziness or disorientation (the literal v1 camera model the prototype disproved); a camera that feels laggy, sluggish, or like it's fighting the player's own tilt; an occlusion arc so wide it turns a "fair surprise" into an unfair one, or so narrow that the far-side surprise the prototype's own tester liked disappears entirely; any camera behavior a player could point to as the actual cause of a death.

**Serves the pillars.** *Pillar 1, Instant Readability* — primary: the camera's own occlusion arc is what "in view" and "hidden" literally mean for every other system. *Pillar 3, Juice on Every Near-Miss* — the FOV-punch hook this system exposes.

## Detailed Design

### Core Rules

1. **Orbit, first-order lag, and roll — the validated model, not a fresh design.** The camera's own orbit angle `phi_cam` around Tube Track's axis lags the ball's angle `theta` through a first-order lag (the same math family as Ball Movement's own `BALL_LAG_TAU` lag, Ball Movement F1), governed by this system's own `CAMERA_LAG_TAU` (Formulas F1). **Corrected value, not the prototype's literal number:** the concept prototype's own `CAMERA_FOLLOW_SPEED` = 3.0 was verified, against the prototype's actual source (`prototypes/ball-in-tube-movement-concept/main.gd`), to already be a *rate* (it sits where `1/tau` sits in Ball Movement's own `alpha` formula), not a time constant itself — so `CAMERA_LAG_TAU` ships as its reciprocal, `≈0.333` s, not `3.0`. **No `OMEGA_MAX`-style hard rate cap** — unlike Ball Movement's own lag, nothing about fairness depends on a worst-case camera catch-up time, and the lag is self-limiting in practice because Camera freezes on every `dt_eff` = 0 tick exactly when Ball Movement also freezes (Rule 5) and snaps instantly on `run_reset`, so `phi_cam` can never drift arbitrarily far behind `theta` between moving frames; this safety is a consequence of Rule 5's freeze-together contract, not an inherent property of unbounded lag, and should not be assumed to hold if Rule 5 is ever revised independently. The camera's own "up" vector points radially outward from the tube axis at the camera's **own** lagged angle `phi_cam`, not the ball's `theta` — this is what makes the camera roll with its own orbit and is the specific fix the concept prototype found necessary (`prototypes/ball-in-tube-movement-concept/REPORT.md`): a camera that orbits with the ball but keeps a fixed world-up made the tube visibly swing and tilt on screen; rolling with the orbit keeps the tube static and centered instead.
2. **Camera position is a fixed radius and back-offset from the ball — `d_cam` is a derived consequence, never an independently chosen value.** The camera sits on its own circle around the tube axis at `CAMERA_RADIUS` (a fixed distance from the axis, outside the ball's own orbit radius `R + D/2`), at its own lagged angle `phi_cam` (Rule 1), offset backward along `s` from the ball's current position by `CAMERA_BACK_DISTANCE`. `camera_distance`/`d_cam` — the straight-line distance from the camera eye to the ball, which Tube Track's own F9 visibility budget already reads as an external configuration value — is computed from `CAMERA_RADIUS`, `CAMERA_BACK_DISTANCE`, and the current angular lag between `phi_cam` and `theta` (Formulas F1); it is never a second, independently-tuned number that could silently disagree with the geometry that actually produces it.
3. **Look-at target: ahead of the ball, on the tube axis.** The camera looks at a point on the tube axis at `s_ball + CAMERA_LOOK_AHEAD`, not at the ball itself — this points the camera slightly toward where the ball is heading rather than exactly at its current position, matching the concept prototype's own validated framing.
4. **`VISIBLE_ARC_HALF_WIDTH` is derived from this camera's own geometry, not chosen independently of it — and depends on less than it might seem to.** Because the tube's own curved surface occludes part of its own far side from any external vantage point, the angular half-width (from `THETA_REF`, Obstacle System's own reference point) within which the tube's own circumference is guaranteed unoccluded by its own curvature is a pure function of `CAMERA_RADIUS` and `TUBE_RADIUS` alone (Formulas F3) — proven, not assumed, to be independent of `CAMERA_BACK_DISTANCE` and of the camera's live lagged angle `phi_cam` (a straight, axis-aligned tube's tangent-plane equation has no axial term), and independent of field of view (FOV clips the render frustum; it does not change what the tube's own curvature occludes). This closes Obstacle System's own Open Question 7 and Tube Track's own placeholder for this value, with one honest caveat carried into Open Questions: the arc's *magnitude* is exact and fixed, but its *center* is the camera's own live `phi_cam(t)`, not a fixed world angle — `THETA_REF` = 0 is a near-neutral proxy anchor, the same kind of proxy Obstacle System's own F4 already admits using for `T_reveal`, not a literal live boundary.
5. **Instant snap on reset; frozen otherwise.** On `run_reset`, the camera's pose snaps immediately to directly behind the ball's start pose — no lag, no transition — matching Run State's own Interactions table ("`run_reset` cuts to the start pose") and the same "no jolt at the moment that matters" pattern Ball Movement's own Rule 9 uses for its own reset. In Hit, Paused, Resuming, and every settling tick (`dt_eff` = 0), the camera holds its exact last pose — it is inert wherever Ball Movement itself is inert (Ball Movement Rule 10), needing no phase-awareness of its own beyond reading the same `dt_eff` = 0 signal every other system already reads.
6. **No collision of its own; never clips through tube geometry, by construction.** The camera owns no physics body and performs no collision test — `CAMERA_RADIUS` is fixed strictly greater than the tube's own outer radius (`TUBE_RADIUS`), so the camera eye is always outside the tube mesh for any legal configuration; this is a load-bearing consequence of Rule 2's own placement rule, not a runtime check.
7. **An FOV-punch hook, mechanism and ease shape only — Juice & Feedback owns the values.** Camera exposes one call, `apply_fov_punch(amount, duration)`, that additively and temporarily widens the camera's field of view and eases linearly back to baseline over `duration` (Formula F5) — the mechanism this system owns. It decides nothing about when a punch fires, or how large `amount`/`duration` are for a near-miss versus any other trigger; Juice & Feedback (once authored) reads `near_miss_detected` and drives this call with its own tuned values, mirroring the same trigger-vs-presentation boundary every other system in this project draws against Juice & Feedback. A new call always replaces whatever ease is already in progress (Edge Cases) — never additive stacking.
8. **No side effects; read-only inputs.** Camera sends no requests to Ball Movement, Tube Track, or Run State & Restart — it only reads their published state and events. It owns no gameplay logic and makes no judgment about hazards, score, or difficulty.
9. **Deterministic.** Given the same sequence of `theta` values and `dt_eff` steps, the camera's own lagged orbit angle, position, and derived `d_cam` are always the same — the same first-order-lag determinism guarantee Ball Movement's own F1 already relies on for its analogous lag.
10. **`CAMERA_RADIUS` must clear `TUBE_RADIUS` by a real margin, checked at config load, not just "greater than."** Formula F3 shows `VISIBLE_ARC_HALF_WIDTH` approaches 0 as `CAMERA_RADIUS` approaches `TUBE_RADIUS` — a config that is technically legal under Rule 6's own bare inequality could still leave almost nothing of the tube visible at all. `CAMERA_RADIUS` `<` `TUBE_RADIUS + CAMERA_RADIUS_MARGIN_MIN` is rejected at content-load time with `CAMERA_RADIUS_TOO_CLOSE`, naming both values — a correctness floor on top of Rule 6's own structural guarantee, not a replacement for it.
11. **Structure.** `CameraMath` is a stateless static class holding the pure functions (F1's lag step, F2's `d_cam`, F3's `VISIBLE_ARC_HALF_WIDTH`, F4's position/look-at, F5's FOV-punch ease; `wrap_angle` reused verbatim from Ball Movement/Tube Track's own canonical implementation, never reimplemented). `CameraCore` is a `RefCounted` with no engine calls, holding `phi_cam` and the FOV-punch ease state, driven by injected read-only test doubles for Ball Movement (`theta`, `s`), Tube Track (`R`), and Run State (`run_reset`/`run_paused`/`run_ended`) plus an injected `log_sink` — mirroring `BallCore`'s and `TubeWindow`'s own seam pattern. `CameraConfig` is a `Resource` holding every value in Tuning Knobs, with a `validated(log_sink)` method that returns a clamped copy and enforces Core Rule 10's own margin floor (`CAMERA_RADIUS_TOO_CLOSE`) and Core Rule 6's bare inequality, the same pattern `BallConfig`/`TubeConfig` already use.

### States and Transitions

Camera has no phase of its own; its behavior is a function of `dt_eff` and Run State's events, the same pattern Ball Movement already uses.

| Situation | Event / `dt_eff` | Camera does |
|-----------|------------------|-----------|
| Boot, Menu | none | Parked at the start pose, directly behind the ball's own parked pose |
| New run | `run_reset` | Snaps instantly to directly behind the ball's start pose (Rule 5); no lag |
| Running, `dt_eff` > 0 | every step | `phi_cam` lags `theta` (Rule 1); position, look-at, and `d_cam` update every frame (Rules 2-3) |
| Hit, Paused, Resuming, settling tick | `dt_eff` = 0 | Frozen at its last pose (Rule 5) |

### Interactions with Other Systems

| System | Direction | Data / events | Note |
|--------|-----------|----------------|------|
| Ball Movement (Approved) | in | `theta`, `omega`, `speed`, `s`, once per frame | Hard dependency; already listed as a Ball Movement dependent (its own Interactions table) |
| Tube Track (Approved) | in | `R`, the tube axis to orbit around | Hard dependency; already listed as a Tube Track dependent |
| Run State & Restart (Approved) | in | `run_reset` (cuts to start pose), `run_paused`, `run_ended` (both hold) | Hard dependency; already listed exactly this way in Run State's own Interactions table |
| Tube Track (Approved) | out | `rear_extent` (`C_b`), `camera_distance` (`d_cam`), published as configuration values at map load | Resolves Tube Track's own placeholder guesses (6 and 8) for both — Tube Track's own Dependencies table already anticipates this exact shape |
| Obstacle System (Approved) | out | `VISIBLE_ARC_HALF_WIDTH` | Resolves Obstacle System's own Open Question 7 and its "external contract, not yet supplied" placeholder |
| Platform Services (Approved) | in (soft, provisional) | Safe area | Platform Services' own note already anticipates "Camera and HUD read the safe area" |
| Juice & Feedback (Not Started) | out (provisional) | `apply_fov_punch(amount, duration)` | Rule 7's mechanism-only hook; not yet authored |

## Formulas

Every default below is a concept-prototype starting point, none individually signed off by a tester (`prototypes/ball-in-tube-movement-concept/REPORT.md`) except where a specialist pass in this session corrected a value against the prototype's own source code.

**F1. Camera angular lag**

```
e_cam   = wrap_angle(theta - phi_cam)              (shortest signed arc, ball leads camera)
alpha   = 1 - exp(-dt / CAMERA_LAG_TAU)            (alpha = 1 when CAMERA_LAG_TAU < 1e-4)
phi_cam = wrap_angle(phi_cam + e_cam * alpha)
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `theta` | float | `[-PI, PI)` | Ball Movement's published wrapped angle (Ball Movement F1) |
| `phi_cam` | float | `[-PI, PI)` | Camera's own tracked orbit angle; the lag target of Core Rule 1 |
| `dt` | float | 0 to 0.1 | `dt_eff`; `dt <= 0` or non-finite is a no-op (Core Rule 5 freeze) |
| `CAMERA_LAG_TAU` | float | `≈0.333` (corrected; see Core Rule 1) | lag time constant; 0 means instant follow |
| `e_cam` | float | `[-PI, PI)` | signed shortest arc from `phi_cam` to `theta`, via `wrap_angle` |
| `alpha` | float | `[0, 1)` | fraction of the remaining error closed this step |

**Output range:** `|step| = |e_cam * alpha| <= |e_cam| <= PI`; the step never overshoots or reverses past the target (the same guarantee Ball Movement's own F1 gives its analogous lag), so `phi_cam` converges monotonically with no oscillation for any `dt`. No hard angular-rate cap is applied (Core Rule 1) — none is needed because `e_cam` is already self-bounded in practice: Ball Movement guarantees `|omega| <= OMEGA_MAX` at all times, so solving this lag for a sustained constant `omega` shows `|e_cam|` rises toward, and never exceeds, `OMEGA_MAX * CAMERA_LAG_TAU` during normal play (≈1.0 rad at Ball Movement's default `OMEGA_MAX` = 3.0 and this GDD's own `CAMERA_LAG_TAU` ≈0.333) — the camera-lag analogue of Ball Movement F5a's own crossover constant `K`.

**Example** (`CAMERA_LAG_TAU` = 0.333 s, `dt` = 1/60 s): `alpha = 1 - exp(-0.05005) = 0.0488`. `e_cam` = 1.0 rad gives a step of 0.0488 rad this frame. Holding `theta` fixed after a sharp turn, `phi_cam` closes to within 0.05 rad of `theta` after `t = CAMERA_LAG_TAU * ln(1.0 / 0.05) ≈ 1.0` s.

**F2. Camera position and `d_cam`**

```
r_ball = R + D/2                                     (Tube Track's R, Ball Movement's D)
delta  = wrap_angle(phi_cam - theta)                  (camera's angular lag behind the ball)
d_cam  = sqrt( r_ball^2 + CAMERA_RADIUS^2
             - 2*r_ball*CAMERA_RADIUS*cos(delta)
             + CAMERA_BACK_DISTANCE^2 )
```

The in-plane (radial) separation between the ball and the camera follows the law of cosines with included angle `delta`; the axial separation is exactly `CAMERA_BACK_DISTANCE` (both points share the same `s` reference, Core Rule 2); the radial plane and the axial direction are orthogonal, so the true 3D distance is the exact Pythagorean sum of the two — not an approximation.

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `R` | float | tube radius, 3.0 (registry) | Tube Track's radius |
| `D` | float | ball diameter, 0.8 (registry) | Ball Movement's diameter |
| `r_ball` | float | derived, 3.4 at defaults | ball's own orbit radius, `R + D/2` |
| `CAMERA_RADIUS` | float | fixed, `>` `TUBE_RADIUS`; 6.0 | camera's own orbit radius (Core Rule 2, 6) |
| `CAMERA_BACK_DISTANCE` | float | fixed; 6.0 | axial offset behind the ball (Core Rule 2) |
| `delta` | float | `[-PI, PI)` | wrapped angular lag between camera and ball; `-e_cam` (F1) |
| `d_cam` | float | derived, see Output range | straight-line eye-to-ball distance; Tube Track F9's external config input |

**Output range:** `d_cam` is monotonically increasing in `|delta|` over `[0, PI]`, so its practical range follows directly from F1's own practical bound on `|delta|` (`<= OMEGA_MAX * CAMERA_LAG_TAU ≈ 1.0` rad during normal play): **best case** (`delta` = 0, no active steering) `d_cam = sqrt((CAMERA_RADIUS - r_ball)^2 + CAMERA_BACK_DISTANCE^2) = sqrt(2.6^2 + 6.0^2) ≈ 6.54` u; **worst case** (`delta ≈ 1.0` rad, sustained full-lock turning) `d_cam = sqrt(3.4^2 + 6.0^2 - 2*3.4*6.0*cos(1.0) + 6.0^2) ≈ 7.84` u. A theoretical absolute max at `delta = PI` (unreachable under normal play, per F1's own bound) would be `≈11.16` u.

**What this means for Tube Track's own F9.** Tube Track's own visibility budget currently guesses a single fixed `d_cam` = 8 as an external configuration value. That guess sits just above this formula's own derived practical worst case (7.84 u, 0.16 u of headroom) and is used as a subtrahend there (`T_vis = (F_read - d_cam) / v_max`), so a larger assumed `d_cam` is the conservative direction — it never overstates `T_vis`. **This safety margin is coincidental, not structural**: it depends on `CAMERA_RADIUS`, `CAMERA_BACK_DISTANCE`, `CAMERA_LAG_TAU`, and Ball Movement's own `OMEGA_MAX` all staying near today's values, and would silently invert (making Tube Track's F9 optimistic rather than conservative) if any of those were retuned upward without re-checking this derivation. A cross-file edit proposing Tube Track replace its fixed guess with this formula's own worst-case bound — rather than continuing to hardcode 8 — is proposed in Dependencies.

**F3. `VISIBLE_ARC_HALF_WIDTH` — the tube's own self-occlusion**

```
VISIBLE_ARC_HALF_WIDTH = acos(TUBE_RADIUS / CAMERA_RADIUS)
```

For a circle of radius `r` (the tube, `TUBE_RADIUS`) viewed from an external point at distance `d` (the camera, `CAMERA_RADIUS`) from the same center, the tangent points to the circle satisfy `angle(O-Tangent-Camera) = 90°` (tangent ⟂ radius); in that right triangle, `cos(half-angle) = r/d`, so the half-width of the arc containing the near-point direction — the point on the circle facing the camera — that stays unoccluded by the circle's own curvature is `acos(r/d)`. **Proven independent of `CAMERA_BACK_DISTANCE`, the camera's live lagged angle `phi_cam`, and field of view**: a straight, axis-aligned cylinder's tangent-*plane* equation (`cos(theta_t)*x0 + sin(theta_t)*y0 = r`) has no axial (`z0`) term, so the magnitude depends only on the camera's perpendicular distance from the axis (`CAMERA_RADIUS`, fixed) — never on position along the axis or on which direction the camera currently faces; FOV clips the render frustum but does not change what the tube's own geometry occludes.

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `TUBE_RADIUS` (`R`) | float | 2.5–3.3 (Tube Track) | the tube's own vertex radius, the occluding cylinder |
| `CAMERA_RADIUS` | float | `>` `TUBE_RADIUS` (Core Rule 6) | camera's fixed distance from the tube axis |
| `VISIBLE_ARC_HALF_WIDTH` | float | `(0, PI/2)` rad | half-width of the tube's own circumference guaranteed unoccluded by its own curvature, centered on the near-point direction |

**Output range:** since `CAMERA_RADIUS` `>` `TUBE_RADIUS` always (Core Rule 6, structural, never a runtime check), the ratio lies in `(0, 1)`, so the result lies in `(0, PI/2)` rad — never a full hemisphere (only in the `CAMERA_RADIUS -> infinity` limit) and never zero (only if `CAMERA_RADIUS -> TUBE_RADIUS`, ruled out by Core Rule 6).

**Example** (prototype defaults, `CAMERA_RADIUS` = 6.0, `TUBE_RADIUS` = 3.0): `VISIBLE_ARC_HALF_WIDTH = acos(0.5) = 1.0472` rad (60.0 degrees) exactly.

**The one honest gap this formula does not close.** This value is the arc's exact *magnitude*; it says nothing about the arc's *center*. The true near-point direction is the camera's own live `phi_cam(t)` (Core Rule 1), which constantly changes as the camera lags the ball — not a fixed world angle. `THETA_REF` = 0 (Obstacle System's own reference point, Tube Track's fixed world "top") is a near-neutral proxy anchor, exact only when `phi_cam ≈ 0`, and its error grows with the ball's own live angular offset from `theta` = 0 — the same kind of proxy Obstacle System's own F4 already admits using for `T_reveal`, not a new problem this GDD introduces. Tracked in Open Questions, not silently treated as exact.

**F4. Camera position and look-at point — reused, not reinvented**

```
camera_position    = P(phi_cam, s_ball - CAMERA_BACK_DISTANCE, CAMERA_RADIUS - R)
look_at_s           = s_ball + CAMERA_LOOK_AHEAD
look_at_point       = the point on the tube's central axis at s = look_at_s   (radius 0; independent of any angle)
```

Camera never computes world coordinates of its own — it reuses Tube Track's own `P(theta, s, h)` (Tube Track Rule 1), the same "publish an angle/distance, let Tube Track place it in world space" pattern Ball Movement already follows for the ball itself. `P` places a point at radius `R + h` from the axis; passing `h = CAMERA_RADIUS - R` places the camera at exactly `CAMERA_RADIUS` from the axis (Core Rule 2), and `h = -R` places a point exactly on the axis (radius 0), which is what the look-at target requires — the angle argument is irrelevant at radius 0, since every angle maps to the same point there.

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `camera_position` | vector | — | World-space camera position, via Tube Track's own `P` |
| `look_at_point` | vector | — | World-space look-at target, on the tube's central axis |
| `look_at_s` | float | derived | `s` value the look-at point sits at (Core Rule 3) |

**Output range:** inherits `P`'s own guarantees (Tube Track); no new failure mode is introduced by this formula beyond what `P` itself already handles (Tube Track's own Edge Cases).

**Example** (defaults, `phi_cam` = 0.2, `s_ball` = 500): `camera_position = P(0.2, 494.0, 3.0)`; `look_at_point` = the axis point at `s` = 512.0, via `P(anything, 512.0, -3.0)`.

**F5. FOV-punch ease (Core Rule 7)**

```
fov_offset(t) = amount * max(0, 1 - t / duration)     for 0 <= t <= duration; 0 for t > duration or duration <= 0
```

A linear ease-out from `amount` back to baseline over `duration` — the simplest ease that satisfies Player Fantasy's "immediately rewarding" without introducing a new fixed decay-rate constant this GDD would otherwise have to own on top of the two values Juice & Feedback already supplies per call.

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `CAMERA_FOV` | float, degrees | 75.0 (Tuning Knobs) | the camera's own un-punched field of view, set once at boot; `amount` is additive on top of this baseline, never a replacement for it |
| `amount` | float | supplied by caller (Juice & Feedback) | peak additive FOV offset, in the same degree units as `CAMERA_FOV` |
| `duration` | float | supplied by caller (Juice & Feedback), `> 0` for a real ease | how long the ease takes to reach 0 |
| `t` | float | `>= 0` | seconds since the most recent `apply_fov_punch` call (Core Rule 7's own "latest call replaces" rule resets this to 0) |

**Output range:** `[0, amount]` for `amount >= 0`; linear and monotonically decreasing in `t` over `[0, duration]`, exactly 0 before any call and after `duration` elapses. A new `apply_fov_punch` call at any `t` resets `t` to 0 and replaces `amount`/`duration` outright (Edge Cases) — the prior ease's own remaining offset is discarded, never added to the new one.

**Example:** `amount` = 0.05, `duration` = 0.2 s: `fov_offset(0)` = 0.05; `fov_offset(0.1)` = 0.025; `fov_offset(0.2)` = 0; `fov_offset(0.3)` = 0.

## Edge Cases

- **If `CAMERA_RADIUS` is tuned close enough to `TUBE_RADIUS` that `VISIBLE_ARC_HALF_WIDTH` (F3) would fall below `CAMERA_RADIUS_MARGIN_MIN`'s own floor**: rejected at content-load time with `CAMERA_RADIUS_TOO_CLOSE` (Core Rule 10), naming both values — a config that is bare-legal under Rule 6's own inequality but leaves almost nothing of the tube visible is caught before it ships, not discovered on a device.
- **If `run_reset` arrives while the camera's own lag error (`e_cam`, F1) is still nonzero**: discarded entirely — the camera snaps instantly to directly behind the ball's fresh start pose (Core Rule 5), the same "no jolt at the moment that matters" pattern Ball Movement's own reset uses; there is no partial-lag carryover into the new run.
- **If a stall or a clamped `dt_eff` (Run State's own `DT_MAX`) produces an unusually large single step**: F1's own `alpha` bound (`< 1` for any finite `CAMERA_LAG_TAU` `>` 0) already prevents the step from overshooting `e_cam`, so no special-casing is needed — the same guarantee Ball Movement's own F1 already relies on for an identical clamp.
- **If `apply_fov_punch(amount, duration)` (Rule 7) is called again while a previous punch is still easing back to baseline**: the new call's parameters replace the in-progress ease immediately — the FOV jumps to (or toward) the new `amount` and eases from there, rather than stacking additively with whatever offset remained from the first call. This is a deliberate choice: additive stacking could push the FOV arbitrarily far from baseline if near-misses cluster, which nothing about Pillar 3's own "immediately rewarding" promise asks for.
- **If Ball Movement ever publishes a non-finite `theta`**: treated as a no-op frame, holding `phi_cam` (and everything derived from it — position, `d_cam`) at its last known-good value — the same guard Near-Miss Detection and Obstacle System already apply to the same published field.
- **If `theta` wraps across the `-PI`/`PI` boundary during a turn**: already handled by F1's own `wrap_angle` (the same canonical implementation Ball Movement and Tube Track share) — `e_cam` always takes the shortest signed arc, so a wrap never produces a spurious near-`2*PI` lag error or a visible snap.

## Dependencies

**Upstream (Camera needs these)**

| System | Type | What it needs | Note |
|--------|------|----------------|------|
| Ball Movement (Approved) | Hard | `theta`, `omega`, `speed`, `s`, once per frame | Read-only; already listed as a Ball Movement dependent in its own Interactions table |
| Tube Track (Approved) | Hard | `R`, the tube axis to orbit around | Already listed as a Tube Track dependent |
| Run State & Restart (Approved) | Hard | `run_reset`, `run_paused`, `run_ended` | Already listed exactly this way in Run State's own Interactions table |
| Platform Services (Approved) | Soft, provisional | Safe area | Platform Services' own note already anticipates "Camera and HUD read the safe area" |

**Downstream (these need Camera)**

| System | Type | What it needs |
|--------|------|-------|
| Tube Track (Approved) | Hard (config values, not runtime calls) | `rear_extent` (`C_b`), `camera_distance` (`d_cam`), published at map load |
| Obstacle System (Approved) | Hard (config value) | `VISIBLE_ARC_HALF_WIDTH` |
| Juice & Feedback (Not Started) | Soft, provisional | `apply_fov_punch(amount, duration)` |

**Bidirectional consistency (checked against the existing GDDs)**
- **Ball Movement:** already lists Camera as a dependent needing `theta`, `omega`, `speed`, `s` — consistent, no edit needed.
- **Run State & Restart:** already lists Camera as a Hard dependent needing exactly `run_reset`, `run_paused`, `run_ended` — consistent, no edit needed.
- **Tube Track:** already lists Camera as a Hard dependent supplying `rear_extent`/`C_b` and `camera_distance`/`d_cam` as map-load configuration values, currently guessed at 6 and 8. This GDD **confirms** `rear_extent` = `CAMERA_BACK_DISTANCE` = 6.0 exactly (the camera's own position, `CAMERA_BACK_DISTANCE` behind the ball, is the rearmost point that must stay loaded for a forward-looking camera that never looks further back than itself) — Tube Track's own guess was already correct, no value changes. `camera_distance`/`d_cam`, however, is **not** a single fixed number this GDD ships — F2 derives it as a function of the current angular lag, with a proven practical range of ≈6.54–7.84 u. The cross-file edit has been applied: Tube Track's own F9 now re-sources its fixed `d_cam` = 8 guess against F2's own derived worst-case bound (a function of `CAMERA_RADIUS`/`CAMERA_BACK_DISTANCE`/the ball's orbit radius/the practical lag bound) rather than leaving it a free-floating guess — 8 still exceeds today's derived 7.84, so no value changed, only its justification.
- **Obstacle System:** already lists Camera as the "external contract, not yet supplied" owner of `VISIBLE_ARC_HALF_WIDTH` (its own F4, Open Question 7). The cross-file edit filling in the real value — `VISIBLE_ARC_HALF_WIDTH = acos(TUBE_RADIUS / CAMERA_RADIUS) ≈ 1.0472` rad (60°) at defaults (F3) — has been applied, along with F3's own honest caveat: the arc's magnitude is exact, but `THETA_REF` = 0 is a near-neutral proxy for the camera's own live angle, the same kind of proxy Obstacle System's F4 already uses for `T_reveal`.
- **Platform Services:** its own note anticipating "Camera... read the safe area" is consistent with this GDD's own upstream table; no concrete safe-area interface exists yet (Platform Services' own GDD doesn't name one precisely) — left provisional.
- **Systems index:** the Dependency Map already lists Camera as depending on Ball Movement, Tube Track, and Run State & Restart — consistent, no edit needed.

**Provisional assumptions**: the exact safe-area interface shape (Platform Services names the concept but not a concrete call). Juice & Feedback's own exact consumption of `apply_fov_punch` is no longer provisional — resolved 2026-09-29 (`juice-feedback.md` Formula F3): `amount` = 1.125° (`FOV_PUNCH_PCT` = 1.5% of `CAMERA_FOV`), `duration` = 0.08 s, fixed, no closeness-scaling.

## Tuning Knobs

| Knob | Default | Safe range | Affects | Too low | Too high |
|------|---------|------------|---------|---------|----------|
| `CAMERA_LAG_TAU` | `≈0.333` s (corrected from the prototype's misread `CAMERA_FOLLOW_SPEED` = 3.0; Core Rule 1, F1) | 0.15–0.6 s | How quickly `phi_cam` catches up to `theta` (F1) | Camera snaps almost instantly, losing the "catching up" feel the prototype's own tester validated and reading as rigid/mechanical | Camera feels sluggish and disconnected from the player's own steering; F1's own practical `delta` bound (`OMEGA_MAX * CAMERA_LAG_TAU`) grows, widening `d_cam`'s own worst case (F2) and tightening Tube Track's F9 margin |
| `CAMERA_RADIUS` | 6.0 | 4.0–8.0, structural floor `TUBE_RADIUS + CAMERA_RADIUS_MARGIN_MIN` (Core Rule 10) | `VISIBLE_ARC_HALF_WIDTH` (F3) and `d_cam` (F2) simultaneously — the two are not independent knobs | A narrower visible arc (more of the tube hidden, F3) — closer to the "liked surprise" the prototype's tester reported, but risks Pillar 1/2's fairness promise if pushed too far | A wider visible arc (less hidden, weaker far-side surprise) and a larger `d_cam`, which tightens Tube Track's F9 margin (F2) |
| `CAMERA_BACK_DISTANCE` | 6.0 (= Tube Track's own `rear_extent`, confirmed exactly, Dependencies) | 3.0–10.0 | How far behind the ball the camera sits (Core Rule 2); `d_cam` (F2) | The camera crowds the ball, reducing the framing the concept prototype validated | The ball reads small/distant; `d_cam` grows, tightening Tube Track's F9 margin the same way a larger `CAMERA_RADIUS` does |
| `CAMERA_LOOK_AHEAD` | 12.0 | 6.0–20.0 | Where the camera looks relative to the ball (Core Rule 3) — framing feel only, not safety-critical | The camera looks almost directly at the ball rather than ahead of it, reducing the sense of "heading somewhere" | The camera looks so far ahead the ball reads as off-center or trailing |
| `CAMERA_RADIUS_MARGIN_MIN` | 0.5 | 0.25–1.5 | The floor `CAMERA_RADIUS` must clear above `TUBE_RADIUS` (Core Rule 10) | Lets `CAMERA_RADIUS` land close enough to `TUBE_RADIUS` that `VISIBLE_ARC_HALF_WIDTH` (F3) collapses toward 0 — almost nothing of the tube visible at all | Needlessly forbids an otherwise-reasonable tight `CAMERA_RADIUS` tuning; at the default 0.5, the tightest legal `CAMERA_RADIUS` (`TUBE_RADIUS` + 0.5 = 3.5 at defaults) still gives `VISIBLE_ARC_HALF_WIDTH` = `acos(3.0/3.5)` ≈ 0.5054 rad (≈29°), a real floor, not a token one |
| `CAMERA_FOV` | 75.0° (Godot's `Camera3D.fov` engine default) | 60.0–90.0° | The camera's own un-punched field of view (F5); Juice & Feedback's own `apply_fov_punch` `amount` is computed as a percentage of this value (Juice & Feedback F3) | A narrower view crops more of the tube at the screen edges, reducing reaction space | A wider view shrinks hazards on screen, hurting readability (Pillar 1) |

**Fixed constants (not tuning knobs):** none of this GDD's own — every geometric input besides the five knobs above (`TUBE_RADIUS`, `D`, `OMEGA_MAX`) is owned and tuned by another GDD.

**Knob interactions**
- `CAMERA_RADIUS` and `CAMERA_BACK_DISTANCE` both feed `d_cam` (F2) in the same direction — raising either one raises `d_cam`'s own worst case and tightens Tube Track's own F9 margin; re-check F9's own validation range (Tube Track) before raising either knob far from its shipped default.
- `CAMERA_LAG_TAU` and Ball Movement's own `OMEGA_MAX` jointly bound `delta`'s own practical maximum (F1's own derivation), which feeds `d_cam`'s worst case (F2) the same way `CAMERA_RADIUS`/`CAMERA_BACK_DISTANCE` do — a change to Ball Movement's `OMEGA_MAX` changes Camera's own worst-case `d_cam` even if no Camera knob moves at all.
- `CAMERA_RADIUS` alone determines `VISIBLE_ARC_HALF_WIDTH` (F3) — `CAMERA_RADIUS_MARGIN_MIN` (Core Rule 10) exists specifically to keep this knob's own safe range from silently producing a near-zero visible arc.

**Sources of truth elsewhere:** `TUBE_RADIUS` (Tube Track); `D`, `OMEGA_MAX` (Ball Movement); `T_VIS_MIN`'s own margin, which `d_cam`'s worst case feeds into (Tube Track F9). `CAMERA_FOV` is consumed by Juice & Feedback's own Formula F3 (near-miss FOV-punch magnitude) — a change to this knob changes that GDD's `amount` value even though no Juice & Feedback knob moves.

## Visual/Audio Requirements

**No screen shake, ever.** game-concept.md's own near-miss juice list is explicit: "FOV punch, white ring pulse, whoosh SFX; **no screen shake**, see art bible Section 2" — this is a constraint on this system, not a suggestion. Whatever Juice & Feedback wants to do for a hit, a near-miss, or any other moment, it may never move the camera's own position or orbit outside the transform this GDD's own Core Rules 1-3 define. **`apply_fov_punch` (Core Rule 7) is the one camera-owned exception** — an additive, temporary field-of-view offset, never a position or rotation change — and it is mechanism only: this GDD names the call and its easing behavior (Edge Cases), Juice & Feedback owns every actual `amount`/`duration` value. No audio is owned here — Camera renders nothing and plays no sound of its own.

## UI Requirements

No player-facing UI of its own, and no requests to other systems beyond what Dependencies already states. No UX Flag: there is no screen or HUD element of its own to specify — Camera is a transform, not a screen.

## Acceptance Criteria

**Targets:** **[M]** `CameraMath` static pure functions (F1 lag step, F2 `d_cam`, F3 `VISIBLE_ARC_HALF_WIDTH`, F4 position/look-at, F5 FOV-punch ease; `wrap_angle` reused verbatim from Ball Movement/Tube Track's canonical implementation, never reimplemented); **[C]** `CameraCore`, a `RefCounted` with injected Ball Movement/Tube Track/Run State test doubles and a `log_sink` (mirrors `BallCore`/`TubeWindow`, Core Rule 11); **[K]** `CameraConfig.validated(log_sink)`, a preflight returning a clamped copy (Core Rule 10, `CAMERA_RADIUS_TOO_CLOSE`); **[L]** CI lint, no engine coupling (mirrors Ball Movement AC-25 / Tube Track AC-25); **[I]** integration, deferred until named owner+date; **[V]** device/playtest evidence in `production/qa/evidence/camera/`. Tests live in `tests/unit/camera/`, named `camera_[feature]_test.gd`.

**Fixture:** `make_camera_fixture()` returns `CAMERA_LAG_TAU` = `1.0/3.0` (the exact reciprocal of the prototype's `CAMERA_FOLLOW_SPEED` = 3.0, per Core Rule 1 — the GDD's own "≈0.333" is prose rounding; tests use full precision), `CAMERA_RADIUS` 6.0, `CAMERA_BACK_DISTANCE` 6.0, `CAMERA_LOOK_AHEAD` 12.0, `CAMERA_RADIUS_MARGIN_MIN` 0.5. Test doubles supply `TUBE_RADIUS` 3.0, `D` 0.8 (`r_ball` = 3.4), and Ball Movement's `OMEGA_MAX` 3.0 (needed only for AC-3's steady-state bound). `make_core(cfg)` and `make_sink()` are companions. Exact `==` for log codes and snapped poses; 1e-6 tolerance otherwise, stated per-AC where looser.

**Logic, BLOCKING**
- **AC-1 [M]** (F1) `step(e_cam, dt, tau)` table: (1.0, 1/60, 1/3) → alpha 0.0487706, step 0.0487706; (0.5, 1/30, 1/3) → alpha 0.0951626, step 0.0475813; (-1.0, 1/60, 1/3) → step -0.0487706 (sign mirror). Guard: `dt` 1e-5 with `tau` 9.99e-5 gives `alpha` 1; `tau` 1e-4 gives 0.0951626.
- **AC-2 [M]** (F1, output range) Swept table `e_cam` in [-PI, PI], `dt` in {0, 1/120, 1/60, 0.1}: `|step| <= |e_cam| * alpha <= |e_cam|` always, `sign(step) == sign(e_cam)` or 0, monotonic convergence, no oscillation across repeated application. **No-cap mutation:** at (`e_cam` = PI, `dt` = 0.1, `tau` = 1/3), the correct uncapped step is 0.814022 rad — a mutation that clamps `step` to `OMEGA_MAX * dt` (0.3 rad, reintroducing Ball Movement's own F1 pattern by mistake) must fail this AC.
- **AC-3 [M]** (F1, Core Rule 1's own self-limiting claim) Drive `e_cam` with `theta` advancing at a constant `omega` = `OMEGA_MAX` = 3.0 rad/s for 5 s at 60 Hz (wrap is a no-op throughout since the bound stays under PI): `|e_cam|` rises monotonically and asymptotically toward, and never exceeds, `K = OMEGA_MAX * CAMERA_LAG_TAU` = 1.0 rad (within 1e-3 after 5 s). Confirms no hard `OMEGA_MAX`-style cap exists on `phi_cam`'s own step, only this emergent bound.
- **AC-4 [M]** (F1) At 60 Hz, `e_cam` = 1.0 rad held fixed: frame 59 gives `|e_cam|` ≈ 0.0522 (`>` 0.05), frame 60 gives ≈ 0.0496 (`<=` 0.05) — first frame within tolerance is 60, matching the GDD's own "≈1.0 s" claim.
- **AC-5 [M]** (F4) `look_at_s(s_ball, look_ahead) = s_ball + look_ahead`: (100.0, 12.0) → 112.0; (0.0, 12.0) → 12.0; non-finite `s_ball` holds the last known-good target (mirrors AC-13). `camera_position` and `look_at_point` each delegate to Tube Track's own `P(theta, s, h)` with the exact `h` arguments F4 states (`CAMERA_RADIUS - R` and `-R`) — a mutation that computes either point independently of `P` must fail this AC.
- **AC-6 [M]** (F2) `d_cam(r_ball=3.4, CAMERA_RADIUS=6.0, CAMERA_BACK_DISTANCE=6.0, delta)`: `delta` 0 → 6.53911; 0.5 → 6.91047; 1.0 (practical max) → 7.84319; symmetry: `d_cam(-1.0) == d_cam(1.0)`; monotonically increasing over `|delta|` in [0, PI]. `d_cam` has no setter in `CameraCore` — only the derived getter (Core Rule 2: never an independently-tuned value); a mutation adding a settable `d_cam` field must fail the AC-17 lint.
- **AC-7 [M]** (F2, theoretical bound) `delta` = PI (unreachable in normal play) → `d_cam` ≈ 11.1517; asserted alongside AC-3: since AC-3 proves `|delta|` never exceeds `K` ≈ 1.0 rad in normal play, `d_cam`'s practical worst case is the AC-6 value at `delta` = 1.0 (7.84319), not this theoretical one.
- **AC-8 [M]** (F3) Defaults (`CAMERA_RADIUS` 6.0, `TUBE_RADIUS` 3.0): `acos(0.5)` = 1.047198 rad (60.0°) exact. Second pair (`CAMERA_RADIUS` 3.5, `TUBE_RADIUS` 3.0 — the tightest legal pair at the default margin): `acos(3.0/3.5)` = 0.505474 rad (≈28.96°).
- **AC-9 [M]** (F3, independence — Core Rule 4's own proof) For the fixed pair (6.0, 3.0), `VISIBLE_ARC_HALF_WIDTH` is bit-identical across every combination of `CAMERA_BACK_DISTANCE` in {3.0, 6.0, 10.0} and `phi_cam` in {0, PI/2, PI}. **Mutation:** any function signature that accepts and uses either parameter, and produces a different result for two of these combinations, must fail this AC.
- **AC-10 [K]** (Core Rule 10, boundary) `TUBE_RADIUS` 3.0, `CAMERA_RADIUS_MARGIN_MIN` 0.5 (floor 3.5): `CAMERA_RADIUS` = 3.5 loads (`VISIBLE_ARC_HALF_WIDTH` 0.505474, no log); `CAMERA_RADIUS` = 3.499999 is rejected with exactly one `CAMERA_RADIUS_TOO_CLOSE`, naming both 3.499999 and 3.0; `CAMERA_RADIUS` = 3.0 (violates Core Rule 6's bare inequality too) is also rejected.
- **AC-11 [C]** (Core Rule 5, snap) From an arbitrary prior lag (`phi_cam` 2.5, `theta` 0.1), `on_run_reset()` sets `phi_cam` to exactly the ball's start-pose angle (0.0, bit-identical) with no partial-lag carryover; the very next `d_cam` read uses `delta` = 0.
- **AC-12 [C]** (Core Rule 5, freeze) A step with `dt_eff` in {0, -0.001, NaN, +inf} leaves `phi_cam`, position and `d_cam` bit-identical to their pre-call values; no log for 0, one `BAD_DT` for each other value (mirrors Ball Movement AC-2).
- **AC-13 [C]** (Edge Cases, non-finite `theta`) A step with `theta` NaN or infinite is a no-op: `phi_cam` (and everything derived from it) holds its last known-good value, one error logged.
- **AC-14 [M]** (F1, `wrap_angle` boundary) `theta` = PI - 0.05 (3.091593), `phi_cam` = -PI + 0.05 (-3.091593): `e_cam = wrap_angle(theta - phi_cam)` = -0.1 exactly (within 1e-9), not the raw difference 6.183185 — confirms the shortest-arc wrap, not a spurious near-`2*PI` error, at the seam.
- **AC-15 [C]** (Core Rule 7, Formula F5, "no stacking") `apply_fov_punch(0.05, 0.2)` then, at `t` = 0.1 mid-ease (`fov_offset` would be 0.025 if left alone), a second call `apply_fov_punch(0.03, 0.1)`: the internal ease state resets fully to `(amount=0.03, elapsed=0, duration=0.1)`, discarding the first call's 0.025 remainder entirely — `fov_offset` immediately after the second call is exactly 0.03, not 0.055. **Mutation:** an implementation that adds the first call's residual to the second (additive stacking, giving 0.055) must fail this AC. A companion row confirms F5's own linear decay numerically: `amount` 0.05, `duration` 0.2 → `fov_offset(0)` = 0.05, `fov_offset(0.1)` = 0.025, `fov_offset(0.2)` = 0, `fov_offset(0.3)` = 0.
- **AC-16 [C]** (Core Rule 9) Two fresh `CameraCore` instances fed an identical scripted sequence of `(theta, dt_eff)` pairs, including resets, freezes and non-finite inputs, are bit-identical after every step.
- **AC-17 [L]** (Core Rules 6, 8, 9, 11) Static scan over `CameraMath`, `CameraCore`, `CameraConfig`: none contains `CollisionObject3D`, `Area3D`, `PhysicsServer`, `RayCast3D`, `request_`, `hit_reported`, `Input.`, `Engine.`, `Time.`, `OS.`, `DisplayServer.`, `get_tree`, `_process`, `_physics_process`, `randi`, `randf`, `randomize` (structural backing for "no collision of its own," "no side effects," and determinism); `CameraConfig.validated()` rejects any config with `CAMERA_RADIUS <= TUBE_RADIUS` (Core Rule 6's bare inequality, distinct from AC-10's margin floor).
- **AC-18 [K, ADVISORY]** (Config/Data smoke) The shipped `CameraConfig.tres` equals the Tuning Knobs table defaults and validates with zero `KNOB_CLAMPED` / `CAMERA_RADIUS_TOO_CLOSE`.

**Integration [I], deferred**
- **AC-19 [I], deferred** (Core Rules 1, 2, 5; blocked by the game-loop ADR and a named driver story, neither currently ticketed) A test-only driver wires real `BallCore`, `TubeWindow`/`TubeConfig`, and Run State's core to `CameraCore`: over a scripted run including a hit, a pause, a resume and a reset, `phi_cam` lags the real `theta`, freezes exactly when Ball Movement freezes, and snaps on `run_reset` in the same tick Ball Movement's own pose resets. **Not BLOCKING today** — per the standing rule this project's own precedent GDDs established (Ball Movement AC-29/AC-31): no AC may be BLOCKING for a milestone while its blocking dependency has no named owner or no date.

**Device and playtest**
- **CAM-1 [V, ADVISORY]** (Open Question 1 / systems-index scope risk: "lagged rolling orbit... 'sense of speed' with a static tube is unproven") First-playable device playtest: testers rate disorientation/dizziness (target near-zero — the specific failure the concept prototype's v1 model produced) and control-lag feel, screenshot + lead sign-off recorded in `production/qa/evidence/camera/`. **Classified ADVISORY, not BLOCKING**: this is a purely subjective, device-dependent claim (Testing Standards' Visual/Feel row), and `production/qa/designated-gates.md` carries no entry for Camera — the two-limb escalation exception (`coding-standards.md`) requires a creative-director designation plus producer ratification, neither of which exists for this GDD. Escalating this to BLOCKING here would be inventing a ratification, exactly the failure mode Ball Movement's own review log warns against.

**Gate policy.** AC-1 through AC-17 are Logic, BLOCKING (Formulas F1-F5, Core Rules 1, 3, 5, 6, 7, 8, 9, 10, 11). AC-18 is Config/Data, ADVISORY. AC-19 is Integration — BLOCKING once its ADR/driver dependency has a named owner *and* a date (currently neither), tracked as an open gap, not a present blocker. CAM-1 is Visual/Feel, ADVISORY by default; it may only become BLOCKING through a fresh `/design-review` pass with an explicit creative-director designation and producer ratification recorded in `production/qa/designated-gates.md` — not assumed here.

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | The real, named scope risk from systems-index.md: "lagged rolling orbit was accepted by 1 internal tester with keyboard input only; 'sense of speed' with a static tube is unproven" — this GDD formalizes the model but does not itself validate it beyond the prototype | user | Vertical slice, on a real device |
| 2 | `VISIBLE_ARC_HALF_WIDTH`'s magnitude is exact (F3), but its center (`THETA_REF` = 0) is a near-neutral proxy for the camera's own live, constantly-lagging angle `phi_cam(t)` — the same honest gap Obstacle System's own F4 already carries for `T_reveal`. Whether this proxy's error is small enough in practice to ignore, or needs a tighter treatment, is unresolved | systems-designer, whoever revisits Obstacle System's F4 | On-device spike, or when real content authoring makes the error's real-world size measurable |
| 3 | Whether and how the camera's own perceptual lag (`CAMERA_LAG_TAU`, F1) should fold into Obstacle System's `T_REVEAL_MIN` proxy — Camera's GDD now supplies a concrete, validated lag value, but the fold-in decision itself belongs to Obstacle System's own F4, not to this GDD | whoever revisits Obstacle System's F4 | When Obstacle System's own hidden-side rule is next revised |
| 4 | The exact safe-area interface Platform Services will eventually supply (a `Rect2`? a margin per edge?) — Platform Services' own GDD names the concept but not a concrete call | whoever revises Platform Services, or this GDD | When that interface is concretely defined |
| 5 | Whether `CAMERA_RADIUS_MARGIN_MIN`'s own default (0.5, giving a floor of ≈29° on `VISIBLE_ARC_HALF_WIDTH`) is actually the right trade-off between guaranteeing a real visible arc and leaving `CAMERA_RADIUS` room to tune — a design-feel question, not a correctness one | user, game-designer | Once real content exists and the hidden-side "fair surprise" tension (Player Fantasy) can be playtested |
| 6 | Re-justifying `TUBE_RADIUS` (`R`) against tilt resolution and the visible arc after a device test — carried over from Tube Track's own former Open Question 7, now actionable against this GDD's own concrete `VISIBLE_ARC_HALF_WIDTH` formula (F3) rather than blocked on an unauthored dependency | user, whoever runs the device spike | Alongside the Ball Movement / Tilt Input device spike |
