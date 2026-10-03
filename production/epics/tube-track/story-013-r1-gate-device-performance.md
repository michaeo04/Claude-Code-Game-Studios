# Story 013: R-1 renderer gate and device performance evidence

> **Epic**: Tube Track
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 4 h (device session)
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-012` (closes the Partial), `TR-tube-track-021`, `TR-tube-track-022`, `TR-tube-track-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0003: Renderer choice and tube render route (primary, gate R-1); ADR-0013: Distance precision and the render origin (PRC-1); ADR-0009: Test framework and CI (device evidence rule)
**ADR Decision Summary**: Mobile (Vulkan) is chosen behind gate R-1 on at least two Android makers with Forward+ as the pre-committed fallback (`rendering/renderer/rendering_method.mobile="forward_plus"`); the tube moves to R2 (MultiMesh) only if its draw-call share is exceeded. R-1 runs first once `project.godot` exists; no Environment, Hazard view or Ball view story starts until R-1 is recorded.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Mobile fog, draw-call accounting, flat shading, per-fragment fog, tonemap-linear contrast and Shader Baker on Android are unverified until R-1 (items 1 to 11 in the ADR). Measure draw calls as a delta with `RenderingServer.viewport_get_render_info` after `frame_post_draw`; `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` is not trusted as an absolute. The earlier "68 draw-call baseline" did not reproduce: record the real baseline.
**Control Manifest Rules (this layer)**:
- Required: R-1 passes before Story 011 is Done; R-1 and PRC-1 results are recorded in `production/qa/evidence/`; tonemapper pinned to linear; `physics/common/physics_interpolation` false.
- Forbidden: skipping R-1 and trusting Forward+ numbers for `F_read`; marking the device check passed without a device log.
- Guardrail: tube +12 draw calls (or the measured figure), total at most 150; 60 FPS for 10 minutes; recycle p99 at most 0.2 ms (provisional); `begin_run` at most 2 ms (re-verify at N = 12); object, node and resource counts differ by 0 between warm-up end and run end.

## Acceptance Criteria
- [ ] **AC-28** [P] Draw calls measured as a delta between the scene with and without the tube, on Forward+ and Mobile, `cast_shadow` off, every slot on one Mesh and Material (expected +12 on Mobile, to be re-verified); total at most 150 on an exported build; the engine baseline is recorded.
- [ ] **AC-29** [P] In a release export after a 10 s warm-up, static memory compared with an idle baseline; `Performance.OBJECT_COUNT`, `OBJECT_NODE_COUNT` and `OBJECT_RESOURCE_COUNT` differ by 0 between the end of the warm-up and the end of the run; a 10-minute heat-soak reports frame time at t = 0 and at the end.
- [ ] **AC-30** [P] With `Time.get_ticks_usec()` around `advance()` (no-op listeners connected), report the p99 over a run for recycle frames (provisional at most 0.2 ms) and at most 2 ms of Tube Track's own work in `begin_run()` (N = 12).
- [ ] **R-1 / TR-012** On at least two Android makers: depth fog sampled at several distances and mid-segment, post-tonemap with linear tonemapper, matches F1 within the F9 margin; derived `F_read` at `v_max` is at least 45.5 and `T_vis` at least 1.5 s; hazard-to-tube contrast at `F_read` at least 4:1; flat shading visibly faceted; `get_current_rendering_method()` reports `mobile`; MSAA 2x/4x and banding checked.
- [ ] **PRC-1** A frame capture across a rebase at 60 and 120 Hz shows no pop; error is measured at the largest placed z just before a rebase (8-ulp model); shadow-off and physics-interpolation-off settings are asserted.

## Implementation Notes
Build against the Story 011/012 tube on a debug export with a small profiling overlay (debug-only, not a player UI). Write one evidence doc per spike: `production/qa/evidence/r1-renderer-gate-<date>.md`, `.../tube-track-performance-<date>.md`, `.../prc1-rebase-<date>.md`, each with device models, OS versions, raw numbers and screenshots. On an R-1 failure follow the ADR rollback (switch `rendering_method.mobile` to `forward_plus`, or move the tube to R2) and amend ADR-0003; Environment F1 values are re-derived by that epic.

## Out of Scope
- Story 014: subjective seam checks and AC-27 playtest
- Hazard, ball, HUD and Menus draw-call shares (their own epics' R-1 rows)

## QA Test Cases
- **R-1 / AC-28**: Setup: release export on two makers, Mobile then Forward+. Verify: draw-call delta, baseline, fog samples, faceting screenshot. Pass condition: every R-1 checkbox in the ADR is ticked or the rollback is applied and recorded.
- **AC-29 / AC-30**: Setup: 10-minute run with the sim driving `advance`. Verify: counts at warm-up end and run end; p99 recycle and `begin_run` times. Pass condition: counts differ by 0; times within the provisional limits or the new measured limits are recorded for the GDD.
- **PRC-1**: Setup: capture across the first rebase at 60 and 120 Hz. Verify: no pop, largest placed z error. Pass condition: error at most 0.0024 u.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/` (R-1, performance and PRC-1 documents as named above); blocking at the first-playable gate
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 011, Story 012, Story 009; platform-services epic (Android export preset) and a real device
- Unlocks: Story 011 Done, environment-theming and hazard/ball view epics (R-1 recorded), Story 014
