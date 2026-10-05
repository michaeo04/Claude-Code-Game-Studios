# Story 001: PatternConfig, tier selection, config guards and pattern fixture

> **Epic**: Pattern & Difficulty
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (Core Rule 2; Formula F1; Edge Cases on tier durations and threshold)
**Requirement**: `TR-pattern-difficulty-001`, `TR-pattern-difficulty-004`, `TR-pattern-difficulty-014` (config guards only; the `t_dodge_worst` supply is Story 011)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (primary); ADR-0009: Test framework and CI; ADR-0004: Map Loader and MapConfig (`PatternConfig` stays in its own `.tres`)
**ADR Decision Summary**: Logic is split into pure static `PatternMath`, a `RefCounted` `PatternCore` and a validated `PatternConfig`; per-build knobs stay in their own `.tres` file, a map contributes only what varies per map.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Float exports must keep float64 values (`PI/2`, `1.0472`); assert exact values after a disk load (ADR-0008 verification items 1-3, 8). No post-cutoff API is needed here.
**Control Manifest Rules (this layer)**:
- Required: `PatternConfig` is validated and returns stable codes through the 4-argument `log_sink(level, code, key, message)` (`LogLevel`); tier is a pure function of `run_time` (upper boundary inclusive); gameplay values are data-driven.
- Forbidden: autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; module-private log level constants.
- Guardrail: Pure functions, no allocation in per-tick paths.

## Acceptance Criteria
- [ ] **AC-1** `tier(8)` = INTRO; `tier(15.0)` = RAMP; `tier(14.999)` = INTRO; `tier(47)` = RAMP; `tier(90.0)` = FULL; `tier(300)` = FULL. `TIER_INTRO_DURATION` = `TIER_RAMP_DURATION` (both 90) and 91 > 90 are rejected with `TIER_ORDER_INVALID`; 89.999 < 90 is accepted.
- [ ] **AC-1b** `ANGULAR_REVERSAL_THRESHOLD` = `PI/3` and `2*PI/3` accepted; `PI/3 - 0.001` and `2*PI/3 + 0.001`, `0` and `PI` rejected with `ANGULAR_THRESHOLD_OUT_OF_RANGE`.
- [ ] **AC-1c** `TIER_INTRO_DURATION` 8 and 20 accepted, 7.999 and 20.001 rejected; `TIER_RAMP_DURATION` 45 and 240 accepted, 44.999 and 240.001 rejected, all with `TIER_DURATION_OUT_OF_RANGE`; `TIER_INTRO_DURATION` = 0 is independently rejected by the range guard (checked before the ordering guard).

## Implementation Notes
Create `src/core/pattern_difficulty/pattern_math.gd` (static `tier_for(run_time, intro, ramp)` returning `ChunkDef.Tier`) and `pattern_config.gd` (`Resource`, knobs `tier_intro_duration` 15, `tier_ramp_duration` 90, `angular_reversal_threshold` PI/2, `max_opposing_fraction` 0.6) with `validated(log_sink)`. Order of guards: range guards (`TIER_DURATION_OUT_OF_RANGE`) first, then `TIER_ORDER_INVALID`, then `ANGULAR_THRESHOLD_OUT_OF_RANGE`. Use `ChunkDef.Tier` for the tier enum; do not redefine it. Create the shared test fixture `tests/support/pattern_fixture.gd` (`make_pattern_fixture()`, `make_chunk`, `make_content_library`, `make_run_time_stub`, `make_run_id_stub`, `make_core`) with the 8-chunk fixture W1-W4, SP1, DG1, NR1, REV2 from the GDD Acceptance Criteria tables; later stories reuse it. Fixture values come from GDD constants, not magic numbers inline in tests.

## Out of Scope
- Story 003: chunk library compile checks.
- Story 008: `MAX_OPPOSING_FRACTION` use (clustering advisory).
- Story 009: the shipped `PatternConfig.tres`.

## QA Test Cases
- **AC-1**: tier boundaries and ordering guard
  - Given: fixture config (15, 90). When: `tier_for` runs at 8, 14.999, 15.0, 47, 90.0, 300; configs (90,90), (91,90), (89.999,90) validated. Then: INTRO, INTRO, RAMP, RAMP, FULL, FULL; first two rejected with `TIER_ORDER_INVALID`, last accepted.
  - Edge cases: exact `==` on the enum; boundary is inclusive on the upper tier.
- **AC-1b**: threshold range
  - Given: threshold values at and just outside both range ends. When: validated. Then: accepted/rejected as listed with the exact code.
  - Edge cases: `0` and `PI` rejected.
- **AC-1c**: duration ranges
  - Given: duration values at and outside each range. When: validated. Then: exact accept/reject and code; intro 0 rejected by the range guard, not the ordering guard.
  - Edge cases: log line names the offending knob and value (`key`).

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_config_test.gd` (AC-1, AC-1b, AC-1c)
**Status**: [x] Created and passing
**Evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_config_test.gd`. AC-1, AC-1b, AC-1c proven (tier boundaries, order/range/threshold guards). Note: guards run independently, so 90/90 also logs TIER_DURATION_OUT_OF_RANGE (intro 90 is outside 8..20; GDD AC-1 and AC-1c overlap). `make_core` of the fixture arrives with Story 006.

## Dependencies
- Depends on: obstacle-system story 001 (ChunkDef.Tier), test-harness-ci epic (GUT runner), `LogLevel` in `src/core/log/log_level.gd`
- Unlocks: Stories 002 to 014 (config and fixture)
