# Story 004: F3-NM preflight validator: NEAR_ZONE_OVERLAP

> **Epic**: Near-Miss Detection
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format; ADR-0009: Test framework and CI
**ADR Decision Summary**: `ContentPreflight` is a pure RefCounted composing `ObstacleMath`, `PatternMath` and `NearMissMath` validators; P1 includes `NEAR_ZONE_OVERLAP`, P2 re-checks it across chunk boundaries (ADR-0008 Decision 5).
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: The validator returns every violation (exhaustive, deterministic order) as `PreflightRecord` (`code`, `s0`, `pieces`) like `ObstacleMath.validate_gaps` in `src/core/obstacle/obstacle_math.gd`. Never partial application.
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [ ] AC-8 [M]: two pieces separated by exactly `GAP_MIN` (0.5896): near zones consume 0.2358 total, 0.3538 (60%) open, accepted; joint corner (`NEAR_MISS_ANGLE_COEFF` 1.5, `GAP_MARGIN` 2.0, `fraction_consumed` 0.75) accepted; deliberately illegal row (coefficient 3.0, `GAP_MARGIN` 2.0, 1.5) rejected, exercising the check.
- [ ] AC-9 [K]: pieces A `[0.00, 2.00]`, B `[2.01, 4.00]`, C `[4.30, 6.00]` sharing one critical `s0` pass F3's aggregate check (0.5932 >= 0.5896) yet yield exactly one `NEAR_ZONE_OVERLAP` naming `s0` and pair (A, B) only; B-C and C-A not reported.
- [ ] AC-10 [K]: two pieces at the same critical `s0` far apart (2.5 rad each side) do not fire `NEAR_ZONE_OVERLAP`; a mutation flagging any pair merely sharing `s0` must fail (the check keys off near-zone gap width).

## Implementation Notes
- Sort pieces active at each critical `s0` (F3's own points) by `theta_eff` centre; test angularly adjacent pairs including the wraparound pair, with near zones, over the whole library (same scope as `HAZARD_OVERLAP`). Reject with `NEAR_ZONE_OVERLAP`; the record names `s0` and the pair.
- Never fires for the common single-gap topology. Sequential hazards with no shared `s0` are out of scope by design (GDD F3-NM); the coalescing need is Juice's (Open Question 8).
- Wiring into the real `ContentPreflight` P1/P2 belongs to the obstacle-system and pattern-difficulty epics; this story delivers the pure validator and its unit tests.

## Out of Scope
- Story 011: ContentPreflight integration.
- Open Question 7: reachability under Pattern's real placement style.

## QA Test Cases
- **AC-8**: see criterion above
  - Given: two-piece fixtures at GAP_MIN, the joint corner, and the illegal 3.0 row
  - When: validator run
  - Then: first two accepted, third rejected
  - Edge cases: fraction = k / GAP_MARGIN
- **AC-9**: see criterion above
  - Given: A, B, C above
  - When: validator run
  - Then: exactly one record (code, s0, (A,B))
  - Edge cases: wraparound pair C-A examined and clean
- **AC-10**: see criterion above
  - Given: two far-apart pieces at one `s0`
  - When: validator run
  - Then: no record
  - Edge cases: mutant on co-presence fails

## Test Evidence
**Story Type**: Logic
**Required evidence**: tests/unit/near_miss_detection/near_miss_detection_overlap_validator_test.gd
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 001, 002
- Unlocks: Story 011
