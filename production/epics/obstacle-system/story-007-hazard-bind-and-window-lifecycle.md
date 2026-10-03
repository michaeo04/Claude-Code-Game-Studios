# Story 007: ObstacleCore hazard bind and window lifecycle

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/obstacle-system.md` (Core Rules 1, 5, 6, 7; Edge Cases window and lifecycle)
**Requirement**: `TR-obstacle-system-002`, `TR-obstacle-system-006`, `TR-obstacle-system-007`, `TR-obstacle-system-009`, `TR-obstacle-system-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 3); ADR-0002: Game loop, Composition Root and tick order (secondary)
**ADR Decision Summary**: On `segment_entered_window(i)` the core calls `hazards_for_segment(i)` once and per returned spec assigns `hazard_id` and builds a world-space flat footprint; the shared spec is never copied.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Signals are declared on the owning core (`ObstacleCore`) with typed arguments; handlers are typed. A closure captures a primitive by value, so tests count events through an `Array`.
**Control Manifest Rules (this layer)**:
- Required: `s_offset = (i - spec.local_segment_index) * L`; footprint = 4 floats per piece (`theta_min`, `theta_max`, `s_start + s_offset`, `s_end + s_offset`) in a `PackedFloat64Array`; record `{hazard_id, home_segment = i, hazard_type, footprint, s_lo, s_hi}`; no offset arithmetic outside the bind.
- Forbidden: `duplicate()` / `duplicate_deep()`; `_process`; autoload; unmutated-record reads of raw world Z.
- Guardrail: at most 16 window segments live, 192 pieces held.

## Acceptance Criteria
- [ ] **AC-14 [K]** `hazards_for_segment` called twice for one index: the second call is rejected with one `DUPLICATE_SEGMENT_QUERY` error, the first binding untouched; a legitimate call for another index proceeds.
- [ ] **AC-19 [C]** `segment_entered_window(4)` calls the provider exactly once for 4 and spawns its hazards with fresh sequential `hazard_id`s; `segment_left_window(4)` releases them, and the same ball coordinates then produce no `hit_reported` for those ids.
- [ ] **AC-20 [C]** a window bound to 10..18 receiving `window_primed(-2, 6)`: every old hazard released first, then -2..6 populated by one provider call per index in increasing order (recording provider), regardless of overlap with the old range.
- [ ] **AC-21 [C]** two consecutive `begin_run()` calls against a stateful provider: both query the same index range in the same order; the second run's `hazard_id`s restart at 0.

## Implementation Notes
`hazard_id` is non-negative, sequential per spawn within a run, never reused within the same `run_id`; the counter restarts at 0 only on `window_primed` (CR5). `window_primed` releases everything unconditionally, with no diffing, then populates. Zero hazards for a segment is valid. A hazard keeps one id across its pieces. Emit `hazard_bound(hazard_id: int, footprint: PackedFloat64Array)` after the record is stored (ADR-0014: state is recorded before emission, Story 008 exposes the accessors). The live call may re-run the preflight checks only as a debug-build assertion and never rejects mid-run (TR-013). Add `make_core(cfg, provider, log_sink)` to `tests/support/`. Obstacle holds no hazards while Tube Track is Idle or Uninitialized; there is no `unload_map` release in the MVP.

## Out of Scope
- Story 008: `hazard_released` flag, `run_reset`, accessors.
- Story 009: the hit test.
- Pattern & Difficulty's real provider (Story 013).

## QA Test Cases
- **AC-14**: Given a provider and core. When index 7 is queried twice. Then one `DUPLICATE_SEGMENT_QUERY` and unchanged binding.
- **AC-19**: Given a recording provider. When enter(4), tick inside the footprint, leave(4), tick again. Then one provider call; hit before, none after.
- **AC-20**: Given window 10..18 and `window_primed(-2, 6)`. Then release-all precedes nine provider calls (-2..6, increasing order); no report at old positions.
  - Edge cases: overlapping new range still releases first.
- **AC-21**: Given two runs. Then identical query order; ids restart at 0.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/obstacle_system/obstacle_system_lifecycle_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 001, 002
- Unlocks: Stories 008, 009
