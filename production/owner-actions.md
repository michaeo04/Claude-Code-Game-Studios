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

## D. Resolved (kept so the history is visible)

- Godot binary on this machine: installed at `C:/Users/candl/tools/godot-4.7.2/` (2026-10-03).
- Spike T-1 (GUT on 4.7.2): done on Windows, evidence in `production/qa/evidence/test-harness-ci/`.
