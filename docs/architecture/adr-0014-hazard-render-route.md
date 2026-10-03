# ADR-0014: Hazard render route and view node tree

## Status

Proposed

## Date

2026-10-03

## Last Verified

2026-10-03

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

The Obstacle GDD owns no height ("height is a rendering concern") and the art bible only *proposes* "one MultiMesh per family, about 60 triangles"; nothing decides how a variable-width arc hazard is turned into geometry, who owns the view, or how many draw calls it costs (architecture review 2026-10-03, finding G-1). This ADR decides: **one `MeshInstance3D` per hazard** (not per piece), taken from a pool built once at map load; the pieces of one hazard are merged into **one `ArrayMesh` per `HazardSpec`**, built once by a pure `HazardMeshBuilder` and cached by spec identity; all hazard bodies share **one `ShaderMaterial`**; the Double Gate plinth is a second surface of the same mesh with its own Environment-owned material; and Camera's far plane is bound to the fog end so fully fogged hazards are frustum-culled. A **silhouette-covers-footprint** invariant ties the visible mesh to the analytic collision footprint (no phantom hits, Pillar 2). A MultiMesh per family is rejected: a fixed mesh under a linear instance transform cannot reproduce an arc of variable angular width on a cylinder.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Rendering (mesh generation, instancing, materials on the Mobile renderer) |
| **Knowledge Risk** | HIGH for the renderer (ADR-0003); the APIs used here (`ArrayMesh.add_surface_from_arrays`, `MeshInstance3D`, `surface_set_material`) are stable since 4.0, but their behaviour on the Mobile renderer, instance shader uniforms and draw-call accounting are **unverified on 4.7.2** |
| **References Consulted** | `docs/engine-reference/godot/modules/rendering.md`, `breaking-changes.md`, `deprecated-apis.md`, ADR-0003, ADR-0008 |
| **Post-Cutoff APIs Used** | Typed `Dictionary[HazardSpec, ArrayMesh]` (4.4). `duplicate_deep()` is not used. `MultiMesh`, `custom_aabb` and vertex-shader deformation are deliberately **not** used |
| **Verification Required** | **NEEDS VERIFICATION (device, folded into gate R-1):** (1) hazard draw-call delta equals surfaces times instances inside the frustum (including a hazard that straddles the camera) on the Mobile renderer, and the count on the Forward+ fallback (a depth pre-pass may double it); (2) an `unshaded` spatial material still receives depth fog on Mobile, and at a distance below `fog_depth_begin` its output equals the art-bible luminances (face 0.079, shade 0.03, linear relative luminance, to be confirmed) after the tonemapper, with the R-1 pins `tonemap_exposure` 1.0, camera exposure multiplier 1.0, auto-exposure off, adjustments off; (3) every face is visible under `cull_back` (winding; a debug `cull_disabled` comparison); (4) `Camera3D.far` frustum culling removes a fully fogged hazard without a pop (fog density 1.0, depth mode), and the far plane does not clip the tube, props or sky wrongly; (5) the killer isolate of ADR-0012: `set_surface_override_material(0, ...)` on the killer node replaces only the body surface, and a pooled node released while isolated and rebound carries no override (no instance uniform is used, never `material_override`); (6) per-surface materials set on the `ArrayMesh` are shared by every node using the mesh; (7) prewarm time and memory for the shipped library (spike HV-1); (8) `reset_physics_interpolation()` and `physics_interpolation_mode = OFF` are belt and braces (project interpolation is off, ADR-0002); what prevents a stale-position flash is setting the transform **before** `visible = true` in the same tick; (9) `add_surface_from_arrays` AABB for chunk-local negative-z geometry, including the 5.4 rad Near-Ring; (10) headless creation of an `ArrayMesh` works but read-back may be empty, so tests assert on `HazardMeshData`; (11) 192 pooled hidden nodes leave no residual cost on device; (12) a Retry (second `apply_map` with a recompiled library) leaves no stale spec identity in the cache |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (view has no `_process`; `_wire()` rows), ADR-0003 (draw-call allocation, shared materials, warm-up scene, fog and tonemapper), ADR-0004 (`MapDefinition`, `MapConfig`, Phase B), ADR-0008 (`HazardSpec`, `hazard_bound`, `hazard_released`) |
| **Enables** | ADR-0012 (chroma exemption needs one node and one body material per hazard), the Obstacle view stories, the Environment plinth and preview stories, the Obstacle debug overlay |
| **Blocks** | Obstacle epic (view stories), Environment & Theming epic (plinth, Menu preview) |
| **Ordering Note** | Gate R-1 (ADR-0003) gains the hazard rows below; ADR-0004 now carries the Phase B step (B4, amended 2026-10-03); the `HazardStyle` field is a follow-up after Accepted |

## Context

### Problem Statement

A hazard is a set of pieces `(theta_min, theta_max, s_start, s_end)` with arbitrary angular width, from a seam-crossing 5.4 rad Near-Ring to a narrow Spike. The collision test is analytic on those numbers (ADR-0008). Nothing says how the same numbers become triangles, how many draw calls they cost, who owns the nodes, or what height a hazard has. The art bible's MultiMesh proposal cannot express variable width on a curved surface, and a node per piece can exceed the 40-call allocation (content bound: 12 pieces per segment).

### Constraints

- At most 150 draw calls total, 40 allocated to hazards (ADR-0003, provisional until R-1); 60 FPS on mid-tier Android.
- Hazards are the loudest element: full silhouette and chroma the instant they enter view, no fade, alpha ramp or LOD pop-in (TR-obstacle-system-023).
- The hit test equals the visible silhouette in the ball's band (Pillar 2): no hit without visible contact, no visible contact without a hit (beyond the documented one-frame AABB corner cut).
- Art bible 3b: abrupt joint with the tube, no curves in the silhouette, height at least one ball diameter, Spike single apex with its defining feature in the top third, Block flat-topped.
- No `CollisionObject3D`; no per-spawn copy of a Resource; no `_process` in views; no allocation during a run (ADR-0002, ADR-0003, ADR-0008).
- The tube is a 32-facet flat-shaded cylinder whose `R` is the **circumradius** (the facet centre lies at `R*cos(PI/32)`, 0.0144 u below `R` at `R` = 3).
- Environment: the fully fogged tube end must show no horizon; the plinth belongs to Environment and takes the 0.88 world chroma shift, the hazard body does not.

### Requirements

- Decide the geometry route, the node tree, the material split, the draw-call arithmetic and the culling rule.
- Keep every approved formula (world-space, float64) untouched: the view reads, never feeds back.
- Provide the hooks ADR-0012 needs (per-hazard node, hazard-only body material).

## Decision

### 1. Route: one node per hazard, one merged mesh per `HazardSpec`

`HazardMeshBuilder` (pure `RefCounted`, no `Node`, no `ArrayMesh`) turns one compiled `HazardSpec` plus a `HazardStyle` and the `WorldGeometry` constants into `HazardMeshData`: raw arrays (`PackedVector3Array` positions and normals, `PackedColorArray` colours) for surface 0 (body) and, for a DOUBLE_GATE, surface 1 (plinth). Coordinates are **chunk-local** (the spec's own `s` values, tube axis along Z, `z = -s`); the node transform supplies the world offset `z = render_z(s_offset)` (ADR-0013), so one mesh serves every segment the chunk is ever bound to. `HazardView` creates the `ArrayMesh` from the arrays once and caches it in `Dictionary[HazardSpec, ArrayMesh]` keyed by spec identity.

All pieces of one hazard (Double Gate: two blocks; Spike cluster: two or three needles) are merged into the same surface, so the draw cost is **per hazard, not per piece**. No `MultiMesh`, no vertex-shader deformation, no `custom_aabb` (the mesh AABB follows the node transform because no vertex is displaced in a shader).

### 2. Geometry (data-driven, from `HazardStyle`)

Constants: `R`, `D`, `N_F` = 32 (tube facets), `L`. `delta = 2*PI / N_F`. `r_apothem = R * cos(PI / N_F)`. `r_base = r_apothem - HAZARD_BASE_SINK` with `HAZARD_BASE_SINK = 0.05 * D` (a builder constant, not gameplay data): the body base sits below the faceted tube surface everywhere, so no crack shows and the joint stays abrupt.

Per piece with `k = ceil((theta_max - theta_min) / delta)` arc subdivisions (vertices exactly at `theta_min` and `theta_max`, unwrapped angles used as given, so a seam-crossing piece needs no special case):

- **Body prism:** every radial level from `r_base` up to `r_solid = R + D` has the **full footprint cross-section** (`theta_min..theta_max` by `s_start..s_end`). Sides are radial planes (constant theta) and caps are planes of constant `s`.
- **Top:** BLOCK, WALL, DOUBLE_GATE and NEAR_RING end in a flat top at `r_top = R + height_d(type) * D`, a faceted polyline with one quad per subdivision. Its vertices are placed at `r_top / cos(dsub/2)` (`dsub` = the subdivision angle, at most `delta`) so the **chord midpoint** lies at `r_top` and a circle of radius `r_top` never leaves the solid between vertices (without this the chord sags up to about 0.018 u). SPIKE keeps the prism to `r_solid` and then rises in **two planar slopes** from the two side edges (`theta_min` and `theta_max` at `r_solid`) to a **ridge line along `s`** at the piece centre angle and `r_top = R + height_d(SPIKE) * D`; the interior top vertices are ignored for SPIKE. Seen from the front the ridge reads as a triangle ("single apex"); it is a ridge, not a pyramid point.
- No bottom face (hidden inside the tube).
- **Winding:** Godot's front face is **clockwise**. Every triangle satisfies `cross(b - a, c - a) . outward_normal < 0` in the right-handed frame, so `cull_back` shows every face (sides, caps, top, taper), tested per face on `HazardMeshData` and checked on device against `cull_disabled`.
- **Vertices are duplicated per face; no normal array is consumed.** `HazardMeshData` carries `body_normals` and `plinth_normals` (flat per face; the winding unit tests use them), but `HazardView` adds no `ARRAY_NORMAL` to the mesh unless the lit fallback of Risks is taken, because the body material is unshaded. A surface without `ARRAY_NORMAL` on the Mobile renderer is not covered by the engine reference, so the R-1 hazard rows include it. `ARRAY_FLAG_COMPRESS_ATTRIBUTES` is not set (flags 0), so positions stay float32.
- **Colour per vertex** (`COLOR.r` = shade flag, exactly 0 or 1, stored 8-bit): face colour on the start cap (the `-s` face the approaching camera sees) and the top, shade colour on the side walls, the end cap and the spike slopes (proposal; the art director confirms, and also whether top and start cap merging into one flat region keeps "flat-topped" legible). The colour array length equals the vertex count (asserted; a missing `ARRAY_COLOR` would default to white and render every face as shade). Real colours are never stored in vertex colour.
- Triangles per piece: about `6k + 4`; a hard cap `MAX_HAZARD_TRIANGLES = 512` per hazard mesh is asserted at build (a Near-Ring of 5.4 rad is about 170).

**Silhouette-covers-footprint invariants (CPU-array invariants, tested on `HazardMeshData`, not on screen; GPU positions are float32):**

- I1: at `r_base` the piece's angular and `s` extents equal the piece bounds to 1e-6.
- I2: for every radius in `[r_base, R + D]`, **including the chord midpoints of the top polyline**, the cross-section extents equal the piece bounds (the whole ball band, centre `R + D/2`, radius `D/2`).
- I3: `r_top >= R + D` at the chord midpoints; the SPIKE slopes start at `r_solid`, never below.
- I4 (plinth reach): no raised plinth geometry lies within the ball's visual reach `sqrt(h * (D - h))` of any point outside the hit-expanded footprint (the piece bounds expanded by D/2 along `s` and by the ball's angular half-width); equivalently the footing's `s` extension is at most `D/2 - sqrt(h * (D - h))`, and no footing covers any part of a gap.

Why: the collision footprint is a rectangle in `(theta, s)` expanded by `BALL_HALF_ANGLE` and `D/2`. A sphere at the riding radius touching a radial plane has centre distance `(R + D/2) * sin(delta_theta)`, which is exactly that expansion; a tapered pyramid inside the ball band would make the player die without touching anything visible. The prism up to `R + D` removes that.

### 3. Style data: `HazardStyle` in `MapDefinition`

`HazardStyle` is a scalar-only `Resource` (floats and Colors, no nested Resource, same rule as `EnvConfig`) referenced from `MapDefinition.hazard_style`, validated by `MapLoader` Phase A (`HAZARD_STYLE_INVALID`) and carried as a validated copy in `MapConfig.hazard_style`:

| Field | Default (proposal) | Safe range |
|---|---|---|
| `height_d_wall`, `height_d_double_gate`, `height_d_near_ring` | 1.0 | 1.0 to 3.0 (at least one ball diameter, art bible 3b) |
| `height_d_spike` | 1.6 | 1.5 to 3.0 (taper inside the top third) |
| `face_color`, `shade_color` | Signal Red, Ember (art bible 4) | `face_color != shade_color`; luminances are read by Environment F1/F3, never changed here |

Per-map variation stays within the art bible 3g ceilings (proportions within 15%).

### 4. Node tree, pool and lifecycle

```text
WorldRoot (Node3D)
  TubeView                 (ADR-0003)
  HazardView (Node3D)      no _process; owns the pool, the mesh cache, two materials
    pool[0 .. P-1]  MeshInstance3D   P = N_MAX * MAX_PIECES_PER_SEGMENT (192), all created once, visible = false, mesh kept as last assigned (never null after the first bind), cast_shadow OFF, physics_interpolation_mode OFF
    preview         MeshInstance3D   one reserved node for the Menu preview hazard (Environment Rule 6), not part of the pool
  BallView, ...
```

- **Build and prewarm** are a new **Phase B step** (ADR-0004 follow-up): `HazardView.apply_map(cfg: MapConfig, geometry: WorldGeometry, library: CompiledLibrary, plinth_material: ShaderMaterial) -> bool`, after `Pattern.apply_map` and before `TubeTrack.load_map` (step B4 of the amended ADR-0004; `MapLoaderSeams` gains `apply_hazard_view`). `geometry` is the one immutable `WorldGeometry` value (`R`, `D`, `N_F`, `L`) that `GameRoot` builds at composition from the base `TubeConfig` and `BallConfig` and validates before the first `MapLoader.attempt`; it is the same value passed to `BallView.build` and `CameraMath.published`, so `D` has one owner (Ball Movement) and `TubeConfig` holds no copy; `MapConfig` carries none of them; `plinth_material` and the plinth height come from Environment, whose `apply_map` (B1) creates the material first, so surface 1 is never null. **Environment mutates that material's uniforms and never replaces the object**, or the shared meshes would go stale. It creates the pool (first call only), builds every mesh of the library, sets the per-surface materials on each `ArrayMesh`, and returns `false` on failure (the seam is bool-only, so the codes such as `HAZARD_MESH_FAILED`: non-finite value, triangle cap, bad style go to the log sink and the loader reports `MAP_APPLY_FAILED`). It creates only inert hidden nodes and resources: no signal, no visible change, no tick effect, idempotent (Retry clears the cache and rebuilds, because Pattern recompiles and the spec identities change). **ADR-0004 wording follow-up:** apply steps may "build inert hidden nodes and resources". Pattern gains a read-only `compiled_library()` getter. **Boot budget:** the prewarm shares ADR-0004's MS-1 boot budget (100 ms for load, validate, apply and Tube Track prime); HV-1 measures it and, if the sum misses 100 ms, the MS-1 number is re-derived with the prewarm included (the earlier 250 ms proposal is dropped).
- **Bind:** `ObstacleCore` still emits `hazard_bound(hazard_id, footprint)` (ADR-0008 unchanged) and gains two read accessors next to `footprint_of`: `spec_of(hazard_id) -> HazardSpec` and `s_offset_of(hazard_id) -> float`, valid **during** the emission (Obstacle records state before it emits; tested). Extending the signal payload was rejected to keep ADR-0008's contract. `HazardView._on_hazard_bound` takes a free node, **stores `s_offset` in its own per-node record** (so `rebase()` never calls the Obstacle accessor outside the emission), looks up `cache.get(spec)` (asserted non-null), sets `position = Vector3(0.0, 0.0, world_frame.render_z(s_offset))` (a float64 value cast to float32 only there, ADR-0013), clears any surface override (ADR-0012), calls `reset_physics_interpolation()` (belt and braces, interpolation is off), and sets `visible = true` **last**, so no stale transform is ever drawn. Nothing is allocated.
- **Release:** `hazard_released(hazard_id, released_by_reset)` hides the node, clears any surface override and returns it to the free list; the mesh stays assigned (the cache holds it anyway). `release_all()` is explicit and used by `window_primed`, Retry and reset before rebinding in the same tick.
- **Menu and the primed window:** `load_map` primes the window at boot, so hazards may bind behind the Menu. `HazardView` hides the whole pool (`pool_root.visible = false`, one flag) outside the phases that show gameplay and shows it when a run begins (the Menu shows only the `preview` node, Environment's Menu row). The phase rule is wired from `phase_changed` in `_wire()`. NEEDS CONFIRMATION in the Environment and Run State review (Open Question 3).
- **Wiring:** `HazardView` handlers are `_wire()` rows ranked after Obstacle's emit and before `Juice.tick`, immediate connections (ADR-0002). A bind in tick `t` is drawn in frame `t`.
- **Lookup:** `HazardView` keeps `hazard_id -> node` in a `Dictionary[int, MeshInstance3D]` of at most 192 entries; `node_of` is for tests; the killer isolate of ADR-0012 is `HazardView.isolate_killer(hazard_id)` / `clear_isolation()`, which find the node themselves.
- **Pool exhaustion** cannot occur for a content-legal library (`TOO_MANY_PIECES` caps pieces per segment at 12, pieces at least as many as hazards); the code asserts in debug and logs and skips the bind in release.

### 5. Materials

- **Body material:** one `ShaderMaterial` (`hazard_body.gdshader`), `unshaded`, opaque, depth fog on (no `fog_disabled`, no `skip_vertex_transform`), `cull_back`, no shadows; the pooled nodes set `cast_shadow` OFF and `gi_mode` disabled. `face_color` and `shade_color` are `source_color` uniforms (authored as sRGB); the colour is `mix(face_color, shade_color, step(0.5, COLOR.r))` (a threshold, because Mobile varyings are mediump), regardless of lights, so the unfogged luminances (below `fog_depth_begin`) equal the art-bible values that Environment F1 and F3 assume. The shader uses no preprocessor (uniforms and `group_uniforms` only), covered by the ADR-0003 lint. It has **no world-chroma uniform**: hazards are exempt from the 0.88 shift by construction. ADR-0012 adds the Hit grey-out term and chooses its mechanism; the recommended path is one shared grey uniform for every hazard plus a pre-built second material of the same shader with grey 0 set on the killer node's **surface 0 only** (`set_surface_override_material(0, ...)`), which leaves the plinth surface alone.
- **Plinth material:** a second `ShaderMaterial` owned by Environment (colour from `EnvConfig`, chroma at most 0.05, never the Signal Red or Ember value, subject to the world chroma shift), set as surface 1 of Double Gate meshes at build.
- Both materials are set **on the `ArrayMesh` surfaces** (shared by every node), never as `material_override` in steady state.
- Both are rendered once in the ADR-0003 warm-up scene, together with the killer-override material and the Menu `preview` node, so no shader or render-state variant is first seen at Hit.

### 6. Culling and draw-call arithmetic

- **Camera far plane:** Camera publishes `camera_far = F_rest + L` where `F_rest` is the **resting** fog end (`fog_end_distance`, 84 u at Map 1; derived in ADR-0004 Phase A step A5 from the validated `MapConfig.env`, not by `CameraMath.published` at composition, which has no map) and is **constant**: the speed pull of `fog_depth_end` (Environment F2) never changes the projection. The far plane is axial depth and fog distance is radial (radial is never smaller), so a fragment beyond axial `F` is already beyond radial `F` and 100% fogged; `far = F` would be correct and the `+ L` is only a conservative margin. A hazard fully swallowed by fog is frustum-culled with no code in the tick. Fog colour equals the background (ADR-0003; R-1 checks the sky band at the tube end), so the cut is invisible. The far plane also clips the tube, props and sky, which R-1 checks.
- **Bound:** consecutive hazard starts are at least `S_MIN_SPACING` (6.25 u) apart (preflight P1 within a chunk, the sequencer across chunks). Culling is by AABB, so a hazard that starts just behind the camera and extends into view is still drawn: hazards drawn at most `floor((camera_far + max_hazard_s_length) / S_MIN_SPACING) + 1`, about 17 at the defaults. Draw calls: 17 bodies + at most 17 plinth surfaces (if every hazard were a Double Gate) = **34 worst case, under the 40 allocation**; the realistic figure is about 10 to 14. The Menu adds the `preview` node (1 to 2).
- **Forward+ fallback:** a depth pre-pass may roughly double these counts (about 68 worst case, over the 40 allocation); the fallback of ADR-0003 therefore re-measures this figure, and the escalation below applies.
- If R-1 measures more than 40, escalate to **mesh per segment** (route B, merged bodies with a per-vertex hazard ordinal, and the ADR-0012 isolate mechanism adapted); the `HazardView` interface (`bind`, `release`, `node_of`) does not change.

### 7. Menu preview and debug overlay

- `HazardView.show_preview(spec: HazardSpec)` and `hide_preview()` fill the reserved `preview` node from the same mesh cache; Environment owns the screen anchor and the transform (Rule 6, AC-12). It uses the same materials and costs no pooled node.
- The developer-only effective-footprint overlay required by the Obstacle GDD before chunk authoring is a **separate editor-only tool** (gated on `OS.has_feature("editor")`) that draws `footprint_of` with the builder's arc-polyline helper; it adds no draw call to a release build.

### Architecture Diagram

```text
MapDefinition.hazard_style --validated--> MapConfig.hazard_style
CompiledLibrary (ADR-0008) --apply_map--> HazardMeshBuilder.build(spec, style, tube) --> HazardMeshData
                                           HazardView: ArrayMesh cache [spec] (surface 0 body, surface 1 plinth), materials on surfaces
ObstacleCore.hazard_bound(id, footprint) --> HazardView.bind: node = free pool node, mesh = cache[spec], z = render_z(s_offset), visible
ObstacleCore.hazard_released(id, reset)  --> HazardView.release: hidden, override cleared, mesh kept
Camera: far = fog_end + L (frustum culls fully fogged hazards)
```

### Key Interfaces

```gdscript
class_name HazardMeshBuilder extends RefCounted          # pure, unit-testable
static func build(spec: HazardSpec, style: HazardStyle, geometry: WorldGeometry, plinth_height_d: float) -> HazardMeshData

class_name HazardMeshData extends RefCounted
var body_vertices: PackedVector3Array; var body_normals: PackedVector3Array; var body_colors: PackedColorArray
var plinth_vertices: PackedVector3Array; var plinth_normals: PackedVector3Array   # empty unless DOUBLE_GATE
var triangle_count: int

class_name HazardView extends Node3D                     # no _process (ADR-0002)
func apply_map(cfg: MapConfig, geometry: WorldGeometry, library: CompiledLibrary, plinth_material: ShaderMaterial) -> bool   # Phase B step; codes to the log sink
func release_all() -> void
func rebase() -> void                                    # ADR-0013: re-places every bound node through render_z(its stored s_offset), then reset_physics_interpolation()
func bind(hazard_id: int, spec: HazardSpec, s_offset: float) -> void   # called by the hazard_bound handler
func release(hazard_id: int) -> void
func node_of(hazard_id: int) -> MeshInstance3D                         # null if not bound; test-only
func isolate_killer(hazard_id: int) -> void                            # ADR-0012: surface 0 override, idempotent, owns the state
func clear_isolation() -> void
func show_preview(spec: HazardSpec) -> void
func hide_preview() -> void

# ObstacleCore additions (read only, next to footprint_of)
func spec_of(hazard_id: int) -> HazardSpec
func s_offset_of(hazard_id: int) -> float
```

## Alternatives Considered

### Alternative 1: One `MultiMeshInstance3D` per family (art bible proposal)
- **Description**: one unit mesh per family, instance transform per hazard.
- **Pros**: 3 to 5 draw calls.
- **Cons**: a linear transform cannot give a variable angular width on a cylinder; a vertex shader that bends a unit mesh from per-instance custom data needs `custom_aabb`, analytic flat normals in the shader, and an unverified Mobile path, and any mismatch with the collision footprint is a Pillar 2 bug.
- **Rejection Reason**: the savings are not needed (34 worst case against 40) and the risk is on the fairness-critical silhouette.

### Alternative 2: One `MeshInstance3D` per piece
- **Description**: a node and a mesh per `HazardPiece`.
- **Pros**: simplest mapping from data to nodes.
- **Cons**: up to 12 pieces per segment times 8 visible segments exceeds 40; Double Gate and Spike clusters split one hazard across several nodes, which breaks the single killer isolate.
- **Rejection Reason**: the draw cost scales with pieces, not hazards.

### Alternative 3: One merged mesh per segment
- **Description**: all hazards of a segment in one mesh.
- **Pros**: fewest draw calls (at most the visible segments).
- **Cons**: the killer hazard cannot be isolated from the others without a per-vertex ordinal and a uniform that selects it, which pulls ADR-0012 into this ADR's geometry.
- **Rejection Reason**: not needed now; held as the escalation path.

### Alternative 4: Per-spawn translated mesh built at bind
- **Description**: build the `ArrayMesh` when a segment enters the window.
- **Pros**: no prewarm.
- **Cons**: a mesh build inside the tick risks a hitch and breaks "no allocation during a run".
- **Rejection Reason**: replaced by a build at map load.

## Consequences

### Positive
- Draw cost follows the number of hazards, bounded at 34 by content rules already enforced elsewhere.
- Collision and visuals agree by construction, with a unit-testable invariant.
- One node and one body material per hazard give ADR-0012 a clean isolate hook.
- A bad style or mesh fails at map load, not mid-run.

### Negative
- A pool of 192 hidden nodes (memory only) and one extra Phase B step.
- Mesh data for the whole library lives in memory (about 4 MB at a few hundred specs, to be measured).
- Plinth and hazard body cannot be batched (separate materials, one extra draw per Double Gate).

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Unshaded hazard material loses depth fog on Mobile | Low | High | R-1 check 2; fall back to a lit material with fixed lights and re-derive the luminances |
| Hazard draw calls exceed 40 on device | Low | Medium | worst case 34 by construction; escalate to route B |
| `camera_far` culls a hazard that fog has not fully hidden | Low | High | far is `F + L`, and the R-1 pop check; Camera validates `far >= F` |
| Plinth span clips the ball in a gap (see Open Question 1) | Medium | High | resolved: per-piece footings, `s` extension capped at 0.114 u, invariant I4; the Environment GDD revision (Rule 10, TR-environment-theming-012, AC-14) must land before the Environment plinth stories |
| Prewarm too slow at boot | Low | Low | spike HV-1; threaded build is not possible for `ArrayMesh` on the main thread, so reduce triangles or lazy-build in a loading frame |
| Face/shade assignment disagrees with the art direction | Medium | Low | one builder function; art director confirms before asset spec |

## Performance Implications

| Metric | Expected | Budget |
|---|---|---|
| Draw calls (hazards) | 10 to 14 typical, 34 worst case (17 bodies + 17 plinths, AABB window) on Mobile; about double on Forward+ | 40 (ADR-0003), measured in R-1 |
| CPU per tick | bind and release: a few property writes, at most two binds per tick | within the 3 ms simulation budget |
| Memory | one mesh per spec (at most 512 triangles each) plus 193 nodes | 512 MB ceiling |
| Boot | `apply_map` builds all meshes once | inside the MS-1 boot budget (ADR-0004), measured by spike HV-1 |

## Migration Plan

Greenfield. Add `HazardStyle` to `MapDefinition`, the Phase B step to ADR-0004, accessors to `ObstacleCore`, and the Camera `camera_far` value. Update the art bible 3b line ("one MultiMesh per family") and ADR-0003 draw-call text (hazards: node per hazard, 34 worst case) once Accepted.

## Validation Criteria

- [ ] `HazardMeshBuilder` unit tests (arrays only): winding (cross product against the outward normal on every face), colour array length equals vertex count and `COLOR.r` is exactly 0 or 1, plinth footing never enters a gap and has no coplanar face with the body, I1, I2, I3 (at chord midpoints) and I4 (plinth reach, with the extension at 0 and at its cap) on every hazard type; a seam-crossing piece (`theta_max > PI`); a 5.4 rad Near-Ring; triangle cap; determinism (same input, identical arrays); non-finite input rejected with a code.
- [ ] Integration test (real nodes, headless): bind and release reuse nodes, the node count never changes after `apply_map`, `visible` and `mesh` follow the lifecycle, a reset releases and rebinds in one tick, `apply_map` twice with a recompiled library is idempotent and `cache.get(spec)` never misses (Retry); `spec_of` and `s_offset_of` are valid inside the `hazard_bound` handler; Environment changing a plinth uniform is followed by every shared node; the pool is hidden in the Menu.
- [ ] R-1 hazard rows (device): draw-call delta, fog on the unshaded body, a surface with no `ARRAY_NORMAL` renders correctly, flat shading, no pop at the far plane, 60 FPS at 16 visible hazards (the spacing worst case).
- [ ] Lint: no `MultiMeshInstance3D` or `MultiMesh` in hazard code; no `ArrayMesh` creation outside `HazardView.apply_map`; no `CollisionObject3D` (ADR-0008).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/obstacle-system.md` | Obstacle System | TR-obstacle-system-023: full silhouette and chroma the instant a hazard enters view, no fade or LOD; draw calls within 150 | node per hazard, fully fogged hazards culled by the far plane, 34 worst case against the 40 allocation |
| `design/gdd/obstacle-system.md` | Obstacle System | CR1 "height is a rendering concern", hazard reaches at least `R + D/2`; hit equals visible silhouette | `HazardStyle` heights, invariants I1 to I3 |
| `design/gdd/environment-theming.md` | Environment & Theming | TR-environment-theming-012 and Rule 10: Double Gate plinth, environment-owned, 0.15 D, chroma at most 0.05, world chroma shift | plinth as surface 1 with an Environment-owned material (span: Open Question 1) |
| `design/gdd/environment-theming.md` | Environment & Theming | Rule 6: Menu preview hazard holds a screen position | reserved `preview` node, `show_preview` |
| `design/art/art-bible.md` | Art bible 3b | abrupt joint, no curves, height at least D, Spike tip-first, Block flat-topped; "one MultiMesh per family" proposal | base sunk below the faceted tube, polyline silhouette, taper in the top third; the MultiMesh proposal is superseded |
| `design/gdd/juice-feedback.md` | Juice & Feedback | killer hazard isolate at Hit | one node and one body material per hazard; `node_of(hazard_id)` |
| `design/gdd/tube-track.md` | Tube Track | F7 facets (R is the circumradius), fog depth mode | `r_apothem`, base sink, far plane tied to the fog end |

## Open Questions

1. **Plinth span versus the ball's path.** RESOLVED 2026-10-03 (technical-director review, adopted by the project owner; the Environment GDD revision is still pending). Environment Rule 10 / TR-environment-theming-012 give the plinth a span of the gate arc plus 0.5 D margin each end and a height of 0.15 D (0.12 u). That span covers the gap the player must fly through, and the ball floats at most 0.0144 u above the faceted surface, so a 0.12 u lip across the gap makes the ball visibly cut through geometry that does not hit it. The first proposal (per-piece footings extended by 0.5 D along `s`) also fails Pillar 2: a lip of height `h` = 0.12 u is touched by the ball's sphere when its centre is within `sqrt(h * (D - h))` = 0.286 u of the lip edge, while the hit expansion along `s` is only D/2 = 0.4 u, so with a 0.4 u extension the ball would visibly touch the lip for about 0.29 u before any hit. **Decision:** the builder emits **per-piece footings** (never one span across the gap), angularly inset by a small epsilon inside the hazard footprint (coplanar radial faces of two colours would z-fight), and the extension of a footing along `s` is capped at `e_max = D/2 - sqrt(h * (D - h))` = 0.114 u (default `PLINTH_S_EXTENSION` = 0, safe range 0 to 0.11 u). Invariant **I4** (below) is the check. The Environment GDD must be revised (Rule 10, TR-environment-theming-012, AC-14); its premise that the plinth "can never foul the ball's path" is wrong for the gate gap. The gap is never narrowed or covered.
2. NEAR_RING has no art family yet (Obstacle OQ5); it uses the flat-topped prism profile until the art director decides.
3. Whether the Menu keeps hazards bound behind the screen (the primed window at boot): this ADR hides the pool in the Menu; Run State and Environment confirm.

## Related Decisions

- ADR-0002, ADR-0003, ADR-0004, ADR-0008; ADR-0012 (chroma and killer isolate), ADR-0013 (distance precision at large `s`: node placement through `WorldFrame.render_z`, `HazardView.rebase()`)
- `docs/architecture/architecture-review-2026-10-03.md` (G-1)
