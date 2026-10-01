# Cross-GDD Re-review (since-last-review)

> **Date**: 2026-10-01
> **Scope**: the 15 GDDs changed since `gdd-cross-review-2026-10-01.md` (menus-screen-flow, tilt-input, tube-track, environment-theming, settings-accessibility, ball-movement, run-state-restart, scoring-personal-best, juice-feedback, near-miss-detection, obstacle-system, pattern-difficulty, camera, platform-services, save-persistence), `design/ux/menus-screen-flow.md`, `design/registry/entities.yaml`; `game-concept`, `hud` and `systems-index` read as context.
> **Method**: two independent read-only passes (consistency and fix verification; scenario and design regressions). Findings are as reported by those passes; line references were not all re-checked by hand.
> **Verdict: CONCERNS.** No blocking issue. Warnings should be resolved before or during architecture.

---

## The 9 blocking items of the first report: all RESOLVED

| # | Verdict | Evidence |
|---|---|---|
| C1 | RESOLVED | `tube-track.md` F3: `ceil((84 + 2.5) / 12) + 1 = 9`, N = 12; Tuning Knobs, F3 table and AC-7/11/12/13/20a/20b/21/23 consistent; `environment-theming.md` no longer says "not yet propagated" |
| C2 | RESOLVED | `menus-screen-flow.md` Rule 2 defines sensor-ready (`valid` AND `input_source == SENSOR`); AC-27; UX spec has the gate-condition row |
| C3 | RESOLVED | Paused Restart gated, Menu ungated, matching `tilt-input.md` rule 10 and `run-state-restart.md` rule 14; UX reason-label slot checked arithmetically |
| C4 | RESOLVED, with a gap (W-D) | `near-miss-detection.md` Rule 5 and AC-28 use `released_by_reset`; Obstacle uses the same name |
| D1 | RESOLVED | F4 `hidden` via `d_min`; AC-15/34/36, Pattern Rule 7/AC-10, Camera F3 agree |
| S1, S2 | RESOLVED | Run State "Subscriber order" cited consistently by Scoring Rule 11, Juice Rule 5, Pattern, Camera; AC-30 |
| S3 | RESOLVED | The loader calls `load_map` and sends `map_ready` only on success; nothing maps `map_ready` to `load_map` |
| S4 | RESOLVED | Environment applies `L_ball_adjusted` live; Settings Rules 6-8 require the getter plus `setting_changed`; Tube Track reads `seam_contrast_scale` every frame |

Independent recomputation agreed: A = 9 and N = 12 (and A = 12, N = 15 at the maximum F); `F_read(v_max)` 45.998; T_vis 1.52 s (margin 0.02 s, unchanged); `s_precision_limit` reached at 682.36 s; seam rate 2.08 Hz; D1 examples (Wall 0.4127 not hidden, (2.8, 3.4) hidden, (0.9, 1.5) not hidden, (5.8, 7.0) not hidden). One correction: the piece (1.2, 2.2) is NOT hidden at the test value PI/2 but IS hidden at the shipped 1.0472; the GDDs state that row only at PI/2, so they stay consistent. UX arithmetic at H = 640 and H = 560 checks out (pill to pill 100 dp and 80 dp).

---

## Warnings

| # | Issue | Status |
|---|---|---|
| W-A | `run-state-restart.md` UI Requirements (Ordinary Paused) left Restart out of the gating | **Fixed 2026-10-01** |
| W-B | `design/ux/hud.md` still read as if Paused Restart is ungated | **Fixed 2026-10-01** |
| W-C | `systems-index.md` still said Tilt's settle must count only while `attentive` (Platform Open Question 24 is resolved) | **Fixed 2026-10-01** |
| W-D | Obstacle has no AC for `released_by_reset` (true on `window_primed`, false on `segment_left_window`); "window close" has no defined trigger (nothing says what releases hazards on `unload_map`) | Open: decision needed (define the trigger, or drop "window close"; add the AC) |
| W-E | Obstacle's `run_reset` handler is described as "store `run_id`" in one place and "clear/reseed" in another; the pinned order puts it in rank 2 with the Tube Track adapter in either order, so a clear after `window_primed` would wipe the new window | Open: decision needed (state that it only stores `run_id`, or pin an order inside rank 2) |
| W-F | `tube-track.md` rule 9 requires `seam_contrast_scale` to be read every frame, with no AC that changes it mid-session | Open: add a [U] row |
| W1 | Juice classifies hit versus abandon by its track state; an abandon while the track is still `NearMiss` (a pause within about 80 ms of a near-miss, then an abandon with a new best) logs `JUICE_PB_CONTRACT_VIOLATION` on a legal path and plays the celebration (Juice AC-13 vs Rule 5) | Open: decision needed (treat `NearMiss` as a legal abandon state that suppresses the PB; make the near-miss presentation real time; or classify by event type) |
| W3 | A persisted `colorblind_safe_enabled = true` has no application at boot (`setting_changed` fires only on change; AC-19 tests flips only) | Open: decision needed (apply from the getter at construction or map load, with an AC; or have Settings emit `setting_changed` once per loaded value) |
| W4 | `hidden` now certifies the obstruction, not the exit: a single-gap Wall with its gap at about 66-113 degrees is legal, and a neutral player may face a 270-degree turn against the 180-degree basis of `T_DODGE_180`; the old centre test rejected it | Open: decision needed (accept and document; limit exits beyond the visible arc to PI-symmetric types such as Near-Ring; or count exit-hidden pieces against `HIDDEN_SPAN_MIN_S`) |

Warnings of the first report that were not part of the 9 decisions (stray tap after the Paused takeover, abandon-path banner, `haptics_intensity` input path, hit-stop time basis, the 682 s cap owner, the `t_reset` shares at N = 12) were checked and **none was made worse**.

## Info

- `t_reset` and draw-call budgets are flagged "to be re-verified at N = 12", not recomputed; the risk is low (`T_restart` 0.216 s against 1 s).
- Fixed 2026-10-01: Menus Rule 3 first sentence (the Paused screen also takes over for `sensor_lost` with `valid` true) and the two statements that HUD's Restart in Hit "forwards every tap unconditionally" (it forwards while `valid` is true); registry `dt_max` note (A = 9); UX Menus line 119 (Open Question 14 resolved); `camera.md` line 58 (cites "Subscriber order"); `run-state-restart.md` rule 11 and D3 (Android only `FOCUS_OUT`, no application-paused).
- Still open: the failure screen waits `MAP_LOAD_TIMEOUT` (10 s) even when `load_map` fails at once (for example the C1 case), and a Retry tapped during a slow first load could call `load_map` on an Idle Tube Track; Obstacle's table has two rows that disagree on populating at Boot or Menu (Pattern would be called unseeded); `obstacle-system.md` AC-20 still uses an N = 9 window shape (a stub fixture); `settings-accessibility.md` Rule 6 lets Platform, Tilt and Menus use the getter alone (a mid-session change then depends on when they read); `tilt-input.md` keeps a `SENSOR_SIGN` +1 example next to the expected Android value -1 (labelled, consistent); the INTRO tier fixtures keep every gap at theta 0, so a player at theta around PI sees a solid wall with the exit unseen 180 degrees away (the known neutral-hugging warning plus W4); Menus fires `UI_TAP` on a Restart or Menu tap inside the 0.3 s guard that Run State then rejects.

## Design side effects checked

- Gating Paused Restart on `valid` does not trap the player: Menu stays ungated in ordinary Paused, HUD's sensor-lost screen has its own Menu (after the 0.3 s guard), HUD has a Menu button in Hit with `valid` false and Back goes to Menu there.
- A Restart that slipped past the gate would be caught downstream (the next settling tick pauses with `sensor_lost`).
- Pillars P2 and P4 hold (text plus dimming, never colour alone; Restart and Menu at least 80 dp from Resume; no new precision). The pinned orders add no new dominant or degenerate behaviour; C4 removes the old phantom near-miss exploit.

## GDDs flagged for revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| obstacle-system.md | W-D, W-E, W4 | Consistency / Design | Warning |
| juice-feedback.md | W1 | Consistency | Warning |
| environment-theming.md | W3 | Consistency | Warning |
| tube-track.md | W-F | Test coverage | Warning |

The systems index statuses were not changed.

## Verdict: CONCERNS

Architecture can begin; resolve W-D, W-E, W1, W3 and W4 (each needs a decision) and the test additions W-D and W-F when the owning GDDs are next revised.
