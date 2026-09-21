# Systems Index: Tube Rush *(working title)*

> **Status**: Draft
> **Created**: 2026-09-19
> **Last Updated**: 2026-09-21
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Tube Rush is a mobile arcade endless-runner: a ball auto-runs along the outside
of a tube and the player tilts the phone to rotate around it and dodge obstacles
jutting from the surface. The mechanical scope is small but tightly coupled: a
movement model (angle plus forward speed), a fair and learnable obstacle stream
(Pillars 1 and 2), a rewarding near-miss loop (Pillar 3), one-axis tilt control
(Pillar 4), and cosmetic-only long-term progression (Pillar 5). Most of the
system count comes from small supporting systems (state, persistence, settings,
HUD, telemetry). The MVP proves the core loop on one map; further maps, pickups
and skins are content on top of it.

**Decisions taken while building this index (2026-09-19)**
- The tube is **straight** for the MVP; a curved (spline) tube is deferred.
- Obstacles come from a **hand-authored chunk library sequenced procedurally by
  difficulty weights**.
- The concept doc's second tier, formerly "Vertical Slice", is now **Content
  Expansion**. The pipeline's `/vertical-slice` is a production-quality build of
  the MVP scope, validated in Pre-Production; it is not a content tier.
- Per-map data uses a **`MapConfig` data contract** (see Circular Dependencies).

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Tube Track | Core | MVP | Approved | design/gdd/tube-track.md | — |
| 2 | Ball Movement | Gameplay | MVP | Not Started | — | Tube Track, Tilt Input, Run State & Restart |
| 3 | Tilt Input | Core | MVP | In Review (revised three times 2026-09-21; the third review was NEEDS REVISION with 6 blocking items addressed; no fourth document review: next are the `TiltCore` + `TiltRunAdapter` harness and the on-device spike) | design/gdd/tilt-input.md | — |
| 4 | Obstacle System | Gameplay | MVP | Not Started | — | Tube Track, Run State & Restart |
| 5 | Pattern & Difficulty (partly inferred) | Gameplay | MVP | Not Started | — | Obstacle System, Ball Movement, Tube Track, Run State & Restart |
| 6 | Near-Miss Detection | Gameplay | MVP | Not Started | — | Ball Movement, Obstacle System |
| 7 | Run State & Restart (inferred) | Core | MVP | Approved | design/gdd/run-state-restart.md | — |
| 8 | Scoring & Personal Best | Gameplay | MVP | Not Started | — | Run State & Restart, Ball Movement, Near-Miss Detection, Save & Persistence |
| 9 | Pickups & Boosters | Gameplay | Content Expansion | Not Started | — | Obstacle System, Ball Movement, Run State & Restart |
| 10 | Camera | Presentation | MVP | Not Started | — | Ball Movement, Tube Track, Run State & Restart |
| 11 | Juice & Feedback (partly inferred) | Presentation | MVP | Not Started | — | Near-Miss Detection, Run State & Restart, Scoring & Personal Best, Obstacle System, Camera, Settings & Accessibility, Platform Services, Tube Track |
| 12 | Environment & Theming (inferred) | Presentation | MVP | Not Started | — | Tube Track, Ball Movement |
| 13 | HUD (inferred) | UI | MVP | Not Started | — | Scoring & Personal Best, Run State & Restart, Near-Miss Detection |
| 14 | Menus & Screen Flow (inferred) | UI | MVP | Not Started | — | Run State & Restart, Scoring & Personal Best, Save & Persistence, Settings & Accessibility |
| 15 | Maps & Levels | Progression | Content Expansion | Not Started | — | Pattern & Difficulty, Scoring & Personal Best, Environment & Theming, Pickups & Boosters, Save & Persistence |
| 16 | Cosmetics & Unlocks | Progression | Content Expansion | Not Started | — | Scoring & Personal Best, Save & Persistence, Menus & Screen Flow |
| 17 | Game Modes | Gameplay | Alpha | Not Started | — | Ball Movement, Scoring & Personal Best, Maps & Levels |
| 18 | Save & Persistence (inferred) | Persistence | MVP | Not Started | — | Platform Services |
| 19 | Settings & Accessibility (inferred) | Persistence | MVP | Not Started | — | Save & Persistence, Tube Track (soft), Tilt Input (soft) |
| 20 | Platform Services (inferred) | Core | MVP | In Review (2026-09-21; first /design-review NEEDS REVISION with 9 blocking items, all applied the same day; no third full round, next are the `PlatformCore` harness and the device spike PS-1..PS-12) | design/gdd/platform-services.md | — |
| 21 | Playtest Telemetry (inferred) | Meta | MVP | Not Started | — | Run State & Restart, Scoring & Personal Best, Save & Persistence |

---

## Categories

| Category | Description | Systems |
|----------|-------------|---------|
| **Core** | Foundations everything depends on | Tube Track, Tilt Input, Run State & Restart, Platform Services |
| **Gameplay** | The systems that make the game fun | Ball Movement, Obstacle System, Pattern & Difficulty, Near-Miss Detection, Scoring & Personal Best, Pickups & Boosters, Game Modes |
| **Presentation** | How the game looks and feels moment to moment | Camera, Juice & Feedback, Environment & Theming |
| **UI** | Player-facing information | HUD, Menus & Screen Flow |
| **Progression** | Long-term growth (cosmetic only, per Pillar 5) | Maps & Levels, Cosmetics & Unlocks |
| **Persistence** | Save state and settings | Save & Persistence, Settings & Accessibility |
| **Meta** | Outside the core loop | Playtest Telemetry |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop on one map (Map 1). Without these you cannot test "is this fun and fair?" | First playable build | Design FIRST |
| **Content Expansion** | Extra maps, pickups and skins on top of a proven core loop. (Renamed from the concept doc's "Vertical Slice" tier to avoid confusion with the pipeline's `/vertical-slice`.) | After MVP | Design SECOND |
| **Alpha** | Remaining mechanical scope in rough form (extra game modes). | Alpha milestone | Design THIRD |
| **Full Vision** | Leaderboard/ghost race, "Roll & Build" depth, web version. Not enumerated as systems yet. | Beta / Release | Design as needed |

---

## Dependency Map

### Foundation Layer (no dependencies)
1. Tube Track — every coordinate (obstacles, ball, camera) lives on the tube
2. Tilt Input — the only control (Pillar 4); reads the phone's motion sensors (the source, gravity or accelerometer, is decided by the spike ADR)
3. Run State & Restart — state machine that nearly every system reacts to
4. Platform Services — haptics, app lifecycle, screen orientation

### Core Layer (depends on Foundation)
1. Ball Movement — depends on: Tube Track, Tilt Input, Run State & Restart
2. Obstacle System — depends on: Tube Track, Run State & Restart
3. Save & Persistence — depends on: Platform Services

### Feature Layer (depends on Core)
1. Near-Miss Detection — depends on: Ball Movement, Obstacle System
2. Pattern & Difficulty — depends on: Obstacle System, Ball Movement, Tube Track, Run State & Restart
3. Scoring & Personal Best — depends on: Run State & Restart, Ball Movement, Near-Miss Detection, Save & Persistence
4. Pickups & Boosters — depends on: Obstacle System, Ball Movement, Run State & Restart
5. Settings & Accessibility — depends on: Save & Persistence, Tube Track (soft: `seam_contrast_scale` reduced-motion hook), Tilt Input (soft: `sensitivity` hook)

### Presentation Layer (depends on Features)
1. Camera — depends on: Ball Movement, Tube Track, Run State & Restart
2. Environment & Theming — depends on: Tube Track, Ball Movement
3. Juice & Feedback — depends on: Near-Miss Detection, Run State & Restart, Scoring & Personal Best, Obstacle System, Camera, Settings & Accessibility, Platform Services, Tube Track
4. HUD — depends on: Scoring & Personal Best, Run State & Restart, Near-Miss Detection
5. Menus & Screen Flow — depends on: Run State & Restart, Scoring & Personal Best, Save & Persistence, Settings & Accessibility

### Polish Layer (depends on everything below)
1. Playtest Telemetry — depends on: Run State & Restart, Scoring & Personal Best, Save & Persistence
2. Maps & Levels — depends on: Pattern & Difficulty, Scoring & Personal Best, Environment & Theming, Pickups & Boosters, Save & Persistence
3. Cosmetics & Unlocks — depends on: Scoring & Personal Best, Save & Persistence, Menus & Screen Flow
4. Game Modes — depends on: Ball Movement, Scoring & Personal Best, Maps & Levels

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Tube Track | MVP | Foundation | game-designer, godot-specialist | L |
| 2 | Run State & Restart | MVP | Foundation | game-designer | S |
| 3 | Tilt Input | MVP | Foundation | game-designer, godot-specialist | L |
| 4 | Platform Services | MVP | Foundation | godot-specialist | S |
| 5 | Ball Movement | MVP | Core | game-designer, systems-designer | L |
| 6 | Obstacle System | MVP | Core | game-designer, systems-designer, level-designer | L |
| 7 | Save & Persistence | MVP | Core | godot-specialist | S |
| 8 | Near-Miss Detection | MVP | Feature | game-designer, systems-designer | M |
| 9 | Pattern & Difficulty | MVP | Feature | level-designer, systems-designer | L |
| 10 | Scoring & Personal Best | MVP | Feature | game-designer | M |
| 11 | Settings & Accessibility | MVP | Feature | ux-designer, accessibility-specialist | S |
| 12 | Camera | MVP | Presentation | game-designer, godot-specialist | M |
| 13 | Environment & Theming | MVP | Presentation | art-director, technical-artist | S |
| 14 | Juice & Feedback | MVP | Presentation | game-designer, sound-designer, technical-artist | M |
| 15 | HUD | MVP | Presentation | ux-designer | S |
| 16 | Menus & Screen Flow | MVP | Presentation | ux-designer | S |
| 17 | Playtest Telemetry | MVP | Polish | godot-specialist | S |
| 18 | Pickups & Boosters | Content Expansion | Feature | game-designer | M |
| 19 | Maps & Levels | Content Expansion | Polish | level-designer, art-director | M |
| 20 | Cosmetics & Unlocks | Content Expansion | Polish | game-designer | S |
| 21 | Game Modes | Alpha | Polish | game-designer | M |

Effort: S = 1 session, M = 2-3 sessions, L = 4+ sessions (one session is one
focused design conversation producing a complete GDD). Roughly, 5 MVP systems are
L. Small systems ("lite") can have short GDDs; all 8 required sections still apply.

---

## Circular Dependencies

- **Maps & Levels <-> Pattern & Difficulty / Scoring & Personal Best / Environment
  & Theming**: each map needs its own obstacle chunk set, scoring style and
  palette, but those systems also need to know the map configuration.
  **Resolution:** a `MapConfig` data contract. Pattern & Difficulty, Scoring and
  Environment & Theming each document the `MapConfig` fields they read in their own
  GDD; Maps & Levels aggregates them and never calls back into those systems. Map 1
  is authored in the same format from the start.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Tilt Input | Technical | Only control; never tested on a phone. `docs/engine-reference/godot/modules/input.md` is pinned to 4.6 with no accelerometer content, and 4.7 renumbered input device IDs. | 0.5-1 day on-device spike before any tilt Tuning Knobs are written; add accelerometer notes to the engine reference. |
| Camera | Design / Technical | Lagged rolling orbit was accepted by 1 internal tester with keyboard input only; "sense of speed" with a static tube is unproven. | Keep the prototype as reference; validate on a real device in the vertical slice. |
| Obstacle System + Pattern & Difficulty | Design | Hidden-side obstacles ("fair surprise") strain Pillars 1 and 2; no quantified rule exists yet. | Define a quantified telegraph and death-cause rule before the Obstacle GDD; playtest early. |
| Pattern & Difficulty | Scope | Chunk library authoring effort (producer estimate: 1-3 week swing). | Start with a small chunk set and fix the data format early. |
| Tube Track | Technical | Endless streaming and pooling versus <=150 draw calls and 512 MB on mobile. | Performance spike on a target device; straight tube only for MVP. |
| Platform Services / budgets | Technical | No target devices, load budget or thermal fallback defined. | Choose target devices in Technical Setup. |

---

## Notes for GDD Authors

- Art bible Sections 1-4 (`design/art/art-bible.md`) are locked: hazards are the
  loudest element, shape before color, juice stays in the cool/white channel, no
  screen shake, restart in under 1 s. GDDs must not contradict them.
- **Obstacle System GDD** must define the quantified rule for hidden-side
  obstacles and how the player learns what killed them (killer hazard stays
  isolated on death).
- **Tilt Input GDD**: run the on-device spike first; do not lock tuning values
  derived from keyboard testing (`CAMERA_FOLLOW_SPEED` 3.0, angular speed 3.0
  rad/s, forward speed 6.0 u/s are prototype starting points only).
- **Platform Services GDD (designed 2026-09-21, revised after its design review)**: owns the OS app-lifecycle notifications and exposes
  `app_backgrounded` / `app_foregrounded` (names provisional) for Tilt Input, the
  portrait lock, the keep-screen-on call, and the Android sensor project settings (Tilt Input rules 3 and 9).
  On Android it ignores `PAUSED/RESUMED` and uses `FOCUS_OUT/IN` only; Tilt Input's settle must count only
  while `attentive` (Platform Services Open Question 24).
- **HUD and Menus & Screen Flow GDDs**: forward the touch half-screen fallback hold
  to Tilt Input only while Running and only for a touch that began after `run_started` (no-sensor phones), gate Play, Resume and Restart on
  `valid` (swallow the tap-anywhere restart in Hit with a "sensor not ready" cue), show the "no motion sensor" notice, tell "reconnecting" from "no motion sensor", and give the sensor-lost pause screen
  a way to the Menu (Tilt Input rules 10 and 11, UI Requirements).
- **Scoring & Personal Best GDD**: decide how a run played with Tilt Input's
  `input_source` `FALLBACK` (touch hold, a different control scheme) is flagged
  (Tilt Input Open Question 27).
- **Save & Persistence, Juice & Feedback, Menus & Screen Flow, Camera, HUD and Settings
  GDDs**: connect to Platform Services as listed in its Dependencies section (Save
  flushes on `app_backgrounded` and keeps it short; Juice calls `haptic(kind)` and never
  makes haptics the only cue; Menus handles `back_pressed` outside Running and owns
  `quit()`; Camera and HUD read the safe area; Settings supplies `haptics_enabled`).
- **Scoring, Pattern & Difficulty, Environment & Theming**: read per-map values
  through `MapConfig`. Each map will have its own theme, rewards and scoring style;
  only Map 1 is in scope now.
- **Pillar 5**: boosters are temporary and found in-run only; no permanent
  upgrades or purchasable advantages.
- Unresolved from the gate: weekly available hours are still unstated;
  GUT vs gdunit4 must be settled before Technical Setup.

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 21 |
| Design docs started | 4 |
| Design docs reviewed | 2 |
| Design docs approved | 2 |
| MVP systems designed | 4/17 |
| Content Expansion systems designed | 0/3 |

---

## Next Steps

- [x] Review and approve this systems enumeration
- [ ] Design MVP-tier systems first (use `/design-system [system-name]`), starting with Tube Track
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Validate the highest-risk systems with `/vertical-slice` before committing to Production
