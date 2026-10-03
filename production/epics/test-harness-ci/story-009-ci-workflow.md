# Story 009: GitHub Actions workflow ci.yml and triggers

> **Epic**: Test Harness & CI
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0009
**Requirement**: `TR-test-???`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Decision 4; Migration Plan step 3)
**ADR Decision Summary**: `.github/workflows/ci.yml`, job named `ci`, on `ubuntu-latest`, runs `python tools/ci/run_ci.py` with a pinned, checksum-verified Godot 4.7.2 Linux binary and SHA-pinned actions, `contents: read`, no secrets.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Godot download URL is expected at `godotengine/godot-builds` release `4.7.2-stable`, file `Godot_v4.7.2-stable_linux.x86_64.zip` (T-1 item 9 confirms). The SHA-512 value in `tools/ci/versions.json` (`godot.sha512`) is committed BY HAND by the project owner; an agent must never fill it from the same release at run time or guess it.
**Control Manifest Rules (this layer)**:
- Required: `actions/checkout` with `persist-credentials: false`; `concurrency` group cancelling superseded runs; `timeout-minutes`; SHA-pinned `actions/setup-python`; workflow-level `permissions: contents: read`; triggers `push` to `dev` and `main`, `pull_request` into `main` and `dev`; SHA-512 verified before unpacking; upload `build/test-reports/` as an artifact.
- Forbidden: moving action tags; third-party Godot image; downloading GUT in CI; fetching the checksum file at run time; caching `.godot/`; any secret; Windows runner.
- Guardrail: at most 5 minutes after warm cache.

## Acceptance Criteria
- [ ] `.github/workflows/ci.yml` implements every Required item above; an existing workflow file in the repo is reviewed and not overwritten blindly.
- [ ] Every third-party `uses:` is a full commit SHA with a version comment; a short note records how the SHAs are refreshed (Dependabot config or manual review routine).
- [ ] The download step fails the job when the archive SHA-512 differs from `versions.json`; an empty or placeholder `godot.sha512` fails the job (never skips the check).
- [ ] The job runs `python3 tools/ci/run_ci.py` and prints the engine version.
- [ ] `.gitignore` handling is checked: `build/` ignored, `export_presets.cfg` decision untouched.
- [ ] A static check (Python unittest or a lint rule) asserts the workflow has `permissions: contents: read`, `persist-credentials: false`, and no non-SHA `uses:`.

## Implementation Notes
Hand-off: the project owner supplies `godot.sha512` (and confirms the URL); this story ends with the workflow committed and failing closed until that value exists. The "required status check on `main`" setting is NOT done here.

## Out of Scope
- Story 010: first green run (T-2) and negative controls
- Android export workflow (separate later, ADR-0006)
- Enabling a required status check (owner approval, Story 010)

## QA Test Cases
- **AC-1/2/6**: static inspection test against the YAML text (no YAML library: line-based checks)
  - Given: `ci.yml`; When: checks run; Then: each required key present, each `uses:` matches `@[0-9a-f]{40}`
- **AC-3**: dry run the verify step logic locally with a wrong hash
  - Then: non-zero exit; with placeholder hash: non-zero exit
- **AC-4/5**: read-through checklist in the smoke note

## Test Evidence
**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-[date].md` plus `tools/ci/tests/test_workflow_static.py`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 003, Story 004; project owner supplies `godot.sha512`
- Unlocks: Story 010
