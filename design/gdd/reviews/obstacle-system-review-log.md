# Review Log: obstacle-system.md

## Review — 2026-09-28 (first full-mode review) — Verdict: NEEDS REVISION, resolved same session
Scope signal: L (5 formulas, 3 hard upstream dependencies, 2 new ADR-adjacent items pending — producer to verify before sprint planning)
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, art-director; creative-director (senior) — full mode
Blocking items: 10 | Recommended: 9 (7 applied same session, 2 deferred — see below)

**Summary (creative-director synthesis):** the collision model itself (swept-AABB with a deliberate
no-tunnel bias, window-lifecycle binding, exhaustive-not-fail-fast preflight, F4b's distance-over-
segment floor, F5's joint-extreme non-degeneracy proof) is sound. The defects found were
containment (an unenforced hidden-content ban), calibration (an understated false-positive bound,
a wrong collar-percentage claim, a misdiagnosed Godot timing risk), and jurisdiction (two visual
proposals — the Near-Ring/Gate mapping, the hazard-colored shared plinth — asserted inside a
systems GDD rather than routed to art-director), not a structural design problem. Verdict:
**NEEDS REVISION, not MAJOR REVISION** — every blocking item was a correction, a new validator/AC,
or a jurisdictional handoff, resolved in hours within this same session.

Escalated separately to the user, outside this GDD's authority: Pillar 2 requires hidden-side
patterns to "repeat so they can be learned," but this promise is currently owned by no system
(Pattern & Difficulty and Camera both have no GDD; Open Questions 2 and 15 carry an owner but no
date). A systems-map gap, not an Obstacle System defect.

### Blocking items resolved this session
1. [game-designer, creative-director] Core Rule 8's hidden-side ban had no enforcement — added
   `HIDDEN_CONTENT_FORBIDDEN` preflight validator (Core Rule 8, Edge Cases, AC-36).
2. [systems-designer, creative-director] F2's false-positive bound was internally inconsistent
   (worked example/AC-5 tested 0.4 rad/3.0u while the variable table claimed 1.0 rad) — corrected
   to the true joint safe-range corner (1.0 rad / 7.5u); user decision: fix the numbers, keep
   `OMEGA_MAX`/`DT_MAX` safe ranges as-is (F2 Output range, worked example, AC-5 new second row).
3. [game-designer] Player Fantasy's absolute "every death is legible" claim walked back to name
   the bounded corner-cut exception explicitly.
4. [godot-specialist, creative-director] Core Rule 2's timing-risk mechanism corrected (Godot's
   fixed-physics-step catch-up / `max_physics_steps_per_frame`, not variable-refresh panels);
   AC-25 given an owner and date — user decision: gameplay-programmer, when Ball Movement's
   `dev-story` begins (new Open Question 16).
5. [qa-lead] AC-15's fixture had no theta values, so `hidden()` could not actually run — fixed to
   author all rows at `theta_center = PI`.
6. [qa-lead] Preflight-validator determinism had no test — added AC-37.
7. [qa-lead] No AC exercised non-default R/D — added AC-38 (F3's joint-extreme corner).
8. [systems-designer] F3's "94% to 76% collar" claim was arithmetically wrong — corrected to
   ~87% to 76% (an 11-point drop, not 18).
9. [art-director, creative-director] Near-Ring's worked example sits outside art bible §3b's
   stated Gate range — relabeled "family TBD (Open Question 5)" in the AC fixture table and
   Visual/Audio Requirements, rather than asserting Gate-family membership; no art-bible edit made
   without art-director.
10. [art-director, creative-director] The shared plinth's hazard-lethal coloring on a non-colliding
    element was flagged against the art bible's color-semantic contract (§4) and reframed as a
    request to art-director, not a settled choice.

### Recommended revisions applied this session
- [godot-specialist] Core Rule 7's Resource-mutation warning now requires `duplicate_deep()` /
  `CACHE_MODE_IGNORE`, not unqualified "duplicated instance."
- [godot-specialist] Cost/benefit reasoning for banning `CollisionObject3D`/`Area3D` now stated
  explicitly in Core Rule 2.
- [qa-lead] Core Rule 9 given a behavioral test (AC-39) alongside AC-24's static lint.
- [qa-lead] AC-24's code-review pairing now requires a recorded sign-off, not an assumed one.
- [art-director] Shared-plinth color caveat (folded into blocking item 10 above).
- [art-director] "No telegraph" LOD rule and Near-Ring/Gate-family caveat reframed as routing, not
  settled fact (folded into blocking items 9-10 above).
- [my own reading] Dependencies section's stale note about the run-state-restart.md cross-file
  edit (already applied, but described as "not made now") corrected.

### Recommended revisions deferred (not applied this session)
- [qa-lead] OS-1/OS-2's n=5 statistical thresholds — real but unactionable for a solo dev; noted,
  not changed.
- [art-director] Near-Ring's height ceiling — left as relative-only guidance pending Environment
  & Theming; no numeric value invented.

Prior verdict resolved: First review
