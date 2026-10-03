# Story 003: MapConfig.build with Camera values and camera_far

> **Epic**: Map Loader & MapConfig
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0004
**Requirement**: `TR-map-loader-???` (related: `TR-camera-016`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary); ADR-0014: Hazard render route (`camera_far`)
**ADR Decision Summary**: Camera values come from pure `CameraMath.published` at composition and travel into `MapConfig`; `camera_far = F_rest + L` is derived per map in Phase A step A5 from the validated env, because the resting fog end is per map.
**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0014 renderer; this story is pure arithmetic)
**Engine Notes**: `camera_far` is applied to `Camera3D.far` by Camera, not here. The far plane is axial and fog radial, so `+ L` is a conservative margin (ADR-0014 Decision 6).
**Control Manifest Rules (this layer)**:
- Required: Camera values derived with static pure `CameraMath.published` from `CameraConfig` and the immutable `WorldGeometry`; `camera_distance` is the derived worst case (about 7.84), not a hand-copied 8
- Required: `camera_far = F_rest + L` where `F_rest` is the resting `fog_end_distance` of the validated env, constant (no speed pull)
- Forbidden: Camera values stored in the map file; `camera_far` from `CameraMath.published` at composition
- Guardrail: tolerance `1e-6`

## Acceptance Criteria
- [ ] `MapConfig.build(...)` copies `map_id`, the validated `env`, the shared `chunk_library` (same instance, never copied) and the validated `hazard_style`, and takes `rear_extent`, `camera_distance`, `visible_arc_half_width` from the camera geometry dictionary (ADR-0004 Decision 1)
- [ ] `MapConfig.build` derives `camera_far = env.fog_end_distance + L` (84 + 12 = 96 at Map 1 defaults) from the validated env (ADR-0014 Decision 6, ADR-0004 A5)
- [ ] Camera geometry that is non-finite or out of range gives `MAP_CAMERA_INVALID` (ADR-0004 A3)
- [ ] `L <= 0` or a non-finite `camera_far` gives `MAP_CAMERA_INVALID` (ADR-0004 A5)
- [ ] The built `MapConfig` is read-only by convention: building twice from the same inputs gives equal values and mutating one does not change the other

## Implementation Notes
`MapConfig.build` is a static function returning the `MapConfig` or a code set; keep it free of engine calls. The camera geometry arrives from the `camera_geometry()` seam as a `Dictionary` with the three keys plus `L`; validate presence, finite, and sign before building (what range is "in range" comes from `CameraMath`'s own constants, do not duplicate; if no range is documented there, treat negative or zero as out of range and note it in the report). `shared chunk_library` must be asserted by identity in the test (`is_same`/`==` on the object).

## Out of Scope
- Story 002: HazardStyle validation
- Story 004: ordering of A3 and A5 within Phase A and aggregation of codes
- Camera node applying `camera_far` (camera epic, presentation)

## QA Test Cases
- **AC-1**: build copies and shares correctly
  - Given: validated env and style, a library stand-in, a camera dictionary
  - When: `MapConfig.build` runs
  - Then: fields equal inputs; `map.chunk_library` is the same object as the input
- **AC-2**: camera_far
  - Given: `fog_end_distance` 84, `L` 12
  - When: built
  - Then: `camera_far == 96.0`
  - Edge cases: fog end changed to 60 gives 72
- **AC-3**: invalid camera geometry
  - Given: dictionaries with `NAN`, `INF`, a missing key, a negative distance
  - When: built
  - Then: each yields `MAP_CAMERA_INVALID`
- **AC-4**: bad L / far
  - Given: `L = 0`; `fog_end_distance = INF`
  - When: built
  - Then: `MAP_CAMERA_INVALID` for both
- **AC-5**: independence
  - Given: two builds from equal inputs
  - When: one result's field is changed in the test
  - Then: the other is unchanged

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/map_loader/map_loader_map_config_build_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001, Story 002; camera epic (`CameraMath.published`) for the real geometry shape
- Unlocks: Story 004
