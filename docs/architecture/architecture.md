# Tube Rush (working title): Master Architecture

## Document Status

- Version: 0.1 (in progress, written incrementally by `/create-architecture`)
- Last Updated: 2026-10-02
- Engine: Godot 4.7.2, GDScript; Android only (ADR-0001); review mode `lean`
- GDDs covered: tube-track, run-state-restart, tilt-input, platform-services, ball-movement, obstacle-system, pattern-difficulty, near-miss-detection, scoring-personal-best, save-persistence, settings-accessibility, camera, juice-feedback, environment-theming, hud, menus-screen-flow (16 system GDDs) plus `design/ux/hud.md`, `design/ux/menus-screen-flow.md`, `design/ux/interaction-patterns.md`
- Technical Requirements Baseline: about 348 requirements (`TR-[slug]-[NNN]`) in `docs/architecture/tr-baseline/` (world-movement, gameplay, foundation, presentation-ui)
- ADRs referenced: ADR-0001 (Android only)
- Technical Director Sign-Off: pending
- Lead Programmer Feasibility: skipped (lean mode)

## Engine Knowledge Gap Summary

The LLM's knowledge covers Godot up to about 4.3; the project pins 4.7.2. Every API below that was added or changed after 4.3 is **HIGH RISK** and must be checked against `docs/engine-reference/godot/` (or a device spike) before an ADR relies on it.

| Domain | Risk | What changed after 4.3 | Systems affected |
|---|---|---|---|
| Rendering | HIGH | glow before tonemapping (4.6), shader preprocessor restrictions (4.7), Shader Baker (4.5), fog depth mode verified on Forward+ only (Mobile unverified) | Environment & Theming, Juice, Tube Track |
| UI | HIGH | dual-focus touch/keyboard (4.6), AccessKit screen reader (4.5), recursive Control disable (4.5), Android edge-to-edge | HUD, Menus & Screen Flow |
| Platform / Android | HIGH | lifecycle notifications under Vulkan (`PAUSED/RESUMED` may not fire), Back on Android 16 / SDK 36, 16 KB pages, OBB removed (4.7), safe area and refresh rate | Platform Services, Save & Persistence |
| Input | HIGH | device ID renumbering (4.7), `Input.get_gravity()` on Android, touch emulates mouse by default, sensor flags off in ProjectSettings | Tilt Input, HUD, Menus |
| Particles | HIGH | angular velocity corrected (4.7) | Juice (shard burst) |
| Core / GDScript | HIGH | variadics and `@abstract` (4.5), `duplicate_deep()` (4.5), `FileAccess.store_*` returns `bool` (4.4), signal argument coercion, `class_name` needs a class cache, `wrapf` collapses PI | all (`Core` classes), Save, Obstacle, Scoring |
| Physics | MEDIUM | Jolt default (4.6); collision here is analytic, so exposure is low | Obstacle System |
| Storage | MEDIUM | `ConfigFile`, `FileAccess`, `DirAccess` behaviour unverified on 4.7.2 | Save & Persistence |
| Camera, RNG, Animation, Navigation, Networking | LOW or unused | none material | Camera, Pattern |

## System Layer Map

Approved 2026-10-02.

```
┌─────────────────────────────────────────────────────────────────┐
│ PRESENTATION   Camera · Environment & Theming · Juice & Feedback│
│                HUD · Menus & Screen Flow                        │
├─────────────────────────────────────────────────────────────────┤
│ FEATURE        Pattern & Difficulty · Near-Miss Detection ·     │
│                Scoring & Personal Best                          │
├─────────────────────────────────────────────────────────────────┤
│ CORE           Tube Track · Tilt Input · Ball Movement ·        │
│                Obstacle System                                  │
├─────────────────────────────────────────────────────────────────┤
│ FOUNDATION     Run State & Restart · Platform Services ·        │
│                Save & Persistence · Settings & Accessibility ·  │
│                Composition Root · Map Loader                    │
├─────────────────────────────────────────────────────────────────┤
│ PLATFORM       Godot 4.7.2: Input, DisplayServer, OS lifecycle, │
│                Camera3D, Environment, GPUParticles3D,           │
│                CanvasLayer/Control, ConfigFile/FileAccess       │
└─────────────────────────────────────────────────────────────────┘
```

Decisions taken while mapping (user, 2026-10-02):

1. **Dependencies point downward only.** Tube Track and Obstacle System (Core) need values owned by Camera and Environment & Theming (Presentation): `rear_extent`, `camera_distance`, `VISIBLE_ARC_HALF_WIDTH`, fog and `F_read`. These travel as **configuration published at map load** (a MapConfig / derived-config data contract in Foundation that the Composition Root passes to the consumers), never as a runtime call from Core up to Presentation.
2. **Two modules have no GDD and are defined here, with ADRs, not new GDDs:** the **Composition Root / Game Loop** (owns construction order, the per-frame tick order, the pinned subscriber order, `process_mode` and `process_priority`) and the **Map Loader** (calls Tube Track `load_map`, sends `map_ready` to Run State only on success, retries on request). They hold no game rules. A row is added to `design/gdd/systems-index.md` for each.
3. **Settings & Accessibility sits in Foundation** (it stores preferences and depends only on Save & Persistence); its consumers read it by getter plus `setting_changed`.

## Module Ownership

[To be designed]

## Data Flow

[To be designed]

## API Boundaries

[To be designed]

## ADR Audit

[To be designed]

## Required ADRs

[To be designed]

## Architecture Principles

[To be designed]

## Open Questions

[To be designed]
