# Story 016: OS-2 corner-cut legibility playtest

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/obstacle-system.md` (Edge Cases corner-cut false positive; Device and playtest checks OS-2; Player Fantasy legibility)
**Requirement**: `TR-obstacle-system-003` (the bias being playtested)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 4: approved swept AABB); ADR-0014: Hazard render route (silhouette must match the footprint)
**ADR Decision Summary**: The swept AABB deliberately favours never missing a hit over pixel-exact contact; a hit can register up to one frame of travel before visual contact. OS-2 asks whether such a death still reads as fair.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Needs a vertical-slice build running on a device or editor with hazard rendering (hazard-view epic).
**Control Manifest Rules (this layer)**:
- Required: the no-tunnel bias stays load-bearing; the playtest uses the shipped analytic test unchanged.
- Forbidden: disabling the swept test's no-tunnel bias as a fix.
- Guardrail: none specific.

## Acceptance Criteria
- [ ] **OS-2 (ADVISORY)** at least 5 testers each experience one engineered corner-cut death (scripted approach at the AC-5 worked values: Picket, `theta -0.3 -> 0.3`, `s 199.0 -> 199.7`) and answer "did that death feel fair" yes or no.
- [ ] Result: fails if more than 1 of 5 answers no.
- [ ] If it fails, the pre-committed response is applied: lower F2's per-frame false-positive bound by tightening the ball-expansion margin's rounding, never by disabling the swept test's no-tunnel bias.

## Implementation Notes
Runnable once any vertical slice exists. Script the approach through a debug harness so each tester sees the same geometry. Record tester count, answers, device, build and any free-text. Advisory only; it does not block merges. The evidence is listed in the GDD under `production/qa/evidence/obstacle-system/os-N.md`.

## Out of Scope
- OS-1 hidden-side fairness (Story 017).
- Re-deriving the algebraic false-positive bound (covered by AC-5, Story 003).

## QA Test Cases
- **Setup**: Build with Wall/Picket fixture and the scripted engineered approach; 5 or more testers, one death each.
- **Verify**: Ask the single yes/no question immediately after the death; log the answer.
- **Pass condition**: at most 1 of 5 answers no; otherwise apply the pre-committed response and re-run.

## Test Evidence
**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/obstacle-system/os-2.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 013; hazard-view epic (rendered hazards); a vertical-slice build
- Unlocks: nothing blocking (ADVISORY)
