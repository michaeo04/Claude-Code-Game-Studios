# ADR-0010: Presentation time, hit-stop and the Ink cover

## Status

Proposed

## Date

2026-10-03

## Last Verified

2026-10-03

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

ADR-0002 froze the world with `dt_eff = 0` and left open which presentation effects keep running, on what clock, and how hit-stop and the Ink cover work. This ADR makes **one rule** for presentation time: every presentation effect is a pure function of a **microsecond stamp** taken from the injected `clock_us` and the current `clock_us` (`elapsed = (now_us - start_us) / 1e6`), evaluated in the owning core at its tick. No presentation timer accumulates `dt`, no shader reads `TIME`, and nothing uses `Engine.time_scale` or `SceneTree.paused`. On that rule: **hit-stop** is a 0.20 s presentation hold (the world is already frozen by the Hit phase) that delays only the shard burst; the **FOV ease** runs on the same clock so it finishes while `dt_eff = 0`; the **Ink cover** is a phase-driven layer-30 cover that turns opaque on the tick of `phase_changed` and fades out, for Menu boundaries only (not Restart).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (timing), UI (CanvasLayer), Particles |
| **Knowledge Risk** | LOW for the APIs used (`CanvasLayer`, `ColorRect`, `Control.visible`, `mouse_filter`, `GPUParticles3D.restart()`, `one_shot`, `emitting`, `Camera3D.fov`); HIGH only for the 4.7 particle change (angular velocity corrected) and for behaviours not in the engine reference (see Verification) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.4 `restart(keep_seed)`, 4.5 recursive Control behaviour, 4.6 dual focus, 4.7 particle angular velocity), `deprecated-apis.md`, `modules/animation.md`, `modules/ui.md`, `modules/rendering.md` |
| **Post-Cutoff APIs Used** | None. `GPUParticles3D.restart()` gained an optional `keep_seed` parameter in 4.4; it is called without arguments |
| **Verification Required** | **PT-1 (device):** the first presented frame after the tick of `phase_changed` is fully opaque (frame capture), at 60 and 120 Hz. **PT-2 (device):** a one-shot `GPUParticles3D` that is hidden and not emitting produces its burst on the frame after `restart()` on Mobile, with no first-frame pop, and the 4.7 angular-velocity change is acceptable visually. **PT-3 (device):** a stall of 5 s during Hit releases the hold at the first tick back, and no stale alpha remains. **PT-4 (device):** tap spam Play / Pause / Menu / Play reaches at most 3 ledger entries per second (Risks). **NEEDS VERIFICATION, not in the reference:** whether `CanvasLayer.visible = false` blocks GUI input (ADR-0011 relies on it; add one assertion to its integration test; this ADR toggles the `ColorRect` itself); and whether a `ColorRect` whose `visible` is false costs nothing on Mobile (expected). Engine specialist review: no blocking finding |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (tick order, `clock_us`, `dt_eff`), ADR-0011 (layer 30, inert-control rules, view and core split) |
| **Enables** | the Juice & Feedback hit sequence, Menus Ink cut, Camera FOV ease and HUD banner stories; closes TR-juice-feedback-007 and TR-menus-screen-flow-012 |
| **Blocks** | Juice & Feedback epic (hit sequence), Menus & Screen Flow epic (Ink cut), Camera epic (FOV punch) |
| **Ordering Note** | Refines ADR-0012 (the grey-out crossfade, now `GREY_CROSSFADE_S` in seconds, runs on this clock); no interface of ADR-0012 changes. Resolves ADR-0011 Open Question 2 (the Ink cover's owner) |

## Context

### Problem Statement

ADR-0002 decision 10 says Tween, AnimationPlayer, GPUParticles3D and shader time keep advancing while `dt_eff = 0`, "decided in ADR-0010". Three things are therefore undecided: (1) which presentation effects need a game-owned clock and which may be engine-driven; (2) what "hit-stop" means when the Hit phase already freezes the world; (3) how the Ink cover that hides Tube Track's seam-phase jump is driven. `architecture.md` Data Flow records two user decisions (hit-stop as a real-time hold, no `Engine.time_scale`, no tree pause; the Ink cut driven by `phase_changed`), but the Menus GDD and UX spec still describe a fade-in before the phase change, and the Camera GDD's FOV ease has no clock when `Camera.step(theta, s, dt_eff)` is a frozen no-op at `dt_eff = 0`.

### Constraints

- `dt_eff = 0` in Hit, Paused, Resuming and on settling ticks; `Camera.step` at `dt_eff <= 0` must leave `phi_cam`, position and `d_cam` bit-identical (TR-camera-009).
- `Engine.time_scale` and `SceneTree.paused` are forbidden (ADR-0002). View nodes have no `_process` (ADR-0002); cores hold no engine calls and receive `clock_us` by injection.
- Hit-stop `HITSTOP_ACTUAL` = 0.20 s, at most `HITSTOP_MAX` (Run State F4); reduced motion never changes it (Juice Rule 10). Run State never calls Juice.
- At most 3 flashes per second system-wide (Juice Rule 11); the Hit flash is at most 30% opacity and lasts `HIT_FLASH_S` (about 2 frames at 60 Hz).
- Menus Core Rule 9: at least one presented frame hides the seam jump at both Menu to Running and Running to Menu. UX envelope for the cut: about 150 to 250 ms.
- No stacked full-screen translucent layers other than one Hit flash or one modal scrim, never together with the Ink cover (ADR-0011).
- Draw calls: Menus 25 and HUD 20 are not concurrent (ADR-0003).

### Requirements

- One time rule that is testable headless with a fake clock.
- The hit sequence, FOV ease and Ink cover keep working through `dt_eff = 0`, a stall and a refresh rate of 60, 90 or 120 Hz.
- Every route into or out of Menu gets the cut without the cover knowing the route.
- A phase change is never delayed by presentation (Run State is the sole owner of phase).

## Decision

### 1. One presentation-time rule

**Every presentation effect is a pure function of a stamp and the clock.** The owning core stores `start_us` (taken from the injected `clock_us` in the event handler) and computes `elapsed_s = PresentationMath.elapsed_s(start_us, clock_us.call())` at its tick or on query. It never accumulates `dt`. Consequences: no drift against the display refresh rate, a stall or a backgrounded app finishes an effect at the next tick instead of freezing it, and a fake clock drives every test.

Classification (what runs on which clock):

| Effect | Clock | Driver | Frozen by `dt_eff = 0`? |
|---|---|---|---|
| Ball, tube scroll, hazards, run time, score | `dt_eff` | Ball, Tube Track, Run State | Yes |
| Seam stripes, fog, sky | none (functions of `s` and uniforms; no `TIME`) | Tube Track, Environment | Yes (inputs frozen) |
| Hit hold, shard release, Hit flash, grey-out crossfade | stamp `hit_us` | `JuiceCore` | No |
| Near-miss rim, ring pulse, PB bloom and sweep | stamp per event | `JuiceCore` | No |
| FOV punch ease | stamp `punch_us` | `CameraCore` | No |
| Ink cover | stamp `cut_us` | `InkCoverCore` | No |
| Resume countdown ring | stamp `resume_us` | Run State (already `clock_us`) | No |
| HUD and Menus pill press feedback | none (set on `button_down` / release, no animation) | views (ADR-0011) | n/a |

`Tween` and `AnimationPlayer` are **not used for any effect in the table**. They are allowed only for the cosmetic UI motions of ADR-0011 (never gameplay or hit presentation), created with `create_tween()` on the view node, killed on `run_reset`, and they read no game state. They advance on the engine delta (`time_scale` is 1; any cap on that delta is unverified), which is acceptable for cosmetics. Shaders do not read `TIME`: an event effect receives a **progress uniform in [0, 1]** written by its core (only when changed), a world shader reads none. `GPUParticles3D` is engine-driven by design (its internal lifetime runs on the engine delta, not `clock_us`; after a stall a burst may jump to the end of its lifetime, which is cosmetic and checked in PT-3), started once by `restart()` at a core-decided stamp, and reads no state. Shard node setup: `visible = true` and `emitting = false` in the scene (a hidden node is not simulated; nothing bursts at instantiation), `one_shot = true`, a `visibility_aabb` covering the burst, `global_transform` set **before** `restart()`, completion read from the `finished` signal (never from `emitting`), and the default `keep_seed = false` (the pattern need not be reproducible). Other engine-driven items that keep advancing at `dt_eff = 0` and feed no state: particle process shaders, ScrollContainer touch inertia, `SceneTreeTimer`. The shader lint covers particle process materials as well as `assets/shaders/**`.

### 2. `PresentationMath` (pure, static)

```gdscript
class_name PresentationMath extends RefCounted
const NOT_STARTED := -1
static func elapsed_s(start_us: int, now_us: int) -> float                  # NOT_STARTED -> -1.0; otherwise max(0, now - start) / 1e6
static func hold_released(start_us: int, now_us: int, hold_s: float) -> bool  # false for NOT_STARTED
static func fade_out(elapsed_s: float, hold_s: float, fade_s: float) -> float # 1.0 for elapsed < hold; linear to 0.0 over fade_s; 0.0 after; 0.0 for elapsed < 0
static func ease_out_linear(amount: float, duration_s: float, elapsed_s: float) -> float  # Camera F5; amount * (1 - e/d) on [0, d]; 0 outside or for non-positive d
```

### 3. Hit-stop

Hit-stop is **not a freeze mechanism**. The world is frozen by the Hit phase (`dt_eff = 0`, ADR-0002) for as long as the phase lasts; hit-stop is a **0.20 s presentation hold** that delays the shard burst so the frozen impact frame reads before the ball breaks (Juice sequencing). On `run_ended` (rank 1, ADR-0002):

- `JuiceCore.on_run_ended` stamps `hit_us = clock_us.call()` and the killer `hazard_id`. At that same tick it requests the Hit flash (`HIT_FLASH_S` ≈ 0.033 s, `HIT_FLASH_OPACITY` 0.30, scaled by reduced motion) and sets `hit_grey` to its crossfade (`GREY_CROSSFADE_S` ≈ 0.033 s, ADR-0012); both durations are seconds on the stamp clock, so they are the same at 60 and 120 Hz and after a stall (they replace the Juice GDD's "2 frames" and "1 to 2 frames"). Both therefore appear at t = 0.
- `JuiceCore.tick()` (the Juice tick step) sets a one-shot edge `shards_release` the first time `hold_released(hit_us, now, hitstop_actual)` is true. `JuiceView` consumes the edge: it hides the ball (`ball_visible_sink(false)`, a Juice-only Callable into `BallView.set_ball_visible`, ADR-0012) and calls `shards.restart()` at the ball's pose (the `BallView` global transform, in render space, ADR-0013; the emitter is created at the Hit, no rebase runs in Hit, and `run_reset` clears it, so it is never re-placed). The emitter sets `fixed_fps` deliberately (the default of 30 looks steppy at 60 Hz; 0 follows the display) and PT-2 checks `interpolate`. Release is at t = 0.20 s, or at the first tick back after a stall.
- `run_reset` (rank 5) clears `hit_us`, the edge, the shards and the ball visibility, unconditionally (Juice Rules 7 and 8). A restart tap cannot arrive before `RESTART_LOCK` >= 0.45 s, so release always precedes it; Rule 8 covers the case anyway.
- `hitstop_actual` is `JuiceConfig` data, validated by `validate_hitstop` (at most `HITSTOP_MAX`); `RESTART_LOCK - hitstop_actual >= T_READ` stays Run State's check. Reduced motion never changes it. The personal-best bloom and sweep are **not** gated by the hold (Juice GDD timing applies).

### 4. FOV ease on the presentation clock

`CameraCore.apply_fov_punch(amount, duration)` stamps `punch_us`; `CameraCore.fov_offset_deg()` returns `PresentationMath.ease_out_linear(amount, duration, elapsed)` at the injected clock (a new call replaces the previous punch, as Camera F5). `CameraCore.step(theta, s, dt_eff)` is **unchanged** and stays a frozen no-op at `dt_eff <= 0` (TR-camera-009 holds: FOV state is not in its bit-identical set). `CameraView` writes `Camera3D.fov = CAMERA_FOV + fov_offset_deg()` in the Camera step, only when changed. `CameraCore.on_run_reset` clears the punch. `CameraCore` gains an injected `clock_us`.

### 5. Ink cover

**Owner:** `InkCoverCore` (RefCounted) inside the Menus module, ticked by `Menus.tick`; `InkCover.tscn` is the layer-30 view (ADR-0011). It is driven by `phase_changed`, never by a request, so Play, the HUD Menu button, Back and every future route behave the same.

**Route predicate** (the only place it is written):

```gdscript
static func is_cut_route(new_phase: int, old_phase: int) -> bool:
    return (new_phase == Phase.MENU and old_phase != Phase.BOOT) \
        or (old_phase == Phase.MENU and new_phase == Phase.RUNNING)
```

So Menu to Running (Play) and Hit or Paused to Menu get the cut. **Restart (Hit to Running), Resuming to Running, Running to Paused and Boot to Menu do not** (user decision 2026-10-03: Restart is the instant-retry path and the world has just reset under the grey-out; no extra luminance step in the death-restart cycle).

**Timeline** (`InkCoverConfig`, data-driven): on a cut route, `on_phase_changed` (rank 5, same tick as the phase change, inside `RunState.tick`) stamps `cut_us`, samples `reduced_motion_enabled` once, and calls `flash_sink(now_us)` (Juice's ledger, see 7). `alpha()` = `fade_out(elapsed, INK_HOLD_S, fade_s)` with `INK_HOLD_S` = 0.05 s (three presented frames at 60 Hz, Run State F2 `N_present`), `fade_s` = `INK_FADE_S` 0.18 s, or `INK_FADE_REDUCED_S` 0.30 s when reduced motion was on at the trigger. Totals: 0.23 s (within the UX envelope of 150 to 250 ms) and 0.35 s. A new cut route during a cut re-stamps (alpha returns to 1; no stacking). `covering()` = `alpha() > 0` is Menus AC-13's `transition_covering`.

**Hold is time only.** The hold ends `INK_HOLD_S` after the stamp on the injected clock; there is no tick-count rule (decided 2026-10-03: `InkCoverCore` has no `tick()` and `PresentationMath.fade_out` takes seconds only). The cover is written opaque in the tick that stamps it, so the first presented frame is always covered (PT-1); after a long stall the hold may already have elapsed on the next presented frame, and that is accepted because the fairness constraint below bounds `INK_HOLD_S`, not the frame count.

**Same-frame guarantee** (verified against Godot's frame model: input, then `SceneTree.process`, then the message-queue flush, then `RenderingServer.draw`; `visible` and `modulate` reach the server immediately). It holds only if every world change happens inside `GameRoot._tick`: **no `call_deferred`, Tween callback or `await` may move the tube or change the seam phase** (lint and review rule). The stamp is taken inside `RunState.tick`; the world changes at `TubeTrack.advance` and later; `InkCoverView.tick` runs in the Menus tick step and writes alpha 1 before the frame is drawn, so the first presented frame after the seam jump is covered. The cover is **not delayed behind the phase change** and does not delay it.

**View:** `CanvasLayer` layer `UiLayers.INK_COVER` (30) with one full-rect `ColorRect` in Ink (a palette colour of `ui_theme.tres`), `mouse_filter = STOP`. It is `visible = false` when `alpha() == 0` (no input, no draw) and writes `modulate.a` (one RenderingServer property set; `color.a` would re-record the item) only when changed. `Menus.tick` ticks the cover **unconditionally**, also when no Menus screen is visible (Hit to Menu, Paused to Menu). Hiding a pressed Control in the screen swap drops its pending release (the `pressed` signal does not fire), which is the wanted behaviour. Taps are blocked while visible (the ADR-0011 blocker rule). In the same tick as the cut, Menus swaps its screens, so a Paused backdrop or a modal scrim is hidden before the fade begins and never stacks translucently with the cover.

**`run_reset` does not clear the cover.** Play fires `run_reset`, `run_started` and `phase_changed` in one tick; the cover must survive the reset (Juice Rule 7 clears Juice's presentations only).

**Fairness constraint** (validated at the composition root next to the Juice validators): `INK_HOLD_S + INK_FADE_REDUCED_S <= s_first / V_START - T_REACT` (0.35 <= 11 / 10 - 0.25 = 0.85 at defaults), else `INK_COVER_EXCEEDS_BUDGET`; pre-committed response: shorten the fade, never raise `s_first`'s dependents. Pattern & Difficulty owns `s_first`, Ball Movement `V_START`, Run State `T_REACT`.

### 6. Wiring

```gdscript
# GameRoot._wire() additions (rank 5, "everything else")
[_run_state.phase_changed, _ink_core.on_phase_changed, 5],
# existing rows unchanged: run_ended -> _juice.on_run_ended (rank 1), run_reset -> _juice/_camera.on_run_reset
# construction: _ink_core = InkCoverCore.new(clock_us, ink_config, settings.reduced_motion_getter, _juice.register_flash)
```

`GameRoot._tick` is unchanged (the Camera step and the Juice, HUD and Menus tick steps already exist, cited by name because ADR-0002 Decision 6 inserts steps); the Camera view applies FOV in the Camera step, and `Juice.tick`, `HUD.tick` and `Menus.tick` (which ticks the Ink cover) run after it.

### 7. Flash accounting

Each Ink cut registers one entry in the shared flash ledger (Juice Rule 11) through the injected `flash_sink`. The cut is never throttled (it must hide the seam); it only reduces headroom for the throttleable near-miss ring. Structural bound: a cut is at least 0.5 s after the Hit flash (`RESTART_LOCK`), Play needs a gated tap, and Menu to Running to Menu needs two taps, so the ledger holds at most 3 entries in any second in normal play. Tap spam is verified by PT-4; **pre-committed response** if it exceeds 3: Menus and HUD ignore a Play or Menu tap within `INK_MIN_INTERVAL_S` = 0.35 s of the last cut start (1 / 0.35 = 2.86 per second).

### Architecture Diagram

```
 clock_us (ADR-0002) --------------------------------------------------------+
   |                                                                          |
 RunState.tick (3) --phase_changed--> InkCoverCore.on_phase_changed  (stamp cut_us, flash_sink)
        |--run_ended (rank 1)--> JuiceCore.on_run_ended (stamp hit_us)   --run_reset--> clears Juice + Camera punch (NOT the cover)
 Camera view (9):  fov = CAMERA_FOV + CameraCore.fov_offset_deg()          [stamp punch_us, ease_out_linear]
 Juice tick:  Juice.tick -> shards_release edge at hit_us + 0.20 s -> JuiceView: ball hidden, shards.restart()
           Menus.tick -> InkCoverView.tick: alpha = fade_out(elapsed, 0.05, 0.18|0.30) -> CanvasLayer 30 ColorRect
 World (dt_eff): Ball, Tube, Hazards   <- frozen in Hit/Paused/Resuming; presentation above is not
```

### Key Interfaces

```gdscript
class_name InkCoverCore extends RefCounted
func _init(clock_us: Callable, config: InkCoverConfig, reduced_motion: Callable, flash_sink: Callable) -> void
func on_phase_changed(new_phase: int, old_phase: int) -> void      # stamps on a cut route only
func alpha() -> float                                               # reads the clock; [0, 1]
func covering() -> bool                                             # alpha() > 0 (Menus AC-13)
static func is_cut_route(new_phase: int, old_phase: int) -> bool

class_name InkCoverConfig extends Resource      # validated(log_sink) -> copy; clamps
# INK_HOLD_S 0.05 [0.034, 0.10] (time only, no tick rule); INK_FADE_S 0.18 [0.10, 0.30]; INK_FADE_REDUCED_S 0.30 [INK_FADE_S, 0.40]

# JuiceConfig additions (seconds on the stamp clock; validated, clamped)
# HIT_FLASH_S 0.033 [0.016, 0.050]; GREY_CROSSFADE_S 0.033 [0.016, 0.050]

# JuiceCore additions
func on_run_ended(run_id: int, hazard_id: int, run_time_ms: int) -> void
func tick() -> void                                                 # sets the shards_release edge once
func consume_shards_release() -> bool                               # true once per hit, then false
func register_flash(now_us: int) -> void                            # ledger entry (also used by Ink cover)
# CameraCore additions: apply_fov_punch(amount, duration), fov_offset_deg() -> float, on_run_reset(run_id)
```

## Alternatives Considered

### Alternative 1: Engine Tween / AnimationPlayer drive the effects

- **Description**: start a Tween on each event (hold via `tween_interval`, cover fade via `tween_property`), `PROCESS_MODE_ALWAYS`.
- **Pros**: least code.
- **Cons**: not testable headless with a fake clock; Tween time follows the engine delta (capped 0.133 s) and the frame rate; the fairness constraint on the cover cannot be asserted; overlapping triggers need manual `kill()` bookkeeping.
- **Rejection Reason**: ADR-0002 and ADR-0011 make cores the testable owners; the cover's timing is a fairness input.

### Alternative 2: `Engine.time_scale` or `SceneTree.paused` for hit-stop

- **Description**: slow or pause the tree for 0.20 s.
- **Pros**: one call.
- **Cons**: forbidden by ADR-0002 (`engine_time_scale_writes`, `scene_tree_paused_for_pause`); Run State derives time from the real clock; the tick must keep polling Tilt and the restart lock.
- **Rejection Reason**: already rejected; recorded only so it is not reopened.

### Alternative 3: Accumulate `real_dt` in presentation timers

- **Description**: each effect adds `real_dt` per tick until its duration.
- **Pros**: no stamps.
- **Cons**: drifts with dropped frames; a stall inflates or skips; every consumer needs the right `dt`; `Camera.step` would need `real_dt` as a fourth argument.
- **Rejection Reason**: stamps are exact, stall-proof and need no extra tick arguments.

### Alternative 4: Fade the cover in before the phase change (UX spec)

- **Description**: Menus waits for the fade-in, then sends the request.
- **Pros**: no hard cut to Ink.
- **Cons**: delays Run State's phase change (the sole owner of phase) by about 100 ms; needs a "pending" state and arbitration with a Back press during the fade; each route needs its own wiring.
- **Rejection Reason**: presentation must never gate gameplay (`architecture.md` principle 5); the hard-cut-then-fade hides the jump on the same frame.

## Consequences

### Positive

- One rule, one helper, one fake clock for every presentation test; stall and refresh-rate proof.
- Every route to Menu gets the cut for free (driven by `phase_changed`).
- Camera and Run State contracts stay unchanged (`step` keeps its signature).
- The Menus GDD's `transition_covering` flag and the Juice hold become data-driven and unit-testable.

### Negative

- A hard cut to Ink on the transition tick is the abrupt luminance step the UX spec avoided (accepted, user decision 2026-10-02; softened by the longer fade under reduced motion).
- Taps are blocked for up to 0.35 s at a cut (the cover is STOP while visible).
- Five cores gain an injected `clock_us` or a stamp field (Juice, Camera, Ink cover; Run State already has it).
- Restart does not hide a possible seam-phase jump (accepted; PT-1 includes a Restart frame capture).

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| The cover hides the first hazard approach at run start | Low | High | fairness validator `INK_COVER_EXCEEDS_BUDGET`; margin 0.85 vs 0.35 at defaults |
| A Restart seam-phase jump is visible | Medium | Low | PT-1 captures it; response: add Hit to Running to `is_cut_route` and re-check the ledger |
| Three cuts plus a Hit flash exceed 3 per second by tap spam | Low | High | PT-4; `INK_MIN_INTERVAL_S` debounce (pre-committed) |
| `GPUParticles3D.restart()` pops or changes look in 4.7 | Medium | Low | PT-2; shards are cosmetic and reduced-motion scaled |
| `run_reset` handler order clears the cover by mistake | Low | Medium | explicit rule and test: `run_reset` does not touch `InkCoverCore` |
| The first presented frame after `phase_changed` is not opaque (late write) | Low | Medium | cover written in the Menus tick step before draw; PT-1 |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/juice-feedback.md` | Rule 3: hit-stop 0.20 s, flash and grey-out at onset, shards as hit-stop ends | stamp `hit_us`, `shards_release` edge, Hit flash and grey-out at t = 0 |
| `design/gdd/juice-feedback.md` | Rules 7, 8, 10, 11: `run_reset` clears presentations; early restart safe; reduced motion never shortens hit-stop; flash ledger | `run_reset` clears hold and shards; `hitstop_actual` fixed; cuts registered in the ledger |
| `design/gdd/menus-screen-flow.md` | Core Rule 9 and AC-13: at least one frame hidden at both boundaries; `transition_covering` | route predicate, 0.05 s hold, `covering()` |
| `design/ux/menus-screen-flow.md` | Ink cut, 150 to 250 ms, Ink colour, not a white flash | 0.23 s default, Ink `ColorRect` (see GDD sync) |
| `design/gdd/run-state-restart.md` | `HITSTOP_MAX`, F4 lock check, `phase_changed`, `N_present`; Run State never calls Juice | hold <= `HITSTOP_MAX`; cover hold = `N_present` frames; `phase_changed` is the only trigger |
| `design/gdd/camera.md` | F5 FOV ease; one FOV hook; TR-camera-009 | `ease_out_linear` on the stamp clock; `step` unchanged |
| `design/gdd/tube-track.md` | Open Question 9: seam-phase jump hidden | cover opaque on the tick of the change |
| `design/gdd/settings-accessibility.md` | `reduced_motion_enabled` consumers | sampled at the trigger: longer fade; Juice scales intensities |
| `design/gdd/hud.md` | Menu button and Back reach Menu | route-agnostic (phase-driven) |

## Performance Implications

- **CPU**: one clock read and a few float operations per presentation core per tick (well under 0.05 ms in total); the cover writes one property per frame during its 0.23 to 0.35 s.
- **Memory**: one `ColorRect` and a few ints; nothing allocated during a run (the view exists at boot).
- **Load Time**: none.
- **GPU**: one full-screen alpha-blended draw (1 draw call) while visible, inside Menus 25 / HUD 20 (not concurrent with a scrim). Measured in R-1 with the ADR-0003 method.
- **Network**: n/a.

## Migration Plan

Greenfield. Order: `PresentationMath` and tests; `InkCoverCore` and `InkCoverConfig`; `JuiceCore` hold; `CameraCore` FOV stamp; views; `_wire()` row. Rollback: supersede with an ADR that moves the cover behind the phase change (Alternative 4); the cores and the stamp rule do not change.

## Validation Criteria

- [ ] `PresentationMath` boundary tests: `elapsed_s` with a stall, `NOT_STARTED`, `fade_out` at the hold and fade edges, `ease_out_linear` at 0 and at the duration.
- [ ] Juice: release at exactly `hit_us + 0.20 s` and at the first tick after a 5 s stall; `run_reset` clears; reduced motion leaves it unchanged.
- [ ] Ink cover: a test over every ordered (old, new) phase pair against the route table; alpha curve; reduced motion sampled once at the trigger; re-stamp; `run_reset` does not clear; `covering()` true across both Menus boundaries (AC-13).
- [ ] Fairness validator rejects hold + fade above the budget with `INK_COVER_EXCEEDS_BUDGET`.
- [ ] Lint: no `Engine.time_scale` write, no `TIME` in `assets/shaders/**`, no `create_tween` / `AnimationPlayer` outside the ADR-0011 UI motion views, no presentation timer that adds `real_dt`.
- [ ] Device PT-1 to PT-4 recorded under `production/qa/evidence/`.

## Related Decisions

- ADR-0002 (tick order, `clock_us`, `dt_eff`), ADR-0003 (draw calls), ADR-0011 (layer 30, blocker rule), ADR-0012 (grey-out crossfade, ball view)
- `docs/architecture/architecture.md` (Data Flow decisions taken 2026-10-02)
- `design/gdd/juice-feedback.md`, `design/gdd/menus-screen-flow.md`, `design/ux/menus-screen-flow.md`, `design/gdd/camera.md`, `design/gdd/run-state-restart.md`
