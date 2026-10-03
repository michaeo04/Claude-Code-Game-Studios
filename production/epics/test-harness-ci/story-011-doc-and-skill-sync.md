# Story 011: Document and skill synchronization (Decision 8)

> **Epic**: Test Harness & CI
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0009
**Requirement**: `TR-test-???`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Decision 8; Migration Plan step 4)
**ADR Decision Summary**: After acceptance, `coding-standards.md` and `technical-preferences.md` are updated and the four test skills drop their gdUnit4 assumptions in favour of GUT and `python tools/ci/run_ci.py`.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Documentation only. Skills are project-owned files under `.claude/skills/`. Wording that depends on T-1 results (exact command options) must use the recorded values, so run after Story 002.
**Control Manifest Rules (this layer)**:
- Required: `/smoke-check` calls `python tools/ci/run_ci.py --only unit`; CI line in `coding-standards.md` replaced; tests/integration and tests/advisory stated.
- Forbidden: gdUnit4 references except as the documented fallback; recording an approval that has not happened.
- Guardrail: no "Minimum Coverage: TO BE CONFIGURED" left; coverage policy text matches Decision 6.

## Acceptance Criteria
- [ ] `.claude/docs/coding-standards.md`: the Godot CI line becomes `python tools/ci/run_ci.py`; the three test folders are stated.
- [ ] `.claude/docs/technical-preferences.md`: Allowed Libraries lists GUT (MIT, pinned); Testing section shows GUT and the no-line-coverage policy; Forbidden Patterns points to the registry list; Architecture Decisions Log has ADR-0009.
- [ ] `/test-setup`, `/smoke-check`, `/test-helpers`, `/test-flakiness` skills contain no gdUnit4 scaffolding or commands, and use the GUT / run_ci commands and JUnit path.
- [ ] `design/gdd/systems-index.md` note "GUT vs gdUnit4 must be settled" is closed; the GDD open questions (Ball Movement 12, Obstacle 9, Platform Services 18, Tilt Input 16) are marked resolved.
- [ ] A repo-wide search for `gdunit4_runner` and `gdUnit4` lists only the fallback mentions.

## Implementation Notes
Edit only the named files; show the diff and ask before writing (collaboration protocol). If T-1 selected gdUnit4, this story is replaced by the ADR amendment.

## Out of Scope
- Story 009/010: CI
- Adding any lint rule

## QA Test Cases
- **AC-1 to 4**: Given each file; When searched for the old text; Then absent and the new text present (grep, with the file list in the smoke note)
- **AC-5**: grep result recorded; Edge cases: references inside archived reviews are allowed if dated

## Test Evidence
**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-[date].md` (grep results)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002 (command wording), Story 004
- Unlocks: first `/smoke-check` run of any sprint
