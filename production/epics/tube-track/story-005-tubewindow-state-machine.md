# Story 005: TubeWindow state machine, priming and load_map

> **Epic**: Tube Track
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-004`, `TR-tube-track-005`, `TR-tube-track-009`, `TR-tube-track-023`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0004: Map Loader and MapConfig (`load_map` only from Uninitialized); ADR-0009: Test framework and CI
**ADR Decision Summary**: `TubeWindow` is a `RefCounted` (not an autoload) taking `TubeConfig`, a `log_sink` Callable and a `slot_binder` Callable `(slot_index: int, segment_index: int)`. No `_process`; `GameRoot` drives it. A failed `load_map` leaves Uninitialized so the loader may Retry.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: An unset `Callable().call()` is a script error: default to `Callable()` and guard with `is_valid()`. Signal arguments coerce to typed handlers; declare typed signals. Lambdas capture primitives by value: recorders use an Array.
**Control Manifest Rules (this layer)**:
- Required: `TubeWindow` takes injected log sink and `slot_binder`; `load_map` accepted only from Uninitialized; `validate()` failure keeps Uninitialized with no binder call and no signal; each prime calls the binder N times; order `window_primed` then `state_changed`.
- Forbidden: autoload; `unload_map` in the MVP game flow (the state exists in the table and is tested); `CONNECT_DEFERRED`; freeing and recreating slots on Retry.
- Guardrail: no persistent state; per-run state is `s`, `s_idle` and the window.

## Acceptance Criteria
- [ ] **AC-19** A table-driven test over all 40 (state, event) pairs: exactly the 16 listed pairs succeed with the listed next state; the other 24 are rejected with no state change, no signal and one logged error (`resume()` and `pause()` in Ended and `advance` in Idle, Paused, Ended among them). Every accepted transition that changes state emits `state_changed(new, old)` exactly once after its effects are complete; none when the state does not change (`begin_run()` from Running emits `window_primed` only); a `state_changed` handler sees the new state and final window; a `window_primed` handler from `begin_run()` sees the final window and the old state.
- [ ] **AC-20a** `load_map(valid)` from Uninitialized: 12 binder calls (`segment_index` -2..9, `slot_index = posmod(segment_index, 12)`), one `window_primed(-2, 9)` then one `state_changed(Idle, Uninitialized)`, no `segment_*`; invalid config (F = NaN): no binder call, no signal, state stays Uninitialized. From Running, Paused and Ended at s = 1234.5 (window 100..111), `to_idle()` gives 12 binder calls, one `window_primed(-2, 9)`, then `state_changed(Idle, old)`, `s_idle` 0, window -2..9. In Idle, 60 s of `tick_idle(1/64)` emits no `window_primed` or `segment_*` and the window stays -2..9.
- [ ] **AC-20b** Invalid config at `load_map`: no binder call or signal, state Uninitialized, one `NOT_FINITE` returned, a following `begin_run()` rejected with one error; then `load_map(valid)` (Retry) is accepted (12 binder calls, `window_primed(-2, 9)`, `state_changed(Idle, Uninitialized)`); `load_map(valid)` from Idle, Running, Paused, Ended is rejected with one error, no signal, state and window unchanged.

## Implementation Notes
`src/core/tube_track/tube_window.gd`. Events: `load_map`, `unload_map`, `begin_run`, `advance`, `pause`, `resume`, `end_run`, `to_idle`; accepted transitions per the GDD table. `begin_run()` resets `s` to 0 and primes `-B .. A`; `to_idle()` and `load_map()` prime at `s_idle = 0`. `unload_map` releases slot bindings and emits `state_changed`. Expose getters `s`, `first_index`, `last_index`, `far_end_s`, state. Test support in `tests/support/` (plain `RefCounted`, no GUT): a state factory, a counting log sink, a binder spy and an ordered signal recorder (`tests/unit/tube_track/test-plan.md` may be written alongside, as the GDD names it).

## Out of Scope
- Story 006: `advance` recycling and re-prime on a jump
- Story 007: re-entrancy guard and the signal-order contract under handlers
- Story 008: `idle_step` math and `tick_idle` value assertions (this story adds a thin `tick_idle(dt)` delegating to `TubeMath.idle_step` and asserts only its no-signal effect)
- Story 010: the Run State adapter

## QA Test Cases
- **AC-19**: 40-pair table
  - Given: a table of (state, event, expected). When: each event is fired from a fresh state factory. Then: accepted pairs reach the listed state, rejected pairs leave state and emit one error and no signal. Edge cases: `begin_run` from Running re-primes with no `state_changed`.
- **AC-20a**: priming
  - Given: counting binder and recorder. When: `load_map`, `to_idle` from three states. Then: 12 binder calls, signal order, window -2..9, `s_idle` 0. Edge cases: invalid config binds nothing.
- **AC-20b**: retry
  - Given: invalid then valid config. When: `load_map` twice, `begin_run` between. Then: Retry accepted, `begin_run` rejected earlier. Edge cases: `load_map` from every non-Uninitialized state rejected.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tube_track/tube_window_states_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002 (indices), Story 003 (`validate`), test-harness-ci
- Unlocks: Story 006, Story 007, Story 008, Story 009, Story 010
