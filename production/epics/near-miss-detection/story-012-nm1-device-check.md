# Story 012: NM-1 on-device near-miss rate speed-invariance check

> **Epic**: Near-Miss Detection
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 2-3 h plus device time
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-012`, `TR-near-miss-detection-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI; ADR-0008: Hazard, collision and content format
**ADR Decision Summary**: NM-1 is a numeric on-device pass/fail check, BLOCKING at the first-playable gate; ADR-0009 lists NM-1 among the device spikes whose evidence goes to `production/qa/evidence/`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Run on the same device spike as Ball Movement BM-1/BM-2/BM-3 and the Tilt Input checks (Android, mid-tier). Spike OB-1 (`Obstacle.test` plus `NearMiss.step` within 0.4 ms at 192 pieces) is measured in the same profiling pass and recorded in the same evidence folder.
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [ ] NM-1: log near-misses per hazard safely passed (`hit_ever_true` false) in an early band (`run_time` < 20 s) and a late band (`run_time` > `T_RAMP`, at `v_max`), at least 30 hazards passed per band (aggregate spike runs, same build and tuning, until reached; fewer is insufficient data, not a verdict). Pass: late-run ratio within +/-20% of the early-run ratio.
- [ ] NM-1 fail condition: divergence beyond +/-20% at sufficient sample size, or the along-track margin (16 ms at defaults, about 5 ms at the worst legal corner) provably failing to register on-device (near-miss rate near zero at `v_max` but not at `V_START`). Pre-committed response: adjust `NEAR_MISS_S_COEFF` (and `NEAR_MISS_ANGLE_COEFF` if the failure is angular) within `[0.5, 1.5]`; never widen `GAP_MARGIN` or loosen `GAP_MIN`.

## Implementation Notes
- Evidence doc `production/qa/evidence/near-miss-detection/nm-1.md`: device, build, both band counts, ratios, verdict, frame timing. Owner: whoever runs the shared device spike. Named build gate: first-playable. This is an Integration device check (coding-standards Scope Limit), not a Visual/Feel escalation.

## Out of Scope
- Open Question 9: fairness of the multi-piece override (separate playtest note).

## QA Test Cases
- **NM-1**: see criterion above
  - Given: a device build with a debug counter of passed hazards and near-misses per band
  - When: play to reach both bands
  - Then: counts logged, ratio computed
  - Edge cases: under 30 per band: rerun

## Test Evidence
**Story Type**: Integration
**Required evidence**: production/qa/evidence/near-miss-detection/nm-1.md (device evidence, BLOCKING at first-playable)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 011; cross-epic: ball-movement and tilt-input device build
- Unlocks: None
