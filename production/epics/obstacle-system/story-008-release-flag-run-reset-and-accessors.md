# Story 008: Release flag, run_reset handler and read accessors

> **Epic**: Obstacle System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/obstacle-system.md` (Core Rule 5; Interactions with Near-Miss)
**Requirement**: `TR-obstacle-system-007`, `TR-obstacle-system-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 3); ADR-0014: Hazard render route and view node tree (Decision 4 accessors); ADR-0002 (rank 2 order)
**ADR Decision Summary**: `hazard_released(hazard_id, released_by_reset)` is unchanged; `ObstacleCore` gains read accessors `footprint_of`, `hazard_type_of`, `spec_of(hazard_id) -> HazardSpec`, `s_offset_of(hazard_id) -> float`, valid during the `hazard_bound` emission (state recorded before emitting; tested). The signal payload is not extended.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Handlers in `_wire()` are immediate connections with typed parameters (signal arguments are coerced to the handler's declared types). Handler order within a rank relies on connection order (NEEDS VERIFICATION, Run State AC-30 spy test on 4.7.2).
**Control Manifest Rules (this layer)**:
- Required: `released_by_reset` true for every `window_primed` release (reset, re-prime, to-idle), false for `segment_left_window`; `run_reset` handler only stores `run_id`; `ObstacleCore` keeps `s` as float64 and publishes offsets.
- Forbidden: calling `spec_of` / `s_offset_of` outside the `hazard_bound` emission; extending the `hazard_bound` payload; clearing or reseeding in `run_reset`; any `hazard_released` for `unload_map`.
- Guardrail: no allocation of pieces in accessors (return shared references or small values).

## Acceptance Criteria
- [ ] **AC-40 [C]** recording subscriber on a window 10..18 holding three hazards: (a) `window_primed(-2, 6)` publishes exactly one `hazard_released(id, true)` per hazard (none false, missing or doubled); (b) `segment_left_window(10)` publishes `(id, false)` for that segment's hazards only; (c) re-prime overlapping the old range and the to-idle `window_primed` both give `true`. A core that always sends false (rows a, c) or always true (row b) fails.
- [ ] **AC-41 [C]** `run_reset(2)` and `window_primed(-2, 6)` in both orders give the same end state (segments -2..6 populated, ids from 0, `hit_reported` carries `run_id` 2); `run_reset(2)` alone leaves bound hazards and the counter untouched and publishes no release. A clearing / reseeding handler fails the `window_primed`-first order.
- [ ] Accessors `footprint_of`, `hazard_type_of`, `spec_of`, `s_offset_of` return the bound values inside a `hazard_bound` handler (ADR-0014 validation criterion).

## Implementation Notes
Order inside Run State rank 2 (Tube Track adapter and Obstacle) is by row order, so both orders must be safe. `unload_map` is not a release trigger; if ever added, Obstacle goes Idle and drops hazards without publishing. Near-Miss reads the flag on `hazard_released` to suppress `near_miss_detected` for discarded hazards. `spec_of` / `s_offset_of` exist for HazardView, which stores `s_offset` in its own node record so `rebase()` never re-queries Obstacle.

## Out of Scope
- Story 007: bind and counter. Story 009: `hit_reported`.
- HazardView consumption of the accessors (hazard-view / presentation epic).

## QA Test Cases
- **AC-40**: Given the three-hazard window. When each of the three triggers fires. Then the recorded `(id, flag)` pairs equal the expectation; mutations fail.
- **AC-41**: Given a recording provider and subscriber. When the two orders run. Then end states are identical; the lone `run_reset` changes nothing.
  - Edge cases: `run_id` captured is the latest value.
- **Accessors**: Given a `hazard_bound` handler that reads all four. Then values match the record; spec identity equals the provider's instance.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/obstacle_system/obstacle_system_release_reset_test.gd`
**Evidence**: `tests/unit/obstacle_system/obstacle_system_release_reset_test.gd` (7 tests: AC-40, AC-41, accessors)
**Status**: [x] Passing (CI 2026-10-04)

## Dependencies
- Depends on: Story 007
- Unlocks: Story 013; near-miss-detection epic; hazard-view (presentation) epic
