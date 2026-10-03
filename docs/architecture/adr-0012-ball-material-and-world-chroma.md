# ADR-0012: Ball material and world chroma

## Status

Proposed

## Date

2026-10-03

## Last Verified

2026-10-03

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

Five GDDs assume the same four things without anyone owning them: who builds the ball view and owns its material, how Environment's colourblind luminance `L_ball_adjusted` reaches that material, how Juice's rim glow layers on the same material, and how the world chroma shift (0.88 at `v_max`) and the Hit grey-out reach shaders while hazards, the ball and pickups stay exempt (architecture review 2026-10-03; ADR-0014 left the killer-hazard isolate open). This ADR decides: **`BallView` owns the ball node and its one `ShaderMaterial`**, with two single-purpose setters (`set_luminance_target` for Environment, `set_rim_glow` for Juice); the ball body is **unshaded** with an albedo whose luminance is exactly the contract value and a **fresnel rim** that gives it form; world chroma and the Hit grey-out are **two global shader parameters** (`world_chroma`, `hit_grey`) written through one small `WorldChroma` object, so exemption is by construction (a shader that does not declare a uniform cannot be affected by it); the **killer hazard** is isolated with a pre-built second material of the hazard shader through `set_surface_override_material(0, ...)`; and the **fog colour** is derived from the same two values in the same tick so the horizon never shows a line.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Rendering (materials, shaders, global shader parameters) |
| **Knowledge Risk** | HIGH for the renderer (ADR-0003); global shader parameters on the Mobile renderer, their declaration in `project.godot` and their per-frame cost are **unverified on 4.7.2** |
| **References Consulted** | `docs/engine-reference/godot/modules/rendering.md`, `breaking-changes.md`, `deprecated-apis.md`, ADR-0003, ADR-0014, `design/gdd/environment-theming.md`, `juice-feedback.md`, `ball-movement.md`, `design/art/art-bible.md` |
| **Post-Cutoff APIs Used** | None specific. Global shader parameters (`RenderingServer.global_shader_parameter_set`, `shader_globals/*` project settings) are 4.0 features not covered by the engine reference. The 4.7 shader preprocessor restrictions are respected (no preprocessor beyond constants) |
| **Verification Required** | **Added after review:** (8) the CPU fog colour path (`srgb_to_linear`, operation, `linear_to_srgb`) matches the tube and sky pixels: the 8-bit tube-end pixel equals the sky pixel within 1 LSB at every chroma and grey value; (9) `fog_sky_affect = 0`, `fog_aerial_perspective = 0`, `fog_sun_scatter = 0`, `fog_light_energy = 1.0` behave as pinned on Mobile, and the sky shader follows a changed global live (not through the radiance cubemap); (10) additive terms on an `unshaded` material go through `ALBEDO`; (11) depth fog applies to the unshaded ball on Mobile; (12) the ball luminance is measured at the disc centre (the rim raises edge luminance, and `rim_glow` raises it further during juice, so the contract is stated at the centre); (13) globals are read only in `fragment()` or the sky shader; (14) a pooled node released while isolated and rebound carries no override (mesh swap keeps the override array); (15) `SphereMesh` radius and height give a round sphere at `D`. Draw-call and shader maths facts are verifiable only on a device (headless uses a dummy renderer, global writes are no-ops). **NEEDS VERIFICATION (device, folded into gate R-1):** (1) `global uniform float world_chroma;` and `hit_grey` work in spatial and sky shaders on Mobile and Forward+, with defaults from `shader_globals/*` correct on the first frame; (2) `RenderingServer.global_shader_parameter_set` per frame is cheap and takes effect the same frame; (3) the luminance-preserving chroma operation, done on linear albedo before fog, keeps the rendered unfogged luminance of tube, sky and prop equal to the art-bible values within 0.5% at chroma 1.0 and equal to the unmodified luma at any chroma; (4) an `unshaded` ball body with a fresnel rim renders the body at exactly `L_ball` (to the R-1 tolerance) after the linear tonemapper; (5) `set_surface_override_material(0, ...)` on a pooled hazard node replaces only the body surface and is cleared by `set_surface_override_material(0, null)`; (6) the fully fogged tube end matches the sky behind it at every `world_chroma` and `hit_grey` value (no horizon line), including the frame the grey-out starts; (7) headless behaviour of global parameters in GUT (the pure `ChromaMath` and `WorldChroma` tests use a fake sink and do not depend on it) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (per-frame order: `Camera.step` 9, `Environment.tick` 10, `Juice.tick` 11; views have no `_process`; this ADR adds `BallView.tick` after `Camera.step`), ADR-0003 (fog depth mode and background colour, no glow, no Compositor, linear tonemapper, ball and rim draw allocation 4), ADR-0014 (`HazardView.node_of`, hazard body shader, no instance uniforms), ADR-0004 (`MapConfig.env` fog and palette) |
| **Enables** | the Ball Movement view stories, Juice stories (rim glow, grey-out), Environment stories (chroma, `L_ball_adjusted`), pickups later |
| **Blocks** | Juice & Feedback epic (grey-out, rim), Environment & Theming epic (chroma, colourblind), Ball view stories |
| **Ordering Note** | ADR-0014 already lists the two `HazardView` methods (`isolate_killer`, `clear_isolation`); ADR-0003's "fog colour equals the background" gets the chroma rule below |

## Context

### Problem Statement

Environment F3 changes only the lightness of the ball ("applied by this system to the ball's material") yet no ADR says who builds that material. Juice layers a rim glow "on the ball's base material". Environment's chroma shift must reach tube, sky and prop but never hazards, ball or pickups, "a separate parameter, never a shared uniform gated by an object flag"; Juice's grey-out must reach every world element except the killer hazard. The fog colour must follow every one of these or the fully fogged tube end shows a horizon line against the sky.

### Constraints

- ADR-0003: glow off, no `Compositor`, linear tonemapper, one shared material per family, fog colour equals the background.
- Art bible: the ball is a smooth sphere (16x12 segments or more) that keeps a cool-white rim in every skin; skins may not change silhouette or scale.
- Environment F3: `L_ball_adjusted = max(min(L_base, L_target), L_floor)`, bit-identical to base when off, applied live on `setting_changed` in any phase and from the getter at construction; ball/hazard contrast (1.4:1 target) and the 0.01 ember margin depend on the **rendered body luminance**.
- Environment F1 contrast uses luminance only: any chroma operation must preserve luminance or the fairness numbers (`F_read`, 4:1) change.
- Juice: grey-out crossfade of 1 to 2 frames, killer hazard exempt, cleared by `run_reset`; rim glow retriggers rather than layers; reduced motion scales intensities, never hitstop.
- No `CollisionObject3D` on the ball (Ball Movement AC-26); no `_process` in views (ADR-0002).

### Requirements

- A single owner and a single writer per material and per shared parameter.
- Exemption must be structural (a shader does not declare the uniform) not a runtime flag.
- Everything that changes colour must keep luminance, so F1 stays valid.

## Decision

### 1. Ball view: `BallView` owns node and material

`BallView` (scene `BallView.tscn`, root `Node3D`, no `_process`) is built by `GameRoot` at composition, **before** `MapLoader` runs. It holds one `MeshInstance3D` (`SphereMesh` with **`radius = D/2` and `height = D`** (a `SphereMesh` has separate radius and height; setting only the radius gives a squashed sphere unless `D` is 1), `radial_segments = 24` and `rings = 12` set explicitly (engine defaults are 64 and 32), `is_hemisphere` false, smooth normals, `cast_shadow` OFF, no collision node) and one `ShaderMaterial` (`ball.gdshader`) that it creates and owns. **No other system holds the material**; Environment and Juice reach it through two setters, injected as **Callable seams** (`ball_luminance_sink`, `rim_glow_sink`) so their cores and tests need no node:

- `set_luminance_target(l: float)`: Environment only (F3), any phase, applied at once; the body albedo is recomputed by `BallMath.albedo_for_luminance(base_color, l_base, l)` and written to the material **only when it changed**.
- `set_rim_glow(v: float)`: Juice only; `v` in `[0, 1]`, 0 at rest; written only when changed.
- `set_ball_visible(v: bool)`: Juice only (ADR-0010 Decision 3: `JuiceView` hides the ball at shard release through its `ball_visible_sink` Callable). It writes the node's `visible` property only when it changed. The name avoids `set_visible`, which already exists on `Node3D`. `BallView.tick` and Environment never write visibility. `run_reset` restores `true` through the same sink (so the ball is visible at every run start and after a Restart); a test asserts visibility is `true` after `run_reset` and that no other call path writes it.

Environment never calls `BallView` at construction (construction emits nothing, ADR-0002): its first `set_luminance_target` is in `Environment.apply_map` and in the `setting_changed` handler, using the injected `base_luminance` value (`BallView.base_luminance()` read once by `GameRoot` at composition and passed in, so there is one source for `L_ball_base`).

`BallView.tick(snapshot)` is a **new line in ADR-0002's per-frame order, right after `Camera.step`** (ADR-0002 follow-up; the spy test of the order is updated). It places the node from the Ball Movement snapshot (`theta`, `s`, `omega`) at the riding radius `R + D/2` using the **same origin mapping as Tube Track** (`z = -s` today; ADR-0013 may change it, so one shared mapping function is referenced, not hard-coded twice), float64 cast to float32 in one place. Cosmetic roll is **stateless**, `roll = fposmod(s / (D/2), TAU)` (stops with the world, resets with `s`), and the lean is a capped function of `omega`; both live in the **view** (no state in the core, Ball Movement TR-019). Because the body is unshaded and uniform, roll and lean are invisible until a skin has a pattern (Open Question 1), so they are applied but not acceptance-tested. **Camera reads the Ball snapshot or core, never `BallView`'s transform**; with one `_process` there is no lag between the camera and the ball. `BallView.base_luminance() -> float` is `ChromaMath.luma_srgb(style.base_color)`.

### 2. Ball body and rim (unshaded plus fresnel)

The ball material is `unshaded`, opaque, depth fog on. Body colour is the uniform `albedo` (`source_color`, linear luminance exactly `L_ball` after `set_luminance_target`), with **no lighting**, so the body luminance is the F3 contract and ball/hazard and ball/tube ratios hold. Form comes from the **cool-white fresnel rim** (art bible: every skin keeps it): `rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power)` mixed toward `rim_color` (Rim White) with `rim_strength` at rest, and **Juice's glow layers on the same term**: `rim_glow` raises the strength and adds the Lagoon outer edge (`edge_color`) in the outer band, no extra pass, no extra material, silhouette and scale unchanged. A low-frequency skin pattern, if a skin has one, must be luminance-preserving (equal luminance bands), so rolling is visible without changing the contract; the MVP skin (Slate Cobalt, L = 0.083) has none and the roll is cosmetic only. The ball has **no chroma or grey uniform** (it is not a world element; see Open Question 2).

`BallStyle` is a scalar-only `Resource` (`assets/data/ball_style.tres`, loaded at composition, validated): `base_color`, `rim_color`, `edge_color`, `rim_power`, `rim_strength`, `rim_glow_max`, `roll_scale`, `lean_max`. It is a **player cosmetic, not a per-map value** (a future skin system swaps the resource).

### 3. World chroma and Hit grey-out: two global parameters

Two `global uniform float` shader parameters, declared in `project.godot` as `[shader_globals]` entries (`world_chroma` default 1.0, `hit_grey` default 0.0, so the first frame is correct; never `global_shader_parameter_add` for these names, which would error and break the editor preview). Shaders read them **only in `fragment()` or in the sky shader** (a global in a vertex stage may hit a storage-buffer limit on some mobile GPUs):

- `world_chroma` in `[0.88, 1.0]`: written by **Environment** (every frame while Running from `u(speed)`, resting 1.0 in Menu; F2 pull of the chroma shift).
- `hit_grey` in `[0, 1]`: written by **Juice** (crossfade over 1 to 2 frames at Hit, 0 on `run_reset`).

**Exemption is structural.** The tube, sky, prop and plinth shaders declare both globals; the hazard body shader declares **only** `hit_grey`; the ball, the shard particles, pickups (later) and the HUD declare neither. No object flag exists.

Operation (in the shader, on **linear albedo, before fog and before additive effect terms** such as the near-miss ring and the PB sweep):

```text
luma(c)          = dot(c, vec3(0.2126, 0.7152, 0.0722))                 linear relative luminance (art bible L)
chroma_eff       = world_chroma * (1 - hit_grey)        world elements (tube, sky, prop, plinth)
chroma_eff       = (1 - hit_grey)                       hazard bodies   (no world_chroma)
albedo'          = luma(c) + (c - luma(c)) * chroma_eff                 luma(albedo') == luma(c) for any chroma_eff
```

Luminance is preserved (the weights sum to exactly 1), so Environment F1 (contrast from luminance only) and the `F_read` and 4:1 numbers are unaffected by any chroma value; for `chroma_eff` in `[0, 1]` every channel stays between `luma` and the original, so nothing clamps. **Additive effect terms go into `ALBEDO`, not `EMISSION`, on unshaded materials** (EMISSION may not be honoured unshaded; R-1).

**Colour space.** Shaders work on linear albedo (`source_color` uniforms are converted on upload); authored `Color` values (`base_fog_color`, `BallStyle.base_color`, sky colours) are **sRGB**. `ChromaMath` therefore has linear functions (`luma`, `apply`) and sRGB wrappers (`luma_srgb`, `apply_srgb`) that do `srgb_to_linear()`, the operation, then `linear_to_srgb()`; every CPU path that writes `fog_light_color` or a `source_color` uniform uses the sRGB wrapper. The art-bible L values must be linear Rec.709 relative luminance (unit test against the hex values). A round trip is not bit-exact, so `BallMath.albedo_for_luminance` **returns its input unchanged when `l_target == l_base`** (Environment AC-9 bit identity). Tests use a **fixed fixture table**, not random colours, with a 1e-6 tolerance (float32).

### 4. `WorldChroma`: one writer object, fog colour in the same call

`WorldChroma` (`RefCounted`, built by `GameRoot`, injected into Environment and Juice) holds `world_chroma` and `hit_grey`, offers **`set_world_chroma(c)` (Environment only)** and **`set_hit_grey(g)` (Juice only)**, writes the two globals through an injected `globals_sink: Callable` whose real implementation is the **only call site of `RenderingServer.global_shader_parameter_set`**, in one named file (`render_globals.gd`, on the engine-call allowlist like `ResourceLoader`), and, **in the same call**, recomputes the effective fog colour `ChromaMath.apply_srgb(base_fog_color, chroma_eff)` and passes it to an injected `fog_sink: Callable`. The fog sink writes **only** `fog_light_color` (and `background_color` if the background is a flat colour); `Environment.apply_map` never writes `fog_light_color` itself (no second writer). Writes happen only when a value changed. Because both setters update the fog colour immediately, the tube end and the sky never disagree, even on the frame the grey-out starts (an `Environment.tick` that read Juice's value one tick late would flash a horizon line for one frame). `set_base_fog_color` is called by `Environment.apply_map`.

**Construction order (ADR-0002 follow-up):** the Environment view node that owns `WorldEnvironment` (the fog sink target), then `WorldChroma`, then `BallView` and `HazardView`, then Environment and Juice (with their injected sinks), then `_wire()`, then `MapLoader`. `GameRoot` keeps strong references to `WorldChroma` and `BallView`. A boot check (like ADR-0003's rendering-method check) asserts `ProjectSettings.has_setting("shader_globals/world_chroma")` and the same for `hit_grey`; a write to an undeclared global would print an error every frame.

**Sky and fog (pinned here, ADR-0003 follow-up).** The sky is drawn by a sky shader (or background gradient) that reads both globals itself, so its CPU base colours are **not** also chroma-adjusted (that would apply chroma twice). `fog_sky_affect = 0` (the sky gradient survives), `fog_aerial_perspective = 0`, `fog_sun_scatter = 0`, `fog_light_energy = 1.0`, ambient and reflected light sources disabled (the sky radiance cubemap may not refresh when a global changes and nothing samples it). The fully fogged end equals the sky behind it only if **`fog_color` equals the sky horizon colour**; `EnvConfig.validated` asserts that invariant (with a test). Because the chroma operation is linear in the colour, the horizon then matches at every `world_chroma` and `hit_grey` value.

### 5. Killer hazard isolate

`HazardView` (ADR-0014) gains two additive methods and **owns the isolation state** (`_isolated_node`): `isolate_killer(hazard_id)` finds the node itself, and sets `set_surface_override_material(0, killer_material)` on it; `clear_isolation()` restores `null`. Both are idempotent and guard a missing node or a null mesh (an unbound killer logs once and does nothing). **`release`, `release_all` and `bind` clear the override defensively**, because a pooled node keeps its override array when its mesh is swapped, and `run_reset` handlers run Obstacle (which releases) at rank 2 before Juice at rank 5; a node released while isolated and rebound must show the normal material (tested). Juice passes only the id; `node_of` is test-only. `killer_material` is `body_material.duplicate()` with `grey_exempt = 1.0` (the shader multiplies `hit_grey` by `1 - grey_exempt`), built at `HazardView.apply_map`; every later uniform write (face and shade colours, Retry) goes through **one helper that writes both materials**. It shares the compiled shader and pipeline with the body material (only a uniform set is new), and is still rendered once in the warm-up scene. Juice calls `isolate_killer` at `run_ended` and `clear_isolation` on `run_reset`. Surface 1 (the plinth) is untouched, so the plinth greys with the world. No instance uniform and no `material_override` is used.

### 6. Draw calls

Ball body and rim are **one draw call** (one mesh, one material), under the allocation of 4 (ADR-0003); the shard burst keeps its 2. Hazards, tube, sky and props gain no draw call (the two globals are uniforms). `killer_material` adds only a uniform set (same shader and render state), warmed at boot.

### Architecture Diagram

```text
Environment.tick  --set_world_chroma(c)-->  WorldChroma --globals_sink--> world_chroma (global)  --> tube, sky, prop, plinth shaders
Juice.tick        --set_hit_grey(g)------>      |       --globals_sink--> hit_grey     (global)  --> tube, sky, prop, plinth, hazard body shaders
                                                |       --fog_sink------> fog_light_color = ChromaMath.apply(base_fog, chroma_eff)  (same call)
Environment F3    --set_luminance_target(l)--> BallView (owns ball material) <--set_rim_glow(v)-- Juice
Juice (run_ended) --isolate_killer(id)------> HazardView: surface 0 override = killer_material (grey_exempt = 1); plinth keeps world material
Ball, shards, pickups, HUD: declare neither global (exempt by construction)
```

### Key Interfaces

```gdscript
class_name ChromaMath extends RefCounted                      # pure, unit-testable
static func luma(c: Color) -> float                           # linear Rec.709 weights, c is LINEAR
static func apply(c: Color, chroma: float) -> Color           # luma + (c - luma) * chroma, c is LINEAR
static func luma_srgb(c: Color) -> float                      # srgb_to_linear first (authored colours are sRGB)
static func apply_srgb(c: Color, chroma: float) -> Color      # srgb_to_linear, apply, linear_to_srgb; used for fog_light_color
static func effective(world_chroma: float, hit_grey: float) -> float   # world_chroma * (1 - hit_grey)

class_name BallMath extends RefCounted
static func albedo_for_luminance(base: Color, l_base: float, l_target: float) -> Color   # scales linear albedo, keeps hue and chroma ratio

class_name WorldChroma extends RefCounted
func _init(globals_sink: Callable, fog_sink: Callable) -> void
func set_base_fog_color(c: Color) -> void                      # Environment.apply_map
func set_world_chroma(c: float) -> void                        # Environment only
func set_hit_grey(g: float) -> void                            # Juice only
var world_chroma: float; var hit_grey: float                   # read-only getters

class_name BallView extends Node3D                             # no _process
func build(style: BallStyle, geometry: WorldGeometry) -> void   # D from the one immutable WorldGeometry (R, D, N_F, L)
func tick(snapshot: BallSnapshot) -> void
func base_luminance() -> float
func set_luminance_target(l: float) -> void                    # Environment only
func set_rim_glow(v: float) -> void                            # Juice only
func set_ball_visible(v: bool) -> void                         # Juice only (ADR-0010 shard release; restored by run_reset)

# HazardView additions (ADR-0014)
func isolate_killer(hazard_id: int) -> void                    # idempotent, owns the isolation state, finds the node itself
func clear_isolation() -> void                                 # release, release_all and bind also clear the override
```

## Alternatives Considered

### Alternative 1: Per-material `world_chroma` uniforms written on four materials
- **Pros**: no dependence on global parameters.
- **Cons**: about four writes per frame and an easy-to-forget material; the grey-out would need the same.
- **Rejection Reason**: kept as the fallback if verification of global parameters on Mobile fails (the `WorldChroma` globals sink becomes a four-material sink; no caller changes).

### Alternative 2: Full-screen desaturation (post-process)
- **Pros**: one place.
- **Cons**: greys the killer hazard and the ball too, needs a `Compositor` (forbidden by ADR-0003) or an extra pass.
- **Rejection Reason**: cannot isolate the killer hazard.

### Alternative 3: Instance uniform `grey_exempt` on the killer node
- **Pros**: no second material.
- **Cons**: depends on per-instance uniforms on Mobile (unverified).
- **Rejection Reason**: a pre-built material override is simpler and verifiable.

### Alternative 4: Lit ball with smooth shading
- **Pros**: looks like a sphere without relying on the rim.
- **Cons**: body luminance varies, so the dark side can reach the Ember value and break the F3 margin and contrast numbers.
- **Rejection Reason**: breaks the luminance contract Environment F3 depends on.

### Alternative 5: Environment owns the ball material
- **Pros**: matches the literal GDD wording ("applied by this system to the ball's material").
- **Cons**: two writers (Environment, Juice) on one material; Environment would need the ball's resources.
- **Rejection Reason**: one owner and two narrow setters keep the same behaviour with a single writer.

## Consequences

### Positive
- One owner per material and per shared value; exemption by construction.
- Luminance is preserved everywhere, so the fairness numbers stay valid under any chroma value.
- Fog colour and chroma change in the same call: no horizon line.
- No new draw calls; the ball is one call.

### Negative
- A ball that reads as a sphere through its rim only (Open Question 1).
- Global shader parameters become project state (`project.godot`, linted).
- A second hazard material variant to warm up.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Global parameters misbehave on Mobile | Low | Medium | R-1 check 1; fallback per-material writes behind the same sink |
| Luma weights differ from the art bible's luminance definition | Low | High | confirm the art bible's L values are linear relative luminance; R-1 check 3 |
| Fog colour and sky disagree on the first grey-out frame | Medium | Medium | one `WorldChroma` call updates both; R-1 check 6 |
| Unshaded ball looks flat | Medium | Medium | art director review of the rim and an optional luminance-preserving pattern; Open Question 1 |
| `isolate_killer` leaves a stale override after an abnormal path | Low | Medium | `clear_isolation` on `run_reset` and in `release_all`; test |
| A new world shader forgets to declare the globals | Medium | Low | lint: every shader under `assets/shaders/world/` declares `world_chroma` and `hit_grey`; hazard shaders declare only `hit_grey`; ball and particle shaders declare neither |

## Performance Implications

| Metric | Expected | Budget |
|---|---|---|
| Draw calls | ball 1 (allocation 4), no change elsewhere | 150 total |
| CPU per frame | two global writes when changed, one fog write when changed, one ball albedo write on change | within the 3 ms simulation budget |
| Memory | one sphere mesh, two materials | 512 MB |
| Load time | one more pipeline in the warm-up scene | ADR-0003 warm-up |

## Migration Plan

Greenfield. Add `[shader_globals]` to `project.godot`, `ChromaMath`, `BallMath`, `WorldChroma`, `render_globals.gd`, `BallView`, `ball.gdshader`, a canonical chroma function block **copied per shader** (no `#include`: 4.7 preprocessor restrictions; a `.gdshaderinc` route is an optional spike checked with `godot --headless --import`), the `killer_material` and the two `HazardView` methods. After Accepted, update **ADR-0002** (per-frame order gains `BallView.tick` after `Camera.step`; construction order above; the spy test), **ADR-0003** (fog colour rule, `fog_sky_affect = 0` and the pinned fog properties; its "only dynamic shared uniform" sentence also omits the near-miss ball-position uniform and these two globals), **ADR-0014** (additive methods, instance-uniform wording removed), the Environment GDD (ball material owner wording, `WorldChroma`, sky and fog invariant), the Juice GDD (`isolate_killer`, global `hit_grey`) and the Ball Movement GDD (view owner). **ADR-0009 lint additions:** every `global uniform` name and type in a shader matches a `[shader_globals]` entry (a small custom parser, since the multi-line values defeat `configparser`) and every declared global is used; the marked chroma function block is textually identical in all shaders; `world_chroma` and `hit_grey` appear only in shaders under the rules of decision 3; `RenderingServer.global_shader_parameter_set` appears only in `render_globals.gd`.

## Validation Criteria

- [ ] Unit (pure): `ChromaMath.apply` preserves `luma` to 1e-6 for chroma 0, 0.88, 1.0 over a fixed fixture table of colours (not random colours; tests are deterministic); `effective`; `BallMath.albedo_for_luminance` hits the target luminance and is bit-identical when `l_target == l_base`; Environment F3 fixtures (0.0421 and the toggle-off identity) pass through `BallView.set_luminance_target` with a fake material sink.
- [ ] Unit: `WorldChroma` writes only on change, never from the wrong setter, and the fog sink value equals `ChromaMath.apply(base, effective)` after every setter in the same call.
- [ ] Integration (real nodes, headless): `isolate_killer` / `clear_isolation` change only surface 0; a reset clears it; the ball view has no `CollisionObject3D` and holds one material.
- [ ] Lint: every shader under `assets/shaders/world/` declares both globals; hazard shaders only `hit_grey`; ball, particle and UI shaders neither; no `RenderingServer.global_shader_parameter_set` outside `render_globals.gd`; no `#include`.
- [ ] R-1 (device): checks 1 to 6 above; screenshot evidence of the grey-out frame with the killer hazard isolated, the resting rim and the near-miss rim in `production/qa/evidence/` (coding standards).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/ball-movement.md` | Ball Movement | TR-ball-movement-019: smooth sphere with cool-white rim; cosmetic roll and capped lean in the view layer; no speed VFX | decisions 1 and 2 |
| `design/gdd/juice-feedback.md` | Juice | TR-juice-feedback-008: grey-out multiplies chroma toward 0 on world elements with luminance preserved; killer hazard exempt | decisions 3 and 5 |
| `design/gdd/juice-feedback.md` | Juice | TR-juice-feedback-012: rim glow is a fresnel treatment layered on the ball's base material | decision 2 (`set_rim_glow`) |
| `design/gdd/environment-theming.md` | Environment | TR-environment-theming-007: world chroma 0.88 on tube, sky, prop only; separate parameter, never a shared uniform gated by an object flag | decision 3 (structural exemption) |
| `design/gdd/environment-theming.md` | Environment | TR-environment-theming-009, -010, -011: `L_ball_adjusted` applied to the ball material, live and at construction, only output | decision 1 (`set_luminance_target`, `base_luminance`) |
| ADR-0003 | Renderer | fog colour equals the background (no horizon line) | decision 4 (fog colour from the same call) |

## Open Questions

1. The ball reads as a sphere through its rim alone (unshaded body). The art director confirms this keeps the ball legible and whether a luminance-preserving pattern is wanted so the cosmetic roll is visible.
2. Juice says "all world elements" greys out. This ADR treats the ball as not a world element (no `hit_grey` uniform). Juice's GDD wording is confirmed in the design review.
3. Pickups (no system yet) take the exempt path (declare neither global) unless a later GDD says otherwise.

## Related Decisions

- ADR-0002, ADR-0003, ADR-0004, ADR-0011 (Hit flash overlay), ADR-0014 (hazard view and shader); ADR-0010 (presentation time: the grey-out crossfade runs on real time)
- `docs/architecture/architecture-review-2026-10-03.md`
