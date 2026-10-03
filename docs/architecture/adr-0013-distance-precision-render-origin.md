# ADR-0013: Distance precision and the render origin (WorldFrame)

## Status

Proposed

## Date

2026-10-03

## Last Verified

2026-10-03

## Decision Makers

Project owner (approach, 2026-10-03); godot-specialist review incorporated 2026-10-03

## Summary

Gameplay distance `s` is a 64-bit float and stays exact for any run length. A 32-bit render position is not: world z = `-s` loses precision as a run gets long (0.0024 u, half a pixel at the ball's distance, is exceeded at `s` = 16384 under the 2-ulp model and at 4096 under the 8-ulp model). This ADR keeps `s` unbounded and shifts the **render origin** instead: one `WorldFrame` value (`origin_s`, a whole number of segments) maps every placed node with `render_z(s) = -(s - origin_s)`, and `GameRoot` rebases the origin in one named step when `s - origin_s` reaches `REBASE_SEGMENTS * L` (default 84 segments, 1008 u). Render z never exceeds about 1130 u, so error stays under 0.0024 u for any run length. No run cap, no double-precision engine build.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core / Rendering |
| **Knowledge Risk** | HIGH for the project (post-cutoff engine); this decision uses only `Node3D.position`, `Transform3D` and `MeshInstance3D` basics, which did not change after 4.3 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/rendering.md`, `breaking-changes.md`, `deprecated-apis.md`; `design/gdd/tube-track.md` (Rule 8, F4, Open Question 13) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | **Not in the engine reference, carried as a spike (PRC-1, device; godot-specialist review 2026-10-03 expects the 8-ulp bound to hold with margin because nothing is made camera-relative on the CPU in a single-precision build):** (1) default Godot builds store node transforms and view matrices in 32-bit floats, so the error model (2 ulp or 8 ulp) is an assumption until measured; (2) whether the Mobile renderer computes camera-relative transforms on the CPU in 32-bit or in 64-bit (this ADR is correct either way, it only decides how large the safe zone would be without the rebase); (3) that a rebase tick shows no visible shift on a device (PT-style frame capture across a rebase); (4) that `Vector3` components built from a float64 difference lose no more than 1 ulp (expected, tested on the host) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (per-frame order, `_wire()` ranks, no view `_process`), ADR-0003 (tube slots, `bind_slot`), ADR-0004 (`WorldGeometry`, `TubeConfig`), ADR-0014 (hazard node placement), ADR-0012 (`BallView.tick` placement) |
| **Enables** | Runs of unbounded length; the first-playable device check of Open Question 13 becomes a regression check instead of a risk |
| **Blocks** | Tube view, Hazard view, Ball view and Camera view stories (all place nodes through `WorldFrame`) |
| **Ordering Note** | Amends ADR-0002 Decision 6 (one new named step, `WorldFrame step`, right after `TubeTrack.advance`), ADR-0003 (`TubeView.rebase`), ADR-0012 (the "shared mapping function" note) and ADR-0014 (`HazardView.rebase`, placement through `render_z`) once Accepted; the Tube Track GDD (Rule 8, F4, Open Question 13, AC-15) and `TR-tube-track-017` are revised |

## Context

### Problem Statement

`TR-tube-track-017` says: `s` is 64-bit, `z = -s` is cast to 32 bits only when a `Vector3` is built, there is **no rebase**, one debug warning per run at `s >= S_PRECISION_LIMIT` (16384, or 4096 under the 8-ulp model), and "the treadmill is the fallback". That is a deferral, not a decision: the limit is 655 s at `V_MAX` = 25 (2-ulp) or 164 s (8-ulp, 4096), against planned runs of 1 to 5 minutes. A good run in the conservative model reaches the limit inside the planned range, and the failure shows as jitter of the whole world relative to the ball, which breaks Pillar 2 (a death must be the player's, not the renderer's). The Tube Track GDD removed an earlier render-origin rebase to keep the MVP simple and parked the question as Open Question 13 and as a pointer to this ADR (ADR-0003, ADR-0012, ADR-0014 all cite "ADR-0013").

### Constraints

- Gameplay is float64 end to end: `s`, `s_offset`, footprints (`PackedFloat64Array`), Scoring's distance. Nothing in logic may change.
- Default Godot builds (and the Android export templates) are single precision; a double-precision build needs SCons and custom export templates and is unverified on Android.
- No view has a `_process` (ADR-0002); the per-frame order is written only in `GameRoot._tick`.
- The seam is a segment-local analytic shader pattern with no `s` uniform (ADR-0003), and `TIME` is banned for effects (ADR-0010), so a shift of whole segments changes nothing a shader sees.
- Tube Track's window logic works in integer segment indices; slots are recycled and only their transforms are set (ADR-0003 `bind_slot`).
- 60 FPS, 16.6 ms, mid-tier Android: any per-frame cost must be negligible.

### Requirements

- World-position error of at most 0.5 px at the ball's distance, 0.0024 u (Tube Track F4), for **any** run length.
- Safe under the conservative 8-ulp model, not only 2-ulp.
- No visible change on the rebase tick (no pop, no seam shift, no hazard jump).
- One owner of the `s` to render-position mapping, so a node cannot be placed with raw `s` by accident.
- Testable on the host without a renderer.

## Decision

### 1. Keep `s` unbounded; shift the render origin

`s` (Ball Movement, float64) is never reduced, wrapped or capped. A pure, engine-free `WorldFrame` (`RefCounted`, built by `GameRoot` at composition, injected into every view that places a node) holds:

- `origin_s: float` (float64), always an exact multiple of `L` (so also of the seam period `SP`, which divides `L`), 0 at run start;
- `render_z(s: float) -> float`: `-(s - origin_s)` (`s` is monotone non-decreasing during a run, Ball Movement Rule 7, so the result only goes positive for nodes behind the ball; it is bounded either way and the soak test and the debug assertion cover both signs), computed in float64, returned as a float that the caller stores in a `Vector3` (this is the **only** place the world distance is cast to 32 bits; it supersedes "z = -s is cast when the Vector3 is built");
- `maybe_rebase(s: float) -> bool`: if `s - origin_s >= REBASE_SEGMENTS * L`, set `origin_s += floor((s - origin_s) / L) * L` (the remainder `s - origin_s` is then in `[0, L)`), and return `true` once for that tick; otherwise `false`.

Rebasing a whole number of segments keeps every segment boundary on the same render grid, so slot `i` after a rebase sits at the same render z as the slot that holds the same relative segment before it (the view re-binds, it does not move anything relative).

### 2. One named step in the per-frame order

`GameRoot._tick` gains **`WorldFrame step`** immediately after `TubeTrack.advance` (and before `Obstacle.test`; ADR-0002 Decision 6 amendment):

```
if _world_frame.maybe_rebase(ball.s):
    _tube_view.rebase()      # re-binds all N slots with render_z
    _hazard_view.rebase()    # re-places every bound node with render_z(s_offset)
```

The rebase therefore happens in the same tick as the `s` change and before any placement that reads the new `origin_s` (`Camera` step, `BallView.tick`) and before the frame is drawn, so no frame is ever drawn with a half-shifted world. It runs only when `advance` ran (Running); Pause, Hit, Resuming and Menu never rebase, so effect nodes created at the Hit (shards at the ball's pose) never outlive a rebase. `GameRoot._tick` is the single writer of these transforms and runs from `_process` (ADR-0002); engine transform writes are flushed to the RenderingServer after `_process` and before draw. Slot and hazard binds made earlier in the same tick (window priming inside `advance`) are covered because `rebase()` re-places every bound node from its stored `segment_index` or `s_offset`.

**Physics interpolation is off.** The project setting `physics/common/physics_interpolation` is pinned to `false` (ADR-0003 already sets `physics_interpolation_mode = OFF` on the slots because `GameRoot` drives them); any re-placed node also calls `reset_physics_interpolation()` in `rebase()` (available since 4.3), so a future switch of the setting cannot smear a 1008 u teleport over one tick. The `project_setting` lint (ADR-0009) asserts the key stays `false`. `WorldFrame.on_run_reset` sets `origin_s = 0` as a `_wire()` row at **rank 1** (before Tube Track's adapter at rank 2 re-primes the window), and `load_map` and `to_idle` start from `origin_s = 0`.

### 3. Placement rule: no raw `s` in a `Vector3`

Every node whose position depends on `s` is placed through `WorldFrame.render_z`:

| Consumer | Placement | Rebase hook |
|---|---|---|
| `TubeView` slots | `render_z(segment_index * L)` in `bind_slot` | `rebase()` re-binds all N slots |
| `HazardView` nodes (ADR-0014) | `Vector3(0, 0, render_z(s_offset))` at bind | `rebase()` loops the bound nodes (at most 192, normally 10 to 17 live) |
| `BallView.tick` (ADR-0012) | `render_z(snapshot.s)` every tick | none (placed every tick) |
| Camera view | the core publishes a **ball-relative** pose (offsets from the ball) and the view adds `render_z(s_ball)` | none |
| Near-miss ring ball-position uniform (ADR-0003, ADR-0010) | render-space ball position | none (written every tick) |
| Environment props (MultiMesh) | **chunked** `MultiMeshInstance3D` nodes with chunk-local instance transforms, each chunk node placed through `render_z` and re-placed in a `rebase()` hook (one long MultiMesh needs a buffer rewrite and a huge AABB that defeats culling) | audit item at the Environment epic |
| Running-state effects that live across ticks (particle trails, sparks, speed lines) | `GPUParticles3D` with `local_coords = true`, or parented to the ball (a world-space particle simulation would jump at a rebase) | rule for Juice and Environment view stories |
| Lights, `AudioStreamPlayer3D`, any other positioned node | generic rule: a node whose position depends on `s` is placed through `render_z` and has a `rebase()` hook, or is parented to the ball-relative frame | review rule |

**Shaders:** no shader reads world-space z (`WORLD_POSITION`, `MODEL_MATRIX[3]`, world-space noise, triplanar, dissolve) unless its period divides `REBASE_SEGMENTS * L`; keep such math in view or model space (the seam is segment-local and already complies; Android drivers may also relax fragment precision, which the Mobile renderer reference does not cover). Directional-light shadows are off (ADR-0003 Decision 5), so cascade snapping does not apply.

Cores never store a world z in a `Vector3`: `CameraCore` and `ObstacleCore` keep `s` as a float64 and publish offsets. Tube Track keeps the segment index as an `int`.

### 4. Budget and validation

`Z_RENDER_MAX = 2048` u: the error of an 8-ulp model at 2048 is `8 * 2^-12 = 0.00195` u, inside the 0.0024 u requirement. At composition, `GameRoot` validates the `WorldFrame` config together with `WorldGeometry`: `(REBASE_SEGMENTS + A + 1) * L <= Z_RENDER_MAX`, else `REBASE_Z_EXCEEDS_BUDGET` (fatal at boot, like `FOG_BEFORE_READ`). Defaults: `REBASE_SEGMENTS` = 84, `L` = 12, `A` = 9 give `(84 + 9 + 1) * 12 = 1128 <= 2048`, ulp(1128) = 2^-13 = 1.2e-4, 8 ulp = 9.8e-4. In debug builds `render_z` asserts `abs(result) <= 2 * Z_RENDER_MAX`, which catches a view that kept a stale origin or placed a node with raw `s`.

Tube Track's `S_PRECISION_LIMIT` warning is retired: `s` is float64 and exact to 2^53 (about 3.6e8 s at `V_MAX` = 25), and render precision no longer depends on `s`. The constant remains in the GDD only as a historical note (revision flag below).

### Architecture Diagram

```
Ball Movement (float64 s) --advance--> TubeTrack (int segment window)
        |                                      |
        v                                      v
   WorldFrame step:  maybe_rebase(s) --yes--> TubeView.rebase(), HazardView.rebase()
        |
        +--> render_z(s) = -(s - origin_s)  (float64 -> float32 here only)
                 |-- TubeView.bind_slot       (segment_index * L)
                 |-- HazardView.bind          (s_offset)
                 |-- BallView.tick            (snapshot.s)
                 `-- Camera view              (ball-relative offsets + render_z(s_ball))
Logic (Obstacle.test, Scoring, Pattern, Near-miss) never sees origin_s.
```

### Key Interfaces

```gdscript
class_name WorldFrame extends RefCounted        # no engine calls, unit-testable
var origin_s: float                              # float64, exact multiple of L; 0 at run start

func _init(config: WorldFrameConfig, geometry: WorldGeometry) -> void
func render_z(s: float) -> float                 # -(s - origin_s); asserts |result| <= 2 * Z_RENDER_MAX in debug
func maybe_rebase(s: float) -> bool              # true once per rebase; origin_s += floor((s - origin_s) / L) * L
func on_run_reset(run_id: int) -> void           # origin_s = 0 (_wire() row, rank 1)

class_name WorldFrameConfig extends Resource     # validated(log_sink) -> copy; clamps
# REBASE_SEGMENTS 84 [24, 128]; Z_RENDER_MAX 2048 (a constant, not a knob)

# view additions
# TubeView.rebase() -> void        re-bind all N slots through render_z
# HazardView.rebase() -> void      re-place every bound node through render_z(s_offset_of(id))
```

## Alternatives Considered

### Alternative 1: Keep no rebase; warn at `S_PRECISION_LIMIT`; treadmill as the fallback (the existing TR-017)
- **Description**: `s` float64, `z = -s` cast per `Vector3`, one debug warning per run, device check at first playable.
- **Pros**: no work now; Tube Track keeps the change "local".
- **Cons**: it is not a decision; the 8-ulp model puts the limit at 164 s, inside planned runs; the fallback would then touch the same four view systems under deadline pressure with real code in place; the warning only exists in debug builds, so a player build jitters silently.
- **Rejection Reason**: the project is greenfield and the four view ADRs are still Proposed, so the placement seam costs the least now.

### Alternative 2: Treadmill (ball and camera fixed, world repositioned every frame)
- **Description**: ball and camera stay at a fixed z; every slot and hazard node is placed at `-(s_i - s)` each frame.
- **Pros**: z is always small, no rebase event.
- **Cons**: about 30 transform writes every frame (a per-frame tick on `HazardView`, which has none), the seam and every static world node become moving nodes, and the ball and camera stop being the world's reference frame (Camera and Ball View ADRs would change).
- **Rejection Reason**: the same precision guarantee at a higher steady cost and a larger change than a periodic rebase.

### Alternative 3: Hard run cap at `S_PRECISION_LIMIT`
- **Description**: end the run when `s` reaches the limit.
- **Pros**: trivial.
- **Cons**: a run ends for a technical reason, not the player's (Pillar 2); the cap sits inside the 8-ulp range of plausible good runs.
- **Rejection Reason**: breaks the design pillar; the project owner decided against it on 2026-10-03.

### Alternative 4: Double-precision Godot build (`precision=double`)
- **Description**: build the engine and the Android export templates with 64-bit world coordinates.
- **Pros**: no gameplay or view change.
- **Cons**: SCons and custom export templates for the whole pipeline (CLAUDE.md lists SCons only for the engine), higher GPU data volume and CPU cost on mid-tier Android, and unverified on this device class and on 4.7.2.
- **Rejection Reason**: the cost lands on every build and every device for a problem a 4-line origin shift solves.

## Consequences

### Positive
- Render error is bounded for any run length under both error models; Pillar 2 does not depend on run length.
- Gameplay, Scoring, Pattern, Obstacle and Near-miss code and tests are untouched (float64 `s`).
- One mapping function and one debug assertion make "a node placed with raw `s`" a failing test, not a late jitter bug.
- The rebase is whole segments, so the seam phase (`fposmod(s, SP)`, segment-local) and slot grid are unchanged.

### Negative
- Four view systems (Tube, Hazard, Ball, Camera) now depend on `WorldFrame`; Tube Track's Rule 1 "keeps the change local to Tube Track" is no longer true for the fallback (the GDD removed this rebase earlier; this ADR reverses that, with the project owner's approval).
- One more named step in `_tick` and one more spy-test line.
- A rebase tick re-places about 12 + 17 nodes (negligible, about every 40 s at `V_MAX`), and every future world node needs a placement decision (the table above).

### Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| A view keeps a stale origin or places with raw `s` and the world pops at the rebase | Medium | High | debug assertion in `render_z`; a unit test that rebases and compares every placed z against a fresh placement; lint (below); PRC-1 frame capture across a rebase |
| Environment props, world-space particles, lights or a world-space shader are placed in world z and miss the hook | Medium | Medium | the placement table and shader rule above; audit at the Environment and Juice epics; PRC-1 |
| `floor((s - origin_s) / L)` misrounds one segment at an exact boundary | Low | Low | the same boundary test already required for `floori(s / L)` (Tube Track F2, literal 11.999999999999998); remainder asserted in `[0, L)` |
| Float32 error model is worse than 8 ulp | Low | Medium | `Z_RENDER_MAX` margin; PRC-1 measures; lowering `REBASE_SEGMENTS` is a data change |
| A frame is presented between `advance` and the rebase | None by construction | n/a | both run in the same `_tick`, before draw (ADR-0002 same-frame model, ADR-0010) |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/tube-track.md` | `TR-tube-track-017` (Rule 8, F4): precision at large `s`; no rebase; treadmill fallback | Replaces the deferral with a render-origin shift; revision flagged below |
| `design/gdd/tube-track.md` | F2 segment boundary, window of integer segment indices | Rebase in whole segments; `bind_slot` re-binds by index |
| `design/gdd/ball-movement.md` | `s` published as float64, Rule 8; reset glide | `s` is never reduced; `WorldFrame` resets with `run_reset` |
| `design/gdd/camera.md` | F4 position and look-ahead from `s_ball` | Camera core publishes ball-relative offsets; the view adds `render_z(s_ball)` |
| `design/gdd/obstacle-system.md` | footprints in float64, `PackedFloat64Array` | untouched; only the node transform uses `render_z` |
| `design/gdd/scoring-personal-best.md` | score from float64 `s` | untouched |

## Performance Implications
- **CPU**: one comparison per tick; a rebase re-binds about 12 slots and 10 to 17 hazard nodes about every 40 s (microseconds).
- **Memory**: one `RefCounted` and one `Resource`.
- **Load Time**: none.
- **Network**: n/a.

## Migration Plan

Greenfield. Create `WorldFrame` and `WorldFrameConfig` with the first Tube View story; the `bind_slot` and `HazardView.bind` stories use `render_z` from the start. Amend ADR-0002 Decision 6, ADR-0003 (`TubeView.rebase`), ADR-0012 (replace the "shared mapping function" note by `WorldFrame.render_z`), ADR-0014 (placement and `rebase()`); revise Tube Track Rule 8, F4, Open Question 13, AC-15 and `TR-tube-track-017`; add the registry stance and lint rule below.

## Validation Criteria

- [ ] Unit (pure): `render_z` equals `-(s - origin_s)` in float64; `maybe_rebase` keeps `origin_s` a multiple of `L`, leaves `s - origin_s` in `[0, L)`, returns `true` once per crossing and `false` below the threshold; the boundary case `s - origin_s` one ulp below a multiple of `L`; `on_run_reset` zeroes the origin; `REBASE_Z_EXCEEDS_BUDGET` fires for `REBASE_SEGMENTS` 128 at `L` = 24.
- [ ] Unit (views with fake nodes): after a rebase every `TubeView` slot and `HazardView` node z equals a fresh placement with the new origin; the relative z between any two nodes is unchanged to 1e-9 in float64.
- [ ] Unit (order): the spy test shows `WorldFrame step` right after `TubeTrack.advance` and before `Obstacle.test`; no rebase in Pause, Hit or Resuming.
- [ ] Soak (host, float64): a simulated 3600 s run at `V_MAX` leaves every placed `abs(z)` below `Z_RENDER_MAX`, for nodes ahead of and behind the ball.
- [ ] PRC-1 (device): a frame capture across a rebase at 60 and 120 Hz shows no pop; the 8-ulp model is measured at the **largest placed z just before a rebase** (the worst case, not the average); the shadow-off and physics-interpolation-off settings are asserted.
- [ ] Lint: no `Vector3(` built from `s`, `s_offset` or `snapshot.s` outside `world_frame.gd` in view code (ADVISORY, registered in `tools/ci/lint_rules.json` by ADR-0009).

## Related Decisions
- ADR-0002 (game loop, per-frame order), ADR-0003 (tube slots), ADR-0004 (`WorldGeometry`), ADR-0010 (same-frame guarantee), ADR-0012 (`BallView.tick`), ADR-0014 (hazard node placement)
- `design/gdd/tube-track.md` (Rule 8, F4, Open Question 13), `docs/architecture/architecture-review-2026-10-03-run3.md` (required ADR 1)
