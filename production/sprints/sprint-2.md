# Sprint 2 — 2026-10-19 to 2026-10-30

## Sprint Goal
Build the headless Core simulation on top of the Sprint 1 spine: Ball Movement (math, config, validation, tracking), the Tilt Input math and config, the Tube Track math and configuration, and the rest of the Run State phase machine (pause, resume, timers, stall guard), all with passing unit tests.

## Capacity
- Total days: 10 working days (same planning assumption as Sprint 1: one developer working with agents, about 6 focused hours per day; Sprint 1 delivered 21 of 21 stories in about two working sessions, so this assumption is probably conservative for agent-written logic and should be revised from real velocity)
- Buffer (20%): 2.0 days (12 h)
- Available: 8.0 days (48 h)
- Planned: Must Have 31.5 h + Should Have 13.0 h = 44.5 h (Nice to Have 13.0 h only if the rest finishes early)

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| BM-001 | [BallMath pure functions (wrap_angle, F1 step, F2 speed and S, F5 T)](production/epics/ball-movement/story-001-ball-math.md) | agent (godot-gdscript-specialist) | 0.58 | test-harness-ci (GUT vendored, spike T-1 passed) | **AC-5 [M]** (F1) `step(e, dt, tau)`: (1.0, 1/60, 0.06) 0.05; (0.1, 1/60, 0.06) 0.0242535; (-1.0, ...) -0.05; `tau` 0: `e` 0.03 gives 0.03, `e` 0.1... |
| BM-002 | [BallConfig resource, shipped defaults and test fixtures](production/epics/ball-movement/story-002-ball-config-fixtures.md) | agent (godot-gdscript-specialist) | 0.42 | test-harness-ci (GUT, scaffold) | `BallConfig` (`Resource`) exposes every Tuning Knob with its default: `STEER_ARC` PI, `BALL_LAG_TAU` 0.06, `OMEGA_MAX` 3.0, `MAPPING_MODE` POSITION... |
| BM-003 | [BallConfig.validated() clamps and the derived T_DODGE_180 check](production/epics/ball-movement/story-003-ball-config-validated.md) | agent (godot-gdscript-specialist) | 0.58 | Story 001, Story 002 | **AC-19 [K]** One row per knob, just outside gives one `KNOB_CLAMPED` and the boundary gives none: `STEER_ARC` 2.0 to 2.09 and 3.2 to PI; `tau` -0.... |
| BM-004 | [BallCore shell, reset and forward speed/distance integration](production/epics/ball-movement/story-004-ballcore-speed-distance.md) | agent (godot-gdscript-specialist) | 0.50 | Story 001, Story 002, Story 003 | **AC-21 [C]** (R7) `s` after 45 / 90 / 120 s is 618.75 / 1575 / 2325 (1e-6) at 30, 60 and 120 Hz and `speed` 17.5 / 25 / 25; the first 1/60 step gi... |
| BM-005 | [Position-mode tracking, dt_eff guards and held-steer semantics](production/epics/ball-movement/story-005-position-tracking-dt-steer.md) | agent (godot-gdscript-specialist) | 0.67 | Story 004 | **AC-2 [C]** (R1, R10) After a moving step (1/60, steer 0.5), one row per `dt_eff` in {0, -0.001, -inf, NaN, +inf}: `theta`, `s`, `speed`, `t_run`... |
| TI-002 | [TiltMath pure functions (roll, filter, mapping, median)](production/epics/tilt-input/story-002-tilt-math.md) | agent (godot-gdscript-specialist) | 0.58 | test-harness-ci (GUT runner, spike T-1) | **AC-1 [M]**: `roll_deg` of (6,-8,0) is 36.870; (3,0,-4) is 36.870; (0,-9.81,0) is 0; (+-9.81,0,0) is +-90; (4.248,-7.358,-4.905) is 25.66 (+-0.01)... |
| TI-003 | [TiltConfig resource, validation and sensitivity hook](production/epics/tilt-input/story-003-tilt-config.md) | agent (godot-gdscript-specialist) | 0.42 | Story 002 | **AC-4 [C]**: `FILTER_TAU` 0 or -1 in a loaded config is clamped to 0.02 with one `KNOB_CLAMPED` error. |
| TT-001 | [TubeMath frame, angle wrap and lane/facet formulas](production/epics/tube-track/story-001-tubemath-frame-angles.md) | agent (godot-gdscript-specialist) | 0.50 | test-harness-ci (GUT runner and `project.godot` scaffold) | **AC-1** `P` evaluated at (0,0,0), (PI/2,0,0), (PI,0,0.5), (0,50,0) gives (0,3,0), (3,0,0), (0,-3.5,0), (0,3,-50) (x and y from `local_point`, z fr... |
| TT-002 | [TubeMath segment index, window sizes and seam spacing](production/epics/tube-track/story-002-tubemath-segments-window-seams.md) | agent (godot-gdscript-specialist) | 0.42 | Story 001 (`TubeMath` file exists) | **AC-7** (F2) L = 12, N = 12: s = -24, -1, 0, 11.999, 11.999999999999998, 12, 24 give i = -2, -1, 0, 0, 0, 1, 2 and `slot(-1) = posmod(-1, 12) = 11`. |
| TT-003 | [TubeConfig resource and validate() failure-code set](production/epics/tube-track/story-003-tubeconfig-validation.md) | agent (godot-gdscript-specialist) | 0.58 | Story 001 (F7 `gap`), Story 002 (F3, F5 functions) | **AC-12** Base map (v_max 25, L 12, n_seams 1, t_lat 0.1, d_cam 8, depth fog, begin 44, curve 1.0, density 1.0, F_read = F, A required): F = 45.5 (... |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| RS-007 | [Pause, resume countdown, Paused guard and abandon](production/epics/run-state-restart/story-007-pause-resume-abandon.md) | agent (godot-gdscript-specialist) | 0.58 | Stories 002, 003, 004, 006 | **AC-15**: `progress_for(duration, elapsed)` and the core give (elapsed, remaining, digit, progress): 0 s: 2.0, 2, 0; 0.7 s: 1.3, 2, 0.35; 2.0 s: 0... |
| RS-008 | [Timers, stall guard and clock robustness](production/epics/run-state-restart/story-008-timers-stall-guard.md) | agent (godot-gdscript-specialist) | 0.58 | Stories 004, 006, 007 | **AC-2**: 2 timers x 6 phases = 12 cases: the countdown expiry acts only in Resuming (to Running, emits `run_resumed`); the lock expiry acts only i... |
| ST-002 | [SettingsCore construction, fixture factories and boot read](production/epics/settings-accessibility/story-002-core-construction-boot-read.md) | agent (godot-gdscript-specialist) | 0.58 | Story 001; test-harness-ci epic (GUT) | **AC-4** Construction calls `get_value_seam` exactly five times, once each for `("settings","haptics_enabled",true)`, `("settings","haptics_intensi... |
| SP-002 | [SaveFs facade, SaveConfig and test fixture](production/epics/save-persistence/story-002-save-fs-config-fixture.md) | agent (godot-gdscript-specialist) | 0.42 | None (cross-epic: test-harness-ci T-1) | **AC-23 [K, ADVISORY]** Shipped defaults match Tuning Knobs: `SAVE_LOG_RATE_LIMIT` = 1.0 s, `CORRUPT_BACKUP_RETENTION` = 5, `CURRENT_SCHEMA_VERSION... |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| BM-006 | [Anchor, resume re-base, 2 PI shift, published previous values and inertness](production/epics/ball-movement/story-006-anchor-resume-published-state.md) | agent (godot-gdscript-specialist) | 0.58 | Story 005 | **AC-4 [C]** (R10) 10 steps of 1/60, then 300 steps of `dt` 0 with changing steer, then 10 steps of 1/60: pose, `t_run` and `speed` are bit-identic... |
| TI-004 | [TiltCore poll, clock stamps and sample ring buffer](production/epics/tilt-input/story-004-tilt-core-poll-buffer.md) | agent (godot-gdscript-specialist) | 0.58 | Story 003; test-harness-ci | **AC-3 [C]**: for each of zero, NaN, INF, (0,-2.99,0) and (0,-1,0), a fresh core in Acquiring given that vector keeps `sample_count` 0 and stays Ac... |
| TT-005 | [TubeWindow state machine, priming and load_map](production/epics/tube-track/story-005-tubewindow-state-machine.md) | agent (godot-gdscript-specialist) | 0.58 | Story 002 (indices), Story 003 (`validate`), test-harness-ci | **AC-19** A table-driven test over all 40 (state, event) pairs: exactly the 16 listed pairs succeed with the listed next state; the other 24 are re... |
| RS-009 | [Same-tick request conflicts and order independence](production/epics/run-state-restart/story-009-same-tick-ordering.md) | agent (godot-gdscript-specialist) | 0.42 | Stories 005, 006, 007, 008 | **AC-18**: table-driven, one row per pair: hit + `pause(button)` gives Hit and one debug line for the pause; `pause(app_interrupted)` sent while a... |

## Carryover from Previous Sprint
None. Sprint 1 closed 21 of 21 stories (`production/sprints/sprint-1.md`). Open items that are not stories: see `production/owner-actions.md`.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| `tube_math.gd` is shared by the composition-root and tube-track epics (CR-004 created it with `local_point`) | Medium | Low | TT-001 extends the existing file; keep the `local_point` tests green; one agent at a time edits it |
| `WorldGeometry` is a placeholder from CR-003 until the map-loader epic replaces it | Medium | Medium | Not touched in this sprint; the map-loader stories are Sprint 3 |
| Ball Movement and Tilt Input ACs reference device-tuned values (BM-1, BM-3, V-1 spikes) | High | Low | Sprint 2 stories are logic with GDD default values; the feel gates stay on `production/owner-actions.md` B7 |
| No independent code review has been done on Sprint 1 code (review budget was spent on architecture) | Medium | Medium | Lint (68 rules) and 200 tests are the gate; one `/code-review` pass over `src/core/` is scheduled at the end of this sprint |
| Agent runs can stop at their turn limit mid-story | Medium | Low | Stories stay Ready until every acceptance criterion is proven; the parent re-runs CI before each commit |

## Dependencies on External Factors
- None for the logic stories (Godot 4.7.2 is installed at `C:/Users/candl/tools/godot-4.7.2/`).
- Device spikes and decisions that need the project owner are listed in `production/owner-actions.md`; none blocks this sprint.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-2-2026-10-04.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests (`python tools/ci/run_ci.py --only all`)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed (one `/code-review` pass over `src/core/`) and merged on `dev`
