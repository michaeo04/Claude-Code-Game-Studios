# Story 006: advance(s) and synchronous recycling

> **Epic**: Tube Track
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-006`, `TR-tube-track-007`, `TR-tube-track-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary, `advance` called once per frame in Running only); ADR-0013: Distance precision and the render origin (index stays `int`, `s` float64)
**ADR Decision Summary**: `GameRoot._tick` calls `TubeTrack.advance` once per frame, Running only, after `Ball.step`. Tube Track has no dependency on update order of Camera or Ball; it reacts to the `s` it is given.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `floori(s / L)` verified not to round up one ulp below a boundary; keep a test at the literal `11.999999999999998`. Use `floori` and `posmod`.
**Control Manifest Rules (this layer)**:
- Required: `TubeTrack.advance` runs in Running only; recycling is synchronous inside `advance` (left of the rearmost then entered of the new far, in increasing index order); a jump of N or more segments re-primes with `window_primed` and no `segment_*`.
- Forbidden: `advance` called from a handler or outside Running; a second caller.
- Guardrail: `s` never decreases (`max(s, prev)`); equal `s` is a silent no-op; NaN/INF `s` ignored with one error.

## Acceptance Criteria
- [ ] **AC-8** `begin_run()` from Idle: window -2..9, exactly one `window_primed(-2, 9)` then one `state_changed(Running, Idle)`, no `segment_*`; `advance` with 11.999, 12.0, 12.0 emits in total exactly one `segment_left_window(-2)` then one `segment_entered_window(10)` (during the second call), window -1..10.
- [ ] **AC-9** Running at s = 0, `advance(132)` (N-1 = 11 segments): 11 pairs in increasing index order (left -2, entered 10, ..., left 8, entered 20), window 9..20. Running at s = 0, `advance(144)` (N segments): exactly one `window_primed(10, 21)` and no `segment_*`.
- [ ] **AC-10** Running at s = 50: `advance(49)` keeps effective s 50 with exactly one warning; `advance(50)` logs and emits nothing; `advance(NaN)` and `advance(INF)` are ignored with one error each; `begin_run()` sets s = 0.

## Implementation Notes
In `TubeWindow.advance(s)`: reject outside Running (one error, already covered by the table in Story 005); ignore non-finite `s`; `s = max(s, s_prev)` with one warning on a decrease (debug builds); compute `i = floori(s / L)`; if `i - i_prev >= N` re-prime (binder N times, `window_primed(i - B, i + A)`); else loop `k` from `i_prev` to `i - 1` emitting `segment_left_window(k - B)` then `segment_entered_window(k + 1 + A)` and calling the binder for the recycled slot. A boundary value `s = i * L` counts as entered, recycled exactly once. Handlers see an intermediate window during a multi-recycle call (document it).

## Out of Scope
- Story 005: state table, `begin_run` priming mechanics (used here as setup)
- Story 007: re-entrant calls from handlers
- Story 009: the 300 s simulation

## QA Test Cases
- **AC-8**: first recycle
  - Given: Idle with a valid map. When: `begin_run`, then advance 11.999, 12.0, 12.0. Then: signals and window as listed; the third call emits nothing. Edge cases: exact boundary 12.0 enters once.
- **AC-9**: multi-segment jump
  - Given: Running at 0. When: `advance(132)` on one instance, `advance(144)` on another. Then: 11 ordered pairs; one re-prime `(10, 21)`. Edge cases: no `segment_*` on the re-prime.
- **AC-10**: bad inputs
  - Given: Running at 50, counting sink. When: 49, 50, NaN, INF. Then: counts as listed, `s` stays 50. Edge cases: `begin_run` resets `s`.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tube_track/tube_window_advance_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 005
- Unlocks: Story 007, Story 009
