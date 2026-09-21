# Review Log: tube-track.md

## Review — 2026-09-20 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, performance-analyst; creative-director (senior)
Blocking items: 9 | Recommended: 9
Summary: The GDD was structurally complete (8/8 sections) and its core math checked out, but
the review found a proportion problem: heavy machinery (render-origin rebase, float precision)
for effects the player never perceives, while the promised feeling of speed had no owner, no
contrast floor and no test. Main defects: an undefined `s_origin` reset and a rebase with no
mechanism, an update-order rule that contradicted the Dependencies table, knob ranges that
broke F3/F4 when L varied, acceptance criteria that failed as written (AC-3, AC-7, AC-14/15,
AC-19, AC-23), no API shape or signals for testability, a comfort risk from a 14.7 Hz seam
pattern, and a Pillar 2 claim with no formula behind it.
Prior verdict resolved: First review

### Resolution (2026-09-20, same session)
All 9 blocking items and the recommended items were addressed in one revision pass.
Design decisions taken by the user:
- Rebase removed from the MVP (ball keeps running along the static tube; precision warning at
  s = 16384; treadmill named as the fallback).
- Hard visibility rule: F / v_max >= 1.5 s, checked when a map loads (new F9).
- Priming is a synchronous `begin_run()` operation, not a state.
- `TUBE_RADIUS` safe range narrowed to 2.5-3.3 (facet gap at most 2% of ball diameter).
Decisions taken from the review without a separate question: `advance(s)` with one caller,
logical segments (rendering choice moves to an ADR), integer `n_seams` with a seam frequency cap
of 8.5 Hz, a seam contrast band and a reduced-motion hook, `Frozen` split into Paused and Ended,
`window_primed` and `state_changed` signals, and a `RefCounted` logic core with an injected
log sink.

Specialist disagreements recorded: rebase (treadmill vs raised threshold vs removal) was
resolved by the user; segment rendering was moved to an ADR; `v_max = 25` is kept as an
unvalidated external contract. The main review's premise that F5 "proves rebase is
unnecessary" was partly wrong (F5's own 8-ulp model gives 3.9 mm at s = 7500); the removal is
justified by cost and by the 2-ulp pixel model, and Open Question 13 keeps an on-device check.

Not yet re-reviewed. Run `/design-review design/gdd/tube-track.md` in a fresh session.

---

## Review — 2026-09-20 (second review) — Verdict: NEEDS REVISION
Scope signal: L for implementation; the revision itself was M
Specialists: game-designer, systems-designer, qa-lead, godot-specialist (ran the real 4.7.2 binary), technical-artist; creative-director (senior)
Blocking items: 12 | Recommended: about 25 (deferred ones tracked in Open Question 17)
Summary: The 9 prior blockers were confirmed fixed and the arithmetic of F1, F3 and F5-F9 and of the window
ACs recomputed correctly (F1 and the AC-3/4/5 constants were also run on the binary). The new findings: F9 divided the
largest fog end (99.9% opaque, not the readable distance, and not the fog at `v_max`) by `v_max`, so the Pillar 2
claim was not supported; seams at 8.33 Hz with a contrast ceiling of 1.5 exceeded the WCAG flash threshold of 3
flashes per second, and a darker seam would have broken the art bible's 4:1 and 3:1 object floors; the 99.9% fog claim is
false at Godot's default `fog_density` 0.01; a function named `wrap` does not parse in GDScript; validation let NaN
through; and several ACs were unpassable, knife-edge or unobservable (AC-12, AC-17, AC-18, AC-20, AC-22, AC-23).
Prior verdict resolved: Yes (2026-09-20, first review: NEEDS REVISION, 9 blockers)

### Resolution (2026-09-20, same session)
All 12 blockers were addressed in one revision pass with a spec freeze (the same discipline as Run State: blockers
only, everything else in Open Question 17). Backup of the pre-revision file:
`production/session-state/tube-track.before-r2.md.tmp` (gitignored; keep until the GDD is committed).
Decisions taken by the user: seam frequency capped at 3 Hz (`SEAM_HZ_MAX` 3, range 2.1-3.0, default `n_seams` = 1
at L = 12, one seam per 12 u); F9 moved to `F_read` (an external contract from Environment & Theming, provisional
guess 40, `T_VIS_MIN` 1.5 s kept) and the header changed from "Implements" to "Supports" Pillar 2.
Rulings from the creative-director applied without a separate question: F4's `2^14` is an exclusive bound (only the
prose and AC-15 were wrong: warn at `s >= 16384`); seams are lighter than the tube and the ceiling comes from the
object-on-seam floors; the "after Mood 3 compression" clause was dropped (the art bible changes chroma only);
`seam_contrast_scale` may reach flat (reduced motion outranks the speed cue); `fog_density = 1.0` is a validated
`MapConfig` contract; `wrap` renamed `wrap_angle`; every numeric input is finite-checked and range-checked as
`not (x >= lo and x <= hi)` with stable failure codes; F8 clamps with the shared `t_lat`; AC-12, 15, 17, 18, 20, 21-23,
26 (split in a headless part and a pixel part), 27 and 28 rewritten; the `TubeMath` log callable and the
`slot_binder` added to the seam; the Tube Track state machine is stated to be the window lifecycle, not the run phase;
`state_changed` only when the state changes; `DT_MAX` ownership now says "settled in the Ball Movement GDD"
(as Run State does); "Foundation" became "Core".

Specialist disagreements recorded: F4 (main review and godot-specialist said "off by one binade"; the other three said the
bound is right, only the prose and AC-15 are off by one value; the creative-director sided with the latter and
the main review withdrew its claim); proportionality (game-designer wanted the state machine, the F4 warning and the
seam apparatus cut; systems-designer and qa-lead reviewed them as needed; the creative-director kept them and the 3 Hz
cap shrinks the seam section); reduced-motion floor (technical-artist wanted a 0.5 floor; the creative-director ruled
flat must be allowed); flash safety (3 Hz cap versus a 0.10 luminance-step cap with an accessibility review; the user
chose the cap); F9 (fix the metric now versus wait for Environment & Theming and Camera; resolved as the minimum
honest revision with no invented numbers); AC-22 (dt = 1/64 with exact index arithmetic, not a +-1 tolerance).

Caveats to remember:
- The claim that thin seam stripes might fall under WCAG's area criterion was raised and not verified; the 3 Hz cap
  makes it moot at the cost of a much sparser speed cue. AC-27 (the on-device seam A/B test) is now the check on that
  cost.
- `F_read` = 40 is a guess; its real value needs Environment & Theming and Camera (`T_reveal`).
- godot-specialist could not confirm a SurfaceTool route to flat normals, and did not run the seam shader, MultiMesh
  culling or an on-device draw-call count. The engine facts verified here (Vector3 is 32-bit, depth fog opacity equals
  `fog_density`, `wrap` collision, `class_name` needs an import pass) are not yet copied to `docs/engine-reference/`.
- `tests/unit/tube_track/test-plan.md` does not exist yet (Open Question 17).

Not re-reviewed after this revision.

---

## Review — 2026-09-20 (third review) — Verdict: NEEDS REVISION
Scope signal: L for implementation; the revision itself was M
Specialists: game-designer, systems-designer (hand-computed, Bash disabled), qa-lead, godot-specialist (ran the real 4.7.2 binary; needed one resume after hitting its turn limit), technical-artist; creative-director (senior)
Blocking items: 6 (merged from about 20 specialist blockers) | Recommended: about 40 (all moved to Open Question 18)
Summary: The 12 prior blockers were confirmed fixed and the arithmetic of F1-F8, the F3 table, the state counts and AC-21/22 recomputed
correctly (several on the binary). The blockers are concentrated in the two areas review 2 knowingly left provisional. F9 treated
`F_read` as measured from the ball while Godot fog is radial from the camera eye (overstating `T_vis` by 0.32 s against a 0.15 s margin),
and its "4:1 after fog" criterion is unachievable (hazard/tube 4.17 against 4:1 leaves about 4% headroom, so the 40/48 defaults were a
fog wall). The seam contrast ceiling's rationale was backwards (hazard, ball and pickup are darker than the tube, so a lighter seam only
raises the object-on-seam ratios). AC-12's `NO_VALID_F` row was not empty at its inputs, L 6-8 could never load under the 3 Hz seam cap,
`slot_binder` was not implementable as written, and AC-27 could pass with seams adding nothing.
Prior verdict resolved: Yes (2026-09-20, second review: NEEDS REVISION, 12 blockers)

### Resolution (2026-09-20, same session)
All 6 blockers were addressed in one revision pass with a spec freeze (everything else in new Open Question 18). Backup of the
pre-revision file: `production/session-state/tube-track.before-r3.md.tmp` (gitignored; keep until the GDD is committed).
Decisions taken by the user: idle scroll kept (only rule 11's wording fixed); AC-27 gets both a numeric on-minus-off margin (at least 6
correct of 48, 20% speed delta) and a downgrade of the Player Fantasy speed claim to a hypothesis; the F9 readable criterion is handed to
Environment & Theming and the art-director and F9 stays a budget with a provisional input; the 3 Hz seam cap is left as decided and a
conditional cap is routed to Open Question 11 for the accessibility-specialist.
Rulings from the creative-director applied without a separate question: `F` and `F_read` are radial from the camera eye and
`T_vis = (F_read - d_cam) / v_max` with `d_cam` published by Camera; the fog fields (`fog_mode`, `fog_depth_begin`,
`fog_depth_curve`) join the `MapConfig` contract and validation (new codes `FOG_MODE`, `FOG_RANGE`); `T_VIS_MIN` floor 1.35; the
`SEAM_CONTRAST_MAX` 1.5 ceiling is stated as a guess and the vacuous AC-26a clauses are removed (AC-26a becomes an advisory smoke
check); derived floor `L_min = ceil(v_max / SEAM_HZ_MAX)` instead of allowing zero seams; `advance(s)` with an unchanged `s` is a
silent no-op in Running only; AC-12 rewritten as a table of exact code sets with stated reporting rules (new code `A_OUT_OF_RANGE`);
`slot_binder(slot_index: int, segment_index: int)`; AC-19's ordering clause, AC-23's dangling reference and AC-29's object counts fixed;
`nextafter` (absent in GDScript 4.7.2) replaced by the literal 11.999999999999998.
Side effect to remember: the default `F_read` moved from 40 to 46 so that `T_vis` stays at least 1.5 s with `d_cam` = 8; with `F` = 48
that is a 2 u fog ramp, flagged as a placeholder (Open Question 10).

Specialist disagreements recorded:
- WCAG flash threshold: the game-designer read the 1.15 floor (luminance step 0.08) as below WCAG's 0.10 and the 3 Hz cap as over-buying
  safety; the technical-artist read it as 14% / 36% of the pair's maximum and the cap as needed; the creative-director computed
  0.081 at the floor and 0.267 at the ceiling, called both directionally right, kept the cap as a safe over-buy and routed a conditional
  cap to the accessibility-specialist. The user chose to leave the cap.
- Fog fix: `T_FADE_MIN` / `FOG_WALL` validation (game-designer) and F of about 65 with A = 7 (technical-artist) were rejected as inventing
  numbers in Environment & Theming's domain; the fade-time test is recorded in Open Question 10.
- Idle-scroll wrap: the game-designer wanted it cut as blocking; downgraded (Open Question 16 already owns it), and the user kept it.
- `advance(s)` in any loaded state as a no-op (game-designer) versus Running only: Running only, so the Running-only contract that AC-19
  tests survives.
- Proportionality (game-designer): the earlier ruling held narrowly; F4, `S_PRECISION_LIMIT` and AC-15 are over-built for one debug
  warning and Open Question 13's device check will promote or collapse them.

Caveats to remember:
- The technical-artist's fog-curve and SurfaceTool statements were from memory; the godot-specialist verified the fog formula and radial
  metric on the binary (Forward+ only; the Mobile renderer was not re-run). SurfaceTool flat normals were not verified.
- The systems-designer's arithmetic was by hand; the new AC-12 rows, `L_min`, F9 examples and A values were re-run in a script after the
  revision and matched.
- The `F_read` = 46 / `F` = 48 defaults, `d_cam` = 8 and the seam contrast band are guesses.
- The verified engine facts (depth fog formula, no `nextafter`, deferred signal connections, and others) are listed in Open Question 18
  but are not yet copied into `docs/engine-reference/godot/`.
- `tests/unit/tube_track/test-plan.md` does not exist yet.

Not re-reviewed after this revision. Run `/design-review design/gdd/tube-track.md` in a fresh session (after `/clear`).

---

## Review — 2026-09-20 (fourth review, lean) — Verdict: NEEDS REVISION, then Approved after revision
Scope signal: L for implementation; the revision itself was S
Specialists: none (lean depth, single-session analysis; arithmetic recomputed in Node)
Blocking items: 1 | Recommended: 4 (3 applied, 1 left in Open Question 18) | Nice-to-have: 3
Summary: All 6 blockers of review 3 were confirmed fixed (F9 radial and `d_cam`, the seam ceiling rationale, the AC-12
`NO_VALID_F` row, `L_min`, `slot_binder`, AC-27 margin), and F1-F9, the F3 table, the 16-of-40 transition count and AC-1/8/9/21/22
recomputed correctly. One new blocker: the Idle window lifecycle was unspecified (`load_map()` and `to_idle()` had no stated effect on
the window, slots or `window_primed`, though rule 11 has the tube scrolling in Idle and AC-8/19 assume a window exists).
Prior verdict resolved: Yes (2026-09-20, third review: NEEDS REVISION, 6 blockers)

### Resolution (2026-09-20, same session)
The blocker was addressed in one revision pass with a spec freeze. Backup of the pre-revision file:
`production/session-state/tube-track.before-r4.md.tmp` (gitignored; keep until the GDD is committed).
Design decision taken without a separate question (it follows from `window_primed` being a reset and `begin_run` already priming
`-B .. A`): `load_map()` and `to_idle()` are synchronous like `begin_run()`: `s_idle = 0`, the run's `s` discarded, N binder calls,
`window_primed(-B, A)`, then `state_changed`; the Idle window never moves. New AC-20a. Also fixed: the Player Fantasy line about
"world contrast compresses" (Mood state 3 drops chroma only; removed from Open Question 18), a stale index sentence, an AC-27 power
note (simulated 35-55% pass rate at the margin), and Open Question 9 now covers the run-to-menu seam-phase jump.
Approved by the user on 2026-09-20 without a further re-review. `systems-index.md` marked Approved.

Left open on purpose (Open Question 18): validation codes for the config's own knobs, F3's `v_max * t_lat` term (appears redundant
under synchronous recycling; relabel as spawn-spread margin or drop), the `relief` fuzz at 0.08, and the art and Tests items.
Still provisional: `F_read` = 46, `d_cam` = 8, `v_max` = 25, the seam contrast band, the 3 Hz cap (Open Questions 10-14).

Caveats to remember:
- AC-20a and the Idle window rule were not run against an implementation; there is no code yet.
- The AC-27 power figure is a Monte Carlo estimate (200,000 runs per case), not a derivation.
- Still not done: engine facts copied to `docs/engine-reference/godot/`, `tests/unit/tube_track/test-plan.md`, art-director notice of
  art bible Section 2 changes, `/consistency-check` for Tube Track and Run State.

---

## Amendment — 2026-09-20 (post-approval, art-director advisory rulings) — Verdict: unchanged (Approved)
Not a review. After approval, an art-director advisory pass (read-only, no files written by the agent) covered the art bible
Section 2 changes and the open art items in Open Questions 10 and 18. The user chose which rulings to apply:
- **Applied to `design/art/art-bible.md` (Section 2 only):** "one continuous loop", the 1 s measured from the touch-down of the tap
  (also in the Never varies list), Mood state 3 changes chroma only (about 12%, x0.88, value unchanged), "contrast compression"
  replaced by "world desaturation" in the Section 2 intro. Section 3d was not edited: "relief of at most 0.1D" still allows zero relief.
- **Applied to `tube-track.md`:** `SEAM_CONTRAST_MAX` 1.5 to 1.25 (bound by seam luminance below the map's darkest sky, Haze Top 0.635,
  and by the rim-white ring staying readable, 1.47 at 1.25 against 1.22 at 1.5); seams are a flat shading band with no geometric
  relief, so `relief`, `SEAM_RELIEF` and the `RELIEF` failure code were removed (rule 9, knobs, map validation, AC-13, Visual
  requirements); AC-26a gained the sky clause; Open Question 18 items updated (WCAG step 0.135 at the ceiling, relief resolved).
- **Not applied:** the F_read two-tier floor (fogged hazard/tube about 2.5-3:1) and fade rule `(F - F_read) / v_max` at least 0.75-1.0 s,
  which would move `F` to roughly 65-70 u; recorded in Open Question 10 as a recommendation for Environment & Theming, no default changed.
Caveats: the agent did not read the Run State GDD; its figures are hand-checked estimates (the luminance ratios were rechecked here);
a normal tilt on a flat-shaded faceted tube is unverified (technical-artist, Open Question 17); everything needs a device check.
