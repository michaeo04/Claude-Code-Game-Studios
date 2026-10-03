# Story 004: TiltCore poll, clock stamps and sample ring buffer

> **Epic**: Tilt Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-003`, `TR-tilt-input-006`, `TR-tilt-input-007` (stamp rules; dt oracle in Story 006), `TR-tilt-input-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; ADR-0009: Test framework and CI (secondary)
**ADR Decision Summary**: `poll()` is called once per rendered frame in every phase before Ball Movement, from the single `_process` driver; time comes only from the injected microsecond `clock_us`; cores are `RefCounted` with injected Callables.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `Callable().call()` on an unset Callable is a script error: default to `Callable()` and guard with `is_valid()`. Lambdas capture primitives by value (tests use a member or a one-element Array). A lambda capturing `self` stored in a `RefCounted` leaks: use bound methods or `dispose()`. `preload` the classes in headless tests to avoid class-cache collisions.
**Control Manifest Rules (this layer)**:
- Required: inject `clock_us` (never call `Time.` in a core); `TiltCore` takes `sample_source`, `clock`, `log_sink`, `fallback_source` Callables; ring buffer is a `PackedFloat64Array` of angles plus a `PackedInt64Array` of stamps with a head index, capacity 256, no getter exposing it (copies only).
- Forbidden: `_physics_process` polling; `Time.`/`Input.` in `TiltCore`.
- Guardrail: ring buffer about 4 KB; `poll()` p95 at most 0.1 ms.

## Acceptance Criteria
- [ ] **AC-3 [C]**: for each of zero, NaN, INF, (0,-2.99,0) and (0,-1,0), a fresh core in Acquiring given that vector keeps `sample_count` 0 and stays Acquiring; (0,-3,0) is accepted (`sample_count` 1, state Live).
- [ ] **AC-47c [C]**: one row per Callable (`sample_source`, `clock`, `log_sink`, `fallback_source`): an invalid Callable logs one error and leaves the core Unavailable.

## Implementation Notes
`poll()` takes no argument. `dt = clamp((now - previous_now) / 1e6, 0, DT_MAX)` with `DT_MAX` 0.1 s; `previous_now` is the stamp of the last accepted poll (stamp greater than it, whether its sample was valid or not), starts as "none", so the first poll even at stamp 0 is accepted with `dt = 0`. An equal or backwards stamp appends no sample, uses `dt = 0` and leaves `previous_now` unchanged. A sample is valid if the vector is finite and `|g| >= G_MIN`. Samples older than `BUFFER_AGE` (1.0 s) are dropped at every append; the buffer uses the real clock (true time), while `dt` is clamped. All durations are integer microseconds. Do not derive `dt` from the engine delta. Ring-buffer capacity 256 and the overwrite order are exercised through captures in Story 005 (AC-26); the stamp-rule and dt oracles are asserted in Story 006 (AC-25) where the filter exists.

## Out of Scope
- Story 005: neutral capture and the `live_core` helper; AC-26 (buffer overwrite order, read through a capture).
- Story 006: filter, dead zone and published output; AC-25 (dt oracles read through the filter).
- Story 013: the node that supplies the real `Input.get_gravity()` sample.

## QA Test Cases
- **AC-3**: Given a fresh Acquiring core; When each vector is polled; Then `sample_count` 0 and state Acquiring, except (0,-3,0) accepted
  - Edge cases: (1e200,0,0) becomes INF in float32 and is invalid (AC-46c, Story 006)
- **AC-47c**: Given an unset Callable for each seam in turn; When the core is built; Then one error is logged and the state is Unavailable
  - Edge cases: all four rows separately; `is_valid()` guard at init

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tilt_input/tilt_core_poll_buffer_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 003; test-harness-ci
- Unlocks: Story 005, Story 006, Story 008, Story 010

