# Code review of `src/core/` (2026-10-04)

> Independent read-only review by the `feature-dev:code-reviewer` agent over the 27 files of `src/core/` plus three files of `tests/support/`, at commit `c81fa7b` (738 unit tests green). It did **not** read the control manifest, the ADRs or the unit tests, so manifest conformance was not checked by it; the lint (68 rules) covers part of that. This is the single review pass planned in `production/roadmap-2026-10-04.md`.

| # | Severity | Finding | Disposition |
|---|---|---|---|
| 1 | HIGH | Log-sink contracts differ across modules: 2, 3 and 4 argument signatures, and level numbers that mean different things (1 is INFO in Save, WARNING in Run State/Settings/WorldFrameConfig, ERROR in `RateLimitedLog`) | **Story CRF-001** (Sprint 4, first) |
| 2 | HIGH | `GameRoot._tick` calls the cores with spy-friendly signatures (`ball.step(world_dt)`, `tube.advance(world_dt)`, ignores `RunState.tick`'s `dt_eff`); `tests/support/system_spy.gd` accepts any arguments so the tests cannot see it | **Story CRF-002** (Sprint 4, first). Expected gap: story CR-002 proved only the call order; the real wiring stories CR-006, CR-007, CR-010 and TI-012 were not built yet |
| 3 | MEDIUM | A Settings sensitivity change never reaches `TiltCore` (read only in `_init`) | **Story CRF-003** |
| 4 | MEDIUM | `haptics_intensity` is never validated (NaN or out-of-range stored in memory while Save rejects it) | **Story CRF-004** |
| 5 | MEDIUM | `PlatformCore` does not use `RateLimitedLog` (a per-frame unknown haptic kind would log every frame) | Folded into CRF-001 (composition root wraps the sink; verify it does) |
| 6 | MEDIUM | `BallMath.wrap_angle` lacks the `r >= PI` edge guard that `TubeMath.wrap_angle` has | **Fixed 2026-10-04** with a regression test (`ball_movement_math_test.gd`). Delegating to `TubeMath` is still not done (owner-actions E8) |
| 7 | MEDIUM | `TubeWindow.advance` re-targets the slot before emitting `segment_left_window`, so a handler sees the slot already bound to the new segment | GDD says only "left, then entered"; recorded as owner-actions E15 (design question), no change |
| 8 | LOW | Duplicated or hard-coded values: `TiltCore.DT_MAX_US`, `TubeConfig.t_lat`, sensitivity bounds in two places | **Story CRF-006** |
| 9 | LOW | `SaveCore` backup names sorted as strings (>10 per second misorders) and a wall clock of 0 or going backwards makes the newest backup look oldest | **Story CRF-005** |
| 10 | LOW | `RunStateCore._apply_app_interrupted` drops an interrupt silently while `_busy` | **Story CRF-007** |

Checked by the reviewer and found sound: Run State phase transitions and hit resolution, Ball anchor re-base and 2 PI shift, `WorldFrame.maybe_rebase`, `TubeWindow` jump re-prime, `TubeConfig` validation, `TiltCore` ring buffer, F6 hold and neutral capture, the `BallConfig` bisection. No unbounded loop found in `SaveCore` after the 2026-10-04 fix.
