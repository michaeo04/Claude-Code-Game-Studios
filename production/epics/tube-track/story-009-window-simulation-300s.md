# Story 009: 300 s deterministic window simulation

> **Epic**: Tube Track
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-010`, `TR-tube-track-020`, `TR-tube-track-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary, determinism and unit test rules); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: Unit tests are deterministic (no seeds, no wall clock, `==` for integers, 1e-6 for floats) and use test doubles for Camera, Ball and Obstacle. Cores are headless.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: dt = 1/64 gives 0.390625 u per frame at 25 u/s, exact in binary; 19,200 frames reach s = 7500 = 625 x 12 exactly. Closures capture primitives by value: count through an Array.
**Control Manifest Rules (this layer)**:
- Required: far edge of the window at least `F + v_max * t_lat` (86.5) and at least `A * L` (108) ahead of `s` after every call; a slot is recycled only when entirely out of view (`far edge <= s - rear_extent`).
- Forbidden: wall-clock assertions in [U] tests; relying on the engine for allocation counts (that is device evidence, Story 013).
- Guardrail: test run must be quick (a 19,200-frame loop of a RefCounted core); no `OS`/`Time` calls.

## Acceptance Criteria
- [ ] **AC-21** 300 s at 25 u/s, dt = 1/64 (19,200 frames) with a camera double publishing `rear_extent = 6`: on every frame the far edge (far edge of segment `i + A`) is at least 86.5 and at least 108 ahead of s; a single step of dt = t_lat (2.5 u) keeps both bounds after the call.
- [ ] **AC-22** In the same simulation, when a slot is recycled its far edge is at most `s - rear_extent`; each boundary crossing emits exactly one `segment_left_window` and one `segment_entered_window` inside the same `advance` call; the count of each equals `floori(s_final / L)` in exact arithmetic (625).
- [ ] **AC-23** Over the whole simulation every `slot_binder` call has `slot_index` in 0..11 and `slot_index = posmod(segment_index, 12)`.

## Implementation Notes
Single test file with one shared simulation run in `before_all`, then separate `test_` functions asserting the recorded series. Record per frame: far-edge distance, recycled-slot far edge, signal counts per `advance` call (via the ordered recorder from Story 007), binder calls. Build the camera double and Ball double as plain `RefCounted` in `tests/support/`. Allocation counts (nothing allocated or freed) are not asserted here; they belong to the device check in Story 013.

## Out of Scope
- Story 006: single-call advance cases
- Story 013: AC-29 object and node counts

## QA Test Cases
- **AC-21**: far-edge bounds
  - Given: default map, v 25, dt 1/64. When: 19,200 frames. Then: both bounds hold every frame; a t_lat step keeps them. Edge cases: frame 1 and the final frame; step of 2.5 u.
- **AC-22**: recycling counts
  - Given: the recorder. When: simulation ends at s = 7500. Then: 625 left and 625 entered; each pair inside one `advance`; recycled far edge <= s - 6. Edge cases: exact boundary at the last frame.
- **AC-23**: slot indices
  - Given: the binder spy. When: simulation ends. Then: all slot indices in 0..11 and equal `posmod(segment_index, 12)`. Edge cases: negative priming indices -2, -1.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tube_track/tube_window_simulation_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 006, Story 007, Story 008
- Unlocks: Story 013 (device soak builds on this)
