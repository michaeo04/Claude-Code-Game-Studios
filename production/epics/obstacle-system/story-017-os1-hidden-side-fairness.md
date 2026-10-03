# Story 017: OS-1 hidden-side fairness playtest (deferred content gate)

> **Epic**: Obstacle System
> **Status**: Blocked
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

> **Blocked**: needs real hidden-side content (pattern-difficulty epic) and the real `VISIBLE_ARC_HALF_WIDTH` (camera epic); hidden content is barred from authoring by Core Rule 8 until Open Questions 2 and 15 resolve. The story is scoped now so it is not designed from scratch later. (This is not an ADR-0015 block.)

## Context
**GDD**: `design/gdd/obstacle-system.md` (Core Rule 8; Formulas F4, F4b; Device and playtest checks OS-1; Gate policy)
**Requirement**: `TR-obstacle-system-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 5: `HIDDEN_CONTENT_FORBIDDEN`, `HIDDEN_UNFAIR`)
**ADR Decision Summary**: Hidden-side hazards are rejected at preflight while the ban is active; the frequency floor `HIDDEN_SPAN_MIN_S` bounds exposure once content is allowed. OS-1 is the playtest that decides whether hidden-side deaths feel like a fair surprise.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Needs a device or editor build with hidden-side hazards, real Camera and hazard rendering.
**Control Manifest Rules (this layer)**:
- Required: playtest at the `HIDDEN_SPAN_MIN_S` boundary using preflight-valid content.
- Forbidden: lifting the `HIDDEN_CONTENT_FORBIDDEN` gate in code before OS-1 has run and OQ2 / OQ15 resolve.
- Guardrail: no hidden-side hazard reaches first-playable before OS-1 has run (content gate).

## Acceptance Criteria
- [ ] **OS-1** at least 5 testers play a build with real hidden-side hazards at the frequency floor's boundary; each hidden-side death is rated 1 ("felt targeted") to 5 ("fair surprise") immediately after it happens.
- [ ] Pass: average rating `>= 4/5`; any single rating `<= 2` requires a written follow-up note.
- [ ] Fail: average `< 4`, or any tester meets two hidden-side hazards closer than `HIDDEN_SPAN_MIN_S` (a content-pipeline bug if preflight works).

## Implementation Notes
Owner is whichever of Pattern & Difficulty / Camera lands second; this story scopes the check and its pass/fail rule, not the finished run. It stays ADVISORY per the GDD (no named build gate yet) but functions as a content gate per Core Rule 8. Reconcile `hidden()` (static proxy anchored to `THETA_REF`) with the live visible arc when running.

## Out of Scope
- `REVEAL_BUDGET` (AC-33, an Open Gap) and Open Questions 2, 15, 17.
- Story 006 classification logic.

## QA Test Cases
- **Setup**: Library containing hidden-side chunks that pass preflight with the ban lifted for the test build only; 5 or more testers.
- **Verify**: Collect per-death ratings, log proximity of hidden hazards.
- **Pass condition**: average at least 4, no unexplained rating at 2 or below, no spacing violation encountered.

## Test Evidence
**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/obstacle-system/os-1.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 006, 013; pattern-difficulty epic; camera epic
- Unlocks: lifting Core Rule 8's hidden-content gate (a future GDD revision)
