# Story 002: ObstacleConfig, sweep-invariant validation and test fixtures

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/obstacle-system.md` (Tuning Knobs; Acceptance Criteria fixture block)
**Requirement**: `TR-obstacle-system-001`, `TR-obstacle-system-016`, `TR-obstacle-system-020`, `TR-obstacle-system-024`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (fixtures in `tests/support/`); ADR-0008: Hazard, collision and content format (secondary)
**ADR Decision Summary**: Factories and fakes live in `tests/support/` as plain `RefCounted` with no GUT call; gameplay values live in a data-driven Resource, never in code.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: GUT on 4.7.2 is confirmed by spike T-1 (test-harness-ci epic). Test files reference support code with `const X = preload("res://tests/support/x.gd")`.
**Control Manifest Rules (this layer)**:
- Required: cores are `RefCounted` with injected seams; gameplay values are data-driven; fixtures use distinct non-shipped values where the GDD says so, with an advisory smoke test asserting shipped defaults; `OMEGA_MAX` and `DT_MAX` are injected, never owned.
- Forbidden: engine calls (`Time.`, `Engine.`, `OS.`, `Input.`) in `ObstacleMath/Core/Config`; hardcoded gameplay values.
- Guardrail: determinism, `==` for ints and codes, `1e-6` for floats.

## Acceptance Criteria
- [ ] **AC-13 [K]** `SWEEP_INVARIANT_VIOLATED`: defaults (`OMEGA_MAX` 3.0, `DT_MAX` 0.1) validate with no log; joint safe-range maxima (4.0, 0.25, product 1.0) pass; the illegal row (31.4, 0.1) is rejected with exactly one `SWEEP_INVARIANT_VIOLATED`.
- [ ] **AC-30 [K, ADVISORY]** the shipped `ObstacleConfig.tres` equals the Tuning Knobs table (`GAP_MARGIN` 2.5, `T_REVEAL_MIN` 1.5, `HIDDEN_SPAN_MIN_TIME` 1.44, `MAX_PIECES_PER_SEGMENT` 12) and validates with zero log lines.
- [ ] `make_obstacle_fixture()`, `make_ball_state_stub(theta_prev, theta, s_prev, s)`, `make_content_provider(table)` and the six worked hazards (Spike cluster 101, Wall 301, Double Gate 202, Near-Ring 401, overlap pair 501/502, Picket 601) exist in `tests/support/` (TR-020).

## Implementation Notes
`ObstacleConfig` is a Resource with `GAP_MARGIN` (2.5, range 2.0-3.5), `T_REVEAL_MIN` (1.5), `HIDDEN_SPAN_MIN_TIME` (1.44), `MAX_PIECES_PER_SEGMENT` (12, range 6-20) and `validated(log_sink)`. External inputs `v_max` 25, `OMEGA_MAX` 3.0, `DT_MAX` 0.1 are injected into validation, never redefined here. Fixture: `R` 3.0, `D` 0.8, `L` 12, `VISIBLE_ARC_HALF_WIDTH_TEST` = PI/2 (deliberately different from Camera's 1.0472). Derived: `BALL_HALF_ANGLE` 0.1179, `w` 0.2358, `GAP_MIN` 0.5896, `HIDDEN_SPAN_MIN_S` 36. `make_core(cfg, provider, log_sink)` is added by Story 007 once `ObstacleCore` exists. The GDD gives the safe range of each knob but no rejection code for an out-of-range knob; do not invent one.

## Out of Scope
- Story 007: `make_core` and `ObstacleCore`.
- Story 003 to 006: the validators that consume the config.
- Camera supplying the real `VISIBLE_ARC_HALF_WIDTH`.

## QA Test Cases
- **AC-13**: sweep invariant
  - Given: `ObstacleConfig` with injected `OMEGA_MAX` / `DT_MAX`. When: `validated(log_sink)` runs for the three rows. Then: no log, no log, exactly one `SWEEP_INVARIANT_VIOLATED`.
  - Edge cases: product exactly `PI` (rejected, the check is `< PI`).
- **AC-30**: config smoke (advisory)
  - Given: shipped `.tres`. When: loaded and validated. Then: four values equal the table; log sink empty.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/obstacle_system/obstacle_system_config_test.gd` (AC-13); `tests/advisory/obstacle_system/obstacle_system_config_defaults_test.gd` (AC-30, ADVISORY); fixtures in `tests/support/obstacle_fixture.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001; test-harness-ci epic
- Unlocks: Stories 003 to 007 (all use the fixture)
