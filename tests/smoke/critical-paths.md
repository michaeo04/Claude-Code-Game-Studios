# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes on a real Android device before any QA hand-off.
**Run via**: `/smoke-check` (reads this file)
**Update**: add an entry when a core system is first implemented. Entries marked (pending) cannot be run until that system exists.

## Core Stability (always run)

1. The app launches to the Menu without a crash (release export, arm64).
2. A run can be started from the Menu by touch.
3. The Menu responds to every button without freezing.
4. Sending the app to the background and back (home button, then reopen) returns to a sane phase and does not crash.

## Core Mechanic (update per sprint)

5. (pending) Tilting the device moves the ball around the tube; no motion without tilt (BM-3).
6. (pending) A hit ends the run and shows the restart-locked Hit state; a tap after the lock restarts.
7. (pending) Pause and resume: the world freezes while paused and resumes without a jump.

## Data Integrity

8. (pending) A personal best survives closing and reopening the app.
9. (pending) A setting change (for example reduced motion) survives closing and reopening the app.

## Performance (target hardware: mid-tier Android)

10. (pending) No visible frame drops over a 2-minute run (60 FPS target, 16.6 ms frame).
11. (pending) No visible memory growth over 5 minutes of play (ceiling 512 MB).
12. (pending) A run longer than 90 seconds shows no world pop at the render-origin rebase (ADR-0013, PRC-1).

## Sprint 1 toolchain smoke (no playable build yet; see production/qa/qa-plan-sprint-1-2026-10-03.md)

13. (pending) `python tools/ci/run_ci.py --only lint` exits 0 and `python -m unittest discover -s tools/ci/tests` passes.
14. (pending) `godot --headless --path . --import` runs with no `SCRIPT ERROR` or `Parse Error` (also proves `project.godot` loads on 4.7.2).
15. (pending) `python tools/ci/run_ci.py --only unit` runs, the JUnit XML reports more than zero tests and zero failures.
16. (pending) A `GameRoot` with fake systems runs the fixed per-frame order (spy test) and a `RunStateCore` runs start, hit, restart headless.
