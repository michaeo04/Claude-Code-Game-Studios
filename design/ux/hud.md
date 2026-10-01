# HUD Design

> **Status**: **Approved by the user 2026-10-01** (no sixth `/ux-review` run; remaining open items are in Open Questions). History: revised after a fifth `/ux-review` 2026-10-01 (NEEDS REVISION: 1 blocking and 7 advisory items addressed: Menu readying during `PAUSE_INPUT_GUARD` in the sensor-lost pause, pill-outline pulse for #8, Menus transition cut layering, Paused screen vs Z1 handoff, minimum supported size, performance and resolution criteria, Pattern Library deviation note)
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

Everything the GDDs ask the HUD to communicate. Almost all of it comes from `design/gdd/hud.md`; Juice & Feedback, Camera, Tilt Input and Scoring add no UI requirement beyond what HUD already owns. Menus & Screen Flow and Settings & Accessibility own their own screens (no HUD element); Menus' Paused screen and transition cut interact with the HUD layer (Layering and input, Open Question 12).

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
| **Z1 Readout** | Top-left, 16 dp from the left safe edge, 8 dp below the top safe edge. The stack is 84 dp high (44 + 8 + 32), 170 dp wide (Score pill 130 dp, BEST pill 170 dp, both left-aligned) | Score pill; BEST pill stacked under it (8 dp gap) | Running, Paused, Resuming (frozen), Hit |
| **Z2 Pause** | Top-right, **40 dp from the right safe edge and 16 dp below the top safe edge** (larger than Z1's insets, see Gesture-edge rule) | Pause button | Running only |
| **Z3 Banner** | Top-centre, 12 dp below the bottom of the Z1 stack (so its top is at 8 + 84 + 12 = 104 dp from the top safe edge), centred, at most 80% of safe width and 360 dp | Personal-best banner | Hit only |
| **Z4 Status slot** | Horizontally centred; vertical centre of the **reserved group** at `min(0.70 × H, H − 264 dp)`, where H is the safe-area height (see Z4/Z5 budget below). The reserved group is 148 dp high: 88 dp circle, 8 dp gap, label pill reserved for 2 lines (52 dp). Contents are **top-anchored** to the group, so nothing moves when the label pill grows | Restart prompt (with its sensor label pill), **or** the resume countdown, **or** the sensor-lost pause label pill. Never two at once | Hit, Resuming, Paused (`sensor_lost`) |
| **Z5 Menu** | Bottom-centre, 16 dp below the bottom of the reserved Z4 group; 78 dp high (48 dp button, 4 dp gap, 26 dp label pill); outside both thumb corners | Round Menu button with its label pill | Hit with `valid` false; sensor-lost pause |

Z4 anchoring: the restart circle's centre sits 44 dp below the Z4 top. The countdown circle (96 dp) is centred on the same point, so it extends 4 dp above the Z4 top and 4 dp below the circle row; this overhang is inside the reserved group's slack and the budget table below is unaffected (nothing else sits within 4 dp of it). The sensor-lost pause shows only the label pill, vertically centred on that same point.

### Gesture-edge rule (Z2)

`platform-services.md` UI Requirements 3 asks HUD to keep touch targets, the pause button in particular, away from the system gesture edges. Android gesture navigation reserves a back-swipe strip along the left and right edges (about 24 dp by default, up to about 40 dp at the highest user sensitivity), the top edge opens the notification shade, and the bottom edge is the gesture bar. Therefore:

1. Z2's hit area starts at least **40 dp** from the right safe edge and at least **16 dp** below the top safe edge (the 56 dp button spans 40 to 96 dp from the right edge).
2. No interactive element sits within 40 dp of the left or right safe edge. Z1 (non-interactive) is exempt and keeps its 16 dp inset. Z4's full-screen tap catcher is exempt (a swallowed edge swipe costs nothing).
3. The bottom 96 dp clear band (see the Z4/Z5 budget) covers the home indicator and gesture bar.
4. The 40 dp / 16 dp values are starting values: Platform Services supplies no system-gesture insets, so they are verified on device (UX-12) and the real insets are requested from Platform Services if they fall short (Open Question 11).

### Z4/Z5 vertical budget

The bottom 96 dp of the safe area stays empty (gesture bar, resting thumbs). Z5 must end at least 96 dp above the safe bottom edge on every screen. The budget is computed for the **worst case**: the label pill grown to 2 lines (primary label plus `Sensor not ready`). Z4's group centre is therefore `min(0.70 × H, H − 264 dp)`: 264 = 96 (clear band) + 78 (Z5) + 16 (gap) + 74 (half of the 148 dp reserved group). Labels never wrap: the pill is up to 280 dp wide, one line per label (see Localization).

| H (dp) | Z4 group centre | Z4 span | Z5 span | Z5 bottom to safe bottom |
|---|---|---|---|---|
| 640 (16:9) | 376 (58.8%) | 302 to 450 | 466 to 544 | 96 |
| 800 | 536 (67%) | 462 to 610 | 626 to 704 | 96 |
| 900 (20:9) | 630 (70%) | 556 to 704 | 720 to 798 | 102 |

On short screens Z4 rises toward the approach zone (the Z4 top is at 47% of H at H = 640, so the circle sits partly inside the 35% to 55% centre band); checked on device (Open Question 3). The earlier "lower third" wording is dropped.

### Layout rules

0. **Deviation noted:** `hud.md` Rule 2 says "the pill is right-anchored". Z1 is anchored top-left; the intent (no width change on rollover) is met by the fixed 130 dp width with right-aligned digits. `Tap` (restart label when unlocked and `valid` true) is a new string introduced here, covered by the 8-character limit.
1. **Z1 never moves between phases.** The score pill has a fixed width reserved for 6 tabular digits, so it does not change width on rollover (`hud.md` Core Rule 2).
2. **The centre and both lower corners are empty** except where Z4 and Z5 are showing. The centre is the approach zone (art bible §3e) and the lower corners are where the thumbs rest.
3. **Z4 is shared** by three contents that never occur in the same phase, so the player always looks in one place to learn what the system is saying.
4. **Menu sits bottom-centre, not bottom-left**, because the lower corners are the resting grip and an accidental tap there would abandon to Menu.
5. **No handedness mirroring in the MVP** (pause is top-right by default); see Open Questions.
6. **UNVERIFIED placement:** Z3 and Z4 assume where the ball and hazards sit on screen. `camera.md` does not fix that, so both are checked on a real device in the vertical slice (Open Questions).

---

## HUD Elements

All sizes are **starting values, unverified on device** (measured at AC-22 and HUD-2). Touch targets follow the floor `design/gdd/hud.md` recommends: 48 dp (Android).

| # | Element (zone) | Form and size | Content | Update | Trigger | Animation |
|---|---|---|---|---|---|---|
| 1 | **Score** (Z1) | Pill, 44 dp high, 130 dp wide (6 tabular digits at about 17 dp each plus 14 dp padding per side); bold 28 sp Ink on Rim White 85% | `current_score`, no unit | Every tick, exact, from the pull seam | Running; frozen in Paused, Resuming and Hit | **None.** No smoothing, pulse or colour shift (`hud.md` Rule 2) |
| 2 | **BEST** (Z1) | Pill, 32 dp high, **170 dp wide** (wider than Score: it must hold the longest tag plus a 6-digit value, about 70 + 6 + 65 + 28 = 169 dp, using the same 0.6 em tabular-digit estimate as Score); 18 sp Ink, tag `BEST` at 14 sp. Value right-aligned, tag left-aligned. **7 or more digits** shrink the value (never the tag, never the pill) down to a 14 sp floor, which fits about 7 digits beside `NEW BEST`; beyond that is Open Question 4 | Stored best. In the passed state the tag becomes `NEW BEST`, the value tracks the live score, and a Lagoon 2 dp outline appears | Static; changes on `personal_best_updated`; passed state on `personal_best_passed` | Hidden while the stored best is 0; otherwise with Z1 | None. State is carried by label and outline only |
| 3 | **Pause button** (Z2) | Circle, 56 dp, pause-bars icon Ink on Rim White 85%; hit area 56 dp | Icon only; accessible name `Pause` | Static | Running only | Press feedback: scale to 0.94 while held, back on release. No other motion |
| 4 | **Resume countdown** (Z4) | Circle pill 96 dp, Lagoon progress ring (4 dp), Ink digit 48 sp centred | `digit` and `progress` from Run State's F5, never from HUD's `dt` | Every tick, pulled | Resuming only | Ring sweeps clockwise with the data; the final partial digit shows the ring alone |
| 5 | **Restart prompt** (Z4) | Circle pill 88 dp with restart icon; Lagoon fill ring fills over `RESTART_LOCK`; **label pill** below (Rim White 85%, 16 sp Ink, 28 dp high for one line, see Sensor label rules) | Locked: icon 60% to 100% opacity as the ring fills (60% keeps the icon at about 4:1 on the pill; the GDD's "about 50%" is approximate). Unlocked: full opacity, label `Tap`. Sensor-dimmed (`valid` false): icon about 45% (inactive, exempt from the 3:1 non-text floor), label per Sensor label rules | `restart_unlocked`; `valid` and `state` pulled each tick | Hit only. The whole screen is the tap target (view-owned catcher), not just the circle | Fill is continuous and calm. Unlock settles with a ~150 ms brightness ease. Reconnecting adds a Lagoon ring pulse of 1.2 s period (at most 1 Hz, no flashing); `No motion sensor` and `Sensor not ready` have none |
| 6 | **PB banner** (Z3) | Pill, 48 dp high, max 80% width; 20 sp Ink, Lagoon 2 dp underline; Rim White 85% | `NEW BEST` plus `final_score` | Once, on `personal_best_updated` | Hit only; cleared on `run_reset` or a phase change to Menu | Entrance only: ~220 ms ease-out, 12 dp slide down plus fade. No hold animation, no exit animation |
| 7 | **Menu button** (Z5) | Circle, 48 dp, house icon Ink on Rim White 85%; label `Menu` 14 sp in its own Rim White 85% pill (26 dp high) below | Icon plus text | Pulled `phase`; `restart_unlocked` | Hit with `valid` false; sensor-lost pause | **In Hit, locked state:** shown at about 50% opacity with no press feedback until `restart_unlocked` (Run State rejects an earlier `menu_requested`, so the button looks and behaves inactive instead of eating taps); then full opacity and the same press feedback as Pause. **In the sensor-lost pause, readying:** Run State ignores `menu_requested` for `PAUSE_INPUT_GUARD` after every entry to Paused (F3; the guard starts over on each entry, including `Resuming → Paused`). For that window the button shows the same calm readying as Menus & Screen Flow's Restart/Menu (`menus-screen-flow.md` Core Rule 3): a Lagoon ring fills around the 48 dp button and the icon rises from about 60% and the label from 65% to 100% opacity (interaction-patterns P11), with no press feedback change. The fill is cosmetic: a tap in the window is forwarded as usual and Run State rejects it (no HUD-side gate, same as Menus). The timer is view-owned, starts at the phase change into Paused and uses the injected `PAUSE_INPUT_GUARD` value (HUD owns no constant for it) |
| 8 | **Sensor-lost pause label** (Z4) | The same label pill as #5 (16 sp Ink on Rim White 85%), centred on the Z4 circle-centre line; no scrim, the frozen world stays visible | Primary label per Sensor label rules (never the secondary line: no tap is swallowed in this pause) | `state` pulled each tick | Paused with source `sensor_lost` while `valid` is false | Reconnecting: the pill's Lagoon 2 dp outline pulses (1.2 s period, at most 1 Hz, no flashing); the outline is absent otherwise. `No motion sensor` has no pulse |

### Sensor label rules (Z4, elements 5 and 8)

One label pill, two possible lines. Rules, all re-derived each tick from `valid` and `state` (`hud.md` Core Rules 6-8, AC-9, AC-10):

1. **Primary line** (shown whenever `valid` is false in Hit or in the `sensor_lost` pause): `state` Acquiring gives `Reconnecting…`; Unavailable gives `No motion sensor`; defensively, `valid` false with HUD's "was Live" latch unset gives `No motion sensor`. The primary line follows `state` live, including when it changes while the secondary line is showing.
2. **Secondary line** `Sensor not ready` (Hit only): added **under** the primary line on the first swallowed tap and kept until `valid` returns, `run_reset`, or the phase leaves Hit. It never replaces the primary line, so the player never loses which of the two sensor states applies.
3. **Growth:** the pill is 28 dp high with one line and grows **downward** to 52 dp when the secondary line appears. Z4's circle and Z5 do not move (the budget reserves the 2-line height).
4. **With `valid` true:** locked shows the circle only (no pill); unlocked shows the pill with `Tap`.
5. No label wraps (see Localization): one line each, 16 sp, pill at most 280 dp wide.

**Restart circle states (valid × lock).** The art bible (§7) wants "still arming" and "genuinely disabled" to read differently. The label pill is the discriminator; opacity alone is not relied on, because the icon opacities are close (60% start versus 45%).

| `valid` | Lock | Icon opacity | Lagoon ring | Label pill |
|---|---|---|---|---|
| true | locked | 60% rising to 100% | fills over `RESTART_LOCK` | none |
| true | unlocked | 100% | full | `Tap` |
| false | locked | 45%, fixed | fills over `RESTART_LOCK` | primary line (plus secondary after a swallowed tap) |
| false | unlocked | 45%, fixed | full | primary line (plus secondary after a swallowed tap) |

A circle with no pill is therefore always "arming and working"; a circle with a sensor pill is always "not usable". The device walkthrough (HUD-2) checks that testers read the two correctly (Open Question 7).

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
| 7 | Menu button | `valid` (Tilt Input), `phase` and `restart_unlocked` (Run State) | 2 |
| 8 | Sensor-lost label | `run_paused(source)` (Run State), `state` (Tilt Input) | 1 in Paused (`sensor_lost`) |

### Visual budget

- At most **4 simultaneous groups** (Philosophy). Worst case is Hit with `valid` false: Z1 readout, Z3 banner, Z4 prompt with label, Z5 Menu.
- At most **17% of the safe-area surface** is covered by HUD pills at any moment, measured on the worst-case state above (Hit, `valid` false, banner shown, after a swallowed tap) at H = 640 dp and 360 dp wide (230,400 dp²). Starting value, unverified; measured in HUD-2. Arithmetic for that state (English reference strings): Score 130×44 = 5,720; BEST 170×32 = 5,440; banner about 205×48 = 9,840; restart circle 88 dp ≈ 6,080; 2-line label pill about 160×52 = 8,320; Menu circle ≈ 1,810; Menu label pill about 50×26 = 1,300. Total ≈ 38,500 dp², about 16.7%. The earlier 12% figure did not survive this arithmetic; it was a guess made before the label pills and sizes existed. The margin to 17% is thin on purpose: it is a paper estimate to be replaced by the on-device measurement.
- **Localized worst case:** with every limit reached at once: both label lines at 24 characters (pill about 228×52 = 11,856, +3,536), the banner tag at 14 characters plus 6 digits (about 277×48 = 13,296, +3,456) and an 8-character Menu label (about 84×26 = 2,184, +884), the total is about 46,400 dp², about 20.1%. The hard ceiling for that case is **21%** (UX-8). An earlier 18.3% figure counted only the label pill. The 17% budget applies to the English reference strings only.
- The vertical centre band (35% to 55% of H) holds no HUD element except Z4 on short screens (Open Question 3).

### Tuning knobs

None. Placement and size values here are design constants, not player-adjustable and not designer-tuned at runtime (GDD `hud.md` Tuning Knobs: none). Handedness mirroring is the one candidate (Open Question 5).

### Rules shared by every element

- Buttons activate on **release inside the button** (Run State rule). Every hit area is at least 48 dp.
- Meaningful labels are at least 14 sp; state labels are at least 16 sp.
- Colour is limited to Ink, Rim White and Lagoon. No gold, no red, no warm hue (art bible §4 and §7).
- Elements 1 and 2 never carry motion of their own (art bible §7).
- **Score digits are right-aligned** inside the fixed-width pill. At 7 or more digits the value shrinks to fit the pill (never wraps, never widens the pill) down to a floor of 20 sp; Scoring has no cap (Open Question 4).
- **Localization budget:** English labels are the reference. Allow 40% expansion. **Labels never wrap.** `Reconnecting…`, `No motion sensor` and `Sensor not ready` each have a hard limit of 24 characters at 16 sp (about 204 dp plus 24 dp padding, inside the 280 dp pill cap). Longer translations are shortened, not scaled down below 14 sp. The `BEST` and `NEW BEST` tags have a limit of 10 characters. `Menu` and `Tap` have a limit of 8. The banner text (`NEW BEST` plus score) has a limit of 14 characters for the tag text at 20 sp, plus the digits, inside the 360 dp cap.

---

## Dynamic Behaviors

**Phase changes are instant** (no fade, no slide), except the two motions defined under HUD Elements: the banner entrance and the restart-prompt unlock settle. Reasons: HUD has a 2 ms reset budget (`hud.md` Core Rule 12), and Pillar 1 wants the new state visible on the tick it begins.

| Transition | What changes (all in the same tick) |
|---|---|
| Menu → Running | Z1 and Z2 appear. Score 0. BEST shown only if the stored best is above 0 |
| Running → Hit | Z2 hides. Z4 shows the restart prompt, locked. Z3 banner enters if `personal_best_updated` fired. Z1 frozen at `final_score` |
| Running → Paused (`button`, `back`, `app_interrupted`) | Z2 hides, Z1 frozen. Nothing else; Menus & Screen Flow's Paused screen takes over |
| Running → Paused (`sensor_lost`) | As above, plus Z4 shows the label pill (primary line per Sensor label rules: `No motion sensor`, or `Reconnecting…` if `state` is Acquiring) and Z5 shows the Menu button in its readying state (Element #7), which completes after `PAUSE_INPUT_GUARD` |
| Paused (`sensor_lost`): `valid` becomes true | Z4 and Z5 hide in the same tick. Menus & Screen Flow's ordinary Paused screen (Resume and Restart gated on `valid` and the sensor source, Menu ungated) takes over; HUD owns no screen from then on. HUD's latch of the pause source clears when Paused is left, as before |
| Paused (any other source): `valid` changes | No HUD change. Gating Resume on `valid` is Menus & Screen Flow's |
| Paused → Resuming | Z4 shows the countdown; Z1 stays visible, frozen |
| Resuming → Running | Z4 hides, Z2 appears |
| Resuming → Paused (`back`, `app_interrupted`; `button` cannot occur, the Pause button is hidden in Resuming) | Z4 hides, countdown discarded (Run State). Z1 stays frozen |
| Resuming → Paused (`sensor_lost`) | Z4 swaps from the countdown to the label pill (primary line per Sensor label rules) and Z5 shows the Menu button, in its readying state (the guard starts over on this entry), in the same tick. From here it behaves as the Running → Paused (`sensor_lost`) case (Run State AC-29) |
| Paused (any source) → Menu | HUD hides entirely: Z1, Z4, Z5 and any banner are cleared (`hud.md` Rule 3). The Menu button of the sensor-lost pause lands here |
| Paused → Running (restart from the ordinary Paused screen) | `run_reset` semantics as for Hit → Running: score back to 0, passed state cleared, banner cleared, Z2 appears |
| Hit → Running (restart) | All Hit elements hide, score back to 0, passed state cleared, banner tween killed, prompt re-locked |
| Hit → Menu | HUD hides entirely; banner cleared |
| Android Back pressed (`back_pressed`: Platform Services' adapter pauses in Running and Resuming; Menus & Screen Flow Rule 5 routes it in the other phases) | Running: pauses (Platform Services adapter). **Hit: goes to Menu, not gated on `valid`**; Run State still rejects it before the lock, so nothing happens until `restart_unlocked`. **Sensor-lost pause with `valid` false: sends nothing** (Back mirrors Resume's `valid` gate), so the Menu button is the only way out there. Resuming: pauses and the countdown is discarded (Run State AC-23; the Z4 and Z5 result follows the pause source, see the Resuming → Paused rows). HUD sends nothing for Back itself; it only reacts to the resulting `phase` change |
| `valid` flips while in Hit | Z4 dims or undims and its label pill follows the Sensor label rules; Z5 shows or hides (shown dimmed until `restart_unlocked`). No animation except the Reconnecting pulse |
| `restart_unlocked` while `valid` is false | The restart circle finishes its fill and the Menu button goes from about 50% to full opacity, with press feedback enabled |

### Missing or unavailable data

| Data | If unavailable | What shows |
|---|---|---|
| `current_score` (pull seam) | Not yet readable at the first tick, or the seam returns null | The last shown value; `0` before any value exists. Never blank, never a placeholder glyph |
| `personal_best` | Not readable at construction, or stored 0 | BEST pill hidden (same as "no best yet") |
| Resume F5 `{remaining, digit, progress}` | Row missing on a Resuming tick | Keep the previous digit and ring for that tick; no HUD-side estimate (`hud.md` Rule 5) |
| `valid` / `state` | Seam unavailable | Treated as `valid` false with the "No motion sensor" primary line in Hit and in the sensor-lost pause, nothing in other phases |
| `safe_area` | Empty rectangle (desktop, no cutout information) | Platform Services returns the full screen rectangle in pixels; the layout uses it as is |
| `viewport_size` or `screen_dpi` | Zero or missing | Layout falls back to `viewport_units_per_dp = 1` and logs once (Open Question 9) |

### Layering and input

- The HUD canvas sits above the world and below Menus & Screen Flow's screens.
- **Menu↔Running cut:** Menus & Screen Flow Core Rule 9 covers the Menu→Running and Running→Menu seam with a brief Ink cut (about 150 to 250 ms). The cut layer sits **above** the HUD canvas, so Z1 and Z2 appear (Menu→Running) or are cleared (Running→Menu) under it, in the same tick as the phase change, and the cut fade is the only fade the player sees. HUD itself adds none.
- The full-screen tap catcher is enabled only in Hit. The Pause and Menu buttons sit above it and win over it (`mouse_filter`), so a Menu press never also sends a restart.
- The Menu button's hit area includes its label pill (one 48 dp-wide-or-more target). The inactive Menu (Hit, before `restart_unlocked`) **consumes** the tap: it sends nothing, does not fall through to the catcher and never shows `Sensor not ready`.
- Outside Hit, a tap on empty screen sends nothing.

### Simultaneity and interruption

- `personal_best_updated` and `run_ended` in the same tick: the frozen score and the banner update together; the banner entrance never delays the restart prompt.
- App sent to the background while the banner is showing: the banner holds its state and does not replay on return.
- The HUD has no auto-hide timer of any kind.

---

## Platform & Input Variants

- **Platforms:** Android only (user decision 2026-10-01), **portrait only** (locked, `tilt-input.md` Rule 3). Touch only: no hover, keyboard or gamepad. Mouse-as-touch in the editor is for developer testing only.
- **Safe area:** every offset is measured from Platform Services' `safe_area`, never the raw screen size. It is read again after `app_foregrounded` / `app_returned`, because it can change. Android cutouts and system gesture insets are UNVERIFIED (device check PS-8).
- **Minimum supported size:** a safe area of **360 dp wide by 560 dp high**. The localized banner (about 277 dp) needs a safe width of at least 346 dp under the 80% cap, and Z3 and Z4 would overlap below about 490 dp of height (Z3 ends at 152 dp, the Z4 top is at H − 338 dp). Smaller windows (split-screen, small or foldable cover screens) are UNVERIFIED and not a release target in the MVP.
- **Aspect ratios:** Z1, Z2 and Z3 are anchored to the top safe edge in dp. Z4 is placed by the formula in the Z4/Z5 vertical budget and Z5 follows Z4, so on 16:9 and 20:9 phones Z5 always ends 96 dp or more above the safe bottom edge.
- **Units:** `dp` and `sp` here are logical UI units, not Godot pixels. One dp equals `screen_dpi / 160` physical pixels (Android definition). Platform Services supplies `safe_area` and `screen_size` in screen pixels and `viewport_size` in stretch units, so the view converts once at layout time: `viewport_units_per_dp = (viewport_size.x / screen_size.x) × (screen_dpi / 160)`. The dpi source and the project's stretch mode are UNVERIFIED (no `project.godot` yet) and need an ADR before the first UI story. `sp` has the same value as `dp` in the MVP, because OS text scaling is not honoured (see Accessibility).
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
| Motion | Only: banner entrance (~220 ms), the countdown ring (data-driven), the Reconnecting pulse (1.2 s period, at most 1 Hz, so far under the 3 flashes per second limit of WCAG 2.3.1), and the button press scale. No flashing anywhere. `reduced_motion_enabled` is not consumed (`hud.md` Open Question 5) |
| Reduced-motion variant, **specified but not wired** | If the setting is ever wired: the banner appears instantly, the Reconnecting pulse becomes a static ring, and the press scale is removed. The countdown ring keeps sweeping because it shows real time |
| Screen reader | Proposed names, **non-binding until AccessKit on 4.7.2 is verified**: Pause `Pause`; Menu `Menu`; restart surface `Restart, tap anywhere`; the sensor label as an alert. The live score is **not** announced per tick. On Hit announce `Run over. Score N.` and `New best.` when the banner shows; during Resuming announce each whole digit once |
| Reading order (screen reader, proposed, same AccessKit caveat) | Running: Score, BEST, Pause. Hit: the `Run over. Score N.` announcement, banner (if shown), restart surface, label pill, Menu (if shown). Sensor-lost pause: label pill, Menu. Resuming: Score, BEST, then the countdown digits |
| Single-handed | Pause sits top-right on purpose, away from the grip, and inset 40 dp from the right edge to stay out of the system gesture strip (Gesture-edge rule). Android Back also pauses in Running (Platform Services), so the button is the second way to pause. Back behavior elsewhere: see Dynamic Behaviors |
| Non-visual countdown | The countdown has no non-visual equivalent; that is Run State's (`hud.md` Open Question 9) |

---

## Acceptance Criteria (layout)

Measured on a device matrix of at least: a 16:9 phone (H about 640 dp), a 20:9 phone (H about 900 dp), a phone with a notch or punch-hole, and a tablet in portrait. Evidence in `production/qa/evidence/hud/` (screenshots plus the measured values). Behavior and contrast criteria stay in `design/gdd/hud.md` (AC-1 to AC-22, HUD-2).

- **UX-1** Every control (Pause, Menu) has a hit area of at least 48 dp, measured on screen; the restart tap target is the full screen.
- **UX-2** On every device in the matrix, no HUD element lies outside the safe area, and Z5 ends at least 96 dp above the safe bottom edge.
- **UX-3** The Score pill keeps the same position and width (130 dp) from 0 to 999,999 and across Running, Paused, Resuming and Hit. The BEST pill keeps its 170 dp width and never clips or overflows in the `NEW BEST` state with a 6-digit value, and shrinks (not widens) at 7 or more digits.
- **UX-4** In the worst-case Hit state (`valid` false, banner shown), at most 4 groups are visible, no two overlap, and the isolated killer hazard is not covered on 10 deaths in a row.
- **UX-5** HUD pills cover no more than 17% of the safe-area surface in that state at H = 640 dp with the English reference strings (paper estimate 16.7%, see Visual budget).
- **UX-6** `valid` becoming true during a `sensor_lost` pause hides Z4 and Z5 in the same tick and the ordinary Paused screen shows with Resume enabled.
- **UX-7** Phase changes show no HUD fade and every state change is visible on the tick it begins (the Menus & Screen Flow Ink cut over the Menu↔Running seam is the only fade, and sits above the HUD); the only HUD motion is the banner entrance (about 220 ms), the unlock settle (about 150 ms), the countdown ring, the Reconnecting pulse and the button press scale.
- **UX-8** With the longest localized strings (40% expansion, up to the 24-character label limit) no label wraps, overflows its pill or drops below 14 sp, and Z4 and Z5 do not move or overlap. In that localized worst case HUD pills cover no more than 21% of the safe-area surface at H = 640 dp.
- **UX-9** Layering: a press on the Menu button in Hit (with `valid` false) sends `menu_requested` exactly once, sends no `restart_requested`, **and does not make the secondary line `Sensor not ready` appear** (spy on both sinks and watch the label, on device, 10 presses, including 10 presses on the Menu label pill and 10 before `restart_unlocked`). The label check is the observable one: with `valid` false the catcher never forwards a restart anyway, so the sink spy alone cannot detect a fall-through to the catcher.
- **UX-10** Sensor label: in Hit with `valid` false and `state` Acquiring, the pill shows `Reconnecting…`; after one tap it shows `Reconnecting…` plus `Sensor not ready` under it; when `state` becomes Unavailable the primary line changes to `No motion sensor` and the secondary line stays; `valid` true clears both. In the `sensor_lost` pause the primary line follows `state` and no secondary line ever appears.
- **UX-11** Menu button in Hit with `valid` false: at about 50% opacity with no press feedback before `restart_unlocked`, full opacity with feedback after; a press before the unlock sends nothing.
- **UX-12** Gesture edges: on an Android phone with gesture navigation (highest back-gesture sensitivity) and on an Android phone with a camera cutout, the Pause button activates on 10 of 10 presses in Running, and no press triggers the system back gesture, or the notification shade. Z2's hit area is at least 40 dp from the right safe edge and 16 dp below the top safe edge, measured on screen.
- **UX-14** Sensor loss during Resuming: the countdown is replaced by the label pill and the Menu button (in its readying state) in the same tick, with the primary line following `state`; Android Back during Resuming pauses with the countdown discarded, Z4 hidden and no Menu button; Paused → Menu clears Z1, Z4, Z5 and the banner. (Run State AC-29 and AC-23 are the upstream behavior, restated here so this criterion stands alone.)
- **UX-15** Menu readying in the sensor-lost pause: the Lagoon ring fills over `PAUSE_INPUT_GUARD` (0.3 s default) from each entry to Paused, including `Resuming → Paused`, with icon rising from about 60% and label from 65% to 100%; a tap inside the window is forwarded (spy on the sink) and Run State rejects it, so the player is not left in the Menu by it; a tap after the window sends `menu_requested` once and the phase becomes Menu. The Reconnecting outline pulse on the label pill is at most 1 Hz.
- **UX-16** Performance, on a mid-tier Android device, worst-case Hit state (`valid` false, banner shown): the HUD adds at most 20 draw calls and at most 1.0 ms of frame time per tick (starting values, replaced by measurement; the project budget is 150 draw calls and 16.6 ms), and the 85% pills cost no dropped frame at 60 FPS over 60 s.
- **UX-17** Resolution: screenshots with measured offsets at 360×640, 360×800 and 412×915 dp, at the minimum supported size 360×560 dp, on a notched phone and on a tablet in portrait, stored in `production/qa/evidence/hud/`.
- **UX-13** Restart circle states: for each row of the valid × lock table, the circle matches its icon opacity, ring and pill; in the HUD-2 walkthrough testers tell "arming" (no pill) from "not usable" (sensor pill) without prompting.

---

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | No `design/player-journey.md`: this spec assumes the player's context (calm at the start, startled in Hit, re-gripping in Resuming). Template at `.claude/docs/templates/player-journey.md` | user, ux-designer | Before `/gate-check pre-production` |
| 2 | No `design/accessibility-requirements.md`: the tier is not committed; WCAG-AA is used as a baseline | user, accessibility-specialist | Before `/gate-check pre-production` |
| 3 | Z3 (banner) and Z4 (status slot) positions assume where the ball and hazards sit on screen; `camera.md` does not fix it. Verify neither covers the isolated killer hazard on death (art bible §3e). On short screens (H = 640 dp) the reserved Z4 group spans 47% to 70% of H, closer to the approach zone | user, art-director | Vertical slice, on device |
| 4 | Score digits: 7 or more digits shrink to a 20 sp floor (Layout rules), which fits about 8 digits in the 130 dp pill. Beyond 8 digits is undefined, and the BEST pill (14 sp floor) already overflows at 8 digits while Score still fits, so the two floors need aligning; Scoring has no cap; a cap or an abbreviation would conflict with "the number is always honest" | game-designer | Before first-playable |
| 5 | Handedness: pause is top-right only. Mirroring needs a setting owned by Settings & Accessibility | user | Post-MVP, or when playtests show reach problems |
| 6 | AccessKit names, roles and announcements on 4.7.2 are unverified; the screen-reader names are a proposal. OS text scaling is not honoured, a deliberate exception to WCAG 1.4.4 | accessibility-specialist, godot-specialist | Vertical slice |
| 7 | All sizes (56 dp pause, 44 dp score, 88 dp prompt, 130 dp score pill, etc.) and the 17% coverage budget are starting values; verify touch comfort, coverage and the 7:1 contrast on device (`hud.md` AC-22, HUD-2) | user, qa-lead | Vertical slice, on device |
| 8 | Accidental restart from a re-grip tap just after the lock (`hud.md` Open Question 10), and an optional hold-to-restart | user, game-designer | First-playable playtest |
| 9 | dp to viewport-unit conversion (dpi source, stretch mode) needs an ADR; no `project.godot` yet (Platform & Input Variants, Units) | technical-director, godot-specialist | Before the first UI story |
| 10 | RESOLVED 2026-10-01: the accessibility requirements file lives at `design/accessibility-requirements.md` (the path the skills and gate checks read); `design/CLAUDE.md` corrected to match | — | Resolved |
| 11 | Platform Services supplies no system-gesture insets; the Z2 values (40 dp right, 16 dp top) are fixed starting values. If UX-12 fails or devices differ widely, Platform Services should expose the real insets and Z2 should read them | technical-director, godot-specialist | Vertical slice, on device |
| 12 | RESOLVED 2026-10-01 (`design/ux/menus-screen-flow.md` Layout Zones): the ordinary Paused screen keeps its abandon row and Resume below the top 92 dp, clear of Z1 | — | Resolved |
| 13 | `hud.md` Core Rule 8 gives HUD no seam for `PAUSE_INPUT_GUARD`; the sensor-lost Menu readying (Element #7) needs the injected guard duration and a view-side timer started at the entry to Paused | ux-designer, whoever next revises `hud.md` | `hud.md` next revision (noted in Rule 8) |

---

## Pattern Library Candidates

No `design/ux/interaction-patterns.md` exists yet. This spec introduces these patterns; they should move to the library when it is created, because Menus & Screen Flow will reuse them:

| Pattern | Defined here |
|---|---|
| **Pill backing** (Rim White 85%, Ink text, every element) | Philosophy #3, Elements |
| **Press feedback** (scale 0.94 while held, activate on release inside, hit area at least 48 dp) | Elements #3, #7 |
| **Shared status slot** (one anchored slot, content swapped by phase, never two at once) | Z4 |
| **Inactive-until-unlocked control** (about 50% opacity, no press feedback) | Element #7 (Menu, Hit). **Deviation, user decision 2026-10-01:** art bible §7 says a cosmetic "not yet" state should use a calm fill, not the dimmed look of genuine unavailability, and Menus & Screen Flow uses a fill for the same kind of timestamp guard. Here the lock is real for the player (the tap is consumed), so the dimmed look was kept. Do not promote this pattern to the shared library without resolving the tension; the pause-guard Menu in the sensor-lost pause uses the fill instead |
| **Label pill with primary and secondary line** | Sensor label rules |
