# HUD — Design Review Log

## Review — 2026-10-01 — Verdict: NEEDS REVISION (resolved same session; lean re-review pending in a fresh session)
Scope signal: M
Specialists: game-designer, ux-designer, ui-programmer, qa-lead, accessibility-specialist, creative-director
Blocking items: 9 | Recommended: 8 | Nice-to-have: several (moved to Open Questions)
Summary: First full-mode pass. The core (a read-only reflection layer with one owned control) fits Pillars 1 and 4
and was kept. The blockers were contract drift against Approved upstream docs and an underspecified live
personal-best moment: (1) Rules 6/7 and AC-6 forwarded Hit taps while `valid` was false, contradicting
`tilt-input.md` Rule 10 (a user decision) and `run-state-restart.md` Core Rule 14 (verified in both files);
(2) that fix leaves Hit with no Menu path on a platform without a Back key; (3) handler signatures did not match
Run State's real payloads (`run_ended(run_id, hazard_id, run_time_ms)`, `menu_requested(press_us)`), and
fixtures used floats against Scoring's `int` contract; (4) `personal_best_passed` was self-contradictory
(Rule 2 vs Visual/Audio), had no handler or AC, and left a stale BEST beside a higher score; (5) no
`on_tap(press_us)` or outbound sinks, so AC-19 had nothing to spy on; (6) the countdown accumulated HUD `dt`
against Run State's own clock; (7) the banner had no defined life on the abandon path; (8) AC-20..23 were
"deferred, no owner/date", the pattern `coding-standards.md` does not allow; (9) the pre-run sensor cue was
rendered by both HUD and Menus.
Disagreements adjudicated by the creative-director: accessibility-specialist's AccessKit spec (BLOCKING) and
countdown extension were deferred to `/ux-design` and Run State as Open Questions (AccessKit behaviour on 4.7 is
unverified; the countdown is Run State's); ui-programmer's full render-layer contract was downgraded to one
obligation (the view kills the banner tween on reset); persistent state chosen over a one-shot flash for
`personal_best_passed`; HUD-1 reclassified as an on-device Integration check because it has a numeric threshold.
**Resolution (same session, 2026-10-01):** user decisions: (D2) a small round HUD Menu button in Hit while `valid`
is false; (D3) persistent `NEW BEST` pill state, no haptic; (D4-D7) BEST pill hidden while the stored best is 0
and no cue on a tie, banner in a fixed top-centre zone cleared on `run_reset` or a phase change to Menu, HUD
declines `milestone_crossed`, sensor-lost recovery hands off to Menus' Paused screen with no confirmation. All 9
blockers applied; the Acceptance Criteria section was rewritten (AC-1 to AC-22, HUD-2), with lints demoted to
ADVISORY. File 57,546 -> 49,524 bytes. Cross-file edits: `scoring-personal-best.md` (Open Question 11 resolved),
`menus-screen-flow.md` (Hit row names HUD's Menu button).
**Known consequence, user to confirm:** because the transition that ends an abandoned run also clears the banner,
the banner is effectively Hit-only; this reverses the 2026-09-30 decision that it shows on abandon too. Scoring's
HUD Interactions row still says "always shows" and its `milestone_crossed` row still reads "provisional"; both
are unedited. Run State needs an F5 read accessor, and its note that the *last* digit is shorter looks wrong
(`ceil(remaining)` makes the first one shorter); both are in Open Question 7.
**Stopping rule (creative-director):** one revision pass; new findings in the re-review block only if they
contradict an upstream doc or make an AC untestable; lean re-review; hard cap of 2 passes, after which leftovers
go to the user as decisions.
Prior verdict resolved: First review
