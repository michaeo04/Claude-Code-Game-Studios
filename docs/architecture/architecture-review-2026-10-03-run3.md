# Architecture Review Report (run 3)

Date: 2026-10-03 (third run, fresh session)
Mode: full (`/architecture-review`), delta review
Engine: Godot 4.7.2, GDScript, Android only (ADR-0001)
GDDs reviewed: 16 system GDDs through the 348-requirement baseline. Only `menus-screen-flow.md` (Core Rule 9, AC-13) and `design/ux/menus-screen-flow.md` (Transitions) changed since run 2 (commit f15f7e9); both edits were checked against ADR-0010.
ADRs reviewed: 13 (ADR-0001 Accepted; ADR-0002 to ADR-0012 and ADR-0014 Proposed)
Previous runs: `architecture-review-2026-10-03.md`, `architecture-review-2026-10-03-rerun.md`

**Method note.** ADR-0010 was read in full. Each of its claims was checked against ADR-0002 (per-frame order, rank table, decision 10), ADR-0003 (decisions 2 and 7), ADR-0011 (layers, Open Question 2), ADR-0012 (`BallView` interface, grey-out), the registry (`docs/registry/architecture.yaml`), `architecture.md` Data Flow, and the Juice, Camera, Menus, Run State, Tube Track and Ball Movement GDDs. The engine-specialist second opinion of Phase 5 was **not run** (as in runs 1 and 2); ADR-0010 carries a `godot-specialist` review from its authoring session ("no blocking finding").

---

## Traceability Summary

| Status | Run 2 | This run | Share |
|---|---|---|---|
| ✅ Covered | 172 | **174** | 91% |
| ⚠️ Partial | 17 | **15** | 8% |
| ❌ Gap | 2 | **2** | 1% |
| ➖ GDD-owned (not counted) | 157 | 157 | n/a |

Architecture-relevant: 191. Total: 348.

**Partial to Covered (2):** TR-juice-feedback-007 (ADR-0010 Decision 3: hit-stop as a 0.20 s presentation hold on the stamp clock, early cut by `run_reset`, `hitstop_actual` injected), TR-menus-screen-flow-012 (ADR-0010 Decision 5: `InkCoverCore.covering()`, route predicate, no cut on Restart).

**Registry text revised (1):** TR-menus-screen-flow-012 now reads as the edited GDD (opaque on the tick of `phase_changed`, hold 0.05 s, fade-out 0.18 s or 0.30 s under reduced motion; cut on Menu to Running and Paused or Hit to Menu; none on Restart); `revised: 2026-10-03`. The ID is unchanged.

### Coverage Gaps (no ADR exists)

| Missing decision | TR | Domain | Engine risk | Suggested ADR |
|---|---|---|---|---|
| Distance precision at s = 16384 (t = 682 s): run cap or rebase | tube-track-017 | Core | LOW | `/architecture-decision distance precision` (ADR-0013) |
| Audio: three Juice cues, bus layout, OS audio policy owner | juice-feedback-016 | Audio | LOW | deferrable |

Full matrix: `docs/architecture/architecture-traceability.md`.

---

## Verified against ADR-0010 (no finding)

- Hit-stop 0.20 s equals `HITSTOP_MAX` (Run State F4, Juice Rule 3); `RESTART_LOCK` >= 0.45 s, so shard release always precedes a restart tap (Juice Rule 8 still covers the early case).
- Fairness validator inputs: `V_START` = 10 u/s (ball-movement Tuning Knobs), `s_first` = 11 (Juice examples, Ball Movement Rule 5), `T_REACT` = 0.25 s (Run State); 0.35 <= 11/10 - 0.25 = 0.85 holds. `N_present` = 3 (Run State F2) is consistent with `INK_HOLD_S` = 0.05 s at 60 Hz.
- Camera F5 equals `PresentationMath.ease_out_linear`; the FOV state is not in TR-camera-009's bit-identical set (`phi_cam`, position, `d_cam`), so `step` can stay a frozen no-op at `dt_eff <= 0`.
- Layer 30 and the STOP-blocker rule match ADR-0011 decision 2 and Decision 5; ADR-0011 Open Question 2 is correctly closed. The Menus GDD (Rule 9, AC-13) and UX edits match ADR-0010 word for word on routes and timings.
- Step numbers 3, 9 and 11 match `architecture.md` Data Flow (ADR-0002 itself lists the order without numbers).
- Draw calls: the cover adds 1 draw inside Menus 25 or HUD 20; the worst concurrent case (about 82) stays under 150.

---

## Cross-ADR Conflicts

No blocking conflict and no dependency cycle.

### C-13: ADR-0010 vs ADR-0012 and the registry (`BallView` setters) - Medium, Integration
- ADR-0010 Decision 3: at shard release `JuiceView` "hides the ball (`ball_visible_sink(false)`, a Juice-only Callable into `BallView`)"; `run_reset` restores ball visibility.
- ADR-0012 Key Interfaces: `BallView` has `set_luminance_target` (Environment only) and `set_rim_glow` (Juice only). Registry stance (`docs/registry/architecture.yaml`, ball material): the only writes are those two setters.
- Impact: a third write path into `BallView` with no owner row, no registry stance and no reset rule; the visibility could be set by `BallView.tick` or by Environment by mistake.
- Resolution: add `set_visible(v)` (Juice only) and its reset behaviour to ADR-0012 Key Interfaces and the registry; ADR-0010 keeps the Callable seam.

### C-14: ADR-0010 internal (`INK_HOLD_TICKS`) - Low
- Decision 5 says the hold ends at the later of `INK_HOLD_S` and `INK_HOLD_TICKS` = 3 ticks. The knob is absent from `InkCoverConfig` (only `INK_HOLD_S`, `INK_FADE_S`, `INK_FADE_REDUCED_S`), `PresentationMath.fade_out` takes seconds only, and `InkCoverCore` has no `tick()` to count ticks (`alpha()` only reads the clock).
- Resolution: add `tick()` and the knob (range and default) to Key Interfaces, or drop the tick rule and rely on `INK_HOLD_S`.

### C-15: ADR-0010 vs Juice GDD (frames versus the stamp clock) - Low
- Juice GDD: the Hit flash is "at most 2 frames" and the grey-out crossfade is 1 to 2 frames (ADR-0012). ADR-0010 puts both on the stamp clock but defines no duration in seconds, so the length differs between 60 and 120 Hz and after a stall.
- Resolution: add `HIT_FLASH_S` and `GREY_CROSSFADE_S` (about 0.033 s) to `JuiceConfig`, or state that these two are tick-counted.

### C-16: ADR-0010 vs ADR-0003 Decision 2 and ADR-0009 (uniforms, lint) - Low
- ADR-0003: "the only dynamic shared uniform is `seam_contrast_scale`". ADR-0010 adds a per-event progress uniform in [0, 1] for event shaders (ring pulse, PB bloom and sweep); ADR-0012 adds two globals and the near-miss ball-position uniform is also missing from that sentence.
- ADR-0009's lint list lacks ADR-0010's rules: no `TIME` in `assets/shaders/**` and particle process materials, no `create_tween` or `AnimationPlayer` outside the ADR-0011 UI motion views, no presentation timer that adds `real_dt`, no `call_deferred`, Tween callback or `await` that moves the tube.
- Resolution: fold into the ADR-0003 amendment (with C-1, C-4, C-12) and the ADR-0009 lint additions.

### C-17: stale back-references and step numbers - Low
- ADR-0002 (lines 32, 219), ADR-0003 (line 207), ADR-0011 (line 253) and ADR-0012 (line 255) still say "future ADR-0010".
- ADR-0010 cites "step 9" and "step 11". The C-11 amendment inserts `BallView.tick` and the Idle step and shifts the numbers; cite step names.
- Resolution: edit the back-references; use step names in ADR-0010 and ADR-0011.

### Still open from runs 1 and 2
C-1, C-2 (in C-11), C-3 (in C-6), C-4, C-5, C-6 to C-12, architecture.md v1.1 drift (now also missing ADR-0010: `InkCoverCore`, `PresentationMath`, the route predicate).

### Noted, not a conflict
Restart (Hit to Running) gets no Ink cut (user decision 2026-10-03). Tube Track's seam phase is `fposmod(s, SP)`, so resetting `s` to 0 can shift it by up to `SP` at Restart as at Play. The ADR accepts this (world resets under the grey-out; PT-1 captures a Restart frame; response: add Hit to Running to `is_cut_route`).

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
```

- No dependency cycle. ADR-0010 refines ADR-0012 (grey-out crossfade) without a "Depends On" and changes none of its interfaces except the C-13 addition.
- ⚠️ Every ADR from 0002 to 0014 depends on at least one Proposed ADR.
- **P-1 (High, unchanged):** the Accepted-versus-spike deadlock still needs the Technical Director's decision. ADR-0010 adds device checks PT-1 to PT-4 (opaque first frame at 60 and 120 Hz, particle burst on Mobile, 5 s stall during Hit, tap-spam ledger); each needs `project.godot`.

---

## Engine Compatibility

- ADRs with an Engine Compatibility section: **13 / 13**. All state Godot 4.7.2.
- Deprecated APIs: none in ADR-0010.
- Post-cutoff APIs: none used. `GPUParticles3D.restart()` gained `keep_seed` in 4.4 and is called without arguments; the 4.7 particle angular-velocity change is a visual check in PT-2.
- **Not in the engine reference, carried as spikes:** the one-shot `GPUParticles3D` pattern (`visible = true`, `emitting = false`, `restart()` after `global_transform`) on Mobile; whether `CanvasLayer.visible = false` blocks GUI input (one assertion added to the ADR-0011 integration test); `ColorRect` cost when hidden. All earlier items (UI-1, UI-A1, R-1 additions, HV-1) stand.
- Reference gap unchanged: `modules/` stops at 4.6.

### Engine Specialist Findings
Not run (see Method note). Re-run on request.

---

## GDD Revision Flags (Architecture → Design Feedback)

New flags from ADR-0010 (the earlier flags stand). Systems-index statuses are **unchanged** (user decision, 2026-10-03, runs 1 and 2); each flag takes effect when its ADR is Accepted.

| GDD | Assumption | Reality (ADR) | Action |
|---|---|---|---|
| juice-feedback.md Rule 11, F1, AC-6 | the ledger holds seam, hit and ring flashes | each Ink cut also registers one entry through `flash_sink` (ADR-0010 Decision 7); the cut is never throttled | add the Ink cut to the ledger and to F1's budget |
| juice-feedback.md Rule 3, Visual table | "hitstop = world freeze 0.20 s"; flash "at most 2 frames"; grey-out crossfade 1 to 2 frames | the world freeze is the Hit phase (`dt_eff = 0`); hit-stop is a 0.20 s hold that delays only the shards; effects run on a stamp clock (C-15) | reword; define the durations in seconds |
| camera.md Rule 7, F5, AC-15 | `t` is "seconds since the call" with an ease state advanced by the caller | `t` comes from a `punch_us` stamp and the injected `clock_us`; the ease keeps running at `dt_eff = 0`; `CameraCore` gains `clock_us` | revise wording and AC-15 setup |
| tube-track.md Open Question 9, Edge Cases | the seam-phase jump is hidden at "Idle to Running" and `to_idle()` | cut routes are Menu to Running and Paused or Hit to Menu; Restart has none (accepted, PT-1) | note the Restart exception |
| run-state-restart.md Visual, F2 | Run State supplies only the timing contract | Ink cover hold = `N_present` frames; no Run State change | cross-reference only |
| menus-screen-flow.md Rule 9, AC-13 and UX Transitions | fade-in before the phase change | already edited in f15f7e9 to match ADR-0010 | none (done) |

---

## Architecture Document Coverage

- 16 / 16 GDD systems appear in architecture.md. Its Data Flow already records ADR-0010's decisions (Ink cut, hit-stop, FOV ease), edited in f15f7e9.
- architecture.md v1.0 still lacks the components of ADR-0010, ADR-0011, ADR-0012 and ADR-0014 in the module tables (`InkCoverCore`, `PresentationMath`, `HazardView`, `BallView`, `WorldChroma`, `UiScaler`, layer stack, the Phase B step). Add to the v1.1 pass.
- Playtest Telemetry (MVP, no GDD) is still absent from architecture and every ADR; Composition Root and Map Loader still have no systems-index row.

---

## Verdict: CONCERNS

91% of architecture-relevant requirements covered (up from 90%), no blocking conflict, no cycle, 13 / 13 ADRs carry an Engine Compatibility section.

### Blocking before coding starts
1. **P-1:** Accepted-versus-spike deadlock (TD decision).
2. ADR-0002 to ADR-0014 are Proposed (TD condition).
3. **C-6** and **ADR-0014 OQ1 (plinth span)** settled before the Obstacle view, Environment and Ball view epics.

### Required ADRs
1. ADR-0013 Distance precision.
2. Audio policy (deferrable).

### Small edits (one session, one amendment per ADR)
ADR-0002 (C-2, C-11, C-17), ADR-0003 (C-1, C-4, C-12, C-16, C-17), ADR-0004 (C-3 via C-6, C-8), ADR-0005 (C-7), ADR-0008 (C-5), ADR-0009 (C-16 lint rules), ADR-0010 (C-14, C-15, C-17), ADR-0011 (C-17), ADR-0012 (C-10, C-13, C-17), ADR-0014 (C-9, C-6), plus architecture.md v1.1, the back-references, and the Juice, Camera and Tube Track GDD edits above.

---

## Pre-gate checklist

| Item | State |
|---|---|
| `tests/unit/` | ✅ |
| `tests/integration/` | ❌ `/test-setup` |
| `.github/workflows/tests.yml` | ❌ `/test-setup` |
| `design/accessibility-requirements.md` | ❌ `/ux-design` (ADR-0011 requires it before the pre-production gate; ADR-0010's Ink cut counts as a named flash in it) |
| `design/ux/interaction-patterns.md` | ✅ |
| `project.godot` | ❌ (needed for every spike, including PT-1 to PT-4) |
| `docs/architecture/control-manifest.md` | ❌ `/create-control-manifest` after Acceptance |

Re-run `/architecture-review` after the amendment pass.
