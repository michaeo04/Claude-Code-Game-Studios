# Story 007: Per-rule pass/fail fixtures and runner self-check

> **Epic**: Test Harness & CI
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0009
**Requirement**: `TR-test-???`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Decision 5 "The lints are tested"; Validation Criteria)
**ADR Decision Summary**: `tools/ci/tests/` holds Python `unittest` cases with one passing and one failing fixture per rule; a rule without both fixtures fails the runner's self-check. Python tests run as step 4a of `run_ci.py`.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `tools/ci/tests/fixtures/` exists with the other agent's partial fixtures. Fixtures that are deliberately invalid GDScript are `.txt` or live under a `.gdignore` folder, so `--import` never loads them.
**Control Manifest Rules (this layer)**:
- Required: one passing and one failing fixture per rule; self-check fails on a rule lacking either; invalid-GDScript fixtures as `.txt` or under `.gdignore`; `tools/` carries `.gdignore`.
- Forbidden: inline ignore comments to silence a rule; unit tests touching real project files for rule logic.
- Guardrail: tests deterministic and independent of execution order.

## Acceptance Criteria
- [ ] For every rule in `lint_rules.json` there is a passing fixture (no finding) and a failing fixture (a finding with that rule id), discovered by naming convention.
- [ ] A generated `unittest` per rule asserts both outcomes and the reported line number of the failing fixture.
- [ ] Self-check: removing either fixture of any rule makes `lint_runner.py` (or its self-check mode) exit non-zero naming the rule.
- [ ] Fixtures for string/comment immunity: a banned token only in a comment and only in a string passes for every `forbid` rule that has a pattern.
- [ ] `godot --headless --import` still exits 0 with the fixtures present (no parse-error leakage).
- [ ] `python tools/ci/run_ci.py --only lint` runs the Python tests as step 4a and fails on any of them failing.

## Implementation Notes
Prefer table-driven tests: iterate rules and fixtures by id. Fixture file names carry the rule id (sanitised) and `_pass` / `_fail`. Add a `.gdignore` under fixtures if any `.gd` extension is used.

## Out of Scope
- Story 006: rule behaviour itself
- Rules added later by other epics (they must ship their own fixtures; the self-check enforces that)

## QA Test Cases
- **AC-1/2**: iterate all rules, Given fixtures, When lint a temp tree with only that fixture, Then 0 or exactly the expected finding
- **AC-3**: delete a fixture in a temp copy; Then non-zero and rule id in output
- **AC-4**: comment-only and string-only variants
- **AC-5**: run import with fixtures present
- **AC-6**: break a unit test deliberately; Then `run_ci.py --only lint` fails

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tools/ci/tests/test_lint_fixtures.py` plus fixtures; Logic gate BLOCKING
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 005, Story 006
- Unlocks: Story 010 (negative controls)
