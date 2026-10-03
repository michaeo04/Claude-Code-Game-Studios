# Story 001: GameRoot clock injection and single tick driver

> **Epic**: Composition Root & Game Loop
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: none, defined by ADR-0002
**Requirement**: `TR-composition-root-???` (no registered id; ADR-0002 Decisions 1-4 and 8); related `TR-run-state-restart-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: `GameRoot` is the scene-root Node and the only node with a game-logic `_process`; it ignores the engine delta, computes `real_dt` from an injected `clock_us` Callable, and keeps ticking in every phase (no `SceneTree.paused`, no `Engine.time_scale`).
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Only `Node._process`, `process_mode`, `Time.get_ticks_usec` and `Callable` are used. Whether `_process` keeps running while unfocused on Android is NEEDS VERIFICATION (spikes PS-1/PS-2, device; platform-services epic). `class_name GameRoot` needs the class cache (`godot --headless --import` before GUT).
**Control Manifest Rules (this layer)**:
- Required: `GameRoot` (`class_name GameRoot extends Node`) is the Composition Root and the only game-logic `_process`; `_process(_engine_delta)` ignores the engine delta; `real_dt = (now_us - prev_us) / 1e6`, raw and unclamped; `world_dt = real_dt`; `process_mode = PROCESS_MODE_ALWAYS` set in the scene file; one `clock_us: Callable` wrapping `Time.get_ticks_usec()` is injected; every view Node calls `set_process(false)` and `set_physics_process(false)`.
- Forbidden: autoloads; `_physics_process` in game logic; `SceneTree.paused`; writes to `Engine.time_scale`; `Time.` calls inside a Core; assuming a 16.6 ms frame.
- Guardrail: orchestration under 0.1 ms per frame (a dozen method calls).

## Acceptance Criteria
- [ ] `GameRoot` is a `Node` with `class_name GameRoot`, scene file sets `process_mode = PROCESS_MODE_ALWAYS` (ADR-0002 Decision 1)
- [ ] `_process(_engine_delta)` ignores its argument: the same `real_dt` results for any engine delta given a fixed fake `clock_us` (Decision 1)
- [ ] `real_dt = float(now_us - _prev_us) / 1e6`, not clamped; a 5 s gap in the fake clock yields `real_dt == 5.0`; `world_dt == real_dt` (Decision 1)
- [ ] `clock_us` is a constructor-injected Callable; the production binding wraps `Time.get_ticks_usec()` and is the only `Time.` call in the composition root (Decision 4)
- [ ] `_process` hands `(real_dt, world_dt)` to a single `_tick()` method; no other function writes the per-frame order (Implementation Guidelines)
- [ ] A view-registration helper calls `set_process(false)` and `set_physics_process(false)` on each view Node it receives (Decision 1)
- [ ] `GameRoot` ticks in every phase and never touches `SceneTree.paused` or `Engine.time_scale` (Decision 8)

## Implementation Notes
Create `src/core/game_root.gd` and the root scene with `PROCESS_MODE_ALWAYS`. Keep `GameRoot` wiring only: no rule keywords, no state beyond `_prev_us` and references. Keep a strong reference to every core (Story 006 fills the construction). `_prev_us` is initialised from the clock at the first tick so the first `real_dt` is 0, not a boot-time gap (state this in a comment; Run State's stall guard needs the raw value afterwards). Static typing everywhere; doc comments on public methods.

## Out of Scope
- Story 002: the content and order of `_tick()`
- Story 006: construction order
- Story 009: the lint that enforces the bans

## QA Test Cases
- **AC-1**: Node class and process mode
  - Given: the GameRoot scene is instantiated headless
  - When: its `process_mode` and script class are read
  - Then: `PROCESS_MODE_ALWAYS` and `GameRoot`
  - Edge cases: scene file value, not a runtime assignment
- **AC-2/3**: engine delta ignored, raw real_dt
  - Given: a fake `clock_us` returning scripted values
  - When: `_process(0.001)` and `_process(0.133)` are called with identical clock steps
  - Then: both record the same `real_dt`; a 5 s step records 5.0 (no clamp)
  - Edge cases: first tick yields 0.0; non-monotone clock value does not crash
- **AC-4/5**: injection and single tick site
  - Given: a spy `_tick`
  - When: `_process` runs
  - Then: `_tick(real_dt, world_dt)` is called once with equal arguments
- **AC-6**: view registration
  - Given: a stub Node with processing on
  - When: registered
  - Then: `is_processing()` and `is_physics_processing()` are false
- **AC-7**: no pausing
  - Given: ticks in Menu, Running, Paused (fake Run State)
  - When: ticked
  - Then: `get_tree().paused` false and `Engine.time_scale` unchanged

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/composition_root/composition_root_tick_driver_test.gd`
**Status**: [~] Tests passing (9) in composition_root_tick_driver_test.gd
**Closed 2026-10-04**: AC-1 is proven by `src/core/game_root.tscn` (root `GameRoot`, `process_mode = 3`) and `tests/integration/composition_root/composition_root_scene_test.gd` (instantiates the scene, asserts the class and the mode, and checks the .tscn text). AC-4's production binding to `Time.get_ticks_usec` is only checked as a valid default callable; the real clock reading is exercised by every device run.

## Dependencies
- Depends on: test-harness-ci (GUT runs, spike T-1)
- Unlocks: Story 002, Story 003, Story 006
