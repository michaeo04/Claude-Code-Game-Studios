# Story 002: Spike T-1 - GUT on Godot 4.7.2

> **Epic**: Test Harness & CI
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-03 (completed; evidence in production/qa/)

## Context
**GDD**: none, defined by ADR-0009
**Requirement**: `TR-test-???`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Decision 1 spike T-1; Engine Compatibility Verification Required items 1 to 14)
**ADR Decision Summary**: Install the chosen GUT release into a throwaway project on 4.7.2 and, on Windows and Linux, run one passing, one failing and one `[N]` SceneTree test headless. Pre-committed failure response: if items 1 to 5 fail, switch to gdUnit4, keep `tests/support/`, port test files, amend the ADR.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Nothing in the engine reference covers GUT. Release choice: the newest GUT release whose notes name 4.5 or later, otherwise the latest tested on 4.7.2. GUT 9.x must parse under the 4.5-4.7 GDScript changes (variadics, `@abstract`).
**Control Manifest Rules (this layer)**:
- Required: spike in a throwaway project under `prototypes/`; record `RenderingServer.get_current_rendering_method()` under the headless driver; GUT command line must work without enabling the plugin.
- Forbidden: gdUnit4 unless T-1 fails; a custom SceneTree runner.
- Guardrail: engine version exactly `4.7.2`.

## Acceptance Criteria
- [ ] Verification items 1-14 of ADR-0009 each have a recorded result (pass / fail / value) on Windows and Linux where the item is OS-relevant.
- [ ] Items 1-5 (loads on 4.7.2, exact headless command, non-zero exit on failure, JUnit XML written and readable by `/test-flakiness`, `[N]` SceneTree test runs headless) all pass, or the gdUnit4 fallback is invoked and the ADR amendment is drafted.
- [ ] `RenderingServer.get_current_rendering_method()` value under the headless driver is recorded (ADR-0003 Decision 1).
- [ ] The exact GUT release tag, upstream commit SHA and archive checksum chosen are recorded for Story 003.
- [ ] Whether `--import` needs a second pass, its duration, and whether a Godot run can print `SCRIPT ERROR`/`Parse Error` with exit 0 are recorded (feeds Stories 004 and 009).

## Implementation Notes
Use a throwaway project in `prototypes/gut-spike/` (allowed before Acceptance); do not touch `src/`. Set `.gutconfig.json` `prefix` to `""` and `suffix` to `_test.gd`. Test with a `class_name` fixture after `--import`. Include a test script with a deliberate parse error to see whether GUT skips it silently (justifies the executed-count check).

## Out of Scope
- Story 003: committing GUT into `addons/gut/`
- Story 009: CI workflow and Linux runner run (Linux here is a local or WSL check)

## QA Test Cases
- **AC-1/2**: pass, fail, `[N]` tests
  - Given: spike project with GUT
  - When: run headless with the recorded command on each OS
  - Then: pass test green; fail test makes exit non-zero; `[N]` test passes with `add_child_autofree`
  - Edge cases: plugin not enabled; `class_name` fixture before and after `--import`
- **AC-3**: rendering method recorded in the evidence doc
- **AC-4**: release, SHA, checksum recorded
- **AC-5**: parse-error test script outcome and exit code recorded

## Test Evidence
**Story Type**: Integration (device/host evidence doc)
**Required evidence**: `production/qa/evidence/test-harness-ci/t-1-gut-on-4-7-2.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001
- Unlocks: Story 003, 004, 009; blocks the first Logic story of every other epic
