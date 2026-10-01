# Menus & Screen Flow

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-09-29
> **Implements Pillar**: Pillar 4 (One-Thumb Simplicity) — primary, every screen here is touch-driven with no complex navigation; Pillar 1 (Instant Readability) — secondary, Back-button behavior and screen state must be instantly predictable.
> **Creative Director Review (CD-GDD-ALIGN)**: Skipped — lean mode, not a PHASE-GATE.

## Overview

Menus & Screen Flow owns the screens that sit around every run — the Menu the player starts from, the Paused screen they can back out through mid-run, the Settings screen where 5 player preferences live, and the map-load-failure screen for the rare case a map can't open — and the routing decisions that connect them: sending Run State the requests it accepts (`start_requested`, `resume_requested`, `restart_requested`, `menu_requested`), handling Android/iOS Back in every phase except Running, and owning the one decision to actually quit the app. It is the one system every session both starts and ends inside, even though the run itself belongs entirely to other systems — Menus & Screen Flow decides nothing about what happens during a run, only what happens before one starts and after one ends. It reads Tilt Input's own sensor state to gate whether Play or Resume can even be tapped, reads Settings & Accessibility's 5 stored values to populate and update the settings screen, and reads Scoring's `personal_best` for the Menu's own display — but it owns none of that data, only the screens that surface it. It exists because six other systems each defined a hook that nothing was actually driving — without it, a player could never start a run, back out of one safely, change a setting, or even know why the app failed to load a map.

## Player Fantasy

**The fantasy.** Getting in and out of a run never costs me anything — no loading screens I have to wait through, no menus that fight me, no accidental quits.

**What the player feels.**
- **Starting a run feels immediate** — I tap Play and I'm in, not staring at a loading bar.
- **Backing out mid-run never feels risky or punishing** — my progress up to that point (personal best) is already safe.
- **Changing a setting feels like a light touch, not a trip to a separate app.**
- **The Back button always does the sensible thing** — I never get stuck, never accidentally quit when I meant to go back one screen.
- **If something fails (a map won't load), I'm told plainly what happened** — not left staring at a frozen or blank screen.

**Feelings to avoid.** A settings screen that feels like leaving the game; a confirm-dialog for every small action (only genuinely destructive things get one); menus that borrow hazard-danger visual language; anything that delays getting back into a run.

**Serves the pillars.** *Pillar 4, One-Thumb Simplicity* — primary; every screen here is touch-driven, no complex navigation. *Pillar 1, Instant Readability* — secondary; Back-button behavior and screen state must be instantly predictable, the same clarity promise the tube itself makes about hazards.

*(`creative-director` not consulted — lean mode; Player Fantasy is not a Section D/H high-risk section under this project's own review-mode rule. Review manually before production.)*

## Detailed Design

### Core Rules

1. **Four screens owned.** The Menu screen, the ordinary Paused screen, the Settings screen, and a map-load-failure screen. The sensor-lost pause screen is explicitly **not** this system's — HUD owns it outright (`hud.md` Core Rule 8), including its own Menu affordance, but only while `valid` is false. When `valid` becomes true during a `sensor_lost` pause, HUD hides its screen and this system's ordinary Paused screen (Rule 3) takes over, so a recovered sensor always has an on-screen Resume (revised 2026-10-01, `/ux-review` of `design/ux/hud.md`).

2. **Menu screen.** Shown while Run State's `phase` == Menu. A Play button sends `start_requested` on tap — **genuinely gated**, not merely cosmetically dimmed: no tap is forwarded at all whenever Tilt Input's `valid` is false (a real difference from HUD's own Restart, Core Rule 6 there, which forwards every tap unconditionally because Run State's own F4 timestamp math is a real backstop; no such backstop exists for `start_requested`, so this system must withhold the tap itself). The button is still shown, never hidden, and dimmed to communicate "shown but non-interactive" (Pillar 1) — the same visual language HUD's own Core Rule 7 established, distinguishing "reconnecting" from "no motion sensor" the same way, but the *behavior* underneath differs from HUD's own cosmetic lock. This system reads `valid`/`state`/`input_source` independently; it receives nothing from HUD (the two systems are a reverse-only, no-data-flow pair, `hud.md` Dependencies). Also shows `personal_best` (Scoring & Personal Best) as a static reference, and a path to the Settings screen. A confirm-quit dialog opens from here (Rule 5/6).

3. **Ordinary Paused screen.** Shown while `phase` == Paused and the pause source is not `sensor_lost`. Three buttons, all owned here: Resume (sends `resume_requested`, genuinely gated on `valid` exactly like Play — Rule 2's own distinction applies here too), Restart (sends `restart_requested(press_us)` — a separate request path from HUD's own Hit-phase tap-anywhere, Core Rule 6 there being Hit-only means the two never overlap or race), and Menu (sends `menu_requested(press_us)`, ending the run). Restart and Menu show a cosmetic "readying" treatment for `PAUSE_INPUT_GUARD` after the screen appears (mirrors HUD's own restart-lock visual, Core Rule 6 there) — Run State's own timestamp-based guard *is* a real backstop for these two (unlike Play/Resume's `valid` gate), so this readying look is genuinely cosmetic, matching HUD's own pattern; the look communicates "getting ready," never "broken."

4. **Settings screen.** Reachable only from the Menu screen (user decision — Settings & Accessibility's own Open Question 3 resolved as "no" for mid-run access). Exposes all 5 Settings & Accessibility values (`haptics_enabled`, `haptics_intensity`, `tilt_sensitivity`, `reduced_motion_enabled`, `colorblind_safe_enabled`) through their own getters and `set_value` calls — this system owns no setting's value or meaning, only the screen.

5. **Back-button handling, ratified default.** Owns `back_pressed` in every phase except Running and Resuming (Platform Services' own already-stated scope): in Paused, Back does exactly what tapping Resume does, **including Resume's own `valid` gate (Core Rule 3)** — if `valid` is false, Back sends no request at all, the same withholding the on-screen button performs, not merely its destination; this applies uniformly across every Paused source, including `sensor_lost` — HUD renders the visual screen there (Core Rule 1), but Back's request-routing remains this system's own concern. In Hit, Back does exactly what tapping Menu does (abandons the run) — this one is **not** gated on `valid`, since only Play and Resume are ever genuinely gated (Core Rules 2-3). In Menu, Back opens `confirm_quit_open` (Rule 2). In Boot's ordinary loading sub-state, Back is a no-op (nothing to back out of — Platform Services' own `quit_on_go_back = false` is the safety net that keeps the OS from quitting first); in Boot's failure sub-state, Back opens the same `confirm_quit_open` the Menu screen uses (see States and Transitions), unlike ordinary Boot's no-op. Resolves Run State's own Open Question 16 and Platform Services' own Open Question 8 together, ratifying the default both GDDs already proposed.

6. **`quit()` ownership.** Called exactly once, only from the Menu confirm-quit dialog's own explicit confirm tap — never automatically, never from any other screen or phase.

7. **`UI_TAP` haptic, claimed by elimination.** Neither HUD nor Juice & Feedback adopted it (`hud.md` Core Rule 11, `juice-feedback.md` Core Rule 12/Open Question 5) — this system finalizes it and fires on every on-screen tap it owns that is actually forwarded or committed — Play and Resume **only when not gated off (Core Rules 2-3)**, Restart, Menu, the Settings entry point, Settings toggles/slider commits, the Settings screen's own Back, the confirm-quit dialog's Cancel and QUIT taps, and the failure screen's Retry and Quit taps. It does **not** fire on a gated Play/Resume tap — no request was sent, nothing to confirm — and it does **not** fire on a hardware Back-triggered transition (Core Rule 5): Back is a Platform Services signal, not an on-screen tap this system renders.

8. **Map-load-failure screen.** If Run State's own `phase` stays Boot for longer than `MAP_LOAD_TIMEOUT` (Tuning Knobs) without transitioning to Menu, this system shows a plain-language failure screen (states what happened, never a blank or frozen screen — Player Fantasy) offering a retry (re-attempt the load) or quit path. This system does **not** claim ownership of sending `map_ready` itself — that remains a loader/content-pipeline concern, still open (Run State's own Open Question 8, the "who sends it" half).

9. **Menu-to-run and run-to-menu transitions hide Tube Track's own seam-phase jump.** A brief cut or fade covers at least one frame at both the Menu→Running and Running→Menu boundaries (Tube Track's own Open Question 9, resolved) — the exact visual treatment is an implementation/`/ux-design` detail, but the guarantee (at least one frame hidden) is this GDD's own commitment.

10. **No side effects beyond the calls Rules 2-7 already name.** `start_requested`, `resume_requested`, `restart_requested`, `menu_requested`, `quit()`, `Settings.set_value(...)`, `PlatformServices.haptic(UI_TAP)`. No requests to Scoring & Personal Best, Save & Persistence, or HUD — those are read-only or no-relationship dependencies.

11. **No randomness; deterministic.** Given the same sequence of upstream events and player taps, this system always shows the same screen and sends the same requests.

12. **Structure.** `MenuCore` is a `RefCounted` with no engine calls, holding which top-level screen is active (Menu, ordinary Paused, map-load-failure) plus two independent overlay flags — `settings_open` (reachable only while the Menu screen is active, Rule 4) and `confirm_quit_open` (reachable from either the Menu screen's base state or the map-load-failure screen, Rules 5-6, 8) — driven by injected read-only seams for Run State & Restart (`phase`, `run_paused(source)`), Tilt Input (`valid`, `state`, `input_source`), Settings & Accessibility (the 5 getters, `set_value`), Scoring & Personal Best (`personal_best`), and Platform Services (`back_pressed`, `quit()`, `haptic`) plus a `log_sink` — mirrors `HudCore`'s own injected-seam pattern.

### States and Transitions

| Run State `phase` | This system's own active screen | Notes |
|---|---|---|
| Boot, loading (no timeout yet) | None | Back is a no-op (Rule 5) |
| Boot, failure sub-state (after `MAP_LOAD_TIMEOUT` elapses) | Map-load-failure screen (Rule 8) | Back opens `confirm_quit_open` (same dialog instance as the Menu screen's, Rule 5) — unlike ordinary Boot's no-op, this sub-state has a real Back destination |
| Menu | Menu screen (Rule 2), with `settings_open` (Rule 4) and `confirm_quit_open` (Rule 2/6) as reachable overlay flags — `confirm_quit_open` is the same dialog instance also reachable from the Boot failure sub-state above | Back opens `confirm_quit_open` from the base Menu screen; closes `settings_open`/`confirm_quit_open` first if either is open |
| Running | None — HUD only | — |
| Paused, source ≠ `sensor_lost` | Ordinary Paused screen (Rule 3) | Back resumes (Rule 5), genuinely gated on `valid` exactly like the on-screen Resume button |
| Paused, source == `sensor_lost`, `valid` false | None — HUD's own sensor-lost screen | This system renders nothing here (Rule 1); Back's request-routing still applies (Rule 5) even though HUD owns the visual screen |
| Paused, source == `sensor_lost`, `valid` true | Ordinary Paused screen (Rule 3) | Takes over from HUD's screen in the same tick `valid` becomes true; Resume is enabled because `valid` is true |
| Hit | None — HUD's own restart prompt, plus HUD's own Menu button while `valid` is false (`hud.md` Core Rule 7) | Back goes to Menu, ending the run (Rule 5) — not gated on `valid` |
| Resuming | None — HUD's own countdown | — |

### Interactions with Other Systems

| System | Direction | Data / events | Note |
|--------|-----------|----------------|------|
| Run State & Restart (Approved) | in / out | in: `phase_changed`, `run_paused(source)`; out: `start_requested`, `resume_requested`, `restart_requested`, `menu_requested` | Ratifies and narrows the former "HUD or Menus" ambiguity (Rules 2-3, 5) |
| Tilt Input (In Review) | in | `valid`, `state`, `input_source` | Read-only, independent of HUD (Rule 2) |
| Settings & Accessibility (Approved) | in / out | in: all 5 getters; out: `set_value(key, value)` | Rule 4 |
| Scoring & Personal Best (Designed) | in | `personal_best` | Rule 2 |
| Platform Services (Approved) | in / out | in: `back_pressed`; out: `quit()`, `haptic(UI_TAP)` | Rules 5-7 |
| HUD (Designed) | none | — | Reverse-only, already established in `hud.md` — no data flows either direction |
| Save & Persistence (Approved) | none (indirect) | — | Reached only through Settings & Accessibility's own `get_value`/`set_value`, never directly |

## Formulas

Menus & Screen Flow introduces no new formulas. It reads Scoring & Personal Best's own `personal_best` and Settings & Accessibility's own getters as plain stored values (no derivation), and Run State's own `phase`/`run_paused(source)` as plain state (Core Rules 2-4). `MAP_LOAD_TIMEOUT` (Core Rule 8) is a plain guessed constant, not a derived formula — it lives in Tuning Knobs.

No specialist consultation was needed for this section — like HUD's own F-section, Platform Services' F1/F2, Save & Persistence's F1/F2, and Settings & Accessibility's F1/F2, this is boolean/comparison/reference-only, not new continuous math.

## Edge Cases

- **Play or Resume is tapped while `valid` is false**: no request is sent at all — genuinely gated, not merely dimmed (Core Rules 2-3). This is the opposite of HUD's own Restart pattern (which forwards every tap unconditionally, relying on Run State's own F4 timestamp math as the real gate); no such backstop exists for `start_requested`/`resume_requested`, so this system must withhold the tap itself rather than forward it and hope.
- **Back is pressed while Paused and `valid` is false**: no request is sent — Back mirrors Resume's own genuine gate (Core Rule 3), not just its target. A Back handler that forwards unconditionally regardless of the on-screen Resume button's own gate would let a player force a resume with no steerable input, defeating the reason Resume is gated in the first place. This applies uniformly across every Paused source, including `sensor_lost`.
- **Back arrives while the Settings screen is open**: closes Settings back to the base Menu screen — does not open the confirm-quit dialog on the same press (Rule 5's "Menu → confirm-quit" only applies from the base Menu screen, not from a sub-state on top of it).
- **Back arrives while the confirm-quit dialog is open**: dismisses/cancels the dialog, returning to the base Menu screen — does not quit and does not open a second dialog.
- **A Settings value is changed and the player leaves the screen (Back or otherwise) immediately after**: no cancel/revert semantics exist — Settings & Accessibility's own "write immediately on actual change" rule (its Core Rule 5) means the value is already committed the instant it changed; there is nothing to lose by leaving.
- **Back is tapped repeatedly in quick succession while Paused**: each tap independently triggers a Resume-equivalent request — no debouncing here (mirrors HUD's own "multiple impatient taps, no debouncing" edge case); Run State's own state machine handles whatever ordering results.
- **Back arrives while the map-load-failure screen is showing**: offers the same confirm-quit path the Menu screen does — unlike ordinary Boot's no-op (Rule 5), a real "way out" exists on this screen, so Back should reach it rather than doing nothing.
- **The map-load-failure screen's own Retry affordance**: explicitly provisional — it re-attempts whatever Boot's own load mechanism is, but that mechanism's real interface (who actually sends `map_ready`, and what a retry looks like at that layer) is still Run State's own Open Question 8, not resolved here. This screen commits only to showing plain-language failure text and *offering* a retry path, not to the retry's own underlying wiring.

## Dependencies

**Upstream (Menus & Screen Flow needs these)**

| System | Type | What it needs | Note |
|--------|------|----------------|------|
| Run State & Restart (Approved) | Hard | `phase_changed`, `run_paused(source)`; sends `start_requested`, `resume_requested`, `restart_requested`, `menu_requested` | Ratifies and narrows the former "HUD or Menus" ambiguity (Core Rules 2-3, 5) |
| Tilt Input (In Review) | Hard | `valid`, `state`, `input_source` | Read-only, independent of HUD (Core Rule 2) |
| Settings & Accessibility (Approved) | Hard | All 5 getters; `set_value(key, value)` | Core Rule 4 |
| Scoring & Personal Best (Designed) | Soft | `personal_best` | Core Rule 2 |
| Platform Services (Approved) | Hard | `back_pressed`; sends `quit()`, `haptic(UI_TAP)` | Core Rules 5-7 |
| Save & Persistence (Approved) | Soft, indirect | Nothing directly — reached only through Settings & Accessibility's own `get_value`/`set_value` | Core Rule 4's own note |

**Downstream (these need Menus & Screen Flow)**

None currently — no other GDD lists Menus & Screen Flow as a dependency, and this system's own outbound calls all go to upstream systems (Run State, Settings, Platform Services), not to a dependent.

**Bidirectional consistency (checked against the existing GDDs)**
- **Run State & Restart:** already lists Menus & Screen Flow as a Hard dependent for `phase_changed` and as the sender of all four requests — consistent. Its own former "tap anywhere in Hit: HUD or Menus, undecided" ambiguity was already resolved to HUD alone during HUD's own session; this GDD's own Core Rule 3 confirms the *ordinary Paused screen's* Restart is a separate, non-overlapping request path. Open Questions 8 (the "what does a failure look like" half) and 16 resolved and applied.
- **Tilt Input:** already lists "Menus & Screen Flow / HUD" as a combined soft dependent — HUD's own session already noted "Menus & Screen Flow's own share, if any, remains for when it is authored" (Open Question 1); resolved and applied now.
- **Settings & Accessibility:** already lists Menus & Screen Flow as a Hard downstream dependent for the settings screen — consistent. Its own Provisional-assumptions line and Open Question 3 (mid-run access) resolved and applied.
- **Scoring & Personal Best:** already lists Menus & Screen Flow as a Soft dependent for `personal_best` display — consistent, no edit needed.
- **Platform Services:** already lists Menus & Screen Flow as the owner of `back_pressed` handling and `quit()` — consistent. Its own Open Question 8 (the Back-behavior default) resolved and applied.
- **Save & Persistence:** already lists Menus & Screen Flow correctly as reaching it only indirectly through Settings — consistent, no edit needed.
- **HUD:** already lists Menus & Screen Flow as a reverse-only, no-data-flow soft dependent — consistent. Its own Open Question 3 (explicit restart/menu buttons beyond HUD's own tap-anywhere) resolved and applied: the ordinary Paused screen's Restart/Menu buttons are exactly that answer.
- **Tube Track:** its own Open Question 9 (menu-to-run seam-phase-jump hiding) resolved and applied (Core Rule 9).
- **Juice & Feedback:** its own Open Question 5 (`UI_TAP`'s final home) resolved and applied (Core Rule 7).
- **Systems index:** row 14 already updated this session (Phase 2) to add Tilt Input and Platform Services as dependencies.

**Provisional assumptions**: the map loader's own real interface (who sends `map_ready`, what a retry actually triggers at that layer) — Run State's own Open Question 8 keeps its "who sends it" half open; this GDD only commits to what the *player* sees on failure, not the loader's own contract.

## Tuning Knobs

| Knob | Default | Safe range | Affects | Too low | Too high |
|------|---------|------------|---------|---------|----------|
| `MAP_LOAD_TIMEOUT` | 10 s (guess) | 5-30 s | How long Boot can sit without transitioning to Menu before the map-load-failure screen shows (Core Rule 8) | A slow device or cold start false-positives into a failure screen it would have recovered from | A genuinely stuck load leaves the player staring at nothing for longer than necessary before being told |

**Fixed constants (not tuning knobs):** the Back-button behavior per phase (Core Rule 5) and the `UI_TAP` haptic values (Platform Services' own `HapticsConfig`, finalized unchanged by this GDD, Core Rule 7) are correctness/consistency decisions, not designer-adjustable numbers.

**Sources of truth elsewhere:** `PAUSE_INPUT_GUARD` (Run State & Restart, the "readying" cosmetic fill on Restart/Menu, Core Rule 3); the 5 Settings & Accessibility values and their own ranges (Core Rule 4); `UI_TAP`'s duration/amplitude/priority (Platform Services' own `HapticsConfig`).

## Visual/Audio Requirements

This section specs the visual presentation of Menus & Screen Flow's own five surfaces — the Menu screen, the ordinary Paused screen, the Settings screen, the confirm-quit dialog, and the map-load-failure screen — plus the Menu↔Running transition cut/fade (Core Rule 9), using the art bible's UI palette (§4: Ink `#1E2433`, pill Rim White `#F4F8FF` at 85% opacity, accent Lagoon `#0E6A82`) and UI shape grammar (§3e: round family only, never a triangle or wedge). It reuses two of `hud.md`'s own already-committed treatments verbatim rather than re-deriving them — the disabled-not-hidden sensor cue (`hud.md` Core Rule 7, Restart-prompt sensor-dimmed table) and the cosmetic-readying fill (`hud.md` Core Rule 6, Restart-prompt locked/unlocked) — because Core Rules 2-3 here explicitly point back at both.

**House rule, reused from HUD verbatim:** every element in this section sits on its own opaque(-ish) Rim White pill, never bare against the tube/sky or a plain background. This is the same guarantee `hud.md`'s own house rule states and the same reason art bible §7 gives it as a general rule, not a HUD-specific one.

**New house rule, established here: primary vs. secondary action grammar.** This is the first GDD with more than one call-to-action competing for attention on the same screen. A **primary action** (the single most important, most positive tap on its screen — Play on Menu, Resume on Paused, Retry on the failure screen) gets: the largest pill in its group, a Lagoon accent stroke or underline (echoing the PB banner's own accent treatment), and bold Ink text/label. A **secondary action** (Settings entry, Restart, Menu, Quit, Cancel) gets the same Rim White pill / Ink text but no Lagoon accent, and is visibly smaller. This gives every screen exactly one visually loudest tap, consistent with Pillar 1 (Instant Readability) applied to UI rather than the tube.

**Icon caution, applies throughout this section:** several conventional icons for this system's own actions are literally angular and would violate §3e's round-family rule if used unmodified — a play "▶" is a triangle, a gear ⚙ has toothed points, a warning "⚠" is a triangle. **Prefer a plain text label as the primary identifier everywhere in this system** (PLAY, SETTINGS, RESUME, RESTART, MENU, RETRY, QUIT) rather than reaching for these icons; if an icon is wanted as a secondary accent, it must be built from round-family primitives only (a circle, a pill, rounded strokes) with no sharp vertex.

### Menu screen

**Play button.** The largest, most visually dominant element on the screen — the single most important tap in the game — using the primary-action treatment above: largest pill, Lagoon accent stroke, bold Ink "PLAY" label (no triangle glyph). Exact placement and touch-target size defer to `/ux-design`, but recommend it exceed the standard mobile floor (44pt iOS / 48dp Android) by a visible margin, since no other tap on this screen should compete with it for size.

**Genuinely-gated visual treatment.** Reuses HUD's own dimmed-plus-pulse sensor-cue visual verbatim, unmodified — Ink icon/label dimmed to ~40-50% opacity on its usual Rim White pill, with a small Lagoon pulse/spinner only while `state` == Acquiring (reconnecting), no pulse while `state` == Unavailable — exactly `hud.md`'s three-row table applied here rather than a new one. This holds even though the underlying behavior differs from HUD's own cosmetic Restart-lock (there, every tap is still forwarded; here, no tap is sent at all, Core Rule 2): the player-facing question both answer is identical — "can I tap this and have it do the intended thing, right now?" — so they must read identically.

**`personal_best` display.** Same Ink-text-on-Rim-White-pill styling and "BEST"/"PB" label HUD uses. Unlike HUD, there is no `current_score` on this screen for it to be typographically subordinate to, so `personal_best` may take a somewhat larger, more legible size than its HUD counterpart. It must still read as clearly secondary to the Play button — smaller pill, placed clear of Play's own visual zone, no Lagoon accent.

**Settings entry point.** Secondary-action styling, sized to the standard touch-target floor only — a low-frequency, low-stakes action that should not compete with Play. Prefer a "SETTINGS" text label or a rounded-sliders icon (parallel rounded tracks, each with a circular thumb — round-family compliant and foreshadows the Settings screen's own controls); never a toothed gear.

**Confirm-quit dialog entry.** Opens from the Back button while on this screen (Core Rule 5); this screen carries no separate visible "Quit" affordance beyond Back, since Core Rule 6 reserves `quit()` for exactly one dialog and the Menu screen's Back is already the documented path to it.

### Ordinary Paused screen

**Resume.** Reuses `run-state-restart.md`'s own already-reconciled wording verbatim: "Resume is the dominant, largest thumb-zone target." Visually, this is the primary-action treatment (largest pill, Lagoon accent, bold Ink label "RESUME") plus the same genuinely-gated disabled-not-hidden visual as Play, above (Core Rule 3) — size/prominence and interactive-availability are orthogonal, so the button stays large even while dimmed.

**Restart and Menu.** Secondary-action styling, visibly smaller than and separated from Resume, text-labeled "RESTART" / "MENU" rather than icon-first. Both show the cosmetic-readying treatment for the `PAUSE_INPUT_GUARD` window after the screen appears, **reusing HUD's own Restart-lock spec verbatim** rather than inventing a new one, per Core Rule 3's explicit instruction: a calm, continuous Lagoon ring or wedge filling from empty to full, Ink icon/label rising from ~50% to 100% opacity, settling at full Ink opacity with an optional brief, non-jarring brightness settle — never a hard pop, never a color change, never inviting urgency and never looking dead. Both buttons run this fill on the same shared `PAUSE_INPUT_GUARD` clock, so they complete in lockstep. This treatment is explicitly **not** the disabled-not-hidden look Resume uses above — different mechanism (a timestamp guard vs. a sensor state), different meaning ("getting ready" vs. "genuinely can't yet"), so they must and do look different.

### Settings screen

Five controls, all round-family (echoing the resume countdown ring's own circular fill language, so "a filled portion communicates a value" reads as one consistent visual grammar across the whole UI system):

| Control | Setting | Visual |
|---|---|---|
| Toggle (pill switch) | `haptics_enabled` | Rounded track + circular knob. ON: Lagoon-filled track, knob at far end. OFF: Rim White/neutral track, Ink-outlined knob at near end. State is told apart by knob position *and* fill together — never Lagoon-tint-alone. |
| Slider + toggle pair | `haptics_intensity` | Rounded track, Lagoon fill from min to current value, circular Ink-outlined thumb — same fill logic as the toggle above. Nested/indented directly beneath `haptics_enabled` (meaningless while haptics are off) and rendered with the disabled-not-hidden dimmed-opacity treatment (no pulse — nothing is "resolving," it is just contextually inert) when `haptics_enabled` is false. |
| Slider | `tilt_sensitivity` | Same rounded-track/Lagoon-fill/circular-thumb treatment, always fully active (no dependency). |
| Toggle | `reduced_motion_enabled` | Same pill-switch treatment as `haptics_enabled`. |
| Toggle | `colorblind_safe_enabled` | Same pill-switch treatment as `haptics_enabled`. |

**Grouping.** No dominant/subordinate hierarchy is needed among the five (they are peers), but recommend clustering into the three natural domains the settings already imply — input (`tilt_sensitivity`), feedback (`haptics_enabled` + `haptics_intensity`), accessibility (`reduced_motion_enabled` + `colorblind_safe_enabled`) — so the screen doesn't read as one undifferentiated list. Exact spacing/order is `/ux-design`'s own call.

**No confirm/cancel affordance of any kind.** Settings & Accessibility's own Core Rule 5 writes every change immediately, and this GDD's own Edge Cases confirm there is nothing to lose by leaving — so this screen must not show a "Save," "Apply," or "Cancel" control, and its close/back affordance should be a plain "Back" (secondary-action styling, no Lagoon accent, no checkmark glyph).

### Confirm-quit dialog

Modal card, round family (rounded-rectangle or pill), strictly Ink/Rim White/Lagoon — never a warm hue. "Slightly more weighted/serious" is carried entirely through **value and scale**, never hue:
- A heavier scrim (a darkened Ink overlay behind the card, moderate opacity) than any other overlay in this system.
- A larger card and more generous padding than any Settings control.
- **One deliberate, one-time exception to the house Rim-White-pill/Ink-text button pattern**: the actual "QUIT" confirm button inverts the treatment — solid Ink fill, Rim White text — the single heaviest-reading button in the entire UI system, reserved for this one irreversible action; the "Cancel"/"Back" option beside it stays in the ordinary Rim-White-pill/Ink-text house style, so the two read asymmetrically without either using a hue outside the palette.

Entrance: brief ease-out scale-up plus fade, ~200-250ms, no bounce or scale-pop — the same register `hud.md` uses for the PB banner's own entrance, slightly toward the slower end of that range to read as more deliberate than a routine popover.

Copy is plain language ("Quit Tube Rush?"), not alarming.

This is the one and only quit-confirmation surface in the game (Core Rule 6): the map-load-failure screen's own quit path reuses this exact same dialog, unmodified.

### Map-load-failure screen

Plain-language, non-alarming failure communication — no red, no warm hue, despite this being a genuine failure state. Round-family card, Ink text on a Rim White pill/card, centered. Copy states plainly what happened (e.g., "The map couldn't load.") — never a blank or frozen screen. If an icon is used at all, a circular container with a plain "!" glyph is acceptable; a triangular warning icon is not.

Two affordances, using the primary/secondary action grammar above:
- **Retry** — primary-action treatment (largest, Lagoon accent, bold "RETRY" label): the more hopeful, forward-moving action, mirroring why Resume is dominant on the Paused screen.
- **Quit** — secondary-action treatment, opens the identical confirm-quit dialog described above.

Back on this screen reaches the same confirm-quit dialog (Edge Cases) — there is exactly one way this screen ever leads to quitting, reached by two input paths.

### Menu↔Running transition cut/fade

Core Rule 9 commits only to "at least one frame hidden" and defers the exact treatment to implementation/`/ux-design`; the recommendation below is a real starting spec, not a locked contract.

**A brief solid Ink cut, not a white flash and not a world-space effect.** Fade-to-Ink over ~80-100ms, hold across the seam-phase jump itself, fade-from-Ink over ~80-100ms — a total envelope of roughly 150-250ms, symmetric at both the Menu→Running and Running→Menu boundaries. This is a **UI-layer treatment (Ink/Rim White/Lagoon), not a Juice & Feedback world effect**, and deliberately does not reuse Mood State 5's own soft white flash — that flash is the hit's own signature moment; reusing it for a routine menu transition would teach players to associate an ordinary boundary with a death. Ink was chosen over Rim White for the same reason: white is already claimed by two other moments (the hit flash and the PB ring sweep).

### Audio

Menus & Screen Flow owns no audio of its own — the same "none, deferred" precedent HUD, Tilt Input, and Save & Persistence already established. `UI_TAP`'s haptic ownership (Core Rule 7) does not imply an accompanying audio requirement — haptics (Platform Services) and audio (Juice & Feedback) are separate systems with separate ownership; if a tap sound for `UI_TAP` moments is ever wanted, that is Juice & Feedback's own future addition, not something this system claims for itself.

### Accessibility cross-check

- **`colorblind_safe_enabled`**: not consumed by this system, and no element here needs it — every signal separates by shape, position, opacity, size, and text label, never by hue alone (the primary/secondary action grammar is accent-plus-size, not accent alone; the genuinely-gated vs. cosmetic-readying distinction is opacity-plus-pulse-presence, not color; toggle state is knob-position-plus-fill, not fill alone).
- **`reduced_motion_enabled`**: not consumed by this system today. Every motion here — the confirm-quit dialog's entrance, the Restart/Menu readying fill, the Menu↔Running cut/fade — is brief, non-repeating, and sits well under the photosensitivity ceiling. A real-device pass may surface a need to soften the cut/fade or dialog entrance under this flag later; if so, that becomes a new Open Question, not a silent scope change.

## UI Requirements

Menus & Screen Flow owns five on-screen surfaces, all specified above (Detailed Design for behavior, Visual/Audio Requirements for treatment):

1. Menu screen (Play button, `personal_best` display, Settings entry)
2. Ordinary Paused screen (Resume, Restart, Menu)
3. Settings screen (5 toggles/sliders)
4. Confirm-quit dialog
5. Map-load-failure screen (plain-language failure, Retry/Quit)

Plus the Menu↔Running transition cut/fade (Core Rule 9).

No requests to other systems beyond what Dependencies already states — Run State, Tilt Input, Settings & Accessibility, Scoring & Personal Best, and Platform Services already publish everything this system reads, and Run State/Settings/Platform Services already accept the requests this system sends.

**📌 UX Flag — Menus & Screen Flow**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the full screen layouts (exact positions, sizes, touch targets, safe-area handling, and the transition animations between screens) **before** writing epics. This GDD deliberately stops at behavior and visual treatment, not pixel layout — stories that reference this system's own UI should cite `design/ux/menus-screen-flow.md` (or per-screen specs), not this GDD directly.

## Acceptance Criteria

**Targets:** **[C]** `MenuCore`, a `RefCounted` with no engine calls, driven entirely through injected read-only seams and push handlers (Core Rule 12) — pull seams re-queried on every `tick(dt)` for `valid`/`state`/`input_source` (Tilt Input) and for elapsed Boot time (against the injected `MAP_LOAD_TIMEOUT`); a pull seam for `personal_best` (Scoring & Personal Best), read once at construction and re-pulled on every `on_phase_changed(MENU)` (the Menu screen has no push event to tell it the value changed, unlike HUD's `personal_best_updated`, so freshness-on-entry is this system's own responsibility); pull seams for the 5 Settings & Accessibility getters, read when the Settings screen opens; push handlers for `on_phase_changed(new_phase)`, `on_run_paused(source)`, `on_back_pressed()`; tap handlers `on_play_tapped()`, `on_resume_tapped()`, `on_restart_tapped(press_us)`, `on_menu_tapped(press_us)`, `on_settings_tapped()`, `on_settings_back_tapped()`, `on_setting_changed(key, value)`, `on_quit_confirm_tapped()`, `on_quit_cancel_tapped()`, `on_retry_tapped()`, `on_failure_quit_tapped()`; outbound Callables for `start_requested`, `resume_requested`, `restart_requested(press_us)`, `menu_requested(press_us)`, `quit`, `set_value(key, value)`, `haptic(kind)`; plus a `log_sink`. **`[K]` tier included, unlike `hud.md`'s precedent**: HUD had zero designer knobs of its own, so it carried no `[K]` row; this GDD owns one real tunable (`MAP_LOAD_TIMEOUT`, Tuning Knobs) that `MenuCore` itself must read to decide when to show the failure screen, so a `MenuConfig`-shipped-default smoke check is warranted here even though Core Rule 12 names no other `*Config` resource. **No `[M]` tier**: Core Rule 12 states no `MenuMath` is anticipated — every value this system reads (`personal_best`, the 5 settings, `phase`/`run_paused(source)`) is a plain stored value or plain state, per Formulas; there is no derivation to test in isolation. **No `[N]` tier**: this GDD stops at `MenuCore` behavior and visual treatment, not pixel layout (UI Requirements' own UX Flag) — the Control-node rendering layer is `/ux-design` and `[I]`/`[V]`/`[UI]` scope. Exact method names above are illustrative, not GDD-pinned — these ACs test the seam *contract* via spies, the same standard HUD's and Settings & Accessibility's own `[C]` rows set. Tests live in `tests/unit/menus_screen_flow/`, named `menu_[feature]_test.gd`. Exact `==` for booleans, enums, log codes, call counts, and outbound payloads; 1e-6 for the elapsed-Boot-time float against `MAP_LOAD_TIMEOUT`. A fresh core per case.

**Fixture** (`make_menu_fixture()`, a named factory, no `.tres` load): phase enum values reused verbatim from Run State's own canonical enum (`BOOT, MENU, RUNNING, PAUSED, HIT, RESUMING`), never redefined — mirrors HUD's own reuse precedent. Pause-source constants reused from Run State (`BUTTON, BACK, APP_INTERRUPTED, SENSOR_LOST`). Tilt Input `state` constants (`UNAVAILABLE, ACQUIRING, LIVE`). `MAP_LOAD_TIMEOUT_TEST` = `3.0` s (fixture-distinct; the shipped `MenuConfig` default is `10.0` s, so no `[C]` AC can pass against a hardcoded shipped value). `PERSONAL_BEST_MENU_TEST` = `500` (initial pull); `PERSONAL_BEST_MENU_REFRESHED_TEST` = `750` (value present on a later Menu-entry pull, simulating a best set during the intervening run). `SETTINGS_STORED_TEST` = `{haptics_enabled: true, haptics_intensity: 0.8, tilt_sensitivity: 1.2, reduced_motion_enabled: false, colorblind_safe_enabled: true}` (fixture-distinct from Settings & Accessibility's own shipped defaults). `PRESS_US_T0`/`PRESS_US_T1`/... distinct integer timestamps for Restart/Menu/Back taps. `UI_TAP` reused verbatim as the one haptic kind this system ever sends. `make_pull_stub(sequence_or_value)` returns a `Callable` plus a spy recording call count and per-call return progression. `make_log_spy()` records `(level, code, message)` tuples. `make_menu_core(get_valid, get_tilt_state, get_input_source, get_personal_best, get_haptics_enabled, get_haptics_intensity, get_tilt_sensitivity, get_reduced_motion_enabled, get_colorblind_safe_enabled, set_value, quit_fn, haptic_fn, start_requested_fn, resume_requested_fn, restart_requested_fn, menu_requested_fn, map_load_timeout, log_sink)` constructs a fresh `MenuCore`.

**States and Transitions — table-driven (Core Rule 1, States table)**
- **AC-1 [C]** Drive `MenuCore` through every reachable combination of `{Boot-loading, Boot-failure, Menu-base, Menu+Settings-open, Menu+confirm_quit_open, Paused+button, Paused+back, Paused+app_interrupted, Paused+sensor_lost, Hit, Resuming, Running}` via `on_phase_changed`/`on_run_paused(source)`/`on_settings_tapped`/`on_back_pressed`, and assert the active top-level screen and both overlay flags (`settings_open`, `confirm_quit_open`) exactly match the States table for that row — including that `Paused+button`, `Paused+back`, and `Paused+app_interrupted` render identically (Core Rule 3's own source-independence) and that `Paused+sensor_lost` shows nothing here (Core Rule 1 — HUD owns that screen). Also asserts Settings is reachable **only** while Menu-base is active — an attempt to open it from any other row is a no-op (Core Rule 4's Menu-only reachability).

**Core Rules 2/3 — genuinely-gated Play/Resume (the mirror image of HUD's own Restart-forwarding risk, inverted)**
- **AC-2 [C]** `on_play_tapped()` while `valid == false`: zero calls to `start_requested`. A companion row with `valid == true`: exactly one call to `start_requested` with no arguments. **Mutation-catching**: an implementation that forwards the tap unconditionally (copying HUD's own Restart pattern, Core Rule 6 there) and relies on a downstream gate must fail the `valid == false` row — there is no such backstop here (Core Rule 2's own explicit warning).
- **AC-3 [C]** Identical table for `on_resume_tapped()` against `resume_requested` while `phase == PAUSED` (non-`sensor_lost` source): zero calls when `valid == false`, exactly one when `valid == true` — the same mutation-catching case as AC-2, applied to Resume (Core Rule 3's own "genuinely gated exactly like Play").
- **AC-4 [C]** Back-at-Paused inherits Resume's own gate (Core Rule 5): `on_back_pressed()` while `phase == PAUSED` and `valid == false` produces zero calls to `resume_requested`; the same call while `valid == true` produces exactly one. Run across all four Paused sources (`BUTTON, BACK, APP_INTERRUPTED, SENSOR_LOST`) — the gate applies uniformly regardless of source. **Mutation-catching**: an implementation that treats Back as a separate code path forwarding unconditionally (not re-checking `valid`) must fail the `valid == false` rows — this is the single most likely implementation error in this GDD, since Back and the on-screen Resume button are natural candidates for separate handlers that silently diverge.

**Core Rule 3 — cosmetic-readying for Restart/Menu (the opposite failure mode from AC-2 through AC-4)**
- **AC-5 [C]** `on_restart_tapped(press_us)` and `on_menu_tapped(press_us)` while `phase == PAUSED`, tested both before and after the `PAUSE_INPUT_GUARD` window's cosmetic fill completes, and with `valid` both `true` and `false`: every tap produces exactly one call to the corresponding outbound method (`restart_requested(press_us)` / `menu_requested(press_us)`), regardless of the guard's cosmetic state and regardless of `valid`. **Mutation-catching**: an implementation that gates these two on the guard's own completion (treating the cosmetic readying fill as a real lock, confusing it with Play/Resume's genuine gate) must fail the pre-completion rows — Restart and Menu are never gated on anything in this system; Run State's own timestamp math (`PAUSE_INPUT_GUARD`) is the real backstop, exactly mirroring HUD's own Restart pattern, not Play/Resume's.

**Core Rule 5 — Back-button routing table, all phases + sub-states + the failure-screen exception**
- **AC-6 [C]** Table-driven, one row per reachable Back context: `Boot-loading` → no outbound call, `confirm_quit_open` stays `false` (ordinary no-op); `Boot-failure` → `confirm_quit_open` becomes `true`, zero calls to `quit` (unlike ordinary Boot, this sub-state has a real destination); `Menu-base` → `confirm_quit_open` becomes `true`; `Menu+Settings-open` → `settings_open` becomes `false`, `confirm_quit_open` stays `false` (does **not** also open the dialog on the same press — Edge Cases); `Menu+confirm_quit_open` → `confirm_quit_open` becomes `false`, zero calls to `quit` (cancels, does not quit, does not open a second dialog); `Paused` (any of the 4 sources) → routed through AC-4's own gate; `Hit` → exactly one call to `menu_requested(press_us)`, unconditionally — **not** gated on `valid` (only Play/Resume are gated, Core Rules 2-3; a mutation that gates this call on `valid` must fail). `Running`/`Resuming` are out of this system's own scope entirely (Platform Services' already-stated scope) — asserted as untested/inapplicable rows, not zero-call assertions, since this system never receives `back_pressed` in those phases at all.
- **AC-7 [C]** Confirm-quit dialog identity across its two entry points: opening it from `Menu-base` via `on_back_pressed()` and opening it from `Boot-failure` via `on_back_pressed()` or `on_failure_quit_tapped()` produce identical `confirm_quit_open` state and identical subsequent behavior for `on_quit_confirm_tapped()`/`on_quit_cancel_tapped()` — same outbound-call shape, same cancel-returns-to-caller behavior (returns to `Menu-base` when opened from Menu, to `Boot-failure` when opened from there) — proving there is exactly one dialog implementation reachable from two contexts, not two dialogs that happen to look alike.

**Core Rule 6 — `quit()` single-call-site guarantee**
- **AC-8 [C]** Across a full scripted session touching every screen and sub-state (Menu, Settings, both confirm-quit entry points, Paused, Hit, the failure screen), `quit` is called **zero** times except via `on_quit_confirm_tapped()` while `confirm_quit_open == true`, where it is called exactly once. **Mutation-catching**: an implementation that calls `quit` directly from `on_back_pressed()` in some phase, or as a side effect of `on_failure_quit_tapped()` without going through the dialog's own confirm tap, must fail this AC.

**Core Rule 7 — `UI_TAP` finalized, exhaustive scope**
- **AC-9 [C]** Table of every tap this system owns that is actually forwarded or committed — `on_play_tapped()`/`on_resume_tapped()` with `valid == true`, `on_restart_tapped`, `on_menu_tapped`, `on_settings_tapped`, `on_settings_back_tapped`, `on_setting_changed` (an actual value change), `on_quit_confirm_tapped`, `on_quit_cancel_tapped`, `on_retry_tapped`, `on_failure_quit_tapped` — each produces exactly one call to `haptic(UI_TAP)`.
- **AC-10 [C]** Non-firing table (the corrected scope's own negative space): `on_play_tapped()`/`on_resume_tapped()` with `valid == false` (gated, discarded — zero `start_requested`/`resume_requested` calls per AC-2/AC-3) produces **zero** `haptic` calls; every `on_back_pressed()` row from AC-6 also produces **zero** `haptic` calls, regardless of what it routes to. **Mutation-catching**: an implementation that fires `UI_TAP` on every tap handler invocation regardless of outcome (treating the haptic as unconditional UI feedback rather than a "this did something" confirmation) must fail both halves of this table.

**Core Rule 8 — `MAP_LOAD_TIMEOUT`-driven failure screen**
- **AC-11 [C]** `tick(dt)` calls accumulating past `MAP_LOAD_TIMEOUT_TEST` (3.0 s) while `phase` has never left `BOOT`: the failure screen becomes active (`Boot-failure` per AC-1) exactly once elapsed time crosses the threshold, not before. A companion row delivers `on_phase_changed(MENU)` at `2.9` s (before the threshold): the failure screen never activates, and further `tick(dt)` calls (now past 3.0 s of wall-clock time but with `phase == MENU`) confirm it stays inactive — the timeout only matters while still in Boot.
- **AC-12 [C]** Boundary exactness: `tick` calls landing at `2.999s / 3.000s / 3.001s` elapsed against `MAP_LOAD_TIMEOUT_TEST = 3.0`: the failure screen is inactive at `2.999s`, active at `3.000s` and after — a `>=` comparison, not `>`, tested directly (a mutation using strict `>` must fail the exact-boundary row).

**Core Rule 9 — Menu↔Running transition-cover flag**
- **AC-13 [C]** A `transition_covering` flag (or equivalent) reads `true` for at least one `tick()` spanning both the `Menu -> Running` and the `Running -> Menu` phase-change calls, and `false` outside those windows — proving at least one tick is flagged across both boundaries per Core Rule 9's "at least one frame hidden" commitment. The exact visual duration/treatment is out of `[C]` scope (deferred to `/ux-design`, tested at `[V]` below, MENU-3).

**Core Rule 4 / Edge Cases — Settings immediate-commit, no revert**
- **AC-14 [C]** `on_setting_changed("haptics_intensity", 0.6)` while Settings is open: exactly one call to `set_value("haptics_intensity", 0.6)`, immediately, with no batching or debounce window. A follow-up `on_settings_back_tapped()` (closing Settings) or `on_back_pressed()` (same effect, per AC-6) produces **zero** additional calls to `set_value` and **no** call reverting the value — confirming there is no cancel/revert code path to accidentally exercise (Edge Cases: "no cancel/revert semantics exist").
- **AC-15 [C]** Settings-open reachability is Menu-exclusive (Core Rule 4): `on_settings_tapped()` called while `phase` is anything other than `MENU`, or while `Menu+confirm_quit_open` is already true, is a no-op — `settings_open` stays `false` and no getters are pulled.

**Edge Case — repeated Back taps in Paused, no debouncing**
- **AC-16 [C]** 5 `on_back_pressed()` calls in immediate succession while `phase == PAUSED` and `valid == true`: 5 separate calls to `resume_requested`, no coalescing, no internal cap or cooldown — mirrors HUD's own "multiple impatient taps, no debouncing" precedent. A companion row with `valid == false` throughout: 5 calls, 5 rejections, zero forwarded — AC-4's gate applies independently to every tap, not just the first.

**Determinism (Core Rule 11)**
- **AC-17 [C]** Two independently constructed `MenuCore` instances fed an identical scripted sequence of pulled seam values, `tick(dt)` calls, push events, and taps (spanning every screen, both confirm-quit entry points, a gated and an ungated Play/Resume attempt, a Settings change, and the failure-screen timeout) produce bit-identical display-state snapshots and outbound-call sequences after every step.

**Core Rule 10 — exactly 7 outbound calls, architecture cap**
- **AC-18 [L]** Static scan of `MenuCore`'s source: zero references to a Scoring-, Tilt-Input-, Settings-, Run-State-, or Platform-Services-shaped symbol beyond the opaque injected seam Callables; zero matches for `Time.`, `Engine.`, `OS.`, `DisplayServer.`, `get_tree`, `_process`, `_physics_process`, `randi`, `randf`, `randomize`, `ConfigFile`, `FileAccess` (no engine coupling, Core Rule 12; no randomness, Core Rule 11). An unused, never-invoked seam or outbound Callable shaped like an 8th call must still fail this AC.
- **AC-19 [C]** Behavioral spy across a full scripted session (every screen, both confirm-quit entry points, a gated and ungated Play/Resume attempt, a Settings change, a failure-screen timeout and Retry, a Back tap in every reachable context): the only outbound calls recorded are exactly the 7 Core Rule 10 names — `start_requested`, `resume_requested`, `restart_requested(press_us)`, `menu_requested(press_us)`, `quit`, `set_value(key, value)`, `haptic(UI_TAP)` — zero calls to any other method, and zero calls with a payload shape not matching those rules.

**Config/Data, ADVISORY**
- **AC-20 [K, ADVISORY]** Shipped `MenuConfig.MAP_LOAD_TIMEOUT` equals the Tuning Knobs default (10.0 s), within the 5-30 s safe range — the fixture deliberately uses `3.0` s instead (AC-11/AC-12), so this smoke check is the only place the real shipped number is asserted. Per `coding-standards.md`'s Config/Data row, ADVISORY.

**Integration [I], deferred**
- **AC-21 [I], deferred** — real Run State & Restart wiring: a live `RunStateCore` feeding `phase_changed`/`run_paused(source)` into a real `MenuCore`, confirming `start_requested`/`resume_requested`/`restart_requested`/`menu_requested` round-trip against Run State's own gates (including that a Restart/Menu tap forwarded during `PAUSE_INPUT_GUARD`, per AC-5, is genuinely filtered by Run State's own F4 timestamp math, not by this system). No owner/date yet.
- **AC-22 [I], deferred** — real Tilt Input wiring: a live `TiltCore` feeding `valid`/`state`/`input_source`, confirming Play/Resume gating (AC-2/AC-3/AC-4) reflects real sensor transitions, not just stubbed values. No owner/date yet.
- **AC-23 [I], deferred** — real Settings & Accessibility wiring: a live `SettingsCore` receiving `set_value` calls and returning updated getter values on the next Settings-open pull. No owner/date yet.
- **AC-24 [I], deferred** — real Scoring & Personal Best wiring: a live `ScoringCore` feeding `personal_best`, confirming the Menu-entry re-pull (Targets) reflects a best set during the just-ended run. No owner/date yet.
- **AC-25 [I], deferred** — real Platform Services wiring: a live `back_pressed` signal and real `quit()`/`haptic(UI_TAP)` calls, confirming the Back-routing table (AC-6) and the `quit()` single-call-site guarantee (AC-8) hold against the actual OS/engine signal, not a scripted call. No owner/date yet.
- **AC-26 [I], deferred** — the failure screen's Retry affordance: explicitly provisional (Edge Cases) pending Run State's own Open Question 8 (who sends `map_ready`, what a retry triggers at that layer) — `on_retry_tapped()` fires `UI_TAP` (AC-9) and is otherwise untested beyond that, since its real wiring doesn't exist yet. No owner/date; becomes BLOCKING `[I]` only once Open Question 8 resolves and a real retry mechanism exists to wire against.

**Visual/Feel, ADVISORY**
- **MENU-1 [V, ADVISORY]** Primary/secondary action grammar readability: on-device screenshot check across the Menu, Paused, and failure screens confirming exactly one visually loudest tap per screen (Play / Resume / Retry, respectively — largest pill, Lagoon accent, bold label) and that every secondary action (Settings, Restart, Menu, Quit, Cancel) reads unambiguously smaller with no accent. Screenshot + lead sign-off in `production/qa/evidence/menus-screen-flow/`. **Not designated BLOCKING**: no entry exists in `production/qa/designated-gates.md` for Menus & Screen Flow, and this is presentation polish, not cross-system retuning.
- **MENU-2 [V, ADVISORY]** Genuinely-gated vs. cosmetic-readying, visually distinguishable from each other: a screenshot of the Paused screen with `valid == false` **and** still inside the `PAUSE_INPUT_GUARD` window (both treatments visible simultaneously — Resume dimmed-plus-pulse, Restart/Menu mid-fill) confirms a tester can tell the two apart at a glance without reading a label, and separately that Play's own dimmed treatment on the Menu screen matches HUD's disabled-not-hidden spec verbatim. Screenshot + lead sign-off in `production/qa/evidence/menus-screen-flow/`. **Not designated BLOCKING** — same rationale as MENU-1.
- **MENU-3 [V, ADVISORY]** Menu↔Running transition cut, on-device: confirms the recommended ~150-250 ms Ink cut envelope genuinely covers the seam-phase jump at both boundaries with no visible pop-in of Tube Track's own geometry, and that it reads distinctly from Mood State 5's white hit-flash (never confusable with a death). Screenshot/short clip + lead sign-off in `production/qa/evidence/menus-screen-flow/`. **Not designated BLOCKING**: a device-observable timing/visual claim without a numeric pass/fail threshold tied to cross-system retuning.

**UI, ADVISORY**
- **MENU-4 [UI, ADVISORY]** Manual interaction walkthrough on a build, once implemented: exercise the full States and Transitions table live (both Boot rows, both confirm-quit entry points, Settings open/close, every Back-routing row from AC-6, a gated Play/Resume attempt with the sensor genuinely off) and confirm each matches the documented behavior, with particular attention to the two mirror-image risks this GDD names explicitly — a Play/Resume tap while invalid producing visibly nothing, and a Restart/Menu tap during the cosmetic readying fill visibly succeeding. Documented in `production/qa/evidence/menus-screen-flow/`, lead sign-off. ADVISORY per `coding-standards.md`'s Testing Standards UI row.

**Gate policy.** AC-1 through AC-17 (`[C]`) are Logic evidence — a dependency-injected, read-only-plus-tap-routing core, the same bar HUD's and Settings & Accessibility's own `[C]` rows set — **BLOCKING**, per `coding-standards.md`'s Logic row, no exceptions. AC-2 through AC-4 (Core Rules 2-3, the genuinely-gated Play/Resume/Back trio) and AC-5 (Core Rule 3's cosmetic-readying counter-case) carry the highest priority in this set: this GDD explicitly names the gated-vs-forwarded distinction as its single most likely implementation error in both directions, and AC-4 in particular is the direct test for Back silently bypassing Resume's own gate — do not treat these as interchangeable with the other `[C]` rows if triage time is short. AC-18 (`[L]`) is BLOCKING under the same Logic row, not a new category — identical precedent to HUD AC-18 / Settings AC-18 / Camera AC-17. AC-20 (`[K, ADVISORY]`) is ADVISORY per Testing Standards' Config/Data row — unlike HUD, this GDD does own one real tunable, so the row exists, but a miss here is a data-config mismatch, not a logic defect. AC-21 through AC-26 (`[I]`) are Integration evidence with no named owner+date yet, so they remain **deferred**, not BLOCKING, per `coding-standards.md`'s Integration row — each becomes BLOCKING the moment it acquires one; AC-26 additionally cannot acquire one until Run State's own Open Question 8 resolves. MENU-1 through MENU-3 (`[V, ADVISORY]`) and MENU-4 (`[UI, ADVISORY]`) are ADVISORY per Testing Standards' own Visual/Feel and UI rules; none is escalated to BLOCKING under `coding-standards.md`'s exception, since `production/qa/designated-gates.md` carries no Menus & Screen Flow entry and none of the three V checks is the sole falsification test for a pillar-breaking, cross-system-retuning failure mode.

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | The map-load-failure screen's own Retry affordance is explicitly provisional (Edge Cases, Core Rule 8) — its real wiring is pending Run State's own Open Question 8 (who sends `map_ready`, what a retry triggers at the loader layer) | map loader (whoever authors it) | When that system is authored |
| 2 | Exact layout, sizing, touch targets, and screen copy — deliberately out of this GDD's own scope (UI Requirements' UX Flag) | ux-designer | `/ux-design`, Pre-Production |
| 3 | MENU-1/MENU-2/MENU-3's own real-device validation (the primary/secondary action grammar's readability, the genuinely-gated-vs-cosmetic-readying visual distinction, the Menu↔Running transition cut) — all currently only exercised at the design-spec level, not on a real device | user, qa-lead | Vertical slice, on a real device |
| 4 | Whether `reduced_motion_enabled` should eventually scale this system's own motion (the confirm-quit dialog's entrance, the Menu↔Running cut/fade) — Visual/Audio Requirements recommends no for now (both are brief/non-repeating), pending the same real-device pass as Open Question 3 | user, accessibility-specialist | Vertical slice, alongside Open Question 3 |
