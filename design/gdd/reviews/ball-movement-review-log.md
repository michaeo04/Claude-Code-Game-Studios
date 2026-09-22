# Review Log: ball-movement.md

**Note on passes 1 and 2:** this log file did not exist before pass 3 (2026-09-22), even
though `ball-movement.md`'s own header cited it since pass 1. Its absence was itself a pass-3
finding (creative-director synthesis, Required Before Implementation #6). The entries below for
passes 1 and 2 are reconstructed from the GDD's own self-referential markers (its `B2`..`B7`
inline revision notes), its committed and uncommitted git history, and `systems-index.md`'s
status line — not from a contemporaneous record, because none was kept. Treat their detail level
as lower-confidence than pass 3's, which was written live during the review it describes.

---

## Review — 2026-09-22 (first review) — Verdict: NEEDS REVISION, then revised
Scope signal: L (reconstructed; not stated in a log at the time)
Specialists: game-designer, systems-designer, qa-lead, godot-specialist; creative-director (senior) — full mode, per the GDD header's own citation
Blocking items: 6 | Recommended: 13 (deferred to a follow-up pass, per the GDD header's own citation)
Summary (reconstructed from the GDD's revision history, not from a contemporaneous log): six
blocking items were resolved in this pass — F5's domain/guard on `T(X, eps)`, the
`OMEGA_MAX`/`BALL_LAG_TAU` cross-knob check (the derived check in `BallConfig.validated()`, Core
Rule 13), the Gate policy's BM-1/BM-3 escalation-exception ratification wording, a `wrap` →
`wrap_angle` rename (GDScript's `wrap` is a global that would not parse unqualified), the
`tube-track.md` F9 cross-file edit (consuming this GDD's `T_DODGE_180` and latency figures), and a
Player Fantasy / Core Rule 5 reconciliation. Thirteen recommended items were deferred to a
follow-up pass. Committed as `40cb191 docs(ball-movement): revise GDD after full /design-review;
apply cross-file edits`.
Prior verdict resolved: First review

### Resolution (2026-09-22, same day, committed)
Applied and committed in `40cb191`. Not re-reviewed against a formal log entry at the time.

---

## Review — 2026-09-22 (second review) — Verdict: NEEDS REVISION, then revised (left uncommitted)
Scope signal: L (reconstructed)
Specialists: game-designer, systems-designer, qa-lead, godot-specialist; creative-director (senior) — full mode, per the GDD header's own citation
Blocking items and fixes, reconstructed from the GDD's own inline `B`-numbered revision notes (its
established convention for marking a fix at its exact location, in place of a log entry):
- **B2** — F2's `T_RAMP <= 0` sentinel was checked only in prose and in AC-19/AC-20's oracles, not in
  the formula itself: `T_RAMP = 0` at `t = 0` evaluated `t^2 / (2*T_RAMP)` as `0/0` (NaN), reachable
  because the sentinel path was deliberately un-logged. Fixed by checking the sentinel first, inside
  the formula.
- **B3** — the full-lock-reversal defect (Open Question 7): `e = phi_target - phi` was unwrapped and
  could reach `+-2 PI`, so a `steer` flip from +1 to -1 at `STEER_ARC = PI` (the same physical point)
  produced `e = -2 PI` and a full 2.09 s lap instead of no motion, directly contradicting Player
  Fantasy. Fixed by wrapping `e` to the shortest signed arc via `wrap_angle`. **This pass also
  narrowed the `STEER_ARC` default from PI to 3.0 rad**, reasoning that the wrap alone left a design
  question (whether to also trade full 360° reach for finer resolution) worth taking — see pass 3
  below, which reverted this specific sub-decision on different grounds than resolution alone.
- **B4** — Core Rule 8's published swept-step bound was corrected to be evaluated against the loaded
  config's actual `V_MAX`/`OMEGA_MAX`, not the shipped defaults, so a legally-tuned config can't
  tunnel a sweep test through a thin hazard.
- **B5/B6** — the derived cross-knob check in `BallConfig.validated()` (AC-19b) was rewritten: an
  earlier version corrected an out-of-budget `(OMEGA_MAX, BALL_LAG_TAU)` pair by *raising*
  `OMEGA_MAX`, which silently made every dodge easier (a difficulty reduction against Pillar 2) and
  widened the collision sweep, without fixing the knob that was actually over budget. Fixed to lower
  `BALL_LAG_TAU` instead, and `BALL_LAG_TAU`'s safe range was narrowed from 0-0.12 to 0-0.072.
- **B7** — `FALLBACK`/RATE mode was scoped as a "degraded compatibility mode" for the MVP: held to
  its own lower bar (BM-7), flagged for Scoring & Personal Best so it never contaminates a
  `SENSOR`/POSITION leaderboard, exempted from the BM-1..BM-5 pillar-gating checks.
- A same-day self-correction: the Gate policy paragraph and `coding-standards.md`'s escalation
  exception had asserted BM-1/BM-3's designation as "ratified" — checked against
  `production/session-logs/agent-audit.log` and found false (no producer had been invoked); corrected
  to "designated ... pending ratification."
Prior verdict resolved: Yes (first review, NEEDS REVISION, 6 blockers, resolved and committed)

### Resolution (2026-09-22, same day, left uncommitted)
Applied to the working copy but **not committed** — `git status` at the start of pass 3 showed
`ball-movement.md` and `.claude/docs/coding-standards.md` both modified and uncommitted. Not
re-reviewed against a formal log entry; this log entry is that missing record, written
retroactively during pass 3.

---

## Review — 2026-09-22 (third review, full mode) — Verdict: NEEDS REVISION, then revised
Scope signal: **XL** (5 hard downstream dependencies, 6 formula blocks, 2 required ADRs — game-loop
and collision — plus a test-framework decision, and a downstream system, Pattern & Difficulty,
receiving a design constraint before it exists)
Specialists: game-designer, systems-designer, qa-lead, godot-specialist (adversarial, parallel);
creative-director (senior synthesis); producer (invoked separately for the BM-1/BM-3 ratification
decision the synthesis required)
Blocking items: 6 | Recommended: 11 | Nice-to-have: 4
Summary: the GDD was structurally sound (8/8 sections, honest self-correcting revision history) but
carried six load-bearing defects. Most significant: the `STEER_ARC` = 3.0 rad default (from pass 2's
B3) created a **moving, unauthorable dead zone** — because `phi_anchor` re-bases on every
`run_resumed` (Core Rule 5) to wherever the ball was at pause, the "unreachable arc opposite the
anchor" relocates with it, so Pattern & Difficulty's "keep that arc hazard-free" constraint cannot
be satisfied by any content-authoring method once resumes are in play, creating a possible
unavoidable death after a resume (a direct Pillar 2 violation). Also: producer ratification of the
BM-1/BM-3 escalation designation was outstanding (a hard blocker on Approval per
`coding-standards.md`'s own rule); two Logic ACs (AC-12, AC-19b) were labeled BLOCKING while their
own text admitted they were not implementable; the 0.11 s input-latency figure feeding the
project's only safety margin (F9, ~0.08 s) was an unbounded approximation, and the margin
arithmetic was silently 60 Hz-only while F5b admitted 30 Hz latency was itself over budget; the
"Node reference simulation" cited ~12 times throughout the GDD as the oracle authority for every
"exact" figure did not exist anywhere in the repository; and this review log file, cited by the GDD
since pass 1, did not exist either.
Prior verdict resolved: Yes (second review, NEEDS REVISION, resolved but never logged or committed
— reconstructed above)

### Specialist findings (adversarial pass)
- **game-designer**: challenged the `STEER_ARC` = 3.0 rad default directly — the shortest-arc wrap
  (B3) alone already fully resolves the full-lock-reversal defect *at* `STEER_ARC` = PI (`e` = 0,
  zero dead zone, full 360° reach intact); narrowing to 3.0 rad traded that hook for a ~4.6%
  resolution gain never tested against the cost. Also flagged: `FALLBACK`/RATE's "degraded
  compatibility mode" (B7) was inadequately justified (no device-population sizing, and its
  post-release coast directly contradicts Player Fantasy's "never moves while my hand is still," a
  Pillar-2-derived promise, for exactly the population already getting the lower bar); the reset
  glide (Core Rule 5) is safety-validated but never feel-validated despite being "common, not rare"
  on the exact instant-restart loop the retention design depends on; the validation machinery's
  complexity (three successive self-caught bugs: B2, B3, B6) may be more than "one continuous axis,
  no taps" (Pillar 4) needs.
- **systems-designer**: plugged boundary values into every formula. Found AC-12 was not merely
  stale but an active hole (its scenario is disowned by the doc itself as invalid, no replacement
  oracle existed); the Tuning Knobs claim "no single pair of `OMEGA_MAX`/`BALL_LAG_TAU` is safe in
  isolation" was false as written (3 of 4 range corners are actually safe; only low-`OMEGA_MAX` +
  high-`BALL_LAG_TAU` is unsafe), and a supporting example (`BALL_LAG_TAU` 0.12) was stale after B6
  narrowed the range to 0-0.072; `T(X, eps)` guards `X <= eps` but not `eps <= 0`, which is equally
  reachable since the function is exposed to Pattern & Difficulty and Tube Track directly;
  `T_RAMP <= 0` is silently accepted with no log while `(0, 45)` is logged — the more suspicious
  input is the unflagged one; Rule 13's bisection corrector has no specified failure mode if
  `OMEGA_MAX`'s floor is ever tuned low enough that even `BALL_LAG_TAU` = 0 can't meet the ceiling
  (only 0.016 s of headroom at the current worst corner). Independently re-derived and confirmed
  correct: F2's NaN-path fix (B2), the F5a boundary continuity, the F5a/F5c figures the doc marked
  "needs Node-sim reverification" (they checked out on hand re-derivation).
- **qa-lead**: found AC-12 and AC-19b both labeled BLOCKING despite admitting non-implementability
  — a real false-Done risk if a team encodes stale/absent numbers to satisfy the label; the Gate
  policy paragraph (the doc's single authoritative gating summary) named only AC-5b and AC-19b as
  caveated, saying nothing about AC-9, AC-12 or AC-13's staleness; producer ratification of BM-1/BM-3
  outstanding is a hard blocker on Approval per the project's own standing rule; the "AC-26/30/32
  tracked as backlog items" claim was contradicted by the very next paragraph (Producer note)
  admitting nothing was ticketed; BM-3's statistics were legitimately rigorous (binomial math
  checked out) but pooled 30 restart + 30 resume trials into one binomial parameter despite the GDD
  itself insisting the two mechanisms are intentionally different (Core Rule 5); BM-2 had no
  statistical framing despite comparable stakes; no reproducible path was ever given for the "Node
  reference simulation."
- **godot-specialist**: no committed process callback (`_process` vs `_physics_process`) for
  `step()`, despite the tilt-poll/adapter-flush/tick/ball-step ordering guarantee depending on
  everyone running in the same cadence; the no-`CollisionObject3D`-in-core decision (Core Rule 11)
  forecloses the idiomatic Jolt/Area3D approach entirely and commits to a custom swept-**arc** test
  (harder than swept-line) with no engineering guidance, punted entirely to an unauthored collision
  ADR; `wrap_angle` has a documented 4.7.2-pinned boundary gotcha that was never checked against the
  pinned binary at the exact seam case the doc itself calls out; `BallMath`'s "stateless static
  class" claim is prose intent, not a GDScript language guarantee, and AC-25's lint doesn't scan for
  a future `static var` that would silently reintroduce shared mutable state.

### Disagreements adjudicated (creative-director)
- **AC-12 vs AC-19b severity**: qa-lead treated them as the same tier; systems-designer separated
  them (AC-12 actively wrong, AC-19b's algorithm verified sound, only its 6-digit oracle missing).
  Adjudicated as a middle path: AC-19b stays BLOCKING, restated as an invariant (implementable
  today without a fixed oracle); its boundary-pair oracle split out as new **AC-19c** (now computed
  via the checked-in bisection routine, not left pending); AC-12 moved out of BLOCKING into a new
  **Open Gaps** list; a new **AC-12a** split out to recover the part of AC-12 unaffected by B3 (the
  `|phi| > 2 PI` shift invariant), implementable today as an invariant assertion.
- **`STEER_ARC` = 3.0 — Recommended Revision or blocker?**: game-designer raised it as a
  design-values trade-off (Recommended-Revision level); creative-director escalated it to BLOCKING
  on a stronger, distinct argument — the dead zone is not fixed tube geography once resumes re-base
  the anchor, making Pattern & Difficulty's constraint unenforceable by any content-authoring method
  and creating a possible unavoidable death (Pillar 2). Adjudicated: BLOCKING; reverted to PI (B8).
- **Game-loop/collision ADR gaps — one finding or two?**: godot-specialist framed it as engine risk,
  qa-lead as gate-readiness risk. Adjudicated: same root cause (Ball Movement froze its contract with
  not-yet-owned systems), two distinct risks needing separate tracking; design should be a co-owner
  of the collision ADR (Open Question 4) since swept-vs-sampled collision is a Pillar 2 decision, not
  a purely technical one.

### Producer ratification (separate invocation, same pass)
Producer verified against `production/session-logs/agent-audit.log` that no producer had been
invoked between the 2026-09-19 concept gate and this ratification — confirming the "pending" status
was accurate, not an error. **RATIFIED** both the escalation-exception rule text and the BM-1/BM-3
designation, with four amendments to the rule (a failure-mode reading of "sole" rather than
per-pillar, since BM-1 and BM-3 both serve Pillar 2 and neither would be "sole" under a per-pillar
reading; a named build-gate expiry instead of a permanent designation; a required pre-committed
failure response; a decline path so the GDD is never permanently deadlocked) and three production
conditions (the gate blocks the first-playable label/sign-off, not implementation of the core, ACs
or harness; BM-1 split into BM-1a, software, any single device, run first, and BM-1b, end-to-end
jig; a "spike readiness" story and device procurement tracked as an owned external dependency before
the spike itself). Also flagged, from a production-cost lens: the marginal cost of this designation
is low because the on-device spike was already unavoidably on the critical path (Tilt Input V-1 is
already user-designated BLOCKING for first playable, 2026-09-21) — the real risk is sequencing, not
the gate itself: a BM-1 miss after Pattern & Difficulty is authored means re-authoring hand-placed
hazard content, not just editing numbers, so the spike must run before Pattern & Difficulty, not
after.

### Resolution (2026-09-22, same day)
Applied in this pass, to the working copy (approval gathered via `AskUserQuestion` for the three
design decisions: `STEER_ARC` reverted to PI; `FALLBACK`/RATE cut from MVP scope; 30 Hz declared
outside the fairness contract rather than left as a silent gap):
- `STEER_ARC` reverted from 3.0 rad to PI (B8): Core Rules 4/5/6, Formulas F1/F5a/F5c, Edge Cases,
  Tuning Knobs, Knob Interactions, Open Question 7, and the systems-index.md notes-for-authors block
  updated. The unreachable-arc constraint on Pattern & Difficulty is removed at the default.
- `FALLBACK`/RATE cut from MVP scope (B9): a no-sensor device now shows "device not supported" and
  never reaches Ball Movement's core in the MVP; `BallCore`'s own input-source latch mechanism is
  kept unchanged (pure logic, still tested by AC-15/AC-16, still useful for the spike comparison and
  possible reuse) — the cut is at the driver/game-flow level, not inside `BallCore`. BM-7 removed.
  Cross-file flag added to `tilt-input.md` Open Question 10 (its own touch/key-fallback generation
  is consequently unreachable in MVP gameplay; left as that GDD's own scoping decision) and to
  `systems-index.md`'s HUD/Menus and Scoring & Personal Best notes.
- 30 Hz fairness contract declared explicitly (B10): F5b now states plainly that BM-1/BM-3 and the
  F9 dodge-margin arithmetic are 60 Hz-only commitments; 30 Hz is recorded but not fairness-gated,
  tracked as a live gap rather than assumed safe by omission.
- AC-12 moved to a new **Open Gaps** section; **AC-12a** and **AC-19c** added; AC-19b restated as an
  implementable invariant with a worked example computed by the checked-in sim; the Gate policy
  paragraph rewritten to enumerate every AC currently carrying a staleness caveat (not just the two
  a prior draft named) and to state a standing rule against future BLOCKING/non-implementable
  mislabeling.
- `tools/reference-sim/ball_movement.js` checked in: implements F1, F2, F3, F5a, F5c, the AC-10/AC-11
  scripted scenarios, and the Rule 13 bisection routine (used to compute AC-19b's worked example and
  AC-19c's boundary pair). Every assertion in it passes as of this pass.
- `.claude/docs/coding-standards.md`'s escalation exception rewritten per producer's ratified text
  (failure-mode reading of "sole," named build-gate expiry, pre-committed failure response, decline
  path, a scope limit noting BM-1/BM-3 would also qualify as ordinary Integration-on-device evidence
  and the exception should not be over-cited for future numeric device checks).
- `production/qa/evidence/ball-movement/` created (producer condition) with a placeholder `README.md`.
- This review log file created (did not exist before this pass, despite being cited since pass 1).

Not yet re-reviewed. Run `/design-review design/gdd/ball-movement.md` in a fresh session.

### Deferred to a follow-up pass (Recommended Revisions not addressed in pass 3)
- Game-loop ADR (process callback ownership) and collision ADR (swept-arc, no `CollisionObject3D`)
  still have no named owner or date — flagged to Obstacle System as a known cost, not yet resolved.
- The ~1.1 s non-interactive window at the start of every restart (reset glide + hazard-free zone)
  remains safety-validated but not feel-validated; no BM check yet targets it directly.
- `T(X, eps)`'s missing `eps <= 0` guard, `T_RAMP <= 0`'s silent (unlogged) acceptance versus the
  logged `(0, 45)` clamp, and Rule 13's bisection failure mode if `OMEGA_MAX`'s floor is ever tuned
  low enough that `BALL_LAG_TAU` = 0 can't meet the ceiling — all still open.
- `wrap_angle` not yet verified against the pinned 4.7.2 binary at the exact seam case Edge Cases
  calls out; unclear whether it will be one canonical shared implementation with Tube Track or two
  independently-authored copies.
- AC-25's forbidden-token lint does not yet scan for a future `static var` in `BallMath`.
- AC-9 and AC-13 are reasoned-confirmed as unaffected by B3's wrap but not yet machine-verified
  against `tools/reference-sim/ball_movement.js` (the sim does not yet script their multi-frame
  sequences).
- AC-12's replacement (a positive test that phi/phi_anchor drift across many ordinary resume/steer
  cycles is correctly bounded at the PI default) still needs a new scripted sequence.

### Caveats to remember
- Passes 1 and 2 above are reconstructed, not contemporaneous; their specialist-finding detail is
  lower-confidence than pass 3's.
- Every default in this GDD remains a guess pending the on-device spike; nothing in pass 3 changed
  that status.
- `tools/reference-sim/ball_movement.js` does not yet cover every AC's oracle (see "Deferred" above)
  — it is the oracle authority for what it does cover, not yet a complete replacement for hand
  verification of the rest.
