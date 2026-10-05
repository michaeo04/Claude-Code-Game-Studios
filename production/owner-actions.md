# Owner Actions (things only the project owner can do or decide)

> Maintained by the assistant while it works autonomously. Each item names why it cannot be done by an agent and what unblocks. Newest groups first. Last updated: 2026-10-04.

## A. By hand, repository or account settings (explicit approval rules in `.claude/docs/git-workflow.md`)

| # | Action | Why it is yours | Blocks |
|---|---|---|---|
| A1 | Commit the SHA-512 of the official Godot 4.7.2 Linux archive into `tools/ci/versions.json` (`godot.sha512`). Candidate to compare: see `production/qa/evidence/test-harness-ci/t-1-gut-on-4-7-2.md` item 9 (`9aa00f7a...`). | ADR-0009: committed by hand so a tampered release cannot vouch for itself | CI workflow (TH-009), spike T-2 (TH-010) |
| A2 | After the first green CI run (T-2): decide whether the `ci` job becomes a required status check on `main`. | Repository setting | nothing technical |
| A3 | **M1 (headless simulation complete) was reached 2026-10-05**: decide whether to open the first `dev` to `main` PR (merge commit, no squash; `gh pr create --base main --head dev`). The assistant will not do it without your yes. Tag releases only at real releases. | CLAUDE.md: explicit approval every time | release |
| A4 | Android: create the first export preset and keystore handling, install a debug APK on your phones. | Needs your devices, signing secrets and accounts | all device spikes |
| A5 | Delete the merged remote branch `wip/run-state-core` (`git push origin --delete wip/run-state-core`). | git-workflow: deleting remote branches needs explicit approval | nothing (cosmetic) |

## B. Device and playtest evidence (needs your phones or your hands)

| # | Check | Story / ADR | Needs |
|---|---|---|---|
| B1 | R-1 renderer gate (Mobile vs Forward+): fog, draw calls, 60 FPS on two Android makers; **runs before any Environment, Hazard view or Ball view story** | ADR-0003, tube-track 013 | debug APK, two phones |
| B2 | PS-1, PS-2, PS-4, PS-12 lifecycle, Back on SDK 36, thread rule (PS-4 failing is a release blocker) | ADR-0006, platform-services 013-014 | phones, Android 13+ and 16 |
| B3 | SP-1 write survives a kill, SP-2 hostile-file sweep, SP-3 death-frame write latency | ADR-0007, save-persistence 011-013 | phone |
| B4 | PRC-1 rebase frame capture at 60 and 120 Hz | ADR-0013, composition-root 012 | phone, 120 Hz device |
| B5 | AU-1, AU-2 audio focus and `play()` latency | ADR-0015 | phones |
| B6 | MS-1 boot time, UI-1 dpi, UI-A1 TalkBack, HV-1 hazard prewarm, PT-1..PT-4 presentation time | ADR-0004, 0011, 0014, 0010 | phones |
| B7 | BM-1 and BM-3 feel checks (latency, unasked motion) for the first-playable gate; BM-6 novice playtest | `designated-gates.md`, Ball Movement GDD | playtesters |
| B8 | Linux headless run of Godot 4.7.2 (T-1 items 8-9) | ADR-0009 | any Linux host, or the first CI run |

## C. Design or art decisions that only you (or an art director) can sign

| # | Decision | Where |
|---|---|---|
| C1 | Ball legibility sign-off (art direction) before the Ball view story is Done | ADR-0012 OQ1 |
| C2 | Flat bridging band across the Double Gate gap, yes or no | `environment-theming.md` Open Question 7 |
| C3 | Whether to add an in-game volume control after the first playtest | ADR-0015 Decision 7 |
| C4 | Weekly working hours (Sprint 1 assumes 6 focused hours per day) | `production/sprints/sprint-1.md` |
| C5 | Technical-director review of ADR-0015 before the Juice audio stories | ADR-0015 (Proposed) |
| C6 | Pattern & Difficulty design review (asked by the technical director, ADR-0008, and by traceability TR-pattern-difficulty-011/-014): ADR-0008 Decision 6 generalises the cross-chunk spacing so the read history includes Spikes, which conflicts with GDD AC-12c / CR9 / F2c; no ADR names the carrier field that supplies `t_dodge_worst` to Tube Track. Stories PD-010, PD-011 and PD-014 are Blocked until the GDD is revised (a design decision, then the assistant can implement) | `design/gdd/pattern-difficulty.md`, `production/epics/pattern-difficulty/` | Needs a design decision |
| C7 | A second independent code review is needed to close two sign-off acceptance criteria: Near-Miss NM-010 (AC-21, AC-22a) and Obstacle OB-010 (AC-24). The first review (2026-10-04) covered only the modules that existed then. You capped independent reviews at three, so the assistant has NOT started one; say 'go' (or run `/code-review` on `src/core/near_miss` and `src/core/obstacle`) and it records the sign-off in `production/qa/` | `production/epics/near-miss-detection/story-010-*`, `obstacle-system/story-010-*` | Review budget |

## E. Decisions the assistant took on its own (confirm or overrule when you have time)

| # | Decision | Where | Why it was taken |
|---|---|---|---|
| E1 | At an exact half-turn error (`wrap_angle(PI)` is `-PI`), `BallCore` turns toward the sign of the raw error, so steer +1 from rest turns the right way | `src/core/ball_movement/ball_core.gd`, Ball Movement AC-3/7/8 | The ACs require it; the GDD does not state the tie rule. Consider one sentence in the GDD edge cases |
| E2 | The default `BALL_LAG_TAU` (0.06) breaks the 1.14 s `T_DODGE_180` ceiling when `OMEGA_MAX` is set to 2.75 (T about 1.154 s); the two omega-boundary tests use 0.03 | Ball Movement GDD F5a/Rule 13 | The GDD checks only the corners of the safe ranges; the derived check stays live. A tuning finding for the BM spike, not a code defect |
| E3 | The stall-pause clause of Run State AC-11 was moved from story RS-004 to story RS-008 AC-16 (the stall guard owner) | `production/epics/run-state-restart/` | Cannot be tested before the stall guard exists |
| E4 | `user://` cannot be matched by the lint (string literals are blanked by design); Run State purity is enforced through the absence of any file API instead | RS-001 AC-9 | Stripper design in ADR-0009 |
| E5 | No in-game volume or mute setting in the MVP | ADR-0015 Decision 7 | Needs a Settings GDD revision; device volume is the control |
| E6 | Settings Core Rule 5 now says a slider commits on `drag_ended`; Save F2/AC-10 now log a file-level failure once per load | `settings-accessibility.md`, `save-persistence.md` | ADR-0007 said so; GDD edited to match |
| E7 | Sprint capacity assumption of 6 focused hours per day (see C4) | sprint plans | Weekly hours were never stated |
| E8 | `BallMath.wrap_angle` (`x - TAU * floor((x + PI) / TAU)`) duplicates the canonical `TubeMath.wrap_angle` (`fposmod` form with a `>= PI` guard). Delegating Ball to Tube Track breaks the Ball test `test_steer_negative_half_is_exact_negation` (the two forms differ in the last bit), so the duplicate stays (since 2026-10-04 BallMath also carries the `r >= PI` edge guard, code review finding 6). The GDD wants one canonical wrap; decide which form wins and update the other GDD and tests together | `src/core/ball_movement/ball_math.gd`, `tube_track/tube_math.gd` | Not a safe mechanical refactor |
| E9 | `TubeWindow.load_map(cfg, v_max, d)` returns the failure-code array (the story and ADR-0004's validate-first design), while `architecture.md` API Boundaries and the Map Loader seam `tube_load(tube_cfg)` say `-> bool`. The Map Loader stories will wrap it (empty array = true); `architecture.md` section 2 should be edited to match when those land | `src/core/tube_track/tube_window.gd`, `architecture.md` | Story needs the codes |
| E10 | RESOLVED 2026-10-04 (CRF-001). Log-level enums disagreed: `SaveConfig.LEVEL_ERROR` is 2 while `RateLimitedLog.Level.ERROR` is 1 (and `RateLimitedLog` has no WARNING). Harmless today (each module uses its own), but one shared level enum would avoid a future mix-up | `src/core/persistence/`, `src/core/platform/rate_limited_log.gd` | Cosmetic, fix when a third consumer appears |
| E11 | `SettingsCore.set_value` coerces a wrong-typed value with `as bool` / `as float`; the Settings stories do not say what a wrong-typed value should do (reject and log vs coerce). A follow-up decision for the Settings GDD | `src/core/settings/settings_core.gd` | Story silent |
| E12 | Three modules now use three different log-level numbers (Save INFO=1/ERROR=2, Run State and Settings WARNING=1, RateLimitedLog DEBUG/ERROR). RESOLVED 2026-10-04 by story CRF-001: one `LogLevel` enum and one 4-argument sink in `src/core/log/`. (Time for one shared level enum (a small refactor story) | `src/core/` | E10 became real when Settings arrived |
| E13 | ADR-0005 Decision 1 says Tilt Input becomes Unavailable after the start timeout, but Tilt GDD AC-29/AC-48 keep Live `FALLBACK` when a sensor was never live (Unavailable only after it had been live). `TiltCore` follows the GDD; ADR-0005 wording should be amended to match. Also: polls are ignored between `on_app_backgrounded()` and `on_app_foregrounded()` (the GDD is silent) | `src/core/tilt_input/tilt_core.gd`, ADR-0005 | GDD ACs win over the ADR sentence |
| E14 | The three export-preset key names in `PlatformSettings` (`permissions/vibrate`, `screen/immersive_mode`, `graphics/picture_in_picture`) are guesses; confirm them against the real `export_presets.cfg` when you create the first Android preset (A4), or let the assistant read the file you create and correct them | `src/core/platform/platform_settings.gd`, platform-services story 011 | Cannot be verified without a preset |
| E15 | `TubeWindow.advance` calls the slot binder before emitting `segment_left_window`, so a left-handler sees the slot already re-bound. The Tube Track GDD says only 'left for the rearmost index first, then entered'. If views must react to 'left' with the old slot contents, the order should be left, bind, entered; change the GDD sentence and the code together | `src/core/tube_track/tube_window.gd`, `tube-track.md` | Code review finding 7; design question |
| E16 | `EnvConfig` (`src/core/map_loader/env_config.gd`) is a scalar-only STUB written by the Map Loader epic: its ranges (fog end and readable_distance positive and finite, `fog_depth_curve` clamped to 0.1..4.0) are invented by the implementing agent. The Environment & Theming epic must extend it in place from the Environment GDD; same for the camera 'in range' rule in `MapConfig.build` (positive, finite, `visible_arc_half_width <= PI`) which should come from `CameraMath` when the Camera epic exists | `src/core/map_loader/env_config.gd`, `map_config.gd` | No owner epic yet |
| E17 | Obstacle System GDD contradiction: AC-9 says a piece with `s 190..193` declared for segment 15 passes, but the Edge Cases rule requires the whole piece inside `[i*L, (i+1)*L)` and 193 is past 192 (L = 12). `ObstacleMath` implements full containment, so AC-9's row would be rejected; the test uses `190..191.5` as the passing row. Decide which statement is right and fix the GDD (story OB-005 stays Ready until then). Also `map_01.tres` holds an empty placeholder `ChunkLibrary`: the real Map 1 chunk content is design work (Pattern & Difficulty / level content), not yet authored | `design/gdd/obstacle-system.md`, `assets/data/maps/map_01.tres` | Needs a design decision and content |
| E18 | Near-Miss AC-12 says a hit wins 'regardless of order', but the tick order (ADR-0002) never delivers a hit after `NearMissCore.step` in the same tick; `NearMissCore` queues hits and releases and applies them inside `step`, so story NM-006 stays Ready on that one wording. Either relax AC-12 to the tick order the ADR fixes, or accept a late hit in a following tick. Also AC-14 ('exactly one emit at release') is implemented as release followed by `step`, and the AC-9 `[lo, hi]` ranges were read as effective theta spans | `design/gdd/near-miss-detection.md`, `src/core/near_miss/near_miss_core.gd` | GDD wording vs ADR tick order |

## D. Resolved (kept so the history is visible)

- Godot binary on this machine: installed at `C:/Users/candl/tools/godot-4.7.2/` (2026-10-03).
- Spike T-1 (GUT on 4.7.2): done on Windows, evidence in `production/qa/evidence/test-harness-ci/`.

- **B (device), PD-013:** run the golden sequence on the Android build and record it in `production/qa/evidence/pattern-difficulty/golden-sequence-android.md`. Headless parts (wiring, golden table) are done; the story stays Ready until this exists.

- **B (editor), OB-011:** run `tools/content_preflight_editor.gd` once in the Godot editor (File > Run) and confirm it reports without errors; it has no automated test, so OB-011 stays Ready until then.
- **Blocked, OB-012:** P2/P3 preflight needs `PatternCore._padding_segments_for` (PD-010, blocked on design review C6) and `assets/data/chunks/chunk_library_01.tres` (hidden-side content, see OB-017).

- **B (device), SP-2 / Save 011:** run the hostile-save battery (`tests/integration/save_persistence/save_persistence_hostile_files_test.gd` fixtures) on an Android export build and record it in `production/qa/evidence/save-persistence-sp2.md`; gate sign-off is yours. Desktop part is done (ConfigFile executed an attached script, so `PersistMath.has_object_constructor` now sniffs the file before parsing).
