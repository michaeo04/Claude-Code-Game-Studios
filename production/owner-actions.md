# Owner Actions (things only the project owner can do or decide)

> Maintained by the assistant while it works autonomously. Each item names why it cannot be done by an agent and what unblocks. Newest groups first. Last updated: 2026-10-04.

## A. By hand, repository or account settings (explicit approval rules in `.claude/docs/git-workflow.md`)

| # | Action | Why it is yours | Blocks |
|---|---|---|---|
| A1 | Commit the SHA-512 of the official Godot 4.7.2 Linux archive into `tools/ci/versions.json` (`godot.sha512`). Candidate to compare: see `production/qa/evidence/test-harness-ci/t-1-gut-on-4-7-2.md` item 9 (`9aa00f7a...`). | ADR-0009: committed by hand so a tampered release cannot vouch for itself | CI workflow (TH-009), spike T-2 (TH-010) |
| A2 | After the first green CI run (T-2): decide whether the `ci` job becomes a required status check on `main`. | Repository setting | nothing technical |
| A3 | Merge `dev` into `main` (PR, merge commit, no squash) when you consider a milestone done; tag releases. | CLAUDE.md: explicit approval every time | release |
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
| E8 | `BallMath.wrap_angle` (`x - TAU * floor((x + PI) / TAU)`) duplicates the canonical `TubeMath.wrap_angle` (`fposmod` form with a `>= PI` guard). Delegating Ball to Tube Track breaks the Ball test `test_steer_negative_half_is_exact_negation` (the two forms differ in the last bit), so the duplicate stays. The GDD wants one canonical wrap; decide which form wins and update the other GDD and tests together | `src/core/ball_movement/ball_math.gd`, `tube_track/tube_math.gd` | Not a safe mechanical refactor |

## D. Resolved (kept so the history is visible)

- Godot binary on this machine: installed at `C:/Users/candl/tools/godot-4.7.2/` (2026-10-03).
- Spike T-1 (GUT on 4.7.2): done on Windows, evidence in `production/qa/evidence/test-harness-ci/`.
