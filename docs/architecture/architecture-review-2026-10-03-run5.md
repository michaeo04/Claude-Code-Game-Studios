# Architecture Review Report (run 5)

Date: 2026-10-03 (fifth run, fresh session)
Mode: full (`/architecture-review`), delta review
Engine: Godot 4.7.2, GDScript, Android only (ADR-0001)
GDDs reviewed: 16 system GDDs through the 348-requirement baseline. Changed since run 4: `ball-movement.md`, `camera.md`, `tube-track.md` (notes only, commit 226c97c).
ADRs reviewed: 14 (ADR-0001 Accepted; ADR-0002 to ADR-0014 Proposed)
Previous runs: `architecture-review-2026-10-03.md`, `-rerun.md`, `-run3.md`, `-run4.md`

**Method note.** Scope is commit 226c97c, the amendment pass for run 4 (C-18 to C-20, E-1 to E-10). The full diff (13 files) was read, then checked against ADR-0002, 0003, 0004, 0009, 0010, 0012, 0013, 0014, the Run State, Tube Track, Camera and Ball Movement GDDs, `architecture.md`, `tr-registry.yaml`, `tr-baseline/`, `docs/registry/architecture.yaml`, `design/registry/entities.yaml` and `tests/unit/tube_track/test-plan.md`, by grep for every renamed or retired symbol (`idle_step`, `to_world`, `local_point`, `S_PRECISION_LIMIT`, `WorldFrame`, `accessibility-requirements`). The engine-specialist second opinion was **not** re-run: run 4 ran it, and this pass changed wording only (no new engine claim).

---

## Traceability Summary

| Status | Run 4 | This run |
|---|---|---|
| ✅ Covered | 179 | **179** |
| ⚠️ Partial | 11 | **11** |
| ❌ Gap | 1 | **1** (audio, deferrable) |
| ➖ GDD-owned (not counted) | 157 | 157 |

Architecture-relevant: 191. Total: 348. No new TR-IDs; the registry is untouched. TR-tube-track-002 needs a text revision once C-21 is decided (the registry still describes `P (rename to_world suggested)`).

---

## Verified closed (no finding)

- **C-18.** ADR-0013 section "The GDD frame `P`" splits `P` into `TubeMath.local_point(theta, h)` (x, y) and `WorldFrame.render_z(s)` (z). The camera worked case is correct: eye z = `render_z(s_ball) + CAMERA_BACK_DISTANCE` equals `-(s_ball - back - origin_s)`; the look-at z = `render_z(s_ball) - CAMERA_LOOK_AHEAD`. Camera F4 and Tube Track Rule 1 carry the pointer note; ADR-0012 (BallView placement at `h = D/2`) and ADR-0010 (shards at the `BallView` global transform; no rebase runs in Hit; `run_reset` clears the emitter) agree. New unit tests in ADR-0013 cover the fixture table and the camera case.
- **C-19.** ADR-0002 Decision 6 and its spy test now say `idle_step` runs only in Menu (Tube Track Idle), never in Paused, Hit or Resuming. Residual wording: see C-24.
- **C-20.** "future ADR-0013" removed from ADR-0003 and ADR-0014; ADR-0009 gains `forbidden:raw_s_in_vector3` (ADVISORY) and the `physics/common/physics_interpolation` `project_setting` row.
- **ADR-0013 follow-through.** `WorldFrame step` after `TubeTrack.advance` in the per-frame order, the diagram line and the spy test (ADR-0002); `WorldGeometry` and `WorldFrame` in the construction order; `TubeView.rebase()` (ADR-0003); placement through `render_z` and `HazardView.rebase()` (ADR-0014); `WorldFrame.reset()` before `to_idle()` with a wiring test (E-2).
- **E-1 to E-10.** E-1 (no running-state world-space effect in the MVP; future ones decide explicitly), E-3 (the 2^33 arithmetic), E-4 (`fog_light_color` via `WorldChroma`), E-5 (`ARRAY_NORMAL` in R-1), E-6 (boot guard wording), E-7 (Vulkan pin on Windows), E-8 (baker plus warm-up measured), E-9 (`fixed_fps`), E-10 (engine reference rows) are applied as worded in the run 4 table.
- **Rank order.** `run_reset`: `WorldFrame` (rank 1, tie with Pattern broken by row order) runs before the Tube Track adapter and Obstacle (rank 2). No dependency between Pattern and `WorldFrame`. No dependency cycle (ADR-0013 depends on 0002, 0003, 0004, 0012, 0014; none depends on it).
- **Boot budget.** `A` (`SEGMENTS_AHEAD`) stays in the base `TubeConfig` (ADR-0004 line 81), so validating `(REBASE_SEGMENTS + A + 1) * L <= Z_RENDER_MAX` at composition cannot be broken by a map.

---

## Cross-ADR Conflicts

No blocking conflict and no dependency cycle. Four new findings, all text-level.

### C-21: ADR-0013 vs `architecture.md`, `tr-registry`, `tr-baseline`, Tube Track test plan (`to_world`) - Medium, Integration
- ADR-0013 introduces `TubeMath.local_point` and states "nothing outside `WorldFrame` and `TubeMath` evaluates `-s`", but it never says what happens to `TubeMath.to_world(theta, s, h) -> Vector3`.
- `architecture.md:218` still defines `to_world` as "the ONLY (theta, s, h) to world conversion". `tr-registry.yaml:45` (TR-tube-track-002), `tr-baseline/world-movement.md:8, 35` and `tests/unit/tube_track/test-plan.md:19, 163` still list it.
- Impact: a story built from the registry or the test plan writes `to_world` returning a `Vector3` with raw `-s`. The new lint only inspects view code, so a raw-`s` `Vector3` inside `tube_math.gd` is not caught, and any view that calls `to_world` bypasses `render_z`.
- Resolution: ADR-0013 states that `to_world` is replaced by `local_point` (x, y) and that the logical `P` exists only in tests as a reference function; revise TR-tube-track-002 (`revised: 2026-10-03`), `tr-baseline`, the test plan and `architecture.md` v1.1.

### C-22: stale registry entries vs ADR-0013 - Low/Medium
- `design/registry/entities.yaml:124` (the `P` entity): "There is no render-origin rebase in the MVP; z = -s grows with the run and is only precise below S_PRECISION_LIMIT (16384, F4)… Only Tube Track converts to world space". This is the source `/consistency-check` reads, and it contradicts ADR-0013. Lines 184 and 699 cite 16384 as a live Ball Movement horizon and are acceptable as arithmetic, but should say "the former".
- `docs/registry/architecture.yaml:1773` (forbidden pattern): "Running-state `GPUParticles3D` use `local_coords = true`". ADR-0013 (after E-1) says no such effect exists in the MVP and a future effect decides explicitly (`local_coords = true` parented to the ball, or `local_coords = false` with a `restart()` on the rebase tick).
- Resolution: edit both entries.

### C-23: ADR-0013 `WorldFrame.reset()` call by the map loader vs ADR-0004 - Low
- ADR-0013 (line 145 and Decision 2) says the map loader calls `WorldFrame.reset()` before `load_map`. ADR-0004 has no `WorldFrame` and its `MapLoaderSeams` has no such seam.
- The call is also redundant: `load_map` is accepted only from Uninitialized (boot or Retry before any run), where `origin_s` is already 0, and `unload_map` is unused in the MVP.
- Resolution: drop the map-loader clause from ADR-0013 and keep the reset at the Tube Track adapter's `to_idle()` call site (the case that matters); or add the seam to ADR-0004. Dropping is simpler.

### C-24: residual wording - Low
- ADR-0003 line 98: `idle_step` "called by GameRoot in Idle"; say "in Menu (Tube Track Idle)" so it uses the Run State phase name (C-19 pattern).
- `ball-movement.md:191` (edge case) still reads "If `s` approaches Tube Track's `S_PRECISION_LIMIT`" as if the constant were live; `tools/reference-sim/ball_movement.js:227` labels a check with it (harmless).
- `run-state-restart.md` `run_reset` rank table (line 73) lists no `WorldFrame` row. AC-30 runs against the real `_wire()` table, so an extra rank-1 row is tolerated, but the GDD should name it so the table and ADR-0002 Decision 7 agree.

---

## ADR Dependency Order

Unchanged from run 4 (14 ADRs, no cycle, ADR-0013 last). Every ADR from 0002 to 0013 still depends on a Proposed ADR. P-1 stays a project-owner decision, not a technical-director ratification (`production/session-logs/agent-audit.log` shows no `technical-director` invocation on 2026-10-03).

---

## Engine Compatibility

- 14 / 14 ADRs carry an Engine Compatibility section; all state Godot 4.7.2. No deprecated API in any ADR.
- Specialist consultation: **not run** this pass (wording-only amendment). Run 4 findings E-1 to E-10 are all applied.
- Carried spikes, unchanged: PRC-1, R-1, HV-1, UI-1, UI-A1, PT-1 to PT-4, T-1. `modules/` still stops at 4.6.

---

## GDD Revision Flags (Architecture → Design Feedback)

Systems-index statuses unchanged (standing user decision, 2026-10-03). Flags from run 4 for `tube-track.md` Rule 1, `camera.md` F4 and `ball-movement.md` lines 128, 165, 259, 263 are **closed** by 226c97c (notes added, no formula change). Open:

| GDD | Assumption | Reality | Action |
|---|---|---|---|
| ball-movement.md:191 | `S_PRECISION_LIMIT` is Tube Track's live constant | retired by ADR-0013 | reword (C-24) |
| run-state-restart.md rank table | `run_reset` order lists no `WorldFrame` | ADR-0002 Decision 7 adds it at rank 1 | add a row note (C-24) |
| systems-index.md:207 | `S_PRECISION_LIMIT` timing risk for Tube Track and Run State to resolve | retired | housekeeping |
| design/registry/entities.yaml:124 | no rebase in the MVP; `P` is the only world conversion | ADR-0013 | edit (C-22) |

---

## Architecture Document Coverage

`architecture.md` v1.0 still lists ADR-0013 as unwritten (lines 302, 323), defines `to_world` (line 218, C-21) and has no module rows for ADR-0010 to ADR-0014 (`InkCoverCore`, `PresentationMath`, `HazardView`, `BallView`, `WorldChroma`, `UiScaler`, `WorldFrame`), the layer stack or the Phase B step. The v1.1 pass is pending. Playtest Telemetry (MVP, no GDD) is still absent from architecture and every ADR.

---

## Verdict: CONCERNS

C-18 to C-20 are verified closed. No blocking conflict, no cycle, 94% coverage. The verdict stays CONCERNS because ADR-0002 to ADR-0014 are Proposed (no technical-director review yet) and ADR-0014 OQ1 (plinth span) is open.

### Blocking before coding starts (`src/`)
1. TD review and Acceptance of ADR-0002 to ADR-0014.
2. **C-21** settled before ADR-0013 is Accepted (it decides what the first TubeMath story builds).
3. ADR-0014 OQ1 (plinth span) before the Obstacle view, Environment and Ball view epics.

### Required ADRs
Audio policy (deferrable). No other ADR is missing.

### Small edits (one session, one commit)
ADR-0013 (C-21 `to_world` fate, C-23 loader clause), ADR-0003 line 98 (C-24), `architecture.md` v1.1 (C-21, lines 302 and 323, module rows), `tr-registry.yaml` TR-tube-track-002 and `tr-baseline/world-movement.md` (C-21), `tests/unit/tube_track/test-plan.md` (C-21), `design/registry/entities.yaml` and `docs/registry/architecture.yaml` (C-22), `ball-movement.md:191` and `run-state-restart.md` rank table (C-24), `systems-index.md:207`, `tr-baseline/world-movement.md:45`, and the five stale "no accessibility-requirements.md" passages (`hud.md` 242 and 289, `menus-screen-flow.md` 327 and 397, `interaction-patterns.md` 259). Verify by grep, not by another full review.

---

## Pre-gate checklist

| Item | State |
|---|---|
| `tests/unit/` | ✅ |
| `tests/integration/` | ✅ (scaffolded, empty) |
| `.github/workflows/tests.yml` | ⚠️ the workflow is `.github/workflows/ci.yml` (name set by ADR-0009, `workflow_dispatch` only); the skill's literal path is absent |
| `design/accessibility-requirements.md` | ✅ (d57d190) |
| `design/ux/interaction-patterns.md` | ✅ |
| `project.godot` | ❌ (needed for every spike) |
| `docs/architecture/control-manifest.md` | ❌ `/create-control-manifest` after Acceptance |
| `tools/ci/run_ci.py`, `lint_runner.py`, `lint_rules.json`, `godot.sha512`, GUT vendored, spike T-1 | ❌ |

`/gate-check` is not offered while any ❌ above remains.
