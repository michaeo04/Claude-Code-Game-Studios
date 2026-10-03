# Sprint 3 — 2026-11-02 to 2026-11-13

## Sprint Goal
Finish the logic of the Foundation persistence and settings systems and extend the Core: Save & Persistence (boot load, write path, failure handling, read validity, backup), Settings & Accessibility (SettingsCore complete), Tube Track window recycling and idle scroll, and the Tilt Input neutral capture and pipeline, all with passing unit tests.

## Capacity
- Total days: 10 working days. **Capacity re-based from observed velocity**: Sprint 1 (21 stories, 60 estimated hours) and Sprint 2 (18 stories, 54 estimated hours) were both closed completely, so the planning figure rises from 6 to 8 focused hours per day; it is still an assumption (the project owner's weekly hours were never stated, see owner-actions C4) and is revised again after this sprint
- Buffer (20%): 2.0 days (16 h)
- Available: 8.0 days (64 h)
- Planned: Must Have 46.5 h + Should Have 14.0 h = 60.5 h (Nice to Have 9.5 h only if the rest finishes early)

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| SP-003 | [SaveCore boot load, get_value and first launch](production/epics/save-persistence/story-003-boot-load-and-get-value.md) | agent (godot-gdscript-specialist) | 0.44 | Story 001, Story 002 | **AC-4 [C]** `get_value`/`set_value` round-trip for `[scoring]` and `[settings]` returns exactly what was stored; on any read failure the returned... |
| SP-004 | [set_value write path (temp, complete map, rename)](production/epics/save-persistence/story-004-write-path.md) | agent (godot-gdscript-specialist) | 0.44 | Story 001, Story 003 | **AC-6 [C]** One `set_value` synchronously calls `write_config(TMP_PATH, sections)` then `rename(TMP_PATH, REAL_PATH)` before returning; `sections`... |
| SP-005 | [Write failure handling and rate-limited logging](production/epics/save-persistence/story-005-write-failure-and-rate-limit.md) | agent (godot-gdscript-specialist) | 0.31 | Story 004; cross-epic: platform-services (`RateLimitedLog` story) | **AC-8 [C]** `write_config` returning false stops the sequence (`rename` never called), `set_value` returns false, one `WRITE_FAILED` is logged, an... |
| SP-006 | [Read validity, per-key fallback and error logging](production/epics/save-persistence/story-006-read-validity-and-error-logging.md) | agent (godot-gdscript-specialist) | 0.38 | Story 001, Story 003; GDD revision of F2/AC-10 (TR-012 open point) | **AC-10 [C]** (reworded to ADR-0007, one log per load for rows 1-2): (1) `PARSE_ERROR` -> every requested key returns its default, one `FILE_UNREAD... |
| SP-007 | [Corrupt-file backup, rotation and oversize guard](production/epics/save-persistence/story-007-corrupt-backup-and-oversize-guard.md) | agent (godot-gdscript-specialist) | 0.38 | Story 003, Story 004 (Story 006 recommended first for the codes) | **AC-15 [C]** On a `PARSE_ERROR` load, `rename` moves the old file to `save.cfg.corrupt-<wall_clock()>-<n>` before any new write; two events on the... |
| ST-003 | [Boot-time tilt sensitivity validation and logging](production/epics/settings-accessibility/story-003-boot-sensitivity-clamp.md) | agent (godot-gdscript-specialist) | 0.25 | Story 001, Story 002 | **AC-3** The three no-correction rows (1.5, 0.4, 2.6) produce zero `log_sink` calls; each of the six corrected rows produces exactly one `SETTING_C... |
| ST-004 | [Typed getters and seam_contrast_scale, no seam access after construction](production/epics/settings-accessibility/story-004-getters.md) | agent (godot-gdscript-specialist) | 0.19 | Story 001, Story 002 | **AC-8** After construction (five `get_value_seam` calls), calling each of the six getters, `get_seam_contrast_scale()` included, at least 10 calls... |
| ST-005 | [set_value writes on change, no-ops on equal, emits setting_changed once](production/epics/settings-accessibility/story-005-set-value-write-and-event.md) | agent (godot-gdscript-specialist) | 0.38 | Story 002; Story 002 (the GDD Core Rule 5 amendment is done) | **AC-9** `set_value("haptics_enabled", false)` with current `true`: `set_value_seam` is called exactly once with `("settings","haptics_enabled",fal... |
| ST-006 | [Runtime tilt sensitivity validation and unknown-key rejection](production/epics/settings-accessibility/story-006-runtime-validation-unknown-key.md) | agent (godot-gdscript-specialist) | 0.31 | Story 001, Story 003, Story 005 | **AC-12** `set_value("tilt_sensitivity", 5.0)` from an in-range current value (fixture MAX 2.6): memory becomes 2.6; `set_value_seam` is called onc... |
| ST-007 | [Failed write keeps the in-memory value](production/epics/settings-accessibility/story-007-write-failure.md) | agent (godot-gdscript-specialist) | 0.12 | Story 005 | **AC-14** With `make_set_value_stub(succeeds := false)`, `set_value("reduced_motion_enabled", true)` from `false`: `set_value_seam` is called once... |
| ST-008 | [No consumer seams, closed call surface and determinism](production/epics/settings-accessibility/story-008-isolation-determinism.md) | agent (godot-gdscript-specialist) | 0.25 | Story 005, Story 006, Story 007 | **AC-15** The full `_init` parameter list is exactly the six names above; nothing consumer-shaped is accepted, so an added unused seam fails. |
| TT-006 | [advance(s) and synchronous recycling](production/epics/tube-track/story-006-tubewindow-advance-recycling.md) | agent (godot-gdscript-specialist) | 0.31 | Story 005 | **AC-8** `begin_run()` from Idle: window -2..9, exactly one `window_primed(-2, 9)` then one `state_changed(Running, Idle)`, no `segment_*`; `advanc... |
| TT-007 | [Re-entrancy guard, binder contract and idempotent begin_run](production/epics/tube-track/story-007-tubewindow-reentrancy-guard.md) | agent (godot-gdscript-specialist) | 0.25 | Story 005, Story 006 | **AC-20** `begin_run()` called twice in a row emits two `window_primed(-2, 9)`, the window holds 12 unique slots and s = 0. A handler connected to... |
| TT-008 | [Idle scroll step and deterministic segment content](production/epics/tube-track/story-008-idle-scroll-and-content-determinism.md) | agent (godot-gdscript-specialist) | 0.31 | Story 002, Story 005 | **AC-17** `TubeMath.idle_step(s_idle, v_idle = 1.5, dt, t_lat = 0.1, L = 12)`: dt = 1/60 adds 0.025; dt = 0.5 adds 0.15 (clamped); dt = -1, NaN, IN... |
| TT-009 | [300 s deterministic window simulation](production/epics/tube-track/story-009-window-simulation-300s.md) | agent (godot-gdscript-specialist) | 0.25 | Story 006, Story 007, Story 008 | **AC-21** 300 s at 25 u/s, dt = 1/64 (19,200 frames) with a camera double publishing `rear_extent = 6`: on every frame the far edge (far edge of se... |
| TI-005 | [Neutral capture mechanics and pending capture](production/epics/tilt-input/story-005-neutral-capture.md) | agent (godot-gdscript-specialist) | 0.44 | Story 002, Story 003, Story 004 | **AC-12 [C]**: a fresh core fed 60 polls where the pose is 5 for every stamp up to `t - 250000` and 30 after, then `run_reset` from Menu at `t`: `p... |
| TI-006 | [Pipeline order and the published output contract](production/epics/tilt-input/story-006-pipeline-output-contract.md) | agent (godot-gdscript-specialist) | 0.38 | Story 005 | **AC-2b [C*]**: with `live_core(0)`, a pose 10 deg above neutral gives `steer > 0` with sign +1 and `< 0` with -1. |
| TI-007 | [Capture policy, conditional re-anchor and run-stop recording](production/epics/tilt-input/story-007-capture-policy-reanchor.md) | agent (godot-gdscript-specialist) | 0.44 | Story 002, Story 005 | **AC-16 [C]** (unless a case says otherwise: `live_core(5)`, 5 polls at pose 5, `on_run_stopped()`, 60 polls at the stated pose, `run_reset` at the... |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| PS-003 | [HapticsConfig validation and shipped defaults](production/epics/platform-services/story-003-haptics-config.md) | agent (godot-gdscript-specialist) | 0.31 | Story 001, Story 002 | **AC-7 [C]** One row per knob; an out-of-range value gives one `KNOB_CLAMPED` and the boundary gives none: `HAPTIC_MIN_INTERVAL` -0.01 and 0.51 bec... |
| PS-004 | [PlatformCore lifecycle model and edge signals](production/epics/platform-services/story-004-core-lifecycle.md) | agent (godot-gdscript-specialist) | 0.44 | Story 002 | **AC-1 [C]** Signals per event for `fis` false and for Android (`fis` true) rows as in the GDD: `fis` false: `FO,P,FI,R` gives INT / BG / - / FG,RE... |
| PS-005 | [PlatformCore haptic call flow, drop causes and counters](production/epics/platform-services/story-005-core-haptics.md) | agent (godot-gdscript-specialist) | 0.38 | Stories 001, 003, 004 | **AC-4 [C]** HIT at stamp 0 plays (`vibrate` receives 80, 1.0); NEAR_MISS at 30000 drops (`THROTTLED`, `last_played_us` unchanged), at 79999 drops... |
| BM-007 | [RATE mapping (F3) and the mapping-mode latch](production/epics/ball-movement/story-007-rate-mode-latch.md) | agent (godot-gdscript-specialist) | 0.31 | Story 005, Story 006 | **AC-14 [C]** (F3) RATE: steer 1 from rest at 1/60 gives `w` 0.727605 and `phi` 0.0063437 (1e-7); 0.1 s at 30 / 60 / 120 Hz gives 0.153998 (1e-6);... |
| BM-008 | [Reset conformance, log-code census and bit-identical determinism](production/epics/ball-movement/story-008-reset-logs-determinism.md) | agent (godot-gdscript-specialist) | 0.31 | Story 005, Story 006, Story 007 | **AC-1 [C]** (R1, R9) A fresh core has `theta`, `theta_prev`, `s`, `s_prev`, `t_run`, `omega`, `phi_anchor`, `w` and the held steer at 0, `speed` 1... |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria (first) |
|----|------|-------------|-----------|-------------|-------------------|
| PS-006 | [PlatformCore Back signal and display facts](production/epics/platform-services/story-006-core-back-display-facts.md) | agent (godot-gdscript-specialist) | 0.31 | Story 004 | **AC-9 [C]** (R5) Each `on_back_requested()` emits exactly one BACK in all four lifecycle states, changes no getter, never calls `quit`, and replay... |
| TI-008 | [Availability states, start timeout and availability signal](production/epics/tilt-input/story-008-availability-states.md) | agent (godot-gdscript-specialist) | 0.31 | Story 004, Story 006 | **AC-28 [C]**: `sensors_enabled = false` gives Live with `FALLBACK` (debug) or Unavailable (release), each with one `SENSORS_DISABLED` error and no... |
| ST-009 | [Architecture and coupling lint for SettingsCore and SettingsMath](production/epics/settings-accessibility/story-009-architecture-lint.md) | agent (godot-gdscript-specialist) | 0.25 | Story 002 (source files exist); test-harness-ci epic (lint runner) | **AC-18** A static scan of `SettingsCore` and `SettingsMath` finds zero matches for `ConfigFile`, `FileAccess`, `DirAccess`, `Input.`, `DisplayServ... |
| SP-008 | [Flush no-op and SaveService node wiring](production/epics/save-persistence/story-008-flush-and-save-service-node.md) | agent (godot-gdscript-specialist) | 0.31 | Story 003, Story 004, Story 005 | **AC-7 [C]** `flush()` with nothing pending produces zero seam calls (a future async rewrite that adds a race fails this AC). |

## Carryover from Previous Sprint
None. Sprint 1 closed 21 of 21 and Sprint 2 closed 18 of 18 stories (`production/sprints/sprint-1.md`, `sprint-2.md`). Open items that are not stories: see `production/owner-actions.md`.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Save & Persistence write path (SP-004) is the riskiest logic: temp-then-rename atomicity is only provable on the real file system (SP-1, device) | Medium | Medium | The stories use the `FakeSaveFs` seam; the real `SaveFs` and the device spikes are Sprint 4+ and owner-actions B3 |
| `TubeWindow.load_map` returns failure codes while `architecture.md` says bool (owner-actions E9) | Low | Low | Reconciled when the Map Loader stories land |
| Tilt Input stories (neutral capture, pipeline order) carry many cross-field ACs | Medium | Medium | Stories stay Ready until every AC is proven; the buffer absorbs one slipped story |
| No independent code review of `src/core/` yet (review budget was spent on architecture) | Medium | Medium | Lint (68 rules) and 480+ tests are the gate; one `/code-review` pass over `src/core/` is the last task of this sprint |
| Agent runs can stop at their turn limit mid-story | Medium | Low | Stories stay Ready until proven; the parent re-runs CI before each commit |

## Dependencies on External Factors
- None for the logic stories (Godot 4.7.2 is installed at `C:/Users/candl/tools/godot-4.7.2/`).
- Device spikes and decisions that need the project owner are listed in `production/owner-actions.md`; none blocks this sprint.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-3-2026-10-04.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests (`python tools/ci/run_ci.py --only all`)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed (one `/code-review` pass over `src/core/`) and merged on `dev`
