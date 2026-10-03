# Story 015: Developer-only effective-footprint debug overlay

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/obstacle-system.md` (UI Requirements: required development tool; Core Rule 1 visual-collision-mismatch risk)
**Requirement**: `TR-obstacle-system-023` (the debug-overlay clause only; full-silhouette rendering and draw-call budget belong to the hazard-view epic)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0014: Hazard render route and view node tree (Decision 7); ADR-0008: Hazard, collision and content format (`footprint_of`)
**ADR Decision Summary**: The overlay is a separate editor-only tool, gated on `OS.has_feature("editor")`, that draws `footprint_of` with the mesh builder's arc-polyline helper and adds no draw call to a release build.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Rendering behaviour on 4.7.2 (unshaded lines, depth test, mobile renderer) is unverified; ADR-0014 gates R-1 and HV-1 cover the hazard rendering. The arc-polyline helper belongs to `HazardMeshBuilder` (presentation epic).
**Control Manifest Rules (this layer)**:
- Required: footprint reads through `ObstacleCore.footprint_of` (world-space float64); positions via `WorldFrame.render_z`.
- Forbidden: `OS.` / `Engine.` calls inside `ObstacleMath/Core/Config` (the overlay lives in its own file outside them); `ArrayMesh` creation outside `HazardView.apply_map`; raw `-s` evaluation.
- Guardrail: zero cost and zero draw calls in release builds.

## Acceptance Criteria
- [ ] The overlay draws the effective boundary (raw footprint expanded by `BALL_HALF_ANGLE` and `D/2`) of every bound hazard, colour-coded by `hazard_id`.
- [ ] It is active only in the editor / debug-feature build (`OS.has_feature("editor")`) and absent from a release export.
- [ ] A visual check confirms each drawn rectangle matches the hazard silhouette plus the ball margin for Wall 301, Double Gate 202 and Near-Ring 401 including the seam-crossing arc.
- [ ] It is available before Pattern & Difficulty begins hand-authoring the chunk library (GDD requirement).

## Implementation Notes
Required before chunk authoring, not before the unit tests. Because the helper and `HazardView` belong to the presentation layer, sequence this story after that epic's mesh builder lands; if the helper is not yet available, draw polylines directly and replace later (record in the story). The silhouette-covers-footprint invariant (ADR-0014 I1 to I3) is the visual contract being checked.

## Out of Scope
- HazardView, mesh builder, materials and draw-call allocation (hazard-view epic).
- Preflight reporting (Stories 011, 012).

## QA Test Cases
- **Setup**: Open the editor scene with the Story 013 wiring; bind fixture hazards 301, 202, 401 and a seam piece.
- **Verify**: Screenshot from a fixed camera; compare overlay outlines to the hazard meshes; toggle a release-feature run and confirm no overlay nodes exist.
- **Pass condition**: outlines match expected expanded bounds within a ball-width tolerance and the seam arc draws as one piece; lead sign-off recorded.

## Test Evidence
**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/obstacle-system/footprint-overlay.md` with screenshots and lead sign-off
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 007, 008, 013; hazard-view (presentation) epic mesh builder helper
- Unlocks: chunk authoring in the pattern-difficulty epic
