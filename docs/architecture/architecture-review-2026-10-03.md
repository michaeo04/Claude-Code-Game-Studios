# Architecture Review Report

Date: 2026-10-03
Mode: full (`/architecture-review`, fresh session)
Engine: Godot 4.7.2, GDScript, Android only (ADR-0001)
GDDs reviewed: 16 system GDDs, through `docs/architecture/tr-baseline/` (348 requirements) plus direct reads of the GDD text behind each finding
ADRs reviewed: 9 (ADR-0001 Accepted; ADR-0002 to ADR-0009 Proposed), `docs/architecture/architecture.md` v1.0, `docs/registry/architecture.yaml`

**Method note.** The GDDs were not all re-read in full: the 2026-10-02 `/create-architecture` session had extracted the baseline from the full GDDs, and this review verified every finding against the GDD text with targeted reads (camera.md F2, pattern-difficulty.md CR10, run-state-restart.md R8, art-bible.md, systems-index.md). The engine-specialist second opinion of Phase 5 was **not run** (see Engine Compatibility); every ADR already carries a `godot-specialist` review from its authoring session.

---

## Traceability Summary

Total requirements: 348 (registered in `docs/architecture/tr-registry.yaml`, first run, no renumbering possible).
Architecture-relevant: 191.

| Status | Count | Share of architecture-relevant |
|---|---|---|
| ✅ Covered | 157 | 82% |
| ⚠️ Partial | 17 | 9% |
| ❌ Gap | 17 | 9% |
| ➖ GDD-owned (not counted) | 157 | n/a |

Per-system table and the full matrix: `docs/architecture/architecture-traceability.md`.

### Coverage Gaps (no ADR exists)

| Missing decision | TR | Domain | Engine risk | Suggested ADR |
|---|---|---|---|---|
| **Hazard render route** (how variable-width arc hazards are meshed and instanced, pooling, who owns the view; Double Gate plinth spawner) | obstacle-system-023, environment-theming-012 | Rendering | MEDIUM | `/architecture-decision hazard render route and view node tree` |
| UI architecture: dp to viewport conversion and stretch mode, CanvasLayer indices, recursive disable property, ScrollContainer drag arbitration, AccessKit scope | hud-015, hud-016, hud-021, menus-screen-flow-014, -015, -016, -019, -021 | UI | HIGH | `/architecture-decision UI architecture` (ADR-0011) |
| Ball view, ball material owner, world chroma uniform, Juice rim glow layering | ball-movement-019, juice-feedback-008, -012, environment-theming-007, -009 | Rendering | HIGH | ADR-0012 |
| Distance precision at s = 16384 (t = 682 s): run cap or rebase | tube-track-017 | Core | LOW | ADR-0013 |
| Audio: three Juice cues, bus layout, OS audio policy owner | juice-feedback-016 | Audio | LOW | deferrable |

**Finding G-1 (highest value): the hazard render route has no owner.** ADR-0003 allocates 40 draw calls to hazards and the art bible proposes "one MultiMesh per family, about 60 triangles" (art-bible.md line 152, marked as a proposal for the technical artist to confirm). A hazard footprint piece is an arc `(theta_min, theta_max, s_start, s_end)` with a variable angular width, which a fixed mesh under a linear instance transform cannot reproduce on a curved surface. The content bound (`MAX_PIECES_PER_SEGMENT` 12, about 7 visible segments) also exceeds 40 if each piece is its own node. No GDD or ADR decides it. This must be settled before the Obstacle and Environment epics.

---

## Cross-ADR Conflicts

No blocking conflict and no dependency cycle. Five documentation-level conflicts, each a text edit:

### C-1: ADR-0003 vs ADR-0003 vs Tube Track R9 (`seam_contrast_scale`) - Medium
- ADR-0003 Decision 2: a material parameter "set **only when the setting changes**".
- ADR-0003 Key Interfaces: `set_seam_contrast_scale(v)  # every frame`.
- Tube Track R9 / TR-tube-track-015 / AC-23a: sampled **every frame in every state** (a mutation that samples only at load or `begin_run` must fail).
- Resolution: Tube Track pulls the Settings getter every frame and writes the material only when the value changed. Satisfies all three.

### C-2: ADR-0002 §6 vs ADR-0003 (Idle step) - Low
- ADR-0003 says `GameRoot` calls `TubeView.idle_step(dt)` in Idle; ADR-0002's per-frame order has no such step and bans view `_process`. Environment resting values in Menu (TR-environment-theming-008) are likewise unlisted.
- Resolution: add "5b `TubeView.idle_step(real_dt)` when the phase is not Running" to ADR-0002 §6 and to architecture.md Data Flow.

### C-3: ADR-0004 §1 vs camera.md F2 (inputs of the Camera values) - Medium
- ADR-0004: the three Camera values are "pure functions of `CameraConfig` and `TubeConfig.R`".
- camera.md F2 and Tuning Knobs (line 227): `d_cam` worst case also depends on Ball Movement's `D` (`r_ball = R + D/2`) and `OMEGA_MAX` (`delta` bound = `OMEGA_MAX * CAMERA_LAG_TAU`).
- Resolution: list `BallConfig.D` and `OMEGA_MAX` as inputs of `CameraMath.published`, validate `BallConfig` before the first `MapLoader.attempt`, and state that `camera_distance` is the derived worst case (about 7.84), not the hand-copied 8. This closes the "silent F9 inversion on a retune" gap recorded in Camera's own gaps.

### C-4: ADR-0003 draw-call allocation arithmetic - Low
- 12 + 40 + 4 + 6 + 2 + 2 + 20 + 25 = 111; adding the stated headroom of 40 gives 151 against 150.
- Resolution: state the assumption that Menus (25) is never concurrent with gameplay except the Paused screen, so the concurrent worst case is about 86 + Paused overlay; re-derive after the hazard render route (G-1) fixes the hazard figure.

### C-5: ADR-0008 Decision 2 vs Decision 3 - Low
- Decision 2: `hazards_for_segment` "also exposes the chunk's base segment". Decision 3 and Key Interfaces compute `s_offset = (i - spec.local_segment_index) * L` and return only specs.
- Resolution: delete the Decision 2 sentence.

**Known conflict-prone areas** (from `docs/consistency-failures.md`): the log's recurring pattern is stale "proposed / not yet" prose after a cross-file edit. architecture.md now has the same defect against ADR-0004 and ADR-0008 (below).

### Document drift: architecture.md v1.0 vs ADR-0003 to ADR-0009
Not ADR-vs-ADR, but `/create-control-manifest` reads architecture.md. Stale items: Phase 4 `HazardSpec` "immutable Resource" (now a compiled `RefCounted`), `hazard_bound(..., Array[HazardPiece])` (now `PackedFloat64Array`), `@abstract class_name HazardContentProvider` (now a plain base class), `MapConfig extends Resource` with `tube` and `env` (now `RefCounted` built from `MapDefinition`), Open Question 7 (emulation wording, revised by ADR-0005), "ADRs referenced: ADR-0001", the Open Questions that ADR-0003 to ADR-0009 resolved, and the Playtest Telemetry omission below.

---

## ADR Dependency Order

```
Foundation (no dependency except ADR-0001)
  1. ADR-0001 Android only                           Accepted
Depends on Foundation
  2. ADR-0002 Game loop, Composition Root            Proposed (requires ADR-0001)
  3. ADR-0003 Renderer and tube render route         Proposed (requires 0001, 0002)
  3. ADR-0005 Sensor source and input pipeline       Proposed (requires 0001, 0002)
Next
  4. ADR-0004 Map Loader and MapConfig               Proposed (requires 0002, 0003)
  4. ADR-0006 Android platform integration           Proposed (requires 0001, 0002, 0003, 0005)
Then
  5. ADR-0007 Persistence implementation             Proposed (requires 0001, 0002, 0006)
  5. ADR-0008 Hazard, collision, content format      Proposed (requires 0002, 0003, 0004)
Last
  6. ADR-0009 Test framework and CI                  Proposed (requires 0002, 0004, 0007, 0008)
```

- No dependency cycle.
- ⚠️ Every ADR from 0002 to 0009 depends on at least one ADR that is still Proposed, so none can be "safely implemented" under the skill's rule.
- Back-reference omissions (minor): ADR-0002 "Enables" omits ADR-0006 and ADR-0008; ADR-0003 "Enables" omits ADR-0004 and ADR-0006.
- ADR-0005 forward-references ADR-0011 (`mouse_behavior_recursive`), which does not exist.

### Process finding P-1 (High): Accepted vs spikes deadlock
- The Technical Director condition (architecture.md header): no implementation until ADR-0002 to ADR-0009 are Accepted.
- ADR-0003: "the decision stays Proposed until R-1 passes" (an on-device measurement). ADR-0009: spike T-1 needs `project.godot` first. ADR-0006, ADR-0007: PS-1/PS-2/PS-4/PS-12, SP-1/SP-2/SP-3 are device spikes.
- A spike is code, so the condition cannot be met as written.
- Recommendation: spikes are throwaway builds under `prototypes/` (already isolated from `src/` by the git workflow) and are explicitly allowed before Acceptance; an ADR is Accepted on the Technical Director's review with its spike listed as a **validation gate on the first dependent story**, not as a precondition of Acceptance. If the TD prefers to keep R-1 as an Acceptance precondition, say so in ADR-0003 and exempt `prototypes/`.

---

## Engine Compatibility

Engine: Godot 4.7.2.

- ADRs with an Engine Compatibility section: **9 / 9**.
- Version consistency: all 4.7.2, no stale reference.
- Deprecated APIs (`deprecated-apis.md`): none used. ADR-0004 uses shallow `Resource.duplicate()` on scalar-only `TubeConfig` and `EnvConfig`, which is the permitted case (the deprecated pattern is `duplicate()` on *nested* resources); the hazard-resource ban in ADR-0008 and the lint scope must stay class-scoped so the two do not collide.
- Post-cutoff APIs, no contradiction between ADRs: depth fog (ADR-0003), Shader Baker 4.5, MSAA, `Input.get_gravity()` (ADR-0005), 16 KB pages and edge-to-edge (ADR-0006), `FileAccess.store_*` returning `bool` (ADR-0007, avoided), `duplicate_deep()` (banned), `@abstract` (avoided, plain base classes).
- **Needs verification, not in the reference** (all carried as spikes): Mobile fog and draw calls (R-1), `emulate_mouse_from_touch` behaviour, lifecycle on Vulkan and Back on SDK 36 (PS-1, PS-2, PS-4, PS-12), `DirAccess.rename_absolute` overwrite (SP-1), `RandomNumberGenerator` portability, GUT on 4.7.2 (T-1), typed-array `.tres` round trip in an export, and `mouse_behavior_recursive` (the property name is not in `modules/ui.md`).
- Reference gap: `docs/engine-reference/godot/modules/` stops at 4.6 and has no module for `ResourceLoader`, `ConfigFile`, `FileAccess`, `DirAccess` or Android export. Add entries as each spike verifies a behaviour.

### Engine Specialist Findings
Not run. The skill asks for a `godot-specialist` second opinion after the audit. All eight ADRs already record a specialist review (ADR-0003 also the shader specialist), and this session does not spawn agents unless asked. Re-run on request.

---

## GDD Revision Flags (Architecture → Design Feedback)

Flags, not blockers: each takes effect when its ADR is Accepted (the ADRs list the same edits as follow-ups). Systems-index statuses are **unchanged** (user decision, 2026-10-03).

| GDD | Assumption | Reality (ADR) | Action |
|---|---|---|---|
| pattern-difficulty.md CR9, F2c, ACs | opposing-only read history | every read incl. Spikes, spacing and clearance (ADR-0008) | design review |
| obstacle-system.md F5, hazard_bound, TR-010 | preflight "across the library"; deep copy | P1 to P3; shared immutable spec; typed footprint (ADR-0008) | revise |
| save-persistence.md F2, AC-10, CR2 | log once per key; "seven seams" | once per load; one facade plus three Callables (ADR-0007) | revise |
| settings-accessibility.md CR5 | write on every change | sliders commit on `drag_ended` (ADR-0007); Menus already commits on release | revise |
| menus-screen-flow.md Rule 8, Rule 9, UX spec | failure on timeout; fade-in before the phase change | `map_load_failed`; cover opaque on the transition tick (ADR-0004, architecture.md) | revise both |
| platform-services.md | no `haptics_intensity` setter; PAUSED/RESUMED wording | `set_haptics_intensity`; ignored (ADR-0006) | revise |
| camera.md | "published at map load" | derived by `CameraMath` at composition (ADR-0004) | wording |
| tube-track.md R9 | every frame | see C-1 | none if ADR-0003 is aligned |
| design/gdd/systems-index.md | no row for Composition Root, Map Loader | defined in ADR-0002, ADR-0004 | add 2 rows |
| `.claude/docs/technical-preferences.md` | Forward+, GUT unlisted | Mobile (ADR-0003), GUT pinned (ADR-0009) | edit after Accepted |

**Status risk.** Camera, Juice, Environment, Settings and Menus are still "Designed, pending independent `/design-review`". ADR-0004 (`EnvConfig`, Camera values) and ADR-0003 (fog, chroma) were written against GDDs that a review may still change.

---

## Architecture Document Coverage

- Systems with a GDD and an index row appear in architecture.md: 16 / 16.
- **Playtest Telemetry** (index row 21, MVP, Not Started, no GDD) is absent from architecture.md and from every ADR. It is an MVP system; it needs a GDD (or an explicit demotion) before the MVP architecture is closed. It touches Save (file schema) and Run State (events).
- Orphaned architecture: **Composition Root** and **Map Loader** exist in architecture.md and ADR-0002/0004 but have no systems-index row (decided 2026-10-02 to be ADR-defined; the two rows are still to be added).
- architecture.md needs a v1.1 pass (see Document drift above).

---

## Verdict: CONCERNS

No blocking cross-ADR conflict, no cycle, 82% of architecture-relevant requirements covered, 9 of 9 ADRs carry an Engine Compatibility section.

### Blocking issues before coding starts
1. **P-1:** resolve the Accepted-versus-spike deadlock (TD decision).
2. ADR-0002 to ADR-0009 are still Proposed (TD condition).
3. **G-1:** the hazard render route must be decided before the Obstacle and Environment epics (not before the Foundation epics).

### Required ADRs (most foundational first)
1. Hazard render route and view node tree (new, not in the architecture.md list)
2. ADR-0011 UI architecture
3. ADR-0012 Ball material and world chroma
4. ADR-0010 Presentation time, hit-stop, Ink cover (decided in architecture.md; ADR not written)
5. ADR-0013 Distance precision
6. Audio policy (deferrable)

### Small edits (no new session needed)
C-1 to C-5, architecture.md v1.1, two systems-index rows, ADR back-references.

---

## Pre-gate checklist

| Item | State |
|---|---|
| `tests/unit/` | ✅ |
| `tests/integration/` | ❌ run `/test-setup` after ADR-0009 is Accepted |
| `.github/workflows/` CI | ❌ `/test-setup` |
| `design/accessibility-requirements.md` | ❌ `/ux-design` |
| `design/ux/interaction-patterns.md` | ✅ |
| `project.godot` | ❌ (needed for spikes T-1 and R-1) |
| `docs/architecture/control-manifest.md` | ❌ `/create-control-manifest` after Acceptance |

Re-run `/architecture-review` after each new ADR and after the GDD follow-up edits.
