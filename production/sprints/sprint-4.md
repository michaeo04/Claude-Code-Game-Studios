# Sprint 4 — 2026-11-16 to 2026-11-27

## Sprint Goal
Close the contract gaps found by the code review (one log-sink contract, GameRoot wired to the real cores), then build the Map Loader (Phase A validation, Phase B apply order, failure and Retry), the Composition Root wiring (rebase contract, construction order, `_wire()` table) and the first Obstacle System stories, so that a scripted run can pass through the real Tilt, Ball, Tube Track, Run State and Obstacle cores in one integration test.

## Capacity
- Total days: 10 working days at 8 planning hours per day (re-based after Sprint 1 and 2; Sprint 3 closed 26 of 27 stories, the 27th waits for phone evidence)
- Buffer (20%): 2.0 days (16 h)
- Available: 8.0 days (64 h)
- Planned: Must Have 48.0 h + Should Have 15.5 h = 63.5 h (Nice to Have 15.0 h only if the rest finishes early)

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| CRF-001 | [One log-sink contract and one level enum for every core](production/epics/code-review-followups/story-001-unified-log-contract.md) | agent (godot-gdscript-specialist) | 0.44 | None | One `LogLevel` enum (DEBUG, INFO, WARNING, ERROR) and one sink signature `(level: int, code: StringName, key: String, message: String)` are defined... |
| CRF-002 | [GameRoot `_tick` against the real core APIs](production/epics/code-review-followups/story-002-game-root-tick-real-apis.md) | agent (godot-gdscript-specialist) | 0.50 | CRF-001 | `GameRoot._tick` uses the `dt_eff` returned by `RunStateCore.tick(world_dt, real_dt)` for everything downstream: Ball and Tube Track receive 0 in P... |
| CRF-003 | [Live tilt sensitivity update from Settings to TiltCore](production/epics/code-review-followups/story-003-live-sensitivity-update.md) | agent (godot-gdscript-specialist) | 0.31 | CRF-002 (the wiring pattern) | `TiltCore.set_sensitivity(value)` exists (validated against `TiltConfig` bounds, one `SETTING_CLAMPED` log when corrected, no effect on the ring bu... |
| CRF-004 | [Validate `haptics_intensity` in SettingsCore](production/epics/code-review-followups/story-004-haptics-intensity-validation.md) | agent (godot-gdscript-specialist) | 0.25 | None | A stored `haptics_intensity` outside the Platform Services range, or non-finite, is replaced by the nearest bound or the default at boot with one `... |
| ML-001 | [MapDefinition, MapConfig and loader seam types](production/epics/map-loader/story-001-map-types-and-seams.md) | agent (godot-gdscript-specialist) | 0.31 | test-harness-ci epic (GUT runnable); `EnvConfig` class from the environment-theming epi... | `MapDefinition`, `MapConfig` (all eight fields of ADR-0004 Key Interfaces), `MapLoaderCore.Status` (`NOT_LOADED`, `READY`, `FAILED`), `MapLoaderSea... |
| ML-002 | [HazardStyle validation and TubeConfig.from_map](production/epics/map-loader/story-002-hazard-style-and-tube-config-from-map.md) | agent (godot-gdscript-specialist) | 0.31 | Story 001; tube-track epic (`TubeConfig`); environment-theming epic (`EnvConfig.validat... | `HazardStyle` has the ADR-0014 fields (`height_d_wall`, `height_d_double_gate`, `height_d_near_ring` default 1.0 range 1.0 to 3.0; `height_d_spike`... |
| ML-003 | [MapConfig.build with Camera values and camera_far](production/epics/map-loader/story-003-camera-values-and-camera-far.md) | agent (godot-gdscript-specialist) | 0.31 | Story 001, Story 002; camera epic (`CameraMath.published`) for the real geometry shape | `MapConfig.build(...)` copies `map_id`, the validated `env`, the shared `chunk_library` (same instance, never copied) and the validated `hazard_sty... |
| ML-004 | [Phase A validation sequence](production/epics/map-loader/story-004-phase-a-validation.md) | agent (godot-gdscript-specialist) | 0.44 | Story 001, 002, 003 | A null result or missing path from `load_definition` gives `MAP_RESOURCE_MISSING`; a result that is not a `MapDefinition` gives `MAP_RESOURCE_TYPE`... |
| ML-005 | [Phase B apply order and map_ready](production/epics/map-loader/story-005-phase-b-apply-and-map-ready.md) | agent (godot-gdscript-specialist) | 0.31 | Story 004 | On success the seams are called exactly in the order env, obstacle, pattern, hazard view, tube load, then `send_map_ready` once, and `attempt()` re... |
| ML-006 | [Failure reporting, map_load_failed and Retry](production/epics/map-loader/story-006-failure-signal-and-retry.md) | agent (godot-gdscript-specialist) | 0.31 | Story 004, Story 005 | Any Phase A or Phase B failure sets `status = FAILED`, stores `last_codes`, and emits `map_load_failed` exactly once with the right code set (ADR-0... |
| CR-005 | [Rebase contract for views, reset wiring and soak](production/epics/composition-root/story-005-world-frame-rebase-contract.md) | agent (godot-gdscript-specialist) | 0.44 | Story 002, Story 003 | After a rebase every fake `TubeView` slot and `HazardView` node z equals a fresh placement with the new origin; the relative z between any two node... |
| CR-006 | [Construction order and the WorldGeometry/WorldFrame preflight](production/epics/composition-root/story-006-construction-order-and-validation.md) | agent (godot-gdscript-specialist) | 0.44 | Story 001, Story 003; map-loader epic (`WorldGeometry`), platform-services, save-persis... | A spy records the construction order and it equals the Decision 5 list, each step finishing before the next starts (ADR-0002 VC-2) |
| CR-007 | [`_wire()` row table and pinned subscriber order](production/epics/composition-root/story-007-wire-table-subscriber-order.md) | agent (godot-gdscript-specialist) | 0.44 | Story 006; run-state-restart epic (signals; fake until then) | Run State AC-30 passes against the real `GameRoot._wire()` table (ADR-0002 VC-1) |
| OB-001 | [Authored content classes, HazardSpec and HazardContentProvider](production/epics/obstacle-system/story-001-authored-content-classes-hazard-spec.md) | agent (godot-gdscript-specialist) | 0.44 | test-harness-ci epic (GUT runner), composition-root epic (project scaffold) | `HazardPiece` (`theta_min`, `theta_max`, `s_start`, `s_end`), `HazardPlacement` (`hazard_type`, `local_segment_index`, `pieces: Array[HazardPiece]`... |
| OB-002 | [ObstacleConfig, sweep-invariant validation and test fixtures](production/epics/obstacle-system/story-002-obstacle-config-and-test-fixtures.md) | agent (godot-gdscript-specialist) | 0.31 | Story 001; test-harness-ci epic | **AC-13 [K]** `SWEEP_INVARIANT_VIOLATED`: defaults (`OMEGA_MAX` 3.0, `DT_MAX` 0.1) validate with no log; joint safe-range maxima (4.0, 0.25, produc... |
| OB-003 | [Effective footprint (F1) and swept-rectangle overlap (F2)](production/epics/obstacle-system/story-003-footprint-expansion-and-swept-overlap.md) | agent (godot-gdscript-specialist) | 0.44 | Story 002 (fixture); tube-track epic (`delta_theta` F1) | **AC-1 [M]** Picket piece `(-0.05, 0.05, 200.0, 200.3)`: `theta_eff = [-0.1679, 0.1679]`, `s_eff = [199.6, 200.7]` (1e-4). Wall raw span 5.4578 giv... |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| CRF-005 | [SaveCore backup ordering and wall-clock robustness](production/epics/code-review-followups/story-005-save-backup-ordering.md) | agent (godot-gdscript-specialist) | 0.25 | None | Backup names are ordered by their numeric (timestamp, counter) pair, not as strings: 11 backups within one second rotate the oldest first. |
| CRF-006 | [Remove duplicated and hard-coded tuning values](production/epics/code-review-followups/story-006-duplicated-tuning-values.md) | agent (godot-gdscript-specialist) | 0.25 | None | `TiltCore.DT_MAX_US` and `TubeConfig.t_lat` read the single Run State `dt_max` source (injected value), not their own copies. |
| CRF-007 | [RunStateCore must not drop an app interrupt while busy](production/epics/code-review-followups/story-007-run-state-interrupt-while-busy.md) | agent (godot-gdscript-specialist) | 0.25 | None | An `app_interrupted` request that arrives while a handler is running is queued and applied after the current emission completes (or rejected determ... |
| ML-007 | [Author map_01.tres and its round-trip test](production/epics/map-loader/story-007-map-01-resource.md) | agent (godot-gdscript-specialist) | 0.31 | Story 004; environment-theming epic (`EnvConfig` fields and Map 1 values); pattern-diff... | `assets/data/maps/map_01.tres` exists with `map_id`, an inline `EnvConfig` carrying the Map 1 values (fog end 84, others from the environment-themi... |
| OB-004 | [Safe-gap sweep-line (F3) and hazard overlap validation](production/epics/obstacle-system/story-004-gap-sweep-line-and-hazard-overlap.md) | agent (godot-gdscript-specialist) | 0.44 | Story 003 | **AC-6 [C]** boundary at `GAP_MIN`: Wall raw gap 0.8254 rad (47.3 degrees) accepted (`open(s0) = GAP_MIN` to 1e-4, check is `>=`); 0.8253 rejected... |
| OB-005 | [Footprint, grace-zone, piece-count and spacing validators](production/epics/obstacle-system/story-005-footprint-limit-density-validators.md) | agent (godot-gdscript-specialist) | 0.44 | Story 003 | **AC-7 [K]** `FOOTPRINT_NOT_FINITE`: one row per field (`theta_min`, `theta_max`, `s_start`, `s_end`) x (`NaN`, `+inf`, `-inf`); each yields exactl... |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| TI-011 | [Fallback input (unwired) and the state-transition table](production/epics/tilt-input/story-011-fallback-input.md) | agent (godot-gdscript-specialist) | 0.31 | Story 008, Story 009, Story 010 | **AC-33 [C]** (debug build, `sensors_enabled` false, one priming poll at stamp 0, then `dt = 1/16`): **33a** `fallback_source` returning +1 gives `... |
| ML-008 | [map_loader.gd driver and ResourceLoader lint](production/epics/map-loader/story-008-map-loader-driver-and-lint.md) | agent (godot-gdscript-specialist) | 0.38 | Story 006, Story 007; test-harness-ci epic (lint runner) | `src/core/map/map_loader.gd` (a thin driver, `RefCounted` or `Node` per the composition-root story) builds the real `load_definition` seam: `Resour... |
| OB-006 | [hidden() classification, hidden-content gate and exit rule (F4)](production/epics/obstacle-system/story-006-hidden-classification-and-exit-rules.md) | agent (godot-gdscript-specialist) | 0.44 | Story 003 | **AC-34 [M]** `hidden()` rows with `THETA_REF` 0 and `VISIBLE_ARC_HALF_WIDTH_TEST` PI/2: `(-0.3, 0.3)` not hidden; `(PI/2, 2.5)` not hidden (strict... |
| CR-008 | [Boot rendering-method check through an injected getter](production/epics/composition-root/story-008-boot-rendering-method-seam.md) | agent (godot-gdscript-specialist) | 0.31 | Story 001; test-harness-ci (spike T-1 result for the headless value) | With the getter returning `"mobile"`, boot continues; with `"forward_plus"`, `"gl_compatibility"` or an empty string, boot is refused with a logged... |
| PS-008 | [PlatformServices node, notification mapping, thread rule and boot](production/epics/platform-services/story-008-node-notifications-boot.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 001, 004, 005, 006, 007 | **AC-19 [N]** `node.notification(X)` against a spy core: `APPLICATION_FOCUS_OUT`, `APPLICATION_FOCUS_IN`, `APPLICATION_PAUSED`, `APPLICATION_RESUME... |

## Carryover from Previous Sprint
None. Sprint 3 closed 26 of 27 stories (`production/sprints/sprint-4.md`). Carried over: BM-008, whose last acceptance criterion is advisory on-device timing evidence (owner-actions B7). Open items that are not stories: see `production/owner-actions.md`.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| The log-sink contract change (CRF-001) touches every module and test | High | Medium | Do it first, one module at a time with CI green after each; no new feature work in parallel on `src/core/` during that story |
| GameRoot wiring (CRF-002) needs adapters that the Tilt (TI-012) and Tube Track (TT-010) stories also describe | Medium | Medium | CRF-002 owns the code; the overlapping acceptance criteria in those stories are marked satisfied by it |
| `WorldGeometry` is still the CR-003 placeholder until ML-001 to ML-003 replace it | Medium | Low | Map Loader stories come before the Composition Root wiring in the sprint order |
| Obstacle System is the largest remaining Core epic (17 stories) | Medium | Medium | Only OB-001 to OB-005 are planned here; the rest is Sprint 5 |
| Agent runs stop at their turn limit mid-story | Medium | Low | Stories stay Ready until proven; the parent re-runs CI before each commit |

## Dependencies on External Factors
- None for the logic stories (Godot 4.7.2 is installed at `C:/Users/candl/tools/godot-4.7.2/`).
- Device spikes and decisions that need the project owner are listed in `production/owner-actions.md`; none blocks this sprint.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-4-2026-10-04.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests (`python tools/ci/run_ci.py --only all`)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed (one `/code-review` pass over `src/core/`) and merged on `dev`
