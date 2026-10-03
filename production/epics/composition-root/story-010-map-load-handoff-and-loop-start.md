# Story 010: Map load hand-off and loop start

> **Epic**: Composition Root & Game Loop
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0002 (with ADR-0004 Decisions 2 and 3)
**Requirement**: `TR-run-state-restart-019`, `TR-composition-root-???` (ADR-0002 Decision 5 tail; Key Interfaces `_ready`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; secondary ADR-0004 (Map Loader)
**ADR Decision Summary**: After `_wire()`, `MapLoader` calls `load_map` and sends `map_ready` on success, then the loop starts. Run State emits nothing until `map_ready`, which arrives only after construction finished.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Map load runs synchronously in one frame, first in `GameRoot` after `_wire()` and before the first `_process`. The editor-only steering source (`OS.has_feature("editor")`) is owned by tilt-input.
**Control Manifest Rules (this layer)**:
- Required: `_ready()` runs `_construct()`, `_wire()`, `_map_loader.start()`; the `map_load_failed` row is in `_wire()`; `map_ready` is sent only after Tube Track `load_map` returned true; on failure send nothing and keep Run State in Boot; the loop starts only after the load attempt.
- Forbidden: `ResourceLoader` outside `map_loader.gd`; threaded load; an `await` between `_wire()` and the first `_process`.
- Guardrail: Boot map-load sequence at most 100 ms on a mid-tier phone (MS-1, measured by the map-loader epic).

## Acceptance Criteria
- [ ] Order spy: `_construct`, `_wire`, `load_map` attempt, `map_ready` (on success), first `_process` tick; no tick before the load attempt (ADR-0002 Decision 5)
- [ ] On a failing load (fake loader) `map_ready` is never sent, Run State stays in Boot, and `map_load_failed` reaches Menus through its `_wire()` row (ADR-0004 Decision 3; Manifest)
- [ ] The tick loop still runs in Boot (Platform, Tilt and Menus ticks) and `RunState.tick` returns `dt_eff = 0` outside Running (ADR-0002 Decision 8)
- [ ] With every collaborator faked, `GameRoot` built through the full path with a mobile-returning getter completes `_ready` headless and runs 60 ticks without a script error (ADR-0002 VC-5, ADR-0003 Decision 1)
- [ ] Sending `map_ready` is the first Run State emission of the process (Boot to Menu) and arrives after all `_wire()` connections exist (TR-run-state-restart-019)

## Implementation Notes
`start()` of the loader is a thin call; the sequence logic belongs to `MapLoaderCore` (map-loader epic). This story only verifies the hand-off order and failure path from the composition root. The scene file for `GameRoot` references the real child view scenes as they land; tests build `GameRoot` from script with fakes, so no scene dependency exists. Keep the loop-start flag in `GameRoot` (`_running`), set last.

## Out of Scope
- map-loader epic: Phase A/B logic, `retry()`, timeout
- Story 011: device soak of the running loop

## QA Test Cases
- **AC-1**: order
  - Given: spies for each step and a fake loader that succeeds
  - When: `_ready()` then 60 `_process` calls
  - Then: log equals expected order; first tick after `map_ready`
- **AC-2**: failure path
  - Given: fake loader failing with `TUBE_LOAD_REJECTED`
  - When: `_ready()`
  - Then: no `map_ready`; Run State phase Boot; Menus handler called once with codes
- **AC-3**: Boot ticks
  - Given: phase Boot
  - When: ticks run
  - Then: `dt_eff == 0`, `Menus.tick` called
- **AC-4**: headless smoke
  - Given: all fakes and mobile getter
  - When: 60 ticks
  - Then: no error output, tick log complete
- **AC-5**: first emission
  - Given: signal spy on Run State
  - When: full startup
  - Then: first emission is the Boot to Menu change, after every connect

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/composition_root/composition_root_startup_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002, Story 006, Story 007, Story 008, Story 009; map-loader epic (loader seam; fake until it lands)
- Unlocks: Story 011, Story 012
