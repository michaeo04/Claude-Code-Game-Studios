# Story 009: Shipped PatternConfig.tres

> **Epic**: Pattern & Difficulty
> **Status**: Complete
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: 1-2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (Tuning Knobs; AC-22)
**Requirement**: `TR-pattern-difficulty-001`, `TR-pattern-difficulty-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (per-build knobs stay in their own `.tres`); ADR-0008: Hazard, collision and content format
**ADR Decision Summary**: `PatternConfig` lives in its own `.tres`; the `PatternConfig.tres` fields beyond the three knobs are not fixed by the GDD (TR-021), so add only what the stories above need (`max_opposing_fraction`, tier durations, threshold).
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Verify exact `PI/2` float64 equality after a disk load (ADR-0008 items 1-3).
**Control Manifest Rules (this layer)**:
- Required: gameplay values data-driven (external `.tres`); the content test loads the real file from disk.
- Forbidden: hardcoded knob values in logic; mutating a loaded (cached) Resource.
- Guardrail: tiny resource.

## Acceptance Criteria
- [ ] **AC-22 (ADVISORY)** The shipped `PatternConfig.tres` equals the Tuning Knobs table (`TIER_INTRO_DURATION` 15, `TIER_RAMP_DURATION` 90, `ANGULAR_REVERSAL_THRESHOLD` PI/2, `MAX_OPPOSING_FRACTION` 0.6) and `validated()` returns no log line beyond AC-21-style advisories.

## Implementation Notes
Create `assets/data/pattern/pattern_config.tres` (path follows the other config resources under `assets/data/`; check `assets/data/` for the project convention before choosing the folder). Exports typed as in Story 001. Smoke check: the test loads it with `load()` and compares to the constants in a `tests/support` table (not inline magic numbers).

## Out of Scope
- Story 014: the real chunk library `chunk_library_01.tres`.

## QA Test Cases
- **Smoke check**: shipped values
  - Setup: run `python tools/ci/run_ci.py`. Verify: the test loads the `.tres` and asserts the four knobs and a clean `validated()`. Pass condition: exact equality (1e-9 for floats), no unexpected log line.

## Test Evidence
**Story Type**: Config/Data
**Required evidence**: smoke check pass `production/qa/smoke-[date].md`, backed by `tests/integration/pattern_difficulty/pattern_difficulty_shipped_config_test.gd`
**Evidence**: `tests/integration/pattern_difficulty/pattern_difficulty_shipped_config_test.gd` (AC-22); shipped file `assets/data/pattern_config.tres`.

## Dependencies
- Depends on: Stories 001, 008
- Unlocks: Story 013
