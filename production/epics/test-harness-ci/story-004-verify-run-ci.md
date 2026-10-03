# Story 004: Verify and harden run_ci.py (entry command and result checks)

> **Epic**: Test Harness & CI
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-03 (completed; evidence in production/qa/)

## Context
**GDD**: none, defined by ADR-0009
**Requirement**: `TR-test-???`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Decision 3; Risks "false green" rows)
**ADR Decision Summary**: One command, `python tools/ci/run_ci.py [--only unit|integration|advisory|lint|all]`, runs import, GUT unit then integration, GUT advisory (warning), then the lint runner (Python tests as step 4a). A green exit code is never trusted.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: VERIFICATION story: `tools/ci/run_ci.py` was written by another agent and has not been run against GUT or a real 4.7.2 binary. Behaviour depends on T-1 results (second import pass, exit-code behaviour, XML format).
**Control Manifest Rules (this layer)**:
- Required: timeout wrapper on every Godot call; JUnit XML must exist, report more than zero tests and at least as many as `*_test.gd` files, zero failures/errors; fail on `SCRIPT ERROR` / `Parse Error` even with exit 0; binary from `GODOT` or `versions.json`; print the engine version and fail unless exactly `4.7.2`.
- Forbidden: retry, skip, `pending`, or disabling tests to go green; trusting the exit code alone.
- Guardrail: full run at most 5 minutes with warm cache.

## Acceptance Criteria
- [ ] `--only unit|integration|advisory|lint|all` each select exactly the documented steps; advisory failure is a warning, not a job failure.
- [ ] Negative controls, each making the command exit non-zero then removed: a failing test; a test file with a parse error (executed count lower than file count); zero tests; an injected `SCRIPT ERROR` with exit 0; a hung Godot call (timeout); a wrong engine version.
- [ ] JUnit XML is written under `build/test-reports/` and `/test-flakiness` can read it.
- [ ] The second-import-pass decision recorded by T-1 is implemented.
- [ ] Python tests for `run_ci.py` result-check logic exist under `tools/ci/tests/` (with fakes for the subprocess).
- [ ] `/smoke-check` documentation line calls `python tools/ci/run_ci.py --only unit` (skill sync is Story 011).

## Implementation Notes
Keep the Godot invocation behind an injectable function so the result checks are unit-testable without Godot. Output scanning must read stdout and stderr. Do not rely on the `GODOT` default of a PATH lookup on the dev host without printing the resolved path.

## Out of Scope
- Story 005-008: lint runner internals
- Story 009: CI workflow

## QA Test Cases
- **AC-1**: run each `--only` mode; Then: expected steps in output order
- **AC-2**: for each negative control
  - Given: the injected fault
  - When: `python tools/ci/run_ci.py --only unit`
  - Then: non-zero exit and a message naming the check
  - Edge cases: fault in advisory only gives exit 0 plus warning
- **AC-3**: open the XML in the `/test-flakiness` reader format check
- **AC-4**: clean checkout needing two passes still ends green
- **AC-5**: `python -m unittest discover tools/ci/tests` passes

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tools/ci/tests/test_run_ci_checks.py` (Python unittest, result-check logic) plus `production/qa/evidence/test-harness-ci/run-ci-negative-controls.md` (device/host evidence doc)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002, Story 003
- Unlocks: Story 009, 010
