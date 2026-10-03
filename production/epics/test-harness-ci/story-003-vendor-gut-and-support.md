# Story 003: Vendor GUT, .gutconfig.json, tests/support skeleton

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
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Decision 1; Decision 2 layout; Migration Plan step 2)
**ADR Decision Summary**: GUT is vendored under `addons/gut/` at a pinned tag; tag, upstream commit SHA, archive checksum and licence file are recorded in `tools/ci/versions.json`. `.gutconfig.json` sets `prefix` "" and `suffix` "_test.gd". Fixtures live in `tests/support/` with no GUT dependency.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Release is the one recorded by T-1. GUT loads without the editor plugin enabled.
**Control Manifest Rules (this layer)**:
- Required: GUT is the only allowed addon; `tests/support/` plain `RefCounted` with no GUT base class or call; tests use `const X = preload("res://tests/support/x.gd")`.
- Forbidden: downloading GUT in CI; `[editor_plugins]` entry unless wanted; fakes named `Double`/`Spy`; `class_name` in `tests/support/` without a unique prefix.
- Guardrail: `addons/gut` and `tests/` excluded from exports (enforced later by the manifest lint).

## Acceptance Criteria
- [ ] `addons/gut/` contains the exact release chosen in T-1, with its licence file, and no files outside the upstream tree.
- [ ] `tools/ci/versions.json` records GUT release tag, upstream commit SHA, archive checksum, licence file path (the `godot.sha512` field is the project owner's, Story 009).
- [ ] `.gutconfig.json` is committed: directories `tests/unit` and `tests/integration` (advisory run separately), recursion on, `prefix` "", `suffix` "_test.gd", `-gexit`, JUnit XML path under `build/test-reports/`.
- [ ] `tests/support/` has a README-free skeleton: one framework-free example fixture and a trivial `tests/unit/test_harness/test_harness_smoke_test.gd` that passes headless.
- [ ] `technical-preferences.md` Allowed Libraries lists GUT (MIT, pinned); if T-1 selected gdUnit4 instead this story is replaced.

## Implementation Notes
Copy only the files upstream ships for the tag; do not hand-edit them. Record the checksum of the downloaded archive, not of the tree. Support code must not reference `GutTest`.

## Out of Scope
- Story 002: the spike itself
- Per-system fixtures (`make_save_fixture`, `FakeSaveFs`, ...) belong to the epics that need them

## QA Test Cases
- **AC-1/2**: `versions.json` fields present; archive checksum reproduces from the recorded URL
- **AC-3**: run GUT with the config
  - Given: smoke test file `*_test.gd`
  - When: run the T-1 command
  - Then: 1 test executed, 1 passed, XML written
  - Edge cases: a file not ending `_test.gd` is not discovered
- **AC-4**: grep `tests/support/` finds no `GutTest`/`gut` token
- **AC-5**: allowed-libraries line present

## Test Evidence
**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-[date].md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002
- Unlocks: Story 004, 009, 010
