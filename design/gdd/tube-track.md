# Tube Track

> **Status**: Revised 2026-09-20 after a fourth `/design-review` (lean depth; verdict NEEDS REVISION, 1
> blocking item, the Idle window lifecycle, addressed with a spec freeze; the first review had 9
> blockers, the second 12 and the third 6). **Approved 2026-09-20** by the user after the revision,
> without a further re-review. **Amended 2026-09-20 (post-approval)** with the art-director's advisory
> rulings the same day: seams are a flat shading band with no geometric relief (`relief`,
> `SEAM_RELIEF` and the `RELIEF` code removed), and `SEAM_CONTRAST_MAX` is 1.25; the readable
> criterion (`F_read`) was handed to Environment & Theming. Provisional inputs (`F_read`, `d_cam`, `v_max`, the seam band) still
> await the other GDDs and an on-device test (Open Questions 10, 12, 13, 14).
> **Author**: user + agents
> **Last Updated**: 2026-09-20
> **Supports Pillar**: Pillar 1 (Instant Readability); Pillar 2 (Fair but Merciless
> Difficulty) only as a supplier of a visibility budget (F9) and of `R`, see Player Fantasy

## Overview

Tube Track is the Core-layer system that defines the world the game is played
on: a single, straight, horizontal, endless cylinder along which the ball travels. It
owns the tube's geometry (radius, length axis, circular cross-section), the coordinate
frame every other system uses to place things on it (an **angle around the tube** and
a **distance along the tube**), the pattern of flush circumferential seams that gives
the player a sense of speed while the tube stays static on screen, and a sliding
window of **logical segments** that lets the track feel endless within a phone's
memory and draw-call budget. It has no player-facing behavior of its own and no
dependencies; Ball Movement, Obstacle System, Pattern & Difficulty, Camera and
Environment & Theming all build on it. In the MVP the tube is always straight and there
is a single map (Map 1); curved (spline) tubes are deferred. Colors, fog and the choice
of seam pattern come from Environment & Theming through `MapConfig`; Tube Track owns
the geometry, the seam pattern format and the derived constraints on those values.

## Player Fantasy

Tube Track is infrastructure: players feel what it enables, not the tube itself. It
serves Pillar 1, *"The player must always be able to tell what killed them, and
every obstacle in view must be easy to read"*, by being the quiet, stable stage that
hazards stand out against.

The player should never think about the tube. If they notice it at all, it is as
solid, quiet ground with a clear rhythm: the seams sliding past under the ball are meant
to add a modest cue for how fast they are going. What they should feel because of it is
(1) a touch of **speed**, even though the tube is static on screen (a hypothesis until
AC-27 shows the seams add to it), (2) a **continuous world** with no hitches, loading or
pop-in, and (3) a **clean stage** that keeps hazards the loudest thing on screen (art
bible section 1).

**Speed is shared.** Seams are one speed cue among several: hazard approach rate
(Obstacle System, Pattern & Difficulty), Camera FOV and Juice & Feedback streaks. The art
bible ranks seam flow fourth, and world chroma drops 10-15% at high speed (Mood state 3; value is
unchanged, so seam contrast does not compress, rule 9).
Tube Track therefore does not claim to carry the feeling alone; the first playable must
A/B seams on and off on a device (AC-27).

**Loudness rule.** Seams are the fourth-ranked cue (art bible section 3f) and are never the
loudest element in a still frame; hazards always are (art bible section 4, hazard/tube
contrast 4:1). Whether a seam sweeping past is a distracting transient in motion is untested
(Open Question 18). Seams are lighter than the tube; the contrast ceiling is an art-director
ruling awaiting a device check, see rule 9.

**Pillar 2.** Tube Track supports Pillar 2 and does not deliver it. Fairness lives in Obstacle
System and Pattern & Difficulty. Tube Track supplies two things: a visibility budget,
`T_vis = (F_read - d_cam) / v_max` (F9), where `F_read` is the distance from the camera at which a
hazard is still readable through fog (owned by Environment & Theming), and the tube radius `R` (how much of the
circumference the player must scan). F9 does not cover the hazard on the hidden far side of the
tube, which is limited by the tube body and the camera height, not by fog: that reveal time,
`T_reveal`, belongs to Camera and Obstacle System (Open Question 7).

**Feelings to avoid**: a hitch when segments are recycled, a segment "jumping" in at
the horizon, or a tube surface so busy that it competes with hazards for attention.

## Detailed Design

### Core Rules

**Coordinate frame** (owned by Tube Track; every other system uses it):
- The tube axis is a straight line along the direction of travel (world -Z). The
  tube has a constant radius `R` (`TUBE_RADIUS`) for every map for now.
- A point on or above the tube is addressed by three values: **theta** (angle
  around the tube), **s** (distance along the tube) and **h** (radial height above
  the surface, `h >= 0`).
- **theta = 0 is the top of the tube** (world +Y). Theta increases **clockwise when
  viewed from behind, looking in the direction of travel**, so tilting right
  increases theta. Theta is periodic and always normalized to [-pi, pi).
- **s** is the distance travelled along the tube since the run started; it
  increases in the direction of travel.
- World position: `P(theta, s, h) = ((R + h) * sin(theta), (R + h) * cos(theta), -s)`.
  The outward surface normal at theta is `(sin(theta), cos(theta), 0)`.

**Rules**
1. **Address by (theta, s, h).** Systems place, move and query things using
   (theta, s, h). Only Tube Track converts to world space; no other system reads or
   writes raw world z. (This is what lets a later change, such as a treadmill or a
   render-origin shift, happen without touching other systems.)
2. **Angular distance.** The difference between two angles is always the shortest
   signed arc, `delta_theta = wrap_angle(theta_a - theta_b)` in [-pi, pi). Systems must
   use this rule and must not subtract angles directly.
3. **The tube is straight and constant** for the MVP: same radius and circular
   cross-section on every map. Curved tubes and per-map radii are deferred. `R` is the
   vertex radius of the 32-sided tube mesh; the ball rides the true circle of radius
   `R + D/2`, so it floats between 0 (at a vertex) and `R * (1 - cos(PI/32))` (at a
   facet centre) above the surface (F7; 0.0144, or 1.8% of the ball diameter, at
   defaults). The safe range of `R` is capped so this stays at most 2% of `D`.
4. **Progress input: `advance(s)`.** Tube Track does not move anything by itself during a run.
   It is driven by one call, `advance(s)`, made **once per frame by exactly one caller** in one
   loop: the system that owns the traveller (Ball Movement, integrating `s` with the `dt_eff` that
   Run State's `tick()` returns). `advance(s)` is valid only in Running, and the owner never calls
   it in another phase (Run State rule 3, Owner contract). The menu idle scroll is not a call of
   `advance`: it is the separate internal step `idle_step(dt)` of the Idle state (rule 11, F8).
   Tube Track has no dependency on the update order of Camera or Ball Movement; it only reacts to
   the `s` it is given. Which loop makes the call (`_process` with a clamped delta, or the physics
   tick with interpolation) is decided in the game-loop ADR (Open Question 4). `s` never decreases
   within a run and is reset to 0 by `begin_run()`. The caller clamps its per-frame time step to
   `t_lat` (F3, the shared `DT_MAX`), so `s` never advances more than `v_max * t_lat` in one call
   in normal play.
5. **Segments are logical.** Segment `i` covers `s` in `[i*L, (i+1)*L)`
   (`SEGMENT_LENGTH` = `L`, an integer-valued float). Tube Track keeps a window of
   `N = A + B + 1` slots: `SEGMENTS_BEHIND` (`B`) behind the traveller's current segment,
   the current one, and `SEGMENTS_AHEAD` (`A`) ahead. When the traveller enters the next
   segment, the rearmost slot is recycled to the far end of the window. Whatever is bound
   to a slot (mesh, material, hazard containers) is re-targeted, never allocated or freed
   during a run. How the tube is rendered (one mesh per slot, a MultiMesh, or one mesh
   with a scrolling seam shader) is an implementation choice recorded in an ADR (Open
   Question 3); it must not change any rule or signal here.
6. **Continuous world.** Recycling is **synchronous**: it happens inside the same
   `advance(s)` call in which `s` crosses a segment boundary, once per boundary, before
   the call returns. A slot is recycled only after its segment is completely out of view:
   `B * L >= C_b + M_cam` (F3), where `C_b` is the Camera's `rear_extent`. The far end of
   the window is always at least `F + v_max * t_lat` ahead of `s` after any call (F3), so
   the player never sees pop-in, a gap or a jump at the horizon or behind the ball. Signal
   handlers run inside `advance()`; they must not call any mutating method of Tube Track
   (re-entrant calls are rejected with an error, see Edge Cases).
7. **Horizon and visibility.** The far end of the window lies beyond the map's fog end
   distance `F` (`fog_end_distance` from `MapConfig`) at all speeds, so the end of the tube is
   never visible. `F` is the largest fog end distance over all speeds (fog pulls nearer as speed
   rises), defined as the distance at which fog opacity reaches 100%; the fog color equals
   the sky color at the horizon (`fog_color`). Verified on Godot 4.7.2 (Forward+; the Mobile
   renderer was not re-run in review 3): with depth fog the factor is `pow(smoothstep(fog_depth_begin, fog_depth_end, d), fog_depth_curve) *
   fog_density`, where `d` is the **radial distance from the camera eye** (not the depth along the
   view axis), so at `fog_depth_end` the opacity equals `fog_density`. The map must therefore set
   `fog_mode` to depth (the engine default, exponential, never becomes fully opaque at a finite
   distance; `FOG_MODE`), `fog_density = 1.0` (the engine default 0.01 is far from opaque;
   `FOG_DENSITY`) and `fog_depth_begin < fog_depth_end` (`FOG_RANGE`), and Tube Track validates all
   three. `F` is `fog_depth_end`; smoothstep reaches 99.9% just before it, so this is conservative.
   `F` and `F_read` are radial distances from the camera eye. The camera sits `d_cam` behind the
   ball, so a point at radial distance `F` is about `F - d_cam` ahead of the ball (the difference
   between radial and axial distance is under 0.5 u at these ranges and ignored); F3 sizes the
   window on `F` measured from `s`, which over-provisions by about `d_cam`. `F` serves only the
   window size (F3). Whether a hazard is still readable is a different distance, `F_read` (F9),
   supplied by Environment & Theming, who also own the readable criterion itself (Open Question
   10). Tube Track validates only what it can derive (F9 visibility time, F3 window size, the fog
   fields above, finite and positive values); the raw range of `F` and `F_read` and the
   speed-driven fog behavior belong to Environment & Theming (Open Question 10).
8. **Precision, no render-origin shift in the MVP.** `s` is a 64-bit float (GDScript
   `float`); `z = -s` is cast to 32 bits only when a Vector3 is built, and `s` is never
   stored in a Vector3. There is no rebase: world z grows with `s`. Precision stays within
   the requirement below `S_PRECISION_LIMIT` (F4). If `s` reaches it (`s >= S_PRECISION_LIMIT`), Tube Track logs one
   warning per run (debug builds) and changes nothing else. If on-device testing shows
   jitter, the fallback is a treadmill (ball and camera fixed on z, segments positioned
   from `s` each frame); rule 1 keeps that change local to Tube Track.
9. **Seams.** A seam pattern is a `SeamPattern` resource owned by Tube Track: `n_seams`
   (integer seams per segment). Seams are a **flat shading band** (a normal tilt and an albedo shift
   inside the contrast band below) with **no geometric relief** (art-director ruling 2026-09-20): a
   raised lip of 0.05-0.08 u would clip the ball, which floats at most 0.0144 u above the faceted
   surface (F7), and would break the tube silhouette. `MapConfig.seam_pattern_id`
   selects one; Environment & Theming owns colors and materials. Seam spacing is `SP = L / n_seams`
   (F5). Seams sit at fixed `s` positions in segment-local space, so they stream past at the
   ball's speed and give the sense of speed while the tube is static on screen (art bible
   section 3d). Seams never change the tube's silhouette enough to read as a hazard.
   **Comfort:** the seam frequency at `v_max` is at most `SEAM_HZ_MAX` = 3 Hz (F5, this caps
   `n_seams`), so the seam pattern never produces more than 3 luminance flashes per second (the
   WCAG 2.3.1 general flash threshold; the art bible cap is also 3 per second). **Contrast:** seams
   are **lighter** than the tube. The seam/tube contrast (WCAG luminance ratio, art bible
   convention) stays within [`SEAM_CONTRAST_MIN`, `SEAM_CONTRAST_MAX`] = [1.15, 1.25], the floor
   measured in a still frame (the art bible's Mood state 3 changes chroma only, not value, so there
   is no compression term). **The ceiling 1.25 is an art-director ruling (2026-09-20), not yet
   validated on a device; the floor 1.15 is still a guess until AC-26.** Hazard, ball and pickup
   are all darker than the tube (luminance about 0.08, 0.08 and 0.12 against 0.49), so a lighter
   seam only raises the object-on-seam ratios (hazard/seam is about 5.2 at ratio 1.25): the art bible
   floors (hazard/seam and ball/seam at least 4:1, pickup/seam at least 3:1) guard only against a
   seam darker than the tube and never bind a lighter one. Two things bind the ceiling: the seam
   luminance stays below the map's darkest sky value (Haze Top, 0.635 on Map 1, a ratio of 1.27; 1.25
   leaves margin, seam about 0.625), so a seam never erases the tube/sky contour; and the rim-white
   near-miss ring stays readable across a seam (rim/seam is 1.83 divided by the ratio: 1.47 at
   1.25, against 1.22 at 1.5). A
   runtime multiplier `seam_contrast_scale` in [0, 1] from Settings & Accessibility
   (reduced motion) scales seam contrast; at 0 the seams match the tube surface: reduced motion
   outranks the speed cue, which the other cues carry.
10. **Deterministic.** Given the same `MapConfig` and segment index, segment content is
    identical. Tube Track uses no randomness.
11. **Idle scroll.** When no run is active (menu), Tube Track scrolls slowly at
    `IDLE_SCROLL_SPEED` without a ball so the tube is not dead (art bible: "tube idles slowly");
    this scroll does not count as run distance. **Idle window:** Idle always holds a primed window
    `-B .. A` (segment 0 is current, because `s_idle` stays in `[0, L)`). Entering Idle, by
    `load_map()` or by `to_idle()` from Running, Paused or Ended, is a synchronous operation like
    `begin_run()`: it sets `s_idle = 0`, discards the run's `s`, re-targets all N slots through
    `slot_binder` (`segment_index` `-B .. A`), emits `window_primed(-B, A)`, then
    `state_changed`. The window never moves in Idle, so the idle scroll emits no `window_primed`
    or `segment_*` signal; only the view's seam phase changes. It is the internal step `idle_step(dt)` of the Idle
    state (F8), driven by the view node's own per-frame `dt` (Run State's `tick()` returns 0 in
    Menu, Run State Open Question 17) and clamped to the shared `t_lat`. `s_idle` is wrapped into
    `[0, L)` (F8), so the seam pattern needs no other handling (seams repeat every `SP`, which
    divides `L`; a non-periodic object such as the menu's lone hazard would jump by `L` at each
    wrap, see Open Question 16). Going from Idle to Running resets `s` to 0,
    which can shift the seam phase by up to `SP`; that jump is hidden by the menu-to-run
    transition (Open Question 9). How the idle scroll relates to the one lone hazard of Mood
    state 1 is decided with Environment & Theming and Menus (Open Question 16).
12. **No physics ownership.** Tube Track owns no physics bodies and no colliders. Whether
    the ball and hazards are physics bodies or use analytic (theta, s, h) overlap tests is
    decided in the physics/collision ADR (Open Question 5).

**Structure (required by the project's coding standards: data-driven, injectable,
unit-testable).** Not an autoload.
- `TubeConfig`: a `Resource` holding every knob and the `MapConfig` fields Tube Track reads;
  `validate()` returns the list of failed constraints as stable failure codes (rule "Map
  validation" in Edge Cases).
- `TubeMath`: static functions on a `RefCounted` class (`wrap_angle` and `delta_theta` (F1; not
  named `wrap`, a GDScript global function whose unqualified call would not parse), F2, F3, F4,
  F5, F6, F7, `idle_step` (F8), F9 and `P`). Every function that can log takes a
  `log: Callable(level, message)` argument.
- `TubeWindow`: a `RefCounted` state machine that owns the window and emits the signals; it takes
  a `TubeConfig`, a **log sink** (`Callable`) and a `slot_binder`, a `Callable` with the contract
  `(slot_index: int, segment_index: int) -> void` (GDScript has no typed Callable signature, so
  this is documented, not enforced) that it calls once per slot re-targeted, with
  `slot_index = posmod(segment_index, N)` (an int from 0 to N - 1, not an object), so tests can
  count warnings and errors and observe re-targeting. The re-entrancy guard covers every emission (`begin_run`, `pause`, `advance`,
  `state_changed`). The core logs every rejected input; the production sink rate-limits repeated
  identical errors to one per second, so the core stays deterministic.
- `TubeTrack`: a thin `Node3D` view that owns meshes and materials, forwards signals and is
  injected into Ball Movement, Camera and Obstacle System.

### States and Transitions

| State | Meaning | Tube Track does |
|-------|---------|-----------------|
| Uninitialized | No map loaded | Nothing |
| Idle | Menu, no run | Holds the primed window `-B .. A` at `s_idle`; scrolls slowly (rule 11) |
| Running | Run in progress | Recycles slots as `advance(s)` moves `s` |
| Paused | Run paused | Holds still; keeps the window and `s` |
| Ended | Run ended by a hit | Holds still; keeps the window and `s` |

`begin_run()` is a **synchronous operation**, not a state: it resets `s` to 0, places the
window `-B .. A` around it in one call, emits `window_primed`, and enters Running. `load_map()` and
`to_idle()` are synchronous operations of the same kind (rule 11, Idle window): each primes
`-B .. A` at `s_idle = 0`, emits `window_primed`, then enters Idle. A `load_map()` that fails
validation does none of this: no binder call, no signal, state stays Uninitialized.

Accepted transitions (16 of the 40 state/event pairs). Every other pair is rejected: no
state change, no signal, one error in the log sink.

| From | Event | To |
|------|-------|----|
| Uninitialized | `load_map(config)` | Idle (stays Uninitialized and reports errors if `validate()` fails) |
| Idle | `begin_run()` | Running |
| Idle | `unload_map()` | Uninitialized |
| Running | `advance(s)` | Running |
| Running | `pause()` | Paused |
| Running | `end_run()` | Ended |
| Running | `begin_run()` (restart mid-run) | Running |
| Running | `to_idle()` | Idle |
| Running | `unload_map()` | Uninitialized |
| Paused | `resume()` | Running (`s` unchanged) |
| Paused | `begin_run()` | Running |
| Paused | `to_idle()` | Idle |
| Paused | `unload_map()` | Uninitialized |
| Ended | `begin_run()` (instant restart) | Running |
| Ended | `to_idle()` | Idle |
| Ended | `unload_map()` | Uninitialized |

Events: `load_map`, `unload_map`, `begin_run`, `advance`, `pause`, `resume`, `end_run`,
`to_idle` (8 events x 5 states = 40 pairs). The idle scroll is an internal step of the
Idle state, not an external event. `resume()` in Ended is rejected: a run that ended in a
hit cannot be resumed. These five states describe the lifecycle of the window and of the map,
not the phase of play: Run State & Restart is the only owner of the phase (its rule 1), and Tube
Track's adapter follows it. `state_changed` is emitted only when the state changes, so
`begin_run()` from Running re-primes and emits `window_primed` only.

### Interactions with Other Systems

All interfaces below are **provisional** until the other systems have GDDs.

**Signals emitted by Tube Track** (integers only, no Array or Dictionary payloads):
- `state_changed(new_state, old_state)`: after the effects of the transition are complete. The state
  variable changes just before this emission, so a handler of the `window_primed` that
  `begin_run()` emits first sees the final window and the old state.
- `window_primed(first_index, last_index)`: emitted by `load_map()`, `to_idle()`, `begin_run()`
  and by a re-prime (F2). It is a **reset**: consumers discard everything tied to the old window and
  populate the range as needed (on `to_idle()` this is how Obstacle System learns the run's hazards
  are gone). No `segment_entered_window` or `segment_left_window` is emitted for a priming. Order
  within `load_map()`, `to_idle()` and `begin_run()`: `window_primed`, then `state_changed` (only
  when the state changes).
- `segment_entered_window(index)` and `segment_left_window(index)`: emitted for each
  recycle, `left` for the rearmost index first, then `entered` for the new far index, in
  increasing index order when several recycles happen in one call.

| System | Direction | Data / events | Interface owner |
|--------|-----------|---------------|-----------------|
| Run State & Restart | in | events that map to `begin_run`, `pause`, `resume`, `end_run`, `to_idle` (names provisional) | Run State defines the events |
| Ball Movement | in / out | in: `advance(s)` each frame (single caller). out: `P`, `R`, surface normal, `delta_theta`, state | Tube Track owns the frame; Ball Movement owns speed, `v_max` and the `s` value |
| Obstacle System | out | the frame; `window_primed`, `segment_entered_window`, `segment_left_window`, `state_changed` | Tube Track owns the events; Obstacle System owns hazard lifecycle |
| Pattern & Difficulty | out | the same events; `SEGMENT_LENGTH`; the guarantee that the ahead window reaches beyond `F` (rule 7); in: `T_dodge_worst` for F9 | as above |
| Camera | out / in | out: `R`, the tube axis; in: `rear_extent` and `camera_distance` (`d_cam`, the camera-to-ball distance) as configuration values published at map load | Camera owns its offsets, `rear_extent` and `camera_distance` |
| Environment & Theming | in (via `MapConfig`) | `seam_pattern_id`, `fog_mode`, `fog_depth_begin`, `fog_end_distance` (`F`, radial from the camera), `fog_depth_curve`, `fog_density`, `fog_color`, `readable_distance` (`F_read`, radial from the camera); Theming applies colors and materials; owns fog range, the readable criterion and speed-driven fog | Theming owns the values; Tube Track documents the fields it reads and validates derived constraints |
| Settings & Accessibility | in | `seam_contrast_scale` (reduced motion), soft dependency | Settings owns the value |
| Juice & Feedback | out | the frame for surface-anchored effects (ring pulse at the ball's position) | Juice owns the effects |

Provisional assumptions to re-check when the other GDDs exist: whether Pattern &
Difficulty places chunks in whole numbers of segments and treats indices `-B .. -1` as
hazard-free; and that `s` is an input, not a code dependency on Ball Movement. (Run State's
event names and who calls `begin_run()` are settled in `run-state-restart.md`.)

## Formulas

All worked examples use the proposed defaults (R = 3.0, D = 0.8, L = 12, A = 6, B = 2,
n_seams = 1, F = 48, F_read = 46, d_cam = 8, v_max = 25, t_lat = 0.1). Defaults are proposals; see
Tuning Knobs. (`F_read` was 40 before review 3; with `d_cam` in F9 that gives 1.28 s, below
`T_VIS_MIN`. 46 and 48 leave a 2 u ramp, which is a fog wall: both are placeholders until
Environment & Theming and the art-director set the readable criterion, Open Question 10.)
Numbers marked "guess" have no measured basis yet. **`v_max = 25` is an unvalidated
external contract** (Ball Movement owns the real value; the concept prototype ran at 6.0
u/s), and every example that uses it is "at v_max = 25". Tube Track asserts its
v_max-dependent constraints when a map loads.

**Variables**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Angle | a, b, theta | float (64-bit) | any finite | angle in radians |
| Distance along tube | s | float (64-bit) | >= -B*L | distance since run start; negative values are the tube behind the start |
| Segment length | L | float | integer values 6-24 and at least `L_min = ceil(v_max / SEAM_HZ_MAX)` (F5) | `SEGMENT_LENGTH` |
| Seams per segment | n_seams | int | >= 1 | `SeamPattern.n_seams` |
| Seam spacing | SP | float | L / n_seams | derived, never set directly |
| Segments ahead / behind | A, B | int | A <= A_MAX = 12, B <= B_MAX = 3 | `SEGMENTS_AHEAD` / `SEGMENTS_BEHIND` |
| Pool size | N | int | A + B + 1 <= N_MAX = 16 | number of window slots |
| Fog end distance | F | float | derived range (F3) | `fog_depth_end`, radial distance from the camera eye; largest fog end distance across speeds; opacity 100% there (needs `fog_density = 1.0` and depth fog mode); used only for the window size |
| Readable distance | F_read | float | external contract, guess | radial distance from the camera eye at `v_max` up to which a hazard is still readable through fog; the criterion (for example a hazard/tube contrast floor after fog blending) is set by Environment & Theming and the art-director, not by Tube Track (F9, Open Question 10) |
| Camera distance | d_cam | float | 8 (guess; Camera owns) | distance from the camera eye to the ball, published by Camera at map load; converts `F_read` to a distance ahead of the ball (F9); the same estimate as F4's `d` |
| Max speed | v_max | float | finite and > 0; 25 u/s (confirmed as design intent 2026-09-22, provisional pending the device spike) | Ball Movement owns the real value |
| Step margin | t_lat | float | 0.05-0.25 s, default 0.1 (guess) | the shared `DT_MAX`, the caller's per-frame time-step clamp (Run State & Restart uses it in its F1; its owner is settled in the Ball Movement GDD, Run State Open Question 9) |
| Camera rear extent | C_b | float | 6 (Camera owns) | how far behind the ball the camera can see |
| Camera slack | M_cam | float | 2 (guess) | safety margin |
| Tube radius | R | float | 2.5-3.3 (guess) | `TUBE_RADIUS` |
| Ball diameter | D | float | 0.8 (Ball Movement owns) | ball diameter |
| Seam frequency | f_seam | float | v / SP | seams passing the ball per second |

*Formulas F4 and F5 of the earlier draft (render-origin rebase) were removed with the
rebase; the remaining formulas are numbered F1-F9.*

**F1. Angle wrap**
`wrap_angle(a) = fposmod(a + PI, TAU) - PI`, then if the result is at least PI subtract TAU (the
guard is needed: for `a` = the double just below `-PI` the plain formula gives `+PI`; verified on
Godot 4.7.2). `delta_theta(a, b) = wrap_angle(a - b)`. The name is not `wrap`: that is a GDScript
global function `wrap(value, min, max)` and an unqualified call does not parse (verified). Output
range: [-PI, PI).
Example: wrap_angle(PI) = -PI; wrap_angle(-PI) = -PI; wrap_angle(3*PI/2) = -PI/2. NaN or infinite
input returns 0 and logs an error. Two exactly opposite angles give a result of magnitude PI, but
the sign depends on rounding of `a - b` (for `delta_theta(0, PI)` it is exactly -PI, for other
values it can be +PI - 1 ulp), so systems must not rely on that sign.

**F2. Segment index and recycling**
`i = floori(s / L)`; `slot = posmod(i, N)` with `N = A + B + 1`. The window is
[i - B, i + A]. When i advances from k to k + 1, segment `k - B` is recycled to become
segment `k + 1 + A`.
Example: s = 11.999 gives 0; s = 12 gives 1; s = -1 gives -1. Use `floori` and
`posmod`, never `int()` or `%`, which are off by one for s < 0. A jump of `N` or more
segments in one `advance` re-primes the window (`window_primed`) instead of looping; a
jump of `N - 1` or fewer segments recycles that many segments. `L` is integer-valued so `i * L` is
exact, and `floori(s / L)` was checked on Godot 4.7.2 not to round up to the next index for `s` one
ulp below a boundary (a test at the literal `11.999999999999998`, the double just below 12, keeps it
that way; GDScript 4.7.2 has no `nextafter`). The same holds for L = 6 to 24 and indices -3 to 3999
(228,171 checks, review 3).

**F3. Window sizes**
`A >= ceil((F + v_max * t_lat) / L) + 1` and `B >= ceil((C_b + M_cam) / L)`;
`A <= A_MAX`, `B <= B_MAX`, `N <= N_MAX`. Output: integers. Recycle rate is `v_max / L`
per second (2.1 at L = 12, 4.2 at L = 6).
Why each term: recycling is synchronous (rule 6), so after any call the far end is at
least `A * L` ahead of `s`. `v_max * t_lat` is the most `s` can move in one clamped step,
and the `+1` is one spare segment (`L / v_max` = 0.48 s at defaults) so consumers of
`segment_entered_window` can spread their spawn work over several frames before a new
segment can come inside the fog distance.
Examples at L = 12, v_max = 25, t_lat = 0.1, C_b = 6, M_cam = 2 (B >= 1, default B = 2):

| L | F | A required | Note |
|---|---|-----------|------|
| 12 | 37.5 | 5 | F3 alone; the minimum loadable F at v_max = 25 is 45.5 (F9, `d_cam` = 8), which also gives A = 5 |
| 12 | 48 | 6 | default; horizon 72 against fog 48; N = 9 |
| 12 | 129.5 | 12 | maximum F that fits A_MAX |
| 6 | 48 | 10 | B >= 2 at L = 6 |
| 6 | 100 | 19 | rejected (> A_MAX) |
| 24 | 37.5 | 3 | B >= 1 |

These rows test F3 alone. Some are not loadable maps: F9 rejects any `F` below 45.5 at v_max = 25
and `d_cam` = 8 (rows with F = 37.5), and L = 6 is below `L_min` = 9 (F5).

**F4. Precision (no rebase in the MVP)**
`ulp(m) = 2^(floor(log2(m)) - 23)` for a 32-bit float of magnitude m.
*Requirement (proposal):* world-position error of at most 0.5 px at the ball's distance.
One pixel is about `2 * d * tan(FOV/2) / H` = 0.0048 u at d = 8 u, 60 degrees vertical FOV
and 1920 px (estimate; Camera and Platform Services own the real values), so 0.5 px is
0.0024 u.
*Error model:* 2 ulp (one rounding for the object's translation and one for the camera's).
`S_PRECISION_LIMIT = 2^14 = 16384` is the first power of two at which `2 * ulp(s)` exceeds 0.0024,
used as an **exclusive** bound: for `s` in [8192, 16384) the ulp is 2^-10 and `2 * ulp` is 0.00195,
at 16384 it is 0.0039. So the safe zone is `s < 16384` and the warning fires for `s >= 16384`. At
v_max = 25 that is 655 s; planned runs are 1-5 minutes.
*Conservative model:* if the real error is 8 ulp, the limit is `2^12 = 4096` (164 s at
v_max = 25, longer at average speeds). That is why Open Question 13 requires an on-device
check and rule 8 names the treadmill as the fallback.
Example: ulp(700) = 6.1e-5; ulp(7500) = 4.9e-4; ulp(16384) = 1.95e-3; ulp(1e6) = 0.0625.

**F5. Seam spacing and frequency**
`SP = L / n_seams` with `n_seams` an integer. Seam positions:
`seam_s(i, j) = i * L + (j + 0.5) * SP` for `j = 0 .. n_seams - 1`, baked in segment-local
space. Frequency `f_seam = v_max / SP`. Constraint: `f_seam <= SEAM_HZ_MAX` (3 Hz by default,
safe range 2.1-3.0): at most 3 luminance flashes per second (the WCAG 2.3.1 general flash
threshold and the art bible cap). An earlier draft used 8.5 Hz, which a review found unsafe once
seam contrast reaches the levels of rule 9. The aliasing bound `f_seam <= f_min / 2` (f_min = 30
fps gives 15 Hz) is implied. Seam stripes must be at least one frame's travel wide at the lowest
supported frame rate or they strobe (Open Question 17).
Example at L = 12, v_max = 25: n_seams = 1 gives SP = 12, a seam at 6 and f_seam = 2.08 Hz
(default, accepted); n_seams = 2 gives SP = 6 and 4.17 Hz (rejected at the 3 Hz cap); n_seams = 3,
4, 5 give 6.25, 8.33, 10.4 Hz (rejected). Because SP divides L by construction, gaps are uniform
across segment boundaries. Validation reports the largest `n_seams` allowed for the map's `L` and
`v_max`, `floor(SEAM_HZ_MAX * L / v_max)`.
**Shortest loadable segment.** `n_seams >= 1` makes the lowest seam frequency `v_max / L`, so a map
loads only if `L >= L_min = ceil(v_max / SEAM_HZ_MAX)`: 9 at v_max = 25 and 3 Hz (L 6 to 8 can never
load), 12 at 2.1 Hz, 14 at v_max = 40. Below `L_min` the validator reports `L_INVALID` with `L_min`
printed and does not also report `SEAM_HZ`; at or above it the largest allowed `n_seams` is at
least 1. Zero seams is not a map option: reduced motion reaches flat seams through the user setting
`seam_contrast_scale` (rule 9), and a map author must not be able to ship no speed cue silently.

**F6. Lane capacity around the tube**
`w = 2 * asin(D / (2 * (R + D/2)))` and
`N_lanes = floor(PI / asin(D / (2 * (R + D/2))))`. Informational for the Obstacle System
and Pattern & Difficulty GDDs, which own difficulty. Defined for `R > 0` (validation
restricts `R` to the safe range).
Example: R = 3, D = 0.8 gives w = 13.5 degrees and 26 lanes; R = 2.5 gives 22 lanes.
Lane count is not the real resolution limit: tilt resolution and angular size are
(Open Question 7).

**F7. Facet gap**
`gap(R) = R * (1 - cos(PI / 32))`, the largest height the ball's centre circle floats
above the faceted surface. Requirement: `gap <= 0.02 * D`.
Example: R = 3.0 gives 0.0144 (1.8% of D); R = 3.3 gives 0.0159 (1.99%); R = 3.4 gives
0.0164 (2.05%, rejected), which is why the `R` range ends at 3.3.

**F8. Idle scroll**
`s_idle = fposmod(s_idle + v_idle * step, L)` with `step = clamp(dt, 0, t_lat)` if `dt` is finite,
else 0 (`t_lat` is the shared `DT_MAX`). Does not count as run `s`. It is the pure static function
`TubeMath.idle_step(s_idle, v_idle, dt, t_lat, L)`, called by the Idle state's `tick_idle(dt)`.
Example: v_idle = 1.5 u/s gives 0.025 u per frame at 60 FPS, one seam every 8 s at n_seams = 1
(SP = 12). Negative, NaN or infinite `dt` adds 0.

**F9. Hazard visibility time**
`T_vis = (F_read - d_cam) / v_max`, validated as `T_vis >= T_VIS_MIN` (1.5 s, guess). `F_read` is
the radial distance from the camera eye up to which a hazard is still readable at `v_max`; the
camera is `d_cam` behind the ball (8 u, guess, Camera owns it), so a hazard at `F_read` is about
`F_read - d_cam` ahead of the ball and `T_vis` is the time until it reaches the ball. (Before review
3 the formula was `F_read / v_max`, which treated `F_read` as measured from the ball and
overstated `T_vis` by `d_cam / v_max` = 0.32 s at defaults, more than the 0.15 s margin in
`T_VIS_MIN`.) **The readable criterion is not Tube Track's to define.** The art bible's hazard/tube
contrast is 4.17:1 against a 4:1 floor, only about 4% of headroom, so a "still at least 4:1 after fog
blending" criterion puts `F_read` at roughly the fog start and any fog that ramps more than a few
units reads as a wall (hazard/tube falls below 4:1 at about 1% fog, 3:1 at about 8%, 2:1 at about
24%; review 3 figures). Environment & Theming and the art-director set the criterion (for example
a looser floor) and supply `F_read`; F9 stays a budget with a provisional input (Open Question 10,
which also records a fade-time test, `(F - F_read) / v_max` at least a minimum, as the mechanism
that would prevent a fog wall). `F_read` replaces the fog end `F` in this formula: `F` is where fog
is 100% opaque and only says that the
end of the tube is hidden (F3); a hazard is unreadable well before that (a review computed
hazard/tube contrast falling from 4.14 at 0% fog to 1.96 at 25%), and fog pulls nearer as speed
rises, so dividing the largest `F` by `v_max` overstated the time at exactly the speed that
matters. F9 is a budget that Pattern & Difficulty consumes, not a fairness proof: the worst
dodge (180 degrees, the gap on the hidden far side) is limited by the tube body and the camera
height, and that reveal time, `T_reveal`, is supplied by Camera (Open Question 7).
Derivation of `T_VIS_MIN` (guess, revised 2026-09-22 to consume Ball Movement's confirmed values):
Ball Movement's `T_DODGE_180 = T(PI, 0.05)` = 1.064 s (its F5a; supersedes the 1.05 rad/s-cap-only
prototype assumption), plus a simple visual reaction of 0.25 s (the value Run State uses), plus an
input-pipeline latency of about 0.11 s (Ball Movement F5a and F5b: sensor, poll frame, display
frames and Tilt Input's own filter settling, layered ahead of `BALL_LAG_TAU` and not double-counting
it — `BALL_LAG_TAU`'s own contribution is already inside `T_DODGE_180`), giving about 1.42 s and a
margin against the 1.5 s default of about 0.08 s (not the earlier, unverified 0.10 s, which had
substituted a latency figure not traceable to Ball Movement's own numbers). Without the margin the
sum is about 1.064 + 0.25 + 0.11 = 1.43 s, which is the floor of the `T_VIS_MIN` safe range
(raised from 1.35 s, which was derived from the old 1.05 s / 0.05 s numbers and is stale under this
derivation — a `T_VIS_MIN` inside the old 1.35-2.5 range but below 1.43 s would have passed
validation while sitting under the real safe minimum). Pattern & Difficulty will supply the real
`T_dodge_worst` and the sum is redone then (Open Question 8).
Validation: `F_read >= T_VIS_MIN * v_max + d_cam`, `F >= F_read`, and `F <= (A_MAX - 1) * L -
v_max * t_lat` (F3). If the range `[T_VIS_MIN * v_max + d_cam, (A_MAX - 1) * L - v_max * t_lat]` is
empty for the map's `L`, `v_max`, `t_lat` and `d_cam`, the validator reports one `NO_VALID_F` error
with the range printed, and does not also report `VISIBILITY` or `A_TOO_LARGE`, which are
consequences of the empty range.
Example at v_max = 25, L = 12, d_cam = 8, t_lat = 0.1: F_min = 1.5 * 25 + 8 = 45.5 and F_max =
129.5; `F_read` = 20 gives T_vis = (20 - 8) / 25 = 0.48 s and is rejected; `F_read` = 45 gives 1.48 s
and is rejected; `F_read` = 46 (F = 48, the default) gives 1.52 s.

## Edge Cases

**Distance `s` and the window**
- **If `s` decreases between frames** (bug or negative speed): keep
  `s = max(s, s_previous)`, ignore the decrease, and log one warning in debug builds. An `s`
  equal to the previous value is not a decrease: in Running, `advance(s)` with an unchanged `s` is a
  silent no-op (no warning, no signal).
- **If `s` jumps forward by N segments or more in one `advance`** (a bug or a debug teleport:
  Run State's step clamp and stall guard prevent it in play): re-prime the window at the new
  segment (`window_primed(first, last)`); no `segment_entered_window` is emitted for skipped
  segments, and consumers treat `window_primed` as a reset. A jump of fewer than N segments
  recycles each one.
- **If `s` equals a segment boundary exactly** (`s = i * L`): the new segment counts as
  entered (the lower bound is inclusive) and is recycled exactly once.
- **If `s` is negative** (behind the start point): valid down to `-B * L`; use `floori`
  and `posmod`. After `begin_run()` the segments `-B .. -1` already exist.
- **If `advance(s)` is called in any state except Running**: it is rejected (one error).
  The ball may only advance `s` once Tube Track is Running.
- **If `s` reaches `S_PRECISION_LIMIT`** (`s >= S_PRECISION_LIMIT`): one warning per run in debug builds; nothing
  else changes (rule 8).

**Angles, heights and invalid values**
- **If theta is NaN or infinite**: `delta_theta` returns 0 and the conversion function
  returns the point at theta = 0; both log an error. NaN must not spread into transforms.
- **If two angles are exactly opposite**: the result has magnitude PI and an arbitrary
  sign; no system may rely on that sign.
- **If `h < 0`**: clamp `h = 0` and log a warning (nothing sits inside the tube).
- **If `s` is NaN or infinite**: ignore that `advance`, keep the previous `s`, and log an
  error. **If `h` is NaN**: clamp `h = 0` and log an error. The core logs every rejected input; the
  production log sink rate-limits repeated identical errors to one per second.

**Map validation** (map load fails, Tube Track stays Uninitialized and reports every failed
constraint by a stable failure code: `NOT_FINITE`, `NOT_POSITIVE`, `VISIBILITY`, `FOG_BEFORE_READ`,
`FOG_DENSITY`, `FOG_MODE`, `FOG_RANGE`, `A_TOO_LARGE`, `A_TOO_SMALL`, `A_OUT_OF_RANGE`,
`B_OUT_OF_RANGE`, `L_INVALID`, `SEAM_HZ`, `R_RANGE`, `NO_VALID_F`; it never computes
`A = 0`). Every numeric input (`F`, `F_read`, `d_cam`, `fog_depth_begin`, `fog_depth_curve`,
`v_max`, `t_lat`, `C_b`, `M_cam`, `L`, `R`, `D`, `n_seams`, `fog_density`) is first checked
for finiteness and then tested as `not (x >= lo and x <= hi)`, so NaN and infinity fail and never
pass a `< min` test. **Reporting rules** (so the returned code set is exact): a non-finite input
reports `NOT_FINITE` and a non-positive one `NOT_POSITIVE`, and every derived check that uses that
input is skipped; `A_TOO_SMALL` is reported only when the required `A` is at most `A_MAX`; an empty
range of F reports `NO_VALID_F` and suppresses `VISIBILITY` and `A_TOO_LARGE`; below `L_min` only
`L_INVALID` is reported, not `SEAM_HZ`. Tests compare the code set, not an ordered list.
- `F`, `F_read`, `d_cam` or `fog_depth_curve` is non-finite or not positive; `v_max` is not finite
  and greater than 0; `F_read - d_cam < T_VIS_MIN * v_max` (`VISIBILITY`); `F < F_read`
  (`FOG_BEFORE_READ`); `fog_density` is not 1.0 (`FOG_DENSITY`); `fog_mode` is not depth
  (`FOG_MODE`); `fog_depth_begin >= F` (`FOG_RANGE`); the required `A` from F3 exceeds `A_MAX`
  (`A_TOO_LARGE`); the configured `A` is below the required `A` (`A_TOO_SMALL`); the configured `A`
  is not an integer in [1, `A_MAX`] (`A_OUT_OF_RANGE`); the range of F is empty (`NO_VALID_F`,
  printed with the range).
- `B` is below `ceil((C_b + M_cam) / L)` or above `B_MAX`.
- `L` is not an integer in [6, 24] or is below `L_min = ceil(v_max / SEAM_HZ_MAX)` (`L_INVALID`, the
  error prints `L_min`); `n_seams` is not an integer >= 1; `f_seam` exceeds `SEAM_HZ_MAX` at
  `v_max` (`SEAM_HZ`, the error prints the largest allowed `n_seams`, at least 1 once `L` passes).
- `R` is outside [2.5, 3.3] or `gap(R)` (F7) is above `0.02 * D` for the real `D`.

**Simultaneous events and state**
- **If `begin_run()` is called while Running, Paused or Ended**: the window is re-primed
  from scratch (idempotent); `s` is 0 and no slot is duplicated. There are no pending
  recycles to discard, because recycling is synchronous.
- **If a signal handler calls a mutating method** (`advance`, `begin_run`, `pause`, ...):
  the call is rejected with one error and state is unchanged.
- **If `pause()` arrives**: it takes effect at once in Running; in any other state it is
  rejected.
- **If the app is backgrounded and resumed mid-run**: Run State pauses (Paused); on
  resume, Paused -> Running with `s` unchanged and no catch-up.
- **If Idle runs for a long time** (menu left open for minutes): `s_idle` stays in
  `[0, L)` (F8); nothing accumulates.
- **If Idle -> Running**: the seam phase can jump by up to `SP`; hide it under the
  menu-to-run transition.
- **If `to_idle()` arrives in Running, Paused or Ended**: the run's `s` is discarded, `s_idle` is 0,
  the window is re-primed at `-B .. A` (N binder calls) and one `window_primed(-B, A)` is emitted,
  then `state_changed`. The seam phase can jump by up to `SP` here too (Open Question 9).
- **If `load_map()` succeeds**: the window is primed at `-B .. A` before Idle is entered, so the
  menu never shows an unbound tube.
- **If the map is unloaded while Running**: go to Uninitialized, release every slot binding,
  and emit `state_changed`.

## Dependencies

Tube Track has **no system dependencies** (Core layer). It has data inputs, which
are contracts rather than code dependencies, and several dependents.

### Data inputs

| Input | Supplied by | Used for | Note |
|-------|-------------|----------|------|
| `s` via `advance(s)` (traveller distance) | Ball Movement during a run; Tube Track's own idle scroll in the menu | Drives segment recycling | Ball Movement uses Tube Track's frame, but Tube Track only receives a number, so there is no code cycle |
| `v_max` | Ball Movement (external contract) | F3, F5, F9 validation at map load | Confirmed as design intent 2026-09-22 (ball-movement.md Open Question 12); still provisional pending BM-1/BM-2 and Environment & Theming's `F_read` |
| `rear_extent`, `camera_distance` (`d_cam`) | Camera, as configuration values published when a map loads | Checks `SEGMENTS_BEHIND` (F3); converts `F_read` to a distance ahead of the ball (F9) | Config values, not runtime calls, so Camera can depend on Tube Track without a cycle |
| `MapConfig`: `seam_pattern_id`, `fog_mode`, `fog_depth_begin`, `fog_end_distance`, `fog_depth_curve`, `fog_density`, `fog_color`, `readable_distance` (`F_read`) | Environment & Theming (map data) | Seam pattern; horizon and visibility checks (F3, F9, rule 7) | Theming owns the values; `fog_mode` must be depth and `fog_density` 1.0; `fog_end_distance` and `F_read` are radial distances from the camera eye; `F_read` and its criterion are provisional until Theming, the art-director and Camera exist |
| `seam_contrast_scale` | Settings & Accessibility | Reduced-motion scaling of seams (rule 9) | Soft dependency |
| Run State events (`run_reset`, `run_paused`, `run_resumed`, `run_ended`, entering Menu) | Run State & Restart | State transitions | Loose signal coupling; Run State does not know Tube Track. A thin adapter owned by Tube Track maps them to `load_map`, `begin_run`, `pause`, `resume`, `end_run` and `to_idle`; event names are defined in the Run State & Restart GDD |

### Dependents

| System | Type | What it needs from Tube Track |
|--------|------|-------------------------------|
| Ball Movement | Hard | The frame (theta, s, h to world), `R`, surface normal, `delta_theta`, state |
| Obstacle System | Hard | The frame; `window_primed`, `segment_entered_window`, `segment_left_window` |
| Pattern & Difficulty | Hard | Segment events; the horizon guarantee (rule 7); `SEGMENT_LENGTH` |
| Camera | Hard | `R`, the tube axis, the frame to orbit around |
| Environment & Theming | Hard | Segment material slots to apply color and fog; the `SeamPattern` format |
| Juice & Feedback | Soft | The frame for surface-anchored effects |
| Settings & Accessibility | Soft | The `seam_contrast_scale` hook |

### Bidirectional consistency

The systems index lists Tube Track as a dependency of Ball Movement, Obstacle System,
Pattern & Difficulty, Camera, Environment & Theming and Juice & Feedback. Settings &
Accessibility is a soft dependent, and its index row (19) already lists Tube Track (soft).
Each dependent's GDD must list Tube Track as a dependency when it is written.

## Tuning Knobs

All defaults are proposals or guesses with reasoning, not measured on a real device.
Values that live in other systems are not duplicated here. Every knob lives in the
`TubeConfig` resource (data-driven).

| Knob | Default | Safe range | Affects | Too high | Too low |
|------|---------|------------|---------|----------|---------|
| `TUBE_RADIUS` (R) | 3.0 | 2.5-3.3 (guess) and `gap(R) <= 0.02 * D` for the real D (F7) | Lanes (F6), dodge ease, camera orbit radius, facet gap (F7) | Facet gap above 2% of D at R > 3.3; lanes finer than tilt resolution | Few lanes; the ball takes up much of the circumference |
| `SEGMENT_LENGTH` (L) | 12 | integer 6-24 and at least `ceil(v_max / SEAM_HZ_MAX)` (F5): 9 at v_max = 25 and 3 Hz, 12 at 2.1 Hz | Recycle rate (`v_max / L` per second), window size, the lowest seam frequency | Larger window and more spawn work per recycle | Recycling more often; A may exceed A_MAX; below the floor no `n_seams` fits the cap and the map does not load |
| `SEGMENTS_AHEAD` (A) | 6 (from F3) | required value from F3 up to 12 | Horizon length | Spawn and draw cost | The far end of the tube becomes visible (breaks rule 7) |
| `SEGMENTS_BEHIND` (B) | 2 | `ceil((C_b + M_cam) / L)` to 3 | Protection against pop-in behind the camera | Waste | Segments vanish while still in view |
| `n_seams` | 1 (at L = 12, v_max = 25) | integer, `L / n_seams` giving `f_seam <= SEAM_HZ_MAX` at v_max | Seam rhythm, sense of speed | Flicker, discomfort, more than 3 flashes per second | Weak sense of speed (one seam per 12 u at the default) |
| `SEAM_HZ_MAX` | 3 | 2.1-3.0 (the upper bound is the 3 flashes per second cap; the lower bound keeps the default `n_seams = 1` loadable at L = 12, v_max = 25) | Comfort and flash-safety cap on seam frequency (F5) | More than 3 flashes per second: not allowed | Forces fewer seams; at 2.1 Hz only one seam per 12 u at v_max = 25 |
| `SEAM_CONTRAST_MIN` / `MAX` | 1.15 / 1.25 (floor a guess until AC-26; ceiling an art-director ruling 2026-09-20, device check pending) | floor >= 1.05 in a still frame; the ceiling keeps the seam below the map's darkest sky value and the rim-white ring readable (rule 9); the object-on-seam floors (hazard/seam and ball/seam >= 4:1, pickup/seam >= 3:1) guard only against a seam darker than the tube and never bind a lighter one (rule 9, Open Question 18); seams lighter than the tube | Seam visibility (rule 9, AC-26) | Seams compete with hazards; may erase the tube/sky contour and the rim-white ring | Seams invisible at speed |
| `seam_contrast_scale` | 1.0 | 0-1 (set by Settings) | Reduced-motion hook | n/a | Flat seams |
| `IDLE_SCROLL_SPEED` | 1.5 | 0.5-3 | Life in the menu | Menu motion competes with run energy | The tube looks dead |
| `T_VIS_MIN` | 1.5 s | 1.43-2.5 (guess; the floor is the derivation without its margin, 1.064 + 0.25 + 0.11, revised 2026-09-22 to Ball Movement's confirmed `T_DODGE_180` and latency; raised from 1.35, which was stale under the old 1.05/0.05 numbers) | Minimum hazard visibility time (F9), lower bound of `F_read` (`T_VIS_MIN * v_max + d_cam`) and so of `F` | Fog must be pushed far | Unfair surprises |
| `S_PRECISION_LIMIT` | 16384 | 4096-16384 | Where the precision warning fires (F4) | Jitter before the warning | Noisy warnings |
| `RECYCLE_STEP_MARGIN` (t_lat) | 0.1 s (guess; the shared `DT_MAX`, its owner is settled in the Ball Movement GDD, Run State Open Question 9) | 0.05-0.25 (the range of the shared `DT_MAX`) | Window size (F3; at the default L, F and v_max the required A does not change inside this range); the caller's `dt` clamp; the idle-scroll step clamp (F8) | A larger window at other L or F | Not a window problem (recycling is synchronous): Run State clips hitches early and the run drifts slower than real time |
| `CAMERA_MARGIN` (M_cam) | 2 (guess) | 1-4 | `B` requirement (F3) | Waste | Segments vanish while in view |
| `A_MAX` / `B_MAX` / `N_MAX` | 12 / 3 / 16 | fixed caps (`N_MAX` = `A_MAX` + `B_MAX` + 1 is implied by the other two) | Sanity limits on the window | n/a | n/a |

**Sources of truth elsewhere** (not duplicated): `v_max` and ball diameter `D` (Ball
Movement), `rear_extent` / C_b and `camera_distance` / d_cam (Camera), `fog_end_distance` and its raw range
(`MapConfig`, Environment & Theming), `T_dodge_worst` (Pattern & Difficulty).

**Interactions between knobs**
- `A >= ceil((F + v_max * t_lat) / L) + 1`, so changing L, F, v_max or t_lat means
  recomputing A; the validator reports which cap is hit.
- `F_read` must satisfy F9 and `F` must be at least `F_read`, so a slower or faster `v_max` moves the allowed range of both.
- `n_seams` must give `f_seam <= SEAM_HZ_MAX` at `v_max`; changing `L` changes the valid
  `n_seams` values (SP = L / n_seams), and `L` must be at least `ceil(v_max / SEAM_HZ_MAX)` for any
  `n_seams` to fit (F5).
- Changing `R` affects the number of lanes (Obstacle System, Pattern & Difficulty), the facet
  gap and the camera orbit radius.

## Visual/Audio Requirements

**Visual**: follows the art bible. The tube is a flat-shaded 32-sided cylinder with
flat seams (a shading band, no geometric relief) and a clear sky band around its contour
(section 3d). Tube color is Mist Sage (#A9BFB0, luminance 0.49) with environment chroma
at most 0.05, and the fog color equals the sky color at the horizon (section 4). Seam
luminance stays above 0.10 (only hazards and the ball go below it) and seam/tube contrast
stays inside the band in rule 9; the seams are lighter than the tube and the tube must never rely on seams alone to carry speed.
Per-map palettes come from `MapConfig` through Environment & Theming. Tube Track creates no
effects itself; surface-anchored effects (such as the near-miss ring pulse) belong to Juice
& Feedback and are positioned with Tube Track's coordinate frame.

**Audio**: none. (The whoosh and other feedback sounds belong to Juice & Feedback.)

> **Asset Spec**: Visual requirements are defined. After the art bible is complete,
> run `/asset-spec system:tube-track` to produce per-asset specs.

## UI Requirements

None. Tube Track has no player-facing UI. (A developer-only debug overlay showing `s`,
the window indices and the state is optional and not a player requirement.)

## Acceptance Criteria

Test types: **[U]** automated unit test in `tests/unit/tube_track/` (GUT, BLOCKING), run
headless against the `RefCounted` logic core (`TubeMath`, `TubeWindow`, `TubeConfig`) with
test doubles for Camera, Ball and Obstacle, and an injected log sink so "one warning" is
countable; **[I]** integration test in `tests/integration/tube_track/` (BLOCKING);
**[V]** screenshot or playtest evidence in `production/qa/evidence/` (ADVISORY, needs a GPU
renderer, not `--headless`); **[P]** on-device performance measurement (ADVISORY; numeric
limits are set after the renderer ADR). Defaults: R = 3, D = 0.8, L = 12, n_seams = 1,
A = 6, B = 2, N = 9, F = 48, F_read = 46, d_cam = 8, v_max = 25, t_lat = 0.1. Numeric tolerance is 1e-6 unless
stated. No [U] or [I] test asserts wall-clock time. Test seam: every `TubeMath` function that can log takes a `log: Callable`; `TubeWindow` takes a log sink and a `slot_binder`; `tests/unit/tube_track/test-plan.md` (to be written, structured like Run State's) holds the state factory, the getters (`s`, `first_index`, `last_index`, `far_end_s`) and the ordered signal recorder (Open Question 17).

**Logic: frame and math**
- **AC-1 [U]** (R1, P): **GIVEN** `P`, **WHEN** evaluated at (0, 0, 0), (PI/2, 0, 0),
  (PI, 0, 0.5) and (0, 50, 0), **THEN** the results are (0, 3, 0), (3, 0, 0), (0, -3.5, 0)
  and (0, 3, -50).
- **AC-2 [U]** (R1): **GIVEN** `h = -0.5`, **WHEN** converting, **THEN** the result equals
  the `h = 0` result and exactly one warning reaches the log sink; `h = 0` logs nothing;
  `h = NaN` clamps to 0 and logs exactly one error.
- **AC-3 [U]** (F1): **THEN** `wrap_angle(PI) = -PI`, `wrap_angle(-PI) = -PI`,
  `wrap_angle(3*PI/2) = -PI/2`, `wrap_angle` of the literal constant `-3.141592653589793 - 4.44e-16`
  lies in [-PI, PI) with `abs(abs(r) - PI) < 1e-9`, `delta_theta(0, PI) = -PI` exactly, and
  `delta_theta(-3, 3) = +0.2832` (+/- 1e-4).
- **AC-4 [U]** (F1, R2): **GIVEN** the fixed grid `x_i = -100 + 0.02 * i` for `i = 0 .. 10000`,
  **THEN** `wrap_angle(x_i)` and `delta_theta(x_i, x_i + PI)` lie in [-PI, PI),
  `abs(sin(wrap_angle(x_i)) - sin(x_i)) < 1e-9` (the wrap keeps the angle), and
  `abs(abs(delta_theta(x_i, x_i + PI)) - PI) < 1e-9` (the sign is not asserted).
- **AC-5 [U]** (R2): `delta_theta(PI - 0.05, -PI + 0.05) = -0.1` and the reversed call
  `= +0.1`, each within 1e-9 (a ball and an obstacle straddling the seam of the angle range).
- **AC-6 [U]** (F1, Edge): **GIVEN** a NaN or infinite theta, **THEN** `wrap_angle` returns 0 and
  logs exactly one error through the injected `log`, and `P(NaN, s, h)` has finite components
  equal to `P(0, s, h)`; a NaN or infinite `s` in `P` likewise gives finite components and one
  error.

**Logic: window and states**
- **AC-7 [U]** (F2): **GIVEN** L = 12 and N = 9, **WHEN** s = -24, -1, 0, 11.999,
  11.999999999999998 (the double just below 12), 12, 24, **THEN** i = -2, -1, 0, 0, 0, 1, 2 and
  `slot(-1) = 8`.
- **AC-8 [U]** (R5, R6, F2): **GIVEN** `begin_run()` from Idle, **THEN** the window is -2..6,
  exactly one `window_primed(-2, 6)` and then one `state_changed(Running, Idle)` are emitted,
  and no `segment_*` signal is emitted; **WHEN** `advance` is called with 11.999, 12.0 and
  12.0, **THEN** exactly one `segment_left_window(-2)` then one `segment_entered_window(7)`
  are emitted in total (during the second call), and the window is -1..7.
- **AC-9 [U]** (F2, Edge): **GIVEN** Running at s = 0, **WHEN** `advance(96)` (8 = N-1
  segments), **THEN** 8 pairs are emitted in increasing index order (left -2, entered 7,
  ..., left 5, entered 14) and the window is 6..14. **GIVEN** Running at s = 0, **WHEN**
  `advance(108)` (9 = N segments), **THEN** exactly one `window_primed(7, 15)` is emitted
  and no `segment_left_window` or `segment_entered_window`.
- **AC-10 [U]** (R4, Edge): **GIVEN** Running at s = 50, **WHEN** `advance(49)`, **THEN**
  the effective s stays 50 and exactly one warning is logged; `advance(50)` at s = 50 logs
  nothing and emits nothing; `advance(NaN)` and `advance(INF)` are ignored with one error each;
  `begin_run()` sets s = 0.
- **AC-11 [U]** (F3): **GIVEN** v_max = 25, t_lat = 0.1, C_b = 6, M_cam = 2, **THEN** the
  required A and B match the F3 table: (L = 12, F = 37.5, 48, 129.5) give A = 5, 6, 12 with
  B >= 1; (L = 6, F = 48) gives A = 10 with B >= 2; (L = 24, F = 37.5) gives A = 3 with B >= 1;
  (L = 6, F = 100) is rejected (A = 19 > A_MAX). These rows test the F3 function only: they need
  not load as maps (F = 37.5 fails F9, and L = 6 is below `L_min`). A configured A = 5 at
  (L = 12, F = 48) fails validation with `A_TOO_SMALL`, and a configuration with A = 13
  (`A_OUT_OF_RANGE`) or B = 4 (`B_OUT_OF_RANGE`) fails (`N_MAX` is implied by the two caps).
- **AC-12 [U]** (F9, map load, reporting rules): **GIVEN** a base map at v_max = 25, L = 12,
  n_seams = 1, t_lat = 0.1, d_cam = 8, depth fog (`fog_depth_begin` = 10, `fog_depth_curve` = 1.0),
  `fog_density` = 1.0 and `F_read` = F with `A` set to the required value, **THEN** F = 45.5 (A = 5),
  48 (A = 6) and 129.5 (A = 12) load. **WHEN** one change from the table is applied to the base map
  (A = 6 and F = 48, F_read = 46 unless the row says otherwise), **THEN** the load fails, the state
  stays Uninitialized and the **set** of returned failure codes equals the set in the row:

  | Change | Expected code set |
  |--------|-------------------|
  | F = F_read = 0; F = F_read = -1 | `NOT_POSITIVE` |
  | F = F_read = NaN; F = F_read = INF | `NOT_FINITE` |
  | F = F_read = 45.49, A = 5 (T_vis 1.4996 s) | `VISIBILITY` |
  | F = F_read = 129.51, A = 12 (required A is 13) | `A_TOO_LARGE` (`A_TOO_SMALL` is suppressed) |
  | F_read = 20 (0.48 s); F_read = 45 (1.48 s) | `VISIBILITY` |
  | F_read = 50 | `FOG_BEFORE_READ` |
  | F_read = 46 | none (loads: 1.52 s, the default) |
  | `fog_density` = 0.01 | `FOG_DENSITY` |
  | `fog_mode` exponential | `FOG_MODE` |
  | `fog_depth_begin` = 48 | `FOG_RANGE` |
  | configured A = 5 | `A_TOO_SMALL` |
  | configured A = 13 | `A_OUT_OF_RANGE` |
  | `v_max` = 0 | `NOT_POSITIVE` |
  | `v_max` = NaN; `v_max` = INF | `NOT_FINITE` |
  | L = 9, A = 12, t_lat = 0.25, `T_VIS_MIN` = 2.5, d_cam = 31, F = F_read = 93.5 (range [93.5, 92.75]) | `NO_VALID_F` with the range printed (`VISIBILITY` and `A_TOO_LARGE` suppressed) |
- **AC-13 [U]** (map validation): **THEN** R = 2.4 and 3.4 are rejected and 2.5, 3.0, 3.3
  accepted (D = 0.8); with D = 0.6, R = 2.5 is rejected by `gap(R) <= 0.02 * D`; at v_max = 25
  and the 3 Hz cap `L_INVALID` is reported for L = 5, 12.5 and 25 and for L = 8 (below `L_min` = 9;
  the record prints 9 and `SEAM_HZ` is not reported) and is not reported for L = 9, 12 and 24;
  the default map (L = 12) loads, and L = 9 with A = 7 (F = 48, the boundary of the floor) loads;
  `n_seams` = 0 and -1 are rejected (the validator takes a
  Variant, so 2.5 is also rejected as not an integer); at L = 12 and v_max = 25 `n_seams` = 2
  (4.17 Hz) is rejected and 1 (2.08 Hz) accepted, and the error prints the largest allowed
  `n_seams` (1); a B below the
  required value and B = 4 are rejected.
- **AC-14 [U]** (F5): **GIVEN** `n_seams = 1`, L = 12, **THEN** the seam sits at 6, over 100
  segments every consecutive gap is 12.0 (+/- 1e-9, computed in 64-bit s-space) and `f_seam` at
  v_max is 25/12 = 2.0833 (+/- 1e-6). **GIVEN** `n_seams = 4`, L = 12 (a spacing test only, not a
  valid map at the 3 Hz cap), **THEN** seams sit at 1.5, 4.5, 7.5, 10.5 and every gap, including
  across segment boundaries, is 3.0 (+/- 1e-9).
- **AC-15 [U]** (F4, R8): `ulp32(700) = 6.1e-5`, `ulp32(7500) = 4.9e-4`, `ulp32(16384) = 1.95e-3`,
  `ulp32(1e6) = 0.0625` (relative tolerance 1%); `2 * ulp32(16383) <= 0.0024` and
  `2 * ulp32(16384) > 0.0024`; **GIVEN** Running at an `s` just below the limit (reached by steps
  of fewer than N segments, not by `advance(16384)` from 0, which is a re-prime), **WHEN**
  `advance(16383.0)`, **THEN** no warning; **WHEN** `advance(16384.0)`, **THEN** exactly one
  warning, and a second call at or above the limit logs no more in that run; `begin_run()`
  re-arms the warning.
- **AC-16 [U]** (F6, F7): R = 3 gives w = 13.5 degrees (+/- 0.05) and 26 lanes; R = 2.5
  gives 22 lanes; `gap(R)` is at most `0.02 * D` for R = 2.5, 3.0 and 3.3 and above it for
  R = 3.4.
- **AC-17 [U]** (F8, R11): with `TubeMath.idle_step(s_idle, v_idle = 1.5, dt, t_lat = 0.1, L = 12)`:
  dt = 1/60 adds 0.025; dt = 0.5 adds 0.15 (clamped to `t_lat`); dt = -1, NaN and INF add 0;
  `s_idle` = 11.99 plus one 1/60 step wraps to 0.015 (+/- 1e-9); through the Idle state's
  `tick_idle(dt)`, after 60 s of idle scroll run distance is 0 and `s_idle` is in [0, 12); Idle to
  Running discards `s_idle` and sets s = 0.
- **AC-18 [U]** (R10): `TubeMath.segment_content(config, index)` deep-equals across two
  instances for absolute index 102; the content of every segment in the window is identical
  between a continuous run and a re-prime at s = 1234.5 (segment 102), and across two
  `begin_run()` cycles; content is compared by absolute index (`seam_s` values in segment-local
  space); world transforms are not compared.
- **AC-19 [U]** (States): **GIVEN** a table-driven test over all 40 (state, event) pairs,
  **THEN** exactly the 16 pairs listed in States and Transitions succeed with the listed next
  state and the other 24 are rejected with no state change, no signal and one logged error;
  `resume()` and `pause()` in Ended, and `advance` in Idle, Paused or Ended, are among the
  rejected ones. Every accepted transition that changes state emits `state_changed(new, old)`
  exactly once after its effects are complete, and none is emitted when the state does not change
  (`begin_run()` from Running re-primes and emits `window_primed` only); at the `state_changed`
  emission a handler that snapshots state and window sees the new state and the final window,
  and in `begin_run()` a handler of the `window_primed` emitted just before sees the final window
  and the old state.
- **AC-20 [U]** (Edge): **GIVEN** `begin_run()` called twice in a row, **THEN** two
  `window_primed(-2, 6)` are emitted, the window holds 9 unique slots and s = 0; **GIVEN** a
  handler connected to one of `window_primed`, `state_changed`, `segment_entered_window` or
  `segment_left_window` (the `advance` that triggers it crossing exactly one boundary) that calls
  `advance`, `begin_run` or `pause`, **THEN** the call is rejected with one error and state is
  unchanged; `begin_run()` calls the injected `slot_binder` exactly N times, with `slot_index` 0..8
  once each and `segment_index` -2..6 (`slot_index = posmod(segment_index, 9)`).
- **AC-20a [U]** (R11, Idle window): **GIVEN** Uninitialized and a valid config, **WHEN**
  `load_map(config)`, **THEN** `slot_binder` is called exactly 9 times (`segment_index` -2..6,
  `slot_index = posmod(segment_index, 9)`), exactly one `window_primed(-2, 6)` and then one
  `state_changed(Idle, Uninitialized)` are emitted, and no `segment_*` signal; **GIVEN** an invalid
  config (`F` = NaN), **THEN** no binder call and no signal occur and the state stays Uninitialized.
  **GIVEN** Running (and again Paused, and again Ended) at s = 1234.5 with the window 100..108,
  **WHEN** `to_idle()`, **THEN** the binder is called 9 times as above, exactly one
  `window_primed(-2, 6)` and then one `state_changed(Idle, old)` are emitted, `s_idle` is 0 and the
  window is -2..6. **THEN**, in Idle, after 60 s of `tick_idle(1/64)` no `window_primed`,
  `segment_entered_window` or `segment_left_window` is emitted and the window stays -2..6.

**Logic: simulation, then integration**
- **AC-21 [U]** (R6, R7): **GIVEN** a deterministic 300 s simulation at 25 u/s with dt = 1/64
  (0.390625 u per frame, 19,200 frames, exact in binary) and a camera test double publishing
  `rear_extent = 6`, **THEN** on every frame the far edge of the window (the far edge of segment
  `i + A`) is at least `F + v_max * t_lat` (= 50.5) ahead of s and at least `A * L` (= 72) ahead;
  a single step of `dt = t_lat` (2.5 u) keeps both bounds after the call.
- **AC-22 [U]** (R6): in the same simulation, when a slot is recycled its far edge is at most
  `s - rear_extent`; each boundary crossing emits exactly one `segment_left_window` and one
  `segment_entered_window` inside the same `advance` call; the count of each equals
  `floori(s_final / L)` in exact arithmetic (625, because frame 19,200 reaches s = 7500 = 625 x 12
  exactly).
- **AC-23 [U]** (R5): over the whole simulation every `slot_binder` call has a `slot_index` in
  0..8 and `slot_index = posmod(segment_index, 9)`; that nothing is allocated or freed is asserted
  by the [P] check AC-29 (engine object, node and resource counts), not here.
- **AC-24 [I / static]** (R3, R12): the generated tube mesh has 32 facets with vertex radius
  `R`, and the `TubeTrack` node tree contains no `CollisionObject3D` (deferred until the mesh
  exists).
- **AC-25 [I / static, deferred]** (R1, cross-system): a CI lint over Ball Movement and
  Obstacle System scripts finds no reads of raw world z (`position.z`, `position[2]`,
  `global_position.z`, `global_transform.origin`). Owned by those systems' stories; it does
  not gate Tube Track. Any shader that uses world z instead of segment-local z has a tile
  period that divides `L` (deferred until the first seam shader exists).

**Visual / Feel**
- **AC-26a [Config/Data smoke, ADVISORY]** (R9, from palette values; runs when a seam colour
  exists): the WCAG ratio of the seam colour to the tube colour (Mist Sage) is in
  [`SEAM_CONTRAST_MIN`, `SEAM_CONTRAST_MAX`] in a still frame, the seam is lighter than the tube
  its luminance is below the map's darkest sky value (Haze Top, 0.635 on Map 1) and its chroma is
  at most 0.05; hazard/seam and ball/seam are at least 4:1 and pickup/seam at
  least 3:1 (a guard against a seam darker than the tube, not a ceiling: rule 9). The ratio helper
  it uses has its own [U] test: white against black is 21.0 and two equal colours give 1.0
  (+/- 1e-9).
- **AC-26b [V]** (R9, R7, needs a GPU): on rendered pixels sampled at the ball's screen position
  at rest, the seam/tube ratio is at least `SEAM_CONTRAST_MIN`, hazard/seam is at least 4:1 and
  pickup/seam at least 3:1 (the fog decay of seam visibility is measured at the same point with
  fog on and off); with `seam_contrast_scale = 0` the seam surface matches the tube surface;
  pixels at the far window edge at maximum fog are within 1/255 of `fog_color` (Haze Low on Map
  1).
- **AC-27 [V]** (Player Fantasy 1, a hypothesis test): first-playable exit test (a playtest, not
  screenshot evidence): on a device, each of 8 testers sees 6 clip pairs per arm (seams on, seams
  off; 48 trials per arm), each clip 6 s long with hazards and the Camera FOV effect present in
  both arms, the two clips of a pair differing only in speed by 20% (for example 20 and 24 u/s),
  and picks the faster. The trials are not independent (8 testers x 6), so probabilities are
  indicative. Pass: seams-on at least 36 of 48 correct (under 1% at chance) **and** seams-on minus
  seams-off at least 6 correct of 48 (12.5 points; a smaller effect cannot be told from noise with
  this sample). Both counts are reported. **Power is low** (simulated, review 4): if the true effect is
  exactly at the margin (about 12.5 points, for example 65% correct without seams and 77.5% with),
  the combined pass rule succeeds only about 35-55% of the time, so a fail is weak evidence.
  Advisory; a failure means the seams add nothing
  measurable: the speed claim in Player Fantasy stays a hypothesis and the design leans on hazard
  approach rate, Camera FOV and Juice, not on a louder seam.

**Performance** (reference device class is an open item; all ADVISORY)
- **AC-28 [P]**: draw calls are measured with `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` (a
  global total: an empty scene already reports 68) as a delta between the scene with the tube and
  the same scene without it, per renderer (Forward+ and Mobile), with tube `cast_shadow` off and
  every slot sharing one Mesh and one Material (nine `MeshInstance3D` added +1 on Forward+ and +9
  on Mobile, a MultiMesh +1); the total is at most 150 on an exported build; the numeric limit for
  Tube Track's share follows the renderer ADR (Open Question 1).
- **AC-29 [P]**: static memory is compared in a release export after a 10 s warm-up against
  an idle baseline; the drift limit is set after Open Question 2. `Performance.OBJECT_COUNT`,
  `OBJECT_NODE_COUNT` and `OBJECT_RESOURCE_COUNT` differ by 0 between the end of the warm-up and
  the end of the run (rule 5: nothing is allocated or freed during a run). A 10-minute heat-soak run
  reports frame time at t = 0 and at the end.
- **AC-30 [P]**: with `Time.get_ticks_usec()` around Tube Track's own `advance()` (signal
  handlers excluded), report the p99 over a run for recycle frames (provisional: at most 0.2
  ms, guess), and at most 2 ms of Tube Track's own work in `begin_run()`. Downstream hazard
  spawn cost is attributed to the Obstacle System.

**Deferred until other GDDs exist**: the menu-to-run transition covering the seam phase jump
(Menus & Screen Flow); exact Run State event names.

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | Renderer backend (Forward+ vs Mobile), shadow setup and draw-call accounting; the numeric limit for AC-28 | technical-director | ADR at Technical Setup |
| 2 | Reference device class for the performance criteria; how the 1 s restart budget is split; memory drift limit | technical-director | Technical Setup |
| 3 | Verify Godot 4.7 specifics: how the tube is rendered (node per slot, MultiMesh with `custom_aabb`, or one mesh with a scrolling seam shader driven by a 64-bit-computed uniform, never `TIME`); depth-fog parameters and metric; the draw-call monitor name and what it counts; flat shading; GUT with 4.7 log capture | godot-specialist | Before implementation (ADR) |
| 4 | Game-loop ADR: `advance(s)` called from `_process` with a clamped delta, or from the physics tick with interpolation | technical-director, godot-specialist | Technical Setup |
| 5 | Physics/collision ADR: analytic (theta, s, h) overlap tests versus Jolt bodies; Tube Track owns none | technical-director | Technical Setup |
| 6 | RESOLVED in `design/gdd/run-state-restart.md`: Run State defines the events, and Tube Track's own adapter calls `begin_run()`, `pause()`, `resume()`, `end_run()` and `to_idle()` (the adapter skips `pause()` when Tube Track is already Paused, and `to_idle()` on Boot to Menu) | Run State & Restart GDD | Resolved 2026-09-20 |
| 7 | Camera publishes `rear_extent` and `camera_distance` (`d_cam`, 8 u guess) as configuration values at map load; the visible-arc formula and camera height (the real lever on the hidden arc); re-justify `R` against tilt resolution and that arc after a device test | Camera GDD, Obstacle System GDD | When those GDDs are authored |
| 8 | Does Pattern & Difficulty place chunks in whole numbers of segments; does it treat indices `-B .. -1` as hazard-free; supply `T_dodge_worst` for F9 | Pattern & Difficulty GDD | When that GDD is authored |
| 9 | The menu-to-run transition (and the run-to-menu transition, which resets `s_idle` to 0) must hide a seam-phase jump of up to `SP` for at least one frame | Menus & Screen Flow GDD | When that GDD is authored |
| 10 | `MapConfig` fields (`seam_pattern_id`, `fog_mode` = depth, `fog_depth_begin`, `fog_end_distance` (radial from the camera eye), `fog_depth_curve`, `fog_density` = 1.0, `fog_color`, `readable_distance` = `F_read` (radial from the camera eye)); Environment & Theming and the art-director own the raw fog range and the **readable criterion**: the art bible's hazard/tube 4.17:1 against a 4:1 floor leaves about 4% headroom, so a "4:1 after fog blending" criterion puts `F_read` at about the fog start and makes the placeholder 46/48 defaults a fog wall (readable to invisible in about 0.1 s); decide a looser floor or a soft-fog rule, and consider a fade-time check `(F - F_read) / v_max >= T_FADE_MIN` (0.75-1.0 s, a guess) as the mechanism that prevents a wall, here or in Theming. They also name the owner of the speed-driven fog change to the shared Environment. **Art-director recommendation (2026-09-20, advisory, unverified; for that GDD to decide, no default here is changed):** keep 4:1 as the unfogged palette floor and add a separate fogged-readability floor for hazard/tube at `F_read` of about 2.5-3:1, plus the fade rule `(F - F_read) / v_max >= 0.75-1.0 s`; that would move `F` out to roughly 65-70 u (more segments and draw calls: a producer and technical-artist cost check), the speed-driven "fog pulls nearer" must be capped so `F_read(v) >= T_VIS_MIN * v + d_cam` at every speed, and hazards must not be exempted from fog (they would pop in at the horizon); validate on a device in sunlight at 50% brightness | Environment & Theming GDD, art-director | When that GDD is authored |
| 11 | Settings & Accessibility: `seam_contrast_scale` reduced-motion hook; accessibility review of a full-screen periodic seam pattern at up to 3 Hz, and a ruling on a conditional flash cap in place of the frequency-only cap (Open Question 18) | Settings & Accessibility GDD, accessibility-specialist | When that GDD is authored |
| 12 | RESOLVED 2026-09-22 (`/design-review`, ball-movement.md): `v_max` = 25 u/s confirmed as Ball Movement's design intent — provisional pending BM-1/BM-2 (the device spike) and Environment & Theming's `F_read`, not yet a locked contract; `v_max`'s registry source now points to Ball Movement | Ball Movement GDD | Resolved |
| 13 | On-device check of precision without a rebase; under the conservative 8-ulp model the safe zone ends at s = 4096. Fallback: treadmill | user, godot-specialist | First playable build |
| 14 | Default values (L, A, B, n_seams, SEAM_HZ_MAX, seam contrast band, IDLE_SCROLL_SPEED, t_lat, M_cam, T_VIS_MIN, R range) are guesses; validate on a real phone | user | First playable build |
| 15 | Curved (spline) tube for later maps: revisit the camera model before adopting it | user | Full Vision |
| 16 | Idle scroll versus Mood state 1 ("one lone hazard"): does the hazard scroll with the tube (then the `s_idle` wrap moves it 12 u every 8 s) or stay put (then seams slide under it); or is the idle scroll cut from the MVP | Environment & Theming GDD, Menus & Screen Flow GDD | When those GDDs are authored |
| 17 | Deferred items from the second design review (2026-09-20), frozen out of the revision pass. Rendering: seams as a shader-only analytic pattern with derivative anti-aliasing (MSAA does not smooth shader stripes), stripe width at least one frame's travel at the lowest supported fps (0.42 u at 60 fps, 0.83 u at 30 fps), relief as a normal tilt, `fposmod(s, SP)` computed in 64 bits and passed as the uniform; the one-mesh scrolling-shader option forces a treadmill; flat shading needs a derivative-normal shader or duplicated vertices (a SurfaceTool route was not confirmed); `CylinderMesh` has its axis on Y (rotate 90 degrees); Mobile versus Forward+ (draw calls differ). Design: `v_max` = 25 is unvalidated (prototype 6.0; at 6, F9, the seam cap and F4 are inert); `R` is a weak lever and its cap comes from the 32-facet mesh (raise the facet count, make it a knob); the seam-phase jump on the instant restart is hidden by the camera cut and the flash, so Open Question 9 may be dropped; seams as a ruler for Pattern & Difficulty (`SP` divides `L`); flat seams at reduced motion lose the speed cue, the other cues carry it; the 1920 px assumption in F4 (the limit falls to 8192 when the screen is taller than 2365 px); the re-prime threshold (`ceil(v * t / L) + 1`); a tolerance in F3's `ceil` at exact boundaries; reject a finite `s` above 1e9. Tests: `tests/unit/tube_track/test-plan.md` (state factory, getters `s`, `first_index`, `last_index`, `far_end_s`, ordered signal recorder); AC-8, 9, 15 and 20 split into single behaviours; AC-1 needs a 1e-6 tolerance for rounding noise of about 4e-16; coverage gaps: Idle to Running, `begin_run` at s > 0 from Running, Paused and Ended, pause and resume leave `s` unchanged, `unload_map`, the `seam_contrast_scale` clamp and NaN, the Run State adapter ([I] test against the real core, including who stops calling `advance` while Run State ticks in Paused and Hit), the AC-25 lint token list (`transform.origin.z`, `global_position[2]`); `class_name` needs an import pass (`godot --headless --import`) before GUT in CI and there is no `project.godot` yet; GUT versus gdunit4 (coding-standards) | user, godot-specialist, `/test-setup` | Technical Setup / Pre-Production |
| 18 | Deferred items from the third design review (2026-09-20), frozen out of the revision pass. **Seams and art:** `SEAM_CONTRAST_MAX` was ruled 1.25 by the art-director on 2026-09-20 (advisory, device check pending); what binds it is a rim-white near-miss ring crossing a seam (rim/seam is 1.83 on the tube and about 1.22 at ratio 1.5, and a ring at v_max overlaps a seam 16-28% of the time) and the seam against the sky contour (seam luminance 0.757 at 1.5 exceeds Haze Top 0.635); the flash budget is global (a seam at 2.08 Hz uses about 70% of the art bible's 3 per second, leaving 0.9 per second for rings, streaks and the hit flash: allocate it with Juice and Settings); the 3 Hz cap stays (user decision) but a conditional cap is the better long-term rule (WCAG 2.3.1 counts a flash at a luminance step of 0.10: the 1.15 floor gives 0.081, the 1.25 ceiling 0.135, and the 0.10 step falls at a ratio of about 1.185, inside the band; a two-tier pattern with fine low-contrast ticks was proposed and not adopted); relief semantics RESOLVED 2026-09-20 (art-director: seams are a flat shading band with no geometric relief, so `relief`, `SEAM_RELIEF` and the `RELIEF` code are removed; a normal tilt on a flat-shaded faceted tube is unverified and needs the technical-artist, Open Question 17); whether a seam sweeping past is a distracting transient in motion (add a "what drew your eye first" question to AC-27); `seam_contrast_scale` formula `L_seam_eff = L_tube + scale * (L_seam - L_tube)` with the band applying at scale = 1 only; a sparse tick at low speed (0.5 Hz at 6 u/s) is not a speed cue; simplest render route is one ring strip baked into the shared mesh (a UV band, no per-slot data). **Validation:** no code for the config's own knobs (`SEAM_HZ_MAX` above 3 silently disables the flash cap, `T_VIS_MIN` = 0 disables F9, `IDLE_SCROLL_SPEED` NaN, `t_lat`, `M_cam`, `S_PRECISION_LIMIT`); no valid `R` when `D < 0.602` (`gap(R) <= 0.02 * D` gives `R <= 4.1535 * D`); `h = +INF`; an unknown `seam_pattern_id`; a typed `@export` int cannot hold 2.5 (the not-an-integer check applies to Variant or Dictionary input), and a cached shared `.tres` must be duplicated before `seam_contrast_scale` is applied. **API:** signal parameter types are not enforced at `emit` (declare typed signals and assert first); `CONNECT_DEFERRED` handlers run after `advance()` returns and bypass the re-entrancy guard (state that the guarantee holds for immediate connections only; an awaiting handler resumes outside it too); handlers of a multi-recycle `advance` see an intermediate window; an unset `Callable().call()` is a script error (default `Callable()` and guard with `is_valid()`), a lambda captures an int by value (count through an Array or recorder), and the parameter name `log` shadows the global (rename `log_sink`); rename `P` to `to_world` (snake_case) and list `TubeMath.segment_content` and `tick_idle` in Structure. **Tests:** split AC-2, 6, 8, 9, 15 and 20 into single behaviours; AC-13 should assert a structured `{code, max_n_seams}` record, not message text (its relief clause was removed 2026-09-20); AC-17 with dt = 1/64 (3840 ticks give exactly 6.0); AC-18 (assert recorded binder calls equal between a continuous run and a re-prime, add a CI lint for `randf` and `RandomNumberGenerator`) and AC-21/22 (tautologies of the window definition) need real assertions; AC-26b needs a tube pixel sample at 5 angles including the darkest facet, a +-2/255 per-channel tolerance and a pass rule for fog decay; AC-29's 10-minute soak reaches s of about 15,000, below 16,384, and Open Question 13's device check has no AC; AC-30 cannot exclude handlers around a synchronous `advance` (connect no-op listeners); AC-25 is tagged [I] but does not gate; AC-1 never checks the surface normal; AC-28's "empty scene reports 68" did not reproduce (0 in a SubViewport run), so pin the measurement setup; uncovered: `NOT_FINITE` for the ten numeric inputs not in AC-12, `delta_theta(NaN)`, `unload_map` releasing slot bindings, backgrounding, rule 4 (one caller, dt clamp), an unknown `seam_pattern_id`. **Proportionality** (creative-director, review 3): F4, `S_PRECISION_LIMIT` and AC-15 are over-built for one debug warning; Open Question 13's device check either promotes them to a treadmill or collapses them. **Not verified:** `SurfaceTool.set_smooth_group(-1)` flat normals, Mobile-renderer fog and draw calls, GUT on 4.7.2, `.tres` int coercion and NaN load. **Engine facts (copied into `docs/engine-reference/godot/` on 2026-09-20; the GDScript ones were re-run on the 4.7.2 binary, the fog formula is the godot-specialist's Forward+ result):** depth fog is `pow(smoothstep(begin, end, radial eye distance), curve) * density` (default mode exponential, default density 0.01), GDScript has no `nextafter`, signal arguments are coerced to the handler's typed parameter (a float becomes an int for `func h(v: int)`, an untyped handler or lambda receives the float; re-verified 2026-09-20), a lambda captures a primitive by value and a container by reference, `Callable().call()` errors, deferred connections run after the emitter returns, `fposmod(-tiny, y)` can return exactly `y`, a `class_name` script needs `godot --headless --import` before GUT | user, godot-specialist, art-director, accessibility-specialist, `/test-setup` | Technical Setup / Pre-Production; art items with Environment & Theming |
