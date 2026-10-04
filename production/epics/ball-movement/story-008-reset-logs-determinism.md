# Story 008: Reset conformance, log-code census and bit-identical determinism

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/ball-movement.md`
**Requirement**: `TR-ball-movement-011`, `TR-ball-movement-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary); ADR-0002: Game loop, Composition Root and tick order (`run_reset` rank 3 for Ball)
**ADR Decision Summary**: `run_reset` is a `_wire()` row (rank 3 for Ball) calling `BallCore.reset()` synchronously; tests assert no shared static state and exact log codes.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `Performance.get_monitor(Performance.OBJECT_COUNT)` is used for the allocation check; verify it behaves under the headless GUT runner.
**Control Manifest Rules (this layer)**:
- Required: `reset()` has no loop, allocation, `.new()` or `load(` in its body; same input sequence gives bit-identical output; the driver's sink (not the core) rate-limits logs.
- Forbidden: `static var` shared state; randomness; a rate limiter inside the core.
- Guardrail: reset budget about 1 ms on the mid-tier Android target (measured on device, ADVISORY).

## Acceptance Criteria
- [ ] **AC-1 [C]** (R1, R9) A fresh core has `theta`, `theta_prev`, `s`, `s_prev`, `t_run`, `omega`, `phi_anchor`, `w` and the held steer at 0, `speed` 10 and `radius` 0.4. After 100 mixed steps, an armed re-base and a latched mode, `reset()` equals a fresh core field for field (latch cleared, re-base disarmed).
- [ ] **AC-18 [C]** (R13) The log codes are exactly `BAD_DT`, `DT_OVER_MAX`, `BAD_STEER`, `KNOB_CLAMPED`, all error level; a 60-frame NaN stream gives 60 lines (the limiter is the driver's); the sine run and the AC-22 run give zero lines.
- [ ] **AC-24 [C]** (R12) Two fresh cores fed the same 1000-step table (NaN, invalid, `dt` 0, resumes, resets) are bit-identical after every step; a third core interleaved changes nothing.
- [ ] **AC-27 [C + V]** (R9) 1000 `reset()` calls leave `OBJECT_COUNT` unchanged and the reset body has no loop, `.new()` or `load(` (checked by the Story 009 lint); the device part [V], ADVISORY: the maximum over 1000 calls is at most 1 ms on the mid-tier Android target, recorded in `production/qa/evidence/ball-movement/ac-27-reset-timing.md`.

## Implementation Notes
Add a `BallCore` snapshot helper for tests only if needed (a field-by-field equality helper in `tests/support/ball_fixtures.gd`, not a public API). The determinism replay table uses the fixed LCG from Story 002. The device timing is measured with the Story 013 harness; mark it ADVISORY and do not block the story on the device. Tests: `tests/unit/ball_movement/ball_movement_reset_determinism_test.gd`.

## Out of Scope
- Story 009: the lint that scans the reset body
- Story 010: `_wire()` rank and driver order

## QA Test Cases
- **AC-1**: reset equals fresh
  - Given: a used core (steps, armed re-base, latched mode)
  - When: `reset()`
  - Then: every field equals a fresh core's
  - Edge cases: latch and re-base flag cleared
- **AC-18**: codes census
  - Given: NaN stream of 60 frames, the sine run, the AC-22 run
  - When: logs collected
  - Then: 60 / 0 / 0 lines; codes limited to the four listed
  - Edge cases: level always error
- **AC-24**: replay
  - Given: three cores, one interleaved
  - When: 1000-step table
  - Then: bit-identical every step
  - Edge cases: includes resets and resumes
- **AC-27**: allocation
  - Given: object count before
  - When: 1000 `reset()` calls
  - Then: count unchanged
  - Edge cases: device timing is advisory evidence only

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/ball_movement/ball_movement_reset_determinism_test.gd` (must pass); device part `production/qa/evidence/ball-movement/ac-27-reset-timing.md` (advisory)
**Status**: [~] Tests created and passing (AC-1, AC-18, AC-24, AC-27 automated allocation part). Gap: AC-27 lint on the reset body (Story 009) and the advisory device timing evidence (`ac-27-reset-timing.md`, Story 013 harness) are not done, so the story stays Ready.

## Dependencies
- Depends on: Story 005, Story 006, Story 007
- Unlocks: Story 009 (lint relies on final reset body), Story 010
