# Designated Gates Register

Per `.claude/docs/coding-standards.md`'s Visual/Feel escalation exception: a check becomes
BLOCKING only when the creative-director designates it (as part of a `/design-review`) and the
producer ratifies. Check this register before designating a new gate — if another GDD already
claims the same failure mode, neither is "sole." This file was created 2026-09-27 (Ball Movement
pass-4 `/design-review`) to hold the first entries; the BM-1/BM-3 designation below was decided
and ratified on 2026-09-22 (pass 3) but had not yet been recorded here — a gap this file closes,
not a new decision.

---

## Active designations

### BM-1a / BM-1b / BM-3 — Ball Movement

- **GDD**: `design/gdd/ball-movement.md`
- **Failure modes**:
  - BM-1a/BM-1b: input-to-ball pipeline latency makes a death the pipeline's fault, not the
    player's (Pillar 2 primary, Pillar 4 secondary).
  - BM-3: unasked ball motion at run start/resume (Pillar 2).
- **Designated by**: creative-director, `/design-review` pass 3, 2026-09-22.
- **Ratified by**: producer, 2026-09-22 (verified against `production/session-logs/agent-audit.log`
  that no producer had been invoked between the 2026-09-19 concept gate and this ratification, so
  the prior "pending" status was accurate — not an error). Amendments made at ratification: a
  failure-mode reading of "sole" (not per-pillar, since BM-1 and BM-3 both serve Pillar 2 and
  neither would be "sole" under a per-pillar reading); a named build-gate expiry instead of a
  permanent designation; a required pre-committed failure response; a decline path.
- **Named build gate**: the **first-playable** label and sign-off (qa-lead and technical-director
  sign). The designation expires when that gate is passed, unless re-designated. It blocks the
  first-playable *label*, not implementation of `BallCore`/`BallMath`/`BallConfig`, the Logic ACs,
  the AC-25 lint, the driver or the view — all buildable and testable headlessly, on desktop,
  before any device is available.
- **Pre-committed failure response** (decided before the result is known): if BM-1a, BM-1b or BM-3
  miss, the default response is **lowering `V_MAX`** (toward about 22 u/s), **not** loosening Tube
  Track's `T_VIS_MIN` floor or Ball Movement's `T_DODGE_180_MAX` — loosening a validator is the
  easy path under deadline pressure and is exactly the path that would quietly erode Pillar 2
  (Ball Movement's "Strategic note on margins," `design/gdd/ball-movement.md`).
- **Production conditions** (producer, pass 3): BM-1 split into BM-1a (software, any single
  device, run first) and BM-1b (end-to-end jig, does not need to wait for BM-1a); a "spike
  readiness" story (harness, per-frame `theta` logging, jig setup, this directory's existence)
  lands before the spike itself; device procurement (>= 2 Android makers; no iPhone, the project is Android-only) is an owned
  external dependency, user-owned, date to be confirmed.
- **Not designated**: BM-2 (Dodge 180) — its own text treats a miss as "a tuning finding," so it
  is BLOCKING only for locking the `OMEGA_MAX`/`BALL_LAG_TAU` tuning defaults, never for the
  first-playable build's existence. BM-4 and BM-6 are ADVISORY (see below for BM-4's trigger
  condition). BM-7 was removed from scope entirely (Rule 6, B9).

---

## Watched, not yet designated

### BM-4 (Resolution feel) off-neutral drift logging — Ball Movement

- **GDD**: `design/gdd/ball-movement.md`
- **Candidate failure mode**: involuntary off-neutral ball drift (Edge Cases, added pass 4,
  2026-09-27) consumes enough of the fine-positioning clearance in a tight gap that a dodge the
  player executed correctly still fails — a Pillar 2 concern, distinct from BM-1/BM-3's failure
  modes above (unasked motion at rest vs. drift while actively steering).
  Not yet designated: this GDD's own pass 4 explicitly declined to designate it now, because no
  defensible pass/fail threshold exists before any device data — a BLOCKING label without an
  implementable oracle is exactly the defect class this GDD's own standing rule (Gate policy)
  forbids.
- **Trigger condition for a future designation**: if BM-4's logged drift is found to consume
  roughly a third or more of a 2.5-width gap's clearance (the fine-positioning floor named in F5c),
  it becomes a candidate for BLOCKING designation in a subsequent pass — through the normal
  creative-director-designates / producer-ratifies path, not automatically.
- **Owner of the watch**: game-designer, qa-lead (BM-4 evidence review after the spike).
