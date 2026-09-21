# Godot Rendering — Quick Reference

Last verified: 2026-02-12 | Engine: Godot 4.6

## What Changed Since ~4.3 (LLM Cutoff)

### 4.6 Changes
- **D3D12 is the default rendering backend on Windows** (was Vulkan)
- **Glow processes before tonemapping** (was after) — uses screen blending mode
- **AgX tonemapper**: new white point and contrast controls
- **SSR overhauled**: better realism, visual stability, and performance

### 4.5 Changes
- **Shader Baker**: Pre-compiles shaders to reduce startup time
- **SMAA 1x**: New anti-aliasing option (sharper than FXAA, cheaper than TAA)
- **Stencil buffer support**: Enables selective geometry masking/portal effects
- **Bent normal maps**: Directional occlusion encoded in normal map textures
- **Specular occlusion**: Ambient occlusion now correctly affects reflections

### 4.4 Changes
- **`RenderingDevice.draw_list_begin`**: Many parameters removed; optional `breadcrumb` added
- **Shader texture types**: Changed from `Texture2D` to `Texture` base type
- **Particles `.restart()`**: Added optional `keep_seed` parameter

### 4.3 Changes (in training data)
- **Compositor node**: `Compositor` + `CompositorEffect` for post-processing chains

## Current API Patterns

### Post-Processing (4.3+)
```gdscript
# Use Compositor node — NOT manual viewport shader chains
# Add Compositor as child of WorldEnvironment or Camera3D
# Create CompositorEffect resources for each post-process step
```

### Anti-Aliasing Options (4.6)
```
Project Settings → Rendering → Anti Aliasing:
- MSAA 2D/3D: Hardware MSAA (quality but expensive)
- Screen Space AA: FXAA (fast, blurry) or SMAA (sharp, moderate cost)  # SMAA new in 4.5
- TAA: Temporal (best quality, ghosting on fast motion)
```

### Rendering Backend Selection (4.6)
```
Project Settings → Rendering → Renderer:
- Forward+ (default): Full featured, desktop-focused
- Mobile: Optimized for mobile/low-end, limited features
- Compatibility: OpenGL 3.3 / WebGL 2, broadest hardware support

Windows default backend: D3D12 (was Vulkan pre-4.6)
```

### Depth fog (verified on 4.7.2, Forward+ only; 2026-09-20)
```
factor = pow(smoothstep(fog_depth_begin, fog_depth_end, d), fog_depth_curve) * fog_density
d      = radial distance from the camera eye (not the depth along the view axis)
```
- The default `fog_mode` is exponential, which never becomes fully opaque at a finite distance;
  set depth mode when a fixed "fully fogged at distance X" is needed.
- The default `fog_density` is 0.01, so at `fog_depth_end` the opacity equals `fog_density`
  (1% by default). Set `fog_density = 1.0` for a fully opaque far end.
- Because `d` is radial from the eye, a point at radial distance `F` is slightly nearer than `F`
  along the view axis; with the camera behind the subject, subtract the camera distance to get the
  distance ahead of the subject.
- Verified by the godot-specialist on the Forward+ renderer only; the Mobile renderer was not re-run.

### Still unverified (do not rely on these)
- Fog behaviour and draw-call counts on the **Mobile** renderer.
- `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` baselines: an empty scene did not reproduce a
  baseline of 68 (it read 0 in a SubViewport run); pin the measurement setup before quoting numbers.
- Flat shading through `SurfaceTool.set_smooth_group(-1)` (flat normals were not confirmed).
- GUT on 4.7.2 (log capture, `class_name` handling), and how a `.tres` file coerces an `int` field
  or loads NaN.

## Common Mistakes
- Assuming Vulkan is the default backend on Windows (D3D12 since 4.6)
- Assuming the default fog reaches 100% opacity at `fog_depth_end` (default mode is exponential and
  default `fog_density` is 0.01)
- Using manual viewport chains instead of Compositor for post-processing
- Using `Texture2D` in shader uniform types (use `Texture` since 4.4)
- Not using Shader Baker for projects with many shader variants
