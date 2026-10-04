# Story 004: step(): non-finite, negative, over-range and decreasing s

> **Epic**: Scoring & Personal Best
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `GameRoot` is the only node that runs a per-frame callback and calls systems in one fixed order; cores are RefCounted with injected seams, no autoloads. GUT 9.x runs the Logic tests.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Converting a non-finite or over-range float through `floori()` is undefined-behavior-adjacent in GDScript and does not raise a catchable error, so the check must come before the conversion, never after.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [x] **AC-15** `NAN` then `INF` via `s_seam` mid-session leave `current_score` at its last known-good value on every affected tick; an ending right after captures that value as `final_score` and, if it writes, passes that integer (never NaN or INF) to `set_value_seam`. Companion rows: a negative finite `-5.0` holds; a finite non-negative decreasing sequence `500.0, 490.0` holds at 500; a finite `1e19` holds with no garbage integer. Recovery rows: `500, 490, 495, 510` publishes 500, 500, 500, 510; `500, NaN, 510` publishes 500, 500, 510; `s = 9.2e18` exactly is accepted, just above it holds.

## Implementation Notes
- Guard order in `step()`: `is_finite(s) and s >= 0.0 and s <= 9.2e18`, then `floori(s)`, then hold if `floori(s) < current_score`. Check before converting, never after.
- The "last known-good value" is `current_score` itself; there is no `last_s` tracker, so `on_run_reset()` clears the memory automatically.
- The `9.2e18` bound is crash-safety only; a finite spike below it is not defended against here.
- A held frame leaves everything unchanged and fires nothing.

## Out of Scope
- Story 003: the normal path and reset. Story 005: the ending handlers (this story only asserts what they capture).

## QA Test Cases
- **AC-15**: guards and recovery
  - Given: stubs for each row above on a fresh core
  - When: `step()` runs per value, then `on_run_ended` where stated
  - Then: scores match the listed sequences; the `set_value_seam` argument is a finite int
  - Edge cases: `9.2e18` accepted vs just above held; NaN as the first step after a reset holds 0

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/scoring_personal_best/scoring_personal_best_guards_test.gd`
**Status**: [x] Created
**Evidence**: scoring_personal_best_guards_test.gd (AC-15 rows)

## Dependencies
- Depends on: Story 003; the ending assertions in AC-15 use story 005 (write the ending-dependent rows after it, or stub the handler)
- Unlocks: Story 008
