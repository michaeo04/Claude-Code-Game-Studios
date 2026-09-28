# Near-Miss Detection — Review Log

## Review — 2026-09-28 — Verdict: NEEDS REVISION (first full-mode pass)
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, creative-director
Summary: First full `/design-review`. Added NM-1 (a named, numeric device check for margin speed-invariance, replacing unscoped Open Question 6); the 16 ms along-track time-budget note on F1-NM; documented the sequential-hazard near-zone-overlap blind spot F3-NM's own two-piece proof doesn't cover, handed to Juice & Feedback as a coalescing requirement; Rule 4's multi-piece override rationale, plus an AC-11 row for it. Resolved same session.
Prior verdict resolved: First review

## Review — 2026-09-28 — Verdict: NEEDS REVISION (re-review, second full-mode pass)
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, creative-director
Blocking items: 4 | Recommended: 2
Summary: game-designer found F3-NM's sequential near-zone-overlap coalescing requirement cited "(Open Questions)" but no such row existed — a dangling reference protecting exactly the failure mode this GDD's own Player Fantasy names under Feelings to Avoid. qa-lead found NM-1's ±20% pass band had no stated minimum sample size, risking a false pass/fail from sampling noise given its pre-committed, automatically-executed failure response. systems-designer independently verified all formulas correct but found an arithmetic slip in F1-NM's world-units aside (used R alone instead of R+D/2) and that the 16 ms time-budget note only covered defaults, not the ~5 ms worst legal tuning corner. creative-director additionally found NM-1's "Designation status" paragraph self-undermined its own BLOCKING status by invoking an escalation-exception/ratification track that `coding-standards.md`'s Scope Limit paragraph says a numeric on-device measurement never needed.
Resolved same session: added Open Questions row 8 (owner: Juice & Feedback) and fixed the dangling citation; NM-1 now requires ≥30 hazards-passed per speed band before its ratio is treated as meaningful; NM-1's designation paragraph removed, grounded solely in the Scope Limit Integration classification; F1-NM's arithmetic corrected (0.401 u, ≈0.50 ball diameters) and the ~5 ms worst-corner figure added to NM-1's fail condition; Rule 4's fairness claim no longer cites AC-11 as proof — moved to new Open Question 9 for a first-playable playtest; AC-22 given the same acknowledged-limit framing as AC-21.
Prior verdict resolved: Yes
