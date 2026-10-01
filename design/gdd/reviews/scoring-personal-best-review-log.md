# Scoring & Personal Best — Design Review Log

## Review — 2026-10-01 — Verdict: NEEDS REVISION (resolved same session; Approved by user decision without re-review)
Scope signal: S
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director
Blocking items: 4 | Recommended: 9 | Nice-to-have: several (moved to story notes)
Summary: Fifth full-mode pass (blockers 8 -> 4 -> 1 -> 1 -> 4). Core design (`floor(s)`, strictly-greater
comparison, `RefCounted`/DI core, near-miss exclusion) held unchanged. The creative-director found the rise
came from defensive prose and ACs added in passes 2-4, not from a worse design. Blockers: (1) the
decreasing-`s` guard had no defined comparison target or reset behavior, so a separate `last_s` would score
every run after the first as 0 (fixed: guard is `floori(s) < current_score`, no tracker, reset clears it);
(2) `MILESTONE_DISTANCES` had no injection path because Rule 7 closed the constructor at three seams, plus an
invalid `...` default and no consumer (user decision: fourth constructor data parameter, finite default, 1 u =
1 m); (3) the AC-11a assert check was untestable and `assert` is stripped from release builds (fixed:
static `validate_seams()`); (4) AC-20a and AC-23 claimed mutations that could not fail (fixed: boundary rows).
Disagreements adjudicated by the creative-director: qa-lead's fixture/wiring items and godot-specialist's
AC-11b item rated Recommended, not Blocking; godot-specialist's ConfigFile type gap judged mitigated by Save &
Persistence's type-mismatch fallback (not independently verified in this session); systems-designer's
plausibility cap on `s` rejected. User decisions: lint ACs (AC-10, AC-12b, typed-binding row, AC-19 scans)
demoted to ADVISORY CI lint, producer to confirm; `game-concept.md` Autonomy row edited (OQ10 resolved).
Stopping rule set by the creative-director: BLOCKING only for wrong player-visible behavior, an
implementation-blocking contradiction, or a BLOCKING AC that cannot run or fail; no sixth full pass.
Rules 5, 7, 11 and the Gate Policy were shortened and review-history commentary removed (file 96,952 -> 91,033
bytes). Cross-file edits: `game-concept.md` (Autonomy row), `systems-index.md` row 8.
**Approval caveat:** the user chose to mark the GDD Approved and skip the recommended lean re-review, so these
revisions have not been checked by a second reviewer.
Prior verdict resolved: Yes — fourth pass (1 blocker, logged below)

## Review — 2026-09-30/10-01 — Verdict: NEEDS REVISION (revised same session; re-review pending in a fresh session)
Scope signal: S
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director
Blocking items: 1 | Recommended: 8 | Nice-to-have: 2
Summary: Fourth full-mode pass (blockers 8 -> 4 -> 1 -> 1). Core design (`floor(s)`, strictly-greater comparison,
`RefCounted`/DI core, near-miss exclusion) held unchanged. The one blocker: Rule 7 promised construction "fails loudly"
on a bad seam, but `Callable.is_valid()` checks only liveness and method existence, not arity or return type
(qa-lead and godot-specialist converged independently). Resolved by narrowing the claim, citing the composition
root's statically-typed binding as the real guarantee, and adding a typed-binding row to AC-11a. Recommended items
applied: int64-range guard on `s` (F1, AC-15 row 4); "the moment I know" placed at the end-of-run banner (Section B)
with Open Question 8 reframed; OQ7 aligned to OQ6's owner and gate; AC-25 reworded as a tier correction, not a
Visual/Feel exception; empty `MILESTONE_DISTANCES` documented as valid (milestones disabled); AC-9 row for
consecutive `on_run_reset()`; `milestone_crossed` made a tracked commitment for `hud.md`/`juice-feedback.md`;
AC-11b reworded because `get_script_method_list()` inherited-member exclusion is unverified on 4.7.2. Nice-to-have
applied: Rule 12 wording softened; Section B notes the abandon path. No specialist disagreements; the
creative-director raised item 1 from Recommended to Blocking. Cross-file edits: none (`systems-index.md` row 8 only).
Prior verdict resolved: Yes — third pass (1 blocker, logged below)

## Review — 2026-09-30 — Verdict: NEEDS REVISION (resolved same session)
Scope signal: S
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director
Blocking items: 1 | Recommended: 10 | Nice-to-have: 3
Summary: Third full-mode re-review, run in a fresh session per the prior pass's own recommendation. Core
design (`floor(s)`, strictly-greater comparison, `RefCounted`/dependency-injection core, near-miss exclusion)
held up for a third consecutive pass and was preserved unchanged. Blocker count trend across passes: 8 -> 4 ->
1, converging rather than churning. The sole blocker was an internal contradiction: F1's Output Range claimed
`current_score` "provably never decreases mid-run" unconditionally, but Edge Cases guarded only two of three
ways `s` could violate its own monotone-non-decreasing contract (non-finite, negative-finite) — a valid,
finite, non-negative `s` that simply decreased (e.g. 500 -> 490) hit neither guard and was untested by AC-2.
User chose the symmetric-guard resolution (matching the existing two guards) over softening the proof to be
conditional on Ball Movement's own contract. Ten recommended items: an `entities.yaml` registry gap (F1 named
by `hud.md` but never registered — same class of omission as the earlier Ball Movement `t_dodge_180`/
`omega_max` fix); an AC-25 tier reclassification (Config/Data/ADVISORY -> Logic/BLOCKING, since a deterministic
preflight validator isn't a balance-tuning value); an unimplementable AC-19 fixture (no `ScoreService`/fake-
Run-State helpers defined, and a dead `make_score_fixture()` spec); an uncited same-tick ordering dependency
on two other GDDs' own frame-model facts; an unpinned `is_finite(s)`-before-`floori()` implementation
ordering obligation; unpinned signal parameter types; an AC-11b wording overclaim ("externally-callable" when
GDScript enforces no privacy); a missing AC-12 companion scan for out-of-band global/autoload calls; AC-20
split into AC-20a-AC-20f for partial-failure traceability; and a missing AC-18 companion row for the
large-hand-edited-`personal_best` case. One specialist disagreement surfaced and adjudicated by the
creative-director, upholding the pass-2 ruling on different grounds: game-designer argued Rule 5 (a voluntary
quit banks a personal best) combined with Rule 12 (the live PB-crossing flash, added the same session as the
pass-2 ruling but never cross-checked against it) creates an optimal "quit the instant the flash appears"
strategy undercutting Pillars 2/5. Creative-director rejected this on the merits: the numeric outcome is
unchanged by quitting (Rule 6 writes identically on both paths), the presentation argument runs backward
(the abandon path gets the *lesser* presentation, since Juice & Feedback suppresses its celebration there),
and there is no risk/reward lever to avoid since near-misses aren't scored (Rule 8) — recommended documenting
the combined reasoning in Rule 5 rather than reopening the design. A second, narrower disagreement: qa-lead
recommended relocating AC-25's evidence to a smoke check; creative-director instead reclassified the AC's
own tier, keeping it in `tests/unit/`.
**Resolution (same session, 2026-09-30):** The blocking item resolved via the symmetric-guard approach (new
Edge Cases guard + AC-15 companion row); all 10 recommended items applied directly (Gate Policy AC-25
reclassification; Fixture section completed for AC-19 and `make_score_fixture()`; Rule 5/Rule 11 same-tick
citation added; F1 Implementation Note's `is_finite`-ordering obligation pinned; signal parameters typed in
Rules 6/12/13 and Rule 11; AC-11b reworded to "public API surface (by naming convention)"; AC-12b added;
AC-20 split into AC-20a-AC-20f with the Gate Policy reference updated; AC-18 companion row added for the
large-`personal_best` case); all 3 nice-to-have items applied (Rule 12's fresh-install suppression now notes
`milestone_crossed` as an incidental compensator; Section B's "honest" clause scoped to distance, cross-
referencing Open Questions 6/7; F1's Output Range gained an int64-vs-float64 footnote). Cross-file edit
applied: `design/registry/entities.yaml` (new `score_from_distance` formula entry for F1, closing the
`hud.md` named-reference gap; `personal_best`/`current_score` deliberately left unregistered as constants,
reasoned in the GDD's own Tuning Knobs section, since neither is a fixed design value another GDD must
agree with). `systems-index.md` row 8 updated to match this verdict.
Prior verdict resolved: Yes — second pass (4 blockers, 2026-09-30, logged below)

## Review — 2026-09-30 — Verdict: NEEDS REVISION (resolved same session)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director
Blocking items: 8 | Recommended: 4 | Nice-to-have: 3
Summary: Core design (`floor(s)`, strictly-greater comparison, `RefCounted`/dependency-injection core) is sound
and was preserved; 8/8 sections present with unusually thorough edge cases. Blocked on one internal
architectural contradiction (Core Rule 7 conflated 3 constructor seams with 4 public methods and omitted
`step()` entirely, making AC-11 untestable — all four specialists converged on this independently), one
broken cross-file contract (Scoring's own Rule 5 makes `run_abandoned` fire `personal_best_updated`, but
`juice-feedback.md`'s Rule 5 asserted it fires only from `run_ended` and classified the abandon path as
`JUICE_PB_CONTRACT_VIOLATION` — a legal path that logged an error and had no defined presentation), and one
Player-Fantasy gap requiring a user decision (Section B promised a live PB-crossing moment; the design only
signaled at run end, bundled with the death presentation). Plus: `S_PRECISION_LIMIT` misattributed to Ball
Movement twice (it is Tube Track's float32 world-Z jitter threshold and is irrelevant to an int score exact
to 2^53); `personal_best`'s `>=0` domain was never validated on read though `save-persistence.md`'s own Rule
10 deliberately leaves the file editable; no named driver owned `step()`/`s_seam`; stale `[scoring]`
`run_id`/timestamp prose sat in the Approved `save-persistence.md`; AC-7 could not catch a copy-paste
divergence between the two ending handlers. Distance-only scoring was upheld against the game-designer's
challenge, but Open Question 6 was mis-framed (the analysis is closed, not empirically open) and its
proposed fallback changed from a near-miss score bonus to a separate HUD near-miss counter. The
creative-director diverged from qa-lead on one item (a proposed AC-20 for double-ending re-entrancy): rated
Recommended, not Blocking, since the GDD has an explicit reasoned policy of trusting Run State's state
machine — the free idempotency the strictly-greater rule provides was documented in Rule 6's rationale
instead, with a new advisory-tier check (SCORE-1).

**Resolution (same session, 2026-09-30):** All 8 blocking items fixed directly in `scoring-personal-best.md`
(Core Rules 7/11/12 added/rewritten, F1 Output Range and Tuning Knobs corrected, new Edge Cases + AC-18/
AC-20/SCORE-1, AC-7/AC-11a/AC-11b/AC-12/AC-16 rewritten, Gate Policy updated). Two required user decisions
were resolved via `AskUserQuestion`: the live PB-crossing gap uses Option A (a new `personal_best_passed`
signal, HUD-only, non-occluding); the `run_abandoned`+PB contract break uses fix (a) (Juice & Feedback
suppresses the banner on the abandon path rather than treating it as a contract violation). Cross-file edits
applied: `save-persistence.md` (Core Rule 1 + AC-16, stale `run_id`/timestamp text removed), `juice-feedback.md`
(Rule 5, States and Transitions, Edge Cases, Dependencies, AC-12, AC-13), `hud.md` (Core Rule 2, Core Rule 14,
Interactions row — minimal spec for the new `personal_best_passed` acknowledgment, full treatment deferred to
HUD's own `/design-review`). All 4 Recommended items and the AC-16 phrasing clarification were also applied
in the same pass.
Prior verdict resolved: First review

## Review — 2026-09-30 — Verdict: NEEDS REVISION (resolved same session)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director
Blocking items: 4 | Recommended: 14 | Nice-to-have: 2
Summary: Re-review of the document as it stood after the same-day tranche of revisions described below. Core design
(`floor(s)`, strictly-greater comparison, `RefCounted`/dependency-injection core) upheld again and preserved. Four
blockers: (1) Core Rule 7 left the `current_score`/`personal_best` accessor implementation (getter method vs.
computed property) undecided, which two specialists converged on independently — qa-lead found AC-11b untestable
as written, godot-specialist found the AC's own claim about `get_script_method_list()` excluding computed properties
unverified and plausibly wrong; resolved by pinning explicit getter methods in Core Rule 7 and rewriting AC-11b to
a fixed six-method list. (2) Rule 11's connect-before-emit guarantee rested on a `run-state-restart.md` commitment
that GDD never actually made; resolved with a new `run-state-restart.md` Core Rule 15 (cross-file edit). (3)
AC-21/AC-22 carried a "deferred, no owner/date" status that `coding-standards.md`'s Integration row does not
authorize (Integration is unconditionally BLOCKING); reframed as BLOCKING at the first-playable gate with a named
owner. (4) This document's own status header claimed a prior "second full-mode re-review" that the review log
(this file) never actually recorded, and `systems-index.md` was likewise still first-pass-only — the exact failure
mode `coding-standards.md`'s Verification-obligation paragraph documents, recurring. Resolved per creative-director's
recommendation: no back-dated entry (unfalsifiable — `production/session-logs/agent-audit.log` cannot attribute any
cycle to a specific target document), the header rewritten to only point at this log instead of narrating its own
history, and this entry is the first one that actually corroborates a second pass. The same-day revisions the old
header described (Core Rule 7's accessor exemption, AC-10's symbol-match narrowing, Core Rules 11/12's expansion,
AC-16/AC-7/AC-20's extensions, Open Questions 6-8's reframing, and the `hud.md`/`juice-feedback.md` banner split) were
verified present in this pass and are folded into this review rather than treated as a separately-gated milestone.
One specialist disagreement, resolved by the creative-director against the specialist: game-designer rated Core
Rule 5 (a personal best can be set by `run_abandoned`, i.e. quitting) as BLOCKING, reasoning it lets a player "bank"
a record risk-free; the creative-director closed this as a non-issue — `current_score` is monotone non-decreasing,
so continuing weakly dominates quitting (no downside to surviving longer, only upside), and the HUD-banner-vs-Juice
Rule 5 asymmetry the same finding flagged is a ratified, intentional design decision from the prior pass, not a bug.
Also fixed: a raw arithmetic error in Core Rule 7 ("three seams and four methods... not one undifferentiated list
of five" — 3+4=7, not 5); AC-1's mutation rationale (GDScript's `round(10.5)` is 11, not 10); an asymmetry note added
for the high-end `personal_best` clamp; Rule 12's haptic exclusion re-justified (channel collision, not Pillar 1);
the AC-19 autoload/singleton scan generalized; AC-9/AC-14 scope clarifications; non-worked-example rows added to
AC-1/AC-3. User decision: added Core Rule 13, a new `milestone_crossed` signal (with `MILESTONE_DISTANCES` as this
GDD's first Tuning Knob and new AC-23/AC-24/AC-25), restoring `game-concept.md`'s own promised distance-milestone
beat that no GDD had implemented — flagged by game-designer, upgraded from nice-to-have to a user decision by the
creative-director. `game-concept.md`'s own stale Autonomy-row claim (near-miss risk "for feedback/score") is now
recorded as this GDD's Open Question 10, since editing `game-concept.md` was outside this session's approved
changeset.
**Resolution (same session, 2026-09-30):** All 4 blocking items and all 14 recommended items fixed directly in
`scoring-personal-best.md`. Cross-file edit applied to `run-state-restart.md` (new Core Rule 15, Interactions table
row, Last Updated note). `hud.md`, `juice-feedback.md`, and `game-concept.md` were **not** edited this pass (out of
scope; `milestone_crossed`'s consumption by HUD/Juice & Feedback and the Autonomy-row fix are left as provisional
follow-ups, Dependencies and Open Question 9 respectively). `systems-index.md` row 8 updated to match this verdict.
Prior verdict resolved: Yes — first pass (8 blockers, 2026-09-30, logged above)
