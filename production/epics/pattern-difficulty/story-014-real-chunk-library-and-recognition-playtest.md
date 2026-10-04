# Story 014: Real chunk library and recognition playtest (PD-1)

> **Epic**: Pattern & Difficulty
> **Status**: Blocked
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: Content authoring (several sessions); evidence 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

> **BLOCKED**: depends on content authoring (GDD Open Question 3, systems-index scope risk) and on Story 010 (padding is part of the shipped feel), which waits on the Pattern design review (`TR-pattern-difficulty-011` Partial). The authoring debug overlay required by Obstacle before chunk authoring starts is also a prerequisite. Unblock when Story 010 is Done and an author is assigned.

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (AC-27 deferred integration; PD-1 device/playtest check; Open Questions 3, 8, 11)
**Requirement**: `TR-pattern-difficulty-021`, `TR-pattern-difficulty-009`, `TR-pattern-difficulty-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: The shipped `assets/data/chunks/chunk_library_01.tres` (one external `.tres` per `ChunkDef`) must pass `ContentPreflight` P1 to P3 as the blocking CI test; the export smoke test loads and compiles it from the exported package.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION (items 1, 2, 3, 8): typed arrays of custom Resources round-trip in an Android export; floats and enum ints preserved. Run preflight after `godot --headless --import`.
**Control Manifest Rules (this layer)**:
- Required: the content test loads real `.tres` files from disk and asserts exact values such as `PI/2`; the blocking CI test `tests/integration/pattern_difficulty/pattern_difficulty_content_preflight_test.gd` passes for any merge touching `assets/data/chunks/`; INTRO has at least 2 grace-compliant chunks.
- Forbidden: JSON or GDScript constant tables for content; running the 500-seed soak in the debug-build boot; mutating a loaded Resource.
- Guardrail: padding frequency measured at first playable (Pattern OQ11); INTRO/RAMP/FULL pool sizes decided by the author.

## Acceptance Criteria
- [ ] **AC-27 (deferred, becomes BLOCKING when claimed)** The real hand-authored library replaces the 8-chunk fixture: it passes P1, P2 and the P3 soak (`pattern_difficulty_content_preflight_test.gd`), the tier pools meet Core Rule 6 and the advisory clustering check is reviewed.
- [ ] **PD-1 (ADVISORY, device/playtest)** At least 5 testers rate repeat encounters of an INTRO chunk on the anchored 5-point scale; the average is >= 4/5 and no tester reports a repeat gap outside `[min_gap, max_gap]`. Evidence: `production/qa/evidence/pattern-difficulty/pd-1.md`.
- [ ] Padding frequency at first playable is measured and recorded (OQ11).

## Implementation Notes
Author chunks in the editor against the debug overlay; do not hand-edit `.tres`. Keep each `ChunkDef` in its own file under `assets/data/chunks/`. Content count and pool sizes are an author decision (OQ3). Tooling needs from OQ8 (live clustering check, pair-and-chunk naming, padding preview) are tools-programmer tasks outside this story. Add the `.tres` export-smoke test if the exported package route exists by then.

## Out of Scope
- Maps & Levels per-map library selection (OQ4).

## QA Test Cases
- **AC-27**: Given: the shipped library. When: CI preflight runs P1 to P3. Then: no violations; the library compiles in the exported build.
- **PD-1**: Setup: build with a repeated INTRO chunk within one run. Verify: each tester rates repeats. Pass condition: mean >= 4/5, no out-of-bounds repeat gap reported.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/pattern_difficulty/pattern_difficulty_content_preflight_test.gd` and `production/qa/evidence/pattern-difficulty/pd-1.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 010 (Blocked), Story 013; obstacle-system stories 011 and 012 (`ContentPreflight`)
- Unlocks: first-playable content gate
