# Story 011: t_dodge_worst config supply to Tube Track

> **Epic**: Pattern & Difficulty
> **Status**: Blocked
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

> **BLOCKED**: `TR-pattern-difficulty-014` is Partial in `docs/architecture/architecture-traceability.md` ("t_dodge_worst supply to Tube Track is not in the MapConfig or from_map path", ADR-0004). No ADR names the carrier field. Unblock when ADR-0004 (or an amendment) fixes where `t_dodge_worst` travels (`MapConfig` field or the `TubeConfig.from_map` path) and Tube Track F9 names its reader. The config guards of TR-014 are already in Story 001.

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (Core Rule 10; AC-16)
**Requirement**: `TR-pattern-difficulty-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary, partial coverage); ADR-0008: Hazard, collision and content format
**ADR Decision Summary**: Cross-layer values travel as configuration at map load because Core must not call up; `t_dodge_worst` = `T_DODGE_180` is a configuration value, never derived per chunk.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: None post-cutoff. Reuse the carrier chosen in the ADR amendment.
**Control Manifest Rules (this layer)**:
- Required: `t_dodge_worst` read once at config load from `T_DODGE_180` (Ball Movement `BallMath.T(PI, 0.05, ...)`); supplied as configuration at map load.
- Forbidden: per-chunk derivation or any runtime recomputation in the `hazards_for_segment` path; Core calling up.
- Guardrail: zero per-tick cost.

## Acceptance Criteria
- [ ] **AC-16** `PatternConfig.t_dodge_worst` equals `T_DODGE_180` (1.064 at fixture defaults) exactly, read once at config load; a property scan of `PatternCore`'s `hazards_for_segment` path confirms no chunk-specific recomputation of this value.
- [ ] The value reaches Tube Track through the carrier fixed by the ADR amendment (assertion defined when unblocked).

## Implementation Notes
Add the field and a read-only accessor to `PatternConfig`; the Tube Track side is read by the Tube Track epic's F9 budget, so only the supply is implemented here. Do not add a second source of truth for `T_DODGE_180`.

## Out of Scope
- Tube Track F9 consumption (tube-track epic). The config guards (Story 001).

## QA Test Cases
- **AC-16**: fixed value, no per-chunk derivation
  - Given: fixture config (T_DODGE_180 1.064). When: loaded; `hazards_for_segment` path scanned (script reflection or call-count spy on the derive function). Then: value equals exactly; the derive function has zero calls inside the provider path.
  - Edge cases: changing `OMEGA_MAX`/`BALL_LAG_TAU` changes the loaded value but nothing at call time.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/pattern_difficulty/pattern_difficulty_t_dodge_worst_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: ADR-0004 amendment naming the carrier (external gate); Stories 001, 006; map-loader `MapConfig`
- Unlocks: tube-track F9 visibility budget wiring
