# HUD Design

> **Status**: Drafted, pending `/ux-review`
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
| **Z4 Status slot** | Lower third, horizontally centred, vertical centre at about 78% of safe height, clear of the bottom 96 dp grip band | Restart prompt (with its sensor label), **or** the resume countdown, **or** the sensor-lost pause label. Never two at once | Hit, Resuming, Paused (`sensor_lost`) |
| **Z5 Menu** | Bottom-centre, 24 dp below Z4, outside both thumb corners | Round Menu button | Hit with `valid` false; sensor-lost pause |

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

### Rules shared by every element

- Buttons activate on **release inside the button** (Run State rule). Every hit area is at least 48 dp.
- Meaningful labels are at least 14 sp; state labels are at least 16 sp.
- Colour is limited to Ink, Rim White and Lagoon. No gold, no red, no warm hue (art bible §4 and §7).
- Elements 1 and 2 never carry motion of their own (art bible §7).

---

## Dynamic Behaviors

**Phase changes are instant** (no fade, no slide), except the two motions defined under HUD Elements: the banner entrance and the restart-prompt unlock settle. Reasons: HUD has a 2 ms reset budget (`hud.md` Core Rule 12), and Pillar 1 wants the new state visible on the tick it begins.

| Transition | What changes (all in the same tick) |
|---|---|
| Menu → Running | Z1 and Z2 appear. Score 0. BEST shown only if the stored best is above 0 |
| Running → Hit | Z2 hides. Z4 shows the restart prompt, locked. Z3 banner enters if `personal_best_updated` fired. Z1 frozen at `final_score` |
| Running → Paused (`button`, `back`, `app_interrupted`) | Z2 hides, Z1 frozen. Nothing else; Menus & Screen Flow's Paused screen takes over |
| Running → Paused (`sensor_lost`) | As above, plus Z4 shows `No motion sensor` and Z5 shows the Menu button |
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
- **Aspect ratios:** Z1, Z2 and Z3 are anchored to the top safe edge in dp. Z4 is anchored by proportion (78% of safe height) and Z5 follows Z4, so on 20:9 and 16:9 phones both stay in the lower third.
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
| Text size | Labels at least 14 sp, state labels at least 16 sp. OS text scaling is **not** honoured in the MVP (fixed sp) |
| Motion | Only: banner entrance (~220 ms), the countdown ring (data-driven), the Reconnecting pulse, and the button press scale. No flashing anywhere. `reduced_motion_enabled` is not consumed (`hud.md` Open Question 5) |
| Reduced-motion variant, **specified but not wired** | If the setting is ever wired: the banner appears instantly, the Reconnecting pulse becomes a static ring, and the press scale is removed. The countdown ring keeps sweeping because it shows real time |
| Screen reader | Proposed names, **non-binding until AccessKit on 4.7.2 is verified**: Pause `Pause`; Menu `Menu`; restart surface `Restart, tap anywhere`; the sensor label as an alert. The live score is **not** announced per tick. On Hit announce `Run over. Score N.` and `New best.` when the banner shows; during Resuming announce each whole digit once |
| Single-handed | Pause sits top-right on purpose, away from the grip. Android Back also pauses (Platform Services); iOS has no equivalent, so the button is its only in-app pause |
| Non-visual countdown | The countdown has no non-visual equivalent; that is Run State's (`hud.md` Open Question 9) |

---

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | No `design/player-journey.md`: this spec assumes the player's context (calm at the start, startled in Hit, re-gripping in Resuming). Template at `.claude/docs/templates/player-journey.md` | user, ux-designer | Before `/gate-check pre-production` |
| 2 | No `design/accessibility-requirements.md`: the tier is not committed; WCAG-AA is used as a baseline | user, accessibility-specialist | Before `/gate-check pre-production` |
| 3 | Z3 (banner) and Z4 (status slot) positions assume where the ball and hazards sit on screen; `camera.md` does not fix it. Verify neither covers the isolated killer hazard on death (art bible §3e) | user, art-director | Vertical slice, on device |
| 4 | Maximum score digits: the pill reserves 6 tabular digits. What happens at 7 or more is undefined (Scoring has no cap) | game-designer | Before first-playable |
| 5 | Handedness: pause is top-right only. Mirroring needs a setting owned by Settings & Accessibility | user | Post-MVP, or when playtests show reach problems |
| 6 | AccessKit names, roles and announcements on 4.7.2 are unverified; the screen-reader names are a proposal. OS text scaling is not honoured | accessibility-specialist, godot-specialist | Vertical slice |
| 7 | All sizes (56 dp pause, 44 dp score, 88 dp prompt, etc.) are starting values; verify touch comfort and the 7:1 contrast on device (`hud.md` AC-22, HUD-2) | user, qa-lead | Vertical slice, on device |
| 8 | The `Sensor not ready` text has no localisation budget: a 40% text expansion could overflow Z4's 16 sp label in longer languages | localization-lead | Before localisation |
| 9 | Accidental restart from a re-grip tap just after the lock (`hud.md` Open Question 10), and an optional hold-to-restart | user, game-designer | First-playable playtest |
