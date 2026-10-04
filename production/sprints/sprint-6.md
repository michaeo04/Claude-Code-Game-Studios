# Sprint 6 — 2026-12-14 to 2026-12-25

## Sprint Goal
Finish the remaining headless Foundation and Core stories: Tilt Input wiring and adapters, Tube Track run-state integration, the PlatformServices node and its lint gates, Ball and Obstacle integration, the Map Loader driver and its wiring into GameRoot, and the Near-Miss and Scoring integration stories, so that everything that needs no phone is Complete and the remaining work is device evidence, views and design decisions.

## Capacity
- Total days: 10 working days at 8 planning hours per day (unchanged from Sprint 4)
- Buffer (20%): 2.0 days (16 h)
- Available: 8.0 days (64 h)
- Planned: Must Have 48.0 h + Should Have 14.0 h = 62.0 h (Nice to Have 16.5 h only if the rest finishes early)

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| TI-011 | [Fallback input (unwired) and the state-transition table](production/epics/tilt-input/story-011-fallback-input.md) | agent (godot-gdscript-specialist) | 0.31 | Story 008, Story 009, Story 010 | **AC-33 [C]** (debug build, `sensors_enabled` false, one priming poll at stamp 0, then `dt = 1/16`): **33a** `fallback_source` returning +1 gives `... |
| TI-012 | [TiltRunAdapter and the level-triggered sensor-lost pause](production/epics/tilt-input/story-012-tilt-run-adapter.md) | agent (godot-gdscript-specialist) | 0.44 | Story 007, Story 009, Story 010; run-state-restart (SceneTree-free core and its AC-8 ha... | **AC-39 [C]/[I]** (BLOCKING, built with Run State's real SceneTree-free core, a real `TiltCore` and injected `request_pause` and `phase_source`): *... |
| TI-013 | [TiltInput node, ProjectSettings and log sink](production/epics/tilt-input/story-013-tilt-input-node.md) | agent (godot-gdscript-specialist) | 0.44 | Story 001, Story 006, Story 008, Story 011; test-harness-ci; platform-services (manifes... | **AC-28 [I]**: the `TiltInput` node passes `sensors_enabled` from `ProjectSettings` (`input_devices/sensors/enable_gravity`) to the core in a scene... |
| TT-010 | [Run State adapter and map-load integration](production/epics/tube-track/story-010-run-state-adapter.md) | agent (godot-gdscript-specialist) | 0.38 | Story 004, Story 005, Story 006; run-state-restart epic (core and event names); map-loa... | (TR-024) With a real `TubeWindow` and a real `RunStateCore` (or its approved test double from the run-state-restart epic): `run_reset` leads to `be... |
| PS-008 | [PlatformServices node, notification mapping, thread rule and boot](production/epics/platform-services/story-008-node-notifications-boot.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 001, 004, 005, 006, 007 | **AC-19 [N]** `node.notification(X)` against a spy core: `APPLICATION_FOCUS_OUT`, `APPLICATION_FOCUS_IN`, `APPLICATION_PAUSED`, `APPLICATION_RESUME... |
| PS-009 | [CI lint for OS-call ownership (AC-12)](production/epics/platform-services/story-009-lint-ownership.md) | agent (godot-gdscript-specialist) | 0.31 | Story 008; test-harness-ci lint runner stories | **AC-12a [L]** `NOTIFICATION_APPLICATION_(FOCUS_IN/FOCUS_OUT/PAUSED/RESUMED)`, `NOTIFICATION_WM_GO_BACK_REQUEST`, `Input\.vibrate_handheld`, `Displ... |
| PS-010 | [CI manifest lint for project.godot and export preset (AC-13)](production/epics/platform-services/story-010-lint-manifest.md) | agent (godot-gdscript-specialist) | 0.38 | Story 007; test-harness-ci lint runner stories | **AC-13 [L]** Manifest lint (`tools/ci/` Python, driven by `PlatformSettings` entries: section, key, expected, owner tag). A missing key fails. By... |
| BM-010 | [Sign and driver-order integration with Tilt and Run State (AC-29, AC-31)](production/epics/ball-movement/story-010-sign-driver-order-integration.md) | agent (godot-gdscript-specialist) | 0.44 | Story 006, Story 008, Story 009; tilt-input (TiltCore + adapter stories); run-state-res... | **AC-29 [I]** (Tilt AC-40 gate; **the epic cannot close without it**) A test-only driver assembles tilt poll, flush, `tick`, ball step with real Ti... |
| OB-009 | [Level-triggered hit test with broad phase](production/epics/obstacle-system/story-009-level-triggered-hit-test.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 003, 007 (and 008 for `run_id` capture) | **AC-16 [C]** Wall 301 bound, ball held at a stationary point inside its effective footprint (`theta_prev == theta`, `s_prev == s`, `dt_eff == 0`)... |
| OB-010 | [Determinism, no side effects and the engine-coupling lint](production/epics/obstacle-system/story-010-determinism-no-side-effects-and-lint.md) | agent (godot-gdscript-specialist) | 0.31 | Stories 007, 008, 009; test-harness-ci epic (lint runner) | **AC-23 [C]** two fresh `ObstacleCore` instances fed an identical 500-tick script (window signals interleaved with ball ticks, resets, no-ops, hits... |
| OB-011 | [ContentPreflight P1, exhaustive and deterministic](production/epics/obstacle-system/story-011-content-preflight-p1-exhaustive.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 001, 004, 005, 006 | **AC-32 [K]** one fixture engineered to fail `FOOTPRINT_INVALID_ORDER` (a piece with `s_end < s_start`) and `NO_SAFE_GAP` elsewhere reports both re... |
| ML-008 | [map_loader.gd driver and ResourceLoader lint](production/epics/map-loader/story-008-map-loader-driver-and-lint.md) | agent (godot-gdscript-specialist) | 0.38 | Story 006, Story 007; test-harness-ci epic (lint runner) | `src/core/map/map_loader.gd` (a thin driver, `RefCounted` or `Node` per the composition-root story) builds the real `load_definition` seam: `Resour... |
| ML-009 | [Loader wiring order, map_load_failed to Menus, Retry Callable](production/epics/map-loader/story-009-wiring-and-menus-retry.md) | agent (godot-gdscript-specialist) | 0.38 | Story 008; composition-root epic (`GameRoot._wire()`); run-state-restart epic | A spy test records the `GameRoot` construction log and asserts the first `MapLoader.attempt` occurs after every `_wire()` row is connected and befo... |
| CR-008 | [Boot rendering-method check through an injected getter](production/epics/composition-root/story-008-boot-rendering-method-seam.md) | agent (godot-gdscript-specialist) | 0.31 | Story 001; test-harness-ci (spike T-1 result for the headless value) | With the getter returning `"mobile"`, boot continues; with `"forward_plus"`, `"gl_compatibility"` or an empty string, boot is refused with a logged... |
| CR-009 | [Composition-root lint rules and the import-before-test order](production/epics/composition-root/story-009-ci-lints-and-import-order.md) | agent (godot-gdscript-specialist) | 0.31 | test-harness-ci (lint runner and rule table); Story 001 | The lint finds no `_process`/`_physics_process` override outside `GameRoot`, no `[autoload]` entry, no `CONNECT_DEFERRED`, no `Engine.time_scale` w... |
| CR-010 | [Map load hand-off and loop start](production/epics/composition-root/story-010-map-load-handoff-and-loop-start.md) | agent (godot-gdscript-specialist) | 0.31 | Story 002, Story 006, Story 007, Story 008, Story 009; map-loader epic (loader seam; fa... | Order spy: `_construct`, `_wire`, `load_map` attempt, `map_ready` (on success), first `_process` tick; no tick before the load attempt (ADR-0002 De... |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| NM-009 | [Determinism and no side effects](production/epics/near-miss-detection/story-009-determinism-and-no-side-effects.md) | agent (godot-gdscript-specialist) | 0.31 | Stories 005-008 | AC-19 [C]: two fresh `NearMissCore` instances fed an identical 500-tick script (binds, releases, hits, no-op frames interleaved) produce bit-identi... |
| NM-010 | [Engine-coupling lint and reuse-not-reimplement guard](production/epics/near-miss-detection/story-010-lint-and-reuse-guard.md) | agent (godot-gdscript-specialist) | 0.31 | Stories 003, 005 | AC-21 [L]: over `NearMissMath`, `NearMissCore`, `NearMissConfig` and transitive dependencies none contains `CollisionObject3D`, `CharacterBody3D`,... |
| NM-011 | [Wire NearMissCore to real Ball, Obstacle, Run State and Juice](production/epics/near-miss-detection/story-011-integration-wiring.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 005-008; cross-epic: ball-movement, obstacle-system stories 006-007, run-state-... | AC-23 [I]: wiring to the real `BallCore` published `theta`, `theta_prev`, `s`, `s_prev` (all four already exposed by `src/core/ball_movement/ball_c... |
| SC-009 | [ScoreService driver and Run State wiring against a fake source](production/epics/scoring-personal-best/story-009-score-service-driver.md) | agent (godot-gdscript-specialist) | 0.31 | Stories 003, 005; `RunStateCore` signal shapes (exist in `src/core/run_state/run_state_... | **AC-19** A fake Run State source (`make_fake_run_state()` with only `run_reset(run_id)`, `run_ended(run_id, hazard_id, run_time_ms)`, `run_abandon... |
| SC-010 | [CI lints: identifier, deny-list and typed-binding scans](production/epics/scoring-personal-best/story-010-ci-lints.md) | agent (godot-gdscript-specialist) | 0.38 | Story 008; story 011 for the typed-binding row | **AC-10** (ADVISORY lint) Identifier-only scan of `score_math.gd` and `score_core.gd` finds zero `near_miss`, `NearMiss` or `NearMissDetection`-sha... |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| SC-011 | [Composition Root: construct, wire rows, tick call and milestone preflight](production/epics/scoring-personal-best/story-011-composition-root-wiring.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 007, 009; composition-root epic stories (`_construct`, `_wire`, rank constants... | Covers GDD Rules 11 and 7 (no standalone AC id): `_construct()` builds `ScoreCore`/`ScoreService` after `SaveService` and `SettingsCore` and togeth... |
| OB-012 | [ContentPreflight P2 pairs, P3 soak and the blocking CI test](production/epics/obstacle-system/story-012-content-preflight-p2-p3-sequencer-soak.md) | agent (godot-gdscript-specialist) | 0.44 | Story 011; pattern-difficulty epic (real `PatternCore` sequencer and compiled library);... | P2 detects `NO_SAFE_GAP`, `HAZARD_OVERLAP`, `TOO_DENSE`, `NEAR_ZONE_OVERLAP` across a chunk boundary and names both chunks and the padding used. |
| OB-013 | [GameRoot wiring and real-system integration](production/epics/obstacle-system/story-013-gameroot-wiring-integration.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 008, 009, 010; composition-root, ball-movement, tube-track, run-state-restart e... | **AC-25 [I]** with the real `BallCore` published state, the test runs exactly once per published pair, including after a large `real_dt` hitch (no... |
| SC-012 | [Integration: real SaveCore round trip (AC-21)](production/epics/scoring-personal-best/story-012-real-save-round-trip.md) | agent (godot-gdscript-specialist) | 0.31 | Stories 005, 011; save-persistence epic (`SaveCore`, fake `SaveFs`); spike SP-3 result | **AC-21** With a real `SaveCore` (not a stub) bound to `ScoreCore` through the actual seam implementation: a new best set by `on_run_ended` is read... |
| SC-013 | [Integration: real Ball Movement and Run State lifecycle (AC-22, AC-26)](production/epics/scoring-personal-best/story-013-real-run-state-and-ball-integration.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 005, 011; ball-movement and run-state epics (real cores exist); Juice and HUD r... | **AC-22** With real Ball Movement and Run State: `current_score` tracks the real `s` through a full lifecycle (reset, start, running, hit, restart)... |

## Carryover from Previous Sprint
None. Sprint 5 closed all Must Have stories and most Should Have stories (see `production/sprints/sprint-5-status.yaml`). Carried over: OB-005 (GDD contradiction, owner-actions E17), NM-006 (GDD wording, E18), BM-008 (device evidence), CR-007 (needs Pattern/Camera/Juice/HUD rows).

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| The PlatformServices node (PS-008) and the lints (PS-009, PS-010) touch engine APIs that are only provable on a device | Medium | Medium | Implement the thin node and the headless lints now; the device spikes PS-1/2/4/12 stay on the owner list (B2) |
| Map Loader driver (ML-008/009) uses `ResourceLoader` (allowed only in `map_loader.gd`) | Low | Low | Integration tests read `map_01.tres` from the project; the Android export remap is the device check ML-010 |
| Pattern & Difficulty remains blocked (owner-actions C6), so the Map Loader still loads an empty chunk library | High | Low | Not in this sprint; hazards for the M1 run come from fixtures |
| Agent runs stop at their turn limit mid-story | Medium | Low | Stories stay Ready until proven; the parent re-runs CI before each commit |

## Dependencies on External Factors
- None for the logic stories (Godot 4.7.2 is installed at `C:/Users/candl/tools/godot-4.7.2/`).
- Device spikes and decisions that need the project owner are listed in `production/owner-actions.md`; none blocks this sprint.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-6-2026-10-05.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests (`python tools/ci/run_ci.py --only all`)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed (one `/code-review` pass over `src/core/`) and merged on `dev`
