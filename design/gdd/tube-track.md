# Tube Track

> **Status**: Designed (pending `/design-review` in a fresh session)
> **Author**: user + agents
> **Last Updated**: 2026-09-19
> **Implements Pillar**: Pillar 1 (Instant Readability), Pillar 2 (Fair but Merciless Difficulty)

## Overview

Tube Track is the Foundation-layer system that defines the world the game is played
on: a single, straight, horizontal, endless cylinder along which the ball travels. It
owns the tube's geometry (radius, length axis, circular cross-section), the coordinate
frame every other system uses to place things on it (an **angle around the tube** and
a **distance along the tube**), the pattern of flush circumferential seams that gives
the player a sense of speed while the tube stays static on screen, and the division of
the tube into segments that are recycled so the track feels endless within a phone's
memory and draw-call budget. It has no player-facing behavior of its own and no
dependencies; Ball Movement, Obstacle System, Pattern & Difficulty, Camera and
Environment & Theming all build on it. In the MVP the tube is always straight and there
is a single map (Map 1); curved (spline) tubes are deferred. Colors and per-map seam
pattern variants come from Environment & Theming through `MapConfig`; Tube Track owns
only the geometry.

## Player Fantasy

Tube Track is infrastructure: players feel what it enables, not the tube itself. It
serves Pillar 1, *"The player must always be able to tell what killed them, and
every obstacle in view must be easy to read"*, by being the quiet, stable stage that
hazards stand out against.

The player should never think about the tube. If they notice it at all, it is as
solid, quiet ground with a clear rhythm: the seams sliding past under the ball tell
them how fast they are going, and that rhythm quickens as the run goes on. What they
feel because of it is (1) **speed**, even though the tube is static on screen, (2) a
**continuous world** with no hitches, loading or pop-in, and (3) a **clean stage**
that keeps hazards the loudest thing on screen (art bible section 1).

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
- World position: `P(theta, s, h) = ((R + h) * sin(theta), (R + h) * cos(theta),
  -(s - s_origin))`, where `s_origin` is the current render-origin offset (rule 8;
  other systems never use it). The outward surface normal at theta is
  `(sin(theta), cos(theta), 0)`.

**Rules**
1. **Address by (theta, s, h).** Systems place, move and query things using
   (theta, s, h). Only Tube Track converts to world space; no other system reads or
   writes raw world z or the render origin.
2. **Angular distance.** The difference between two angles is always the shortest
   signed arc, `delta_theta = wrap(theta_a - theta_b)` in [-pi, pi). Systems must
   use this rule and must not subtract angles directly.
3. **The tube is straight and constant** for the MVP: same radius and circular
   cross-section on every map. Curved tubes and per-map radii are deferred. `R` is the vertex radius
   of the 32-sided tube mesh; the ball rides the true circle of radius `R + D/2`, so
   it floats at most `R * (1 - cos(PI/32))` (about 0.0144, or 1.8% of the ball
   diameter, at defaults) above the centre of a facet, which is accepted as
   imperceptible.
4. **Progress input.** Tube Track does not move anything by itself. It is driven by
   a single input, the current distance `s` of the traveller (the ball during a
   run), supplied each frame by whichever system owns the traveller. `s` never
   decreases within a run and resets to 0 when a run starts or restarts.
5. **Segments.** The tube is a chain of fixed-length segments (`SEGMENT_LENGTH`).
   Only a window of segments exists at any time: `SEGMENTS_BEHIND` behind the
   traveller's current segment, the current one, and `SEGMENTS_AHEAD` ahead. When
   the traveller enters the next segment, the rearmost segment is recycled to the
   far end of the window. Nothing is allocated or freed during a run.
6. **Continuous world.** A segment is recycled only after it is completely out of
   view (behind the rear-most camera extent, which Camera publishes as
   `rear_extent`), and a new far segment must already be in place before it could
   come into view. The player never sees pop-in, a gap or a jump at the horizon or
   behind the ball. Tube Track updates after Ball Movement and Camera in the same
   frame so recycling never lags by more than one frame, and at s = 0 the window
   already includes `SEGMENTS_BEHIND` segments behind the start point.
7. **Horizon.** The far end of the ahead window must lie beyond the map's fog end
   distance (`fog_end_distance` from `MapConfig`) at all speeds, so the end of the
   tube is never visible. `fog_end_distance` is the largest value over all speeds
   (fog pulls nearer as speed rises), defined as the distance at which fog opacity
   is at least 99%, and the fog color equals the sky color at the horizon (`fog_color` from `MapConfig`). Non-positive or
   non-finite values, or values outside [20, 100], fail validation when the map loads.
8. **Hidden rebase.** `s` is unbounded. To keep world-space numbers small enough
   for precise rendering, Tube Track **must** shift the render origin (`s_origin`)
   when the traveller gets far from it (`REBASE_THRESHOLD`; trigger and shift
   amount in F4), moving every active world object by the same amount in one
   frame. It runs in every state that advances `s`, including Idle Scroll.
   Recycling and rebasing happen atomically within one frame. The shift is
   invisible: no visual change, no hitch, and no other system's (theta, s, h)
   values change. Tube Track emits `origin_rebased(delta)` for systems that cache
   world-space positions (for example VFX, camera smoothing state, trails); those
   systems must use local space or apply `delta`. Any shader that uses world z must
   have a tile period that divides `SEGMENT_LENGTH`.
9. **Seams.** Each segment carries flush circumferential seams (relief at most 0.1
   ball diameters) whose pattern comes from `MapConfig`. Seams sit at fixed `s`
   positions, so they stream past at the ball's speed and give the sense of speed
   while the tube is static on screen (art bible section 3d). Seams never change
   the tube's silhouette enough to read as a hazard.
10. **Deterministic.** Given the same `MapConfig` and `s`, segment content is
    identical. Tube Track uses no randomness.
11. **Idle scroll.** When no run is active (menu), Tube Track can scroll slowly at
    `IDLE_SCROLL_SPEED` without a ball so the tube is not dead (art bible: "tube
    idles slowly"); this scroll does not count as run distance. In Idle Scroll, `s_idle` plays the
    role of `s` for recycling and rebase. Moving from Idle
    Scroll to Priming resets `s` to 0, which can jump the seam phase by up to one
    segment length; that jump is hidden under the menu-to-run transition (Menus & Screen
    Flow must cover the tube for at least one frame; see Open Questions).

### States and Transitions

| State | Meaning | Tube Track does |
|-------|---------|-----------------|
| Uninitialized | No map loaded | Nothing |
| Idle Scroll | Menu, no run | Scrolls slowly (rule 11) |
| Priming | A run is starting or restarting | Places the full window for s = 0 from pooled segments |
| Running | Run in progress | Recycles segments as s advances |
| Frozen | Run ended or paused | Holds still; keeps segments in place |

Transitions:
- Uninitialized -> Idle Scroll: a map's `MapConfig` is loaded.
- Idle Scroll -> Priming: a run is requested.
- Priming -> Running: the window is fully placed (must fit well inside the 1 s
  restart budget; see Acceptance Criteria).
- Running -> Frozen: the run ends (hit) or the game is paused.
- Frozen -> Running: resumed after a pause (`s` is unchanged).
- Frozen -> Priming: instant restart.
- Running -> Priming: a restart is requested mid-run.
- Running or Frozen -> Idle Scroll: return to the menu.
- Any -> Uninitialized: the map is unloaded.

### Interactions with Other Systems

All interfaces below are **provisional** until the other systems have GDDs.

| System | Direction | Data / events | Interface owner |
|--------|-----------|---------------|-----------------|
| Run State & Restart | in | `run_started`, `run_ended`, `run_reset`, `paused` / `resumed` (names provisional) | Run State defines the events |
| Ball Movement | in / out | in: `s` each frame. out: convert (theta, s, h) to world, `R`, surface normal, angular-difference helper | Tube Track owns the coordinate frame; Ball Movement owns speed and `s` |
| Obstacle System | out | the coordinate frame; `segment_entered_window(index)` and `segment_left_window(index)` so hazards are placed and removed with segments | Tube Track owns the events; Obstacle System owns hazard lifecycle |
| Pattern & Difficulty | out | the same segment events; guarantees the ahead window is at least the spawn horizon (rule 7) | as above |
| Camera | out | `R`, the tube axis, the frame to orbit around | Camera owns its own offsets |
| Environment & Theming | in (via `MapConfig`) | `seam_pattern_id`, `fog_end_distance`, `fog_color`; Theming applies colors and material to segments | Theming owns the values; Tube Track only documents the fields it reads |
| Juice & Feedback | out | the frame for surface-anchored effects (ring pulse at the ball's position) | Juice owns the effects |

Provisional assumptions to re-check when the other GDDs exist: the shape of Run
State's events; whether Pattern & Difficulty places chunks in whole numbers of
segments; and that `s` is an input, not a code dependency on Ball Movement (Ball
Movement uses Tube Track's frame, but Tube Track only receives a number).

## Formulas

All worked examples use the proposed defaults (R = 3.0, D = 0.8, L = 12, A = 6,
B = 2, F = 48, v_max = 25). Defaults are proposals; see Tuning Knobs. Numbers marked
"guess" have no measured basis yet.

**Precision rule.** `s` and `s_origin` are held as 64-bit floats (GDScript `float`).
`s - s_origin` is computed in 64 bits before casting to 32 bits for any Vector3. `s`
is never stored in a Vector3.

**Variables**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Angle | a, b, theta | float (64-bit) | any finite | angle in radians |
| Distance along tube | s | float (64-bit) | s >= -B*L | distance since run start; negative values are the tube behind the start |
| Render origin | s_origin | integer multiple of L | any | render-origin offset, always a whole number of segments |
| Segment length | L | float | 6-24 | `SEGMENT_LENGTH` |
| Seam spacing | SP | float | 1.7-6, divides L | `SEAM_SPACING` |
| Segments ahead / behind | A, B | int | A 1-12, B 1-3 | `SEGMENTS_AHEAD` / `SEGMENTS_BEHIND` |
| Pool size | N | int | A + B + 1 | number of segment objects |
| Fog end distance | F | float | 20-100 (guess) | largest fog end distance across speeds; the distance at which fog opacity is at least 99% |
| Max speed | v_max | float | 25 u/s (assumed) | Ball Movement owns the real value |
| Allowed recycle lateness | t_lat | float | 0.25 s (guess) | one hitch |
| Camera rear extent | C_b | float | 6 (Camera owns) | how far behind the ball the camera can see |
| Camera slack | M_cam | float | 2 (guess) | safety margin |
| Rebase threshold | TH | float | multiple of L | `REBASE_THRESHOLD` |
| Tube radius | R | float | 2.5-4 (guess) | `TUBE_RADIUS` |
| Ball diameter | D | float | 0.8 (Ball Movement owns) | ball diameter |

**F1. Angle wrap**
`wrap(a) = fposmod(a + PI, TAU) - PI`, then if the result is at least PI subtract TAU.
`delta_theta(a, b) = wrap(a - b)`. Output range: [-PI, PI).
Example: wrap(PI) = -PI; wrap(3*PI/2) = -PI/2. NaN or infinite input returns 0 and
logs an error. Two exactly opposite angles always give -PI, so the sign of a
half-turn is arbitrary and systems must not rely on it.

**F2. Segment index and recycling**
`i = floori(s / L)`; `slot = posmod(i, N)` with `N = A + B + 1`. The window is
[i - B, i + A]. When i advances from k to k + 1, segment `k - B` is recycled to become
segment `k + 1 + A`.
Example: s = 11.999 gives 0; s = 12 gives 1; s = -1 gives -1. Use `floori` and
`posmod`, never `int()` or `%`, which are off by one for s < 0. A jump of N or more
segments (for example on app resume) re-primes the window instead of looping.

**F3. Window sizes**
`A >= ceil((F + v_max * t_lat) / L) + 1` and `B >= ceil((C_b + M_cam) / L)`.
Output: integers. At worst the horizon is A*L from the ball (ball at the end of its
segment).
Example: F = 48 gives ceil(54.25 / 12) + 1 = 6, a horizon of 72 against fog 48.
F = 100 gives 10; F = 20 gives 4. B >= ceil(8 / 12) = 1 (default B = 2). Pool size at
defaults: 6 + 2 + 1 = 9 segments (13 at F = 100).

**F4. Rebase**
`W = s - s_origin`. Trigger when `W >= TH`. Shift `delta = L * floor(W / L)` and set
`s_origin = s_origin + delta`; every active world object's world z increases by delta in one frame (z = -(s -
s_origin), so everything moves back toward the origin). `origin_rebased(delta)`
carries this positive delta.
`delta` is a multiple of L, so it is also a multiple of the seam period and of any
world-space shader tile (both must divide L). After a shift the traveller sits at
z in (-L, 0].
Bound: `max_abs_z = TH + v_max * t_lat + (A + 1) * L`. Keep
`TH <= 1024 - (A + 1) * L - v_max * t_lat`.
Example: TH = 600, A = 6 gives 600 + 6.25 + 84 = 690.25; A = 10 gives 738.25.

**F5. 32-bit float precision**
`ulp(m) = 2^(floor(log2(m)) - 23)` for a 32-bit float of magnitude m.
Example: magnitudes 512-1024 give 6.1e-5 (0.06 mm); 7500 (5 minutes at 25 u/s with no
rebase) gives 4.9e-4; 1,000,000 gives 0.0625 (6 cm). The worst-case error of about
8 ulp is 0.5 mm at abs(z) <= 1024, which meets the 1 mm requirement. Note: for 1-5
minute runs the error without rebase is still only about 0.5 mm, so rebase is
insurance for long menu idling and long sessions, not a hard need.

**F6. Seam positions**
`seam_s(i, j) = i * L + (j + 0.5) * SP` for `j = 0 .. n - 1`, with `n = L / SP` an
integer. Seams are baked in segment-local space. Constraints: `L mod SP = 0` and
`SP >= 2 * v_max / f_min` (f_min = 30 gives 1.67).
Example: L = 12, SP = 3 gives n = 4 seams at 1.5, 4.5, 7.5, 10.5. SP = 5 would give
gaps of 5, 5, 7 across a segment boundary, a visible stutter, so it is rejected.

**F7. Lane capacity around the tube**
`w = 2 * asin(D / (2 * (R + D/2)))` and
`N_lanes = floor(PI / asin(D / (2 * (R + D/2))))`. Informational for the Obstacle
System and Pattern & Difficulty GDDs, which own difficulty.
Example: R = 3, D = 0.8 gives w = 13.5 degrees and 26 lanes. R -> 0 is undefined;
R = 100 gives 788 lanes, finer than tilt noise. Suggested range R = 2.5-4 (guess).

**F8. Idle scroll**
`s_idle = s_idle + v_idle * min(dt, 0.1)`. Does not count as run `s`.
Example: v_idle = 1.5 u/s gives 0.025 u per frame at 60 FPS, one seam every 2 s.

## Edge Cases

**Distance `s` and the segment window**
- **If `s` decreases between frames** (bug or negative speed): keep
  `s = max(s, s_previous)`, ignore the decrease, and log a warning in debug builds.
- **If `s` jumps forward by N segments or more in one update** (app resume, a large
  hitch): re-prime the whole window at the new segment instead of looping recycles.
  The skipped segments are never populated with hazards. Run State pauses on app
  interruptions, so this is only a safeguard.
- **If `s` equals a segment boundary exactly** (`s = i * L`): the new segment counts
  as entered (the lower bound is inclusive) and is recycled exactly once.
- **If `s` is negative** (behind the start point): valid down to `-B * L`; use
  `floori` and `posmod`. When Priming, segments with indices `-B .. -1` already exist.
- **If the ball is ready before Priming has finished**: the ball may only advance `s`
  once Tube Track is in Running; `s` input is ignored until then.

**Angles, heights and invalid values**
- **If theta is NaN or infinite**: `delta_theta` returns 0 and the conversion
  function returns the point at theta = 0; both log an error. NaN must not spread
  into transforms.
- **If two angles are exactly opposite** (half a turn apart): `delta_theta = -PI`
  and the sign is arbitrary; no system may rely on that sign.
- **If `h < 0`**: clamp `h = 0` and log a warning (nothing sits inside the tube).
- **If `s` is NaN or infinite, or `h` is NaN**: ignore that `s` update (keep the
  previous `s`) or clamp `h = 0`, and log an error.
- **If `fog_end_distance` is non-positive, non-finite or outside [20, 100] when a map loads**: map load
  fails, Tube Track stays Uninitialized and reports the error; it never computes
  `A = 0`.
- **If `SEAM_SPACING` does not divide `SEGMENT_LENGTH`, or the pool needed for `F`
  exceeds the draw-call budget**: map validation rejects the map at load ("divides" means
  `abs(L / SP - round(L / SP)) < 1e-6`)
  instead of running with visibly uneven seams.

**Simultaneous events and state**
- **If `run_reset` arrives in the same frame as a segment recycle**: Priming wins
  and the pending recycles are discarded.
- **If `run_reset` arrives while already Priming**: Priming restarts from scratch
  (idempotent) without duplicating segments.
- **If a pause is requested while Priming**: it takes effect only once Running.
- **If a recycle, a rebase and a hazard spawn fall in the same frame**: all are
  atomic within that frame (order: recycle, then rebase, then emit events).
- **If the app is backgrounded and resumed mid-run**: Run State pauses (Frozen);
  on resume, Frozen -> Running with `s` unchanged and no catch-up.
- **If Idle Scroll runs for a long time** (menu left open for minutes): rebase still
  runs in Idle (rule 8).
- **If Idle Scroll -> Priming**: the seam phase can jump by up to `L`; hide it under
  the menu-to-run transition.
- **If the map is unloaded while Running**: go to Uninitialized, release every
  segment, and notify Run State (provisional).

## Dependencies

Tube Track has **no system dependencies** (Foundation layer). It has data inputs,
which are contracts rather than code dependencies, and several dependents.

### Data inputs

| Input | Supplied by | Used for | Note |
|-------|-------------|----------|------|
| `s` (traveller distance) | Ball Movement during a run; Tube Track's own idle scroll in the menu | Drives segment recycling and rebase | Ball Movement uses Tube Track's frame, but Tube Track only receives a number, so there is no code cycle |
| `rear_extent` | Camera, as a configuration value published when a map loads | Checks `SEGMENTS_BEHIND` (F3) | A config value, not a runtime call, so Camera can depend on Tube Track without a cycle |
| `MapConfig`: `seam_pattern_id`, `fog_end_distance`, `fog_color` | Environment & Theming (map data) | Seam pattern; horizon check (F3) | Theming owns the values |
| Run State events (`run_started`, `run_ended`, `run_reset`, `paused` / `resumed`) | Run State & Restart | State transitions | Loose signal coupling; Run State does not know Tube Track. Names are provisional |

### Dependents

| System | Type | What it needs from Tube Track |
|--------|------|-------------------------------|
| Ball Movement | Hard | The frame (theta, s, h to world), `R`, surface normal, angular-difference helper, Running / Priming state |
| Obstacle System | Hard | The frame; `segment_entered_window` and `segment_left_window` |
| Pattern & Difficulty | Hard | Segment events; the spawn horizon (rule 7); `SEGMENT_LENGTH` |
| Camera | Hard | `R`, the tube axis, the frame to orbit around |
| Environment & Theming | Hard | Segment material slots to apply color and fog |
| Juice & Feedback | Soft | The frame for surface-anchored effects; `origin_rebased(delta)` |

### Bidirectional consistency

The systems index already lists Tube Track as a dependency of Ball Movement,
Obstacle System, Pattern & Difficulty, Camera and Environment & Theming. Juice &
Feedback's row in the index did not; it is to be updated with a soft dependency on
Tube Track (decided 2026-09-19). Each dependent's GDD must list Tube Track as a
dependency when it is written.

## Tuning Knobs

All defaults are proposals or guesses with reasoning, not measured on a real
device. Values that live in other systems are not duplicated here.

| Knob | Default | Safe range | Affects | Too high | Too low |
|------|---------|------------|---------|----------|---------|
| `TUBE_RADIUS` (R) | 3.0 | 2.5-4 (guess) | Number of lanes around the tube (F7), ease of dodging, camera orbit radius | Lanes finer than tilt noise (R = 100 gives 788), dodging too easy | Few lanes; the ball takes up much of the circumference. R >= 1.66 for at least 16 lanes (verified: 1.65 gives 15) |
| `SEGMENT_LENGTH` (L) | 12 | 6-24 | Recycle frequency (at most about 2.1 per second at 25 u/s), pool size | Large pool, harder to avoid pop-in | Recycling too often, CPU cost |
| `SEGMENTS_AHEAD` (A) | 6 (from F3) | 4-10 (F = 20 gives 4, F = 100 gives 10) | Horizon length, draw calls | Draw-call and memory cost | The tube's far end becomes visible (breaks rule 7) |
| `SEGMENTS_BEHIND` (B) | 2 | 1-3 | Protection against pop-in behind the camera | Waste | Segments vanish while still in view |
| `REBASE_THRESHOLD` (TH) | 600 (= 50 * L) | 240-876 (for A up to 10), multiple of L | Rebase frequency (about every 24 s at 25 u/s), bound on abs(z) | Above 1024 the error exceeds 1 mm | Rebasing too often |
| `SEAM_SPACING` (SP) | 3 | 1.7-6, must divide L | Seam rhythm (8.3 Hz at 25 u/s), sense of speed | Weak sense of speed | Stutter or aliasing below 1.67 |
| `SEAM_RELIEF` | 0.05 (guess) | 0-0.08 (0.1 * D, art bible) | How raised the seams are | Seams read as obstacles | Seams invisible |
| `IDLE_SCROLL_SPEED` | 1.5 | 0.5-3 | Life in the menu | Menu motion competes with run energy | The tube looks dead |

**Derivation constants used in F3** (tune together): `RECYCLE_LATENESS` t_lat = 0.25 s
(guess, one hitch) and `CAMERA_MARGIN` M_cam = 2 (guess).

**Sources of truth elsewhere** (not duplicated): `v_max` and ball diameter `D` (Ball
Movement), `rear_extent` / C_b (Camera), `fog_end_distance` (`MapConfig`, owned by
Environment & Theming).

**Interactions between knobs**
- `A >= ceil((F + v_max * t_lat) / L) + 1`, so changing L, F or v_max means
  recomputing A.
- `TH` must be a multiple of L and satisfy
  `TH <= 1024 - (A + 1) * L - v_max * t_lat`.
- `SP` must divide `L`.
- Changing `R` affects the number of lanes (Obstacle System, Pattern & Difficulty)
  and the camera orbit radius.

## Visual/Audio Requirements

**Visual**: follows the art bible. The tube is a flat-shaded 32-sided cylinder with
flush seams (relief at most 0.1 ball diameters) and a clear sky band around its
contour (section 3d). Tube color is Mist Sage (#A9BFB0) with environment chroma at
most 0.05, and the fog color equals the sky color at the horizon (section 4). Per-map
palettes come from `MapConfig` through Environment & Theming. Tube Track creates no
effects itself; surface-anchored effects (such as the near-miss ring pulse) belong to
Juice & Feedback and are positioned with Tube Track's coordinate frame.

**Audio**: none. (The whoosh and other feedback sounds belong to Juice & Feedback.)

> **Asset Spec**: Visual requirements are defined. After the art bible is complete,
> run `/asset-spec system:tube-track` to produce per-asset specs.

## UI Requirements

None. Tube Track has no player-facing UI. (A developer-only debug overlay showing
`s`, `s_origin` and the window indices is optional and not a player requirement.)

## Acceptance Criteria

Test types: **[U]** automated unit test in `tests/unit/tube_track/` (GUT, BLOCKING);
**[I]** integration test in `tests/integration/tube_track/` (BLOCKING); **[V]**
screenshot evidence in `production/qa/evidence/` (ADVISORY); **[P]** performance
measurement (the reference device class is an open item). Defaults: R = 3, D = 0.8,
L = 12, SP = 3, A = 6, B = 2, N = 9, F = 48, v_max = 25, TH = 600. Numeric tolerance
is 1e-6 unless stated.

**Logic**
- **AC-1 [U]** (R1, R3): **GIVEN** `s_origin = 0`, **WHEN** P is evaluated at
  (0, 0, 0), (PI/2, 0, 0), (PI, 0, 0.5) and (0, 50, 0), **THEN** the results are
  (0, 3, 0), (3, 0, 0), (0, -3.5, 0) and a point with z = -50.
- **AC-2 [U]** (R1): **GIVEN** `h = -0.5`, **WHEN** converting, **THEN** the result
  equals the `h = 0` result and exactly one warning is logged; `h = 0` logs nothing.
- **AC-3 [U]** (F1, R2): **GIVEN** the wrap function, **WHEN** given PI, -PI, 3*PI/2
  and -PI minus one ulp, **THEN** it returns -PI, -PI, -PI/2 and a value in [-PI, PI);
  `delta_theta(-3, 3) = +0.2832` (+/- 1e-4); `delta_theta(x, x + PI) = -PI`; a sweep of
  10,000 angles over [-100, 100] never leaves [-PI, PI).
- **AC-4 [U]** (F1, Edge): **GIVEN** a NaN or infinite theta, **WHEN** wrap or P is
  called, **THEN** wrap returns 0 and logs one error, and P(NaN, s, h) has finite
  components equal to P(0, s, h).
- **AC-5 [U]** (F2): **GIVEN** L = 12 and N = 9, **WHEN** s = -24, -1, 0, 11.999, 12,
  24, **THEN** i = -2, -1, 0, 0, 1, 2 and `slot(-1) = 8`.
- **AC-6 [U]** (R5, F2): **GIVEN** Priming at s = 0, **THEN** exactly 9 segments
  (indices -2..6) exist; **WHEN** s is fed 11.999, then 12.0, then 12.0, **THEN**
  segment -2 is recycled into 7 exactly once and the window is -1..7.
- **AC-7 [U]** (F2, Edge): **GIVEN** s = 0, **WHEN** s jumps to 96 (8 segments),
  **THEN** 8 recycles happen; **WHEN** it jumps to 108 (N or more), **THEN** the
  window is re-primed once and no hazard events are emitted for skipped segments.
- **AC-8 [U]** (R4, Edge): **GIVEN** s = 50, **WHEN** s = 49 is fed, **THEN** the
  effective s stays 50 and one debug warning is logged; **WHEN** s = 50 is fed during
  Priming, **THEN** s stays 0 and the window is unchanged; a NaN `s` is ignored with
  an error; `run_started` sets s = 0.
- **AC-9 [U]** (F3): **GIVEN** L = 12, v_max = 25, t_lat = 0.25, C_b = 6, M_cam = 2,
  **WHEN** F = 48, 100 and 20, **THEN** A = 6, 10 and 4, B = 1, and the pool is 9 or
  13; a map with A = 5 at F = 48 fails validation.
- **AC-10 [U]** (R7): **GIVEN** a map load, **WHEN** F is 0, -1, NaN, INF, 19 or 101,
  **THEN** the load fails, the state stays Uninitialized and an error is reported;
  F = 48 loads.
- **AC-11 [U]** (F4, F6, knobs): **GIVEN** map validation, **THEN** SP = 5 with L = 12
  and SP = 1.5 are rejected; `SEAM_RELIEF` 0.09 is rejected and 0.05 accepted;
  TH = 601 and TH = 936 (A = 6) are rejected and TH = 600 is accepted.
- **AC-12 [U]** (F4): **GIVEN** TH = 600, **WHEN** s = 599.99, **THEN** no rebase;
  s = 600 triggers one rebase with delta = 600; a single-frame jump 590 -> 613.5 gives
  delta = 612 and traveller z = -1.5; `s_origin` is always a multiple of 12.
- **AC-13 [U]** (R8, Edge): **GIVEN** a recycle and a rebase in one frame, **THEN**
  events are emitted in the order recycle, rebase, entered/left_window; **GIVEN** Idle
  Scroll with `s_idle = 600`, **THEN** one rebase occurs and run distance is unchanged.
- **AC-14 [U]** (F5): ulp(700) = 6.1e-5, ulp(7500) = 4.9e-4, ulp(1e6) = 0.0625; with
  s = 1e7 + 0.5 versus 1e7, world z differs by 0.5 +/- 1e-6 (64-bit `s`).
- **AC-15 [U]** (F6, R9): seams sit at 1.5, 4.5, 7.5, 10.5; every gap, including
  across segment boundaries, is 3.0 over 100 segments; seam relief is at most 0.08; a
  static scan finds every world-z shader tile period dividing 12.
- **AC-16 [U]** (F7): R = 3 gives w = 13.5 degrees (+/- 0.05) and 26 lanes; R = 2.5
  gives 22; R = 4 gives 34; R = 1.66 gives 16 and R = 1.65 gives 15.
- **AC-17 [U]** (F8, R11): dt = 1/60 adds 0.025; dt = 0.5 adds 0.15 (clamped); after
  60 s of idle, run distance is 0.
- **AC-18 [U]** (R10): two Priming cycles, and a continuous run versus a re-prime at
  s = 1234.5, produce identical segment transforms and seam positions (hash compare).
- **AC-19 [U]** (States): the 9 listed transitions succeed; Uninitialized -> Priming
  and Idle Scroll -> Running are rejected.
- **AC-20 [U]** (Edge): `run_reset` twice during Priming still gives 9 unique
  segments and s = 0; `run_reset` in a recycle frame discards the recycle (window
  -2..6); a pause requested during Priming takes effect only once Running.

**Integration**
- **AC-21 [I]** (R8, R1): **GIVEN** a ball at (0.5, 605, 0) and an obstacle at
  (0.5, 610, 0), **WHEN** a rebase fires, **THEN** both (theta, s, h) are unchanged,
  both world z values increase by exactly 600, their relative distance is unchanged,
  and `origin_rebased(600)` fires once.
- **AC-22 [I / static]** (R1, cross-system): Ball Movement and Obstacle System scripts
  never reference `position.z`, `global_position.z` or `s_origin`; a ball at
  theta = PI - 0.05 and an obstacle at -PI + 0.05 measure 0.1 rad apart.
- **AC-23 [I]** (R6, R7): **GIVEN** a deterministic 300 s simulation at 25 u/s and
  dt = 1/60, **THEN** on every frame: resident segments cover [s - 6, s + 54.25]; no
  recycled segment intersects the camera frustum; a newly placed segment's near edge
  is at least 48 from the ball (72 on time, at least 65.75 when 0.25 s late);
  recycling happens in the same frame the traveller enters the segment; and frames
  that rebase take at most 2x the median frame time.

**Visual / Feel**
- **AC-24 [V]** (R8): the same frame rendered with `s_origin = 0` and `s_origin = 600`
  is pixel-identical (within 1/255).
- **AC-25 [V]** (R7): at s = 11.999 and maximum fog, pixels at the far window edge are
  within 1/255 of the sky color at the horizon (`fog_color`; Haze Low on Map 1).
- **AC-26 [V]** (R9): seam luminance is above 0.10 and chroma at most 0.05 (art bible
  section 4); a grayscale render shows seams below hazard contrast. Proxy for "sense
  of speed": v_max / SP <= fps / 2 (8.3 <= 15 Hz), plus a playtest with at least 8
  testers where at least 80% pick the faster of two clips.
- **AC-27 [V]** (R3): the visible gap between the ball and a facet centre is at most
  2% of D.

**Performance** (reference device class is an open item)
- **AC-28 [P]**: total draw calls are at most 150 on an exported build (verify the
  monitor name in 4.7); Tube Track's own share is at most N (9 at defaults, 13 at
  F = 100) *(proposal)*.
- **AC-29 [P]**: zero allocation over a 300 s run: object, node and resource counts
  are identical at s = 0 and at the end (625 recycles, 12 rebases); static memory
  drift is at most 64 KB *(proposal)*.
- **AC-30 [P]**: Priming takes at most 100 ms and a recycle-plus-rebase frame adds at
  most 1 ms (p95 over 100 restarts) *(proposals; the 1 s restart budget is not split
  yet)*. CI proxy: Priming moves exactly 9 segments and instantiates 0.

**Deferred until other GDDs exist**: the menu-to-run transition covering the seam
phase jump (Menus & Screen Flow); exact Run State event names.

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | Renderer backend (Forward+ vs Mobile) and Tube Track's share of the draw-call budget (at most N) | technical-director | ADR at Technical Setup |
| 2 | Reference device class for the performance criteria, and how the 1 s restart budget is split (Priming at most 100 ms is a proposal) | technical-director | Technical Setup |
| 3 | Verify Godot 4.7 specifics: segment pooling / MultiMesh approach and the draw-call monitor name (engine reference is pinned to 4.6) | godot-specialist | Before implementation |
| 4 | Names of Run State's events and who triggers Priming | Run State & Restart GDD | When that GDD is authored |
| 5 | Camera publishes `rear_extent` as a configuration value at map load | Camera GDD | When that GDD is authored |
| 6 | Does Pattern & Difficulty place chunks in whole numbers of segments (aligned with L = 12)? | Pattern & Difficulty GDD | When that GDD is authored |
| 7 | The menu-to-run transition must cover the tube for at least one frame to hide the seam-phase jump | Menus & Screen Flow GDD | When that GDD is authored |
| 8 | `MapConfig` must provide `seam_pattern_id`, `fog_end_distance` and `fog_color` | Environment & Theming GDD | When that GDD is authored |
| 9 | Default values (L, A, B, TH, SP, SEAM_RELIEF, IDLE_SCROLL_SPEED, t_lat, M_cam, R range) are guesses; validate on a real phone | user | First playable build |
| 10 | Curved (spline) tube for later maps: revisit the camera model before adopting it | user | Full Vision |
