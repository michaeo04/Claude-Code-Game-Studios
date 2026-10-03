# Story 006: Restart lock, press_us handling and restart_unlocked

> **Epic**: Run State & Restart
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-013`, `TR-run-state-restart-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0005: Sensor source and input pipeline (primary, `press_us` stamping); ADR-0002 (injected clock)
**ADR Decision Summary**: `press_us` is stamped with `Time.get_ticks_usec()` in the input handler (`_gui_input`), from `InputEventScreenTouch` pressed only, never also the emulated mouse event; a stock Button stamps in `button_down`; each tap is stamped once.
**Engine**: Godot 4.7.2 | **Risk**: HIGH (input emulation, verified on device by ADR-0005 spikes; this story is the pure core side)
**Engine Notes**: input events carry no hardware timestamp; with `emulate_mouse_from_touch` on one tap gives a mouse event then a touch event (ADR-0005 Verification item 4). The stamping handlers belong to HUD and Menus; this story tests the core's use of `press_us` only.
**Control Manifest Rules (this layer)**:
- Required: stamp with the injected clock only; `emulate_mouse_from_touch` stays true; use `_gui_input`
- Forbidden: a global `_input` with `Time.get_ticks_usec()` to stamp; buffering or replaying presses
- Guardrail: the lock is judged on `press_us - hit_us >= RESTART_LOCK_us`, never on when the request is processed

## Acceptance Criteria
- [ ] **AC-12**: with a hit at 10,000,000 and a lock of 500,000, presses at 10,499,000 (processed at 10,520,000) and 10,499,999 are rejected; 10,500,000, 10,500,001 and 10,517,000 are accepted; `restart_unlocked` is emitted once over 1000 ticks and re-arms for each Hit and is not emitted on a tick in which an accepted restart or menu request already left Hit; `menu_requested` behaves the same; a press stamped 10,400,000 and still held at 10,600,000 sends no accepted request; a `press_us` of 0 or negative is replaced by `now_us` with one error, one in the future is clamped to `now_us` with one error (the log is asserted)

## Implementation Notes
`RESTART_LOCK_us = round(RESTART_LOCK * 1e6)`. A missing or non-positive `press_us` is replaced by `now_us`, a future one clamped to `now_us`, each with one error log; the result inside the lock is still rejected (debug). `restart_unlocked(run_id)` emits once per Hit at the timers step of the first tick where `now_us - hit_us >= RESTART_LOCK_us` and the phase is still Hit. Hit never times out (add a regression row with a very long idle, a known gap in test-plan section 6). There is no buffering of presses. The tap catcher itself (one request per tap, duplicate emulated tap) is a deferred HUD/Menus check (GDD D2), not part of this story.

## Out of Scope
- Story 007: the Paused guard (same math, separate anchor)
- Story 010: lock clamping and `LOCK_MIN`/`LOCK_MAX`
- HUD epic: the tap catcher and locked-state cue

## QA Test Cases
- **AC-12**: lock arithmetic
  - Given: Hit entered at 10,000,000, lock 500,000
  - When: the listed presses are sent and processed at the listed times; 1000 ticks run
  - Then: accept/reject matches the list; `restart_unlocked` once
  - Edge cases: `press_us` 0, negative, future (one error each); held press from 10,400,000 never converts; second Hit re-arms the unlock; hit never times out

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/run_state/run_state_restart_lock_test.gd`
**Evidence**: `tests/unit/run_state/run_state_restart_lock_test.gd` (19 tests, passing): AC-12 lock arithmetic for restart and menu, one unlock over 1000 ticks, re-arm, no unlock on the leaving tick, held press, press_us 0/negative/future, Hit never times out.
**Status**: [x] Created and passing

## Dependencies
- Depends on: Stories 002, 003, 005
- Unlocks: Stories 009, 011
