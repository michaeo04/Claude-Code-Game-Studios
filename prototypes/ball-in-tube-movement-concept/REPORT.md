# Concept Prototype Report: Ball-in-Tube Movement

> **Date**: 2026-09-19 (built 2026-09-14, playtested and iterated through 2026-09-19)
> **Prototype Path**: Engine (Godot 4.7.2, GDScript)
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

If the player rotates a ball around the OUTSIDE of a moving tube (desktop
stand-in for phone tilt: Left/Right arrow keys), using a follow-camera that
orbits with the ball's angular position but does NOT roll, movement will feel
physical and readable — evidenced by a first-time player consistently dodging 3
obstacles in a row within their first 2 minutes, without the camera or rotation
confusing them about which way is safe.

---

## Riskiest Assumption Tested

That "camera orbits with the ball's angle but does not roll" keeps the ball and
obstacles readable on the exterior of a tube. **It did not prove out.** The first
build pinned the ball at screen center while the tube spun around it, which the
tester reported as dizzying. The camera model had to change (see Result).

---

## Approach

A single-script Godot project (`main.gd`) that builds the whole scene in code:
a cylinder mesh, a sphere on its outer surface controlled by an angle, 6
hardcoded box obstacles, a follow camera, and a hit counter. Collision is a
distance/angle check, not the physics engine.

**Path chosen:** Engine
**Reason for path:** The hypothesis is about moment-to-moment feel and camera
behavior in 3D; a browser prototype would misrepresent feel and would not use
the project's actual engine.

**Shortcuts taken (intentional):**
- Everything hardcoded; placeholder unshaded colored primitives, no lighting or art
- Keyboard (Left/Right arrows) instead of phone tilt
- Constant forward speed, no difficulty ramp
- One obstacle type (box), 6 fixed positions that loop
- No menus, score, sound, or restart flow beyond "hit resets to start"

---

## Result

Three camera models were tried in sequence:

1. **v1 — camera at the ball's angle, looking at the ball, world-up (no roll).**
   Ball pinned to screen center, tube appeared to spin around it.
   Tester: *"camera dính theo quả bóng là không nên ... di chuyển bị chóng mặt quá"*.
   Judged: not acceptable.
2. **v2 — camera angle lags behind the ball, looks at the tube axis, world-up
   (no roll).** Movement was accepted (*"chuyển động ok rồi"*, lag *"ổn"*), but the
   tube still swung/tilted on screen as the camera orbited.
3. **v3 — camera angle lags behind the ball, looks at the tube axis, up = radial
   outward from the axis (camera rolls with its orbit).** The tube looks identical
   every frame (static, centered); only the ball and obstacles travel around it.
   Tester: *"đúng ý t rồi"*.

Additional observations from the tester:
- Obstacles on the far/underside of the tube are hidden by the tube itself. The
  tester's description: obstacles feel "random" and appear as a surprise when the
  ball moves underneath (*"chỉ khi di chuyển quả bóng xuống dưới mới kiểu bất ngờ gặp vật cản"*).
  Rated *"ổn"*; occlusion-related issues explicitly deferred (*"sau này fix sau"*).
- Left/Right controls were inverted relative to the tester's expectation. The sign
  was swapped in code. **Not yet visually re-confirmed by the tester.**
- Wants more obstacle variety, later a nicer moodboard/UI, and speed increasing
  over time.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | Engine |
| Iterations to playable | 3 camera models + 1 input-direction fix |
| Prototype duration | Not tracked precisely; built in one session, iterated across a second |
| Playtesters | 1 internal (the developer) / 0 external |
| Feel assessment | v1 caused dizziness with ball pinned to screen center. v3 with `CAMERA_FOLLOW_SPEED = 3.0` (time constant about 0.33 s): tube static, lag judged acceptable, movement judged OK. |
| Hypothesis verdict | PARTIALLY CONFIRMED |

---

## Recommendation: PROCEED

The core interaction — rotating a ball around the outside of a tube while the
tube auto-advances — works and was accepted once the camera model was corrected.
The original camera assumption was wrong, but the fix was quick and the tester
signed off on the result. Several things are unvalidated (see Lessons Learned),
so this PROCEED covers the core mechanic and camera model only, not tilt input,
difficulty pacing, or obstacle variety.

---

## If Proceeding

- **Core tuning values discovered** (starting points; the tester did not object to
  them but did not sign off on each individually): `CAMERA_FOLLOW_SPEED` 3.0,
  camera radius 6.0 from the axis (`TUBE_RADIUS` 3.0 + `CAMERA_RADIUS_OFFSET` 3.0),
  `CAMERA_BACK_DISTANCE` 6.0, `CAMERA_LOOK_AHEAD` 12.0, forward speed 6.0 units/s,
  angular speed 3.0 rad/s, ball radius 0.4, obstacle half-angle 0.35 rad.
- **Assumptions confirmed:** one-axis angular control around a tube exterior is
  playable; a lagged camera makes the ball's movement around the tube visible.
- **Assumptions disproved:** `game-concept.md` says the follow camera "does NOT
  roll" and that the screen horizon stays stable (Core Mechanics item 3, MVP
  Required item 4, Open Questions). Actual working model: camera orbit lags the
  ball's angle and DOES roll with the orbit so the tube stays static on screen.
- **Emergent mechanics:** the tube hides the far side, so obstacles there are
  unseen until the ball goes around. The tester found this engaging.

**Design conflict to resolve later (not decided here):** the hidden-obstacle
surprise the tester liked conflicts with the locked pillars *Instant Readability*
and *Fair but Merciless Difficulty* (deaths caused by reaction, learnable
patterns). Resolve in `/design-system` or by revisiting the pillars.

**Next steps:**
1. Update `design/gdd/game-concept.md` camera description (see Assumptions disproved)
2. `/design-review design/gdd/game-concept.md`
3. `/gate-check`
4. `/art-bible`, then `/map-systems`
5. `/design-system [mechanic]` (use the tuning values above in Tuning Knobs)

---

## If Pivoting

Not applicable — verdict is PROCEED.

---

## If Killing

Not applicable — verdict is PROCEED.

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  That a non-rolling camera would be comfortable. A camera that stays level while
  orbiting made the tube swing on screen; making the camera roll with its orbit
  produced the static-tube result the tester wanted.

- **What surprised us that didn't show up in the brainstorm?**
  The tube occluding the far side turned out to be liked, not just a flaw, which
  conflicts with the readability and fairness pillars.

- **What would we test differently next time?**
  Test on a real phone with accelerometer tilt early (input direction and
  sensitivity were only checked with keys). Include more than one obstacle type,
  a speed ramp, and more than one tester. Not validated at all: sustained
  sessions, tilt input, difficulty pacing, obstacle variety.

---

> *Prototype code location: `prototypes/ball-in-tube-movement-concept/`*
> *This code is throwaway. Never refactor into production.*
