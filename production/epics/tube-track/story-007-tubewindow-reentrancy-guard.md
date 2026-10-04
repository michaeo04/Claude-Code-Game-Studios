# Story 007: Re-entrancy guard, binder contract and idempotent begin_run

> **Epic**: Tube Track
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-008`, `TR-tube-track-009`, `TR-tube-track-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary, Decision 7 immediate connections); ADR-0009: Test framework and CI
**ADR Decision Summary**: Control signals use immediate connections only; typed handlers are mandatory. `CONNECT_DEFERRED` is banned by lint because it bypasses guards.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `CONNECT_DEFERRED` handlers run after `emit()` returns and escape the guard (the guarantee covers immediate connections only). Signal parameter types are not enforced at `emit`: declare typed signals and assert. A handler that `await`s resumes outside the guard.
**Control Manifest Rules (this layer)**:
- Required: signals carry integers only; the re-entrancy guard covers every emission (`begin_run`, `pause`, `advance`, `state_changed`); core logs every rejected input; typed handlers.
- Forbidden: `CONNECT_DEFERRED` on control signals; Array/Dictionary signal payloads; a handler calling a mutating method.
- Guardrail: production sink rate-limits identical errors to one per second (core stays deterministic).

## Acceptance Criteria
- [ ] **AC-20** `begin_run()` called twice in a row emits two `window_primed(-2, 9)`, the window holds 12 unique slots and s = 0. A handler connected to each of `window_primed`, `state_changed`, `segment_entered_window`, `segment_left_window` (the triggering `advance` crossing exactly one boundary) that calls `advance`, `begin_run` or `pause` is rejected with one error and state is unchanged. `begin_run()` calls the injected `slot_binder` exactly N times with `slot_index` 0..11 once each and `segment_index` -2..9 (`slot_index = posmod(segment_index, 12)`).

## Implementation Notes
Add a `_in_emission` depth flag set around every `emit_signal`/`signal.emit()` in `TubeWindow`; any mutating public method called while set returns early with one error and no state change. The mutating methods: `load_map`, `unload_map`, `begin_run`, `advance`, `pause`, `resume`, `end_run`, `to_idle`. Provide the ordered signal recorder and binder spy (shared with Story 005) in `tests/support/`. Keep the production rate-limited sink out of this core: only an injected Callable is used. Document that a multi-recycle `advance` shows handlers an intermediate window.

## Out of Scope
- Story 005: state table and priming
- Story 006: recycling mechanics
- composition-root epic: the `CONNECT_DEFERRED` lint rule itself

## QA Test Cases
- **AC-20**: guard and idempotence
  - Given: a recorder and a binder spy; for each of the four signals a handler that attempts `advance`, `begin_run` or `pause`. When: the triggering operation runs. Then: each nested call logs exactly one error; state, `s` and window equal the pre-call values. Edge cases: a handler that reads state sees a consistent window; two successive `begin_run` leave 12 unique slots; binder call set is {0..11} with segments -2..9.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tube_track/tube_window_reentrancy_test.gd`
**Status**: [x] Created and passing
**Evidence**: `tests/unit/tube_track/tube_window_reentrancy_test.gd`: test_handler_calls_are_rejected_with_one_error_and_no_state_change (4 signals x 3 actions), test_begin_run_twice_emits_two_primes_and_twelve_unique_slots, test_binder_called_once_per_slot_with_posmod_segment

## Dependencies
- Depends on: Story 005, Story 006
- Unlocks: Story 009, Story 010
