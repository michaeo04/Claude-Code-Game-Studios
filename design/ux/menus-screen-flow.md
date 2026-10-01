# UX Spec: Menus & Screen Flow

> **Status**: Drafted 2026-10-01, pending `/ux-review` in a fresh session
> **Author**: user + ux-designer
> **Last Updated**: 2026-10-01
> **Revision note 2026-10-01**: `/review-all-gdds` 2026-10-01 items C2 (gates also need `input_source == SENSOR`), C3 (Paused Restart gated, Menu ungated) and S3 (Retry contract) applied.
> **Journey Phase(s)**: unknown (no `design/player-journey.md`)
> **Template**: UX Spec (multi-screen: Menu, ordinary Paused, Settings, confirm-quit dialog, map-load-failure, Menu↔Running cut)
> **Behavior source**: `design/gdd/menus-screen-flow.md` (what each screen does and sends); this file owns layout, sizing, touch targets, transitions and accessibility. HUD layers are specified in `design/ux/hud.md`.

---

## Purpose & Player Need

The screens around a run have one job: let the player get into a run, out of a run, or change a preference without losing anything and without confusion. The player does not come here to use a menu. They want to be back in the tube as fast as possible.

| Screen | The player arrives wanting to... |
|---|---|
| **Menu** | start a run right now (Play), and see their BEST |
| **Ordinary Paused** | get back into the run (Resume), or deliberately abandon it (Restart / Menu) |
| **Settings** | change one setting (haptics, tilt sensitivity, accessibility) and return, without feeling they left the game |
| **Confirm-quit dialog** | be sure before leaving the app, so Back never quits by accident |
| **Map-load-failure** | know plainly what happened and retry or quit, never stare at a blank or frozen screen |

**What goes wrong without it or when it is hard to use:** the player cannot start a run (Play blocked with no visible reason), quits the app by accident with Back, gets stuck in Paused when the sensor drops, or watches a frozen screen when a map fails to load.

*Sources: `design/gdd/menus-screen-flow.md` (Player Fantasy, Core Rules 1-8), Pillar 4 (One-Thumb Simplicity), Pillar 1 (Instant Readability).*

---

## Player Context on Arrival

No `design/player-journey.md` exists, so the states below are assumptions (logged in Open Questions).

| Screen | Arrives from | Assumed state | Voluntary? |
|---|---|---|---|
| **Menu** | App launch (after Boot), or Paused → Menu / Hit → Menu | Calm and curious at launch. After abandoning a run or dying: a little annoyed, wants a quick retry | Yes (except after abandoning a run) |
| **Ordinary Paused** | Pause button, Android Back, app interruption (call, Home), or the sensor recovering after `sensor_lost` | Mid-run, hands in the tilt grip, possibly startled. Not time-pressured, but wants back in at once | Sent by the game (except the Pause button) |
| **Settings** | Menu only | Calm, deliberate | Yes |
| **Confirm-quit** | Back on Menu or on the failure screen | May have meant "go back one step", so slightly uncertain | Sent by the game |
| **Map-load-failure** | Boot lasting longer than `MAP_LOAD_TIMEOUT` | Confused and impatient, does not know whether the fault is theirs | Sent by the game |

**Design consequence:** every screen must read in one glance, with one thumb and no precision (Pillars 1 and 4). Screens the game sends the player to (Paused, failure, confirm-quit) must say plainly what is happening and never assume the player chose to be there.

---

## Navigation Position

`Boot → Menu → Running → (Paused | Hit) → …`. Menus & Screen Flow owns **Menu** (the root), the **ordinary Paused** screen, **Settings** and the **confirm-quit dialog** (two overlays reachable only from Menu or the failure screen), and the **map-load-failure** screen (a branch of Boot). Hit and the sensor-lost pause belong to the HUD (`design/ux/hud.md`). Running and Resuming have no screen of this system.

```
Boot ──(timeout)──► Failure ──► confirm-quit
  │
  ▼
Menu ──► Settings        Menu ──(Back)──► confirm-quit ──► quit()
  │ Play (cut)
  ▼
Running ⇄ Paused (Resume → Resuming → Running)
  │            ├─ Restart → Running
  ▼            └─ Menu → Menu (cut)
Hit (HUD) ──► Running | Menu
```

---

## Entry & Exit Points

**Entry points**

| Screen | From | Trigger | Player carries |
|---|---|---|---|
| Menu | Boot | `map_ready` | `personal_best` (re-pulled on every entry to Menu) |
| Menu | Hit / Paused / sensor-lost pause | accepted `menu_requested` | a finalized run |
| Menu | Settings, confirm-quit | Back or Cancel | nothing |
| Ordinary Paused | Running | pause (button, Back, `app_interrupted`) | frozen score |
| Ordinary Paused | sensor-lost pause | `valid` becomes true while Paused | frozen score, sensor recovered |
| Settings | Menu | tap Settings | the 5 stored values |
| Confirm-quit | Menu / failure | Back, or the Quit button on the failure screen | the caller, so Cancel returns to the right place |
| Failure | Boot | longer than `MAP_LOAD_TIMEOUT` | nothing |

**Exit points**

| Screen | To | Trigger | Notes |
|---|---|---|---|
| Menu | Running | Play (gated: `valid` and `input_source == SENSOR`) | through the Ink cut |
| Menu | Settings / confirm-quit | Settings / Back | overlays |
| Ordinary Paused | Resuming | Resume or Back (gated: `valid` and `input_source == SENSOR`) | with the gate closed nothing is sent |
| Ordinary Paused | Running | Restart (gated like Resume; then after the guard) | abandons the run; with the gate closed nothing is sent |
| Ordinary Paused | Menu | Menu (never gated; after the guard) | abandons the run, through the cut; always available as the exit |
| Settings | Menu | Back | values are already written, no revert |
| Confirm-quit | the caller / app exit | Cancel or Back / QUIT | **one-way:** QUIT is the only path to `quit()` |
| Failure | (retry) / confirm-quit | Retry (the loader retries `load_map`; its interface is provisional) / Quit or Back | a failed retry stays in Boot |
| Failure | Menu | `phase` becomes Menu while the failure screen shows (a late map load) | the failure screen disappears by itself, no Retry press needed (user decision 2026-10-01) |

---

## Layout Specification

### Information Hierarchy

| Screen | 1 (read first) | 2 | 3 | Discoverable |
|---|---|---|---|---|
| **Menu** | PLAY (largest, Lagoon accent) | why Play is dimmed (`Reconnecting…` / `No motion sensor`) | BEST | Settings (secondary); Quit only through Back |
| **Ordinary Paused** | RESUME (largest, accent) | why Resume and Restart are dimmed (same reason, two label slots) | RESTART (gated like Resume), MENU (never gated); secondary, small, set apart | frozen score (HUD Z1) |
| **Settings** | the 5 controls, in 3 groups (input, feedback, accessibility) | Back | | |
| **Confirm-quit** | the question `Quit Tube Rush?` | QUIT (inverted Ink, heaviest button) | Cancel | |
| **Map-load-failure** | plain-language message | RETRY (primary) | Quit (secondary) | |

### Layout Zones

Portrait, locked. All offsets in dp inside the safe area from Platform Services (never the raw screen), with the HUD rules reused: no interactive element within **40 dp** of the left or right safe edge (Android back-gesture strip), and the bottom **96 dp** stays clear (gesture bar, resting thumbs). Minimum supported safe area is 360 × 560 dp (`hud.md`, Platform & Input Variants). All sizes are starting values, unverified on device.

Arrangement chosen (user, 2026-10-01): **thumb-low** for Menu, **Resume low and abandon actions mid-screen** for Paused.

| Screen | Zone | Position and size |
|---|---|---|
| **Menu** | **M1 BEST** | Top-centre, 16 dp below the top safe edge. Pill 200×44, value 24 sp, tag `BEST` 14 sp. No accent; clearly smaller than Play. What it shows when the stored best is 0 (first run) is decided in States & Variants |
| | **M2 Play group** | Centred. Play pill **240×72** (Lagoon accent, bold label). 8 dp below it, space reserved for the sensor label pill (28 dp, one line, shown only while `valid` is false). 16 dp below that, the Settings pill 160×48. The group ends 96 dp above the safe bottom edge, so Play's centre is at `min(0.70 × H, H − 232)` (H = 640: 408, 64%; H = 800: 560; H = 900: 630) |
| **Ordinary Paused** | **P1 Abandon row** | Restart and Menu: two text pills **128×48**, 24 dp apart (280 dp in all, edge-to-edge 40 dp at 360 dp wide), centred at 45% H. One shared `PAUSE_INPUT_GUARD` clock drives both readying fills, so they finish together. **Restart reason-label slot (C3):** one 28 dp label slot, centred under the P1 row and 8 dp below it, one line, reserved always so nothing moves; shown only while Restart is gated (same strings and rule as the Resume label). Menu is never dimmed, so a dimmed Restart beside a full-opacity Menu tells the label's subject. The 80 dp clearance below is measured between **pills** (the slot is not interactive); exact placement is Open Question 14 |
| | **P2 Resume group** | Resume pill 240×72 (accent) with the reserved 28 dp sensor label slot under it. Centre at `min(0.70 × H, H − 168)` (H = 640: 448). The gap from P1 to Resume is at least 80 dp (H = 640: 100 dp) so a Resume tap cannot land on an abandon action |
| | HUD layer | Z1 stays visible, frozen, top-left (84 dp high, 170 dp wide). Z2, Z4, Z5 are hidden. P1 and P2 never reach the top 92 dp, so Menus' screen does not cover Z1 (**resolves `hud.md` Open Question 12**) |
| **Confirm-quit** | **Q1 Card** | Ink scrim at about 60% over the whole screen (heavier than any other overlay). Card 300 dp wide, centre at 50% H, title `Quit Tube Rush?` 24 sp. Two buttons **stacked**, each 252×48, 12 dp apart: **QUIT** (inverted: solid Ink, Rim White text) on top, **Cancel** (house pill) below. The safe option sits nearest the thumb, so a stray tap cancels instead of quitting |
| **Map-load-failure** | **F1 Card** | Card 300 dp wide, centre at 50% H: round "!" container 56 dp, message up to 2 lines at 20 sp, **Retry** 252×64 (primary), **Quit** 252×48 (secondary) 12 dp below. Quit opens the confirm-quit dialog |
| **Settings** | **S1 Header** | Fixed at the top: title `SETTINGS`, 16 dp below the top safe edge |
| | **S2 List** | A **vertical scroll list** between header and Back. Three groups with heading labels (`Input`, `Feedback`, `Accessibility`). Rows at least 56 dp (sliders 72 dp), 8 dp apart, 40 dp side margins. `haptics_intensity` is indented under `haptics_enabled` |
| | **S3 Back** | Fixed, bottom-centre, 120×48, ends 96 dp above the safe bottom edge |
| **Menu↔Running cut** | full screen | Ink cover layer above the HUD canvas (see Transitions) |

### Component Inventory

| Component | Where | Interactive | Pattern |
|---|---|---|---|
| **Primary action pill** (240×72, Lagoon accent, bold Ink label) | Play, Resume; Retry (252×64) | Yes | **New** (art bible §7; add to the library) |
| **Secondary action pill** (Rim White 85%, Ink label, no accent) | Settings, Restart, Menu, Quit, Cancel, Back | Yes | **New** |
| **Inverted confirm pill** (solid Ink, Rim White label) | QUIT only | Yes | **New**, one-off (art bible §7, irreversible action) |
| **Label pill** (16 sp, one line) | sensor reason under Play and Resume, and under the Paused P1 row for Restart | No | Reused from `hud.md` |
| **BEST pill** | Menu M1 | No | Reused from `hud.md`, larger |
| **Readying underline** (Lagoon 3 dp, left to right along the pill base, label 65% to 100%) | Restart, Menu in Paused | No (cosmetic) | **New** (the pill counterpart of the HUD's circular fill) |
| **Toggle** (round knob, pill track) | `haptics_enabled`, `reduced_motion_enabled`, `colorblind_safe_enabled` | Yes | **New** |
| **Slider** (Lagoon fill, round thumb) | `haptics_intensity`, `tilt_sensitivity` | Yes | **New** |
| **Modal card + scrim** | confirm-quit, failure | No (container) | **New** |
| **Settings scroll list** | Settings S2 | Yes (vertical scroll) | **New** |
| **Ink cover** | Menu↔Running cut | No | **New** |

### ASCII Wireframes

Menu (H = 640):

```
┌────────────────────────┐
│     [ BEST 1575  ]     │  M1 (hidden while best = 0)
│                        │
│    tube visible        │
│    behind              │
│                        │
│  ╭──────────────────╮  │
│  │       PLAY       │  │  M2, 240x72, centre 64% H
│  ╰──────────────────╯  │
│   [ Reconnecting… ]    │  label slot (only when valid is false)
│      [ SETTINGS ]      │  160x48
│                        │
│   (bottom 96 dp clear) │
└────────────────────────┘
```

Ordinary Paused (H = 640):

```
┌────────────────────────┐
│[SCORE][BEST]  Z1 (HUD) │  frozen
│                        │
│                        │
│  [RESTART]   [ MENU ]  │  P1, 128x48 each, 45% H, readying underline
│   [ label slot ]       │  Restart reason (only while gated)
│          ↓ >= 80 dp    │  (pill to pill)
│  ╭──────────────────╮  │
│  │      RESUME      │  │  P2, 240x72, 70% H
│  ╰──────────────────╯  │
│   [ label slot ]       │
│   (bottom 96 dp clear) │
└────────────────────────┘
```

Confirm-quit and map-load-failure (cards on the scrim / on the screen):

```
┌────────────────────────┐   ┌────────────────────────┐
│░░░░░░░░░░░░░░░░░░░░░░░░│   │                        │
│░ ┌──────────────────┐ ░│   │  ┌──────────────────┐  │
│░ │  Quit Tube Rush? │ ░│   │  │       (!)        │  │
│░ │ [      QUIT     ] │ ░│   │  │ The map couldn't │  │
│░ │ [     Cancel    ] │ ░│   │  │ load.            │  │
│░ └──────────────────┘ ░│   │  │ [    RETRY     ] │  │
│░░░░░░░░░░░░░░░░░░░░░░░░│   │  │ [     Quit     ] │  │
└────────────────────────┘   │  └──────────────────┘  │
                             └────────────────────────┘
```

Settings:

```
┌────────────────────────┐
│       SETTINGS         │  S1 (fixed)
│  Input                 │
│  Tilt sensitivity ──●─ │  72 dp row
│  Feedback              │  S2 scrolls
│  Haptics         (●  ) │  56 dp row
│     Intensity    ──●── │  indented, dims when haptics off
│  Accessibility         │
│  Reduced motion  (  ●) │
│  Colorblind safe (  ●) │
│                        │
│       [  BACK  ]       │  S3 (fixed), ends 96 dp above the bottom
└────────────────────────┘
```

---

## States & Variants

Sensor strings are the HUD's (`Reconnecting…`, `No motion sensor`, each at most 24 characters). **Gate condition (all Gated rows):** a control is gated unless `valid` is true **and** `input_source == SENSOR`; a not-`SENSOR` source with `valid` true reuses the `No motion sensor` look and label (dimmed, no pulse).

| Screen | State / variant | Trigger | What changes |
|---|---|---|---|
| **Menu** | Default | `valid` true and `input_source` `SENSOR` | Play primary, full opacity |
| | Gated: Reconnecting | `valid` false, `state` Acquiring | Play dimmed to about 45%; the pill's Lagoon outline pulses (1.2 s period, at most 1 Hz); label pill `Reconnecting…`. A tap on Play sends nothing |
| | Gated: No sensor | `valid` false, `state` Unavailable | Play dimmed to about 45%, no pulse; label pill `No motion sensor` |
| | Gated: not a sensor source | `valid` true, `input_source` not `SENSOR` (no MVP driver produces it today) | As No sensor: Play dimmed, no pulse, label `No motion sensor`. A tap on Play sends nothing |
| | BEST empty | stored best is 0 (first run) | The BEST pill is hidden (same rule as the HUD); a first-run Menu shows only Play and Settings (user decision 2026-10-01) |
| **Ordinary Paused** | Default | `valid` true and `input_source` `SENSOR` | Resume primary; Restart and Menu show the readying underline for `PAUSE_INPUT_GUARD` (0.3 s), then settle at full opacity |
| | Resume and Restart gated | the gate condition fails (`valid` false, or `input_source` not `SENSOR`) | Resume and Restart dimmed to about 45%, each with its label pill (Resume's under Resume, Restart's in the P1 slot; pulse only while `state` Acquiring); Android Back sends nothing either. The Restart readying underline is not drawn while gated (the gated look takes precedence). **Menu stays at full opacity and tappable** (the exit) |
| | Restart readying | gate open, inside `PAUSE_INPUT_GUARD` | Underline fill on Restart and Menu as in Default; a tap is forwarded and Run State's guard filters it. Visually distinct from the gated look (underline and 65% to 100% label, not a 45% dim with a label) |
| **Settings** | Default | opened from Menu | Values come from the getters when the screen opens; no loading state |
| | Haptics off | `haptics_enabled` false | `haptics_intensity` dimmed (no pulse, no label: nothing is resolving) |
| | Write failed | `set_value` returns false | No error is shown; the value still changes for the session (Settings AC-14) and one line is logged |
| **Confirm-quit** | Default | Back on Menu or failure | One state only; Back again acts as Cancel |
| **Map-load-failure** | Default | Boot longer than `MAP_LOAD_TIMEOUT` | Message, Retry, Quit. Leaves by itself if `phase` becomes Menu |
| | Retrying (loader interface provisional) | tap Retry | The loader retries `load_map` and sends `map_ready` only on success. Retry dimmed with the outline pulse until `phase` changes (the screen then leaves by itself) or the timeout runs out again, then the failure screen shows again (a failed load stays in Boot) |
| **Boot, loading** | no screen of this system | Boot under the timeout | The engine splash, then a plain Ink background (no pill, no spinner). Menu appears when `phase` is Menu (user decision 2026-10-01) |

**Platform variants.**
- **Platform:** Android only (user decision 2026-10-01); `quit()` and the confirm-quit dialog apply on every screen that offers them.
- **Android:** as written; Back follows the GDD routing table (Core Rule 5).
- **Tablets and foldables:** elements keep their dp sizes and stay centred (cards 300 dp, pills 240 dp); nothing scales up.

---

## Interaction Map

Touch only (Android, portrait): no hover, keyboard or gamepad. Every button activates on **release inside the button**, hit area at least 48 dp, and shows the press feedback of the HUD (scale to 0.94 while held). A gated control shows **no** press feedback and fires no haptic.

| Component | Action | Feedback | Outcome |
|---|---|---|---|
| **Play** | tap (release inside) | press scale, haptic `UI_TAP` | `start_requested`, through the Ink cut. **Gated:** unless `valid` is true and `input_source == SENSOR`, nothing is sent, no haptic, no press feedback |
| **Resume**, **Back in Paused** | tap / Back | as Play | `resume_requested`. Gated the same way (the same condition) |
| **Restart** (Paused) | tap, `press_us` stamped on press-down | as Play | `restart_requested(press_us)` when the gate is open; the guard belongs to Run State. **Gated** like Play: nothing sent, no haptic, no press feedback, dimmed with a reason label |
| **Menu** (Paused) | tap, `press_us` stamped on press-down | as Play | `menu_requested(press_us)`; **never gated** (always forwarded, the guard belongs to Run State) |
| **Settings** (Menu) | tap | as Play | opens the Settings screen |
| **Toggle** | tap | knob slides, haptic | `set_value(key, bool)` at once |
| **Slider** | drag the thumb | the Lagoon fill follows the finger | one `set_value(key, value)` and one `UI_TAP` **on release** (user decision 2026-10-01); nothing is written while dragging |
| **Back** (Settings) | tap | as Play | closes Settings; no revert, values are already written |
| **QUIT** / **Cancel** | tap | as Play | `quit()` / closes the dialog. A tap on the scrim does nothing (user decision 2026-10-01); only Cancel or Back closes it |
| **Retry** | tap | as Play | retry (provisional) |
| **Failure Quit** | tap | as Play | opens the confirm-quit dialog |
| **Hardware Back** | press | no haptic (not an on-screen tap) | routed by the GDD table (Core Rule 5) |

**Focus order:** not applicable (touch only). Screen-reader reading order is in Accessibility.

---

## Events Fired

| Player action | Event / request | Payload | Notes |
|---|---|---|---|
| Play (gate open: `valid` and `input_source == SENSOR`) | `start_requested` | none | plus haptic `UI_TAP` |
| Resume, Back in Paused (gate open) | `resume_requested` | none | |
| Restart (gate open) | `restart_requested` | `press_us` | plus haptic `UI_TAP` |
| Menu | `menu_requested` | `press_us` | never gated; plus haptic `UI_TAP` |
| Change a setting | `set_value(key, value)` | key, value | **Changes persistent state** (written through Settings & Accessibility to Save & Persistence): architecture should note it |
| Confirm QUIT | `quit()` | none | the only path to `quit()` |
| Every other on-screen tap | haptic `UI_TAP` only | | |
| A gated tap (Play, Resume, Restart), any hardware Back | none, no haptic | | deliberate (Core Rule 7); a gated Restart tap is treated like a gated Play tap |
| Analytics | **none** | | the project has no analytics system yet; omitted on purpose |

---

## Transitions & Animations

Same principle as the HUD: a screen shows on the tick its phase begins. Every motion is short, non-repeating (except the pulse) and far under the photosensitivity ceiling.

| Transition | Treatment | Duration |
|---|---|---|
| **Menu → Running** (Play) | Ink cut: fade to Ink, hold across the seam-phase jump, fade from Ink. The cover layer sits **above** the HUD canvas | 80-100 ms + hold + 80-100 ms, about 150-250 ms in all |
| **Running / Paused / Hit → Menu** | The same cut, symmetric (the GDD's Running → Menu boundary) | as above |
| **Paused → Running** (Restart), **Hit → Running** | **No cut** (`run_reset` snaps the camera; Core Rule 9 only covers the two Menu boundaries) | instant |
| **Entering or leaving ordinary Paused, Settings, failure** | **Instant**, no fade or slide (user decision 2026-10-01) | 0 |
| **Confirm-quit** enter | Gentle scale-up plus fade, ease-out, no bounce | about 240 ms |
| Confirm-quit leave | Instant | 0 |
| **Readying underline** (Paused) | The Lagoon 3 dp line runs left to right over `PAUSE_INPUT_GUARD`, label 65% to 100%, then a soft brightness settle | 0.3 s, settle about 150 ms |
| **Outline pulse** (Reconnecting, Retrying) | The pill's Lagoon outline pulses | 1.2 s period, at most 1 Hz, no flashing |
| **Toggle / slider** | Knob slides, fill follows the finger | toggle at most 150 ms |
| **Press feedback** | Scale to 0.94 while held | instant |

`reduced_motion_enabled` is not consumed by this system (GDD Visual/Audio). If a device pass shows a need, the cut and the dialog entrance become instant cuts; that would be a new Open Question, not a silent change. The Ink cut is a UI-layer effect and never reuses Mood State 5's white hit flash (art bible §7).

---

## Data Requirements

The UI owns no game state. The overlay flags `settings_open` and `confirm_quit_open` are navigation state held by `MenuCore`, not game state.

| Data | Source (owner) | Read / Write | Update | If unavailable |
|---|---|---|---|---|
| `phase`, `run_paused(source)` | Run State & Restart | Read | pushed events | keep the current screen |
| `valid`, `state`, `input_source` | Tilt Input | Read | pulled every tick | seam missing: treated as `valid` false with `No motion sensor`. `input_source` is a gate input, not only a label input: every gate needs `valid` true **and** `input_source == SENSOR`; a not-`SENSOR` source shows `No motion sensor` |
| `personal_best` | Scoring & Personal Best | Read | pulled on every entry to Menu (no push event) | 0 or unreadable: the BEST pill is hidden |
| The 5 settings values | Settings & Accessibility | Read and Write (`set_value`) | read when Settings opens | each key falls back to its own default (Settings contract) |
| `back_pressed` | Platform Services | Read | event | n/a |
| `safe_area`, `viewport_size`, `screen_dpi` | Platform Services | Read | at layout, again after `app_foregrounded` | as the HUD: full screen rectangle, `viewport_units_per_dp = 1` |
| `PAUSE_INPUT_GUARD` | Run State config (injected) | Read | at construction | n/a |
| Boot elapsed time against `MAP_LOAD_TIMEOUT` (10 s default) | `MenuCore` / `MenuConfig` | Read | every tick | n/a |

---

## Accessibility

No `design/accessibility-requirements.md` exists, so there is no committed tier. WCAG-AA is the working baseline, as in the HUD spec (HUD Open Question 2).

| Area | Requirement |
|---|---|
| Contrast | Ink on Rim White about 14.5:1 nominal and at least 7:1 over a live backdrop (measured on device, same method as HUD AC-22). QUIT (Rim White on solid Ink) does not depend on the backdrop. Lagoon on Rim White about 5.8:1 (above the 3:1 non-text floor) |
| Touch targets | Every control has a hit area of at least 48 dp (Play and Resume 72, slider thumb 48, rows at least 56), activated on release inside. No interactive element within 40 dp of the left or right safe edge |
| Colour independence | Toggle: knob position plus fill. Primary versus secondary: size plus accent. Gated: dimming plus a text label (the reason label is always at full opacity). Nothing relies on Lagoon versus Ink alone |
| Text size | Play, Resume, Retry 28 sp bold; secondary buttons and Settings rows 16 sp; group headings 14 sp; dialog title 24 sp; failure message 20 sp. OS text scaling is **not** honoured (same deliberate exception to WCAG 1.4.4 as the HUD) |
| Motion | Only the Ink cut, the dialog entrance, the readying underline, the outline pulse (at most 1 Hz), toggle slides and the press scale. No flashing |
| Screen reader | **Proposed names, non-binding until AccessKit on 4.7.2 is verified:** `Play` (with the reason when gated), `Resume` and `Restart` (each with the reason when gated), `Menu` (never gated), `Settings`; toggles as switches announcing on or off; sliders announcing a percentage; the confirm-quit dialog and the failure message as alerts, with focus on Cancel in the dialog |
| Reading order (proposed, same caveat) | Menu: BEST, Play, reason label, Settings. Paused: Restart (with the reason when gated), Menu, Restart reason label (P1 slot, only while gated), Resume (with the reason when gated), Resume reason label. Settings: title, the list in order, Back. Dialog: title, Cancel, QUIT. Failure: message, Retry, Quit (Android) |
| Single-handed | The primary actions sit lower-centre within thumb reach; Settings is a vertical scroll with one finger; the abandon actions are set apart from Resume on purpose |

---

## Localization Considerations

English strings are the reference. Allow 40% expansion. **Labels never wrap**, except Settings row labels, the dialog title and the failure message, which wrap as shown.

| Element | Limit | Notes |
|---|---|---|
| PLAY, RESUME, RETRY (28 sp bold, 240 dp pill) | 10 characters | |
| **RESTART, MENU** (16 sp, 128 dp pill) | **9 characters** | **HIGH PRIORITY:** a 40% expansion of `RESTART` can break the pill (for example `RECOMMENCER`, 11); the P1 row cannot widen (280 dp between 40 dp edges at 360 dp), so longer translations must be shortened |
| SETTINGS (160 dp pill) | 11 characters | |
| BEST tag | 10 characters | as the HUD |
| Settings row labels | 2 lines, 40 characters | a 56 dp row holds two lines of 16 sp |
| Dialog title (24 sp) | 2 lines | the card grows vertically |
| Failure message (20 sp) | 3 lines | the card grows vertically |
| Sensor labels | 24 characters | as the HUD |

Numbers: BEST shows plain digits with no thousands separator, as the HUD (widths are computed for plain digits); locale formatting is post-MVP.

---

## Accessibility

[To be designed]

---

## Localization Considerations

[To be designed]

---

## Acceptance Criteria

Measured on the device matrix of the HUD spec (a 16:9 phone, a 20:9 phone, a notched phone, a tablet in portrait, and the 360×560 dp minimum). Evidence in `production/qa/evidence/menus-screen-flow/`. Behavior and gating logic stay tested in `design/gdd/menus-screen-flow.md` (AC-1 to AC-27, MENU-1 to MENU-4).

- **MN-1 Performance:** every screen shows on the tick its phase begins; Menu shows within 100 ms of `phase` becoming Menu; Settings opens within one frame (no loading state); the confirm-quit entrance takes about 240 ms. All these screens together add at most 25 draw calls and 1.0 ms per tick on a mid-tier Android device (starting values, replaced by measurement; the project budget is 150 draw calls and 16.6 ms).
- **MN-2 Gating:** with the sensor off (or `valid` simulated false, or `valid` true with `input_source` simulated not `SENSOR`), 10 taps on Play start no run, give no haptic and no press feedback, and the label `Reconnecting…` or `No motion sensor` shows correctly (a not-`SENSOR` source shows `No motion sensor`). The same holds for Resume, for Restart (dimmed, its label in the P1 slot, nothing sent, no abandoned run) and for Android Back in Paused. Menu in Paused stays tappable and works in the same state.
- **MN-3 Back (Android):** Menu opens confirm-quit; confirm-quit closes; Settings closes (and does not open confirm-quit); Paused acts like Resume (gated on `valid` and `input_source == SENSOR`); Hit goes to Menu; Boot while loading does nothing; the failure screen opens confirm-quit. No Back press calls `quit()` or gives a haptic.
- **MN-4 Quit:** `quit()` runs only through the QUIT button; Cancel, Back and a tap on the scrim never quit (a tap on the scrim does nothing). QUIT sits above Cancel and Cancel is nearest the thumb.
- **MN-5 Safe abandon:** Restart and Menu in Paused are at least 80 dp from Resume (measured on screen); the readying underline runs for 0.3 s from every entry to Paused; with the sensor ready, a tap inside that window does not abandon the run and a tap after it does (with the gate closed Restart abandons nothing at any time, while Menu always can after the window); the Restart reason-label slot is reserved so no pill moves when it appears.
- **MN-6 Layout:** at 360×640, 360×800, 412×915 and 360×560, no element lies outside the safe area, every button ends at least 96 dp above the safe bottom edge, no interactive element lies within 40 dp of the left or right safe edge, and every hit area is at least 48 dp.
- **MN-7 Empty state:** on the very first run (stored best 0) Menu shows no BEST pill; after the first run it shows BEST with the right score.
- **MN-8 Failure:** a Boot longer than `MAP_LOAD_TIMEOUT` shows the message and Retry and Quit; if `phase` becomes Menu the failure screen disappears by itself; Retry sends nothing but the haptic until a loader exists (provisional; the contract is that the loader retries `load_map` and sends `map_ready` only on success).
- **MN-9 Settings:** a toggled value is still set after closing and reopening the app; a slider writes once, on release; switching haptics off dims `haptics_intensity`; there is no Save, Apply or Cancel control; all 5 rows can be reached by scrolling at 360×560.
- **MN-10 Cut:** the Menu↔Running cut hides at least one frame in both directions, no tube geometry is seen jumping, the cover sits above the HUD, and it cannot be confused with the white hit flash.
- **MN-11 Accessibility:** contrast of Ink on the pills is at least 7:1 over three backdrops (same method as HUD AC-22); every state can be told apart in a greyscale screenshot; text sizes match the Accessibility table.
- **MN-12 Localization:** with the longest strings (40% expansion, within the limits table) no label overflows its pill or wraps where it must not, and the P1 row keeps its size.

---

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | No `design/player-journey.md`: the arrival states are assumptions. Template at `.claude/docs/templates/player-journey.md` | user, ux-designer | Before `/gate-check pre-production` |
| 2 | No `design/accessibility-requirements.md`: the tier is not committed; WCAG-AA is the baseline | user, accessibility-specialist | Before `/gate-check pre-production` |
| 3 | Retry and the Retrying look: the contract is decided (the loader retries `load_map`, sends `map_ready` only on success, a failed load stays in Boot) but the loader's interface is provisional until Run State's Open Question 8 is resolved | whoever authors the map loader | When that system is authored |
| 4 | SUPERSEDED 2026-10-01: the project is Android-only, so `quit()` applies everywhere and the GDD needs no platform split | — | Superseded |
| 5 | No game name or wordmark on Menu (the name is a working title); a reserved area is not drawn | user, art-director | When the name and branding are final |
| 6 | AccessKit names, roles and reading order on 4.7.2 are unverified (proposal only) | accessibility-specialist, godot-specialist | Vertical slice |
| 7 | All sizes are starting values. Play at 64% to 70% of H needs a thumb-reach check; the Resume to Restart/Menu distance needs a playtest for accidental abandons | user, qa-lead | Vertical slice, on device |
| 8 | Boot splash colour must equal Ink so the hand-off from the engine splash to the Ink background shows no flash | godot-specialist | `project.godot` setup |
| 9 | dp to viewport-unit conversion needs an ADR (shared with `hud.md` Open Question 9) | technical-director, godot-specialist | Before the first UI story |
| 10 | No left-handed mirroring in the MVP (as `hud.md` Open Question 5) | user | Post-MVP |
| 11 | No distinct copy for "device not supported" (sensor Unavailable and never Live) or for a not-`SENSOR` `input_source` with `valid` true (the gate is closed, C2); this spec reuses `No motion sensor` for both | ux-designer, writer | Before first-playable |
| 12 | `tilt_sensitivity` is adjusted blind (Settings has no motion preview); a preview may be needed | user, game-designer | First-playable playtest |
| 13 | DONE 2026-10-01 (`design/ux/interaction-patterns.md`, 20 patterns): the new patterns in the Component Inventory (primary / secondary / inverted pill, readying underline, toggle, slider, modal card, scroll list, Ink cover) belong in `design/ux/interaction-patterns.md`, together with the HUD's candidates | ux-designer | `/ux-design patterns` |
| 14 | RESOLVED 2026-10-01 (user): keep the proposal below, one reserved 28 dp line centred under the P1 row. Original question: placement of the gated Restart's reason label (C3): proposed as one reserved 28 dp line centred under the P1 row, 8 dp below it. At H = 640 that leaves about 64 dp between the slot and the Resume pill (100 dp pill to pill, which still meets the 80 dp rule measured between pills); a centred label under two pills could also read as describing Menu, which the full-opacity Menu mitigates. Alternatives: a label inside the Restart pill (does not fit 128 dp at 16 sp with `No motion sensor`), or one shared label for Resume and Restart | user, ux-designer | Next `/ux-review`, or before the first UI story |
