# Story 013: SP-3 death-frame write latency (device)

> **Epic**: Save & Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-006` (immediate synchronous write)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: The write stays inside `set_value`. SP-3 measures the whole path (build `ConfigFile`, `save`, `rename`) on a mid-tier Android phone: p95 at most 3 ms over at least 1000 writes, maximum reported (at most 8 ms expected), idle and during a hit-frame replay. Pre-committed failure response: `set_value` only marks dirty and `GameRoot` calls `save.flush_dirty()` as the last step of the same tick (after `Menus.tick`).
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Flash journal stalls appear only in the tail; use microsecond timestamps from the injected `clock_us`, not frame time. Write-behind to `app_backgrounded` is rejected.
**Control Manifest Rules (this layer)**:
- Required: measure the full `set_value` path; include the 10-second slider-drag negative control with commit on `drag_ended`.
- Forbidden: write-behind to `app_backgrounded`; `set_value` on every `value_changed`.
- Guardrail: 16.6 ms frame budget at 60 FPS.

## Acceptance Criteria
- [ ] Over at least 1000 `set_value` writes idle: p95 <= 3 ms; maximum reported and <= 8 ms expected.
- [ ] Repeated during a hit-frame replay with Juice effects running: same p95 bound.
- [ ] A 10-second slider-drag run with commit on `drag_ended` produces exactly one write (negative control for the Settings/Menus constraint).
- [ ] If the budget is missed, the pre-committed deferred-flush change is recorded as a follow-up story and AC-6 is reworded (Story 004).

## Implementation Notes
Measure around `set_value` using `Time.get_ticks_usec()` in the harness (the harness may use `Time.`; `SaveCore` may not). Record device model, Android version, storage type. Same device session as Story 012. Gate: first-playable.

## Out of Scope
- Story 012: kill safety. Implementing the deferred flush (only if SP-3 fails).

## QA Test Cases
- **Setup**: release-like build on a mid-tier phone; harness writing 1000 values; separate hit-replay scene.
- **Verify**: p50, p95, p99, max per run; write count for the slider run.
- **Pass condition**: p95 <= 3 ms in both runs; slider run writes once.
- Edge cases: first write after boot (cold cache); battery saver on.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/save-persistence-sp3.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 009; same device session as Story 012; cross-epic: Juice hit-frame replay (if not available, idle run only and note)
- Unlocks: first-playable gate (blocking); the Scoring and Settings epics' slider decision
