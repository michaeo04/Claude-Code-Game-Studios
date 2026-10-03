# Story 004: `TubeMath.local_point` and the logical-frame reference

> **Epic**: Composition Root & Game Loop
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0013 (frame `P` from `design/gdd/tube-track.md` Rule 1)
**Requirement**: `TR-tube-track-002` (the `local_point` part), `TR-tube-track-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0013: Distance precision and the render origin (WorldFrame)
**ADR Decision Summary**: `TubeMath.local_point(theta, h) -> Vector2` returns the x and y of the GDD's `P`; the z part is `WorldFrame.render_z(s)`. It replaces the proposed `to_world`; no `TubeMath` function returns a `Vector3` built from `s`.
**Engine**: Godot 4.7.2 | **Risk**: HIGH (project-level; this story uses only `sin`, `cos`, `Vector2`)
**Engine Notes**: No post-cutoff API. The logical `P` with `z = -s` exists only as a test reference function.
**Control Manifest Rules (this layer)**:
- Required: `TubeMath` static `RefCounted`; `local_point(theta, h) -> Vector2` = `((R + h) * sin(theta), (R + h) * cos(theta))` (no `s`); a view builds `Vector3(p.x, p.y, world_frame.render_z(s))`; non-finite input returns 0 and logs (TR-tube-track-002).
- Forbidden: any `TubeMath` function returning a `Vector3` built from `s`; evaluating `-s` outside `WorldFrame` and `TubeMath`.
- Guardrail: tolerance 1e-9 in float64 for the camera placement check; 1e-6 elsewhere.

## Acceptance Criteria
- [ ] `local_point(theta, h)` equals the x and y of the GDD's `P` on a fixed fixture table: theta 0, PI/2, PI, -PI/2; h = 0, D/2, CAMERA_RADIUS - R (ADR-0013 VC-5)
- [ ] The camera placement (eye at `local_point(phi_cam, CAMERA_RADIUS - R)`, z = `render_z(s_ball) + CAMERA_BACK_DISTANCE`) equals reference `P(phi_cam, s_ball - CAMERA_BACK_DISTANCE, CAMERA_RADIUS - R)` shifted by `origin_s`, to 1e-9 in float64 (VC-5)
- [ ] The look-at on the axis uses z = `render_z(s_ball) - CAMERA_LOOK_AHEAD` and matches the reference the same way (Decision 3)
- [ ] Non-finite `theta` or `h` returns `Vector2.ZERO` and logs once through the injected sink (TR-tube-track-002)
- [ ] No `TubeMath` function has a `Vector3` return type (a reflection test over `get_script().get_script_method_list()`) (Decision 3)

## Implementation Notes
`R` comes from `WorldGeometry`/`TubeConfig`; `local_point` is static, so pass `R` as a parameter or read it from a static-config argument, whichever the tube-track story for `TubeMath` settled (check that story first and add this function to the same `tube_math.gd`; do not create a second file). The reference `logical_p(theta, s, h) -> Vector3` lives under `tests/support/` only (framework-free fixture), never in `src/`.

## Out of Scope
- Story 003: `WorldFrame`
- tube-track epic: the other `TubeMath` functions (wrap_angle, delta_theta, F2-F9, idle_step)
- camera epic: `CameraView` itself

## QA Test Cases
- **AC-1**: fixture table
  - Given: theta and h fixture rows
  - When: `local_point`
  - Then: matches reference x, y within 1e-9
  - Edge cases: theta = TAU; negative h
- **AC-2/3**: camera placement
  - Given: `origin_s` 0 and 1008, `s_ball` 1200.5
  - When: eye and look-at built from `local_point` + `render_z`
  - Then: equal to reference `P` shifted by `origin_s`
- **AC-4**: non-finite
  - Given: NAN, INF
  - When: called
  - Then: `Vector2.ZERO`, one log record
- **AC-5**: reflection
  - Given: the `TubeMath` script
  - When: its methods are listed
  - Then: none returns `TYPE_VECTOR3`

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/composition_root/tube_math_local_point_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 003; tube-track epic (the `tube_math.gd` file; coordinate)
- Unlocks: camera and ball view stories
