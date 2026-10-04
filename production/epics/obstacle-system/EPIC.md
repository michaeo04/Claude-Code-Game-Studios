# Epic: Obstacle System

> **Layer**: Core
> **GDD**: design/gdd/obstacle-system.md
> **Architecture Module**: Obstacle System
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 17 stories (see table)

## Overview

Obstacle System owns hazard instances (bound per entering segment from compiled immutable `HazardSpec` resources), the analytic swept collision against the ball (`hit_reported`, level-triggered every tick), the content preflight (`ContentPreflight` P1 to P3) and the read accessors `footprint_of`, `spec_of`, `s_offset_of`. No physics node is used; `hazard_bound` and `hazard_released` drive the Hazard View (Presentation).

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0002: Game loop, Composition Root and tick order | This ADR makes one scene-root node, `GameRoot`, the Composition Root and the **only** node that runs a per-frame `_process`; it calls every system in one fixed order, builds them in one fixed order, and registers the... | Accepted | LOW |
| ADR-0008: Hazard, collision and content format | This ADR fixes them. **Authored** content is a typed Resource tree (`ChunkLibrary` > `ChunkDef` > `HazardPlacement` > `HazardPiece`, `.tres`, edited in the Godot editor). | Accepted | MEDIUM |
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |
| ADR-0014: Hazard render route and view node tree | This ADR decides: **one `MeshInstance3D` per hazard** (not per piece), taken from a pool built once at map load; the pieces of one hazard are merged into **one `ArrayMesh` per `HazardSpec`**, built once by a pure `Haz... | Accepted | HIGH |

**Engine risk of the epic: HIGH** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

24 requirements registered for this system: 18 covered by an ADR, 1 partial, 0 gap, 5 GDD-owned (specified fully by the GDD, no ADR needed).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-obstacle-system-001 | Logic is split into static pure `ObstacleMath` (F1 expansion, F2 swept overlap + `arc_overlap`, F3 gap sweep-line, F4 `hidden()`, F5 spacing), `RefCounted` `ObstacleCore` and a data-driven `ObstacleConfig` Resource with `valida... | GDD-owned |
| TR-obstacle-system-002 | A hazard is `{hazard_id:int>=0, footprint_pieces:[(theta_min,theta_max,s_start,s_end)], home_segment}`. Pieces of one hazard share one id. Raw `s`-range of every piece lies inside `[i*L,(i+1)*L)`. No height dimension. | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-003 | The hit test is analytic (no `CollisionObject3D`/`Area3D`/`PhysicsServer3D`). It is a swept AABB: `s_hit = s_prev<=s_eff_end and s>=s_eff_start`, and `theta_hit = arc_overlap(...)` using a single `fposmod`. Bounds are expanded... | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-004 | The test runs exactly once per published `(theta_prev,theta,s_prev,s)` pair, in the same tick domain as Ball Movement's publish. A driver node owns this guarantee. A render-frame-only callback is forbidden because of physics ca... | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-005 | Reporting is level-triggered. One `hit_reported(hazard_id:int, run_id:int)` is sent per overlapped hazard per tick, in every phase, with no phase awareness (a no-op frame degenerates to a point-in-footprint test). | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-006 | Lifecycle follows Tube Track's signals. `segment_entered_window(i)` calls the provider once and spawns hazards. `segment_left_window(i)` releases them. `window_primed(first,last)` releases everything, then populates `[first,las... | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-007 | Obstacle System emits `hazard_bound(hazard_id, footprint_pieces)` on spawn and `hazard_released(hazard_id, released_by_reset: bool)` on release. The flag is true for any `window_primed`-caused release (reset, re-prime, to-idle)... | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-008 | The `run_reset(run_id)` handler only stores `run_id`. It must not clear, reseed or reset the id counter, so either order within rank 2 is safe. | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-009 | The content seam is `HazardContentProvider.hazards_for_segment(segment_index:int) -> Array[HazardSpec]`. It is called once per entering segment and never re-queried (a second call gives `DUPLICATE_SEGMENT_QUERY`, binding untouc... | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-010 | If `HazardSpec` is a Resource, each spawned hazard gets an owned deep copy. Plain `duplicate()` is shallow. | ADR-0008 ⚠️ Partial |
| TR-obstacle-system-011 | Footprint bounds are unwrapped reals with `theta_min<=theta_max` and width `<2*PI`. A seam-crossing piece is authored with `theta_max>PI` or `theta_min<-PI`. Bounds are wrapped only when compared to the ball. | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-012 | An offline preflight runs over the whole library, exhaustively (not fail-fast), in deterministic order. It emits stable codes and structured records: `FOOTPRINT_NOT_FINITE`, `FOOTPRINT_INVALID_ORDER`, `FOOTPRINT_TOO_WIDE`, `FOO... | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-013 | The live `hazards_for_segment` call may re-run the checks only as a debug-build assertion. It never rejects mid-run. | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-014 | `hidden(piece)` uses `d_min>VISIBLE_ARC_HALF_WIDTH` with `fposmod` (never `wrapf`) and strict `>`. The hidden ban stays active until OQ2/OQ15 resolve. The exit rule requires a type with `theta_solution` and `d_exit>VISIBLE_ARC_... | GDD-owned |
| TR-obstacle-system-015 | A non-finite published `theta` or `s` is a no-op frame (last good swept endpoint held) with one error logged, and never reaches a comparison. | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-016 | The cross-system invariant `OMEGA_MAX*DT_MAX<PI` is validated at load with `OMEGA_MAX` and `DT_MAX` injected (not owned). | GDD-owned |
| TR-obstacle-system-017 | Per-tick work is bounded by `MAX_PIECES_PER_SEGMENT`=12 (safe range 6-20) times at most `N_MAX`=16 window segments, which is at most 192 pieces tested every tick. The test is its own broad phase. No numeric ms budget is stated. | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-018 | No side effects: the only output is `hit_reported` (plus the two Near-Miss signals). Obstacle System reads only `theta`/`s` and their prev values (never raw world Z). It never calls mutating Ball Movement or Tube Track methods. | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-019 | A lint over ObstacleMath/Core/Config and their transitive dependencies bans `CollisionObject3D`, `CharacterBody3D`, `Area3D`, `RayCast3D`, `ShapeCast3D`, `PhysicsServer`, `Input.`, `Engine.`, `Time.`, `OS.`, `DisplayServer.`, `... | ADR-0009 ✅ Covered |
| TR-obstacle-system-020 | Tests are driven by `make_obstacle_fixture()`, `make_ball_state_stub`, `make_content_provider(table)` and `make_core(cfg, provider, log_sink)`, using scripted ticks only. Exact `==` for ints and codes, 1e-6 for floats. Files ar... | GDD-owned |
| TR-obstacle-system-021 | Determinism: no randomness; two instances fed the same 500-tick script give bit-identical `hit_reported` streams; no static shared state. | ADR-0008, ADR-0002 ✅ Covered |
| TR-obstacle-system-022 | A hazard that hit the ball stays bound through the Hit freeze. Recycling happens only inside `advance()` in Running. | ADR-0002 ✅ Covered |
| TR-obstacle-system-023 | Hazards render at full silhouette and chroma the instant they enter the visible arc (no fade, alpha ramp or LOD pop-in). A developer-only debug overlay drawing every effective footprint is required before chunk authoring. Draw... | ADR-0014 ✅ Covered |
| TR-obstacle-system-024 | No persisted state. Config lives in `ObstacleConfig.tres`: `GAP_MARGIN` 2.5 (2.0-3.5), `T_REVEAL_MIN` 1.5, `HIDDEN_SPAN_MIN_TIME` 1.44, `MAX_PIECES_PER_SEGMENT` 12. | GDD-owned |

**Partial or gap requirements:** stories for these carry the open point named in `docs/architecture/architecture-traceability.md` (Partial Coverage) and are marked Blocked until it is closed.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/obstacle-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Authored content classes, HazardSpec and HazardContentProvider](story-001-authored-content-classes-hazard-spec.md) | Integration | Complete | ADR-0008 |
| 002 | [ObstacleConfig, sweep-invariant validation and test fixtures](story-002-obstacle-config-and-test-fixtures.md) | Logic | Complete | ADR-0009 |
| 003 | [Effective footprint (F1) and swept-rectangle overlap (F2)](story-003-footprint-expansion-and-swept-overlap.md) | Logic | Complete | ADR-0008 |
| 004 | [Safe-gap sweep-line (F3) and hazard overlap validation](story-004-gap-sweep-line-and-hazard-overlap.md) | Logic | Ready | ADR-0008 |
| 005 | [Footprint, grace-zone, piece-count and spacing validators](story-005-footprint-limit-density-validators.md) | Logic | Ready | ADR-0008 |
| 006 | [hidden() classification, hidden-content gate and exit rule (F4)](story-006-hidden-classification-and-exit-rules.md) | Logic | Ready | ADR-0008 |
| 007 | [ObstacleCore hazard bind and window lifecycle](story-007-hazard-bind-and-window-lifecycle.md) | Logic | Ready | ADR-0008 |
| 008 | [Release flag, run_reset handler and read accessors](story-008-release-flag-run-reset-and-accessors.md) | Logic | Ready | ADR-0008, ADR-0014 |
| 009 | [Level-triggered hit test with broad phase](story-009-level-triggered-hit-test.md) | Logic | Ready | ADR-0008, ADR-0002 |
| 010 | [Determinism, no side effects and the engine-coupling lint](story-010-determinism-no-side-effects-and-lint.md) | Logic | Ready | ADR-0009, ADR-0008 |
| 011 | [ContentPreflight P1, exhaustive and deterministic](story-011-content-preflight-p1-exhaustive.md) | Logic | Ready | ADR-0008 |
| 012 | [ContentPreflight P2 pairs, P3 soak and the blocking CI test](story-012-content-preflight-p2-p3-sequencer-soak.md) | Integration | Ready | ADR-0008, ADR-0009 |
| 013 | [GameRoot wiring and real-system integration](story-013-gameroot-wiring-integration.md) | Integration | Ready | ADR-0002, ADR-0008 |
| 014 | [Spike OB-1, worst-case per-tick cost on a mid-tier phone](story-014-ob1-worst-case-cost-spike.md) | Integration | Ready | ADR-0008 |
| 015 | [Developer-only effective-footprint debug overlay](story-015-footprint-debug-overlay.md) | Visual/Feel | Ready | ADR-0014 |
| 016 | [OS-2 corner-cut legibility playtest](story-016-os2-corner-cut-legibility.md) | Visual/Feel | Ready | ADR-0008 |
| 017 | [OS-1 hidden-side fairness playtest (deferred content gate)](story-017-os1-hidden-side-fairness.md) | Visual/Feel | Blocked | ADR-0008 |

## Next Step

Run `/story-readiness production/epics/obstacle-system/story-001-authored-content-classes-hazard-spec.md`, then `/dev-story`.
