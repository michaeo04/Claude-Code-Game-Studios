# Story 012: Integration with Run State core (INT/BACK pause, 340 sequences)

> **Epic**: Platform Services
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-05

> **Unblocked 2026-10-03**: the Run State stories now exist; depends on `run-state-restart` stories 001-004 (core, AC-8) and `composition-root` story 001, which supplies the production adapter wiring.

## Context
**GDD**: `design/gdd/platform-services.md`
**Requirement**: `TR-platform-services-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (integration folder); ADR-0006: Android platform integration (Decision 3, handlers never run inside a Run State tick)
**ADR Decision Summary**: The harness uses Run State's real SceneTree-free core, a real `PlatformCore` and a test-only adapter (INT becomes `pause_requested(app_interrupted)`, BACK becomes `pause_requested(back)`); headless-capable integration tests are BLOCKING.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Pure GDScript, no SceneTree. Run State rule 3 (no request from inside a tick) is really covered by PS-12 (Story 013); AC-15 is regression only.
**Control Manifest Rules (this layer)**:
- Required: run State applies `app_interrupted` when sent; the adapter, not Platform Services, converts signals into Run State requests; fixtures from named factories.
- Forbidden: never run a lifecycle handler inside a Run State tick or handler; no skipping or retrying a failing test.
- Guardrail: all 340 sequences deterministic, fixed enumeration order.

## Acceptance Criteria
- [x] **AC-14 [I]** (R4, R5) INT or BACK in Running or Resuming gives Paused with one `run_paused` whose source is `app_interrupted` or `back`, applied before the `on_*` call returns; in Menu, Boot, Hit and Paused: no phase change, zero log lines; two BACK in Running give one pause; an Android Home sequence (A1) leaves Paused with `run_id` unchanged and no `run_ended`.
- [x] **AC-15 [I]** (regression only) Events delivered between ticks: all 340 sequences of 1-4 events (4+16+64+256), both `fis`, from Running: zero Run State Error logs, and the run is Paused iff the sequence contains FO or (with `fis` false) P.

## Implementation Notes
Use the test-only adapter described in the GDD; the production adapter belongs to the composition-root epic. Events are delivered between ticks. A second BACK in Paused is a silent no-op in Run State. AC-16 (re-anchoring the Paused guard with `app_returned`) and AC-17 are deferred; do not implement them here. This story is blocked by the Run State core story (its AC-8 SceneTree-free core) and by the production adapter story, which the producer assigns.

## Out of Scope
- AC-16 (deferred; owner Run State epic, then the adapter story) and AC-17 (deferred; owner Story 013 and the Tilt Input, Save, Menus epics)
- Production adapter wiring (composition-root epic)

## QA Test Cases
- **AC-14**: INT/BACK pause
  - Given: Run State core in each phase and a real `PlatformCore` with the test adapter
  - When: INT, BACK, two BACK, and the A1 sequence are delivered
  - Then: Running/Resuming pause with one `run_paused` and the right source before the call returns; other phases: no change and zero logs; `run_id` unchanged and no `run_ended` after A1
  - Edge cases: second BACK in Paused is a silent no-op
- **AC-15**: 340 sequences
  - Given: both `fis` values, Running start
  - When: every sequence of 1-4 events is delivered
  - Then: zero Run State Error logs; Paused iff the sequence contains FO or (`fis` false) P
  - Edge cases: failure message prints `fis` and sequence

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/platform_services/platform_services_run_state_test.gd` (must pass)
**Evidence**: `tests/integration/platform_services/platform_services_run_state_test.gd` (6 tests, passing; AC-14 x5, AC-15 x1 over 340 sequences x 2 `fis`); test-only adapter `tests/support/platform_run_adapter.gd`. Note: Run State queues every pause source except `app_interrupted` until the next tick, so BACK is asserted after one tick; INT is applied before the `on_*` call returns.
**Status**: [x] Created, passing

## Dependencies
- Depends on: Stories 004, 006; run-state-restart epic core story (AC-8) and the production adapter story (composition-root epic)
- Unlocks: first-playable confidence in the pause path
