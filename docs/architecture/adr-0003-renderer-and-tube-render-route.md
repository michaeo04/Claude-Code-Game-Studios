# ADR-0003: Renderer choice and tube render route

## Status

Proposed

## Date

2026-10-02

## Last Verified

2026-10-02

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

The renderer was never chosen: `technical-preferences.md` says Forward+, the Environment GDD calls Mobile "likely", and its fog formula (F1) was verified on Forward+ only. This ADR picks the **Mobile renderer** for the Android build behind a measured device gate (R-1) with **Forward+ as the fallback**, renders the tube as **one `MeshInstance3D` per segment slot sharing one Mesh and one Material**, and fixes a provisional draw-call allocation inside the 150 budget. Two specialists (Godot, shader) reviewed it: approve with notes, no blocker.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Rendering |
| **Knowledge Risk** | HIGH: renderer behavior after 4.3 changed (glow before tonemapping 4.6, shader preprocessor restrictions 4.7, Shader Baker 4.5, `Texture` uniform type 4.4); fog and draw-call accounting on the Mobile renderer are **unverified** |
| **References Consulted** | `docs/engine-reference/godot/modules/rendering.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` |
| **Post-Cutoff APIs Used** | Depth fog on `Environment` (properties verified on 4.7.2, Forward+ only); Shader Baker (4.5, export-time); `Compositor` is **not** used |
| **Verification Required** | **Verified by the reference (Forward+, 4.7.2):** depth fog formula and radial `d`; default fog mode is exponential; default `fog_density` 0.01. **NEEDS VERIFICATION on the Mobile renderer, on device (gate R-1):** (1) depth fog factor against F1 and the derived `F_read`; (2) draw-call delta of the tube (+12 expected) and the engine baseline; (3) flat shading from duplicated vertices (and the derivative-normal shader fallback); (4) that `rendering/renderer/rendering_method.mobile` is the per-platform override, that its default is `mobile`, and that it wins over `rendering_method` on an Android export; (5) the default of `rendering/rendering_device/fallback_to_opengl3` (a non-Vulkan device may silently run Compatibility) and `RenderingServer.get_current_rendering_method()` at boot; (6) Shader Baker on an Android export (it does not remove driver pipeline creation); (7) depth fog computed per fragment, not per vertex, on Mobile (the tube has long triangles); (8) fog and contrast measured after tonemapping with the tonemapper pinned to linear, and fog gradient banding (`use_debanding`); (9) the draw-call delta on Forward+ (a depth pre-pass may make the tube about 24 calls there) versus Mobile (+12); (10) glow, MSAA 2x and 4x, FXAA and SMAA (4.5) support and cost on Mobile; (11) 60 FPS on the reference devices |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Android only), ADR-0002 (the view has no `_process`; `GameRoot` calls `idle_step`) |
| **Enables** | ADR-0010 (presentation time), ADR-0011 (UI architecture), ADR-0012 (ball material and world chroma) |
| **Blocks** | Tube Track, Environment & Theming and Juice & Feedback epics |
| **Ordering Note** | Spike R-1 is the validation gate of the first Tube Track story (it cannot be Done until R-1 passes); the ADR can be Accepted on technical-director review before R-1 runs (P-1, 2026-10-03), and a failed R-1 triggers the Forward+ rollback below |

## Context

### Problem Statement

Tube Track Open Questions 1 and 3, and Environment Open Question 5, all wait for a renderer ADR: the backend, the shadow setup, how draw calls are counted, and how the tube is rendered (node per slot, MultiMesh, or a scrolling shader). Environment's whole fog derivation (`F_read` 46.22 u, the 4:1 contrast floor, `MAP_VISIBILITY_UNSAFE`) rests on Forward+ behavior, while the project targets mid-tier Android where Forward+ is the heavier renderer.

### Constraints

- At most 150 draw calls and 16.6 ms; 512 MB; mid-tier Android; 60 FPS.
- The fairness budget `T_VIS_MIN` has only a 0.02 s margin against `F_read` at `v_max` (46.00 u), so a fog or contrast shift of 0.5 u on device breaks Pillar 2.
- The art bible fixes hazards as the loudest element; no screen shake; juice stays in the cool/white channel.
- The desktop editor and desktop runs use `rendering_method` (default Forward+), while an Android export uses the `.mobile` override: a desktop screenshot does **not** represent the device, so fog and contrast checks run on the device or with `--rendering-method mobile`.
- GDD rules fix: a 32-facet flat-shaded tube (Tube Track R3, F7, AC-24); no `CollisionObject3D`; every slot shares one Mesh and one Material; fog must use depth mode with `fog_density` 1.0; the seam is a flat shading band with no geometry.

### Requirements

- Choose the backend and the tube route with numbers that can be measured.
- Fog, contrast and draw calls must be measurable on a real device before the fairness numbers are trusted.
- A fallback must exist if the Mobile renderer disagrees with the Forward+-derived formulas.

## Decision

1. **Renderer: Mobile (Vulkan) for the Android build, gated by R-1.** Set `rendering/renderer/rendering_method="mobile"` (so desktop previews, screenshots and GUT runs use the same renderer as the device) **and** `rendering/renderer/rendering_method.mobile="mobile"` (the Android override). The OpenGL fallback is disabled (`rendering/rendering_device/fallback_to_opengl3` off), and `GameRoot` checks `RenderingServer.get_current_rendering_method()` at boot and refuses to run if it is not `mobile`, so a non-Vulkan device is blocked instead of silently running Compatibility (where fog and glow differ and F1 is invalid); the Vulkan requirement goes into the Play manifest (ADR-0006). Gate **R-1** (below) must pass on at least two Android makers before this ADR is Accepted. If it fails (fog or contrast off by more than the F9 margin, draw calls over budget, or frame rate under 60 FPS), the project switches to **Forward+** by setting `rendering/renderer/rendering_method.mobile="forward_plus"` (changing only `rendering_method` would not affect the Android build) and Environment F1 is used as derived, with this ADR amended. Compatibility (OpenGL) is not used. A renderer change needs an editor restart.
2. **Tube route: R1.** `TubeTrack`'s view creates `N` (= 12) `MeshInstance3D` slots once at `load_map`, all referencing **one `ArrayMesh`** (32-facet cylinder, flat normals from duplicated vertices, axis along Z) and **one `ShaderMaterial`**. `slot_binder(slot_index, segment_index)` only sets the slot's transform and calls `reset_physics_interpolation()` on recycle (or the slots set `physics_interpolation_mode = OFF`, since `GameRoot` drives them), so a recycled slot never streaks for a tick; nothing is allocated or freed during a run. `cast_shadow = OFF`. Slots need no `custom_aabb` (the mesh AABB follows the node transform); one is required only if a vertex shader ever moves vertices. The seam is a segment-local analytic shader pattern (identical in every segment), so no per-frame `s` uniform exists. The dynamic shared inputs are: `seam_contrast_scale` (a material parameter: Tube Track **pulls the Settings getter every frame in every state** (Tube Track R9, AC-23a) and **writes the material only when the value changed**); the per-event progress uniform in [0, 1] of the event shaders (ring pulse, PB bloom and sweep, ADR-0010); the two global shader parameters of ADR-0012 (written only through `render_globals.gd`); and the near-miss ball-position uniform.
3. **Fog: `Environment` depth mode.** `fog_mode` depth, `fog_density = 1.0`, `fog_depth_begin` and `fog_depth_end` from MapConfig, `fog_depth_curve` 1.0. The speed pull moves only `fog_depth_end` (Environment F2). The fog colour equals the sky horizon colour (ADR-0012 Decision 4, asserted by `EnvConfig.validated`) and ADR-0012 pins `fog_sky_affect = 0`, `fog_aerial_perspective = 0` and `fog_sun_scatter = 0`, so the fully fogged tube end shows no horizon line; `fog_light_color` is written on every change through `WorldChroma` (ADR-0012), so the fog colour is static in the tube route but not a constant of this ADR; the tonemapper is pinned to **linear** on every renderer (a filmic curve changes the 4:1 contrast), and fog banding is checked (`use_debanding`).
4. **Glow and post-processing.** `WorldEnvironment` glow is **off** in the MVP. The personal-best bloom and the near-miss ring are shader terms or overlay opacity, not engine glow (glow ordering changed in 4.6 and Mobile glow cost is unmeasured). No `Compositor` effects in the MVP. The hit flash is a full-screen `CanvasLayer` `ColorRect` (one blend pass, `visible = false` when idle); the near-miss ring is an additive Rim White term on the tube material driven by a world-space ball-position uniform (correct across all 12 shared slots, and faded by fog with distance).
5. **No real-time shadows.** No light casts shadows; the flat-shaded look comes from the material.
   **Antialiasing.** MSAA 2x is the default (cheapest on tile-based GPUs, keeps hazard edges crisp), 4x is measured as a quality option, FXAA is not used (it blurs), SMAA (4.5) is unverified on Mobile, TAA is not available. MSAA does not smooth shader stripes, so the seam uses `smoothstep` with `fwidth()`. `scaling_3d/scale` is the lever if 60 FPS fails; the choice is part of R-1.
6. **Shaders.** Spatial shaders avoid the preprocessor beyond simple `#define` constants (4.7 restrictions). The seam is analytic and uses no texture uniforms (if one is ever added it is declared `sampler2D` in shader code; the 4.4 `Texture` change applies to API signatures, not shader source). The Android export uses **Shader Baker** (4.5) **and** a mandatory **warm-up scene** that renders every material once before a run starts (tube, hazards, the plinth material, the killer-override material, ball, the shard `GPUParticles3D` and the Menu preview node; ADR-0014 Decision 5, ADR-0012 Decision 5), because the baker does not remove the driver's Vulkan pipeline creation.
7. **Draw-call allocation (provisional, measured in R-1):** tube 12, hazards 34 (ADR-0014: 17 bodies plus 17 plinth surfaces in the AABB window), ball and rim 4, props 6 (MultiMesh), sky 2, shards 2, HUD 20 (UX-16), Hit flash 1, Menus 25 (never concurrent with gameplay). The concurrent gameplay worst case on Mobile is about 81 (84 with the full ball allocation), plus the Paused overlay, so the headroom is about 65 against 150. On the Forward+ fallback a depth pre-pass may double the hazard figure to about 68, above its allocation; ADR-0014 names the escalation (one mesh per segment). The engine's own baseline is unknown (the earlier "68" was not reproduced) and must be measured before these figures are trusted.
8. **Escalation path.** If R1 exceeds its share, the tube moves to **R2 (one `MultiMeshInstance3D`, `custom_aabb` set)**; the `slot_binder` contract and Tube Track's logic do not change.

### Architecture Diagram

```
TubeTrack (view Node3D, no _process)         Environment (WorldEnvironment)
  slot 0..11  MeshInstance3D  --shared--> ArrayMesh (32 flat facets) + ShaderMaterial (seam band)
  slot_binder(slot, segment) sets transform only        fog: depth mode, density 1.0, begin/end from MapConfig
  seam_contrast_scale: shared uniform (pulled every frame from Settings, written on change)
Renderer: Mobile (Vulkan)  [gate R-1]  ->  fallback Forward+
No shadows, no engine glow, no Compositor in the MVP
```

### Key Interfaces

```gdscript
# project settings (to verify on 4.7.2)
# rendering/renderer/rendering_method        = "mobile"   # desktop previews match the device
# rendering/renderer/rendering_method.mobile = "mobile"   # Android override; rollback value: "forward_plus"
# rendering/rendering_device/fallback_to_opengl3 = false
# lights: shadow off; Environment: fog_mode DEPTH, fog_density 1.0, tonemap linear

class_name TubeView extends Node3D       # no _process (ADR-0002)
func build(cfg: TubeConfig, mesh: ArrayMesh, mat: ShaderMaterial) -> void   # creates N slots once
func bind_slot(slot_index: int, segment_index: int) -> void                # transform only
func idle_step(dt: float) -> void                                         # called by GameRoot in Idle
func set_seam_contrast_scale(v: float) -> void                             # called every frame with the Settings value; writes the material only on change
```

### Implementation Guidelines

- Build the `ArrayMesh` from raw arrays with duplicated vertices and **explicit analytic facet normals**; do not rely on `SurfaceTool.set_smooth_group(-1)` (unconfirmed). Fallbacks: a `flat` varying, or a derivative normal (`dFdx`/`dFdy`, per-pixel cost, 2x2-quad artifacts at silhouettes).
- Measure draw calls as the **delta** with and without a group, read through `RenderingServer.viewport_get_render_info` (`VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME`) after `frame_post_draw`; the absolute `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` is not trusted (it counts all passes and reads the previous frame). Cross-check on device with Android GPU Inspector or Snapdragon Profiler for true draw calls, overdraw and GPU time.
- Keep UI pills small and never stack full-screen translucent panels (fill rate, not draw calls, is their cost).
- Keep every slot on the same Mesh and Material resource so batching and the draw-call count stay predictable.

## Alternatives Considered

### Alternative 1: Forward+ as the primary renderer

- **Description**: keep the `technical-preferences.md` value.
- **Pros**: the fog formula was verified there; more features.
- **Cons**: heavier on mid-tier Android GPUs; less headroom for the 60 FPS target.
- **Rejection Reason**: kept only as the fallback behind gate R-1 (selected through `rendering_method.mobile`).

### Alternative 2: Compatibility (OpenGL ES)

- **Description**: widest device coverage.
- **Pros**: runs on devices without Vulkan.
- **Cons**: fog, glow and `Compositor` behavior differ and are unverified; invalidates Environment F1.
- **Rejection Reason**: too many unverified differences for a fairness-critical fog derivation.

### Alternative 3: Tube as one `MultiMeshInstance3D` (R2)

- **Description**: 12 instances in one draw call.
- **Pros**: 1 draw call instead of 12.
- **Cons**: needs `custom_aabb`, per-recycle instance transform updates, more validation work.
- **Rejection Reason**: not needed while 12 draw calls fit the budget; held as the escalation path.

### Alternative 4: One mesh with a scrolling seam shader (R3)

- **Description**: a single mesh scrolls a seam pattern from a 64-bit-derived uniform.
- **Pros**: fewest nodes.
- **Cons**: forces a treadmill (rebase of `s`), conflicts with Tube Track's recycle model and with the open precision question (ADR-0013).
- **Rejection Reason**: couples rendering to the precision decision for no draw-call benefit.

## Consequences

### Positive

- A renderer decision with a measurable gate and a defined fallback; the tube route is simple and testable.
- The fairness-critical fog numbers will be measured on the target renderer before they are trusted.

### Negative

- Environment's `F_read` derivation may need re-deriving if R-1 shows a Mobile fog difference.
- `MeshInstance3D` slots cost +12 draw calls on Mobile (accepted).
- No engine glow limits the bloom look to shader and overlay effects.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Mobile depth fog differs from the Forward+ formula | Medium | High | gate R-1; fall back to Forward+; re-derive F1 |
| Flat shading from duplicated vertices does not render flat on Mobile | Low | Low | derivative-normal shader fallback |
| Draw-call baseline higher than assumed | Medium | Medium | measure the baseline in R-1; move the tube to R2 |
| Shader Baker unsupported or ineffective on Android Mobile | Medium | Low | warm-up scene at boot; measure first-use hitching |
| A non-Vulkan device silently runs the Compatibility renderer | Medium | High | OpenGL fallback disabled; `get_current_rendering_method()` check at boot; Vulkan requirement in the manifest (ADR-0006) |
| Rollback applied to the wrong setting key (the `.mobile` override wins on Android) | Medium | Medium | rollback plan names `rendering_method.mobile` |
| Mobile fog computed per vertex or with reduced precision, banding | Low | High | R-1 samples fog mid-segment and checks banding; fall back to Forward+ |
| Driver pipeline hitching on the first use of a material or particle system | Medium | Medium | mandatory warm-up scene (decision 6) |
| Fog and contrast change with the tonemapper | Low | High | tonemapper pinned to linear; contrast measured post-tonemap |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | n/a | tube slots recycle with transform updates only | 16.6 ms frame |
| Memory | n/a | one mesh and one material shared by 12 slots | 512 MB |
| Draw calls | n/a | tube +12 on Mobile (provisional allocation in decision 7) | at most 150 total |
| Load Time | n/a | mesh built once at `load_map`; shaders baked at export | n/a |

## Migration Plan

Greenfield. Create `project.godot` rendering settings, the `TubeView`, then run gate R-1.

**Rollback plan**: set `rendering/renderer/rendering_method.mobile="forward_plus"` (and keep `rendering_method` equal for desktop previews; restart the editor); move the tube to R2 if draw calls exceed the allocation.

## Validation Criteria

Gate **R-1** (on at least two Android makers, release export):

- [ ] Depth fog sampled at several distances **and on pixels mid-segment** (per-vertex versus per-pixel check), measured post-tonemap with the tonemapper at linear, matches F1 within the F9 margin; derived `F_read` at `v_max` is at least 45.5 u (the legacy floor) and `T_vis` is at least 1.5 s.
- [ ] Hazard-to-tube contrast at `F_read` is at least 4:1 on screen.
- [ ] Tube draw-call delta is +12 (or the measured figure) and the full scene is at most 150 with the engine baseline recorded.
- [ ] Flat shading is visibly faceted with no smoothing seams.
- [ ] 60 FPS sustained for 10 minutes; first-use shader hitching under one frame with Shader Baker (or a warm-up).
- [ ] `godot --headless --import` **parses** every shader in CI (headless has no RenderingDevice, so SPIR-V compilation is verified on device), and no shader uses unsupported preprocessor patterns.
- [ ] `RenderingServer.get_current_rendering_method()` reports `mobile` on every test device, and a device without Vulkan is blocked, not downgraded.
- [ ] Antialiasing choice (MSAA 2x, 4x) measured against 60 FPS; fog gradient shows no visible banding.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/tube-track.md` | Tube Track | renderer backend and draw-call accounting (OQ1); how the tube is rendered (OQ3, R3, F7, AC-24, AC-28) | Mobile behind R-1; route R1 with one shared Mesh and Material; +12 draw calls measured as a delta |
| `design/gdd/tube-track.md` | Tube Track | fog must be depth mode with `fog_density` 1.0 (R7); `F9` visibility budget | depth fog on `Environment`; R-1 re-measures `F_read` and `T_vis` |
| `design/gdd/environment-theming.md` | Environment & Theming | F1 derivation assumes Forward+ (OQ5, AC-22) | R-1 is the on-device check of F1 on the target renderer, with a Forward+ fallback |
| `design/gdd/juice-feedback.md` | Juice & Feedback | ring and bloom as shader terms, +0 draw calls; shard `GPUParticles3D`; no glow dependency | glow off, effects as shader and overlay terms; 2 draw calls allocated for shards |
| `design/gdd/hud.md`, `design/gdd/menus-screen-flow.md` | HUD, Menus | at most 20 and 25 draw calls | allocation in decision 7 |
| `.claude/docs/technical-preferences.md` | project | at most 150 draw calls, 60 FPS, 512 MB | allocation and R-1 criteria; technical-preferences updated from Forward+ to Mobile when this ADR is Accepted |

## Related

- ADR-0001, ADR-0002; ADR-0010, ADR-0011, ADR-0012, future ADR-0013
- `docs/architecture/architecture.md` (Open Questions 1 and 6)
