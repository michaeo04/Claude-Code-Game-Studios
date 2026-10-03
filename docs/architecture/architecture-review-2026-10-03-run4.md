# Architecture Review Report (run 4)

Date: 2026-10-03 (fourth run, fresh session)
Mode: full (`/architecture-review`), delta review
Engine: Godot 4.7.2, GDScript, Android only (ADR-0001)
GDDs reviewed: 16 system GDDs through the 348-requirement baseline. Changed since run 3: `camera.md`, `juice-feedback.md`, `tube-track.md` (amendment pass 5d4c4d5) and `ball-movement.md`, `tube-track.md` (ADR-0013, 0cf2497).
ADRs reviewed: 14 (ADR-0001 Accepted; ADR-0002 to ADR-0014 Proposed)
Previous runs: `architecture-review-2026-10-03.md`, `-rerun.md`, `-run3.md`

**Method note.** Scope is the three commits after run 3: the amendment pass (5d4c4d5, C-1 to C-17), the P-1 resolution (37e7560) and ADR-0013 (0cf2497). Every diff was read in full; ADR-0013 was read in full and checked against ADR-0002 (per-frame order, `_wire()` ranks), ADR-0003, ADR-0004, ADR-0010, ADR-0012, ADR-0014, the registry, `architecture.md`, and the Tube Track, Camera, Ball Movement GDDs. The engine-specialist second opinion of Phase 5 **was run for the first time** (`godot-specialist`, read-only). Most of its points come from memory of the engine and are marked as such; the engine reference modules stop at 4.6.

---

## Traceability Summary

| Status | Run 3 | This run | Share |
|---|---|---|---|
| ✅ Covered | 174 | **179** | 94% |
| ⚠️ Partial | 15 | **11** | 6% |
| ❌ Gap | 2 | **1** | 1% |
| ➖ GDD-owned (not counted) | 157 | 157 | n/a |

Architecture-relevant: 191. Total: 348. No new TR-IDs; the registry text of TR-tube-track-017 was already revised in 0cf2497.

**Gap to Covered (1):** TR-tube-track-017 (ADR-0013: render-origin shift, `s` unbounded float64).

**Partial to Covered (4), closed by the amendment pass:**
- TR-tube-track-015 and TR-settings-accessibility-009 (ADR-0003 Decision 2: Tube Track pulls the Settings getter every frame in every state and writes the material only on change; C-1).
- TR-tube-track-016 (ADR-0002 Decision 6 now lists `TubeView.idle_step`; C-2 and C-11; see C-19 for a wording defect).
- TR-camera-016 (ADR-0004 Decision 1: `CameraMath.published` takes `WorldGeometry` and `OMEGA_MAX`; C-3 and C-6).

### Remaining gap
| Missing decision | TR | Domain | Engine risk | Suggested ADR |
|---|---|---|---|---|
| Audio: three Juice cues, bus layout, OS audio policy owner | juice-feedback-016 | Audio | LOW | deferrable |

### Remaining partial (11)
TR-tube-track-012 (Mobile fog gated by R-1), TR-obstacle-system-010 and TR-pattern-difficulty-011 (GDD revision needed), TR-pattern-difficulty-014 (`t_dodge_worst` supply), TR-near-miss-detection-019 (coalescing in Juice), TR-scoring-personal-best-003 (script reflection on 4.7.2), TR-run-state-restart-022 (`t_reset` shares), TR-platform-services-006 (Back on SDK 36, PS-4), TR-save-persistence-012 (once per load vs once per key), TR-settings-accessibility-005 (slider commit), TR-environment-theming-012 (plinth span, ADR-0014 OQ1).

Full matrix: `docs/architecture/architecture-traceability.md`.

---

## Verified (no finding)

- **C-1 to C-17 are closed.** Each amendment was checked against its diff: seam scale pull and write rule and the uniform list (ADR-0003 Decision 2, C-1 and C-16); `idle_step` and `BallView.tick` in the per-frame order and the construction order (ADR-0002, C-2, C-11); `WorldGeometry` owning `D` (ADR-0004, ADR-0012, ADR-0014, C-3 and C-6); draw calls 34 plus 1 Hit flash, about 81 concurrent against 150 (ADR-0003 Decision 7, C-4 and C-9); ADR-0008 wording (C-5); ADR-0005 wording (C-7); Phase B step B4 (ADR-0004, C-8); fixed fixture table instead of random colours (ADR-0012, C-10); fog colour and warm-up list (ADR-0003, C-12); `set_ball_visible` in ADR-0012 and the registry (C-13); the hold is time only (ADR-0010, C-14); `HIT_FLASH_S` and `GREY_CROSSFADE_S` (C-15); lint additions (ADR-0009, C-16); back-references and step names (C-17, except C-20 below).
- **ADR-0013 arithmetic.** ulp(1128) = 2^-13, 8 ulp = 9.8e-4 < 0.0024 u; 8 ulp at 2048 = 0.00195. Default window `(84 + 9 + 1) * 12 = 1128 <= 2048`.
- **Idle scroll.** `s_idle` wraps into `[0, L)` (Tube Track Rule 11, F8), so it needs no rebase.
- **`run_reset` rank.** `WorldFrame.on_run_reset` at rank 1 ties with Pattern and runs before the Tube Track adapter (rank 2) and Obstacle; matches `architecture.md` line 152 and ADR-0002 Decision 7.
- **P-1.** Resolved in ADR-0003, ADR-0009 and `architecture.md` as a project-owner decision. `production/session-logs/agent-audit.log` shows no `technical-director` invocation on 2026-10-03; the commit message says so too. This is **not** a TD ratification (coding standards, verification obligation).
- **No dependency cycle.** ADR-0013 depends on ADR-0002, 0003, 0004, 0012, 0014; none of them lists it under Depends On.

---

## Cross-ADR Conflicts

No blocking conflict and no dependency cycle.

### C-18: ADR-0013 vs Tube Track Rule 1, Camera F4, ADR-0010 Decision 3 (`P`) - Medium, Integration
- Tube Track Rule 1 (line 87) still defines `P(theta, s, h) = ((R + h) * sin(theta), (R + h) * cos(theta), -s)`, "the only place that converts to world space". Camera F4 places the camera through `P(phi_cam, s_ball - CAMERA_BACK_DISTANCE, ...)`; ADR-0010 releases the shards at "the ball's pose (Tube Track's `P`)".
- ADR-0013 makes `WorldFrame.render_z` the only placement of `s` and says cores publish ball-relative offsets, but never says what happens to `P`.
- Impact: a story that follows the Camera or Juice text builds a `Vector3` with raw `-s`, exactly what ADR-0013 forbids; the raw z also breaks at the first rebase.
- Resolution: split `P` into a local point `(x, y)` from `(theta, h)` plus `render_z(s)`, or give `P` a `WorldFrame`; revise Tube Track Rule 1, Camera F4 and its symbol table; ADR-0010 places shards from `BallView`'s global transform.

### C-19: ADR-0002 Decision 6 vs ADR-0003 and Tube Track (`idle_step`) - Medium, Integration
- ADR-0002 (amended in 5d4c4d5): `TubeView.idle_step(real_dt)` "only when the phase is not Running", and its spy test asserts that.
- ADR-0003 Key Interfaces: "called by GameRoot in Idle". Tube Track States: Paused and Ended "hold still"; `idle_step` belongs to the Idle state.
- Impact: implemented as written, the seam phase scrolls during Paused, Hit and Resuming, which breaks the world freeze (Juice Rule 3, ADR-0010) and the seam-phase assumptions of PT-1.
- Resolution: "only when the phase is Menu (Tube Track Idle)"; fix the spy test to match.

### C-20: stale back-references and missing lint rules (ADR-0013 follow-through) - Low
- ADR-0003 line 207 and ADR-0014 line 273 still say "future ADR-0013".
- ADR-0013 says the `raw_s_in_vector3` rule and the `physics_interpolation = false` `project_setting` are registered by ADR-0009; ADR-0009's lint list lacks both. The registry now lists `raw_s_in_vector3` as an active forbidden pattern, so ADR-0009's registry-coverage meta-rule has no rule to match.
- Resolution: edit the two references; add both rules to ADR-0009.

### Pending amendments declared by ADR-0013 (not conflicts)
ADR-0002 Decision 6 (`WorldFrame step` after `TubeTrack.advance`, construction order for `WorldGeometry` and `WorldFrame`), ADR-0003 (`TubeView.rebase`), ADR-0012 line 76 ("`z = -s` today"; replace by `render_z`), ADR-0014 (placement through `render_z`, `HazardView.rebase`). Until Accepted these show as stale text.

---

## ADR Dependency Order

```
1  ADR-0001 Android only                              Accepted
2  ADR-0002 Game loop, Composition Root               Proposed (0001)
3  ADR-0003 Renderer and tube render route            Proposed (0001, 0002)
3  ADR-0005 Sensor source and input pipeline          Proposed (0001, 0002)
4  ADR-0004 Map Loader and MapConfig                  Proposed (0002, 0003)
4  ADR-0006 Android platform integration              Proposed (0001, 0002, 0003, 0005)
5  ADR-0007 Persistence implementation                Proposed (0001, 0002, 0006)
5  ADR-0008 Hazard, collision, content format         Proposed (0002, 0003, 0004)
5  ADR-0011 UI architecture                           Proposed (0002, 0003, 0005, 0006)
6  ADR-0009 Test framework and CI                     Proposed (0002, 0004, 0007, 0008)
6  ADR-0010 Presentation time, hit-stop, Ink cover    Proposed (0002, 0011)
6  ADR-0014 Hazard render route                       Proposed (0002, 0003, 0004, 0008)
7  ADR-0012 Ball material and world chroma            Proposed (0002, 0003, 0004, 0014)
8  ADR-0013 Distance precision and render origin      Proposed (0002, 0003, 0004, 0012, 0014)
```

- No cycle. Every ADR from 0002 to 0013 depends on a Proposed ADR (unchanged).
- **P-1:** device spikes under `prototypes/` may run before Acceptance, and each spike gates the first dependent story. The ADR Acceptance itself still needs a technical-director review, which has not happened.

---

## Engine Compatibility

- ADRs with an Engine Compatibility section: **14 / 14**. All state Godot 4.7.2.
- Deprecated APIs: none. Post-cutoff APIs named in the ADRs (`GPUParticles3D.restart(keep_seed)` 4.4, typed `Dictionary` 4.4, `mouse_behavior_recursive` 4.5 (not used), Shader Baker 4.5, `global_shader_parameter_set`, Environment fog properties) have correct names per the specialist.
- Not in the engine reference, carried as spikes: PRC-1 (ADR-0013: error model, camera-relative CPU maths, rebase frame capture), R-1, HV-1, UI-1, UI-A1, PT-1 to PT-4. `modules/` stops at 4.6.

### Engine Specialist Findings
`godot-specialist`, first run of this phase. **0 BLOCKER, 0 HIGH.** Source "memory" means pre-4.4 knowledge, unverified on 4.7.2.

**Confirmed:** the 2-ulp and 8-ulp error model and `Z_RENDER_MAX`; same-frame transform flush before draw (no half-shifted frame if every write is in `GameRoot._tick`; memory); `physics/common/physics_interpolation` setting, `physics_interpolation_mode` and `reset_physics_interpolation()` exist since 4.3 (a no-op with the setting off); MultiMesh chunking and AABB culling; view-space fog and depth independent of world z; all Environment fog property names, global shader parameter API, `GPUParticles3D` one-shot pattern; `Control` mouse-filter defaults.

| ID | ADR | Severity | Finding | Source |
|---|---|---|---|---|
| E-1 | 0013 Decision 3 | Medium | The rule for running-state effects ("`GPUParticles3D` with `local_coords = true`, or parented to the ball") is inconsistent for trails: a ball-parented local-space trail moves rigidly with the ball, and a world-space trail (`local_coords = false`) jumps about 1008 u at each rebase and leaves the far plane for one particle lifetime. Choose: accept the one-lifetime vanish, add a compensating backward velocity, or `restart()` the emitters on the rebase tick. | follows from ADR text |
| E-2 | 0013 Decision 2 | Low/Medium | Only `on_run_reset` is a `_wire()` row. Running to Menu goes through `to_idle`, and `load_map` starts the run state; a stale `origin_s` of 1000 u or more puts idle slots at z of about +4000 and trips the debug assertion. Add an explicit reset for `to_idle` and `load_map` before the slots are re-primed, with a Running-to-Menu test after a rebase. | follows from ADR text |
| E-3 | 0013 Summary, Decision 4 | Low | "Exact to 2^53 (about 3.6e8 s at `V_MAX` = 25)" is garbled: 3.6e8 s is s of about 9e9 u (about 2^33), where the float64 ulp is about 2e-6 u. | arithmetic |
| E-4 | 0012 Decision 4 | Low | "`fog_color` equals the sky horizon colour": the property is `fog_light_color`; check `EnvConfig.validated` and its test use the same name. | engine reference |
| E-5 | 0014 Decision 2 | Low | Text says no normal array is built, but `HazardMeshData` declares `body_normals` and `plinth_normals`; a surface without `ARRAY_NORMAL` on Mobile is not covered by the reference. Add to R-1 check 3. | memory |
| E-6 | 0003 Decision 1 | Low | With `fallback_to_opengl3` off and no Vulkan the engine aborts before `GameRoot` runs its `get_current_rendering_method()` check; the real guard is the Play manifest requirement (ADR-0006). | memory |
| E-7 | 0003 Decision 1 | Low | Windows desktop previews default to D3D12 since 4.6; pin `rendering/rendering_device/driver.windows = "vulkan"` for fog and screenshot checks. | reference |
| E-8 | 0003 Decision 6 | Low | 4.4+ ships its own pipeline-compilation work (memory); keep the warm-up scene and measure with and without it. | memory |
| E-9 | 0010 Decision 1 | Low | `GPUParticles3D.fixed_fps` defaults to 30; set it deliberately for the shards (0 follows the display); check `interpolate` in PT-2. | memory |
| E-10 | engine reference | Low | `deprecated-apis.md` and `rendering.md` row "`Texture2D` in shader parameters to `Texture`" reads as shader source; shader source still declares `sampler2D`. Clarify the row (reference defect, not an ADR defect). Also `AudioStreamPlayer3D.doppler_tracking` is off by default; a 1008 u jump would spike it if ever enabled. | reference |

**Could not verify (specialist):** Mobile renderer CPU camera-relative maths in 4.7.2 (PRC-1 item 2); `CanvasLayer.visible = false` blocking GUI input; fog, unshaded fog, MSAA 2x and SMAA on Mobile (R-1); global shader parameters on Mobile; Android `screen_get_dpi()`; AccessKit on Android in 4.7.2; `PASS` on a stock Button inside a `ScrollContainer` (ADR-0011 check 5b); any 4.7 delta limit on Tween or process; the 4.7 shader preprocessor and particle changes (ADRs avoid both); `set_surface_override_material` persistence across a mesh swap.

---

## GDD Revision Flags (Architecture → Design Feedback)

Systems-index statuses are **unchanged** (standing user decision, 2026-10-03); each flag takes effect when its ADR is Accepted. Earlier flags stand.

| GDD | Assumption | Reality (ADR) | Action |
|---|---|---|---|
| tube-track.md Rule 1 (line 87) | `P(theta, s, h)` has `z = -s` and is the only world conversion | `WorldFrame.render_z` is the only placement of `s` (ADR-0013); C-18 | revise `P` |
| camera.md F4 and symbol table | `camera_position` and `look_at_point` are world-space via `P(phi_cam, s_ball - ..., ...)` | the core publishes ball-relative offsets; the view adds `render_z(s_ball)` (ADR-0013); C-18 | revise F4 |
| ball-movement.md lines 128, 165, 259, 263 | `S_PRECISION_LIMIT` (16384) is a live Tube Track constant and a run horizon | retired by ADR-0013 (line 191 and Open Question 6 already updated) | reword as a test horizon |
| tube-track.md F4 and AC-15 | precision derivation | kept as derivation only; AC-15 superseded by ADR-0013 Validation Criteria | done |
| systems-index.md line 207 and `tr-baseline/world-movement.md` line 45 | `S_PRECISION_LIMIT` timing risk, unvalidated knob | retired | housekeeping |

---

## Architecture Document Coverage

- 16 / 16 GDD systems appear in `architecture.md`. v1.0 still lists ADR-0013 as unwritten (lines 302, 323) and lacks the components of ADR-0010 to ADR-0014 in its module tables (`InkCoverCore`, `PresentationMath`, `HazardView`, `BallView`, `WorldChroma`, `UiScaler`, `WorldFrame`, layer stack, Phase B step). v1.1 pass still pending.
- Playtest Telemetry (MVP, no GDD) is still absent from architecture and every ADR; Composition Root and Map Loader still have no systems-index row.

---

## Verdict: CONCERNS

94% of architecture-relevant requirements covered (up from 91%), no blocking conflict, no cycle, 14 / 14 ADRs carry an Engine Compatibility section, the engine specialist found no BLOCKER or HIGH issue.

### Blocking before coding starts (`src/`)
1. ADR-0002 to ADR-0014 are Proposed; they need a technical-director review (P-1 was a project-owner decision, not a TD ratification).
2. **C-18, C-19, E-1, E-2** settled before ADR-0013 is Accepted.
3. **ADR-0014 OQ1 (plinth span)** settled before the Obstacle view, Environment and Ball view epics.

### Required ADRs
Audio policy (deferrable). No other ADR is missing.

### Small edits (one session)
ADR-0002 (C-19, ADR-0013 step, construction order), ADR-0003 (C-20, E-6, E-7, E-8), ADR-0009 (C-20 lint rules), ADR-0010 (C-18 shard origin, E-9), ADR-0012 (E-4, line 76), ADR-0013 (C-18, E-1, E-2, E-3), ADR-0014 (C-20, E-5), plus Tube Track Rule 1, Camera F4, Ball Movement text, `architecture.md` v1.1, and the engine reference row of E-10.

---

## Pre-gate checklist

| Item | State |
|---|---|
| `tests/unit/` | ✅ |
| `tests/integration/` | ❌ `/test-setup` |
| `.github/workflows/tests.yml` | ❌ `/test-setup` |
| `design/accessibility-requirements.md` | ❌ `/ux-design` (ADR-0011 requires it before the pre-production gate; the Ink cut counts as a named flash in it) |
| `design/ux/interaction-patterns.md` | ✅ |
| `project.godot` | ❌ (needed for every spike) |
| `docs/architecture/control-manifest.md` | ❌ `/create-control-manifest` after Acceptance |

`/gate-check` is not offered while any item above is ❌. Re-run `/architecture-review` after the amendment pass.

---

## Amendment pass applied (2026-10-03, same day, author session)

Applied by the authoring session; **not yet re-reviewed** (the next `/architecture-review` must run in a fresh session).

| Item | Resolution |
|---|---|
| C-18 | ADR-0013 gains a section "The GDD frame `P(theta, s, h)`": the GDD formula stays as the logical frame; implementation is `TubeMath.local_point(theta, h)` (x, y) plus `WorldFrame.render_z(s)` (z); camera worked case. One-sentence notes in `tube-track.md` Rule 1 and `camera.md` F4; ADR-0012 BallView placement and ADR-0010 shard origin updated. Juice and Ball Movement GDD formulas unchanged. |
| C-19 | ADR-0002 Decision 6 and its spy test: `idle_step` only when the phase is Menu (Tube Track Idle), never in Paused, Hit or Resuming. |
| C-20 | "future ADR-0013" replaced in ADR-0003 and ADR-0014; ADR-0009 lint table gains `raw_s_in_vector3` (ADVISORY) and the `physics_interpolation` project setting. |
| ADR-0013 follow-through | `WorldFrame step` after `TubeTrack.advance` and `WorldGeometry` and `WorldFrame` in the construction order (ADR-0002); `TubeView.rebase()` (ADR-0003); placement through `render_z` and `HazardView.rebase()` (ADR-0014). |
| E-1 | ADR-0013 effects row rewritten: no running-state world-space effect exists in the MVP; future ones decide explicitly; stored anchors keep `s` and convert each tick. |
| E-2 | `WorldFrame.reset()` called by the Tube Track adapter immediately before `to_idle()` (and by the loader before `load_map`); new wiring test. |
| E-3, E-4, E-5, E-6, E-7, E-8, E-9, E-10 | Applied as worded in the table above (ADR-0013 arithmetic, ADR-0012 fog colour naming, ADR-0014 normals and R-1 row, ADR-0003 boot check, Windows Vulkan driver pin and warm-up measurement, ADR-0010 `fixed_fps`, engine-reference `Texture2D` rows). |
| Ball Movement GDD | `S_PRECISION_LIMIT` references reworded as the retired constant. |

**Still open:** `architecture.md` v1.1 (module tables, ADR-0013 listed as unwritten at lines 302 and 323), `systems-index.md` line 207 and `tr-baseline/world-movement.md` line 45 (retired constant), ADR-0002 to ADR-0014 Acceptance (TD review), ADR-0014 OQ1 (plinth span), the audio ADR, and the pre-gate items (`project.godot`, spike T-1, `run_ci.py`, control manifest).
