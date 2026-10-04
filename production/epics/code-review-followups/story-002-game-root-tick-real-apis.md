# Story 002: GameRoot `_tick` against the real core APIs

> **Epic**: Code Review Follow-ups
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context

**GDD**: none (code review finding, `production/qa/code-review-2026-10-04.md`)
**Requirement**: `TR-code-review-???`
**ADR Governing Implementation**: ADR-0002 (injected sinks, single tick driver); ADR-0009 (test rules)
**ADR Decision Summary**: cores are pure RefCounted classes that receive time, sinks and seams by injection; the composition root is the only place that wires them.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none (GDScript only)
**Control Manifest Rules (this layer)**:
- Required: static typing; pure cores with no engine calls; values from config.
- Forbidden: autoloads; `CONNECT_DEFERRED`; editing `tools/ci/lint_rules.json` to turn a lint green (a story that needs a new rule adds it with fixtures).
- Guardrail: `python tools/ci/run_ci.py --only all` stays green and finishes in about 15 s.

---

## Acceptance Criteria

- [x] `GameRoot._tick` uses the `dt_eff` returned by `RunStateCore.tick(world_dt, real_dt)` for everything downstream: Ball and Tube Track receive 0 in Paused, Hit, Resuming and on the settling tick.
- [x] `BallCore.step(dt_eff, steer, valid, input_source)` is called with the Tilt Input outputs (`steer`, `valid`, `input_source`); `TubeWindow.advance(s)` receives the ball's absolute `s` (Running only); `WorldFrame.maybe_rebase(s)` follows it.
- [x] The test doubles in `tests/support/system_spy.gd` check argument count and types (strict signatures) so a wrong call fails the test.
- [x] An integration test runs the REAL `RunStateCore`, `BallCore`, `TubeWindow`, `TiltCore` (fed by a scripted sample source) and `WorldFrame` for 600 ticks with a scripted hit and restart, and asserts: ball `s` does not move in Hit and Paused, window indices follow `s`, the rebase fires once at the expected `s`.
- [x] The adapter objects needed (`TiltRunAdapter`, the Tube Track run-state adapter) live in `src/core/` as RefCounted classes with unit tests; the engine node stays thin.

---

## Implementation Notes

Finding 2. Overlaps stories CR-006, CR-007, CR-010 and TI-012: implement the wiring here and mark the overlapping acceptance criteria in those stories as satisfied by this story (do not duplicate code).

---

## Out of Scope

- Anything not named in the acceptance criteria; other findings have their own stories.

---

## QA Test Cases

One test per acceptance criterion above (Given the pre-fix behaviour described in the finding, When the scenario runs, Then the corrected behaviour). Each test fails on the pre-fix code and passes after.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/composition_root/` test
**Status**: [x] Created
**Evidence**: tests/integration/composition_root/composition_root_real_tick_test.gd; tests/unit/composition_root/composition_root_tick_order_test.gd (strict spy); tests/unit/tilt_input/tilt_run_adapter_test.gd; tests/unit/tube_track/tube_run_adapter_test.gd

---

## Dependencies

- Depends on: CRF-001
- Unlocks: the real wiring stories of the composition-root epic
