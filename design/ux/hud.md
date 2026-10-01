# HUD Design

> **Status**: Revised after `/ux-review` 2026-10-01 (NEEDS REVISION: 2 blocking and 5 advisory items addressed); pending a re-run of `/ux-review` in a fresh session
> **Author**: user + ux-designer
> **Last Updated**: 2026-10-01
> **Template**: HUD Design
> **Behavior source**: `design/gdd/hud.md` (what each element does); this file owns layout, sizing, touch targets, transitions and accessibility.

---

## HUD Philosophy

**Minimal, phase-adaptive.** The HUD is a thin layer of instruments that never competes with the tube. At most four things are on screen in any phase, and each phase shows only what that phase needs.

1. **Running** is the quietest phase: score and BEST (once a best exists) plus one pause button. Nothing else, and no live value moves or pulses on its own.
2. **Every other phase swaps the content, never the layout.** Hit, Resuming and the sensor-lost pause each show their own few elements in fixed zones. Score and BEST do not change position or width across phases.
3. **Every element sits on its own Rim White pill.** Contrast does not depend on the world behind it.
4. **A state is told apart by shape, opacity and text label, never by hue.** There are no warm colors or gold anywhere, even for error-like states.
5. **One thumb, no precision.** The only precision-free control is the tap-anywhere restart. Small controls (pause, Menu) are placed away from the resting grip.

**Conflict rule:** if a proposed element would add a fifth simultaneous item, or would need motion on a live value, it is declined unless a GDD requires it.

*Sources: `design/gdd/hud.md` (States table, Core Rules 2 and 10), `design/art/art-bible.md` §7, Pillars 1 and 4.*

---

## Information Architecture

### Full Information Inventory

Everything the GDDs ask the HUD to communicate. Almost all of it comes from `design/gdd/hud.md`; Juice & Feedback, Camera, Tilt Input and Scoring add no UI requirement beyond what HUD already owns.

### Categorization

| # | Item | Category | When | Source |
|---|---|---|---|---|
| 1 | Score (`current_score`) | **Must Show** | Running; frozen in Paused and Hit | `hud.md` Rule 2 |
| 2 | BEST pill, with the persistent `NEW BEST` state | **Must Show** (hidden while the stored best is 0) | Running, Paused, Hit | Rule 2 |
| 3 | Pause button | Contextual | Running only | Rule 4 |
| 4 | Resume countdown (ring + digit) | Contextual | Resuming only | Rule 5 |
| 5 | Restart prompt (locked, unlocked, sensor-dimmed) | Contextual | Hit only | Rules 6-7 |
| 6 | Personal-best banner | Contextual | Hit only; clears on `run_reset` or a phase change to Menu | Rule 3 |
| 7 | Sensor cue text (`Reconnecting…`, `No motion sensor`, `Sensor not ready`) | Contextual | Hit with `valid` false; sensor-lost pause | Rules 6-8 |
| 8 | Hit Menu button | Contextual | Hit with `valid` false | Rule 7 |
| 9 | Sensor-lost pause screen with Menu | Contextual | Paused (`sensor_lost`) | Rule 8 |
| 10 | Near-miss counter, milestone beat | **Hidden** | Never in the MVP; the world and Juice & Feedback carry them | Rule 10 |
| 11 | Run time, speed, death cause | **Hidden** | The hazard itself shows the cause of death (Pillar 1); no GDD requires them | none |

**On Demand:** none. A one-thumb game has nothing the player should have to summon.

**Philosophy check.** Must Show is 2 items. The densest moment is Hit with `valid` false: score+BEST, banner, restart prompt, Menu button. The sensor label is treated as part of the restart prompt (one element, not counted separately), so the worst case is **4 groups**, matching the Philosophy cap.

---

## Layout Zones

Portrait, locked (`tilt-input.md` Rule 3). Arrangement chosen: **top corners**. All offsets are in dp inside the safe area supplied by Platform Services (`safe_area`, never the raw screen), so notches and the home indicator are respected.

| Zone | Position | Holds | Phase |
|---|---|---|---|
| **Z1 Readout** | Top-left, 16 dp from the left safe edge, 8 dp below the top safe edge | Score pill; BEST pill stacked under it (8 dp gap) | Running, Paused, Hit |
| **Z2 Pause** | Top-right, same 16 dp / 8 dp insets | Pause button | Running only |
| **Z3 Banner** | Top-centre, below the Z1/Z2 row (12 dp gap), centred, at most 80% of safe width | Personal-best banner | Hit only |
| **Z4 Status slot** | Horizontally centred; vertical centre at `min(0.70 × H, H − 240 dp)`, where H is the safe-area height (see Z4/Z5 budget below). The group is about 116 dp high (88 dp circle, 8 dp gap, 20 dp label) | Restart prompt (with its sensor label), **or** the resume countdown, **or** the sensor-lost pause label. Never two at once | Hit, Resuming, Paused (`sensor_lost`) |
| **Z5 Menu** | Bottom-centre, 16 dp below the bottom edge of Z4; about 70 dp high (48 dp button, 4 dp gap, 18 dp label); outside both thumb corners | Round Menu button | Hit with `valid` false; sensor-lost pause |

### Z4/Z5 vertical budget

The bottom 96 dp of the safe area stays empty (gesture bar, resting thumbs). Z5 must end at least 96 dp above the safe bottom edge on every screen. Z4's centre is therefore `min(0.70 × H, H − 240 dp)`: 240 = 96 (clear band) + 70 (Z5) + 16 (gap) + 58 (half of Z4).

| H (dp) | Z4 centre | Z5 span | Z5 bottom to safe bottom |
|---|---|---|---|
| 640 (16:9) | 400 (62.5%) | 471 to 541 | 99 |
| 800 | 560 (70%) | 631 to 701 | 99 |
| 900 (20:9) | 630 (70%) | 701 to 771 | 129 |

On short screens Z4 rises toward the approach zone (62.5% at H = 640); checked on device (Open Question 3). The earlier "lower third" wording is dropped.

### Layout rules

1. **Z1 never moves between phases.** The score pill has a fixed width reserved for 6 tabular digits, so it does not change width on rollover (`hud.md` Core Rule 2).
2. **The centre and both lower corners are empty** except where Z4 and Z5 are showing. The centre is the approach zone (art bible §3e) and the lower corners are where the thumbs rest.
3. **Z4 is shared** by three contents that never occur in the same phase, so the player always looks in one place to learn what the system is saying.
4. **Menu sits bottom-centre, not bottom-left**, because the lower corners are the resting grip and an accidental tap there would abandon to Menu.
5. **No handedness mirroring in the MVP** (pause is top-right by default); see Open Questions.
6. **UNVERIFIED placement:** Z3 and Z4 assume where the ball and hazards sit on screen. `camera.md` does not fix that, so both are checked on a real device in the vertical slice (Open Questions).

---

## HUD Elements

All sizes are **starting values, unverified on device** (measured at AC-22 and HUD-2). Touch targets follow the floor `design/gdd/hud.md` recommends: 44 pt iOS / 48 dp Android.

| # | Element (zone) | Form and size | Content | Update | Trigger | Animation |
|---|---|---|---|---|---|---|
| 1 | **Score** (Z1) | Pill, 44 dp high, width fixed for 6 tabular digits; bold 28 sp Ink on Rim White 85% | `current_score`, no unit | Every tick, exact, from the pull seam | Running; frozen in Paused and Hit | **None.** No smoothing, pulse or colour shift (`hud.md` Rule 2) |
| 2 | **BEST** (Z1) | Pill, 32 dp high, same width as Score; 18 sp Ink, tag `BEST` at 14 sp | Stored best. In the passed state the tag becomes `NEW BEST`, the value tracks the live score, and a Lagoon 2 dp outline appears | Static; changes on `personal_best_updated`; passed state on `personal_best_passed` | Hidden while the stored best is 0; otherwise with Z1 | None. State is carried by label and outline only |
| 3 | **Pause button** (Z2) | Circle, 56 dp, pause-bars icon Ink on Rim White 85%; hit area 56 dp | Icon only; accessible name `Pause` | Static | Running only | Press feedback: scale to 0.94 while held, back on release. No other motion |
| 4 | **Resume countdown** (Z4) | Circle pill 96 dp, Lagoon progress ring (4 dp), Ink digit 48 sp centred | `digit` and `progress` from Run State's F5, never from HUD's `dt` | Every tick, pulled | Resuming only | Ring sweeps clockwise with the data; the final partial digit shows the ring alone |
| 5 | **Restart prompt** (Z4) | Circle pill 88 dp with restart icon; Lagoon fill ring fills over `RESTART_LOCK`; label 16 sp below | Locked: icon 50% to 100% opacity as the ring fills. Unlocked: full opacity, label `Tap`. Sensor-dimmed: icon about 45%, label replaced by `Reconnecting…`, `No motion sensor` or `Sensor not ready` | `restart_unlocked`; `valid` and `state` pulled each tick | Hit only. The whole screen is the tap target (view-owned catcher), not just the circle | Fill is continuous and calm. Unlock settles with a ~150 ms brightness ease. Reconnecting adds a small Lagoon pulse; the other two labels have none |
| 6 | **PB banner** (Z3) | Pill, 48 dp high, max 80% width; 20 sp Ink, Lagoon 2 dp underline; Rim White 85% | `NEW BEST` plus `final_score` | Once, on `personal_best_updated` | Hit only; cleared on `run_reset` or a phase change to Menu | Entrance only: ~220 ms ease-out, 12 dp slide down plus fade. No hold animation, no exit animation |
| 7 | **Menu button** (Z5) | Circle, 48 dp, house icon Ink on Rim White 85%, label `Menu` 14 sp below | Icon plus text | Static | Hit with `valid` false; sensor-lost pause | Same press feedback as Pause |
| 8 | **Sensor-lost pause label** (Z4) | Pill, 16 sp Ink, `No motion sensor`; no scrim, the frozen world stays visible | Text only | Static | Paused with source `sensor_lost` | None |

### Data source and priority

Priority decides what yields if a future element ever competes for Z4 or the 4-group cap (1 = never yields).

| # | Element | Data source (owner) | Priority |
|---|---|---|---|
| 1 | Score | `current_score` (Scoring & Personal Best), pull seam | 1 |
| 2 | BEST | `personal_best`, `personal_best_updated`, `personal_best_passed` (Scoring & Personal Best) | 2 |
| 3 | Pause button | `phase` (Run State & Restart) | 1 in Running |
| 4 | Resume countdown | F5 `{remaining, digit, progress}` (Run State & Restart) | 1 in Resuming |
| 5 | Restart prompt | `run_ended`, `restart_unlocked` (Run State), `valid` and `state` (Tilt Input) | 1 in Hit |
| 6 | PB banner | `personal_best_updated` (Scoring & Personal Best) | 3 |
| 7 | Menu button | `valid` (Tilt Input), `phase` (Run State) | 2 |
| 8 | Sensor-lost label | `run_paused(source)` (Run State), `state` (Tilt Input) | 1 in Paused (`sensor_lost`) |

### Visual budget

- At most **4 simultaneous groups** (Philosophy). Worst case is Hit with `valid` false: Z1 readout, Z3 banner, Z4 prompt with label, Z5 Menu.
- At most **12% of the safe-area surface** is covered by HUD pills at any moment, measured on the worst-case state above at H = 640 dp and 360 dp wide. Starting value, unverified; measured in HUD-2.
- The vertical centre band (35% to 55% of H) holds no HUD element except Z4 on short screens (Open Question 3).

### Tuning knobs

None. Placement and size values here are design constants, not player-adjustable and not designer-tuned at runtime (GDD `hud.md` Tuning Knobs: none). Handedness mirroring is the one candidate (Open Question 5).

### Rules shared by every element

- Buttons activate on **release inside the button** (Run State rule). Every hit area is at least 48 dp.
- Meaningful labels are at least 14 sp; state labels are at least 16 sp.
- Colour is limited to Ink, Rim White and Lagoon. No gold, no red, no warm hue (art bible §4 and §7).
- Elements 1 and 2 never carry motion of their own (art bible §7).
- **Score digits are right-aligned** inside the fixed-width pill. At 7 or more digits the value shrinks to fit the pill (never wraps, never widens the pill) down to a floor of 20 sp; Scoring has no cap (Open Question 4).
- **Localization budget:** English labels are the reference. Allow 40% expansion. `Reconnecting…` and `No motion sensor` have a hard limit of 20 characters at 16 sp and wrap to 2 lines in Z4 (centred, the circle does not move); `Sensor not ready` has a limit of 18. Longer translations are shortened, not scaled down below 14 sp. The `BEST` and `NEW BEST` tags have a limit of 10 characters. `Menu` and `Tap` have a limit of 8.

---

## Dynamic Behaviors

**Phase changes are instant** (no fade, no slide), except the two motions defined under HUD Elements: the banner entrance and the restart-prompt unlock settle. Reasons: HUD has a 2 ms reset budget (`hud.md` Core Rule 12), and Pillar 1 wants the new state visible on the tick it begins.

| Transition | What changes (all in the same tick) |
|---|---|
| Menu → Running | Z1 and Z2 appear. Score 0. BEST shown only if the stored best is above 0 |
| Running → Hit | Z2 hides. Z4 shows the restart prompt, locked. Z3 banner enters if `personal_best_updated` fired. Z1 frozen at `final_score` |
| Running → Paused (`button`, `back`, `app_interrupted`) | Z2 hides, Z1 frozen. Nothing else; Menus & Screen Flow's Paused screen takes over |
| Running → Paused (`sensor_lost`) | As above, plus Z4 shows `No motion sensor` and Z5 shows the Menu button |
| Paused (`sensor_lost`): `valid` becomes true | Z4 and Z5 hide in the same tick. Menus & Screen Flow's ordinary Paused screen (Resume gated on `valid`, Restart, Menu) takes over; HUD owns no screen from then on. HUD's latch of the pause source clears when Paused is left, as before |
| Paused (any other source): `valid` changes | No HUD change. Gating Resume on `valid` is Menus & Screen Flow's |
| Paused → Resuming | Z4 shows the countdown |
| Resuming → Running | Z4 hides, Z2 appears |
| Resuming → Paused | Z4 hides |
| Hit → Running (restart) | All Hit elements hide, score back to 0, passed state cleared, banner tween killed, prompt re-locked |
| Hit → Menu | HUD hides entirely; banner cleared |
| `valid` flips while in Hit | Z4 dims or undims and its label changes; Z5 shows or hides. No animation except the Reconnecting pulse |

### Layering and input

- The HUD canvas sits above the world and below Menus & Screen Flow's screens.
- The full-screen tap catcher is enabled only in Hit. The Pause and Menu buttons sit above it and win over it (`mouse_filter`), so a Menu press never also sends a restart.
- Outside Hit, a tap on empty screen sends nothing.

### Simultaneity and interruption

- `personal_best_updated` and `run_ended` in the same tick: the frozen score and the banner update together; the banner entrance never delays the restart prompt.
- App sent to the background while the banner is showing: the banner holds its state and does not replay on return.
- The HUD has no auto-hide timer of any kind.

---

## Platform & Input Variants

- **Platforms:** iOS and Android, **portrait only** (locked, `tilt-input.md` Rule 3). Touch only: no hover, keyboard or gamepad. Mouse-as-touch in the editor is for developer testing only.
- **Safe area:** every offset is measured from Platform Services' `safe_area`, never the raw screen size. It is read again after `app_foregrounded` / `app_returned`, because it can change. iOS cutouts are UNVERIFIED.
- **Aspect ratios:** Z1, Z2 and Z3 are anchored to the top safe edge in dp. Z4 is placed by the formula in the Z4/Z5 vertical budget and Z5 follows Z4, so on 16:9 and 20:9 phones Z5 always ends 96 dp or more above the safe bottom edge.
- **Units:** `dp` and `sp` here are logical UI units, not Godot pixels. One dp equals `screen_dpi / 160` physical pixels (Android definition; iOS pt maps 1:1 to dp). Platform Services supplies `safe_area` and `screen_size` in screen pixels and `viewport_size` in stretch units, so the view converts once at layout time: `viewport_units_per_dp = (viewport_size.x / screen_size.x) × (screen_dpi / 160)`. The dpi source and the project's stretch mode are UNVERIFIED (no `project.godot` yet) and need an ADR before the first UI story. `sp` has the same value as `dp` in the MVP, because OS text scaling is not honoured (see Accessibility).
- **Tablets and foldables:** elements keep their dp size and are not scaled up. The banner is also capped at 360 dp wide. A portrait screen on a natural-landscape device is UNVERIFIED.
- **Android navigation bar:** the bottom 96 dp is kept clear of HUD elements for the gesture bar and the resting thumbs.
- **Multi-touch:** the HUD does not handle multi-touch itself. The rule that a restart press must begin after the lock is Run State's (F3).
- **Refresh rate:** the HUD updates once per tick; no animation depends on the refresh rate.

---

## Accessibility

No `design/accessibility-requirements.md` exists yet, so there is no committed tier. This section uses **WCAG-AA as the working baseline** and logs the gap in Open Questions.

| Area | Requirement |
|---|---|
| Contrast | Ink on Rim White is about 14.5:1 nominal. Over a live backdrop at 85% opacity it must still be at least 7:1, measured on device (AC-22) |
| Touch targets | Every control has a hit area of at least 48 dp, activated on release inside |
| Colour independence | Every state is told apart by shape, opacity or text. Nothing relies on Lagoon versus Ink alone |
| Non-text contrast | Lagoon `#0E6A82` on Rim White `#F4F8FF` is about 5.8:1, above the 3:1 floor for rings and outlines (WCAG 1.4.11). The BEST pill's Lagoon outline sits on its outer edge against the live backdrop, so it is measured on device with AC-22; the `NEW BEST` label carries the state regardless |
| Text size | Labels at least 14 sp, state labels at least 16 sp. OS text scaling is **not** honoured in the MVP, so `sp` equals `dp` (see Units). This is a **deliberate exception** to WCAG 1.4.4 (text resize), logged in Open Questions 6 |
| Motion | Only: banner entrance (~220 ms), the countdown ring (data-driven), the Reconnecting pulse, and the button press scale. No flashing anywhere. `reduced_motion_enabled` is not consumed (`hud.md` Open Question 5) |
| Reduced-motion variant, **specified but not wired** | If the setting is ever wired: the banner appears instantly, the Reconnecting pulse becomes a static ring, and the press scale is removed. The countdown ring keeps sweeping because it shows real time |
| Screen reader | Proposed names, **non-binding until AccessKit on 4.7.2 is verified**: Pause `Pause`; Menu `Menu`; restart surface `Restart, tap anywhere`; the sensor label as an alert. The live score is **not** announced per tick. On Hit announce `Run over. Score N.` and `New best.` when the banner shows; during Resuming announce each whole digit once |
| Single-handed | Pause sits top-right on purpose, away from the grip. Android Back also pauses (Platform Services); iOS has no equivalent, so the button is its only in-app pause |
| Non-visual countdown | The countdown has no non-visual equivalent; that is Run State's (`hud.md` Open Question 9) |

---

## Acceptance Criteria (layout)

Measured on a device matrix of at least: a 16:9 phone (H about 640 dp), a 20:9 phone (H about 900 dp), a phone with a notch or punch-hole, and a tablet in portrait. Evidence in `production/qa/evidence/hud/` (screenshots plus the measured values). Behavior and contrast criteria stay in `design/gdd/hud.md` (AC-1 to AC-22, HUD-2).

- **UX-1** Every control (Pause, Menu) has a hit area of at least 48 dp, measured on screen; the restart tap target is the full screen.
- **UX-2** On every device in the matrix, no HUD element lies outside the safe area, and Z5 ends at least 96 dp above the safe bottom edge.
- **UX-3** The Score pill keeps the same position and width from 0 to 999,999 and across Running, Paused and Hit.
- **UX-4** In the worst-case Hit state (`valid` false, banner shown), at most 4 groups are visible, no two overlap, and the isolated killer hazard is not covered on 10 deaths in a row.
- **UX-5** HUD pills cover no more than 12% of the safe-area surface in that state at H = 640 dp.
- **UX-6** `valid` becoming true during a `sensor_lost` pause hides Z4 and Z5 in the same tick and the ordinary Paused screen shows with Resume enabled.
- **UX-7** Phase changes show no fade; the only motion is the banner entrance (about 220 ms), the unlock settle (about 150 ms), the countdown ring, the Reconnecting pulse and the button press scale.
- **UX-8** With the longest localized strings (40% expansion) no label overflows its slot or drops below 14 sp.

---

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | No `design/player-journey.md`: this spec assumes the player's context (calm at the start, startled in Hit, re-gripping in Resuming). Template at `.claude/docs/templates/player-journey.md` | user, ux-designer | Before `/gate-check pre-production` |
| 2 | No `design/accessibility-requirements.md`: the tier is not committed; WCAG-AA is used as a baseline | user, accessibility-specialist | Before `/gate-check pre-production` |
| 3 | Z3 (banner) and Z4 (status slot) positions assume where the ball and hazards sit on screen; `camera.md` does not fix it. Verify neither covers the isolated killer hazard on death (art bible §3e). On short screens (H = 640 dp) Z4 rises to 62.5% of H, closer to the approach zone | user, art-director | Vertical slice, on device |
| 4 | Maximum score digits: the pill reserves 6 tabular digits. What happens at 7 or more is undefined (Scoring has no cap) | game-designer | Before first-playable |
| 5 | Handedness: pause is top-right only. Mirroring needs a setting owned by Settings & Accessibility | user | Post-MVP, or when playtests show reach problems |
| 6 | AccessKit names, roles and announcements on 4.7.2 are unverified; the screen-reader names are a proposal. OS text scaling is not honoured, a deliberate exception to WCAG 1.4.4 | accessibility-specialist, godot-specialist | Vertical slice |
| 10 | dp to viewport-unit conversion (dpi source, stretch mode) needs an ADR; no `project.godot` yet (Platform & Input Variants, Units) | technical-director, godot-specialist | Before the first UI story |
| 11 | Location of the accessibility requirements file: `design/CLAUDE.md` says `design/ux/accessibility-requirements.md`, this spec and the gate checks say `design/accessibility-requirements.md` | user | Before writing it |
| 7 | All sizes (56 dp pause, 44 dp score, 88 dp prompt, etc.) are starting values; verify touch comfort and the 7:1 contrast on device (`hud.md` AC-22, HUD-2) | user, qa-lead | Vertical slice, on device |
| 8 | The `Sensor not ready` text has no localisation budget: a 40% text expansion could overflow Z4's 16 sp label in longer languages | localization-lead | Before localisation |
| 9 | Accidental restart from a re-grip tap just after the lock (`hud.md` Open Question 10), and an optional hold-to-restart | user, game-designer | First-playable playtest |
