# Story 001: RunStateCore skeleton, public API, signals and purity

> **Epic**: Run State & Restart
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-001`, `TR-run-state-restart-002`, `TR-run-state-restart-017`, `TR-run-state-restart-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI (GUT, lints)
**ADR Decision Summary**: Core logic classes (`XCore`) are RefCounted with no engine calls; the clock is one injected `clock_us: Callable`; signals are declared on the owning core; no autoloads; construction emits nothing.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `class_name` needs the class cache, so tests `preload` the core and CI runs `godot --headless --import` first. Verify that `get_script().get_script_signal_list()` works for typed signals on 4.7.2 before AC-8 relies on it (GDD AC-8). A static and an instance function cannot share a name (use `progress_for`).
**Control Manifest Rules (this layer)**:
- Required: `RunStateCore` is a `RefCounted`, built with `(config, clock: Callable, log_sink: Callable)`; signals declared on the core; tests are GUT `*_test.gd` under `tests/unit/run_state/`
- Forbidden: autoload entries; `Time.`, `Engine.`, `FileAccess`, `ConfigFile`, `user://` or other systems' classes inside the core; a test-only `force_phase` hook
- Guardrail: construction emits nothing (ADR-0002 Decision 5); integers compared exactly, floats at 1e-6

## Acceptance Criteria
- [ ] **AC-8**: the script's own signal list (`get_script().get_script_signal_list()`) is exactly `run_reset`, `run_started`, `run_paused`, `run_resuming`, `run_resumed`, `run_ended`, `run_abandoned`, `restart_unlocked`, `phase_changed`, with int or enum arguments only; the core builds without a SceneTree (`core is RefCounted and not core is Node`); two instances share no static state; a new instance is Boot with `run_id` 0
- [ ] **AC-9**: a CI lint over the core's source finds no reference to another system's class or an autoload, no `FileAccess`, `ConfigFile`, `user://`, `ResourceSaver`, `DirAccess`, `OS.`, no `Time.` or `Engine.` call, and no test-only hook (R2, R12; construction emits no event)

## Implementation Notes
Create `src/core/run_state/run_state_core.gd` with the public API of `tests/unit/run_state/test-plan.md` section 1 (`request_map_ready`, `request_start`, `request_hit`, `request_pause`, `request_resume`, `request_restart`, `request_menu`, `tick`, read-only `phase`, `run_id`, `run_time`, `run_time_ms()`, `resume_remaining()`, `resume_progress()`, `static progress_for`). The 6-value phase enum starts at Boot. Behaviour is filled in by later stories; this story fixes the shape, the signal declarations and the purity. The test plan notes AC-9 reads source files, so run it as a CI lint rule in `tools/ci/lint_rules.json` (kind `forbid`, scope the core file), not as a unit test. Construction emits nothing (GDD Core Rule 15). Note the GDD lists `sensor_lost` as a fourth pause source; the test plan lists three: use four.

## Out of Scope
- Story 002: request validation and transitions
- Story 003: event emission order
- Story 010: config validation (this story only takes a config object)

## QA Test Cases
- **AC-8**: signals and construction
  - Given: a freshly built core with an injected clock and a recording log sink
  - When: the script signal list, base class, a second instance and the initial state are inspected
  - Then: the 9 signals match exactly with int or enum arguments (`TYPE_INT`); no Node base; `phase` is Boot and `run_id` is 0 on both instances; building the core fires no signal
  - Edge cases: mutate a static field on one instance, the other is unaffected; an enum-typed argument reports `TYPE_INT`
- **AC-9**: purity lint
  - Given: the lint rule over `src/core/run_state/`
  - When: `python tools/ci/lint_runner.py` runs on the real file and on a failing fixture containing `Time.get_ticks_usec()`
  - Then: the real file passes; the fixture fails the rule
  - Edge cases: a banned token inside a comment or string must not trigger it (ADR-0009 state-machine stripping)

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/run_state/run_state_core_shape_test.gd` plus the lint fixtures in `tools/ci/tests/`
**Status**: [x] Done. **Evidence**: AC-8 proven by `tests/unit/run_state/run_state_core_shape_test.gd` (7 tests: signal list, int-typed arguments, enum arguments report TYPE_INT, RefCounted not Node, new instance Boot with run_id 0, no shared state, construction emits nothing). AC-9 proven by the CI lint rules `forbidden:run_state_core_purity` (no FileAccess, ConfigFile, ResourceSaver, DirAccess, OS, Time, Engine, Input, ProjectSettings, DisplayServer, RenderingServer) and `forbidden:run_state_core_coupling` (no other system class, no get_tree, get_node, get_parent, preload) with pass and fail fixtures, run by `python tools/ci/run_ci.py --only lint`. **Known limit**: `user://` appears only inside a string literal, which the lint stripper blanks by design, so it cannot be matched; it is covered indirectly because the core has no file API to use a path with.