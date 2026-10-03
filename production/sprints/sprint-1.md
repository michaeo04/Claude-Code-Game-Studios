# Sprint 1 — 2026-10-05 to 2026-10-16

## Sprint Goal
Prove the test harness on Godot 4.7.2 (spike T-1, vendored GUT, one green `run_ci.py --only unit`) and build the Foundation spine on top of it: `GameRoot` clock and tick driver, `WorldFrame`, and the Run State core with its phase machine, events and run clock, all covered by passing unit tests.

## Capacity
- Total days: 10 working days (assumption: one developer working with agents, about 6 focused hours per day; the weekly hours were never stated in the project, so this is a planning assumption to correct after the first week)
- Buffer (20%): 2.0 days (12 h) reserved for unplanned work
- Available: 8.0 days (48 h)
- Planned: Must Have 34.5 h + Should Have 12.0 h = 46.5 h (Nice to Have 13.0 h is only taken if Must and Should finish early)

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| TH-001 | [Verify project scaffold (project.godot, .gitattributes, .gdignore)](production/epics/test-harness-ci/story-001-verify-scaffold.md) | agent (godot-gdscript-specialist) | 0.33 | None | `godot --headless --path . --import` on the existing `project.godot` exits 0 with no `SCRIPT ERROR` / `Parse Error` / unknown-key warnings; any han... |
| TH-002 | [Spike T-1 - GUT on Godot 4.7.2](production/epics/test-harness-ci/story-002-spike-t1-gut-on-4-7-2.md) | agent (godot-gdscript-specialist) | 0.58 | Story 001 | Verification items 1-14 of ADR-0009 each have a recorded result (pass / fail / value) on Windows and Linux where the item is OS-relevant. |
| TH-003 | [Vendor GUT, .gutconfig.json, tests/support skeleton](production/epics/test-harness-ci/story-003-vendor-gut-and-support.md) | agent (godot-gdscript-specialist) | 0.42 | Story 002 | `addons/gut/` contains the exact release chosen in T-1, with its licence file, and no files outside the upstream tree. |
| TH-004 | [Verify and harden run_ci.py (entry command and result checks)](production/epics/test-harness-ci/story-004-verify-run-ci.md) | agent (godot-gdscript-specialist) | 0.50 | Story 002, Story 003 | `--only unit/integration/advisory/lint/all` each select exactly the documented steps; advisory failure is a warning, not a job failure. |
| TH-005 | [Harden the GDScript comment and string stripper](production/epics/test-harness-ci/story-005-harden-gdscript-stripper.md) | agent (godot-gdscript-specialist) | 0.50 | None (Python only) | Each construct listed above has a Python `unittest` case with an exact expected output (stripped text), including a string containing `#`, an escap... |
| CR-001 | [GameRoot clock injection and single tick driver](production/epics/composition-root/story-001-game-root-clock-and-tick-driver.md) | agent (godot-gdscript-specialist) | 0.42 | test-harness-ci (GUT runs, spike T-1) | `GameRoot` is a `Node` with `class_name GameRoot`, scene file sets `process_mode = PROCESS_MODE_ALWAYS` (ADR-0002 Decision 1) |
| CR-002 | [Fixed per-frame order in `_tick()` (spy test)](production/epics/composition-root/story-002-per-frame-tick-order.md) | agent (godot-gdscript-specialist) | 0.42 | Story 001 | The spy call log of one Running tick equals the section 6 order exactly, with `WorldFrame step` immediately after `TubeTrack.advance` and before `O... |
| CR-003 | [WorldFrame, WorldFrameConfig and the render-origin math](production/epics/composition-root/story-003-world-frame-core.md) | agent (godot-gdscript-specialist) | 0.58 | Story 001; map-loader epic (`WorldGeometry`; fake until then) | `render_z(s)` equals `-(s - origin_s)` in float64 for fixture values including `s` beyond 9e9 (ADR-0013 VC-1) |
| RS-001 | [RunStateCore skeleton, public API, signals and purity](production/epics/run-state-restart/story-001-core-skeleton-api.md) | agent (godot-gdscript-specialist) | 0.42 | test-harness-ci (GUT vendored, spike T-1 recorded, lint runner) | **AC-8**: the script's own signal list (`get_script().get_script_signal_list()`) is exactly `run_reset`, `run_started`, `run_paused`, `run_resuming... |
| RS-002 | [Phase machine, request queue and validation by phase](production/epics/run-state-restart/story-002-phase-machine-validation.md) | agent (godot-gdscript-specialist) | 0.58 | Story 001 | **AC-1**: the 6 phases x 7 requests table (46 cases with Hit locked/unlocked and Paused inside/after guard) accepts exactly 10 pairs and rejects 36... |
| RS-003 | [Event emission order, two-step start and re-entrancy guard](production/epics/run-state-restart/story-003-events-two-step-start.md) | agent (godot-gdscript-specialist) | 0.58 | Story 002 | **AC-3**: one table row per sequence asserts ordered events and arguments: Menu to Running `run_reset(n), run_started(n)`; Hit to Running `run_rese... |
| RS-004 | [tick(), run clock F1 and settling tick](production/epics/run-state-restart/story-004-tick-run-clock.md) | agent (godot-gdscript-specialist) | 0.42 | Story 002 | **AC-10**: after a run starts and its settling tick, 3600 ticks of `world_dt` = `real_dt` = 1/60 give `run_time` 60.0 (+/- 1e-3); `tick(0.3, 0.3)`... |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| RS-005 | [Hit acceptance, stale run_id and same-tick tie-break](production/epics/run-state-restart/story-005-hit-handling.md) | agent (godot-gdscript-specialist) | 0.42 | Stories 002, 003, 004 | **AC-7**: the first `request_hit(id, run_id)` emits `run_ended(run_id, id, run_time_ms)` exactly once and later hits are ignored; the next run ends... |
| RS-006 | [Restart lock, press_us handling and restart_unlocked](production/epics/run-state-restart/story-006-hit-lock-press-us.md) | agent (godot-gdscript-specialist) | 0.42 | Stories 002, 003, 005 | **AC-12**: with a hit at 10,000,000 and a lock of 500,000, presses at 10,499,000 (processed at 10,520,000) and 10,499,999 are rejected; 10,500,000,... |
| ST-001 | [SettingsMath (seam contrast derivation and tilt sensitivity validation)](production/epics/settings-accessibility/story-001-settings-math.md) | agent (godot-gdscript-specialist) | 0.42 | None (test harness: test-harness-ci epic, GUT installed) | **AC-1** `seam_contrast_scale(false)` == `1.0` exactly and `seam_contrast_scale(true)` == `0.0` exactly; each output asserted a member of `{0.0, 1.... |
| SP-001 | [PersistMath pure functions](production/epics/save-persistence/story-001-persist-math.md) | agent (godot-gdscript-specialist) | 0.42 | None (cross-epic: test-harness-ci spike T-1 must be passed so GUT runs) | **AC-1 [M]** `schema_compatible(v, 3)`: 0 -> false, -1 -> false, 1/2/3 -> true, 4 -> false; type-guard rows `"1"`, `true`, `[1]` -> false with no r... |
| PS-002 | [RateLimitedLog and log codes](production/epics/platform-services/story-002-rate-limited-log.md) | agent (godot-gdscript-specialist) | 0.33 | test-harness-ci story 002 (GUT confirmed on 4.7.2) | **AC-6 [R]** Log codes are exactly `UNKNOWN_HAPTIC_KIND`, `KNOB_CLAMPED`, `SETTINGS_MISMATCH` (error level) and `LIFECYCLE_NOOP` (debug). `RateLimi... |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| CR-004 | [`TubeMath.local_point` and the logical-frame reference](production/epics/composition-root/story-004-tube-math-local-point.md) | agent (godot-gdscript-specialist) | 0.33 | Story 003; tube-track epic (the `tube_math.gd` file; coordinate) | `local_point(theta, h)` equals the x and y of the GDD's `P` on a fixed fixture table: theta 0, PI/2, PI, -PI/2; h = 0, D/2, CAMERA_RADIUS - R (ADR-... |
| TH-006 | [Harden lint rule kinds and the registered rule table](production/epics/test-harness-ci/story-006-harden-lint-rule-kinds.md) | agent (godot-gdscript-specialist) | 0.67 | Story 005 | Every rule named in ADR-0009 Decision 5 and the manifest (forbid, only_in, project_setting, manifest, secret, custom lists) exists in `lint_rules.j... |
| PS-001 | [PlatformMath pure functions (haptic gate, effective, interval, fps)](production/epics/platform-services/story-001-platform-math.md) | agent (godot-gdscript-specialist) | 0.50 | test-harness-ci story 002 (GUT confirmed on 4.7.2, spike T-1) | **AC-3 [M]** `haptic_gate(enabled, attentive, dur, prio, now, last, last_end, last_prio, min_us)` returns the play/drop decisions listed in the GDD... |
| TH-007 | [Per-rule pass/fail fixtures and runner self-check](production/epics/test-harness-ci/story-007-per-rule-fixtures-and-self-check.md) | agent (godot-gdscript-specialist) | 0.67 | Story 005, Story 006 | For every rule in `lint_rules.json` there is a passing fixture (no finding) and a failing fixture (a finding with that rule id), discovered by nami... |

## Carryover from Previous Sprint
None (first sprint).

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| No Godot 4.7.2 binary on the dev machine (`run_ci.py` reports MISSING), so spike T-1 and every GDScript test cannot run | High | High | The project owner provides the Godot path (`GODOT` env var or `godot.local_path` in `tools/ci/versions.json`) on day 1; until then only the Python-only story TH-005 (and the Nice to Have TH-006, TH-007) can proceed |
| GUT does not run on 4.7.2 (T-1 fails) | Medium | Medium | Pre-committed response in ADR-0009: switch to gdUnit4, keep `tests/support/` unchanged and port the test files; budget the port inside the buffer |
| `project.godot` was written by hand and has not been opened in Godot 4.7.2 | Medium | Medium | TH-001 opens it once, commits what the editor rewrites, and re-runs the `project_setting` lints |
| `godot.sha512` is the project owner's by hand; CI stays manual-only until it exists | High | Low | Not needed for Sprint 1 (no CI trigger story is planned) |
| Estimates are agent-hours guesses with no velocity history | High | Medium | Review after the first week; the 20% buffer and the Should Have tier are the release valves |

## Dependencies on External Factors
- A Godot 4.7.2 executable on the dev machine (project owner, day 1).
- Network access to download the pinned GUT release for TH-003 (the release tag and commit are then recorded in `tools/ci/versions.json`).

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-1.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests (`python tools/ci/run_ci.py --only unit`)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged (on `dev`; the `dev` to `main` merge is a separate owner decision)

> ⚠️ **No QA Plan yet**: run `/qa-plan sprint` before the first implementation story (done as the next step of this session).
