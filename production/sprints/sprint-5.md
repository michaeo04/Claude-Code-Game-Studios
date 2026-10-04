# Sprint 5 — 2026-11-30 to 2026-12-11

## Sprint Goal
Build the Feature-layer logic (Scoring & Personal Best, Near-Miss Detection) on the real Foundation and Core, and continue the Obstacle System (collision test, hit reporting, hazard lifecycle) and the Run State leftovers, so that a scripted run produces a score, a personal best and near-miss events from the real cores.

## Capacity
- Total days: 10 working days at 8 planning hours per day (unchanged from Sprint 4)
- Buffer (20%): 2.0 days (16 h)
- Available: 8.0 days (64 h)
- Planned: Must Have 46.0 h + Should Have 14.0 h = 60.0 h (Nice to Have 11.5 h only if the rest finishes early)

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| SC-001 | [ScoreMath: floor score and strict new-best comparison](production/epics/scoring-personal-best/story-001-score-math.md) | agent (godot-gdscript-specialist) | 0.25 | None (the GUT framework, spike T-1, is owned by the test-framework work) | **AC-1** `ScoreMath.score(s)`: `0 -> 0`; `9.999 -> 9`; `10.0 -> 10`; `10.5 -> 10`; `1574.991 -> 1574`; `1575.008 -> 1575`; `777.3 -> 777`. A `round... |
| SC-002 | [ScoreCore construction, seams, boot read and accessors](production/epics/scoring-personal-best/story-002-score-core-construction.md) | agent (godot-gdscript-specialist) | 0.38 | Story 001; `SaveCore` (exists in `src/core/persistence/save_core.gd`) | **AC-9** Constructed against `make_save_stub(500)`, across N cycles of `on_run_reset()`, several `step()`s and a new-best ending, `get_value_seam`... |
| SC-003 | [step(): live score, frozen score and run reset](production/epics/scoring-personal-best/story-003-step-live-frozen-reset.md) | agent (godot-gdscript-specialist) | 0.31 | Stories 001, 002 | **AC-4** Feeding a scripted advancing `s` through `step()` once per tick publishes `current_score = floor(s)` on every tick, matching AC-1 per valu... |
| SC-004 | [step(): non-finite, negative, over-range and decreasing s](production/epics/scoring-personal-best/story-004-out-of-contract-s-guards.md) | agent (godot-gdscript-specialist) | 0.25 | Story 003; the ending assertions in AC-15 use story 005 (write the ending-dependent row... | **AC-15** `NAN` then `INF` via `s_seam` mid-session leave `current_score` at its last known-good value on every affected tick; an ending right afte... |
| SC-005 | [Run endings: finalize, new-best write and personal_best_updated](production/epics/scoring-personal-best/story-005-run-endings-and-personal-best-write.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 001, 002, 003; spike SP-3 (save-persistence epic) for the on-device write timing | **AC-7** Two parallel scenarios with an identical `s` script, one ending with `on_run_ended(run_id, hazard_id, run_time_ms)`, one with `on_run_aban... |
| SC-006 | [personal_best_passed: once-per-run live crossing](production/epics/scoring-personal-best/story-006-personal-best-passed.md) | agent (godot-gdscript-specialist) | 0.31 | Stories 003, 005 | **AC-20a** `personal_best` 500, `s` 499.5, 500.4, 501.2, 700: no fire at score 500, exactly one `personal_best_passed(500)` at the tick the score b... |
| NM-001 | [NearMissConfig, validation and test fixtures](production/epics/near-miss-detection/story-001-near-miss-config-and-fixtures.md) | agent (godot-gdscript-specialist) | 0.31 | None (cross-epic: test-harness-ci for GUT; obstacle-system story 002 fixture pattern) | AC-7 [K]: `NEAR_MISS_ANGLE_COEFF` = 0 or negative, and separately `NEAR_MISS_S_COEFF` = 0 or negative, each reject config load with one `NEAR_MISS_... |
| NM-002 | [NearMissMath near-zone expansion (F1-NM)](production/epics/near-miss-detection/story-002-near-zone-expansion.md) | agent (godot-gdscript-specialist) | 0.25 | Story 001; obstacle-system `ObstacleMath` F1/F2 (already in `src/core/obstacle/obstacle... | AC-1 [M]: for Graze 701, `theta_near = [-0.5358, 0.5358]` and `s_near = [99.2, 102.3]` to 1e-4; the near zone's angular span is exactly `w` (0.2358... |
| NM-003 | [Two-invocation swept test: HIT_ZONE and NEAR_MISS_CANDIDATE (F2 reused)](production/epics/near-miss-detection/story-003-swept-near-zone-test.md) | agent (godot-gdscript-specialist) | 0.38 | Story 002 | AC-3 [M]: Graze at `theta_prev -0.5, theta -0.45, s_prev 100.5, s 100.6`: `HIT_ZONE` false, `NEAR_ZONE` true, `NEAR_MISS_CANDIDATE` true (pure angu... |
| NM-004 | [F3-NM preflight validator: NEAR_ZONE_OVERLAP](production/epics/near-miss-detection/story-004-near-zone-overlap-validator.md) | agent (godot-gdscript-specialist) | 0.38 | Stories 001, 002 | AC-8 [M]: two pieces separated by exactly `GAP_MIN` (0.5896): near zones consume 0.2358 total, 0.3538 (60%) open, accepted; joint corner (`NEAR_MIS... |
| NM-005 | [NearMissCore per-hazard state and edge-triggered output](production/epics/near-miss-detection/story-005-near-miss-core-state-and-edge-output.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 001, 002, 003; cross-epic: obstacle-system story 007 (signal shapes), run-state... | AC-13 [C]: a hazard held in the near zone (not hit zone) for 5 stationary ticks (`dt_eff` 0) emits zero `near_miss_detected`; on tick 6, with the p... |
| NM-006 | [Hit overrides near-miss and same-tick order](production/epics/near-miss-detection/story-006-hit-override.md) | agent (godot-gdscript-specialist) | 0.25 | Story 005 | AC-11 [C]: tick 1 near zone (`was_in_near_zone` true), tick 2 `hit_reported`, tick 3 exit or release: no `near_miss_detected`. Multi-piece row (Spi... |
| OB-006 | [hidden() classification, hidden-content gate and exit rule (F4)](production/epics/obstacle-system/story-006-hidden-classification-and-exit-rules.md) | agent (godot-gdscript-specialist) | 0.44 | Story 003 | **AC-34 [M]** `hidden()` rows with `THETA_REF` 0 and `VISIBLE_ARC_HALF_WIDTH_TEST` PI/2: `(-0.3, 0.3)` not hidden; `(PI/2, 2.5)` not hidden (strict... |
| OB-007 | [ObstacleCore hazard bind and window lifecycle](production/epics/obstacle-system/story-007-hazard-bind-and-window-lifecycle.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 001, 002 | **AC-14 [K]** `hazards_for_segment` called twice for one index: the second call is rejected with one `DUPLICATE_SEGMENT_QUERY` error, the first bin... |
| OB-008 | [Release flag, run_reset handler and read accessors](production/epics/obstacle-system/story-008-release-flag-run-reset-and-accessors.md) | agent (godot-gdscript-specialist) | 0.31 | Story 007 | **AC-40 [C]** recording subscriber on a window 10..18 holding three hazards: (a) `window_primed(-2, 6)` publishes exactly one `hazard_released(id,... |
| RS-010 | [RunConfig validation and lock bounds](production/epics/run-state-restart/story-010-config-validation-lock-bounds.md) | agent (godot-gdscript-specialist) | 0.31 | Story 001 | **AC-14**: `LOCK_MIN` 0.45 and `LOCK_MAX` 0.60 with the default inside; a lock of 0.3 is clamped to 0.45 and 0.9 to 0.60; countdown 0.5 to 1.0; sta... |
| RS-011 | [Flash bound bot and contract doubles](production/epics/run-state-restart/story-011-flash-bound-contract-doubles.md) | agent (godot-gdscript-specialist) | 0.31 | Stories 003, 004, 005, 006, 008, 009, 010 | **AC-24** (BLOCKING): a bot on the injected clock at 60 fps hits at a fixed run time and restarts at the earliest allowed press (`press_us = hit_us... |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| SC-007 | [milestone_crossed, ScoringConfig and validate_milestones](production/epics/scoring-personal-best/story-007-milestones-and-scoring-config.md) | agent (godot-gdscript-specialist) | 0.38 | Stories 002, 003 | **AC-23** Thresholds `[100, 250]` with `s` 99, 101, 249, 251: `milestone_crossed(100)` once at the first tick the score reaches 100, `milestone_cro... |
| SC-008 | [Public surface, determinism and no side effects](production/epics/scoring-personal-best/story-008-surface-determinism-no-side-effects.md) | agent (godot-gdscript-specialist) | 0.38 | Stories 004, 005, 006, 007 | **AC-11b** `ScoreCore`'s non-underscore script-defined methods are exactly `step`, `on_run_reset`, `on_run_ended`, `on_run_abandoned`, `get_current... |
| NM-007 | [Release by reset suppression and same-tick bind and release](production/epics/near-miss-detection/story-007-reset-release-and-same-tick.md) | agent (godot-gdscript-specialist) | 0.25 | Story 005 | AC-28 [C]: two hazards in the near zone, not hit: `hazard_released(id, true)` emits nothing and discards the entry; `hazard_released(id, false)` em... |
| NM-008 | [Non-finite ball state is a no-op frame](production/epics/near-miss-detection/story-008-non-finite-state-guard.md) | agent (godot-gdscript-specialist) | 0.19 | Story 005 | AC-17 [C]: a tick with `theta = NaN` or `s = +inf` is a no-op (last known-good swept endpoint held), logs exactly one error, produces no `near_miss... |
| SP-009 | [Real SaveFs implementation and file round trip](production/epics/save-persistence/story-009-real-save-fs.md) | agent (godot-gdscript-specialist) | 0.44 | Story 004, Story 007, Story 008 | Round trip through the real `SaveFs` in a temp directory: `int`, `float`, `bool`, `String`, `Vector2` written by `write_config` read back by `read_... |
| ST-010 | [Shipped defaults and sensitivity range smoke check (ADVISORY)](production/epics/settings-accessibility/story-010-defaults-smoke.md) | agent (godot-gdscript-specialist) | 0.12 | Story 002 | **AC-21 (ADVISORY)** Shipped defaults match Core Rule 1: `haptics_enabled` true; `haptics_intensity` 1.0; `tilt_sensitivity` 1.0 (== `DEFAULT_SENSI... |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| OB-009 | [Level-triggered hit test with broad phase](production/epics/obstacle-system/story-009-level-triggered-hit-test.md) | agent (godot-gdscript-specialist) | 0.44 | Stories 003, 007 (and 008 for `run_id` capture) | **AC-16 [C]** Wall 301 bound, ball held at a stationary point inside its effective footprint (`theta_prev == theta`, `s_prev == s`, `dt_eff == 0`)... |
| OB-010 | [Determinism, no side effects and the engine-coupling lint](production/epics/obstacle-system/story-010-determinism-no-side-effects-and-lint.md) | agent (godot-gdscript-specialist) | 0.31 | Stories 007, 008, 009; test-harness-ci epic (lint runner) | **AC-23 [C]** two fresh `ObstacleCore` instances fed an identical 500-tick script (window signals interleaved with ball ticks, resets, no-ops, hits... |
| TI-011 | [Fallback input (unwired) and the state-transition table](production/epics/tilt-input/story-011-fallback-input.md) | agent (godot-gdscript-specialist) | 0.31 | Story 008, Story 009, Story 010 | **AC-33 [C]** (debug build, `sensors_enabled` false, one priming poll at stamp 0, then `dt = 1/16`): **33a** `fallback_source` returning +1 gives `... |
| ML-008 | [map_loader.gd driver and ResourceLoader lint](production/epics/map-loader/story-008-map-loader-driver-and-lint.md) | agent (godot-gdscript-specialist) | 0.38 | Story 006, Story 007; test-harness-ci epic (lint runner) | `src/core/map/map_loader.gd` (a thin driver, `RefCounted` or `Node` per the composition-root story) builds the real `load_definition` seam: `Resour... |

## Carryover from Previous Sprint
None. Sprint 4 closed all Must and most Should stories (see `production/sprints/sprint-4-status.yaml`). Carried over: CR-007 (needs the real Pattern, Camera, Juice, Scoring and HUD rows), OB-005 (GDD contradiction, owner-actions E17), BM-008 (device evidence), and the Sprint 4 Nice to Have stories that were not started.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Scoring writes the personal best synchronously through the real SaveCore (ADR-0007); SP-3 death-frame cost is a device spike | Medium | Low | Logic against `FakeSaveFs`; the device measurement stays on the owner list (B3) |
| Near-Miss depends on the Obstacle signals (`hazard_bound`, `hazard_released`, `hit_reported`) that OB-006 to OB-008 create | Medium | Medium | Obstacle stories come first in the sprint order; Near-Miss unit stories use strict spies for the signals |
| Pattern & Difficulty is blocked on a design decision (owner-actions C6) | High | Low | Not in this sprint |
| TR-scoring-personal-best-003 (script reflection) is unverified on 4.7.2 | Medium | Low | Story SC-008 starts with the throwaway reflection check and has a pre-committed fallback |
| Agent runs stop at their turn limit mid-story | Medium | Low | Stories stay Ready until proven; the parent re-runs CI before each commit |

## Dependencies on External Factors
- None for the logic stories (Godot 4.7.2 is installed at `C:/Users/candl/tools/godot-4.7.2/`).
- Device spikes and decisions that need the project owner are listed in `production/owner-actions.md`; none blocks this sprint.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-5-2026-10-05.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests (`python tools/ci/run_ci.py --only all`)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed (one `/code-review` pass over `src/core/`) and merged on `dev`
