# Accessibility Requirements: Ball-in-Tube (working title)

> **Status**: Committed (pending /ux-review)
> **Author**: user + ux-designer
> **Last Updated**: 2026-10-03
> **Accessibility Tier Target**: Basic, plus the named features below
> **Platform(s)**: Android (phones; ADR-0001, ADR-0006)
> **External Standards Targeted**:
> - WCAG 2.1 AA as the working baseline for contrast (1.4.3, 1.4.11) and touch targets
> - WCAG 2.3.1 (three flashes or below threshold): binding
> - WCAG 1.4.4 (text resize): deliberate exception, see Known Intentional Limitations
> - AbleGamers CVAA: N/A (no voice chat or messaging)
> - Xbox XAG, PlayStation guidelines: N/A (Android only)
> - Google Android accessibility guidelines: Partial (48 dp targets met; TalkBack unverified, spike UI-A1)
> **Accessibility Consultant**: None engaged
> **Linked Documents**: design/gdd/settings-accessibility.md, design/ux/hud.md, design/ux/menus-screen-flow.md, design/ux/interaction-patterns.md, docs/architecture/adr-0011-ui-architecture.md (section 7)

> **Why this document exists**: per-screen accessibility annotations live in the UX specs. This file holds the project-wide commitments, the feature matrix, the test plan and the audit history. If a feature conflicts with a commitment here, this document wins: change the feature, not the commitment, unless the producer approves a formal revision. Update it after each `/gate-check`, after any audit, and whenever a system is added to `systems-index.md`.

---

## Tier Commitment

**Target Tier**: Basic, plus the features listed under "In scope beyond Basic".

**Rationale**: One-thumb, tilt-steered, voice-free, short-session mobile game. The main barriers are motor (steering is tilt only) and visual (a fast world, flashes, a cobalt ball over a dark-hazard field), not reading or audio. The project already designed reduced motion, a colourblind-safe ball luminance, tilt sensitivity, haptics intensity and a WCAG 2.3.1 flash baseline, which sit above Basic. Standard would add an in-game text size and input remapping, which are excluded for stated reasons; Comprehensive needs a screen reader and high-contrast mode on Android, and AccessKit on Android is unverified (ADR-0011). Dropping below Basic would remove the flash safety and colour-independence commitments that Pillars 1 and 2 already rely on.

**In scope beyond Basic**: `reduced_motion_enabled`; `colorblind_safe_enabled`; `tilt_sensitivity` 0.5 to 2.0; `haptics_enabled` and `haptics_intensity`; a named flash budget covering the Hit flash and the Ink cut; a hardware Back press as an alternative exit.

**Out of scope**: see Known Intentional Limitations.

---

## Visual Accessibility

| Feature | Tier | Status | Commitment and source |
|---|---|---|---|
| Text contrast | Basic | Designed | Ink on pill at least 7:1 over the live backdrop (HUD AC-22, Menus MN-11; nominal 14.5:1) |
| Non-text contrast | Standard | Designed | Rings and outlines at least 3:1 (Lagoon on Rim White about 5.8:1) |
| Text size | Basic | Designed | Labels at least 14 sp, state labels at least 16 sp; sp equals dp (OS scaling not honoured) |
| Colour independence | Basic | Designed | No state or hazard told apart by colour alone; audit below |
| Colourblind-safe setting | Standard | Designed, consumer not yet built | `colorblind_safe_enabled` lifts the ball's luminance (Environment F3); one toggle, not per-deficiency modes. Shown only once wired (ADR-0011) |
| Flash safety | Basic | Designed | See "Flash budget" |
| Reduced motion | Standard | Designed, consumers not yet built | `reduced_motion_enabled`: seam contrast scale to 0, Ink fade 0.30 s instead of 0.18 s, flash, shard and bloom intensity scaled by 0.5, UI motions removed. Hit-stop never changes (Juice Rule 10). Shown only once wired |
| Brightness, UI scaling, high contrast, subtitles | n/a | Not in scope | Android system brightness; no voiced content |

### Flash budget (WCAG 2.3.1)

- Global cap: at most 3 flashes per second across seam, Hit, near-miss ring and Ink cut, enforced at runtime by one shared 1.0 s ledger (Juice Rule 11).
- Hit flash: a single flash per Hit, at most 30% opacity (`HIT_FLASH_OPACITY` ceiling), about 0.033 s (`HIT_FLASH_S`, about 2 frames at 60 Hz).
- Ink cut: registers one ledger entry per cut and is never throttled; its entry can hold a near-miss flash below threshold, never the reverse.
- Seam: 2.08 Hz at defaults (cap 3 Hz, `SEAM_HZ_MAX`).
- Under reduced motion all flash opacities are multiplied by `REDUCED_MOTION_INTENSITY_SCALE` (0.5).

### Colour-as-only-indicator audit

| Location | Colour signal | Meaning | Non-colour backup | Status |
|---|---|---|---|---|
| Ball vs hazard (default) | Cobalt vs red (same luminance 0.08) | Safe vs lethal | Silhouette (round vs angular, art bible section 3); the colourblind-safe ball luminance lift | Needs simulator check |
| Hazard vs tube | Red vs sage | Lethal | Luminance contrast at least 4:1 (binding), silhouette | Designed |
| Pickup vs tube | Lagoon | Collectible | Pickup/tube contrast at least 3:1; shape not yet specified | Gap: confirm a shape cue |
| Hit grey-out | Killer keeps chroma, world desaturated | Which hazard killed | Run over banner text, luminance preserved, killer isolated | Designed |
| Near-miss ring | White pulse | Near miss | NEAR_MISS haptic, FOV punch | Designed |
| HUD states | Lagoon vs Ink | Armed, locked, sensor | Shape, opacity, text labels (HUD Accessibility table) | Designed |

---

## Motor Accessibility

| Feature | Tier | Status | Commitment and source |
|---|---|---|---|
| One-hand play | Beyond Basic | Designed | Pillar 4: one thumb; Pause top-right, inset 40 dp from the gesture edge |
| Tilt sensitivity | Beyond Basic | Designed | `tilt_sensitivity` 0.5 to 2.0 for limited wrist range |
| Touch targets | Basic | Designed | At least 48 dp, at least 8 dp apart, activate on release inside; restart target is the full screen |
| Alternative exit | Basic | Designed | Android Back pauses in Running (Platform Services) |
| Timed input | Basic | Designed | No input has a time limit except gameplay itself |
| Hold, rapid, remap | n/a | Not applicable | No hold or rapid inputs; one steering axis, no bindings |

---

## Cognitive Accessibility

| Feature | Tier | Status | Commitment and source |
|---|---|---|---|
| Pause anywhere in a run | Basic | Designed | Pause button and Back in Running; Resuming countdown, no instant resume |
| Difficulty options | n/a | Intentionally fixed | Fairness is Pillar 2; difficulty comes from Pattern tiers; see limitations |
| Information load | Basic | Designed | HUD: at most 4 groups visible in the worst Hit state (UX-4) |

---

## Auditory Accessibility

- No voiced content; no subtitles needed.
- Three Juice cues (near-miss whoosh, hit sting, personal-best cue) each have a visual and haptic equivalent; **no gameplay-critical information is audio-only or haptic-only**.
- Volume controls: not specified (no audio ADR yet); see Open Questions.

---

## Platform Accessibility API (Android)

| API | Planned | Status |
|---|---|---|
| TalkBack through AccessKit (Godot 4.5+) | Names, descriptions and live announcements through one helper `UiAccess` (ADR-0011 section 7) | Unverified; spike UI-A1 records full, partial or none, with device and TalkBack version, and re-runs on every Godot upgrade. No acceptance criterion depends on it until then |
| Gesture navigation and cutouts | Safe area, edge insets | HUD UX-12 |
| Keyboard, switch, D-pad focus | Buttons are `FOCUS_NONE` (ADR-0005) | Open: see Open Questions |

---

## Per-Feature Accessibility Matrix

| System | Concern | Addressed |
|---|---|---|
| Tilt Input, Ball Movement | Motor: tilt is the only steering | Partial (sensitivity; exclusion logged) |
| Tube Track, Environment | Visual: seam and motion, fog, chroma | Yes (reduced motion, flash cap, contrast floors) |
| Obstacle, Pattern | Visual: hazard identification | Yes (luminance and silhouette) |
| Juice & Feedback | Photosensitivity, motion | Yes (ledger, caps, reduced scale) |
| Camera | Motion: FOV punch | Open: reduced-motion behaviour of the punch not stated |
| HUD, Menus | Targets, contrast, text size | Yes |
| Settings | Surfaces the five settings | Yes |
| Platform Services | Haptics, Back | Yes |
| Others (Scoring, Save, Run State, Near-Miss) | None | n/a |

---

## Accessibility Test Plan

| Feature | Method | Pass criteria | Owner |
|---|---|---|---|
| Text and non-text contrast | Measure on device screenshots (HUD AC-22, Menus MN-11) | 7:1 on pills, 3:1 on outlines | qa-tester |
| Colour independence | Coblis simulation of gameplay screenshots, toggle on and off | Ball, hazard and pickup distinguishable in all simulated modes | ux-designer |
| Flash safety | Frame capture of Hit, Ink cut, seam and near-miss at 60 and 120 Hz, analysed against WCAG 2.3.1 | At most 3 flashes per second, below general and red thresholds | qa-lead |
| Reduced motion | Walk every screen and a 2-minute run with the toggle on | Listed consumers all respond; hit-stop unchanged | qa-tester |
| Touch targets | Measure on the HUD device matrix | At least 48 dp, 8 dp spacing | qa-tester |
| One-hand play | Playtest with one thumb, 10 runs | Completable without a second hand | producer |
| TalkBack | Spike UI-A1 | Tier recorded | ui-programmer |

---

## Known Intentional Limitations

| Feature | Why not included | Risk | Mitigation and target |
|---|---|---|---|
| Non-tilt steering (touch drag) | Tilt is the core input (game concept) | Players who cannot tilt cannot play | `tilt_sensitivity`; touch-drag steering post-MVP |
| OS text scaling and in-game text size | Fixed dp layout in the MVP | Low-vision players | Post-MVP "Text size" setting multiplying fonts from the single Theme (ADR-0011) |
| Left-handed layout, HUD repositioning | HUD Open Question 5 | Grip comfort | Post-MVP |
| Screen reader | AccessKit on Android unverified | Blind players | Spike UI-A1 decides |
| Keyboard, switch, D-pad navigation | Buttons are `FOCUS_NONE` | Switch-access users | Menus Open Question 1 |
| Difficulty assist | Pillar 2 fairness; fixed Pattern tiers | Some players find it too hard | None planned |
| Per-deficiency colourblind modes, high contrast | One toggle in the MVP | Partial coverage | Evaluate after the simulator check |

---

## Audit History

| Date | Auditor | Type | Scope | Findings | Status |
|---|---|---|---|---|---|
| none yet | | | | | |

---

## Open Questions

| # | Question | Owner | Resolve when |
|---|---|---|---|
| 1 | Is a pre-launch photosensitivity notice shown (template Basic item)? Where does it live in the Menus flow? | user, ux-designer | Before `/gate-check pre-production` |
| 2 | Volume controls and the audio policy owner (no audio ADR yet) | audio-director | With the audio ADR |
| 3 | Does reduced motion soften the FOV punch? Juice and Camera GDDs are silent | game-designer | Next `/design-review` of Juice |
| 4 | Menus controls: `FOCUS_CLICK` with a focus style, or stay `FOCUS_NONE` (ADR-0011 Open Question 1) | user | Before the Menus views are built |
| 5 | Pickup shape cue (colour audit gap) | art-director | Environment epic |
| 6 | Is the Ink cut's term added to Juice F1's flash budget? | game-designer | Next `/design-review` |
| 7 | `reduced_motion_enabled` and `colorblind_safe_enabled` have no wired consumers yet; the toggles stay hidden until they do | ui-programmer | Settings screen story |
