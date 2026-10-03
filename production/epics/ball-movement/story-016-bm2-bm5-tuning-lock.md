# Story 016: BM-2 dodge 180 and BM-5 POSITION vs RATE (tuning lock)

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 4 h plus playtest time
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md` (BM-2, BM-5; F5a)
**Requirement**: `TR-ball-movement-021`, `TR-ball-movement-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (device evidence); ADR-0002: Game loop (secondary)
**ADR Decision Summary**: Device/playtest evidence under `production/qa/evidence/`. BM-2 blocks only locking the `OMEGA_MAX`/`BALL_LAG_TAU` defaults and BM-5 blocks locking the `MAPPING_MODE` default; neither blocks the first playable.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: BM-5 needs RATE mode reachable in a dev build via `BallConfig.MAPPING_MODE` (Story 007); sensor on device unverified until V-1.
**Control Manifest Rules (this layer)**:
- Required: BM-2 and BM-5 results recorded; defaults locked in `ball_config.tres` only after both.
- Forbidden: loosening `T_DODGE_180_MAX` or `T_VIS_MIN` on a miss; changing the shipped default without recording it.
- Guardrail: a BM-2 miss is a tuning finding for `OMEGA_MAX` and `tau`.

## Acceptance Criteria
- [ ] **BM-2 Dodge 180**: a synthetic steer step reaches `|e| <= 0.05` in 1.0667 s +-1 frame at 60 Hz; at least 3 testers, 20 cued 180 degree turns at `V_MAX`: cue to `|e| <= 0.05` p90 at most 1.5 s and median at most 1.40 s.
- [ ] **BM-5 POSITION vs RATE**: 10 testers, crossover, counterbalanced, a fixed 20-gate course, 3 runs per mode; switch to RATE only if at least 9 of 10 prefer it and it clears no fewer gates, otherwise keep POSITION (design default, not a statistical claim).
- [ ] Evidence `bm-2.md` and `bm-5.md` record the outcome and the resulting `ball_config.tres` decision (locked or retuned).

## Implementation Notes
Reuse the Story 013 recorder. Cue-to-arrival timing is computed from logged `theta`. If BM-2 misses, adjust `OMEGA_MAX`/`BALL_LAG_TAU` through `BallConfig` (Story 003 derived check still applies), then re-run.

## Out of Scope
- BM-4, BM-6, AC-32 (Story 017)

## QA Test Cases
- **BM-2**
  - Given: dev build at `V_MAX`, 3 testers
  - When: 20 cued 180 degree turns each
  - Then: p90 at most 1.5 s, median at most 1.40 s
  - Edge cases: synthetic step check first
- **BM-5**
  - Given: counterbalanced crossover course
  - When: 10 testers do 3 runs per mode
  - Then: preference and gates cleared recorded; rule applied exactly as written
  - Edge cases: 8 of 10 (p = 0.0547) does not switch the default

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/ball-movement/bm-2.md` and `bm-5.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 007, Story 013, Story 014
- Unlocks: locking `OMEGA_MAX`/`BALL_LAG_TAU`/`MAPPING_MODE` defaults; pattern-difficulty authoring against `T_DODGE_180`
