# Story 014: Spike OB-1, worst-case per-tick cost on a mid-tier phone

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/obstacle-system.md` (Core Rule 2 broad-phase note; Tuning Knobs `MAX_PIECES_PER_SEGMENT`)
**Requirement**: `TR-obstacle-system-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 4 budget, spike OB-1); ADR-0009: Test framework and CI (device evidence class)
**ADR Decision Summary**: `Obstacle.test` plus `NearMiss.step` take at most 0.4 ms per tick at the 192-piece worst case on a mid-tier phone; advisory until the first-playable profiling pass. Only about 24 pieces pass the broad phase at once, so 192 bounds records held, not pieces tested.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION (ADR-0008 item 6): per-tick cost of the 192-piece worst case on a mid-tier Android phone. Device-needing integration is evidence in `production/qa/evidence/`, blocking at its named gate (`designated-gates.md`).
**Control Manifest Rules (this layer)**:
- Required: float64 flat arrays; broad phase per hazard before pieces.
- Forbidden: moving to engine physics to meet the budget; `Vector4` footprints.
- Guardrail: 0.4 ms per tick for `Obstacle.test` + `NearMiss.step` at 192 pieces; 3 ms simulation tick (provisional).

## Acceptance Criteria
- [ ] A test build binds 192 pieces (12 per segment x 16 window segments) of worst-case shape, including multi-piece hazards and seam-crossing pieces.
- [ ] Median, p95 and max of `Obstacle.test` and of `Obstacle.test + NearMiss.step` are recorded over at least 1,000 ticks on a named mid-tier Android device (model, OS, build type).
- [ ] The evidence file states pass or fail against 0.4 ms and, on a miss, the escalation taken (ADR-0008 names none beyond re-measuring; propose in the file, do not decide here).
- [ ] The count of pieces passing the broad phase per tick is logged (expected about 24).

## Implementation Notes
Use a profiling harness in `prototypes/` or a debug-only scene; time with `Time.get_ticks_usec()` outside `ObstacleCore` (the core never calls `Time.`). Record the library, `L`, `v_max` and fixture used. Near-Miss may not exist yet; if so measure `Obstacle.test` alone and mark the combined figure pending. This spike has no automated pass/fail in CI.

## Out of Scope
- Near-Miss's own cost model (near-miss-detection epic).
- Draw-call and render budgets (hazard-view epic, spike HV-1 / R-1).

## QA Test Cases
- **Setup**: Build a debug APK with the harness; connect a mid-tier Android device; warm up 300 ticks.
- **Verify**: Record 1,000 ticks of per-tick microseconds for both timings and the pieces-tested count.
- **Pass condition**: combined p95 at most 0.4 ms (advisory until first-playable profiling pass); results and device written to the evidence file.

## Test Evidence
**Story Type**: Integration (device)
**Required evidence**: `production/qa/evidence/obstacle-system/ob-1.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 013; near-miss-detection epic (combined figure)
- Unlocks: lock of the 0.4 ms budget; `MAX_PIECES_PER_SEGMENT` tuning (GDD OQ8)
