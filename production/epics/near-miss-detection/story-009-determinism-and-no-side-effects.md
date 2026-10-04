# Story 009: Determinism and no side effects

> **Epic**: Near-Miss Detection
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-014`, `TR-near-miss-detection-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format; ADR-0002: Game loop, Composition Root and tick order; ADR-0009: Test framework and CI
**ADR Decision Summary**: No randomness anywhere in Near-Miss; it reads and calls nothing back, so identical scripted input gives bit-identical streams (ADR-0002: cores are pure RefCounted).
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Doubles record every call. No static mutable state in `NearMissCore`/`NearMissMath`, so two instances never share anything.
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [ ] AC-19 [C]: two fresh `NearMissCore` instances fed an identical 500-tick script (binds, releases, hits, no-op frames interleaved) produce bit-identical `near_miss_detected` streams (ids, order, tick indices); a third instance interleaved with them changes neither stream.
- [ ] AC-20 [C]: doubles for Ball Movement, Obstacle System and Run State record calls; replayed across the AC-11 to AC-19 scripts, none receives a call beyond the read-only accessors (`theta`/`theta_prev`/`s`/`s_prev`; the three inbound signals; `run_id`), and no mutating method is ever invoked.

## Implementation Notes
- The 500-tick script is a constant data file or factory in `tests/support/`, not inline magic numbers. Compare streams as arrays of `[tick, hazard_id, run_id]`.

## Out of Scope
- Story 010: lint of forbidden calls.

## QA Test Cases
- **AC-19**: see criterion above
  - Given: script of 500 ticks
  - When: run on cores A, B, interleaved C
  - Then: A == B == C streams
  - Edge cases: hit and release ticks included
- **AC-20**: see criterion above
  - Given: doubles with call recorders
  - When: replay the Story 005-008 scripts
  - Then: recorded calls are only reads
  - Edge cases: a mutating call fails the test

## Test Evidence
**Story Type**: Logic
**Required evidence**: tests/unit/near_miss_detection/near_miss_detection_determinism_test.gd
**Evidence**: tests/unit/near_miss_detection/near_miss_detection_determinism_test.gd (AC-19 x3, AC-20 x2), script in tests/support/near_miss_script.gd
**Status**: [x] Created, passing

## Dependencies
- Depends on: Stories 005-008
- Unlocks: Story 011
