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

---

## Edit pass applied (2026-10-03, author session)

Applied by the authoring session after this review; **not independently re-reviewed**. Verified by grep only (no remaining live `to_world`, no "no accessibility-requirements.md" text in `design/`).

| Item | Resolution |
|---|---|
| C-21 | ADR-0013 states that `TubeMath.local_point` replaces the proposed `to_world`, and that the logical `P` is a test-only reference. `architecture.md` signature, TR-tube-track-002 (`revised: 2026-10-03`), `tr-baseline/world-movement.md` (lines 8 and 35) and `tests/unit/tube_track/test-plan.md` (lines 19 and 163) updated. Tube Track OQ18 is a historical open question and is left as written. |
| C-22 | `design/registry/entities.yaml` `P` notes rewritten (logical frame, rebase, retired constant); `docs/registry/architecture.yaml` `raw_s_in_vector3` description no longer mandates `local_coords = true`. |
| C-23 | Map-loader clause removed from ADR-0013 (Decision 2 and the `reset()` signature comment); ADR-0004 untouched. |
| C-24 | ADR-0003 `idle_step` comment ("only in Menu (Tube Track Idle)"); `ball-movement.md` edge case; `run-state-restart.md` `run_reset` rank 1 names `WorldFrame`. |
| Housekeeping | `systems-index.md` line 207 and `tr-baseline` line 45 mark `S_PRECISION_LIMIT` retired; `architecture.md` lines 302 and 323 mark ADR-0013 written (Proposed); the five accessibility passages in `hud.md`, `menus-screen-flow.md` and `interaction-patterns.md` now cite the committed tier and keep WCAG-AA contrast as the spec baseline. |

**Still open:** `architecture.md` v1.1 module rows (ADR-0010 to ADR-0014 components, layer stack, Phase B step; only the stale lines were fixed), TD review and Acceptance of ADR-0002 to ADR-0014, ADR-0014 OQ1, the audio ADR, and the pre-gate items.

---

## Technical-director review of ADR-0002 to ADR-0014 (2026-10-03)

Verified against `production/session-logs/agent-audit.log`: `technical-director` invocation completed 2026-10-03 14:29:23. Read-only review; the agent read run 4 and run 5, `architecture.md`, ADR-0002 to ADR-0014, `ci.yml`, the `tests/` tree and Environment GDD lines 222 and 261. It did **not** read ADR-0001, the GDDs in full, the TR registry, the traceability index or `agent-audit.log`. Verdict **CONCERNS**: no blocking architectural flaw, no dependency cycle. The verdict is advisory; **no ADR status has been changed** (moving to Accepted is the project owner's decision).

| ADR | TD verdict | Conditions |
|---|---|---|
| 0002 | ACCEPT WITH CONDITIONS | The `_wire()` sketch lacks the `WorldFrame.on_run_reset` rank-1 row, the `map_load_failed` row and the `phase_changed` rows (ADR-0010, 0014): add or label partial. AC-30 spy on 4.7.2 gates the first Run State story; PS-1/PS-2 gate the first Platform story. |
| 0003 | **REVISE FIRST** | Decision 1 says R-1 must pass "before this ADR is Accepted"; the P-1 ordering note says it gates the first dependent story. Reword. The boot guard (`get_current_rendering_method() != mobile` refuses to run) must be an injectable seam or skipped headless, or any CI test that builds `GameRoot` fails; confirm the headless return value in T-1. Update technical-preferences (Forward+ to Mobile) on Acceptance. |
| 0004 | ACCEPT WITH CONDITIONS | Stale "`map_ready` only after B4" and "B4 is last" (should be B5). ADR-0014 needs `MapDefinition.hazard_style` with `HAZARD_STYLE_INVALID` in Phase A, and `camera_far`; `camera_far` depends on the map's fog end, so `CameraMath.published` (run at composition, before any map) cannot produce it: derive it in Phase A from `MapConfig.env`. MS-1 gates first playable. |
| 0005 | ACCEPT WITH CONDITIONS | V-1 gates the first Tilt story and any tuning lock; verification item 4 (stock Buttons on a real phone) gates the first HUD/Menus story; fix the stale "future ADR-0006/0011" reference; ADR-0011 OQ1 may amend `FOCUS_NONE`. |
| 0006 | ACCEPT WITH CONDITIONS | PS-1, PS-2, PS-4, PS-12 gate the first Platform story (PS-4 failing is a release blocker); clarify min SDK (item 14 says 24, the decision says 28); add `DisplayFacts.screen_dpi`. |
| 0007 | ACCEPT WITH CONDITIONS | SP-1, SP-2, SP-3 gate the first Save story; cite "after `Menus.tick`" instead of "step 11"; GDD edits (AC-10, slider commit on drag end). |
| 0008 | ACCEPT WITH CONDITIONS | Preflight test path is `tests/unit/...` but classed Integration: move to `tests/integration/`; keep P3 (500 seeds) out of the debug-build boot or measure it; Pattern/Obstacle design review before the Pattern epic; OB-1. |
| 0009 | ACCEPT WITH CONDITIONS | T-1 before the first story; fix the ADR-0008 path; update the coding-standards CI line on Acceptance. |
| 0010 | ACCEPT | PT-1 to PT-4 gate the Juice hit-sequence and Ink-cut stories; text nit "Five cores". |
| 0011 | ACCEPT WITH CONDITIONS | UI-1 gates the first UI story; OQ1 (focus) decided before the Menus views; from memory, unverified: `canvas_items` with a zero base size may not be expressible, and a base size would double the dp maths; UI-1 should also test `stretch/mode = disabled` plus `content_scale_factor`. |
| 0012 | ACCEPT WITH CONDITIONS | R-1 checks 1 to 15; art director signs off ball legibility (OQ1) before the Ball view story is Done; Juice wording (OQ2) in design review. |
| 0013 | ACCEPT WITH CONDITIONS | `HazardView.rebase()` calls `s_offset_of(id)` but ADR-0014 guarantees that accessor only during the emission: store `s_offset` at bind, or guarantee it while bound. PRC-1 gates first playable. |
| 0014 | ACCEPT WITH CONDITIONS | OQ1 below; the ADR-0004 amendments above; OQ3 (pool hidden in Menu) confirmed. |

**Other points.**
- Per-frame order, `_wire()` ranks and `WorldGeometry`/`WorldFrame` ownership are consistent across ADRs.
- Draw calls: about 84 concurrent on Mobile against 150 is credible. On the Forward+ fallback the TD's arithmetic gives about 130 or more with the engine baseline unknown, so the margin is thin; R-1 must record the baseline.
- P-1 is sound only with a tightening: a failed R-1 changes `F_read`, the hazard draw-call figures and the ADR-0012/0014 numbers, so R-1 runs first once `project.godot` exists, and **no Environment, Hazard view or Ball view story starts until R-1 is recorded**.
- Acceptance order: 0002, 0003 (after the fix), 0005, 0004 (with its amendments), 0006, then 0007, 0008, 0011, then 0009, 0010, 0014, then 0012, then 0013.
- Audio ADR: not needed before accepting the rest (a leaf; non-positional `AudioStreamPlayer` only, bus layout, OS audio-focus owner in Platform Services, cues on Juice stamp edges). Write it before the Juice audio stories.
- **ADR-0014 OQ1 (plinth span):** blocks only the Double Gate plinth geometry and the Environment plinth stories, not Acceptance. The proposed 0.5 D extension along `s` breaks Pillar 2: a 0.12 u lip is visible to the ball within about 0.286 u of its edge, while the hit expansion along `s` is D/2 = 0.4 u, so the ball would visibly touch the lip for about 0.29 u before any hit. TD recommendation: per-piece footings, angularly inset, with the `s` extension capped at about 0.11 u or zero; add invariant I4 (no raised geometry within the ball's visual reach outside the hit-expanded footprint); revise Environment Rule 10, TR-environment-theming-012 and AC-14 (the GDD premise that the plinth "can never foul the ball's path" is wrong).

Items marked "from memory" are the agent's unverified engine recollection.

---

## TD conditions applied (2026-10-03, author session)

Applied by the authoring session; **not independently re-reviewed**, and **no ADR status was changed**.

| ADR | Applied |
|---|---|
| 0002 | `_wire()` sketch gains the `WorldFrame.on_run_reset` rank-1 row, the `phase_changed` rows (Ink cover, Hazard View) and the `map_load_failed` row, labelled a partial sketch. |
| 0003 | R-1 gates the first Tube Track story and runs first (no Environment, Hazard view or Ball view story until it is recorded); the boot guard reads the rendering method through an injectable seam so headless CI can build `GameRoot`; Ordering Note names the technical-preferences update on Acceptance. |
| 0004 | Phase A gains A3b (`HAZARD_STYLE_INVALID`) and A5 derives `camera_far` from the validated env (it is not in `CameraMath.published`); "B4" corrected to B5; `MapDefinition.hazard_style`, `MapConfig.hazard_style` and `MapConfig.camera_far` added. |
| 0005 | stale "future ADR-0006/0011" reference fixed. |
| 0006 | min SDK settled at 28 (verification item 14 rewritten); `screen_dpi` added to the display facts. |
| 0007 | "step 11" replaced by "after `Menus.tick`". |
| 0008 | preflight test path moved to `tests/integration/...`; P3 stays out of the debug-build boot. |
| 0010 | "Five cores" corrected to three. |
| 0011 | UI-1 also tests `stretch/mode = disabled` with `content_scale_factor`; the zero-base-size assumption is marked unverified. |
| 0013 / 0014 | `HazardView` stores `s_offset` at bind; `rebase()` no longer calls the Obstacle accessor. |
| 0014 OQ1 | RESOLVED: per-piece footings, `s` extension capped at 0.114 u (default 0), invariant I4 and its tests; Environment GDD Rule 10 carries a revision-required note (Rule 10, TR-environment-theming-012 and AC-14 still to be rewritten in a design review; systems-index status unchanged). |

**Not applied (nothing to edit):** ADR-0009 (its only condition was the ADR-0008 path, fixed there; the coding-standards CI line is updated on Acceptance), ADR-0012 (all conditions are gates: R-1 checks 1 to 15, art-director sign-off, Juice wording).

---

## Acceptance (2026-10-03)

- Second technical-director invocation (re-check of commit 136db60), logged in `production/session-logs/agent-audit.log`: all of ADR-0002 to ADR-0014 READY TO ACCEPT; four minor consistency defects reported and fixed before Acceptance (camera_far ownership aligned in ADR-0004 A5 and ADR-0014 lines 136, 230, 246; the vacuous `camera_far < F_rest` check replaced by `L <= 0` or non-finite; T-1 in ADR-0009 now records the headless rendering-method value; the injected `rendering_method_getter` named in ADR-0002 Decision 4; stale `screen_dpi` follow-up wording in ADR-0011).
- **ADR-0002 to ADR-0014 set to Accepted (2026-10-03)** on the project owner's delegation ("tu quyet dinh", the owner's instruction that the assistant decide the plan). The TD review is advisory; the owner's delegation is the authority for the status change, not the TD verdict.
- Synchronised per ADR-0009 Decision 8 and ADR-0003: `architecture.md` (statuses), `.claude/docs/technical-preferences.md` (Rendering Mobile with Forward+ fallback, GUT, forbidden patterns pointer, decisions log), `.claude/docs/coding-standards.md` (CI line). **Not yet done from Decision 8:** replacing the gdUnit4 scaffolding in the `/test-setup`, `/smoke-check`, `/test-helpers`, `/test-flakiness` skills, and marking the GDD open questions (Ball Movement 12, Obstacle 9, Platform Services 18, Tilt Input 16) and the systems-index note resolved.
- Conditions that stay open as gates: every spike on the first dependent story; R-1 before any Environment, Hazard view or Ball view story; art-director sign-off of ball legibility (ADR-0012 OQ1); the Environment GDD revision (Rule 10, TR-environment-theming-012, AC-14) before the plinth stories; the audio ADR before the Juice audio stories.
