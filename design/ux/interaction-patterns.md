# Interaction Pattern Library

> **Status**: Drafted 2026-10-01 (20 patterns), not yet reviewed with `/ux-review patterns`
> **Author**: user + ux-designer
> **Last Updated**: 2026-10-01
> **Template**: Interaction Pattern Library
> **Sources**: `design/ux/hud.md`, `design/ux/menus-screen-flow.md`, `design/art/art-bible.md` §4 and §7

---

## Overview

This library is the single source for the behavior and rules of the UI components shared across screens. Each screen spec decides **placement and size**; this library decides **how a component behaves**. When the two disagree, fix the screen spec to match the library, or record a deviation under the pattern concerned. 20 patterns in 6 groups, extracted from the HUD and Menus & Screen Flow specs.

---

## Pattern Catalog

| # | Pattern | Group | One line | Used in |
|---|---|---|---|---|
| P1 | Pill backing | Foundation | Every element on its own Rim White 85% pill, Ink text | HUD, Menus |
| P2 | Touch target and activation | Foundation | At least 48 dp, activates on release inside | HUD, Menus |
| P3 | Press feedback | Foundation | Scale 0.94 while held; none on gated controls | HUD, Menus |
| P4 | Safe area and gesture edges | Foundation | 40 dp side edges, 96 dp clear bottom, 360×560 minimum | HUD, Menus |
| P5 | Primary action pill | Buttons | The one loudest tap per screen | Menus |
| P6 | Secondary action pill | Buttons | Same pill, no accent, smaller | Menus |
| P7 | Inverted confirm pill | Buttons | Solid Ink, for irreversible actions only | Menus (QUIT) |
| P8 | Round icon button | Buttons | Round icon from round primitives, named | HUD |
| P9 | Gated control | State communication | Dimmed, not hidden, with a reason; pulse only while resolving | HUD, Menus |
| P10 | Reason label pill | State communication | One line (two max), reserved slot, never wraps | HUD, Menus |
| P11 | Cosmetic readying | State communication | Calm fill for "works but not ready" (ring or underline) | HUD, Menus |
| P12 | Inactive-until-unlocked | State communication | HUD-local dimmed look; deliberate deviation | HUD |
| P13 | Toggle | Controls | Whole row is the target; knob position plus fill | Menus (Settings) |
| P14 | Slider | Controls | Drag the thumb only; commit on release | Menus (Settings) |
| P15 | Scroll list | Controls | One-finger vertical scroll, fixed header and Back | Menus (Settings) |
| P16 | Modal card + scrim | Overlays | Stacked buttons, safe option nearest the thumb | Menus |
| P17 | Banner | Overlays | Entrance only, never auto-dismisses | HUD |
| P18 | Transition cover | Overlays | Ink cut above the HUD, never the white flash | Menus |
| P19 | Shared status slot | Data display | One slot, one content at a time, nothing moves | HUD |
| P20 | Live value pill and countdown ring | Data display | Fixed width, no motion of its own; ring from pulled data | HUD |

---

## Patterns

### Group 1: Foundation

#### P1. Pill backing

**Category**: Foundation · **Used In**: every HUD and Menus element

Every UI element sits on its own Rim White `#F4F8FF` pill at 85% opacity with Ink `#1E2433` text or icon, never bare against the world. The UI palette is fixed and ignores fog, speed desaturation and grey-out (art bible §4, §7).

**Specification**:
- Shape: the round family (pill, circle). Never a triangle or a wedge.
- Colour: Ink, Rim White and Lagoon `#0E6A82` only. No red, no gold, no warm hue, even for error-like states.
- Contrast: Ink on the pill is about 14.5:1 nominal and at least 7:1 over a live backdrop (measured on device). Lagoon on the pill is about 5.8:1.

**When to Use**: anything the player reads or touches. **When NOT to Use**: world-space effects (the rings and bloom of Juice & Feedback), which use the Lagoon-tinted outer edge instead.

#### P2. Touch target and activation

**Category**: Foundation · **Used In**: HUD (Pause, Menu), Menus (every button)

**Specification**:
- Hit area at least 48 dp; the control activates on **release inside** the control. A press that starts outside and slides in does not activate it.
- A control that sends a timestamped request (Restart, Menu) stamps `press_us` on **press-down**.
- No multi-touch and no gestures (Pillar 4 anti-pillar).

**When NOT to Use**: the HUD's tap-anywhere restart, whose full-screen catcher acts on press.

#### P3. Press feedback

**Category**: Foundation · **Used In**: Pause, Menu, every Menus pill

**Specification**: scale to 0.94 while held, back on release, no other motion. A gated or inactive control shows **no** press feedback and fires no haptic. The `UI_TAP` haptic belongs to Menus & Screen Flow (provided by Platform Services).

#### P4. Safe area and gesture edges

**Category**: Foundation · **Used In**: HUD (Z2), Menus (every screen)

**Specification**:
- Every offset is measured from Platform Services' `safe_area`, never the raw screen, and read again after `app_foregrounded`.
- No interactive element within **40 dp** of the left or right safe edge (Android back-swipe strip) or within **16 dp** of the top safe edge (notification shade swipe). Non-interactive elements (HUD Z1) and full-screen tap catchers are exempt.
- The bottom **96 dp** stays clear (gesture bar, resting thumbs).
- Minimum supported safe area: 360 × 560 dp. `dp` = `screen_dpi / 160` physical pixels; `sp` = `dp` (OS text scaling is not honoured).

### Group 2: Buttons

#### P5. Primary action pill

**Category**: Buttons · **Used In**: Play, Resume (Menus), Retry (failure screen)

The single most important, most positive action on a screen. **Exactly one per screen.**

**Specification**: the largest pill in its group, a Lagoon accent stroke or underline, bold Ink label at 28 sp. Sizes in use: Play and Resume 240×72 dp, Retry 252×64 dp (inside a card). It keeps its size while gated (P9).

**When NOT to Use**: secondary, abandon, cancel or quit actions, or on a screen that already has a primary.

#### P6. Secondary action pill

**Category**: Buttons · **Used In**: Settings, Restart, Menu, Quit, Cancel, Back

**Specification**: Rim White pill, Ink label at 16 sp, **no accent**, visibly smaller than the primary, at least 48 dp high. Sizes in use: Settings 160×48, Restart and Menu 128×48, Quit and Cancel 252×48, Back 120×48. Text labels, not icon-first, so no angular icon is needed.

#### P7. Inverted confirm pill

**Category**: Buttons · **Used In**: QUIT (confirm-quit dialog)

**Specification**: solid Ink fill with a Rim White label: the heaviest-reading button in the UI, **reserved for an action that cannot be undone**, and always paired with a cancel in the P6 style. No hue outside the palette and no error colouring (art bible §7). Rim White on Ink is about 14.5:1 and does not depend on the backdrop.

#### P8. Round icon button

**Category**: Buttons · **Used In**: Pause (HUD, 56 dp), Menu (HUD, 48 dp with a 26 dp label pill below)

**Specification**: a circular pill with an Ink icon built from round primitives (pause bars, a rounded house). **Never** a triangle (play), a toothed gear or a triangular warning sign. An accessible name is required (`Pause`, `Menu`). If the icon is not self-explanatory, add a label pill below; the hit area includes the label.

### Group 3: State communication

#### P9. Gated control (disabled, not hidden)

**Category**: State communication · **Used In**: restart circle with `valid` false (HUD), Play and Resume (Menus), `haptics_intensity` with haptics off

A control that genuinely cannot be used right now. It stays visible, dimmed to about 45%, with **no** press feedback and no haptic, and a reason label (P10) says why.

**Specification**: the pill's Lagoon outline pulses (1.2 s period, at most 1 Hz) **only while the state is resolving itself** (Reconnecting). No pulse when it will not resolve (No sensor). No pulse and no label when the cause is the player's own choice (haptics off). Dimmed controls are inactive, so they are exempt from the contrast floor; the reason label is not dimmed.

#### P10. Reason label pill

**Category**: State communication · **Used In**: HUD (restart prompt, sensor-lost pause), Menus (under Play and Resume)

**Specification**: a pill at 16 sp, one line of at most 24 characters, always at full opacity. It may grow a second line **downward** (`Sensor not ready` in Hit) inside a slot reserved in advance, so nothing else moves. Strings in use: `Reconnecting…`, `No motion sensor`, `Sensor not ready`, `Tap`. A label never wraps.

#### P11. Cosmetic readying ("still arming")

**Category**: State communication · **Used In**: restart circle and the sensor-lost Menu button (HUD), Restart and Menu in Paused (Menus)

For a control that **works** but is not quite ready: a calm, continuous fill, never a static dim and never an urgent pulse.

**Specification**:
- Two forms by shape: a **Lagoon ring** around a circular control; a **Lagoon 3 dp underline** running left to right along the base of a pill.
- Icon opacity rises from **60%** to 100%; **text** rises from **65%** to 100% (65% keeps Ink on the pill at about 4.8:1, above the 4.5:1 text floor), then a soft brightness settle of about 150 ms.
- Taps are still forwarded; the real gate is Run State's timestamp math.

#### P12. Inactive-until-unlocked (HUD-local)

**Category**: State communication · **Used In**: the HUD Menu button in Hit with `valid` false

Dimmed to about 50%, the tap is consumed, no press feedback. **Deliberate deviation** (user decision 2026-10-01) from art bible §7, which prefers the P11 fill for a "not yet" state. **Not for shared use**: everywhere else use P11.

### Group 4: Controls

#### P13. Toggle (pill switch)

**Category**: Controls · **Used In**: `haptics_enabled`, `reduced_motion_enabled`, `colorblind_safe_enabled` (Settings)

**Specification**:
- A row at least 56 dp high: the label on the left (up to 2 lines at 16 sp), the switch on the right. The **whole row** is the hit area.
- A rounded track with a round knob. ON: Lagoon-filled track, knob at the far end. OFF: Rim White or neutral track, Ink-outlined knob at the near end. State is told by knob position **and** fill, never by colour alone.
- A tap writes at once (`set_value`) and fires `UI_TAP`; the knob slides in at most 150 ms.
- Accessibility: switch role, announces on or off.

#### P14. Slider

**Category**: Controls · **Used In**: `tilt_sensitivity`, `haptics_intensity` (Settings)

**Specification**:
- A 72 dp row: a rounded track with a Lagoon fill from the minimum to the value, and a round Ink-outlined thumb with a 48 dp hit area. **Only dragging the thumb changes the value**; a tap on the track does nothing (no accidental change while scrolling).
- The fill follows the finger. **One commit on release** (one `set_value` and one `UI_TAP`); nothing is written while dragging.
- No numeric readout: the fill is the value. The inert variant uses P9 (no pulse).
- Accessibility: announces a percentage.

#### P15. Scroll list

**Category**: Controls · **Used In**: Settings

**Specification**: one-finger vertical scroll, header and Back fixed, rows 8 dp apart, 40 dp side margins, group headings at 14 sp. A drag that **starts on a slider thumb** moves that slider; a drag that starts anywhere else scrolls. A thin scroll indicator shows while scrolling; inertia is the engine default. Every row must be reachable at 360 × 560 dp.

### Group 5: Overlays

#### P16. Modal card + scrim

**Category**: Overlays · **Used In**: confirm-quit dialog, map-load-failure screen

**Specification**:
- An Ink scrim at about 60% over the whole screen (the heaviest overlay in the system). A rounded Rim White card 300 dp wide, centred at 50% of H, 24 dp padding, title at 24 sp, plain non-alarming language.
- Buttons are **stacked**, the safe action nearest the thumb. Enter: scale-up plus fade, ease-out, about 240 ms, no bounce; leave: instant. A tap on the scrim does nothing; Back acts as Cancel.
- Accessibility: announced as an alert, focus on the safe button. The failure variant has a round "!" container of 56 dp (never a triangle).

#### P17. Banner

**Category**: Overlays · **Used In**: the HUD personal-best banner (Hit)

**Specification**: a pill 48 dp high, at most 80% of the safe width and 360 dp, Ink text at 20 sp, Lagoon 2 dp underline. **Entrance only** (about 220 ms ease-out, a 12 dp slide down plus fade): no hold animation, no exit animation, no auto-dismiss; the owning event clears it. It never covers the killer hazard and never delays an action.

#### P18. Transition cover

**Category**: Overlays · **Used In**: the Menu↔Running seam

**Specification**: a full-screen Ink layer **above** the HUD canvas: fade to Ink in 80-100 ms, hold across the seam-phase jump, fade from Ink in 80-100 ms. A UI-layer effect that **never** reuses Mood State 5's white hit flash (its signature of death).

### Group 6: Data display

#### P19. Shared status slot

**Category**: Data display · **Used In**: HUD Z4

**Specification**: one anchored slot whose content is swapped by phase (restart prompt, resume countdown, sensor-lost label) and **never shows two at once**. The slot reserves the worst-case height (a 2-line label) and its content is top-anchored, so nothing moves when the label grows. A priority order decides who yields if a new element competes for it.

#### P20. Live value pill and countdown ring

**Category**: Data display · **Used In**: Score, BEST, resume countdown (HUD)

**Specification**:
- Live values (Score 28 sp, BEST 18 sp): fixed width, tabular digits right-aligned, **no motion of their own**; only BEST changes state (`NEW BEST` plus a Lagoon outline). Long numbers shrink to a floor (20 sp for Score, 14 sp for BEST) and never change the pill width.
- Countdown: a 96 dp circle, a 4 dp Lagoon ring sweeping clockwise, a 48 sp digit, all read from Run State's own values and never from an accumulated `dt`.

---

## Animation Standards

| Effect | Duration | Easing |
|---|---|---|
| Press feedback | instant (scale 0.94) | none |
| Toggle knob | at most 150 ms | ease-out |
| Banner entrance | about 220 ms | ease-out |
| Modal entrance | about 240 ms | ease-out |
| Ink cut | 80-100 ms each way plus hold (about 150-250 ms in all) | linear |
| Readying fill | equals `PAUSE_INPUT_GUARD` or `RESTART_LOCK`; settle about 150 ms | linear fill, eased settle |
| Outline pulse | 1.2 s period, at most 1 Hz | sine |
| Phase change | instant | none |

General rules: no bounce, no scale-pop, no flashing. The pulse is the only repeating motion. `reduced_motion_enabled` is not consumed by the HUD or Menus; if it is ever wired, the banner and dialog entrances and the cut become instant and the pulse becomes a static outline (the countdown ring keeps sweeping because it shows real time).

---

## Sound Standards

The UI owns **no audio**. The `UI_TAP` haptic (15 ms, amplitude 0.3, priority 0; the config belongs to Platform Services) is fired by Menus & Screen Flow on every accepted on-screen tap, never on a gated tap or a hardware Back. Any tap sound belongs to Juice & Feedback.

---

## Gaps & Patterns Needed

- **Standard controls not used in the MVP:** dropdown, grid, tab bar, tooltip, toast, input field and a loading progress bar. Add one only when a screen spec first needs it.
- **Resolved while consolidating:** the readying opacities are aligned (65% for text, 60% for icons) in `hud.md` and `menus-screen-flow.md`; the pulse of the restart circle and the pulse of a pill are one pattern, a Lagoon outline pulse (P9).
- **Noted, accepted:** the primary pill has two sizes (240×72 and 252×64 inside a card); readying has two forms by shape (P11); P12 is a HUD-local deviation.

---

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | Every size and opacity here is a starting value; verify on device | user, qa-lead | Vertical slice |
| 2 | P4: Platform Services supplies no system gesture insets (`hud.md` Open Question 11) | technical-director, godot-specialist | Vertical slice |
| 3 | P13 to P16: AccessKit names and roles are unverified on 4.7.2 | accessibility-specialist, godot-specialist | Vertical slice |
| 4 | P12: whether to move the HUD Menu button to P11 after playtests (art bible §7) | user, ux-designer | First-playable playtest |
| 5 | RESOLVED 2026-10-03: the tier is committed in `design/accessibility-requirements.md` (Basic plus named features, 2026-10-03); the library keeps WCAG-AA contrast as its baseline | accessibility-specialist | Resolved |
