# Story 001: PlatformMath pure functions (haptic gate, effective, interval, fps)

> **Epic**: Platform Services
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/platform-services.md`
**Requirement**: `TR-platform-services-002`, `TR-platform-services-008`, `TR-platform-services-009`, `TR-platform-services-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: Logic lives in engine-free GDScript (`PlatformMath` static functions) behind the one `PlatformServices` node; the haptic gate, effective duration/amplitude and effective frame rate are pure functions tested without a SceneTree.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure GDScript, no post-cutoff API. Static typing on every parameter and return (NaN/inf handled explicitly with `is_nan` / `is_inf`).
**Control Manifest Rules (this layer)**:
- Required: cores are RefCounted/static with injected seams and no SceneTree; numeric test tolerances exact `==` for integers/codes, `1e-6` for floats; fixtures from a named factory function, not a `.tres` load.
- Forbidden: no `Input.`, `DisplayServer.`, `ProjectSettings.`, `Engine.`, `Time.`, `OS.` or `get_tree` inside `PlatformMath`; no hardcoded gameplay values.
- Guardrail: frame time 16.6 ms; `max_fps` 60.

## Acceptance Criteria
- [ ] **AC-3 [M]** `haptic_gate(enabled, attentive, dur, prio, now, last, last_end, last_prio, min_us)` returns the play/drop decisions listed in the GDD (interval boundary 49999/50000/50001, pulse-end boundary 60000/80000, priority bypass 2/1/0, clock anomaly now < last, `min_us` 0 case, enabled/attentive false and dur 0/-1 drop even with prio 9); `interval_us(0.05, 0.08, 0.5, 0)` = 50000, 80000, 500000, 0.
- [ ] **AC-5 [M]** `effective(dur, amp, max)` exact values: dur 500, 201, 200, 1, 0, -5 give 200, 200, 200, 1, 0, 0; amp 0.5, 0, 1, 1.0000001, 2, -0.0001, -1 give 0.5, 0, 1, 1, 1, -1, -1; max 50 with dur 80 gives 50.
- [ ] **AC-8 [M]** (ADVISORY) `fps_eff(max, hz)` and `frame_time` per the GDD table: (60,60)=60; (60,120)=60; (60,30)=30; (60,0), (60,-1), (60,NaN), (60,+inf)=60; (60,59.94)=59.94; (0,120)=120; (-1,120)=120; (0,0) and (0,+inf)=0 with `frame_time` 0 and no division.

## Implementation Notes
`PlatformMath` is a static class (no state) holding `haptic_gate`, `effective`, `interval_us`, `fps_eff`, `frame_time` (and `fis_for_platform`, built in Story 008). F2: `gate_open = last is none or now < last or (now - last >= min_us and now >= last_end)`; `play = enabled and attentive and dur_eff > 0 and (gate_open or prio > last_prio)`; both comparisons inclusive. F3: `dur_eff = clamp(dur, 0, max)`; `amp_eff = -1` if `amplitude < 0` (sentinel applied before the intensity scale), else `clamp(amp, 0, 1)`; the `* haptics_intensity` scale and the Android level `clamp(int(amp * 255), 1, 255)` are applied by the caller/engine, not tested here. `interval_us` is `roundi(x * 1e6)` on the seconds-to-microseconds conversion, once. F4: `fps_eff = min(max_fps, refresh)` when both positive and finite; `max_fps` when refresh unknown; `refresh` when `max_fps <= 0` and refresh known; else 0. The fixture is a named factory (MIN_INTERVAL 0.05, HAPTIC_MAX_MS 200, screen 1080x1920).

## Out of Scope
- Story 003: HapticsConfig validation and shipped defaults
- Story 005: PlatformCore haptic call flow and drop counters
- Story 008: `fis_for_platform`

## QA Test Cases
- **AC-3**: gate decisions
  - Given: `min_us` 50000, last 0 (last_end 30000, last_prio 1) and the other GDD rows
  - When: `haptic_gate` is called for each listed `now`/`prio`
  - Then: results match the GDD row by row (e.g. 49999 drops, 50000 and 50001 play; prio 2 plays at 20000, prio 1 and 0 drop)
  - Edge cases: `now < last` plays; `min_us` 0 with last_end 130000: 129999 drops, 130000 plays; `dur` -1 and 0 drop at prio 9
- **AC-5**: effective values
  - Given: `max` 200 (and 50 for the last row)
  - When: `effective` is called with the listed values
  - Then: exact equality with the listed outputs (so 1.0000001 clamps to exactly 1)
  - Edge cases: -0.0001 and -1 both give the sentinel -1
- **AC-8**: effective fps (ADVISORY)
  - Given: `max_fps` and refresh values from the table
  - When: `fps_eff` and `frame_time` are called
  - Then: values equal the table; 59.94 compared as 1000/59.94, not 16.683
  - Edge cases: NaN and +inf refresh; `max_fps` 0 and -1; both unknown returns 0 with no division

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/platform_services/platform_services_math_test.gd` (must pass)
**Status**: [x] Created, passing (17 tests)
**Evidence**: `tests/unit/platform_services/platform_services_math_test.gd`: AC-3 `test_gate_*` and `test_interval_us_converts_seconds_once`; AC-5 `test_effective_*`; AC-8 `test_fps_eff_*` and `test_frame_time_*`. Signatures: `haptic_gate(...) -> bool` (`last = NO_LAST_US` (-1) means none; `dur` is the already-effective duration), `effective(dur, amp, max_ms) -> Vector2(dur_eff, amp_eff)`, `interval_us(seconds) -> int` (one argument), `frame_time(fps) -> float` ms.

## Dependencies
- Depends on: test-harness-ci story 002 (GUT confirmed on 4.7.2, spike T-1)
- Unlocks: Story 005, Story 008
