# Story 012: TiltRunAdapter and the level-triggered sensor-lost pause

> **Epic**: Tilt Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-004`, `TR-tilt-input-014`, `TR-tilt-input-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (fixed per-frame order, `_wire()` table); ADR-0009: Test framework and CI (secondary)
**ADR Decision Summary**: Per frame: `TiltInput.poll`, `TiltRunAdapter.flush`, `RunState.tick`, ... in one `_process`; handlers are immediate connections from one `_wire()` table, and nothing sends a request from inside a Run State handler.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Handler order on one signal is connection order (Run State AC-30 spy test, NEEDS VERIFICATION on 4.7.2). Signal arguments are coerced to the handler's typing: use typed handlers. A lambda capturing `self` stored in a `RefCounted` leaks: use bound methods or `dispose()`.
**Control Manifest Rules (this layer)**:
- Required: `TiltRunAdapter` is a `RefCounted` with injected `request_pause: Callable(source)` and `phase_source: Callable() -> phase`; `flush()` is called once per frame after `poll()` and before Run State's tick; a handler reads another system by accessor and never calls its mutating method.
- Forbidden: sending requests from `run_started`, `phase_changed` or `availability_changed` handlers; `await` in a `run_reset` handler; `CONNECT_DEFERRED`.
- Guardrail: at most one pause request per frame.

## Acceptance Criteria
- [ ] **AC-39 [C]/[I]** (BLOCKING, built with Run State's real SceneTree-free core, a real `TiltCore` and injected `request_pause` and `phase_source`): **39a** `run_reset` from Menu captures synchronously before `run_started`; from Hit or Paused it conditionally re-anchors or inherits per AC-16; **39b** `run_resumed` captures; **39c** a pause during the countdown emits no `run_resumed`; **39d** `flush()` requests `pause_requested(sensor_lost)` when `valid` is false in Running or Resuming and does nothing in other phases, at most once per frame; **39e** a run that starts with `valid` false is paused on its settling tick: exactly one `run_paused(sensor_lost)` and zero Run State Error logs; **39g** the adapter's cached phase at `run_reset` is the previous phase and the cache starts from `phase_source` at construction (first Menu-to-Play reset has previous phase Menu); **39h** `run_ended` and `run_paused` reach `on_run_stopped()`.
- [ ] **AC-43 [M]**: `sensor_lost_pause_needed(phase, valid)` is true for {Running, Resuming} with `valid` false, false for `valid` true, and false in Menu, Boot, Hit and Paused with either value.
- [ ] **AC-43b [I]** (each frame is `tilt.poll()`, `adapter.flush()`, `run_state.tick()`): with `valid` false when a restart from Hit is accepted, the next tick pauses with `run_paused(sensor_lost)`: exactly one pause, `run_id` increased by exactly 1 and zero Run State Error logs; with `valid` true nothing is requested; while `valid` stays false in Running or Resuming at most one request per frame.

## Implementation Notes
The pause is level-triggered, evaluated by `flush()` outside any Run State handler (Run State rejects requests sent from inside its handlers, its rule 3). `sensor_lost_pause_needed` is a pure `TiltMath` function. The adapter tracks the phase through `phase_source`, initializes its previous-phase cache from it at construction, forwards `run_reset(previous_phase)`, `run_resumed`, `run_ended`/`run_paused` (to `on_run_stopped()`) and, via the composition root `_wire()`, `app_backgrounded`/`app_foregrounded`. A constructor given an invalid Callable logs one error (guard with `is_valid()`). Menus' gating of Play/Resume/Restart on `valid` and `input_source == SENSOR` is the Menus epic (AC-39f, UI, ADVISORY, tracked there).

## Out of Scope
- Menus epic: AC-39f walkthrough (buttons disabled, swallowed tap-anywhere restart, pause screen offers Menu).
- Composition root: the real `GameRoot._tick` and `_wire()` rows; Ball Movement epic loop story: AC-27.

## QA Test Cases
- **AC-39a-h**: Given a real Run State core, `TiltCore` and stub Callables; When the listed Run State events and polls occur; Then captures, requests and Error-log counts as listed
  - Edge cases: first-ever reset has previous phase Menu; stale cached phase Hit seen at reset
- **AC-43**: table of phases x `valid` for the pure function
- **AC-43b**: frame loop of poll, flush, tick with `valid` false at restart; Then exactly one `run_paused(sensor_lost)`, `run_id` +1, no Error

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/tilt_input/tilt_run_adapter_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 007, Story 009, Story 010; run-state-restart (SceneTree-free core and its AC-8 harness)
- Unlocks: Story 013; composition-root `_wire()` rows
