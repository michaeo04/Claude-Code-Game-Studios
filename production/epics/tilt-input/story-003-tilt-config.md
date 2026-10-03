# Story 003: TiltConfig resource, validation and sensitivity hook

> **Epic**: Tilt Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-005`, `TR-tilt-input-020`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (fixtures, determinism); ADR-0002: Game loop, Composition Root and tick order (secondary)
**ADR Decision Summary**: Gameplay values are data-driven (a `TiltConfig` Resource), validated once at load; tests use distinct fixtures and deterministic assertions.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `TiltConfig` is a typed `Resource` with scalar exports only; never `duplicate_deep()`. `get_setting` is called with an explicit default.
**Control Manifest Rules (this layer)**:
- Required: gameplay values are data-driven (`TiltConfig`), not hardcoded; typed exports; one `KNOB_CLAMPED` log per knob changed.
- Forbidden: `TiltConfig.unvalidated()` referenced from `src/` (lint 37e); `duplicate_deep()`.
- Guardrail: validation runs once at load, never per frame.

## Acceptance Criteria
- [ ] **AC-4 [C]**: `FILTER_TAU` 0 or -1 in a loaded config is clamped to 0.02 with one `KNOB_CLAMPED` error.
- [ ] **AC-8 [C]**: sensitivity NaN, INF, 0 or -1 behaves as 1 (`phi_f` 14 gives 0.531915) with one `KNOB_CLAMPED` error each; 3 equals 2 and 0.1 equals 0.5, each with one `KNOB_CLAMPED`; 0.5 and 2.0 give none.
- [ ] **AC-36 [C]**: table-driven, one row per knob, with its own fixture where the boundary depends on another knob: below-range and above-range values are clamped with one `KNOB_CLAMPED` each; boundary values give none (DZ 4 needs FS >= 26.7, so its row uses FS 30; `N_min` 6 needs W >= 0.3); cross-knob rows: W 0.15 with `N_min` 5 gives `N_min` 3; DZ 4 with FS 12 gives DZ 1.8; `CURVE_EXP` 0.5 gives 1; G 0.35 with W 0.6 gives W 0.55; SETTLE 1.0 with G 0.25 and W 0.3 gives SETTLE 0.45; `sensor_sign` 0 or 2 gives the platform's expected value (-1); a NaN or INF knob takes its default; `REANCHOR_OFFSET` 7 gives 8 and 17 gives 16 (one `KNOB_CLAMPED` each; 8 and 16 give none); `REANCHOR_SPREAD` boundaries give none.

## Implementation Notes
Knobs and defaults are in the GDD Tuning Knobs table (FS 25, DZ 1.5, tau 0.05, k 1, W 0.3, G 0.25, N_min 5, `REANCHOR_OFFSET` 12, `REANCHOR_SPREAD` 3.0, `G_MIN` 3, timeout 2.0, settle 0.3, HOLD 0.1, `FALLBACK_SLEW` 4, `sensor_sign` -1). `PHI_MAX`, `FS_EFF_MAX`, `F_MIN`, `BUFFER_AGE`, `TAU_FLOOR`, `DROPOUT_MIN_POLLS` and `REANCHOR_FS_CAP` are constants, not fields. `validated()` applies rule 14 in order: (1) clamp each knob to its own range (non-finite takes default); (2) if `G + W > 0.9` (integer microseconds) reduce W to `0.9 - G`; (3) clamp SETTLE to at most `1.0 - G - W`; (4) clamp `N_min` to at most `floor(W * F_MIN)` in integer microseconds (0.15 s at 20 Hz gives 3); (5) clamp DZ to at most `0.15 * FS`. Durations are converted once with `roundi(x * 1e6)`. Sensitivity hook: NaN/INF/<=0 becomes 1, finite clamps to [0.5, 2.0], one `KNOB_CLAMPED` each. A test-only `unvalidated()` bypasses validation. Logging goes through the injected `log_sink(level, code, detail)`.

## Out of Scope
- Story 013: the production log sink rate limiter (AC-42).
- Story 005: applying the config inside the pipeline.

## QA Test Cases
- **AC-4 [C]**: Given tau 0 / -1; When `validated()`; Then tau 0.02 and exactly one `KNOB_CLAMPED`.
- **AC-8**: Given sensitivity each of NaN, INF, 0, -1, 3, 0.1, 0.5, 2.0; When validated; Then effective values 1/1/1/1/2/0.5/0.5/2 and the stated `KNOB_CLAMPED` count (0 for 0.5 and 2.0)
  - Edge cases: `phi_f` 14 gives 0.531915 after the clamp
- **AC-36**: Given the table (one fixture per row); When validated; Then clamped value and one log per knob, none on boundaries
  - Edge cases: order dependence of rule 14 (W reduced before `N_min` and SETTLE)

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tilt_input/tilt_config_validation_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002
- Unlocks: Story 004, Story 005
