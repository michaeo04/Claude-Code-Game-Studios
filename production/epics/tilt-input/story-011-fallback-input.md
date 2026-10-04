# Story 011: Fallback input (unwired) and the state-transition table

> **Epic**: Tilt Input
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-019`, `TR-tilt-input-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0005: Sensor source and input pipeline
**ADR Decision Summary**: The fallback (`fallback_source`) is built and unit-tested in `TiltCore` but not wired by any MVP driver; editor steering uses a synthetic gravity source behind `OS.has_feature("editor")` (Decision 6), never `OS.is_debug_build()`.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `move_toward` is the standard GDScript float helper. Tilt Input reads no touch (rule 13); `fallback_source: Callable() -> int` returns -1, 0 or +1 and is guarded with `is_valid()`.
**Control Manifest Rules (this layer)**:
- Required: fallback is terminal for the session; capture events are no-ops in `FALLBACK`; the core never reads touch or keys itself.
- Forbidden: `InputEventScreen*`/`InputEventMouse*`/`_input` in tilt files (lint 37c); wiring the fallback into a driver in the MVP; `OS.is_debug_build()` in dev-input code.
- Guardrail: `FALLBACK` steering costs no more than the sensor path per poll.

## Acceptance Criteria
- [x] **AC-33 [C]** (debug build, `sensors_enabled` false, one priming poll at stamp 0, then `dt = 1/16`): **33a** `fallback_source` returning +1 gives `steer` 0.25, 0.5, 0.75, 1.0 then holds; **33b** returning 0 it falls to 0 in 4 ticks, returning -1 it gives -1, `valid` true throughout; **33c** a release build that reached `FALLBACK` through a timeout (`sensor_ever_live` false) behaves the same; **33d** a returned value of 2 acts as +1.
- [x] **AC-34 [C]**: sensors live in a debug build: the fallback source leaves `steer` unchanged and `input_source` stays `SENSOR`.
- [x] **AC-47b [C]**: after a timeout into `FALLBACK` (`sensor_ever_live` false), a late valid sample does not return to `SENSOR`: `input_source` stays `FALLBACK` and `phi_f` is unchanged.
- [x] **AC-48 [C]**: a debug-build core in `FALLBACK` (`sensors_enabled` false) has `neutral_pending` and `neutral_stale` false; after `run_reset` from Menu and `run_resumed`, `fallback_source` +1 gives `steer` 0.25 on the next 62500 us tick and `neutral_pending` is still false; a release-build core that timed out into `FALLBACK` behaves the same.
- [x] **AC-32 [C]**: table-driven over states {Acquiring, Live `SENSOR`, Live `FALLBACK`, Unavailable (sensor lost), Unavailable (release-build configuration error)} and events {valid sample, invalid past the hold, start timeout (both `sensor_ever_live` values), app backgrounded}: every pair not in the transition table gives no change, no error and no signal (Acquiring plus backgrounded changes no state but still clears the buffer, sets `neutral_stale` and restarts the settle).

## Implementation Notes
F6 fallback: `target = clamp(key + touch, -1, 1)` (the injected source already sums them; clamp the integer to [-1, 1]), `steer = move_toward(steer, target, FALLBACK_SLEW * dt)`, `FALLBACK_SLEW` 4 per second. In `FALLBACK` the state is Live, `valid` true, entering clears `neutral_pending` and `neutral_stale`, and `run_reset`/`run_resumed` capture events do nothing. While `input_source` is `SENSOR` the fallback source is ignored. `input_source` is readable at `run_started` for Scoring (Open Question 27, not this story). AC-32 is the last item because it exercises transitions from Stories 008, 009 and 010; do it after them. The editor-only synthetic gravity source (ADR-0005 Decision 6) is Story 013.

## Out of Scope
- Story 013: the editor-only arrow-key sample source; HUD/Menus: any touch half-screen forwarding (no MVP driver wires it).
- Story 008: the FALLBACK entry transitions themselves.

## QA Test Cases
- **AC-33/48**: Given a `FALLBACK` core and a `fallback_source` stub (member variable); When ticks at `dt = 1/16`; Then the steer sequence and flags as listed
  - Edge cases: value 2 clamps; both release and debug entry paths
- **AC-34/47b**: Given sensors live / a `FALLBACK` core with a late valid sample; Then source ignored / `FALLBACK` terminal, `phi_f` unchanged
- **AC-32**: Given each (state, event) pair; Then no change, no error and no signal for every pair outside the table

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tilt_input/tilt_core_fallback_input_test.gd`
**Evidence**: `tests/unit/tilt_input/tilt_core_fallback_input_test.gd` (AC-33a-d, AC-34, AC-47b, AC-48, AC-32) passes in CI.
**Status**: [x] Created

## Dependencies
- Depends on: Story 008, Story 009, Story 010
- Unlocks: Story 013
