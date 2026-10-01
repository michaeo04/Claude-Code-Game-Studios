# Cross-GDD Review Report

> **Date**: 2026-10-01
> **Scope**: 18 documents (game concept, systems index, 16 system GDDs), the entity registry, `design/ux/hud.md`, `design/ux/menus-screen-flow.md`. Android only (ADR-0001).
> **Method**: three independent read-only passes (consistency 2a-2f, design holism 3a-3g, scenario walkthrough, 8 scenarios). **Provenance:** findings are as reported by the three review passes; the blocking items had not been re-checked line by line against the source files when this report was written. Verify each blocker before editing the GDD it names.
> **Verdict: FAIL** (9 blocking items). Warnings do not block.
> **Not reviewed in full**: Save & Persistence (Overview, Player Fantasy and Core Rules only for the design pass), the art bible beyond greps, Playtest Telemetry (no GDD).

---

## Consistency issues

### Blocking

**C1. Map 1 cannot load: Environment's fog values break Tube Track's window validator.**
- `environment-theming.md` F1 and Tuning Knobs: Map 1 `fog_depth_begin` 44, `fog_end_distance` F = 84. `tube-track.md` F3, Tuning Knobs (default A = 6, N = 9), AC-11 and AC-12 are written for F = 48 and F_read = 46.
- Tube Track F3 needs `A >= ceil((F + v_max * t_lat) / L) + 1`, which is 9 at F = 84; the shipped A = 6 fails `A_TOO_SMALL`. N becomes 12, so the `t_reset` budget costed for N = 9 changes too.
- Decision needed: update Tube Track defaults, worked examples and ACs to F = 84, and name who owns the pass.

**C2. "Device not supported" (the FALLBACK exclusion) is relied on but enforced by nobody.**
- `ball-movement.md` Rule 6 / B9, `tilt-input.md` rules 11 and 13, `systems-index.md` Notes: a no-sensor device is blocked from play. But in `FALLBACK` Tilt Input reports `valid` = true and `state` = Live; `menus-screen-flow.md` Core Rule 2 gates Play only on `valid`; `hud.md` Rule 7 does not read `input_source`; the UX spec (Open Question 11) reuses `No motion sensor` and does not gate on `input_source`.
- Decision needed: gate Play and Resume on `input_source == SENSOR` (with an AC), or stop FALLBACK from reporting `valid` = true.

**C3. Restart gating on `valid` contradicts across Tilt Input, Run State and Menus.**
- `tilt-input.md` rule 10 and `run-state-restart.md` rule 14: Play, Resume and Restart are gated on `valid`. `menus-screen-flow.md` Core Rule 3 and AC-5: the Paused screen's Restart and Menu are forwarded regardless of `valid`.
- Reachable case: a button pause, then the sensor drops (`sensor_lost` is a no-op in Paused). Restart starts a run on a dead sensor and abandons the old run.
- Decision needed: gate Paused Restart on `valid`, or amend Tilt Input and Run State to exempt it.

**C4. Stale near-miss events can fire at restart.**
- `near-miss-detection.md` Rule 5 (`hazard_released` emits `near_miss_detected` if `was_in_near_zone` and not `hit_ever_true`); `obstacle-system.md` Rule 5 (`window_primed` releases every hazard at `run_reset`); `juice-feedback.md` Rules 2 and 7 (no `run_id` filter; run_reset clears presentations).
- Death near another hazard's zone, or a pause frozen in a near zone, then Restart or Menu: the release emits a near-miss for the old run that can trigger ring, haptic and FOV punch at the start of the new one.
- Decision needed: suppress `near_miss_detected` on release-due-to-reset, or require Juice to drop events with a stale `run_id`.

### Warnings

- **W1. Systems index "Depends On" is stale:** Obstacle omits Camera (and provisional Pattern & Difficulty); Environment omits Camera (`d_cam`) and Settings (`colorblind_safe_enabled`); HUD lists Near-Miss although `hud.md` Rule 10 says HUD does not consume it; Tilt Input and Run State show no dependencies although Platform Services lists them as dependents; status text is stale (Platform Services, HUD).
- **W2. One-directional dependencies:** Juice reads `reduced_motion_enabled` but Settings does not list Juice; `L_ball_adjusted` from Environment has no row in Ball Movement; Platform Services' `app_returned` guard re-anchor has no request in Run State (Open Question 17, Platform AC-16 deferred); Tilt Input lists Scoring as a soft consumer of `input_source` and Scoring never mentions it; Tilt's settle must count only while `attentive` (Platform Open Question 24, edit pending).
- **W3. `milestone_crossed` has no consumer:** Scoring emits it, HUD declines it, Juice has no row (its Core Rule 1 admits three triggers). The concept promises distance milestones.
- **W4. The 682 s `s` precision limit has no owner:** Ball Movement says Tube Track and Run State should resolve a cap or rebase; Tube Track only warns; Run State does not mention it.
- **W5. Presentation timing in Hit is unspecified:** no GDD says whether shard travel, hit-stop and the camera FOV ease run on real time or world time (game-loop ADR).
- **W6. Reset-handler budgets:** the `t_reset` shares in Run State F2 were costed before the final designs of Environment, Obstacle, HUD, Scoring and Camera; no GDD owns re-verifying the sum.

### Info
- Stale registry entries: `colorblind_safe_enabled` ("no consumer yet"; Environment F3 consumes it), `t_react` and `t_in` notes (old T_VIS_MIN sum), `stall_pause_threshold` arithmetic (old `dt_max`), `max_fps` (iOS wording). Missing entries worth adding: `s_precision_limit` (16384), `seam_hz_max` (3), the near-miss coefficients, the haptic kind values.
- Menu BEST hiding at a stored best of 0 is a UX-spec decision with no GDD rule or AC.
- Save & Persistence reuses Platform Services' `RateLimitedLog` class (a code-level coupling not listed).

---

## Game design issues

### Blocking

**D1. The hidden-side classifier does not fit the game's geometry.**
- `obstacle-system.md` F4, AC-34, AC-36; `pattern-difficulty.md` Core Rule 7, AC-10 and the fixture table; `camera.md` F3.
- `hidden := abs(delta_theta(center, THETA_REF)) > VISIBLE_ARC_HALF_WIDTH` with the center `(theta_min + theta_max) / 2` and `THETA_REF` = 0. Every fixture Wall (W1-W4, REV2) is the piece `(0.4127, 5.8705)`: center PI, so it classifies as hidden and is rejected with `HIDDEN_CONTENT_FORBIDDEN`, although it covers about 83% of the circle and is plainly visible. The real visible arc is centered on the camera's lagged angle, not the top, so a static test bans visible content and can pass invisible content.
- Options: classify on the solution gap or silhouette; against a worst-case camera-relative arc; drop the static classifier and keep the time-budget proxy; or define hidden as "occupied arc entirely beyond the visible arc".

### Warnings

- **Camera lag vs dodge destination:** in a sustained maximum turn the camera trails the ball by about `OMEGA_MAX * CAMERA_LAG_TAU` = 1.0 rad (57 degrees) against a 60-degree visible half-width, so the destination of a hard dodge is almost outside the shown arc (P1, P2). Options: lower tau or add an omega lead term, widen the arc, fold a lag term into the visibility budget, or playtest in BM-1.
- **Visibility margin at peak speed:** `T_VIS_MIN` 1.5 s is 0.07 s above its own 1.43 s derivation (resting on a guessed latency); `F_read` 46.00 u at `v_max` leaves about 0.02 s against the floor, and the far-side hazard geometry costs about 0.4 u of that. Fog pull is a speed cue working against the fairness budget. Options: `FOG_PULL_MAX` 0 until the spike, raise the floor, lower `V_MAX` toward 22 u/s, or carry the speed cue on seams and FOV.
- **Difficulty plateaus at 90 s** (speed flat at 25 u/s, tier `FULL`); an expert reaches the 682 s ceiling (score about 16384) and the only escalation left is library size.
- **Neutral-hugging is risk-free early:** every INTRO chunk (W1-W4) has its gap at theta = 0 and `MAX_OPPOSING_FRACTION` guards against clustering rather than for spread.
- **Near-miss has no payoff beyond feel:** score is distance only, and the best players see the fewest near-misses (Scoring Open Questions 6, 7).
- **Resume re-bases the hand-to-angle mapping:** after a resume the neutral maps to the frozen ball angle, so "level = top" no longer holds; a deathless pause breaks muscle memory with only a 2 s countdown.
- **P4 vs reclined posture:** the pillar promises "reclined", but Tilt Input's formula loses gain at high pitch (Open Question 6); only sensitivity 0.5-2.0 mitigates.
- **`tilt_sensitivity` is tuned blind** (Settings reachable only from Menu, no preview).
- **"Reduced motion" leaves the camera roll and the FOV punch intact.**
- **Run sequence is seeded by per-session `run_id`:** run N of every session replays the same order, and a PB can be set on an easy shuffle.

### Info
- The dominant loop is clear (chase the personal best); attention budget about 3 active items; no economy to analyze (source/sink N/A); pause, restart and hit-stop exploit checks found nothing; curves scale compatibly; P4 and anti-pillar checks pass for the UI; the P4 name "One-Thumb" describes a whole-hand tilt control.
- Post-MVP boosters (shield, magnet, slow-time) will need a rule for how booster runs count toward the PB (P5).

---

## Cross-system scenario issues

Scenarios walked: 1 death tick, 2 restart, 3 sensor lost, 4 app interrupted, 5 first run ever, 6 settings change in Menu, 7 boot and failure, 8 seam precision and the visibility margin.

### Blockers

**S1. `run_reset` handler order is unspecified but the handlers have data dependencies (scenario 2).**
- `run-state-restart.md` Core Rule 4 requires only that every handler returns before `run_started`; `scoring-personal-best.md` Rule 11 promises no subscriber order.
- Tube Track's adapter (`begin_run`, `window_primed`) running before Pattern & Difficulty's reseed gives the new run's opening hazards from the old PRNG and bag state (breaks determinism by `run_id`, grace zone and first draw). Camera snapping before Ball Movement resets snaps to the death pose, with a 0.33 s swing on the first controllable frame.
- Decision needed: pin the reset order (ADR or composition root), or have dependents re-read at `run_started`.

**S2. Scoring and Juice both subscribe to `run_ended`; their order decides whether the personal-best celebration plays (scenario 1).**
- Scoring emits `personal_best_updated` inside its own handler; Juice classifies Hit vs abandon by its own track state (`juice-feedback.md` Core Rule 5). If Scoring runs first, Juice is `Idle`: a real death is treated as an abandon and the celebration is dropped, or `JUICE_PB_CONTRACT_VIOLATION` fires on a legal path.
- Decision needed: pin Juice's handler before Scoring's, or decide hit vs abandon from something other than the track state.

**S3. Boot has contradictory `map_ready` / `load_map` semantics, and a failed load can reach Menu (scenario 7).**
- `run-state-restart.md` Interactions (line 92) maps `map_ready` to `load_map` (so it precedes loading); its Edge Cases ("If `map_ready` never arrives") says it never arrives when Tube Track validation fails (so it follows loading). A validation failure can leave Tube Track Uninitialized with Run State in Menu and Play enabled. Retry has no defined target (`menus-screen-flow.md` Rule 8; Run State Open Question 8); a late `map_ready` over the failure screen is accepted by Run State and not specified for Menus; `load_map` is listed only from Uninitialized in Tube Track.
- Decision needed: who calls `load_map`, who sends `map_ready` and when, what Retry does, and what Menu entry means if the load failed.

**S4. Two settings consumers are undefined (scenario 6).**
- `colorblind_safe_enabled`: Environment publishes `L_ball_adjusted` for "the ball's own skin system" and Ball Movement has no consumer; live versus next-`run_reset` is left to "whoever implements it" (Environment Open Question 4); the ball is visible behind Settings in Menu.
- `reduced_motion_enabled` / `seam_contrast_scale`: Tube Track names the hook but not when it samples; if only at `load_map` (Boot), a toggle in Menu never takes effect this session. Juice defines its timing (read at presentation time).
- Decision needed: name the colorblind consumer and its timing; state whether Tube Track pulls every frame, subscribes to `setting_changed`, or samples at `begin_run`.

### Warnings
- **Phantom near-miss at reset** (same cause as C4).
- **A persisting overlap kills the player after a resume**, against "an interruption never ends a run" (`run-state-restart.md` rules 3, 7, 11, 12; Edge Cases lines 211 and 221): interrupt at the contact frame, resume, wait 2.0 s, die on the first moving tick. Keep and fix the wording, or add a resume grace.
- **Sensor-recovery screen swap has no guard:** when `valid` returns Menus' Paused screen appears in the same tick, usually after the guard has expired, so a stray tap on Restart or Menu abandons the run; the cosmetic fill then shows "getting ready" on live buttons. Restart the guard on takeover, or add a Menus-side input hold.
- **Abandon-path new best:** Juice and Scoring say HUD's banner still acknowledges it; `hud.md` Rule 3 clears the banner on the same transition (zero frames).
- **Death-frame compounding spike:** a synchronous Save write, shard burst, flash, HIT haptic, banner and first-use shader compilation land on one frame and can eat the `T_READ` margin (Run State F4).
- **Hit-stop and FOV punch semantics:** the banner appears during hit-stop (against "sting, then triumph"); no cancel path for `apply_fov_punch` across a hit; the F5 ease clock is not defined as world or real time; Camera does not say whether `run_reset` clears a punch.
- **`T_VIS_MIN` margin (0.02 s) is below the model's approximations;** Tube Track defaults still read F = 48 and F_read = 46.
- **A stray touch after returning from an interruption in Hit cuts the banner** (`app_returned` has no consumer; Open Question 17 covers only Paused).
- **Lifecycle delivery thread:** Platform Services Core Rule 4 allows another thread (UNVERIFIED); Run State's "applied when sent" exception for `app_interrupted` is unsafe if so (queue and drain before the tick).
- **`haptics_intensity` has no input path into Platform Services** (its Core Rule 11 interface lists only `set_haptics_enabled`).

### Info
- Death-tick ordering is only partly specified (the places of HUD, Juice, Camera and the Tube Track adapter among `run_ended` subscribers; a different hazard's near-miss before or after `run_ended`).
- Back sends nothing in a sensor-lost Paused with `valid` false but goes to Menu in Hit with `valid` false: confirm the silent Back is intended.
- The first death shows the same number three times (score pill, BEST pill, banner).
- Obstacle reports every tick in every phase and Run State logs each ignored hit; confirm no hazards are populated in Menu.
- Two sensor strings in Hit with `valid` false (`Sensor not ready` and the primary labels): reconciled in `design/ux/hud.md` (secondary line under the primary).
- `t_reset` has no Near-Miss, Environment or Settings share and lumps "Score and HUD" at 2 ms while `hud.md` Rule 12 claims 2 ms for HUD alone.
- `MAP_LOAD_TIMEOUT` has no stated start point and time away during `app_interrupted` in Boot counts toward it.

---

## Checks that found nothing

- 2a: Ball Movement, Near-Miss, Pattern & Difficulty, Scoring, Camera, Juice, Menus, Settings and Save index rows match their GDD dependency lists, apart from W1.
- 2b: hit over pause over resume priority, settling-tick rules, hit and abandon finalization, level-triggered hit reporting, HUD and Menus ownership of tap-anywhere versus the Paused buttons, and Back routing per phase.
- 2c: event names match everywhere (`run_ended`, `run_abandoned`, `run_reset`, `restart_unlocked`, `personal_best_updated`, `personal_best_passed`, `back_pressed`, haptic kinds, `UI_TAP`, `near_miss_detected`), except the missing `app_returned` request (W2).
- 2d: single owners for `RESTART_LOCK`, `PAUSE_INPUT_GUARD`, `DT_MAX`, `hitstop_actual`, `haptics_enabled`/`haptics_intensity`, `T_VIS_MIN` versus `T_REVEAL_MIN` (documented reuse), `camera_back_distance` = `rear_extent`.
- 2e: `T_DODGE_180` 1.064 s against 1.14 s, `RESTART_LOCK` − hitstop = 0.30 s ≥ `T_READ`, `T_restart` 0.216 s, seam rate 2.08 Hz < 3 Hz, `L_min` 9, resume countdown ≥ Tilt's settle sum, `F_read` at `v_max` against both floors, hazard-free start against the 10.7 u glide.
- 2f: no pair of ACs that cannot both pass, apart from C3 and the missing AC in C2.
- Scenarios 1 (same-tick conflicts), 3 (mid-run sensor loss), 5 (first run) and 8 (precision) are specified and consistent.
- Android-only: no iOS text found in game concept, index, camera, juice, environment, HUD, Menus, Settings, Obstacle, Pattern, Near-Miss, Scoring or Tube Track.

---

## GDDs flagged for revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| tube-track.md | C1 (F = 84), S3, S4 | Consistency | Blocking |
| environment-theming.md | C1, S4 | Consistency | Blocking |
| obstacle-system.md, pattern-difficulty.md | D1 | Design | Blocking |
| camera.md | D1 (lag), S1 | Design / Consistency | Blocking |
| near-miss-detection.md, juice-feedback.md | C4, S2 | Consistency | Blocking |
| run-state-restart.md | S1, S3, C3 | Consistency | Blocking |
| tilt-input.md, menus-screen-flow.md | C2, C3 | Consistency | Blocking |
| scoring-personal-best.md | S2 | Consistency | Blocking |
| settings-accessibility.md, ball-movement.md | S4 | Consistency | Blocking |
| systems-index.md, platform-services.md, hud.md | dependency column, `haptics_intensity`, abandon path | Consistency | Warning |

The systems index statuses were **not** changed (user decision 2026-10-01); this table is the revision list.

## Verdict: FAIL

### Required before architecture begins
Resolve C1, C2, C3, C4, D1, S1, S2, S3 and S4 in the GDDs named above (each needs a decision first; none was decided in this review). Then re-run `/review-all-gdds consistency` (or `since-last-review`).

---

## Decisions taken (user, 2026-10-01)

| # | Decision | GDDs to revise |
|---|---|---|
| C1 | Raise Tube Track defaults to **A = 9, N = 12** (L stays 12, F = 84 from Environment); update examples and AC-11/AC-12; recompute the `t_reset` and draw-call budgets for N = 12 | tube-track.md, environment-theming.md, run-state-restart.md (F2 share) |
| C2 | **Menus gates Play and Resume on `valid` AND `input_source == SENSOR`**, plus an AC; HUD unchanged | menus-screen-flow.md (Rules 2, 3, 5; AC), design/ux/menus-screen-flow.md |
| C3 | **Gate Paused Restart on `valid`** (same rule as Play/Resume: dimmed with a reason label, nothing sent). Menu stays ungated so there is always an exit | menus-screen-flow.md (Rule 3, AC-5), design/ux/menus-screen-flow.md |
| C4 | **Near-Miss suppresses `near_miss_detected` on a release caused by a reset or window close** (a `released_by_reset` flag), which also covers Paused to Restart or Menu | near-miss-detection.md (Rule 5, States), obstacle-system.md (Rule 5 note) |
| D1 | **`hidden` = the occupied arc lies entirely beyond `VISIBLE_ARC_HALF_WIDTH` of `THETA_REF`** (a Wall covering most of the circle is visible); still a proxy because the camera centre is not fixed | obstacle-system.md (F4, AC-34, AC-36), pattern-difficulty.md (Rule 7, AC-10), camera.md (F3 note) |
| S1 | **Run State pins one subscriber-order list.** `run_reset`: Pattern, then Tube Track adapter / Obstacle, then Ball, then Camera, then the rest. Add an AC | run-state-restart.md (new "Subscriber order"), scoring-personal-best.md (Rule 11), pattern-difficulty.md, camera.md |
| S2 | **`run_ended` order: Juice, then Scoring, then HUD**, in the same pinned list | run-state-restart.md, scoring-personal-best.md (Rule 11), juice-feedback.md (Rule 5) |
| S3 | **The loader calls Tube Track `load_map` (validates) and sends `map_ready` only on success.** Remove the adapter row "`map_ready` to `load_map`". A failed load stays in Boot; Retry makes the loader retry `load_map`; the failure screen leaves by itself when `phase` becomes Menu | run-state-restart.md (Interactions, Edge Cases, Open Question 8), tube-track.md (state table), menus-screen-flow.md (Rule 8) |
| S4 | **Environment & Theming applies `L_ball_adjusted` to the ball material; both `colorblind_safe_enabled` and `reduced_motion_enabled` (`seam_contrast_scale`) take effect immediately** (Tube Track reads `seam_contrast_scale` every frame or on `setting_changed`) | environment-theming.md (Rule 9, Open Question 4), tube-track.md (rule 9), settings-accessibility.md (Rules 6-8), ball-movement.md (no consumer row) |

Status: **applied 2026-10-01** (commits f3a184d, 755209e, cfe6f9d, 71ee608). Follow-up decisions: gated Restart reason label as one reserved 28 dp line under the P1 row; the multi-piece `hidden` rule stays per piece; Tube Track validates `readable_distance` at the v_max value (about 46.00); a gated Restart shows the gated look and no readying underline. Remaining: re-run `/review-all-gdds since-last-review` to confirm no new blockers.
