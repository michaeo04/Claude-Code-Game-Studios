# Story 008: Idle scroll step and deterministic segment content

> **Epic**: Tube Track
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-016`, `TR-tube-track-018`, `TR-tube-track-023`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0003: Renderer choice and tube render route (primary, `idle_step(dt)` driven by `GameRoot`); ADR-0002: Game loop, Composition Root and tick order; ADR-0009: Test framework and CI
**ADR Decision Summary**: `TubeView.idle_step(real_dt)` is called by `GameRoot` only when the phase is Menu (Paused, Hit and Resuming keep the tube still); the view has no `_process`. The idle scroll is internal to the Idle state and does not count as run distance.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `fposmod(-tiny, y)` can return exactly `y`; guard `s_idle` into `[0, L)`. Use dt = 1/64 where exact binary sums matter (3840 ticks give exactly 6.0 u at 1.5 u/s).
**Control Manifest Rules (this layer)**:
- Required: `s_idle = fposmod(s_idle + v_idle * step, L)` with `step = clamp(dt, 0, t_lat)` and 0 for non-finite or negative `dt`; segment content is a pure function of (config, absolute index); compare by absolute index in segment-local space.
- Forbidden: randomness in Tube Track (`randf`, `RandomNumberGenerator`; a CI lint is added or verified by this story); `Time.` in cores.
- Guardrail: no segment_* or window_primed signals in Idle.

## Acceptance Criteria
- [ ] **AC-17** `TubeMath.idle_step(s_idle, v_idle = 1.5, dt, t_lat = 0.1, L = 12)`: dt = 1/60 adds 0.025; dt = 0.5 adds 0.15 (clamped); dt = -1, NaN, INF add 0; `s_idle = 11.99` plus one 1/60 step wraps to 0.015 (+/- 1e-9). Through `tick_idle(dt)`, after 60 s run distance is 0 and `s_idle` is in [0, 12); Idle to Running discards `s_idle` and sets s = 0.
- [ ] **AC-18** `TubeMath.segment_content(config, index)` deep-equals across two instances for absolute index 102; the recorded binder calls and the `seam_s` values of every segment in the window are identical between a continuous run and a re-prime at s = 1234.5 (segment 102), and across two `begin_run()` cycles; world transforms are not compared. A lint or test asserts Tube Track code contains no `randf` or `RandomNumberGenerator`.

## Implementation Notes
`TubeMath.idle_step(s_idle, v_idle, dt, t_lat, L)` static; `TubeWindow.tick_idle(dt)` calls it using `IDLE_SCROLL_SPEED` (default 1.5, range 0.5-3) and `RECYCLE_STEP_MARGIN`. `segment_content(config, index)` returns a small immutable description (index, `seam_s` positions in segment-local space from F5), no engine objects. The seam phase for the view is `fposmod(s, SP)` computed in 64 bits (Story 012).

## Out of Scope
- Story 005: Idle window priming signals
- Story 011: `TubeView.idle_step` node behaviour
- Story 012: seam shader

## QA Test Cases
- **AC-17**: idle step
  - Given: v_idle 1.5, t_lat 0.1, L 12. When: dt values 1/60, 0.5, -1, NaN, INF, plus 3840 ticks of 1/64. Then: increments as listed; 60 s run distance 0, `s_idle` in [0, 12). Edge cases: wrap at 11.99; Idle to Running resets s.
- **AC-18**: determinism
  - Given: two TubeWindow instances, map index 102. When: continuous run vs re-prime at 1234.5 vs two `begin_run` cycles. Then: equal content and equal recorded binder calls by absolute index. Edge cases: negative indices -2..-1 also deterministic.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tube_track/tube_idle_content_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002, Story 005
- Unlocks: Story 009, Story 011
