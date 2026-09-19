# Gate Check: Concept → Systems Design

**Date**: 2026-09-19
**Review mode**: lean (director panel run)
**Verdict**: CONCERNS (first run FAIL, re-run after fixing the blocker)

## Run history
1. **Run 1 — FAIL.** Visual Identity Anchor missing (artifact and quality check); art director NOT READY.
2. **Fix.** User chose the "Quiet World, Loud Hazards" direction; the section was added to `design/gdd/game-concept.md`.
3. **Run 2 — CONCERNS.** Artifact checks re-run; only the art director was re-asked (creative, technical and producer verdicts were unaffected by the visual section and were carried over).

## Required Artifacts: 3/3
- [x] `design/gdd/game-concept.md` exists with content
- [x] Game pillars defined (in the concept doc)
- [x] Visual Identity Anchor section exists
- Recommended: [x] Concept prototype REPORT.md with PROCEED verdict

## Quality Checks: 4/4
- [x] Concept reviewed (`/design-review` NEEDS REVISION, resolved and accepted; not MAJOR REVISION)
- [x] Core loop described
- [x] Target audience identified
- [x] Visual Identity Anchor has a one-line rule (1) and 3 supporting principles

## Director Panel
| Director | Verdict | Key points |
|----------|---------|------------|
| Creative | CONCERNS | Pillar 1 has no quantified rule for hidden-side obstacles; occlusion deaths break "I know what I did wrong"; shield booster conflicts with Pillar 2. Nothing blocks decomposition. |
| Technical | CONCERNS | Concept says spline tube, prototype validated a straight tube; tilt input unvalidated and `input.md` pinned to 4.6; mobile budgets lack target devices; GUT vs gdunit4. |
| Producer | CONCERNS | No weekly hours stated; Vertical Slice tier ordering contradicts Next Steps; tilt is the top early risk; hand-placed vs procedural obstacles unresolved; motivation risk unmitigated. |
| Art (run 2) | CONCERNS | Anchor adequate for this gate. Gaps: no saturation tier for ball, collectibles, boosters, HUD; "sense of speed" unaddressed with a static tube; death-cause visual treatment has no owner; art bible must precede the obstacle-system GDD. |

## Blockers
None.

## Conditions to carry into Systems Design
Verified against files unless marked.
1. Decide straight vs spline tube first (concept lines 74, 237 say spline; prototype is straight).
2. Decide the Pillar 1 rule for hidden-side obstacles / death-cause visual treatment before the obstacle-system GDD.
3. On-device tilt spike before any tilt Tuning Knobs are written (`input.md` has no accelerometer content).
4. Reconcile the Vertical Slice tier (line 307) with Next Steps (line 320).
5. State weekly available hours in the concept doc.
6. Decide hand-placed vs procedural obstacles during `/map-systems` (not verified independently).
7. Extend the anchor: saturation tier for ball, collectibles, boosters, HUD; add a motion-cue allowance for "sense of speed".
8. `/art-bible` is a hard prerequisite before the obstacle-system GDD or any obstacle silhouettes.
9. Resolve GUT vs gdunit4 before Technical Setup.
10. Not independently verified: mobile budget gaps (target devices), endless-track streaming, attach a mitigation to the motivation risk.
Not a real contradiction: tier sums (11–19 weeks) vs "about 3–4.5 months" is rounding only.

## Chain-of-Verification
5 questions checked (3 with file searches) — verdict unchanged (CONCERNS). The former FAIL conditions are resolved with evidence (section present, art director no longer NOT READY). The concerns together are a front-loaded decision list for the start of Systems Design, not a prerequisite for starting it. Creative, technical and producer were not re-run.

## Stage
`production/stage.txt` unchanged pending the user's decision.
