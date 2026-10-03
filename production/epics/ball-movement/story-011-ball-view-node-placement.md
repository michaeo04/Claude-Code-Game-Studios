# Story 011: BallView node, placement through WorldFrame, stateless roll and lean

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md`
**Requirement**: `TR-ball-movement-019`, `TR-ball-movement-013`, `TR-ball-movement-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0012: Ball material and world chroma (primary); ADR-0013: Distance precision and the render origin; ADR-0002: Game loop (`BallView.tick` right after `Camera.step`)
**ADR Decision Summary**: `BallView` (`BallView.tscn`, root `Node3D`, no `_process`) owns one `MeshInstance3D` (`SphereMesh` radius D/2, height D, 24 segments, 12 rings, smooth normals, shadow off, no collision node). `tick(snapshot)` places it at riding radius `R + D/2` with `TubeMath.local_point(theta, h)` for x/y and `WorldFrame.render_z(s)` for z.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Rendering is HIGH risk (ADR-0003/0012); gate R-1 runs before any Ball view story starts (from the control manifest, Presentation layer). `SphereMesh` radius and height give a round sphere at `D` is NEEDS VERIFICATION (item 15). The view belongs conceptually to the Presentation layer; it is carried in this epic because AC-26 and TR-019 are owned here.
**Control Manifest Rules (this layer)**:
- Required: no `_process` (`set_process(false)`, `set_physics_process(false)`); placement only through `WorldFrame.render_z` and `TubeMath.local_point`; roll `fposmod(s / (D/2), TAU)` and a capped lean from `omega` live in the view.
- Forbidden: `CollisionObject3D` on the ball; cosmetic roll/lean state in the core; reading raw world Z; evaluating `-s` outside `WorldFrame`/`TubeMath`; Camera reading `BallView`'s transform.
- Guardrail: ball 1 draw call (allocation 4); render error at the ball at most 0.0024 u.

## Acceptance Criteria
- [ ] **AC-26 [I/static]** (R11, Tube Track AC-24) The instantiated `BallView` scene has no `CollisionObject3D` and holds exactly one `MeshInstance3D` and one material.
- [ ] `tick(snapshot)` places the node at riding radius `R + D/2` using `TubeMath.local_point(theta, h)` (x, y) and `render_z(s)` (z), float64 cast to float32 in one place; verified against the reference `P(theta, s, h)` shifted by `origin_s` for theta in {0, PI/2, PI, -PI/2} (TR-014, ADR-0013 Validation).
- [ ] The sphere mesh has `radius = D/2` and `height = D`, `radial_segments = 24`, `rings = 12`, `is_hemisphere` false, `cast_shadow` OFF (structure asserted headless).
- [ ] Roll and lean are stateless view functions: roll `fposmod(s / (D/2), TAU)`, lean capped by `lean_max`; no state added to `BallCore` (TR-019). Applied but not acceptance-tested visually.
- [ ] The ball carries no speed VFX (no trail or stretch scaling with `speed`).

## Implementation Notes
Files: `src/presentation/ball/ball_view.gd`, `assets/scenes/BallView.tscn` (root name `BallView`). `build(style: BallStyle, geometry: WorldGeometry)`; `D` comes from the one immutable `WorldGeometry`. `BallSnapshot` is the plain published-state record (`theta`, `s`, `omega`) read after `Ball.step`. A node test touching rendering classes runs under the dummy renderer and asserts structure only. Built by `GameRoot` before `MapLoader` (composition-root). R-1 must have passed before this story is started.

## Out of Scope
- Story 012: material, shader, setters, `BallStyle` validation
- Story 013: R-1 device evidence and rim screenshots
- Camera follow (camera epic)

## QA Test Cases
- **AC-26**: structure
  - Given: `BallView.tscn` instantiated headless
  - When: tree walked
  - Then: no `CollisionObject3D`; one mesh; one material; `process` disabled
  - Edge cases: `physics_process` disabled too
- **Placement**
  - Given: `WorldFrame` with `origin_s` 0 and a non-zero multiple of `L`
  - When: `tick` with theta in {0, PI/2, PI, -PI/2}
  - Then: position equals `local_point` + `render_z(s)` within float32 tolerance
  - Edge cases: `s` > 16384 stays placed correctly after a rebase

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/ball_movement/ball_movement_view_structure_test.gd` (must pass)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 009; gate R-1 (tube-track / platform device spike); composition-root (`WorldFrame`, `WorldGeometry` stories); tube-track (`TubeMath.local_point`)
- Unlocks: Story 012, Story 013
