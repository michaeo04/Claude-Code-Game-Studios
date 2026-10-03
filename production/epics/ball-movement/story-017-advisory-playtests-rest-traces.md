# Story 017: Advisory checks (BM-4, BM-6) and recorded rest traces (AC-32)

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 4 h plus playtest time
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md` (BM-4, BM-6, AC-32)
**Requirement**: `TR-ball-movement-021`, `TR-ball-movement-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (advisory tests and device evidence)
**ADR Decision Summary**: Advisory checks report but never fail CI; recorded traces replayed through the real cores are integration tests under `tests/integration/`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: AC-32 consumes Tilt Input V-2 rest traces recorded on a device; its thresholds are frozen only after V-2. BM-6 needs real hazards (Pattern & Difficulty content).
**Control Manifest Rules (this layer)**:
- Required: BM-4 and BM-6 logged as ADVISORY; AC-32 replays recorded traces through TiltCore and BallCore, deterministic.
- Forbidden: promoting BM-4 to BLOCKING without the designation process in `production/qa/designated-gates.md`; fabricating traces.
- Guardrail: BM-4 logs involuntary drift in ball widths per degree of held tilt exploratively.

## Acceptance Criteria
- [ ] **AC-32 [I]** Recorded V-2 rest traces through TiltCore and BallCore: POSITION `max |theta|` at most 0.1 rad over 30 s and RATE within the F3 drift bound (thresholds frozen after V-2).
- [ ] **BM-4 Resolution feel** (ADVISORY): `TILT_FULL_SCALE` 25 vs 35 at `STEER_ARC` = PI, counterbalanced, 5 testers x 10 trials on a 2.5-width gap hold and a 180 degree reach; also logs involuntary off-neutral drift (ball widths per degree) during the gap hold; recommended addition: vary holding posture (seated / reclined / one-handed).
- [ ] **BM-6 Speed ramp** (ADVISORY, blocked by hazards): 10 novice runs; provisional pass: at least 7 of 10 reach `t_run` 30 s (15 u/s), mean "too fast" rating at most 2 of 5, `speed` at death logged.
- [ ] Evidence `bm-4.md` and `bm-6.md`; AC-32 test file committed with its traces under a fixtures folder.

## Implementation Notes
Traces are committed fixtures (small, no personal data) under `tests/integration/ball_movement/fixtures/`. If BM-4 shows drift consuming roughly a third or more of the fine-positioning clearance in a 2.5-width gap, raise it for a BLOCKING designation through creative-director and producer (do not self-designate).

## Out of Scope
- BM-2/BM-5 (Story 016); BM-1/BM-3 (Stories 014/015)

## QA Test Cases
- **AC-32**
  - Given: V-2 rest traces for POSITION and RATE
  - When: replayed through TiltCore and BallCore
  - Then: POSITION `max |theta|` at most 0.1 rad over 30 s; RATE within the F3 bound
  - Edge cases: trace shorter than 30 s rejected
- **BM-4 / BM-6**
  - Given: playtest protocol
  - When: trials run
  - Then: results and drift logged; no pass/fail gate
  - Edge cases: BM-6 waits for Pattern & Difficulty hazards

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/ball_movement/ball_movement_rest_traces_test.gd`; `production/qa/evidence/ball-movement/bm-4.md`, `bm-6.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 013; tilt-input spike V-2; pattern-difficulty hazards (BM-6)
- Unlocks: freezing AC-32 thresholds; Alpha tuning
