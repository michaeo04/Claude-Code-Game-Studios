# HUD

> **Status**: Revised (2026-10-01, first full-mode `/design-review` NEEDS REVISION, 9 blockers resolved; lean re-review same day NEEDS REVISION (minor), 2 blockers and 5 recommended items resolved; review cap reached, ready for `/ux-design`). Review history lives in `reviews/hud-review-log.md`, not in this file.
> **Author**: user + agents
> **Last Updated**: 2026-10-01
> **Implements Pillar**: Pillar 4 (One-Thumb Simplicity) — primary, the entire reason a hands-off, one-tap HUD exists; Pillar 1 (Instant Readability) — secondary, the HUD itself must be instantly readable, not just the tube.
> **Creative Director Review (CD-GDD-ALIGN)**: Skipped — lean mode, not a PHASE-GATE.

## Overview

HUD is the always-on-screen layer that lets the player read, without looking away from the tube, the live score, the personal best, the run's phase cues (pause button, resume countdown, restart prompt) and the sensor-health cues Tilt Input requires. It sends exactly three requests to Run State (`pause_requested`, `restart_requested`, `menu_requested`) and nothing else: everything it shows is read-only reflection of another system's published state, and it decides nothing about what a score is, when a run ends, or what a personal best means. Without it, the systems it displays would have correct internal state nobody could see, and Pillar 4 (One-Thumb Simplicity) would fail: the player could not tell a paused, sensor-lost or locked-restart state from a frozen screen.

## Player Fantasy

**The fantasy.** I always know exactly where I stand, without ever having to think about it.

**What the player feels.**
- **The score climbing feels like proof I'm still going, not a chore to check.**
- **A personal best in reach makes me want to keep going, not tense up.**
- **When I die, I know instantly what happened and what to do next** — no confusion about whether I'm still playing.
- **When my sensor drops or the app pauses, the HUD tells me the truth immediately** — I never wonder if the game is broken or just frozen.
- **The pause button is right there when I need it, invisible when I don't** (hidden in Resuming, Run State & Restart's own rule).

**Feelings to avoid.** A HUD that competes with the tube for attention; a HUD that shifts shape or position distractingly; ambiguity about whether a paused/sensor-lost/locked-restart screen is real or frozen; anything that needs two hands or a precise small tap.

**Serves the pillars.** *Pillar 4, One-Thumb Simplicity* — primary; the entire reason a hands-off, one-tap HUD exists. *Pillar 1, Instant Readability* — secondary; the HUD itself must be instantly readable, not just the tube.

*(`creative-director` not consulted — lean mode; Player Fantasy is not a Section D/H high-risk section under this project's own review-mode rule. Review manually before production.)*

## Detailed Design

### Core Rules

1. **Read-only reflection, one HUD-owned display state.** HUD holds no gameplay state of its own — every value it shows is either read directly from an upstream system's published state (`current_score`, `personal_best`, `phase`, `valid`, `state`, `input_source`) or driven by an event it receives (`personal_best_updated`, `personal_best_passed`, `run_resuming`, `restart_unlocked`, `run_ended`, `run_reset`). It computes nothing beyond formatting and timing already defined elsewhere (Run State's own F5, Scoring's own F1).

2. **Score display.** Shows `current_score` (an `int`, floored upstream) every frame, exact, with no smoothing or count-up of its own (Scoring's "the number is always honest"). Digits are fixed-width (tabular) and the pill is right-anchored, so it never changes width on rollover; no unit label. `personal_best` is shown as a static `BEST` reference, pulled once at construction and updated only on `personal_best_updated`. **While the stored `personal_best` is 0 (no real best yet) the BEST pill is hidden**: a first run gets no BEST pill, and an exact tie with the best gets no cue (resolves Scoring Open Question 11). **On `personal_best_passed`** (Scoring Core Rule 12: once per run, never while the best is 0) the BEST pill enters a **persistent passed state until the run's reset**: its label changes to `NEW BEST`, its value tracks the live `current_score`, and it gains a Lagoon outline. The state is carried by label and outline, never by color alone; it is non-occluding, with no haptic, no FOV punch and no bloom. This is the live half of the personal-best moment; the end-of-run banner (Rule 3) is the full celebration.

3. **Personal-best banner.** On `personal_best_updated(final_score: int)` (Scoring, independent of Juice & Feedback) HUD shows the non-blocking banner with `final_score`, in a fixed top-centre zone, never delaying the restart prompt (Rule 6). Juice & Feedback supplies only its visual language (never gold, Lagoon/Rim White family) and separately drives its own hit-only bloom and ring sweep (its Core Rules 4-5). **The banner clears on `run_reset` or on a `phase_changed` to Menu**, because an exit to Menu emits no `run_reset` and the banner must not outlive the run onto the Menu screen. Consequence: on an abandoned run (Scoring Core Rule 5) the transition that ends the run also clears the banner, so the moment is carried by Menus & Screen Flow's BEST display, not by this banner; the banner is effectively a Hit-phase element.

4. **Pause button.** Visible only while `phase` == Running — hidden in every other phase, including Resuming (Run State's own rule: no on-screen cancel during the countdown). One tap (activated on release inside the button, Run State's rule) sends `pause_requested(button)` exactly once; HUD applies no debounce of its own beyond Run State's own `PAUSE_INPUT_GUARD`, already enforced upstream.

5. **Resume countdown.** While `phase` == Resuming, shows a ring and a digit. `remaining`, `digit` (`ceil(remaining)`) and `progress` are **pulled each tick from Run State's own F5 value** and displayed as given, never accumulated from HUD's own `dt`, so a hitch or stall cannot make the two clocks diverge. `run_resuming(duration_ms)` only starts the display. A non-integer duration makes one digit shorter than the others; HUD shows whatever F5 gives and does not special-case it.

6. **Restart prompt: cosmetic lock for timing, real gate on `valid`.** On `run_ended` the restart prompt shows a locked visual, and on `restart_unlocked` an unlocked one. The lock is cosmetic: while `valid` is true HUD forwards **any** tap that lands during Hit, before or after the visual unlock, as `restart_requested(press_us)`, exactly once per tap, with no HUD debounce or buffering; Run State's F4 timestamp math is the timing gate and rejects an early press. **While `valid` is false HUD swallows the tap** (forwards nothing) and shows the text cue `Sensor not ready`, so a dead sensor never burns a run (Tilt Input Rule 10, a user decision; Run State Core Rule 14). The cue has no timer: it appears on the first swallowed tap and stays until `valid` returns, `run_reset` or a phase change out of Hit. `valid` is read from the pull seam at the moment `on_tap` is handled, not at `press_us`, so a flip between press-down and handling follows the handling tick's value. `press_us` is stamped by the view on press-down (Rule 14); `HudCore` never reads a clock.

7. **Sensor cues, HUD's own share.** While `valid` is false in Hit, the restart prompt is sensor-dimmed on top of its locked/unlocked visual (shown, never hidden) and swallows taps (Rule 6), and a small round **Menu button** is shown that sends `menu_requested(press_us)`, so a dead-sensor Hit is never a dead end on a platform with no Back key (user decision; Run State accepts `menu_requested` in Hit after the lock and rejects an earlier press). Every sensor cue carries a **text label**, never opacity or motion alone: `Reconnecting…` while `state` == Acquiring, `No motion sensor` while `state` == Unavailable after a live reading. HUD keeps its own latch for "was Live this session" (Tilt Input's `sensor_ever_live` is internal to it), never cleared within a session. A run can only begin on a live sensor (Menus gates Play on `valid`), so in Hit and in the sensor-lost pause the latch is normally set; defensively, if `valid` is false there with the latch unset, HUD shows `No motion sensor` (a dimmed prompt is never left without a label). HUD does not read `input_source`. Play and Resume are not HUD elements: Menus & Screen Flow gates them on `valid` (its Core Rules 2-3).

8. **Sensor-lost pause screen.** On `run_paused(sensor_lost)` HUD shows a dedicated pause screen with the sensor label (Rule 7) and a Menu affordance that sends `menu_requested(press_us)`; it does not decide what that does, and asks no confirmation (a pause destroys nothing: Scoring finalizes the run either way). HUD latches the pause source for the whole Paused phase; a later `run_paused` does not change it until the phase leaves Paused. When the sensor recovers (`valid` becomes true while still Paused with source `sensor_lost`), HUD hides its sensor-lost screen in that same tick and the player continues from Menus & Screen Flow's ordinary Paused screen, where Resume is gated on `valid` (its Core Rules 1 and 3; revised 2026-10-01, `/ux-review` of `design/ux/hud.md`). The source latch stays until Paused is left. Run State emits `run_paused(source)` first and `phase_changed` last.

9. **No pre-run sensor cue.** The "device not supported" notice and any other Boot/Menu sensor cue belong to Menus & Screen Flow (its Core Rule 2); HUD renders nothing in Boot or Menu.

10. **No near-miss counter and no milestone beat in the MVP.** Near-Miss Detection is a soft, optional dependency and HUD adds no counter, keeping the element count minimal per Pillars 1 and 4 (post-MVP, Open Question 1). HUD **declines** Scoring's `milestone_crossed(threshold)` (Scoring Core Rule 13): the score pill already shows distance and a HUD-side beat would compete with Pillar 1; whether Juice & Feedback uses it is its own decision (Open Question 11).

11. **Exactly three outbound requests, all to Run State.** `pause_requested(button)` (Rule 4), `restart_requested(press_us)` (Rule 6), `menu_requested(press_us)` (Rules 7-8). HUD sends no requests to Scoring & Personal Best, Near-Miss Detection, Tilt Input, Juice & Feedback, Platform Services, or Menus & Screen Flow — it only reads their published state and events (or, for Menus & Screen Flow, nothing at all — that system is not a dependency of HUD's own, only the reverse, per Rule 7).

12. **Reset budget.** On `run_reset`, HUD's own display state (score mirror back to `score(0)`, PB banner cleared, restart prompt re-locked) completes inside its own 2 ms share of Run State's own `t_reset` sum (F2) — no async work, no tween that outlives the reset tick (`HudCore` creates none; the view kills any banner tween on `run_reset`).

13. **No side effects beyond Rule 11's three calls; deterministic.** No randomness anywhere. Given the same sequence of upstream events and state, HUD always produces the same displayed values and the same outbound calls.

14. **Structure and view contract.** `HudCore` is a `RefCounted` with no engine calls, mirroring `CameraCore` and `SettingsCore`. **Pull seams, read every `tick(dt)`:** `get_current_score() -> int`, `get_resume_countdown()` (Run State's F5 `{remaining, digit, progress}`), `get_valid() -> bool`, `get_state()`. **One-time pull at construction** (`HudCore` is built after `ScoreCore`): `get_personal_best() -> int`. The driver calls `tick(dt)` after `ScoreService.step()`, so the displayed score is never a frame stale. **Push handlers, with upstream payloads:** `on_phase_changed(new, old)`, `on_run_paused(source)`, `on_run_ended(run_id, hazard_id, run_time_ms)` (HUD freezes the last pulled score and ignores the payload), `on_run_resuming(duration_ms)`, `on_restart_unlocked(run_id)`, `on_run_reset(run_id)`, `on_personal_best_updated(final_score: int)`, `on_personal_best_passed(personal_best: int)`, `on_tap(press_us: int)`, `on_pause_tapped()`, `on_menu_tapped(press_us: int)`. **Injected sinks** for the three outbound requests (`pause_sink`, `restart_sink`, `menu_sink`) plus a `log_sink`. `HudCore` exposes `snapshot() -> Dictionary` of display state and emits `banner_shown`/`banner_cleared` so the view never polls a transient. No handler exists for `milestone_crossed` (Rule 10). **The view** (Control layer, `/ux-design` scope) owns the full-screen tap catcher, enabled only in Hit, and the pause and Menu buttons (release-inside activation, `mouse_filter` set so the buttons win over the catcher); it stamps `press_us` from `InputEventScreenTouch` press only (Run State Rule 8). Method names are illustrative; the contract is what is pulled, pushed, how often, and with which payload. Juice & Feedback and Platform Services carry no seam. No `HudMath`: HUD computes no formula of its own.

### States and Transitions

HUD has no phase of its own — every element's visibility and content is a function of Run State's own `phase` (plus Tilt Input's `valid`/`state` for the sensor cues layered on top).

| Run State `phase` | Pause button | Score / PB | Restart prompt | Resume countdown | Sensor cues (HUD's own share) |
|---|---|---|---|---|---|
| Boot / Menu | Hidden | Hidden | Hidden | Hidden | None: Menus & Screen Flow owns the pre-run sensor cue (Rule 9) |
| Running | Visible, active | Live (`current_score`) | Hidden | Hidden | — (HUD owns no Running-phase sensor cue of its own; Play/Resume gating on `valid` is Menus & Screen Flow's, Rule 7) |
| Paused (`button` / `back` / `app_interrupted`) | Hidden | Frozen at last value | Hidden | Hidden | — |
| Paused (`sensor_lost`) | Hidden | Frozen at last value | Hidden | Hidden | While `valid` is false: sensor-lost pause screen with label and Menu affordance (Rule 8). Once `valid` is true: hidden, Menus & Screen Flow's Paused screen takes over |
| Hit | Hidden | Frozen at `final_score`; BEST pill per Rule 2 | Locked, then unlocked on `restart_unlocked` (Rule 6); taps forwarded while `valid`, swallowed with a cue while not | Hidden | While `valid` is false: dimmed prompt, text label and Menu button (Rule 7) |
| Resuming | Hidden | Frozen | Hidden | Visible (Rule 5) | — |

Personal-best banner (Rule 3) layers on top of this table independent of `phase`: it appears on `personal_best_updated` and clears on `run_reset` or a `phase_changed` to Menu. HUD's banner does not gate on which ending occurred, but an exit to Menu clears it (Rule 3).

### Interactions with Other Systems

| System | Direction | Data / events | Note |
|--------|-----------|----------------|------|
| Scoring & Personal Best (Designed) | in | `current_score`, `personal_best`, `personal_best_updated(final_score)`, `personal_best_passed(personal_best)`; `milestone_crossed` declined (Rule 10) | Read-only; Rule 2 |
| Run State & Restart (Approved) | in / out | in: `phase_changed(new, old)`, `run_paused(source)`, `run_ended(run_id, hazard_id, run_time_ms)`, `run_resuming(duration_ms)`, `restart_unlocked(run_id)`, `run_reset(run_id)`, F5 countdown values; out: `pause_requested(button)`, `restart_requested(press_us)`, `menu_requested(press_us)` | The only system HUD ever sends requests to (Rule 11) |
| Tilt Input (In Review) | in | `valid`, `state` | Read-only; Rules 6-8 |
| Menus & Screen Flow (Designed) | none | — | Reverse-only (`menus-screen-flow.md` Core Rules 2-3): Menus gates Play/Resume on `valid` and owns the pre-run sensor cue; HUD owns the Hit-phase Menu button (Rule 7). HUD sends and receives nothing to/from it |
| Juice & Feedback (Designed) | in (reference only) | the banner's own visual-language rules (never gold, Lagoon/Rim White family) | HUD renders and triggers the banner itself directly off Scoring's own `personal_best_updated` (Rule 3, revised 2026-09-30) — Juice & Feedback no longer signals the moment, only supplies the visual language, and separately drives its own hit-only bloom/sweep celebration |
| Platform Services (Approved) | in | safe area, screen size, viewport size | Layout only, no gating |

## Formulas

HUD introduces no new formulas of its own. It reuses two already-Approved/Designed formulas verbatim, read-only:

- **Resume countdown** — Run State & Restart's own F5 (`progress_for(duration, elapsed)` → `remaining`, `digit`, `progress`), driving the countdown ring and digit (Core Rule 5). HUD never recomputes this; it only displays the values Run State's own core already produces.
- **Score display** — Scoring & Personal Best's own F1 (`current_score = floor(s)`), already computed upstream (Core Rule 2). `personal_best` is a stored value with no formula of its own.

The current_score/personal_best display deliberately stays two raw numbers, not a derived comparison (a progress-to-beat percentage or delta was considered and rejected, user decision) — matching Scoring & Personal Best's own "the number is always honest" principle rather than adding an interpretive value HUD would have to own the meaning of.

No specialist consultation was needed for this section — like Platform Services' F1/F2, Save & Persistence's F1/F2, and Settings & Accessibility's F1/F2, this is boolean/comparison/reference-only, not new continuous math.

## Edge Cases

- **A tap lands during Hit before the visual unlock**: forwarded anyway as `restart_requested`, stamped with its own `press_us` (Rule 6) — Run State's own F4 timestamp math is the real gate, not HUD's own visual lock state.
- **Multiple impatient taps arrive during Hit before any restart succeeds**: every one is forwarded as a separate `restart_requested`, with no HUD-side debouncing or buffering — Run State's own "no buffering" rule (a press held across the unlock does not convert) decides which, if any, actually restarts.
- **The app backgrounds while the personal-best banner is showing** (Platform Services `app_interrupted`, Run State pauses): the banner holds at its current state — it is not cleared or restarted on `app_returned`. Only `run_reset` or a phase change to Menu clears it (Rule 3).
- **`valid` drops to false while `phase` == Running** (the sensor is lost mid-run): Run State's own adapter converts this to a pause the same tick; HUD switches to the Paused/`sensor_lost` display (States and Transitions) the moment `phase` changes, not before — the swallowing in Rules 6-7 applies only in Hit.
- **`state` changes while `phase` is Boot or Menu**: HUD shows no sensor cue (Menus & Screen Flow owns it, Rule 9).
- **`personal_best_updated` fires in the same tick as `run_ended`** (the normal case, per Scoring's own Core Rule 6): the score display's frozen `final_score` and the personal-best banner both update together in that tick — there is no partial-frame state where one has updated and the other hasn't, since both are driven by the same tick's events.
- **`valid` is false while `phase` == Hit**: the restart prompt is sensor-dimmed, a tap is swallowed with the "sensor not ready" cue (Rule 6) and nothing reaches `restart_requested`; the Menu button is shown (Rule 7). When `valid` returns, taps forward again.

## Dependencies

**Upstream (HUD needs these)**

| System | Type | What it needs | Note |
|--------|------|----------------|------|
| Scoring & Personal Best (Designed) | Hard | `current_score`, `personal_best`, `personal_best_updated(final_score)`, `personal_best_passed(personal_best)` | Read-only (Core Rule 2) |
| Run State & Restart (Approved) | Hard | `phase_changed`, `run_paused(source)`, `run_ended`, `run_resuming`, `restart_unlocked`, `run_reset`, F5 countdown values (Open Question 7); sends `pause_requested(button)`, `restart_requested(press_us)`, `menu_requested(press_us)` | The only system HUD ever sends requests to (Core Rule 11) |
| Tilt Input (In Review) | Hard | `valid`, `state` | Read-only (Core Rules 6-8) |
| Juice & Feedback (Designed) | Soft | The banner's visual-language rules only (content/style, never gold, Lagoon/Rim White family) | HUD renders and triggers the banner itself directly off Scoring's `personal_best_updated` (Core Rule 3, revised 2026-09-30) — no longer a moment-signal dependency |
| Platform Services (Approved) | Soft | Safe area, screen size, viewport size | Layout only |

**Downstream (these need HUD)**

None currently — no other GDD lists HUD as a dependency, and HUD sends no events of its own for another system to consume (its 3 outbound calls all go to Run State, which is upstream of it, not downstream). Menus & Screen Flow (Designed) is a **reverse-only** relationship, not a real dependency edge: it reads Tilt Input's `valid`/`state`/`input_source` independently for its own genuinely-gated Play/Resume (Core Rule 7, a qa-lead-found gap — Play and Resume are not HUD-owned elements; resolved 2026-09-29, `menus-screen-flow.md` Core Rules 2-3), but HUD sends it nothing and needs nothing from it.

**Bidirectional consistency (checked against the existing GDDs)**
- **Scoring & Personal Best:** already lists HUD as a dependent; the "provisional, not yet authored" wording and Open Question 5's own HUD half are both resolved and applied (Interactions/Dependents rows, Open Question 5).
- **Run State & Restart:** already lists HUD as a Hard dependent for `phase_changed`/`run_ended`/`run_resuming`/`restart_unlocked` — consistent. Its own "tap anywhere in Hit: owner is an open question" row and Open Question 2 are both resolved to HUD and applied; its consolidated Requests-in row for `restart_requested`/`menu_requested` is amended to note HUD as an additional source alongside Menus & Screen Flow.
- **Tilt Input:** already lists "Menus & Screen Flow / HUD" as a combined soft dependent for `valid`/`state`/`input_source`/the Menu path — resolved to note HUD's own half is now designed, applied to the Interactions row and Open Question 1.
- **Juice & Feedback:** does not list HUD as a dependent at all — still correct, but for a different reason as of 2026-09-30: Juice & Feedback no longer signals the PB banner moment at all (`juice-feedback.md` Core Rule 4, revised this session) — HUD now triggers its own banner directly off Scoring & Personal Best's `personal_best_updated` instead. Juice & Feedback's own Interactions table lists HUD only as a provisional, queried (not pushed) relationship for animation-overlap timing. No edit needed here beyond this note.
- **Platform Services:** already lists HUD (paired with Camera) as reading the safe area — consistent, no edit needed.
- **Systems index:** row 13 updated this session to add Tilt Input as a 4th dependency (was missing); design-order line 110 updated to match.

**Provisional assumptions**: the exact touch-half-screen-hold fallback forwarding Tilt Input's own rule 11/13 describes ("HUD forwards the touch hold only while Running and only for a touch that began after `run_started`") is explicitly **not implemented** here — `fallback_source` is a built-but-unwired `TiltCore` capability with no MVP driver (Tilt Input's own Open Question 10 resolution, mirrors Ball Movement's own FALLBACK-out-of-MVP-scope decision), so there is no live control scheme for HUD to forward touch into during the MVP. Flagged in Open Questions rather than silently dropped. Menus & Screen Flow's own eventual UI (explicit restart/menu buttons, if any, beyond HUD's tap-anywhere and sensor-lost paths) is still undesigned.

## Tuning Knobs

**No designer tuning knobs today.** The only numbers HUD owns are presentation constants that live in Visual/Audio Requirements (pill opacity 85%, banner entrance ~200-250 ms); neither affects gameplay, so neither is a knob. HUD's own values are almost entirely non-numeric — which system owns which display, when an element shows or hides (Core Rules, States and Transitions) — rather than designer-adjustable numbers. The personal-best banner's own display duration was considered as a knob and rejected: it clears unconditionally on `run_reset` (Core Rule 3), with no separate auto-dismiss timer, keeping a single source of truth for when it disappears rather than two rules that could disagree.

**Sources of truth elsewhere:** everything HUD displays is a value or event owned by another system (Scoring & Personal Best, Run State & Restart, Tilt Input, Juice & Feedback) — see Dependencies. Layout, sizing, and visual-style values (button placement, text size, safe-area margins) belong to the eventual `/ux-design` spec, not this GDD (UI Requirements' own UX Flag).

## Visual/Audio Requirements

This section specs the visual presentation of HUD's own six owned elements — the score/personal-best display, the personal-best banner's render, the pause button, the resume countdown ring/digit, the restart prompt's locked/unlocked states, and the sensor-state cues — using the art bible's UI palette (§4: Ink `#1E2433`, pill Rim White `#F4F8FF` at 85% opacity, accent Lagoon `#0E6A82`) and UI shape grammar (§3e: round family only, neutral/cool-white, never a triangle or wedge, never covers the isolated killer hazard on death). It says nothing about Mood States 1-3's environment baseline or Juice & Feedback's own near-miss/hit/personal-best world presentation (Mood States 4-6) — those are Environment & Theming's and Juice & Feedback's own Visual/Audio Requirements sections. HUD renders and triggers the personal-best banner itself, off Scoring & Personal Best's own `personal_best_updated` (Core Rule 3, revised 2026-09-30), using visual language Juice & Feedback still supplies — this section, not that one, is the banner widget's own visual spec.

**House rule used throughout this section:** every HUD-owned element sits on its own opaque(-ish) Rim White pill rather than floating bare over the tube/sky. This is not decorative — the UI palette is deliberately fixed and "ignores fog, speed desaturation and grey-out" (art bible §4) precisely so HUD's contrast promises hold regardless of world state; a bare Ink glyph directly over a variable backdrop could not make that same guarantee. It also means HUD's own elements never face the "white juice vanishing into tube/sky glare" problem the art bible's "Juice contrast" note (§4) fixes with a Lagoon-tinted outer edge on Juice & Feedback's own world-space rings — that fix is Juice & Feedback's, scoped to shapes rendered directly against the tube/sky, and is not re-applied to HUD's own pill-backed widgets below.

### Score and personal-best display

| Element | Typography | Color | Placement | Motion |
|---|---|---|---|---|
| `current_score` | Largest / boldest weight in the HUD — the primary live figure | Ink text on a Rim White pill (≈14.5:1, clears the 7:1 floor with margin) | Off the approach zone (§3e) — a screen corner, safe-area-respecting (Platform Services' safe area), fixed position across every map and mood state | None of its own — see below |
| `personal_best` | Smaller / lighter weight than `current_score` (~60-70% of its point size), with a short text label ("BEST" or "PB") distinguishing it as reference rather than live — no icon (a trophy/medal glyph is a plausible future iconography-pass addition, out of this GDD's own scope) | Ink text, same pill or an adjacent smaller pill, same palette | Adjacent to `current_score`, subordinate in the same corner group | Hidden while the stored best is 0; updates on `personal_best_updated`; on `personal_best_passed` it enters the persistent `NEW BEST` state (label change, value tracks the live score, Lagoon outline, no motion; Core Rule 2). The banner (below) marks the end-of-run moment |

Pill-backed, not bare text (user decision) — guarantees the contrast floor the UI palette exists to promise, and stays visually consistent with the pause button and PB banner's own treatment.

**The score display gets zero motion, zero color shift, and zero scale pulse of its own** on near-miss or hit (only the BEST pill changes state, and only on `personal_best_passed`, Rule 2) — it never smooths, counts up, or reacts visually to those moments. Three reasons, not just Core Rule 2: (1) Core Rule 2 already forbids smoothing/count-up; a reactive pulse would contradict its spirit even without breaking its letter; (2) the Mood States table (art bible §2) names the ball, tube, camera, and (state 6) "a non-blocking banner" as the carriers for states 4-6 — it never names the score digits; (3) gestalt economy of attention — only one element should carry a given moment's "this matters" motion cue, and Juice & Feedback's ring/rim/banner already carry it.

### Personal-best banner

| Property | Spec |
|---|---|
| Shape | Pill / rounded rectangle (§3e round family) |
| Background | Rim White `#F4F8FF` at 85% opacity |
| Text/icon | Ink `#1E2433`; accent stroke or underline in Lagoon `#0E6A82` |
| Prohibited | Gold, any warm hue, triangular or wedge framing — consistent with `juice-feedback.md`'s own already-committed banner row |
| Position | A fixed top-centre zone, distinct from the score/PB corner and the restart prompt. HUD has no hazard screen coordinates, so a fixed zone replaces a "never over the killer hazard" rule; the art bible's isolated-killer rule (§3e) is checked in `/ux-design` |
| Entrance | Brief settle-in only — a ~200-250ms ease-out slide/fade, no bounce or scale-pop (Mood State 5's own "abrupt, exact, clean" character argues against a showy entrance) |
| Hold | Static once settled — no idle animation, no auto-dismiss timer (Tuning Knobs: none exists; clears only per Core Rule 3) |
| Exit | Clears on `run_reset` or a phase change to Menu (Core Rule 3); no exit animation, and the view kills any running entrance tween |
| Backgrounding | Holds its settled state through an `app_interrupted`/`app_returned` cycle (Edge Cases) — no replay, no reset on return |

The banner does **not** use the Lagoon-tinted-outer-edge treatment Juice & Feedback applies to its own PB ring sweep — that fix exists because a white shape floats directly over the variable tube/sky; the banner is an opaque UI pill and never faces that failure mode. The concurrent ring sweep is Juice & Feedback's own effect, already specified there.

### Pause button

Round family (§3e): a circular button, Ink icon (pause bars) on a Rim White pill at 85% opacity — the same opaque-pill treatment as the score display, since it also renders directly over live gameplay and needs the same guaranteed contrast.

Touch target: sized for Pillar 4's one-thumb requirement. This GDD does not lock an exact size (layout/sizing defers to `/ux-design`), but recommends the standard mobile floor (44pt iOS / 48dp Android) as the reference minimum for whoever authors that spec.

Placement: reuses Run State & Restart's own already-committed wording verbatim — "in a reachable zone but away from the resting grip, activated on release inside the button, sized to prevent accidental taps." Visible only while `phase` == Running (Core Rule 4).

### Resume countdown ring/digit

Pure UI palette (user decision) — Ink digit, Lagoon progress-ring stroke, Rim White pill backing, not the Lagoon-tinted-white-core treatment Juice & Feedback's own world-space rings use. The countdown ring sits on its own opaque pill (house rule above), so it never faces the "white ring vanishing into glare" problem that treatment fixes, and keeping it in pure Ink/Rim-White/Lagoon preserves a learnable distinction: cool-white-on-the-tube always means Juice & Feedback's world reaction; Ink/Rim-White/Lagoon always means the system is telling you something.

Mechanics: the ring's progress arc sweeps per Run State's own F5 `progress` value (0→1), read-only (Core Rule 5) — Lagoon stroke, filling clockwise; the digit is centered in Ink, updating on each whole-second tick. The final partial digit (Run State's own note on a non-integer countdown) shows the ring alone with no broken/partial digit rendered (Core Rule 5).

### Restart prompt: locked vs. unlocked

The lock is cosmetic for timing (Core Rule 6: while `valid`, HUD forwards every tap and Run State's F4 is the timing gate), so the visual must neither invite nor discourage a tap:

- **Inviting** a tap during lock (a pulsing "tap now" affordance) would create false urgency and encourage frame-perfect mashing, cutting against Mood State 5's own calm, always-available character.
- **Discouraging** a tap (a fully greyed-out, dead-looking icon) is misleading, since an early tap is still forwarded and can still land depending on exactly where Run State's own F4 timestamp math falls.

Treatment: a calm, continuous "readying" visual — a fill/charge on the restart icon (visually similar to the countdown ring: a Lagoon ring or wedge filling from empty to full, Ink icon rising from ~50% to 100% opacity), communicating "getting ready," not "broken" and not "urgent." The unlocked state completes the fill and settles at full Ink opacity, with an optional brief, non-jarring brightness settle marking the transition — never a hard pop or color change.

**Does not reuse the sensor-gated "disabled" visual (below) for the locked restart state.** They mean different things: sensor gating means the element genuinely cannot do anything right now; the restart lock is a cosmetic status readout on an element that already works.

### Sensor-state cues

All treatments stay entirely within Ink / Rim White / Lagoon — never Signal Red, Ember, or any warm hue, despite these being functionally error-adjacent states (art bible §4's "no warm hue" rule). "Temporarily can't," never "broken," is carried by opacity and motion, not color-coding:

| State | `state` value | Visual treatment |
|---|---|---|
| Reconnecting | Acquiring | Restart shown, Ink icon dimmed to ~40-50% opacity on its usual Rim White pill, text label `Reconnecting…`, plus a small Lagoon pulse/spinner for in-progress recovery |
| No motion sensor (mid-run) | Unavailable, after a working session | Same dimmed treatment, text label `No motion sensor`, **no** pulse (not in progress); paired with the sensor-lost pause screen and Menu affordance (Core Rule 8) and, in Hit, the Menu button (Core Rule 7); round buttons only |

Dimmed opacity on the Rim White pill is the shared "disabled" signal; the text label, never the pulse, tells the two states apart (the pulse is decoration, not a discriminator). The pre-run "device not supported" notice is Menus & Screen Flow's (Core Rule 9).

### Audio

HUD owns no audio of its own — the same "none, deferred" precedent Tilt Input and Save & Persistence already established. A tap sound for the pause/restart button, a countdown tick, or a PB-banner appearance sound all belong to Juice & Feedback (and Platform Services for haptics), not HUD. Core Rule 11 caps HUD's outbound calls at exactly three (`pause_requested`, `restart_requested`, `menu_requested`), all to Run State — HUD has no interface to request an audio cue from Juice & Feedback even in the future; any such cue would have to be triggered by Run State's own reaction to those events, or by Juice & Feedback independently observing `phase_changed`.

### Accessibility cross-check

- **7:1 score contrast**: achievable and exceeded. Ink (`#1E2433`, relative luminance ≈0.0178) against opaque Rim White (`#F4F8FF`, relative luminance ≈0.936) computes to ≈14.5:1. The 85%-opacity pill blended against a live tube/sky backdrop is not yet verified on a real device — recommend a HUD-specific device check alongside Juice & Feedback's own outstanding JUI-2 real-device pass, rather than assuming the idealized opaque-pair number holds once the pill's own opacity is in play. The worst-case blended ratio is arithmetic, computable now from the art bible's darkest and lightest backdrops; AC-22 is the on-device measurement.
- **`reduced_motion_enabled`**: not consumed by HUD, and this stays that way. HUD's only motion — the banner's ~200-250ms entrance settle and the countdown ring's data-driven progress sweep — sits well under the photosensitivity ceiling on its own, and the sweep displays Run State's own real remaining time (suppressing or altering it would misrepresent that time, breaking Core Rule 5's own read-never-recompute honesty). A real-device pass may surface a need here later; if so, that becomes a new Open Question, not a silent scope change.
- **`colorblind_safe_enabled`**: not consumed by HUD, and no HUD element needs it — every HUD signal in this section separates by shape, position, opacity, and text label, never by hue alone (the sensor-cue table is the clearest example: reconnecting vs. unavailable is told apart by pulse presence, not color), mirroring the "shape before color" principle already governing obstacles (art bible §1).

## UI Requirements

HUD owns six on-screen elements, all specified above (Detailed Design for behavior, Visual/Audio Requirements for treatment):

1. Score display (`current_score`, live)
2. Personal-best reference display (`personal_best`, static until updated) + its celebration banner
3. Pause button
4. Resume countdown ring/digit
5. Restart prompt (locked/unlocked visual states)
6. Sensor-state cues (reconnecting / no motion sensor / sensor not ready; "device not supported" is Menus', Core Rule 9), the sensor-lost pause screen's Menu affordance, and the Hit-phase Menu button (shown only while `valid` is false)

No requests to other systems beyond what Dependencies already states — Scoring & Personal Best, Run State & Restart, and Tilt Input already publish everything HUD reads, and Run State already accepts the three requests HUD sends.

**📌 UX Flag — HUD**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the full HUD layout (exact positions, sizes, touch targets, safe-area handling, and the transition animations between the States and Transitions table's own rows) **before** writing epics. This GDD deliberately stops at behavior and visual treatment, not pixel layout — stories that reference HUD's own UI should cite `design/ux/hud.md`, not this GDD directly.

## Acceptance Criteria

**Targets:** **[C]** `HudCore`, a `RefCounted` with no engine calls (Core Rule 14), tested through injected pull seams and outbound sinks with spies. **[L]** one advisory lint (AC-18). **[I]** integration (AC-19 to AC-21) and one on-device measurement (AC-22). No `[M]` (HUD has no formula of its own) and no `[K]` (no `*Config` and no default of its own). Method names in Core Rule 14 are illustrative; what is tested is the contract: what is pulled, pushed, how often, with which payload. Tests live in `tests/unit/hud/` and `tests/integration/hud/`, named `hud_[feature]_test.gd`. Exact `==` for scores (ints), booleans, enums, label text and call counts; 1e-6 only for the countdown floats. A fresh core per case.

**Fixture** (`make_hud_fixture()`, no `.tres`): phase, pause-source and Tilt `state` enums are reused from their owners, never redefined. `SCORE_STREAM_TEST = [0, 12, 1575, 1576]` (ints; the 12 to 1575 jump catches smoothing). `PERSONAL_BEST_STORED_TEST = 500`, `PERSONAL_BEST_UPDATED_TEST = 750`. `RESUME_ROWS_TEST`: scripted `{remaining, digit, progress}` rows for a 1700 ms countdown from an independent hand calculation (`1.7/2/0`, `1.0/1/0.4118`, `0.7/1/0.5882`), never from the code under test. `TAP_STAMPS_TEST = [1000, 2000, 3000, 4000, 5000]` (`press_us`). `EXPECTED_VISIBILITY`: a named table constant giving each element's visibility per phase and `valid` (the States table written once, as data). `SENSOR_CUE` enum: `NONE, RECONNECTING, NO_SENSOR`. `make_pull_stub(sequence_or_value)` returns a `Callable` with a call-count spy (state held in a container, since GDScript closures capture primitives by value); `make_sink_spy()` records outbound calls with payloads and can read `HudCore` state inside the callback; `make_hud_core(...)` takes the pull seams, the three sinks and `log_sink`.

**States and banner**
- **AC-1 [C]** Drive `HudCore` through `{Boot, Menu, Running, Paused+button, Paused+back, Paused+app_interrupted, Paused+sensor_lost, Hit-locked, Hit-unlocked, Resuming}`, each with `valid` true and false where it applies, including the Resuming to Running edge. Assert every element's visibility against `EXPECTED_VISIBILITY`; `Paused+back` and `Paused+app_interrupted` snapshots equal the `Paused+button` snapshot; Boot and Menu show no HUD element and no sensor cue for any `state`.
- **AC-2a [C]** `on_personal_best_updated(750)` in Hit shows the banner with `final_score == 750`. It stays through an `app_interrupted`/`app_returned` cycle and is cleared only by `on_run_reset` or by `on_phase_changed(MENU, ...)`.
- **AC-2b [C]** Abandon path: `on_personal_best_updated(750)` then `on_phase_changed(MENU, PAUSED)` in one step leaves no banner visible after the step and no banner state in Menu (Core Rule 3).

**Score and personal best (Core Rule 2)**
- **AC-3 [C]** `on_personal_best_passed(500)` with a stored best of 500: the BEST pill enters the passed state exactly once (label `NEW BEST`, value equals the live `current_score` on each tick, outline flag set), the banner is not shown, and no sink is called. A second `on_personal_best_passed` in the same run changes nothing; `on_run_reset` clears the state.
- **AC-4 [C]** Stored best 0: the BEST pill is hidden before and during the run; `on_personal_best_updated(750)` shows it with 750. A run ending with `final_score` equal to a nonzero stored best changes no display state (a tie gets no cue).
- **AC-5 [C]** `get_current_score` fed `SCORE_STREAM_TEST` over 4 ticks: the displayed value is `==` the seam value after every tick (no intermediate value on the 12 to 1575 jump) and an `int`. `get_personal_best` is called exactly once across 10+ ticks even if its return changes; only `on_personal_best_updated(750)` changes the stored value.

**Restart and sensor gating (Core Rules 6-7)**
- **AC-6 [C]** `valid` true: `on_run_ended(...)` then a tap at `TAP_STAMPS_TEST[0]` before unlock calls `restart_sink` once with that stamp, and a spy reading the lock flag inside the callback sees "locked"; after `on_restart_unlocked`, a later tap is forwarded once. A mutation that gates forwarding on the lock flag fails the pre-unlock row.
- **AC-7 [C]** `TAP_STAMPS_TEST`, 2 taps before unlock and 3 after, `valid` true: 5 `restart_sink` calls, in order, with the 5 stamps; no coalescing, no cap.
- **AC-8 [C]** A tap in any phase other than Hit produces zero `restart_sink` calls, and so does a tap handled after `on_phase_changed(RUNNING, HIT)` or `on_phase_changed(MENU, HIT)` has already been processed in the same step (Run State's only Hit exits; Hit never leads to Resuming). The tap that itself caused the restart is forwarded once and never twice.
- **AC-9 [C]** `valid` false in Hit: a tap produces zero `restart_sink` calls and sets the `Sensor not ready` cue, which persists across later ticks and clears when `valid` returns; a tap whose handling tick sees `valid` true forwards even if `valid` was false at press-down; the prompt stays visible and sensor-dimmed; the Menu button is visible and `on_menu_tapped(T)` calls `menu_sink` once with `T`. With `valid` true again a tap forwards and the Menu button is hidden. A mutation that forwards while `valid` is false, or hides the prompt, fails.
- **AC-10 [C]** Sensor cue: `ACQUIRING` gives `RECONNECTING` with label text `Reconnecting…`; `UNAVAILABLE` after a prior `LIVE` gives `NO_SENSOR` with label `No motion sensor` and no pulse; `UNAVAILABLE` with no prior `LIVE` gives `NONE` in Boot and Menu, but `NO_SENSOR` with label `No motion sensor` in Hit or the sensor-lost pause (Core Rule 7 fallback). A `LIVE`, `UNAVAILABLE`, `ACQUIRING`, `LIVE` sequence re-derives each tick, and HUD's own "was Live" latch never clears within the session.

**Pause, Menu, countdown, ordering**
- **AC-11 [C]** Pause: a tap in Running calls `pause_sink` once with the button source; taps in any other phase call it zero times; two quick taps call it twice (no HUD debounce).
- **AC-12 [C]** `menu_sink` is called only from the sensor-lost pause screen or from Hit with `valid` false; in Paused+button, Paused+back and Paused+app_interrupted no Menu control exists and zero calls are possible.
- **AC-13 [C]** `on_run_resuming(1700)`; `get_resume_countdown` scripted from `RESUME_ROWS_TEST` while `tick(0.5)` is fed a hitch `dt` that matches no row: the displayed remaining, digit and progress equal the seam's rows exactly on every tick, so no HUD arithmetic and no `dt` accumulation. A mutation that accumulates its own `dt` fails.
- **AC-14 [C]** Run State's real order, `on_run_paused(SENSOR_LOST)` then `on_phase_changed(PAUSED, RUNNING)`: the sensor-lost view is shown after the step, never a button-pause view. A second `on_run_paused(BUTTON)` while Paused leaves the source unchanged; leaving Paused clears the latch.

**Reset, determinism, outbound cap**
- **AC-15 [C]** `on_run_reset(7)` from an arbitrary state (mid-run score, banner shown, passed state, prompt unlocked and dimmed, cue set) returns synchronously with score mirror 0, banner cleared, passed state cleared, prompt re-locked and cue cleared, all visible in one `snapshot()`.
- **AC-16 [C]** Two independently constructed `HudCore` instances fed the same scripted sequence (pulls, ticks, pushes, taps, a reset) produce equal `snapshot()` dictionaries and equal sink-call sequences after every step.
- **AC-17 [C]** Behavioral spy over a full scripted session: the sinks record only `pause_requested(button)`, `restart_requested(press_us)` and `menu_requested(press_us)`, each as Core Rules 4, 6-8 require, and nothing else. `HudCore`'s constructor accepts exactly the named seams and sinks (an extra parameter fails), and no `milestone_crossed` handler exists (Core Rule 10).
- **AC-18 [L], ADVISORY** CI lint over `HudCore`'s source, word-boundary token match: no `Time.`, `Engine.`, `OS.`, `DisplayServer.`, `get_tree`, `randi`, `randf`, `randomize`, `ConfigFile`, `FileAccess`. Advisory because a text scan cannot resolve types; AC-17 is the blocking enforcement.

**Integration [I], BLOCKING at the first-playable gate, owner: user** (`coding-standards.md` grants Integration no "deferred" tier)
- **AC-19 [I]** Real Scoring wiring: a live `ScoreCore` feeding `current_score`, `personal_best` and both personal-best events into a real `HudCore`.
- **AC-20 [I]** Real Run State wiring: live events and F5 values; a tap during the lock is rejected by Run State's F4 timestamp math, not by HUD; with `valid` false the tap never reaches Run State. The highest-value integration row.
- **AC-21 [I]** Real Tilt Input wiring (`valid`, `state`), including Menus & Screen Flow reading the same values for its own gating.
- **AC-22 [I], on device, BLOCKING at the vertical-slice gate** Measured contrast of the score/PB pill and banner (Ink on 85% Rim White) over at least 3 live backdrops (bright sky, fogged/desaturated, Hit grey-out) is at least 7:1, screenshots and ratios recorded in `production/qa/evidence/hud/`. A numeric on-device threshold is Integration evidence under `coding-standards.md`'s scope limit, so the escalation exception is not used and no `designated-gates.md` entry is needed.

**UI, ADVISORY**
- **HUD-2 [UI, ADVISORY]** Manual walkthrough on a build of the full States table, including the restart prompt's honest locked visual, the swallow cue with `valid` false, and the Hit Menu button; documented in `production/qa/evidence/hud/`, lead sign-off.

**Gate policy.** AC-1 to AC-17 `[C]` are Logic evidence, **BLOCKING** (`coding-standards.md` Logic row); AC-6 and AC-9 carry the highest priority, since gating on the visual lock and forwarding while `valid` is false are the two likeliest implementation errors. AC-18 is an ADVISORY CI lint (the Testing Standards table has no lint row; set by analogy to Scoring's lint tier, producer to confirm). AC-19 to AC-21 are BLOCKING Integration at the first-playable gate and AC-22 is BLOCKING at the vertical-slice gate, owner: user. HUD-2 is ADVISORY (UI row).


## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | Whether a near-miss counter belongs on the HUD after all (Core Rule 10 excludes it from the MVP, keeping the element count minimal per Pillars 1/4) | user, game-designer | Post-MVP |
| 2 | Touch-fallback forwarding (Tilt Input's own rule 11/13, `fallback_source`) is explicitly not implemented here — no MVP driver wires it into a live control scheme for HUD to forward into, mirroring Ball Movement's own FALLBACK-out-of-MVP-scope decision | user | If touch fallback is reintroduced post-MVP |
| 3 | RESOLVED 2026-09-29 (`menus-screen-flow.md` Core Rules 2-3): Play and Resume are genuinely gated on `valid` (no tap forwarded at all, unlike HUD's own cosmetic Restart lock); the ordinary Paused screen's own Restart and Menu buttons are Menus & Screen Flow's, separate from and never overlapping HUD's own Hit-phase tap-anywhere | — | Resolved |
| 4 | The worst-case contrast of the 85%-opacity pill over a live backdrop: the blended ratio is computable now from the art bible's darkest and lightest backdrops; the on-device measurement is AC-22 | user, qa-lead | Vertical slice, on a real device |
| 5 | Whether `reduced_motion_enabled` should eventually scale HUD's own motion (the PB banner's ~200-250ms entrance settle, the countdown ring's progress sweep, the Reconnecting pulse) — Visual/Audio Requirements recommends no for now (both are brief/data-driven), pending the same real-device pass as Open Question 4 | user, accessibility-specialist | Vertical slice, alongside Open Question 4 |
| 6 | Exact touch-target sizing, full layout, and the transition animations between States and Transitions rows — deliberately out of this GDD's own scope (UI Requirements' UX Flag) | ux-designer | `/ux-design`, Pre-Production |
| 7 | Run State must expose its F5 `{remaining, digit, progress}` as a read accessor for HUD. Its F5 note says a non-integer countdown makes the *last* digit shorter, but with `digit = ceil(remaining)` it is the *first* (1700 ms: digit 2 shows for 0.7 s). Both are `run-state-restart.md` edits, not made here | whoever next revises Run State | Run State's next revision |
| 8 | Screen-reader (AccessKit) names, roles and announcements, text size and OS text scaling, handedness and reach, and an optional hold-to-restart are not specified here; AccessKit behaviour on 4.7.2 is unverified | ux-designer, accessibility-specialist | `/ux-design`, Pre-Production |
| 9 | The resume countdown is a fixed-length wait with no extension and no non-visual equivalent, and the pause button is hidden during it; the countdown is Run State's | user, Run State owner | Run State's next revision |
| 10 | Accidental restart: a re-grip tap just after the lock ends restarts before the killer or the banner is read; whether `RESTART_LOCK` (0.5 s) is long enough is a playtest question | user, game-designer | First-playable playtest |
| 11 | `milestone_crossed` is declined here (Core Rule 10); whether Juice & Feedback or another system uses it is not HUD's decision | Juice & Feedback owner | Juice & Feedback's `/design-review` |
