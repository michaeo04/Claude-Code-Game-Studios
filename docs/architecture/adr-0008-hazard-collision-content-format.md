# ADR-0008: Hazard, collision and content format

## Status

Proposed

## Date

2026-10-02

## Last Verified

2026-10-02

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

Obstacle System, Pattern & Difficulty and Near-Miss Detection are approved as designs, but four things they all depend on are unspecified: the shape of a hazard (`HazardSpec`), the on-disk format of the chunk library and where the correct dodge angle (`theta_solution`) lives, who owns and runs the offline content preflight (and over what, since chunks are drawn from stochastic bags), and a gap in the sequencer that lets adjacent chunks violate `S_MIN_SPACING` and effective-footprint overlap across a chunk boundary. This ADR fixes them. **Authored** content is a typed Resource tree (`ChunkLibrary` > `ChunkDef` > `HazardPlacement` > `HazardPiece`, `.tres`, edited in the Godot editor). At map load Pattern **compiles** it into immutable runtime `HazardSpec` objects (RefCounted, flat `PackedFloat64Array` footprints). Obstacle builds a **world-space flat footprint array** at bind, so `ObstacleMath` and `NearMissMath` keep their approved world-space formulas. A `ContentPreflight` tool checks every chunk alone and **every ordered pair of adjacent chunks through the real sequencer**, as a blocking GUT test and an editor script. The sequencer's spacing history is generalized to every read (Spikes included) and to both `S_MIN_SPACING` and footprint clearance. Collision stays fully analytic (no engine physics), driven by `GameRoot._tick`, with a per-hazard `s` broad phase. The Godot specialist found no design blocker; two of its findings (the missing broad phase and the scope of the pair check) are wording and claim corrections that are folded in below.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (Resource data format) and analytic collision (no physics engine used) |
| **Knowledge Risk** | MEDIUM: typed arrays of custom Resources and packed float arrays in exported `.tres`, `RandomNumberGenerator` determinism across platforms and the headless tool entry point are not in the engine reference; `docs/engine-reference/godot/modules/physics.md` is verified only to 4.6 and is not needed because no physics node is used |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.5 `duplicate_deep()`, 4.6 Jolt default), `deprecated-apis.md`, `design/gdd/obstacle-system.md`, `pattern-difficulty.md`, `near-miss-detection.md`, `docs/architecture/tr-baseline/gameplay.md` |
| **Post-Cutoff APIs Used** | None. `duplicate_deep()` (4.5) is **not** used; nothing is copied. `@abstract` (4.5) is not used |
| **Verification Required** | **NEEDS VERIFICATION:** (1) that `@export var pieces: Array[HazardPiece]`, `Array[HazardPlacement]`, `Array[ChunkDef]` (typed arrays of custom Resources) round-trip in a `.tres` and in an Android export; (2) that `PackedFloat64Array` (`solution_angles`) and `float` exports keep full float64 precision in text and binary resources (for example `1.0472` and `PI/2`); (3) that an exported `enum` property stores and loads as an int; (4) that a `RandomNumberGenerator` with an explicit `seed` produces the **same sequence** on Android ARM64 and on the desktop (a golden-sequence test on both); (5) how to run `ContentPreflight` headless in CI (`godot --headless --script ...`, the `class_name` cache needs `--import` first) and as an editor-time `EditorScript`; (6) per-tick cost of the 192-piece worst case on a mid-tier phone (spike OB-1); (7) that GDScript `float` arithmetic is 64-bit end to end (it is expected to be; `Vector2`, `Vector3` and `Vector4` are single precision in default builds and are therefore not used for footprints); (8) that the `.tres` text writer and the binary export both keep doubles, and that exported enums keep their explicit integer values; (9) that in the editor a Resource whose script is not `@tool` loads as a placeholder (properties readable, methods not callable), so the `EditorScript` reads the authored classes as data only |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (tick order: `Obstacle.test` after `TubeTrack.advance`, no driver node, immediate connections), ADR-0003 (hazard draw-call allocation), ADR-0004 (`MapDefinition.chunk_library`, `Pattern.apply_map`) |
| **Enables** | ADR-0009 (the preflight and golden-sequence tests are GUT tests), the Obstacle, Pattern and Near-Miss epics |
| **Blocks** | Obstacle System epic, Pattern & Difficulty epic; chunk authoring |
| **Ordering Note** | ADR-0004's placeholder type of `MapDefinition.chunk_library` becomes `ChunkLibrary` here; the Pattern GDD CR9 and F2c and the Obstacle GDD F5 wording need a revision (a design review) before the Pattern epic starts |

## Context

### Problem Statement

The Obstacle GDD fixes the hit test and the preflight validators but leaves `HazardSpec` undefined; the Pattern GDD fixes the logical chunk record but not its format or the field that selects a library; neither names an owner or an enumeration for the offline preflight, which cannot "call every segment index" because chunks are drawn from seeded bags with padding; and Pattern's cross-chunk spacing covers only opposing pairs, so adjacent non-opposing chunks (for example `W4` at `s_start` 11.0 followed by `W2` at 17.0, 6.0 u against `S_MIN_SPACING` 6.25 u, or a Spike at 1.0 u after `W4`) can violate the spacing and overlap rules at a boundary that no check ever sees. The architecture also forbids copying hazard Resources (`duplicate_deep()` is a HIGH-risk API).

### Constraints

- No `CollisionObject3D`, `Area3D`, `RayCast3D` or `PhysicsServer3D`; analytic swept test in float64 (Obstacle CR2).
- One `_process`, fixed tick order (ADR-0002); level-triggered `hit_reported`, no phase awareness.
- Per tick at most 192 pieces tested (12 pieces per segment, 16 segments in the window), and Near-Miss reuses `ObstacleMath` on the same pieces.
- Content is data, not code: authored in the editor, no hardcoded gameplay values (coding standards).
- Pattern never redraws, reorders or rejects a chunk at run time; it only pads.
- Determinism: the same `run_id` and call script give bit-identical output.

### Requirements

- One immutable runtime hazard type shared by Obstacle, Near-Miss and Juice, with no per-spawn copying of authored Resources.
- A library that a designer can edit in the inspector and that is proven safe **in every legal sequence**, not only per chunk.
- A single place that decides what is checked at load and what is checked in CI.
- Every approved formula stays as written (world-space, float64).

## Decision

### 1. Authored content: a typed Resource tree

```text
ChunkLibrary (Resource)   assets/data/chunks/chunk_library_01.tres, referenced by MapDefinition.chunk_library
  chunks: Array[ChunkDef]            each ChunkDef is its own external file assets/data/chunks/<chunk_id>.tres (small diffs, easy merges)
ChunkDef (Resource)
  chunk_id: StringName, tier: Tier (INTRO | RAMP | FULL), segment_count: int (1..3)
  placements: Array[HazardPlacement]
HazardPlacement (Resource)
  hazard_type: HazardType (WALL | SPIKE | DOUBLE_GATE | NEAR_RING)
  local_segment_index: int            0 .. segment_count-1 (the segment that owns the hazard)
  pieces: Array[HazardPiece]
  solution_angles: PackedFloat64Array  the correct dodge angle(s); empty for SPIKE
HazardPiece (Resource)
  theta_min, theta_max: float          unwrapped; a seam-crossing piece has theta_max > PI or theta_min < -PI
  s_start, s_end: float                chunk-local, inside [k*L, (k+1)*L) for its segment k
```

- `solution_angles` is **stored explicitly** (one for Wall and Near-Ring, two for Double Gate, none for Spike). The preflight checks that every angle lies inside a real safe gap of its footprint, so the stored value cannot silently disagree with the geometry.
- Authored Resources are **never mutated at run time** and never copied. They are read once, at compile (below).
- `Tier` and `HazardType` are enums with **explicit integer values** (`WALL = 0`, `SPIKE = 1`, ...); a reordered enum would otherwise silently change every stored `.tres`. The authored classes are **data only** (no methods that tooling must call); they are not `@tool`.
- Tier pools are supersets (RAMP includes INTRO, FULL includes all), as in the Pattern GDD; a chunk's `tier` is the first tier that may draw it.

### 2. Runtime: compiled, immutable `HazardSpec`

`Pattern.apply_map(map)` (ADR-0004 Phase B3) calls `ChunkLibraryCompiler.compile(map.chunk_library, ...)`, which validates the **structural** checks (below) and builds a `CompiledLibrary` (RefCounted): per-tier pools of `CompiledChunk` and, per placement, one immutable runtime object:

```gdscript
class_name HazardSpec
extends RefCounted
# built once at compile, no setters, never mutated

var hazard_type: int                    # HazardType
var local_segment_index: int            # k
var pieces: PackedFloat64Array          # 4 per piece: theta_min, theta_max, s_start, s_end (chunk-local)
var solution_angles: PackedFloat64Array # empty for SPIKE
```

`PatternCore` is the `HazardContentProvider`: `hazards_for_segment(segment_index: int) -> Array[HazardSpec]` returns the **shared** specs of the chunk placed at that segment (no copy, no allocation of pieces). The `HazardContentProvider` base class is a plain `RefCounted` returning an empty array (no `@abstract`), faked in tests.

**Structural checks at compile (cheap, O(pieces), always run):** finite values, `theta_min <= theta_max` with width `< 2*PI`, `s_start <= s_end` inside the owning segment, `segment_count` in 1 to 3, `local_segment_index` in range, at most `MAX_PIECES_PER_SEGMENT` pieces per segment, a non-empty pool per tier and at least `GRACE_POOL_MIN_SIZE` grace-compliant INTRO chunks. A failure returns the code set and `Pattern.apply_map` returns false (ADR-0004: `MAP_APPLY_FAILED`). In **debug builds** the full preflight (below) also runs at map load as an assertion; in release builds it never runs on the device.

### 3. Obstacle: world-space flat footprint at bind

When a segment enters the window, `ObstacleCore` calls `hazards_for_segment(i)` once and, per returned spec, assigns `hazard_id` and builds the hazard's **world-space footprint** in its own record:

```text
s_offset  = (i - spec.local_segment_index) * L          (the chunk base translated into world s)
footprint = PackedFloat64Array, 4 values per piece:  theta_min, theta_max, s_start + s_offset, s_end + s_offset
record    = { hazard_id, home_segment = i, hazard_type, footprint, s_lo, s_hi }     s_lo = min piece s_start, s_hi = max piece s_end (world)
```

- `ObstacleMath` and `NearMissMath` keep their approved formulas and operate on the world-space tuples in the flat array (F1 expansion, F2 swept overlap and `arc_overlap`, F3 gap sweep, F4 `hidden()`, F5 spacing, Near-Miss reuse). Nothing is re-derived; there is no offset arithmetic outside the bind.
- `hazard_bound(hazard_id: int, footprint: PackedFloat64Array)` carries the world-space array (the GDD's `footprint_pieces`, now typed). `hazard_released(hazard_id: int, released_by_reset: bool)` is unchanged. Juice reads `ObstacleCore.footprint_of(hazard_id)` and `hazard_type_of(hazard_id)` for the killer-isolate effect.
- **TR-obstacle-system-010 ("each spawned hazard gets an owned deep copy") is superseded:** the spec is shared and immutable, the per-hazard state is the record, and no `duplicate()` or `duplicate_deep()` is called anywhere.
- The `hazard_id` counter, `window_primed` release, `segment_left_window` recycle and `run_reset` handler (stores `run_id` only) are as approved (ADR-0002 ranks).

### 4. Collision: analytic, driven by `GameRoot._tick`

**Broad phase:** the per-hazard `s_lo` and `s_hi` (expanded by `D/2`) are compared with the tick's swept `s` range first, and a hazard whose range does not intersect is skipped without touching its pieces. Only the one or two segments around the ball (about 24 pieces) pass this test at any time, so the 192-piece figure is a bound on records held, not on pieces tested. Near-Miss reuses the same early-out. The hit test stays the approved swept AABB (`s_hit` and `theta_hit` with one `fposmod`), expanded by `BALL_HALF_ANGLE` and `D/2`. It runs **once per tick in `GameRoot._tick`** right after `TubeTrack.advance` (ADR-0002 step order: `Ball.step`, `TubeTrack.advance`, `Obstacle.test`, `NearMiss.step`), on the published `(theta_prev, theta, s_prev, s)` of that tick, so no driver node, `process_priority` or physics catch-up exists. Compile and preflight run on the main thread; if the library is ever loaded with `load_threaded_request`, compile only after the load completes (this settles TR-obstacle-system-004 and the Obstacle OQ16). `hit_reported(hazard_id, run_id)` is emitted by `ObstacleCore` as a signal and connected to Run State's handler in the `_wire()` rows, immediately (never deferred). `Obstacle.test` runs before `NearMiss.step` in the same tick, so a `hit_reported` is always applied before Near-Miss's exit-edge check (resolves gap 5). **Budget:** `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case on a mid-tier phone (spike OB-1, measured in the first-playable profiling pass; advisory until then).

### 5. Content preflight: owner, entry points, enumeration

`ContentPreflight` is a `RefCounted` module in `src/` (pure; it composes `ObstacleMath`, `PatternMath` and `NearMissMath` validators and the **real** `PatternCore` sequencer, so it can never disagree with the game). It returns **every** violation (exhaustive, deterministic order) as stable codes with structured records, never a partial application.

Enumeration:

1. **P1, each chunk alone:** per piece, per hazard and per chunk: `FOOTPRINT_NOT_FINITE`, `FOOTPRINT_INVALID_ORDER`, `FOOTPRINT_TOO_WIDE`, `FOOTPRINT_EFF_TOO_WIDE`, `HOME_SEGMENT_MISMATCH`, `NO_SAFE_GAP`, `TOO_MANY_PIECES`, `TOO_DENSE`, `HAZARD_OVERLAP`, `HIDDEN_CONTENT_FORBIDDEN`, `EXIT_BEYOND_VISIBLE_ARC`, `HIDDEN_UNFAIR`, `SWEEP_INVARIANT_VIOLATED`, `NEAR_ZONE_OVERLAP`, `DODGE_RECOVERY_VIOLATION` (within the chunk), `GRACE_ZONE_VIOLATION`, plus a new `SOLUTION_NOT_IN_GAP` (a stored `solution_angles` entry outside every safe gap).
2. **P2, every ordered pair of adjacent chunks (a boundary-geometry check, not the proof for chains):** for each ordered pair `(A, B)`, `A != B` (and `A == B` only when a tier pool has one chunk), run `A`, then the padding segments the sequencer **actually inserts** for that pair (section 6), then `B`, through the same validators over the combined window with the correct `s` offsets: `NO_SAFE_GAP`, `HAZARD_OVERLAP`, `TOO_DENSE` and `NEAR_ZONE_OVERLAP` across the boundary. The pair count is at most `N^2` for `N` chunks (a few hundred), so the cost is trivial. A violation names both chunks and the padding used. P2 runs each pair with an empty older history; the sequencer pads a chunk against **all** older history (for example an opposing read 26.6 u back), so the guarantee for any chain comes from the sequencer's rule (section 6, correct by construction because chunks are segment-aligned and pieces stay inside their segment) and **P3 is the proof for chains**, not P2. P2 additionally runs each pair behind a synthetic worst-case predecessor (the library's chunk with the latest-ending opposing read) so short chunks are exercised against older history.
3. **P3, sequence soak (backstop for chains longer than a pair):** a fixed, hardcoded list of 500 seeds, 200 segments each, run through the real sequencer and the validators. It proves the pair argument holds in practice; a failure means a boundary interaction exceeded what the padding assumed and is reported as `CHAIN_VIOLATION` with the seed and segment.

Entry points:

- **Blocking CI test:** `tests/unit/pattern_difficulty/pattern_difficulty_content_preflight_test.gd` (GUT) runs P1 to P3 over the shipped `chunk_library_01.tres`; it must pass for any merge that touches `assets/data/chunks/` or the validators.
- **Editor script:** an `EditorScript` (and the same `ContentPreflight` called from the CI runner) prints the records so a designer can check a chunk while authoring, before chunk authoring starts (Obstacle requires a debug overlay of effective footprints first; that overlay is a separate debug view).
- The content test loads the real `.tres` files from disk, so it is classified as **Integration or Content evidence** (the testing standards forbid file I/O in unit tests); the validator unit tests build fixtures with `.new()`. It asserts exact values such as `PI/2` after the load, and the golden-sequence test reloads the library from disk, not an in-memory copy.
- **Not on the device:** release builds run only the structural compile checks. The debug-build assertion at map load runs the full preflight as a development aid.

This resolves Pattern OQ8 (owner and entry point of the preflight) and the tools-programmer task is this module.

### 6. Sequencer spacing, generalized (fixes the cross-chunk hole)

Pattern's read history changes from "non-Spike reads with their solution set" to **every read, Spikes included**:

```text
history entry:   (s_start, s_end, solution_angles)         s_start = earliest piece s of the read; solution_angles empty for SPIKE
pair (p, q):     p = a history entry, q = a read of the chunk about to be drawn
  opposing(p,q)  = any angle pair with abs(delta_theta) > ANGULAR_REVERSAL_THRESHOLD   (false if either set is empty)
  req_spacing    = max(S_MIN_SPACING, DODGE_RECOVERY_S if opposing(p,q) else 0)
  req_clear      = D                                      effective footprints do not overlap in s: q.s_start - p.s_end >= D
  shortfall(p,q) = max(0, req_spacing - (q.s_start - p.s_start), req_clear - (q.s_start - p.s_end))
padding_segments = ceil(max over all (p,q) of shortfall / L)    empty segments inserted before the chunk
history pruned to s_start >= frontier - max(DODGE_RECOVERY_S, S_MIN_SPACING)
```

- `opposing` uses the **wrapped** angular difference (at most `PI`), never a raw `abs`, so seam-crossing angles compare correctly. The `ceil` uses a documented epsilon constant (`PADDING_EPSILON`) so an exact multiple of `L` plus float noise does not add a spurious segment. The pruning horizon is safe only if `DODGE_RECOVERY_S - L >= D` (14.6 u against `D` 0.8 u at the defaults), which `PatternConfig.validated` asserts. `req_clear` ignores `theta`, so it is conservative: a Double Gate or Wall at a different angle may be padded needlessly; padding frequency is measured in Pattern OQ11.
- It never redraws, reorders or rejects a chunk; it only pads, exactly as the approved mechanism. The worst case stays `ceil(1.4 * 3.0)` = 5 segments at the shipped defaults; because `DODGE_RECOVERY_S` (26.6 u) is far above `S_MIN_SPACING` (6.25 u) the generalization adds padding only where a non-opposing pair is closer than 6.25 u or overlaps.
- Cost: occasionally one extra empty segment (12 u, 0.48 s at 25 u/s). The pacing effect is measured in the first playable (Pattern OQ11, padding frequency).
- Within-chunk spacing is still enforced by the P1 preflight; the sequencer now makes the cross-chunk case **true by construction** for any legal library, and P2 proves it per pair.
- **GDD revision required (design review):** Pattern CR9 and F2c, the Pattern acceptance criteria that mention the opposing-only history, and Obstacle F5's wording ("checked across the whole preflighted library") change to this rule.

### 7. Library selection and ownership

`MapDefinition.chunk_library: ChunkLibrary` (ADR-0004; the placeholder type is replaced). The MVP ships one library for one map. A future Maps & Levels system picks a library per map by the same field.

### 8. Determinism and the PRNG

`PatternCore` uses a `RandomNumberGenerator` instance with an explicit `seed` set from `run_id` before the first draw, never `randomize()`, and its own Fisher-Yates (the global `Array.shuffle()` is forbidden). Only the integer path is used for layout decisions (`randi_range`, never `randf`, whose float conversion is more fragile); only `seed` is set, never `state`. The engine does not promise stable sequences across engine versions, so the golden test is re-run on every engine upgrade. A **golden-sequence** unit test fixes the expected chunk order for a hardcoded seed list; the same list runs once on an Android device build (verification item 4). `hazards_for_segment` is called once per index in increasing order, as before.

### Architecture Diagram

```text
authored (editor)                 compile (map load, ADR-0004 B3)            runtime
ChunkLibrary.tres  ──────────►  ChunkLibraryCompiler.compile ──────►  CompiledLibrary { tier pools of CompiledChunk }
 ChunkDef                              structural checks only                      │  shared, immutable HazardSpec
  HazardPlacement                      (debug: full preflight)                     v
   HazardPiece                                                          PatternCore (HazardContentProvider)
                                                                          hazards_for_segment(i) -> Array[HazardSpec]
                                                                                   │
                                                                                   v
  ObstacleCore: bind -> record { hazard_id, home_segment, type, world-space PackedFloat64Array }
        │ hazard_bound(id, footprint)            │ test once per tick (GameRoot._tick, after TubeTrack.advance)
        v                                         v
   NearMissCore, Juice (read-only)          hit_reported(hazard_id, run_id) ──► RunState (immediate)

offline:  ContentPreflight (P1 each chunk, P2 every ordered pair via the real sequencer, P3 500-seed soak)
          └─ GUT test (blocks CI) + EditorScript
```

### Key Interfaces

```gdscript
# hazard_content_provider.gd
class_name HazardContentProvider
extends RefCounted

func hazards_for_segment(_segment_index: int) -> Array[HazardSpec]: return []

# chunk_library_compiler.gd
class_name ChunkLibraryCompiler
extends RefCounted

static func compile(library: ChunkLibrary, config: PatternConfig, segment_length: float, log_sink: Callable) -> CompiledLibrary   # null on a structural failure

# content_preflight.gd
class_name ContentPreflight
extends RefCounted

func run(library: ChunkLibrary, cfg: ContentPreflightConfig) -> Array[Dictionary]   # every violation: {code, chunk_id, other_chunk_id, detail}, deterministic order

# obstacle_core.gd (additions)
signal hazard_bound(hazard_id: int, footprint: PackedFloat64Array)
signal hazard_released(hazard_id: int, released_by_reset: bool)
signal hit_reported(hazard_id: int, run_id: int)
func footprint_of(hazard_id: int) -> PackedFloat64Array
func hazard_type_of(hazard_id: int) -> int
```

## Alternatives Considered

### Alternative 1: Chunk library as JSON parsed into RefCounted objects

- **Pros**: diff-friendly text, no `.tres` typed-array questions.
- **Cons**: no inspector or range editing for designers, a hand-written parser and type checker, and a second place where precision and types can drift.
- **Rejection Reason**: authored Resources give typed fields and editor tooling for free; the compile step already produces the runtime form, so the runtime does not depend on the file format.

### Alternative 2: GDScript constant tables

- **Pros**: no resource loading.
- **Cons**: content mixed with code, no editor, and a recompile for every tuning change; against the data-driven rule.
- **Rejection Reason**: coding standards require external data.

### Alternative 3: Per-spawn translated `HazardSpec` Resources (or `duplicate_deep()` as in TR-obstacle-system-010)

- **Pros**: smallest change to the GDD wording.
- **Cons**: many small allocations per segment, slower property access in a 192-piece loop, and `duplicate_deep()` is a HIGH-risk API on 4.7.
- **Rejection Reason**: the shared immutable spec plus a flat world-space array has neither cost.

### Alternative 4: Content guard bands (every chunk keeps head and tail clear zones) or preflight-only rejection of bad pairs

- **Pros**: no change to the sequencer.
- **Cons**: constrains chunk design (the fixture's `W4` at `s_start` 11.0 would violate) or removes legal chunks from the library by the worst pair.
- **Rejection Reason**: the generalized padding is provable for any legal library and costs only an occasional empty segment.

### Alternative 5: Engine physics (`Area3D` or `PhysicsServer3D`) for the hit test

- **Rejection Reason**: already rejected by the Obstacle GDD (CR2): the analytic swept test is exact, deterministic and independent of physics sub-steps.

## Consequences

### Positive

- One immutable runtime hazard, no copies, no `duplicate_deep()`, and every approved formula stays as written.
- The library is proven safe for every ordered adjacent pair and by a seeded soak, not only per chunk, and the proof uses the real sequencer.
- The preflight has an owner, two entry points and a stated enumeration; the device only runs cheap structural checks.
- Hit test, Near-Miss and Run State have a pinned in-tick order with no driver node.

### Negative

- New types: `ChunkLibrary`, `ChunkDef`, `HazardPlacement`, `HazardPiece`, `CompiledLibrary`, `ChunkLibraryCompiler`, `ContentPreflight`, a runtime `HazardSpec`, and a typed `hazard_bound` payload.
- The Pattern GDD (CR9, F2c, its acceptance criteria) and the Obstacle GDD F5 need a revision, and the Near-Miss and Juice GDDs need the typed `footprint` payload noted. `architecture.md` Phase 4 (HazardSpec was an immutable Resource) changes to a compiled RefCounted.
- Slightly more empty padding segments in play; to be measured.
- A debug-build full preflight at map load adds development boot time.

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Typed arrays of custom Resources do not round-trip in an export | Medium | High (no content) | verification item 1, an export smoke test that loads `chunk_library_01.tres` and compiles it |
| `RandomNumberGenerator` differs across platforms | Low | Medium (a device sequence differs from tests) | golden sequence on device; Pattern keeps its own Fisher-Yates |
| Chains longer than a pair break a rule | Low | Medium | P3 soak; `PIECE_SPAN_TOO_LONG` in P1 |
| Generalized padding makes the game feel sparse | Medium | Medium | padding frequency measured at first playable (Pattern OQ11); `S_MIN_SPACING` is the only knob |
| 192-piece test exceeds its budget on a slow phone | Low | Medium | OB-1; the test is already its own broad phase; flat arrays keep the loop cheap |
| Stored `solution_angles` drift from the geometry | Medium | Medium | `SOLUTION_NOT_IN_GAP` in P1; the blocking CI test |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| obstacle-system.md | CR1, CR7: hazard record and the `HazardContentProvider` seam; `HazardSpec` undefined | Decisions 1 to 3: authored tree, compiled immutable `HazardSpec`, record with world-space footprint |
| obstacle-system.md | CR2, F1, F2: analytic swept hit test, once per tick | Decision 4 (in `GameRoot._tick`, no physics node, no driver) |
| obstacle-system.md | Edge Cases and F3 to F5: offline preflight over the whole library | Decision 5 (P1 to P3, owner, entry points); the cross-chunk hole in Decision 6 |
| obstacle-system.md | CR5, CR9: lifecycle and no side effects | Decision 3 (signals unchanged, typed payload) |
| pattern-difficulty.md | CR1, CR4: chunk record `{chunk_id, tier, segment_count, placements}` | Decision 1 (the typed Resource tree) |
| pattern-difficulty.md | CR9, F2c: cross-chunk padding | Decision 6 (generalized history, formula) |
| pattern-difficulty.md | OQ4: the `MapConfig` field that selects the library | Decision 7 and ADR-0004 |
| pattern-difficulty.md | OQ8: owner of the preflight | Decision 5 |
| pattern-difficulty.md | CR3, CR11: seeded PRNG, determinism | Decision 8 |
| near-miss-detection.md | CR3, F1-NM: reuse `ObstacleMath`; `hazard_bound` payload; `NEAR_ZONE_OVERLAP` preflight | Decisions 3 and 5 |
| juice-feedback.md | Killer-isolate effect reads the bound footprint | Decision 3 (`footprint_of`, `hazard_type_of`) |
| tube-track.md | `L`, segment window (`segment_entered_window`, `window_primed`) | Decision 3 (`s_offset = (i - k) * L`) |

## Performance Implications

- **CPU**: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at 192 pieces (to be measured, OB-1); `hazards_for_segment` is a lookup of shared specs; the flat footprint is built once per spawn (a few dozen floats); `ContentPreflight` runs only in CI, the editor and debug builds.
- **Memory**: the compiled library is resident for the session (tens of chunks, a few KB); each live hazard record holds one small `PackedFloat64Array`; at most 16 window segments are live.
- **Load Time**: the compile is O(pieces) at map load, within the ADR-0004 boot budget.
- **Network**: none.

## Migration Plan

New code. After this ADR is Accepted: revise Pattern CR9, F2c and its acceptance criteria and Obstacle F5 in a design review; note the typed `hazard_bound` payload in the Obstacle, Near-Miss and Juice GDDs; update `architecture.md` Phase 4 (compiled RefCounted `HazardSpec`) and mark TR-obstacle-system-010 superseded; replace the placeholder type in `MapDefinition`; add the `ContentPreflight` task to the production backlog (Pattern OQ8).

## Validation Criteria

- [ ] Unit tests: compile rejects each structural defect with its code; a valid library compiles; the compiled specs are never mutated (a test that freezes and compares); `hazards_for_segment` returns shared instances.
- [ ] Unit tests: the world-space footprint equals `piece + (i - k) * L`; `ObstacleMath` results are unchanged from the approved fixtures.
- [ ] `ContentPreflight` P1 to P3 pass on `chunk_library_01.tres` (blocking in CI), and the micro-fixtures `TWOHOP`, `TOO_CLOSE`, `TWIN_WALL`, `CLUSTERED` plus new `SPIKE_AFTER_WALL` and `LONG_OVERLAP` fixtures produce their expected codes.
- [ ] Sequencer unit tests for the generalized history: a non-opposing pair under 6.25 u gets padding; a Spike after a Wall gets padding; the worst case stays 5 segments; no chunk is ever redrawn.
- [ ] Golden-sequence test for a hardcoded seed list, repeated once on an Android device build.
- [ ] Export smoke test: the library loads from the exported package and compiles.
- [ ] OB-1: `Obstacle.test` plus `NearMiss.step` within 0.4 ms at the 192-piece worst case on a mid-tier phone.
- [ ] A lint: no `CollisionObject3D`, `Area3D`, `RayCast3D`, `PhysicsServer`, `duplicate_deep`, `Vector4` in hazard code; no `randomize()`, `randf` or global `shuffle()` in Pattern; no write to a loaded (cached) Resource anywhere in the content path.

## Related Decisions

- ADR-0002 Game loop and Composition Root; ADR-0003 Renderer and tube render route (hazard draw calls); ADR-0004 Map Loader and MapConfig (`chunk_library`, `Pattern.apply_map`); ADR-0009 (to be written: test framework and CI, hosts the preflight test)
- `design/gdd/obstacle-system.md`, `pattern-difficulty.md`, `near-miss-detection.md`, `juice-feedback.md`, `tube-track.md`
- `docs/architecture/tr-baseline/gameplay.md` (TR-obstacle-system-002/003/004/009/010/012, TR-pattern-difficulty-002/011/021)
