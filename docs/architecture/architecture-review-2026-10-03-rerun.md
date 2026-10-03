# Architecture Review Report (re-run)

Date: 2026-10-03 (second run, fresh session)
Mode: full (`/architecture-review`)
Engine: Godot 4.7.2, GDScript, Android only (ADR-0001)
GDDs reviewed: 16 system GDDs through the 348-requirement baseline. No GDD changed since the first run (`git diff 60e30fd..b2a818b` touches only ADR-0011, ADR-0012, ADR-0014 and `docs/registry/architecture.yaml`), so the baseline and the TR registry are reused unchanged.
ADRs reviewed: 12 (ADR-0001 Accepted; ADR-0002 to ADR-0009, ADR-0011, ADR-0012, ADR-0014 Proposed)
Previous run: `docs/architecture/architecture-review-2026-10-03.md`

**Method note.** The three new ADRs were read in full; every claimed conflict was checked against the text of the other ADR or GDD (ADR-0002 §5 and §6, ADR-0003 Decisions 2, 3, 4, 6, 7, ADR-0004 Phase B, ADR-0005 line 107, ADR-0006 Decisions 2 and 6, environment-theming.md F2, tube-track.md Structure and Sources of truth, camera.md F2, run-state-restart.md AC-8). The engine-specialist second opinion of Phase 5 was **not run** (as in the first run); each new ADR carries a `godot-specialist` review (ADR-0012 also the shader specialist) from its authoring session.

---

## Traceability Summary

| Status | First run | This run | Share |
|---|---|---|---|
| ✅ Covered | 157 | **172** | 90% |
| ⚠️ Partial | 17 | **17** | 9% |
| ❌ Gap | 17 | **2** | 1% |
| ➖ GDD-owned (not counted) | 157 | 157 | n/a |

Architecture-relevant: 191. Total: 348.

**Gap to Covered (14):** TR-ball-movement-019 (ADR-0012), TR-obstacle-system-023 (ADR-0014), TR-juice-feedback-008, -012 (ADR-0012), TR-environment-theming-007, -009 (ADR-0012), TR-hud-015, -016, -021 (ADR-0011), TR-menus-screen-flow-014, -015, -016, -019, -021 (ADR-0011).
**Partial to Covered (1):** TR-hud-014 (ADR-0006 safe area plus ADR-0011 dp conversion).
**Gap to Partial (1):** TR-environment-theming-012 (ADR-0014 decides the plinth as surface 1 with an Environment-owned material, but its Open Question 1 shows the GDD span of "gate arc plus 0.5 D" would cover the gap the ball flies through; an Environment GDD revision is needed).
**Unchanged partials (16):** C-1 to C-5 of the first run are still unedited; ADR-0010 is still unwritten (TR-juice-feedback-007, TR-menus-screen-flow-012).

### Coverage Gaps (no ADR exists)

| Missing decision | TR | Domain | Engine risk | Suggested ADR |
|---|---|---|---|---|
| Distance precision at s = 16384 (t = 682 s): run cap or rebase | tube-track-017 | Core | LOW | `/architecture-decision distance precision` (ADR-0013) |
| Audio: three Juice cues, bus layout, OS audio policy owner | juice-feedback-016 | Audio | LOW | deferrable |

Full matrix: `docs/architecture/architecture-traceability.md`.

---

## Cross-ADR Conflicts

No blocking conflict and no dependency cycle.

**Known conflict-prone area** (`docs/consistency-failures.md`, 2026-10-03 entry): "When an ADR restates a value another document owns, copy the owner's rule verbatim and re-check the full input list." C-6 below is a recurrence of exactly that pattern.

### C-6: ADR-0014 and ADR-0012 vs tube-track.md and camera.md (owner of `D`) - Medium, Integration
- ADR-0014 Decision 4: "`tube` supplies `R`, `D`, `N_F`, `L` (the validated `TubeConfig`)"; `HazardMeshBuilder.build(spec, style, tube: TubeConfig, ...)`.
- ADR-0012 Key Interfaces: `BallView.build(style: BallStyle, tube: TubeConfig)` and the mesh `radius = D/2`, built at composition before `MapLoader`.
- tube-track.md (Sources of truth elsewhere): `v_max` and ball diameter `D` belong to Ball Movement and are **not duplicated** in `TubeConfig`; camera.md F2 and ball-movement.md Tuning Knobs: `BALL_DIAMETER` (`D`) is Ball Movement's.
- Impact: either `TubeConfig` gains a second copy of `D` (drift risk, the failure mode Camera's own gaps record) or the two interfaces cannot be implemented as written.
- Resolution: one immutable `WorldGeometry` value (`R`, `D`, `N_F`, `L`) built by `GameRoot` at composition from the base `TubeConfig` and `BallConfig`, validated before the first `MapLoader.attempt`, passed to `HazardMeshBuilder`, `BallView.build` and `CameraMath.published`. This also closes C-3 of the first run (Camera's missing `D` and `OMEGA_MAX` inputs).

### C-7: ADR-0005 vs ADR-0011 (`mouse_behavior_recursive`) - Low, Pattern
- ADR-0005 line 107: "Hidden HUD subtrees disable input with `mouse_behavior_recursive` (4.5), decided in ADR-0011."
- ADR-0011 Decision 5: not used in the MVP; `visible = false` and full-screen STOP blockers.
- Resolution: edit ADR-0005 (ADR-0011 already lists it as a follow-up).

### C-8: ADR-0004 vs ADR-0014 (Phase B contract) - Low, Integration
- ADR-0004: Phase B is B1 to B4, "B1 to B3 are idempotent setters"; `MapLoaderSeams` lists four appliers; the unit test checks the order "B1..B4".
- ADR-0014 Decision 4: a new step `apply_hazard_view` between Pattern and Tube Track that builds inert hidden nodes and meshes, a new seam, a renumbering, and a share of the MS-1 boot budget.
- Resolution: amend ADR-0004 (Phase B list, seam list, "apply steps may build inert hidden nodes and resources", test order, MS-1 note), as ADR-0014 already lists.

### C-9: ADR-0014 internal (hazard draw-call worst case) - Low
- Decision 6 and Performance: **34** (17 bodies plus 17 plinth surfaces, AABB window). Alternative 1, Consequences and Risks: **32**.
- Resolution: use 34 everywhere.

### C-10: ADR-0012 internal - Low
- Lint target: Decision 4 and Migration name `render_globals.gd` as the only caller of `RenderingServer.global_shader_parameter_set`; Validation Criteria says "outside `world_chroma.gd`'s sink".
- Tests: Validation Criteria asks for `ChromaMath.apply` on "random colours"; Decision 3 says "a fixed fixture table, not random colours", and the coding standards require deterministic tests.
- Stale note: the Ordering Note says ADR-0014 "gains two additive methods once this is Accepted", but ADR-0014 already lists `isolate_killer` and `clear_isolation`.
- Resolution: `render_globals.gd` in the Validation Criteria; fixture table; drop the stale note.

### C-11: ADR-0002 §6 vs ADR-0012 and ADR-0011 (per-frame order) - Low, Dependency
- ADR-0002 §6: `... Camera.step, Environment.tick, Juice.tick, HUD.tick, Menus.tick`; no `BallView.tick`, no Idle step (C-2 of the first run).
- ADR-0012 Decision 1: `BallView.tick` right after `Camera.step`. ADR-0011 Decision 3: "`GameRoot` calls `view.tick(real_dt)` at step 11" for Juice, HUD and Menus (ADR-0002 numbering gives 11, 12, 13).
- ADR-0012 Decision 4 also refines the "every other system" construction step (Environment view, `WorldChroma`, `BallView`, `HazardView`, Environment, Juice).
- Resolution: one ADR-0002 amendment covering C-2 and C-11: per-frame order with `BallView.tick` and the Idle step, construction order, spy test; ADR-0011 cites step names, not numbers.

### C-12: ADR-0003 vs ADR-0012 (fog colour, warm-up list) - Low, Pattern
- ADR-0003 Decision 3: fog colour equals the background (static) and "`fog_sky_affect` is set to match". Decision 2: "the only dynamic shared uniform is `seam_contrast_scale`".
- ADR-0012 Decision 4: `fog_light_color` written every change through `WorldChroma`; `fog_sky_affect = 0`, `fog_aerial_perspective = 0`, `fog_sun_scatter = 0`; `fog_color` equals the sky horizon colour (asserted by `EnvConfig.validated`); two global shader parameters.
- ADR-0003 Decision 6 warm-up list lacks the plinth material, the killer-override material and the Menu preview node (ADR-0014 Decision 5, ADR-0012 Decision 5).
- Resolution: amend ADR-0003 together with C-1 and C-4.

### C-4 (first run), now resolvable
With ADR-0014's figure: concurrent gameplay worst case on Mobile is tube 12 + hazards 34 + ball 1 (allocation 4) + props 6 + sky 2 + shards 2 + HUD 20 + Hit flash 1, about 81 (84 with the full ball allocation), plus the Paused overlay; well under 150. On the Forward+ fallback, a depth pre-pass may double the hazard figure to about 68, over its 40 allocation; ADR-0014 already names the escalation (mesh per segment). Amend ADR-0003 Decision 7.

### Still open from the first run
C-1 (seam scale "on change" vs "every frame"), C-2 (folded into C-11), C-3 (folded into C-6), C-5 (ADR-0008 base-segment sentence), architecture.md v1.1 drift (now also missing ADR-0011, ADR-0012, ADR-0014: `HazardView`, `BallView`, `WorldChroma`, `UiScaler`, layer stack).

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
6  ADR-0014 Hazard render route                       Proposed (0002, 0003, 0004, 0008)
7  ADR-0012 Ball material and world chroma            Proposed (0002, 0003, 0004, 0014)
```

- No dependency cycle. ADR-0014 names `isolate_killer` (ADR-0012) in its interface as a forward reference, not a "Depends On".
- ⚠️ Every ADR from 0002 to 0014 depends on at least one Proposed ADR.
- **P-1 (High, unchanged):** the Accepted-versus-spike deadlock still needs the Technical Director's decision. The new ADRs add spikes UI-1, UI-A1 (ADR-0011), HV-1 and twelve R-1 hazard checks (ADR-0014), and fifteen R-1 checks (ADR-0012); each is a device run that needs `project.godot`.
- Back-reference omissions: ADR-0003 "Enables" omits ADR-0014; ADR-0008 "Enables" omits ADR-0014; ADR-0004 does not mention ADR-0014's Phase B step (C-8); ADR-0005 and ADR-0006 do not list ADR-0011.

---

## Engine Compatibility

- ADRs with an Engine Compatibility section: **12 / 12**. All state Godot 4.7.2.
- Deprecated APIs: none. `killer_material = body_material.duplicate()` is a shallow copy of a `ShaderMaterial` that intentionally shares the `Shader` (the deprecated pattern is `duplicate()` on nested resources needing per-instance copies).
- Post-cutoff APIs, no contradiction: ADR-0011 avoids `mouse_behavior_recursive` and the dual-focus APIs (every Button `FOCUS_NONE`), uses AccessKit only through `UiAccess` with no acceptance criterion depending on it; ADR-0014 uses a typed `Dictionary` (4.4); ADR-0012 respects the 4.7 shader preprocessor restrictions (no `#include`, the chroma block copied per shader), consistent with ADR-0003 Decision 6.
- **Not in the engine reference, carried as spikes:** `Window.content_scale_factor` and stretch `canvas_items`/`fractional` semantics, `DisplayServer.screen_get_dpi()` on Android, `Control._has_point()` for emulated touch (UI-1); AccessKit on Android and the property names (UI-A1); `[shader_globals]` and `global_shader_parameter_set` on Mobile, unshaded materials receiving depth fog, `set_surface_override_material` persistence across mesh swaps (R-1 additions); `ArrayMesh` prewarm time (HV-1).
- Reference gap (unchanged and widened): `modules/` stops at 4.6 and has no entries for Window stretch, global shader parameters, `ResourceLoader`, `ConfigFile`, `FileAccess`, `DirAccess` or Android export.

### Engine Specialist Findings
Not run (see Method note). Re-run on request.

---

## GDD Revision Flags (Architecture → Design Feedback)

New flags from ADR-0011, ADR-0012, ADR-0014 (the first run's ten flags stand). Systems-index statuses are **unchanged** (user decision, 2026-10-03, both runs); each flag takes effect when its ADR is Accepted.

| GDD | Assumption | Reality (ADR) | Action |
|---|---|---|---|
| environment-theming.md Rule 10, TR-012, AC-14 | plinth spans the whole gate arc plus 0.5 D | the span covers the gap; per-piece footings, inset inside the footprint (ADR-0014 OQ1) | revise (design change) |
| environment-theming.md F3, Rule 9 | Environment applies `L_ball_adjusted` "to the ball's material" | `BallView` owns the material; Environment calls `set_luminance_target` (ADR-0012) | wording |
| environment-theming.md fog and sky | fog colour static; chroma written per material | `WorldChroma` writes `fog_light_color` with the chroma; `fog_color` equals the sky horizon colour, asserted at load (ADR-0012) | revise |
| juice-feedback.md grey-out | "all world elements" grey out | the ball declares no `hit_grey` (ADR-0012 OQ2); killer isolate via `HazardView.isolate_killer` | confirm in design review |
| camera.md | publishes `rear_extent`, `camera_distance` only | also `camera_far = F_rest + L` (ADR-0014); inputs include `D`, `OMEGA_MAX`, fog end (C-3, C-6) | revise |
| obstacle-system.md CR1, Interface | height is "a rendering concern"; no spec accessor | `HazardStyle` heights; `spec_of`, `s_offset_of` (ADR-0014) | revise |
| ball-movement.md view | view owner unstated | `BallView` (ADR-0012) | wording |
| hud.md OQ9, menus-screen-flow.md | dp conversion open; recursive disable | resolved by ADR-0011; Menus focus is ADR-0011 OQ1 | close OQs |
| design/art/art-bible.md 3b | "one MultiMesh per family" | node per hazard, merged mesh per spec (ADR-0014) | revise |

---

## Architecture Document Coverage

- 16 / 16 GDD systems appear in architecture.md.
- architecture.md v1.0 does not yet contain anything from ADR-0011, ADR-0012 or ADR-0014 (`HazardView`, `BallView`, `WorldChroma`, `UiScaler`, the layer stack, the new Phase B step). Add to the v1.1 pass.
- Playtest Telemetry (MVP, no GDD) is still absent from architecture and every ADR.
- Composition Root and Map Loader still have no systems-index row.

---

## Verdict: CONCERNS

90% of architecture-relevant requirements covered (up from 82%), no blocking conflict, no cycle, 12 / 12 ADRs carry an Engine Compatibility section.

### Blocking before coding starts
1. **P-1:** Accepted-versus-spike deadlock (TD decision).
2. ADR-0002 to ADR-0014 are Proposed (TD condition).
3. **C-6** and **ADR-0014 OQ1 (plinth span)** settled before the Obstacle view, Environment and Ball view epics.

### Required ADRs
1. ADR-0010 Presentation time, hit-stop, Ink cover (closes two partials; ADR-0011 fixes its layer).
2. ADR-0013 Distance precision.
3. Audio policy (deferrable).

### Small edits (one session)
One amendment per ADR: ADR-0002 (C-2, C-11), ADR-0003 (C-1, C-4, C-12), ADR-0004 (C-3 via C-6, C-8), ADR-0005 (C-7), ADR-0008 (C-5), ADR-0012 (C-10), ADR-0014 (C-9, C-6), plus architecture.md v1.1 and the back-references.

---

## Pre-gate checklist

| Item | State |
|---|---|
| `tests/unit/` | ✅ |
| `tests/integration/` | ❌ `/test-setup` |
| `.github/workflows/tests.yml` | ❌ `/test-setup` |
| `design/accessibility-requirements.md` | ❌ `/ux-design` (ADR-0011 requires it before the pre-production gate) |
| `design/ux/interaction-patterns.md` | ✅ |
| `project.godot` | ❌ (needed for every spike) |
| `docs/architecture/control-manifest.md` | ❌ `/create-control-manifest` after Acceptance |

Re-run `/architecture-review` after ADR-0010 and after the amendment pass.
