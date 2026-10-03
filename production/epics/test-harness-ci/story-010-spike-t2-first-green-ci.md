# Story 010: Spike T-2 - first green CI run and negative controls

> **Epic**: Test Harness & CI
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0009
**Requirement**: `TR-test-???`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Migration Plan steps 3 and 5; Validation Criteria T-2 and negative controls)
**ADR Decision Summary**: T-2 is the first green run of the workflow on `dev` on a trivial test and the lint runner, within the time budget, with checksum-verified Godot and SHA-pinned actions. A deliberately failing test and a deliberately violating file each turn the `ci` job red, then are removed.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Linux binary headless on `ubuntu-latest` without a display is T-1 item 8, confirmed here on the real runner.
**Control Manifest Rules (this layer)**:
- Required: pinned inputs, `contents: read`; full run at most 5 minutes.
- Forbidden: never disable or skip a failing test to pass CI; changing branch protection or repository settings without the owner's explicit approval.
- Guardrail: `.godot/` not cached in the MVP.

## Acceptance Criteria
- [ ] The `ci` job runs green on a push to `dev` (trivial GUT test from Story 003 plus the lint runner and its Python tests); run URL and duration recorded; duration within 5 minutes or the overrun is recorded with a cause.
- [ ] Negative control 1: a deliberately failing GUT test on a throwaway commit makes `ci` red; removed afterwards.
- [ ] Negative control 2: a deliberately violating `.gd` file (for example `_process` outside `game_root.gd`) makes `ci` red; removed afterwards.
- [ ] Negative control 3: a wrong `godot.sha512` makes `ci` red at the download step; restored afterwards.
- [ ] `build/test-reports/` artifact is downloadable and contains the JUnit XML.
- [ ] A `pull_request` into `main` triggers the same job (checked on a draft PR or noted as untested with reason); no merge to `main` is performed by this story.
- [ ] The project owner is asked, in the evidence doc, whether to enable `ci` as a required status check on `main`; the answer is recorded; the story does not change the setting.
- [ ] `/smoke-check` calling `python tools/ci/run_ci.py --only unit` succeeds locally (Validation Criterion).

## Implementation Notes
Negative controls use short-lived commits on a branch cut from `dev` (merged or deleted per git-workflow); never push a red state to `main`. Remove each fault in its own commit.

## Out of Scope
- Story 009: authoring the workflow
- Branch protection changes (owner only)

## QA Test Cases
- **AC-1**: Given a push to `dev`; When the run finishes; Then green and under 5 min
- **AC-2/3/4**: Given each fault; When pushed; Then the job is red with the failing step named; Edge cases: fault removed then green again
- **AC-5**: download the artifact and open it
- **AC-6/7**: record in the evidence doc

## Test Evidence
**Story Type**: Integration (CI run evidence doc)
**Required evidence**: `production/qa/evidence/test-harness-ci/t-2-first-green-ci.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 004, Story 007, Story 008, Story 009; `godot.sha512` committed by the project owner
- Unlocks: first Logic story of every other epic (T-1 and T-2 gate)
