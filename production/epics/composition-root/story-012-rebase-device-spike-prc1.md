# Story 012: PRC-1 rebase spike on device

> **Epic**: Composition Root & Game Loop
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h (plus device time)
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0013
**Requirement**: `TR-tube-track-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0013: Distance precision and the render origin (WorldFrame)
**ADR Decision Summary**: Gate PRC-1 confirms on a device that a rebase shows no pop and that the real float32 error at the largest placed z stays inside the 0.0024 u requirement.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: NEEDS VERIFICATION on device (not in the engine reference): (1) default Godot builds store node transforms and view matrices in 32-bit floats, so the 2-ulp or 8-ulp model is an assumption until measured; (2) whether the Mobile renderer computes camera-relative transforms on the CPU in 32 or 64 bit; (3) no visible shift on the rebase tick; (4) `Vector3` components built from a float64 difference lose no more than 1 ulp (host test).
**Control Manifest Rules (this layer)**:
- Required: measure the 8-ulp model at the largest placed z just before a rebase (worst case, not average); assert shadow-off and `physics_interpolation=false`; a shader reads no world-space z unless its period divides `REBASE_SEGMENTS * L`.
- Forbidden: raising `REBASE_SEGMENTS` beyond the budget to hide an error; any engine-side workaround that places a node with raw `s`.
- Guardrail: error at most 0.0024 u at the ball's distance; `Z_RENDER_MAX` 2048 u; a lower `REBASE_SEGMENTS` is a data change (pre-committed response).

## Acceptance Criteria
- [ ] A frame capture across a rebase at 60 Hz and at 120 Hz shows no pop in tube seam, hazards or ball (ADR-0013 VC-7)
- [ ] The 8-ulp model is measured at the largest placed z just before a rebase and the measured error is reported against 0.0024 u (VC-7)
- [ ] The doc records the shadow-off and physics-interpolation-off assertions read from the exported project (VC-7)
- [ ] The host check that a `Vector3` built from a float64 difference loses at most 1 ulp is part of the Story 003 or 005 test and cited here (Verification Required item 4)
- [ ] If the measured error exceeds 0.0024 u, `REBASE_SEGMENTS` is lowered (data change) and the run repeated, with the final value recorded; the ADR is amended if the 8-ulp model is wrong (Risks)

## Implementation Notes
Add a debug-only probe that forces `maybe_rebase` at a chosen `s` (or starts a run at `s - origin_s` just below the threshold via a debug start offset) so the capture does not need a 40 s wait. Capture with the phone's 60 fps screen recording or the engine's frame capture; compare consecutive frames at the rebase tick for geometry shift (seam position, hazard edges). Run after the first real `TubeView` and `HazardView` exist; until then run with the fake placement nodes only for the host half and mark the device half blocked by dependency.

## Out of Scope
- Story 005: host-side rebase contract
- Story 011: orchestration soak
- Environment and Juice epics: audit of props and effects (listed in their own stories)

## QA Test Cases
- **AC-1**: no pop
  - Setup: release export, debug start offset 20 u below the rebase threshold, tube, hazards and ball present; 60 Hz then 120 Hz device
  - Verify: frame-by-frame capture through the rebase tick
  - Pass condition: no visible position change of any element between the two frames beyond normal motion
- **AC-2**: error measurement
  - Setup: probe logging placed z and the rendered offset near `s - origin_s` = 1007
  - Verify: error at the largest z
  - Pass condition: at most 0.0024 u
- **AC-3**: project settings read from the exported build
  - Pass condition: shadows off, `physics_interpolation` false
- **AC-5**: record the final `REBASE_SEGMENTS`

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/composition-root-prc1-rebase.md` (device models, refresh rates, captures, numbers)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 005, Story 010; tube-track epic (`TubeView.rebase`), hazard-view stories, and the first Android export
- Unlocks: closing ADR-0013 Verification Required; Open Question 13 regression check in the tube-track epic
