# Story 011: TubeView mesh, shared material, slots and rebase

> **Epic**: Tube Track
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-013`, `TR-tube-track-016`, `TR-tube-track-017`, `TR-tube-track-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0003: Renderer choice and tube render route (primary, Decision 2); ADR-0013: Distance precision and the render origin (`rebase()`, `render_z`); ADR-0002: Game loop, Composition Root and tick order (no `_process`)
**ADR Decision Summary**: `TubeView` creates N (= 12) `MeshInstance3D` slots once at `load_map`, all on one `ArrayMesh` (32-facet cylinder, flat normals from duplicated vertices, axis along Z) and one `ShaderMaterial`; `bind_slot` sets the transform only (z from `WorldFrame.render_z(segment_index * L)`); `cast_shadow = OFF`; nothing is allocated or freed during a run.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `SurfaceTool.set_smooth_group(-1)` is unconfirmed: build the `ArrayMesh` from raw arrays with explicit analytic facet normals (fallbacks: `flat` varying, derivative normal). Under the dummy headless renderer assert structure only. `reset_physics_interpolation()` (4.3) on recycle or `physics_interpolation_mode = OFF`. Slots need no `custom_aabb`. Faceted rendering is judged on device (Story 013, R-1).
**Control Manifest Rules (this layer)**:
- Required: `TubeView` interface `build(cfg, mesh, mat)`, `bind_slot(slot_index, segment_index)`, `idle_step(dt)`, `set_seam_contrast_scale(v)`, `rebase()`; `set_process(false)` and `set_physics_process(false)`; every slot on the same Mesh and Material resource.
- Forbidden: `CollisionObject3D` on the tube; MultiMesh or a scrolling seam shader for the tube in the MVP; allocating or freeing slots during a run or on Retry; a `Vector3(` built from raw `s` (use `render_z`).
- Guardrail: tube 12 draw calls (provisional); total at most 150.

## Acceptance Criteria
- [ ] **AC-24** The generated mesh has 32 facets with vertex radius `R` (R = 3.0), flat (duplicated-vertex) normals along the facet normals, and the `TubeTrack` node tree contains no `CollisionObject3D`.
- [ ] (ADR-0003/0013, structural) After `build`, 12 slots share one `ArrayMesh` and one `ShaderMaterial` (same resource ids), `cast_shadow` is off, `_process` and `_physics_process` are off; `bind_slot` sets z to `render_z(segment_index * L)` and x, y to zero; `rebase()` re-binds all 12 slots so every z equals a fresh placement with the new origin and relative z between any two slots is unchanged (1e-9 in float64); object, node and resource counts do not change across 1,000 recycles in the headless test.
- [ ] (idle) `idle_step(dt)` on the view forwards the dt to the window's `tick_idle` and the called-only-in-Menu rule is the caller's (composition-root spy); the view moves no slot.

## Implementation Notes
`src/presentation/tube_track/tube_view.gd` (`class_name TubeView extends Node3D`). `build(cfg: TubeConfig, mesh: ArrayMesh, mat: ShaderMaterial)` creates slots once; mesh built by a pure `TubeMeshBuilder` returning arrays (vertices, normals, indices) that is unit-testable without a renderer, then wrapped in `ArrayMesh` in the view. The mesh is a cylinder with 32 facets, axis Z, length L, vertex radius R; `D` is not a TubeConfig field. Slot binder from `TubeWindow` calls `bind_slot`. Keep this story free of shader details (Story 012). The `Environment` and `GameRoot` composition belong to other epics; use a fake `WorldFrame` and a plain Node3D parent in tests.

## Out of Scope
- Story 012: seam shader and `seam_contrast_scale`
- Story 013: draw calls, faceting, fog and frame-rate gates (device)
- composition-root epic: calling `idle_step` and `rebase` from `_tick`

## QA Test Cases
- **AC-24**: mesh structure
  - Given: `TubeMeshBuilder` output at R = 3. When: inspect arrays. Then: 32 facets, vertex distances from the axis equal R (1e-6), per-facet normals unit length and perpendicular to the facet; no `CollisionObject3D` anywhere under the view. Edge cases: duplicated vertices (no shared smoothing normals).
- **(structural)**: shared resources and rebase
  - Given: a view with a fake `WorldFrame`. When: bind 12 slots, rebase after `origin_s` change, recycle 1,000 times. Then: identical resource ids, correct z, counts via `Performance`/`get_node_count` unchanged. Edge cases: rebase on the same tick as a recycle.
- **(idle)**: forwarding
  - Given: a recording window. When: `idle_step(1/60)`. Then: one `tick_idle` call with that dt; slot transforms unchanged.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/tube_track/tube_view_slots_test.gd` (uses the dummy headless renderer; structure only)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001, Story 004, Story 008; gate: R-1 (Story 013) must pass before this story is marked Done (develop it first as the build R-1 runs against); test-harness-ci (GUT, T-1)
- Unlocks: Story 012, Story 013, Story 014
