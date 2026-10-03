# Story 002: BallConfig resource, shipped defaults and test fixtures

> **Epic**: Ball Movement
> **Status**: Complete
> **Layer**: Core
> **Type**: Config/Data
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/ball-movement.md`
**Requirement**: `TR-ball-movement-003`, `TR-ball-movement-020`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary); ADR-0013: Distance precision and the render origin (secondary, `D` owner feeds `WorldGeometry`)
**ADR Decision Summary**: Factories and fakes live in `tests/support/` as plain `RefCounted` with no GUT calls; unit tests build resources with `.new()` rather than loading `.tres`. `D` has one owner (Ball Movement) and `WorldGeometry` is built from `BallConfig`.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `@export` float fields keep float64 in text `.tres` is NEEDS VERIFICATION (ADR-0008); the round-trip test of `ball_config.tres` covers it.
**Control Manifest Rules (this layer)**:
- Required: every gameplay value lives in `BallConfig` (a `Resource`), never in code; `tests/support/` helpers are plain RefCounted, preloaded with `const X = preload(...)`.
- Forbidden: GUT calls or `Double`/`Spy` names in `tests/support/`; unseeded randomness; hardcoded knob values outside the resource and fixture.
- Guardrail: shipped `ball_config.tres` equals the Tuning Knobs table; fixtures deterministic (fixed LCG).

## Acceptance Criteria
- [x] `BallConfig` (`Resource`) exposes every Tuning Knob with its default: `STEER_ARC` PI, `BALL_LAG_TAU` 0.06, `OMEGA_MAX` 3.0, `MAPPING_MODE` POSITION, `V_START` 10, `V_MAX` 25, `T_RAMP` 90, `BALL_DIAMETER` 0.8 (GDD Tuning Knobs; clamping is Story 003).
- [x] `assets/data/ball_config.tres` exists with the Tuning Knobs defaults and loads with those values (round-trip, integration).
- [x] Fixture contract (GDD AC preamble, TR-020): `make_ball_fixture()` returns the config above; `make_core(cfg, dt_max=0.1)` and `make_sink()` (records level, code, message) exist; steer tables live in one constants file; pseudo-random tables use a fixed LCG; no inline magic numbers in tests.
- [x] `tools/reference-sim/ball_movement.js` is documented as the oracle source (header comment listing which ACs use it); no new oracle logic is invented in tests.

## Implementation Notes
`src/core/ball_movement/ball_config.gd` (`class_name BallConfig extends Resource`, scalar `@export` fields with range hints equal to the safe ranges). `MAPPING_MODE` is an enum with explicit integer values. Support files: `tests/support/ball_fixtures.gd` (factory functions), `tests/support/ball_steer_tables.gd` (constants), `tests/support/ball_sink.gd` (recording `log_sink`). `make_core` is a stub until Story 004 creates `BallCore`. The round-trip test goes under `tests/integration/ball_movement/ball_movement_config_resource_test.gd`.

## Out of Scope
- Story 003: `validated()` and clamping
- Story 004: the `BallCore` the fixtures construct

## QA Test Cases
- **AC-1 (defaults)**: knob defaults
  - Given: `BallConfig.new()`
  - When: each field is read
  - Then: equals the Tuning Knobs default
  - Edge cases: `MAPPING_MODE` enum values explicit
- **AC-2 (round trip)**: shipped resource
  - Given: `assets/data/ball_config.tres` loaded in an integration test
  - When: fields are compared to `make_ball_fixture()`
  - Then: all equal to 1e-12
  - Edge cases: float64 precision of `STEER_ARC`
- **AC-3 (fixtures)**: factories
  - Given: `make_sink()`
  - When: two entries are logged
  - Then: the sink records level, code, message in order
  - Edge cases: LCG table identical on repeated calls

## Test Evidence
**Story Type**: Config/Data
**Required evidence**: smoke check pass `production/qa/smoke-[date].md` plus `tests/integration/ball_movement/ball_movement_config_resource_test.gd`
**Status**: [x] Created and passing
**Evidence**: `tests/integration/ball_movement/ball_movement_config_resource_test.gd` (2 tests, AC-2) and the AC-1/AC-3 tests in `tests/unit/ball_movement/ball_movement_config_test.gd`. The dated `production/qa/smoke-[date].md` file is not written (advisory; the round-trip test covers the same ground).

## Dependencies
- Depends on: test-harness-ci (GUT, scaffold)
- Unlocks: Story 003, Story 004, Story 005 and every later test file; composition-root (`WorldGeometry` reads `D`)
