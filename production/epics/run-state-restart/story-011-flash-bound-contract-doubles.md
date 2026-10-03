# Story 011: Flash bound bot and contract doubles

> **Epic**: Run State & Restart
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-025`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary); ADR-0002 (injected clock)
**ADR Decision Summary**: Unit tests are deterministic with an injected clock and no file I/O; fakes live in `tests/support/` as plain RefCounted with no GUT call.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none.
**Control Manifest Rules (this layer)**:
- Required: GUT `extends GutTest`, `test_[scenario]_[expected]`, injected clock starting well above 0
- Forbidden: random seeds, time-dependent assertions; skipping or marking a failing test pending
- Guardrail: the art-bible cap is 3 flashes per second; margin is zero at the minimum lock

## Acceptance Criteria
- [ ] **AC-24** (BLOCKING): a bot on the injected clock at 60 fps hits at a fixed run time and restarts at the earliest allowed press (`press_us = hit_us + RESTART_LOCK_us`); over 300 cycles every hit-to-hit interval is strictly greater than `RESTART_LOCK`, at most 2 `run_ended` fall in any closed 1.0 s window at the default lock and at most 3 at the minimum lock 0.45
- [ ] **AC-25**: with doubles for Ball Movement, Obstacle System, Juice and Scoring (contract only), 1000 scripted hit and restart cycles give each double exactly one reset per run and a constant number of signal connections, and a `hit_reported` sent from a `run_started` handler is rejected

## Implementation Notes
Per test-plan section 6: state the fixed run time, assert exact counts (a cycle of 32 ticks gives exactly 2 hits per closed second at the default lock, 29 ticks exactly 3 at the minimum lock 0.45; re-derive before coding) and sweep the lock {0.45, 0.5, 0.6} and fps {30, 60, 120} instead of 300 identical cycles. The plan also notes AC-25 duplicates AC-5 and AC-6 and the doubles verify themselves: keep it small (reset-count and connection-count assertions) or fold it into the AC-24 test, but do not drop the constant-connection-count check. Doubles are plain RefCounted in `tests/support/run_state_doubles.gd`.

## Out of Scope
- Story 014: the on-device flash count from a screen recording
- Story 012: real subscribers from `GameRoot._wire()`

## QA Test Cases
- **AC-24**: flash bound
  - Given: a core at the lock {0.45, 0.5, 0.6} and fps {30, 60, 120} with the bot
  - When: 300 cycles run
  - Then: every interval exceeds the lock; the per-window maxima hold
  - Edge cases: window boundaries are closed (both ends included)
- **AC-25**: doubles
  - Given: four doubles connected once
  - When: 1000 hit/restart cycles run
  - Then: one reset per run each; connection count constant; hit from a `run_started` handler rejected

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/run_state/run_state_flash_bound_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 003, 004, 005, 006, 008, 009, 010
- Unlocks: Story 014
