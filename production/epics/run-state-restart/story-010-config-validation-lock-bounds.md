# Story 010: RunConfig validation and lock bounds

> **Epic**: Run State & Restart
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (config injected by the composition root); ADR-0009: Test framework and CI (unit tests build resources with `.new()`)
**ADR Decision Summary**: The core receives a validated config object and an injected plain number `hitstop_actual`; Run State never calls Juice. Unit tests build resources with `RunConfig.new()`, not by loading `.tres`.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `RunConfig` is a `Resource` with scalar fields only; `validated(log_sink)` returns a clamped copy via `duplicate()` and never mutates the loaded instance (same pattern as `EnvConfig`, ADR-0004).
**Control Manifest Rules (this layer)**:
- Required: gameplay values data-driven in a config resource; validation logs one error per correction at startup
- Forbidden: reassigning fields on a loaded resource instance
- Guardrail: exact `==` for integer microsecond values, 1e-6 for floats

## Acceptance Criteria
- [ ] **AC-14**: `LOCK_MIN` 0.45 and `LOCK_MAX` 0.60 with the default inside; a lock of 0.3 is clamped to 0.45 and 0.9 to 0.60; countdown 0.5 to 1.0; stall threshold 0.2 to 0.5; `DT_MAX` 0.02 to 0.05 and 0.4 to 0.25; `PAUSE_INPUT_GUARD` 0.05 to 0.2 and 2.0 to 0.5; NaN and INF for each value are replaced by the default; `LOCK_MIN > LOCK_MAX` (through the `t_restart_30fps` field) uses `LOCK_MIN`; `RESTART_LOCK - hitstop_actual < T_READ` raises the lock to `hitstop_actual + T_READ` capped at `LOCK_MAX` (include the `hitstop_actual` 0.5 cap case); each case logs one error at startup

## Implementation Notes
Create `src/core/run_state/run_config.gd` (Resource) and a default `assets/data/run_config.tres`. Order: NaN/INF to default, then clamp to the safe range with one error each. `STALL_PAUSE_THRESHOLD` must stay at least 2 x `DT_MAX`. Config fields: `restart_lock`, `pause_input_guard`, `resume_countdown`, `dt_max`, `stall_pause_threshold`, `hitstop_actual`, `t_restart_30fps` (test-plan section 1). Open point from test-plan section 6: decide one source for the hitstop term of `LOCK_MIN` (constant `HITSTOP_MAX` in F4 versus injected `hitstop_actual` in Tuning Knobs) and record it in the test. Constants `HITSTOP_MAX`, `T_READ`, `T_REACT`, `T_STOP`, `FRICTION_MAX`, `RESTART_BUDGET` live in the config script as named constants with the GDD rationale in comments. `DT_MAX` is shared with Tube Track's `t_lat`; it stays owned here (GDD Open Question 9).

## Out of Scope
- Story 006: using the validated lock at runtime
- Composition-root epic: pushing `hitstop_actual` from Juice/Settings

## QA Test Cases
- **AC-14**: validation table
  - Given: `RunConfig.new()` with each out-of-range, NaN and INF value
  - When: `validated(log_sink)` runs
  - Then: each value equals the clamped or default value; one error per correction
  - Edge cases: `LOCK_MIN > LOCK_MAX`; lock raise capped at `LOCK_MAX`; shipped `.tres` passes with zero errors (integration round trip)

## Test Evidence
**Story Type**: Config/Data
**Required evidence**: smoke check pass `production/qa/smoke-[date].md` plus `tests/unit/run_state/run_state_config_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001
- Unlocks: Story 006 (final lock value), Story 011
