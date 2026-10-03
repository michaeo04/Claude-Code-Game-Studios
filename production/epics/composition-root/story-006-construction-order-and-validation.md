# Story 006: Construction order and the WorldGeometry/WorldFrame preflight

> **Epic**: Composition Root & Game Loop
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0002
**Requirement**: `TR-run-state-restart-019`, `TR-composition-root-???` (ADR-0002 Decision 5; ADR-0013 Decision 4)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order; secondary ADR-0013, ADR-0004 (`WorldGeometry`), ADR-0012/0014 (view order)
**ADR Decision Summary**: Systems are built in one fixed order, each step finishing before the next; `WorldGeometry` and `WorldFrame` are validated together before any view exists, and `REBASE_Z_EXCEEDS_BUDGET` is fatal.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. Construction uses fakes for Platform and Save so the order is observable headless. Signals emitted before `connect()` are dropped, hence the order.
**Control Manifest Rules (this layer)**:
- Required: order `PlatformServices`, `SaveService` (synchronous load, connect `app_backgrounded`), `SettingsCore` (push `haptics_*` to Platform Services), `RunStateCore` and `ScoreService` (construction emits nothing), immutable `WorldGeometry` and `WorldFrame` validated together before any view, then every other system (Environment view, `WorldChroma`, `BallView`, `HazardView`, Environment, Juice, then HUD and Menus views), then `wire()`, then `MapLoader`, then the loop; `GameRoot` holds a strong reference to every core; build `WorldGeometry` once from the base `TubeConfig` and `BallConfig`.
- Forbidden: autoloads; a view built before the preflight; game state in `GameRoot`.
- Guardrail: construction is synchronous and small.

## Acceptance Criteria
- [ ] A spy records the construction order and it equals the Decision 5 list, each step finishing before the next starts (ADR-0002 VC-2)
- [ ] Constructing `RunStateCore` and `ScoreService` emits no signal (spy on every signal) (TR-run-state-restart-019)
- [ ] `WorldGeometry` and `WorldFrame` are built and validated together before the first view is constructed; the spy shows no view construction earlier (ADR-0002 Decision 5)
- [ ] A `WorldFrameConfig` giving `REBASE_Z_EXCEEDS_BUDGET` stops boot with a fatal error and no view is built (ADR-0013 Decision 4)
- [ ] `GameRoot` holds a strong reference to every core after `_ready`: freeing the local variables used in construction leaves every core alive (ADR-0002 Decision 7)
- [ ] `_ready` runs `_construct()`, then `_wire()`, then `_map_loader.start()` in that order (Key Interfaces)

## Implementation Notes
`_construct()` takes its collaborators from a factory dictionary of Callables so tests substitute fakes (dependency injection over singletons); the production factory binds the real classes with statically typed references, never string-built Callables. Systems that other epics own are constructed by one line each: add the line when that system's story lands, and extend the spy list in the test (Implementation Guidelines). Validation code is the pure function of Story 003. Fatal means `push_error` plus a refusal to continue (`get_tree().quit(1)` in production, a returned error in tests).

## Out of Scope
- Story 007: `_wire()` rows
- Story 008: rendering-method check
- Story 010: map load and loop start
- Each system epic: its own constructor

## QA Test Cases
- **AC-1/3**: order and preflight placement
  - Given: spy factory
  - When: `_construct()`
  - Then: recorded names equal the expected list; `preflight` precedes the first view name
- **AC-2**: construction silence
  - Given: signal spies on Run State and Score
  - When: constructed
  - Then: zero emissions
- **AC-4**: fatal budget
  - Given: config with 128 segments at `L` 24
  - When: `_construct()`
  - Then: error returned, no view in the spy log
- **AC-5**: strong references
  - Given: construction completed
  - When: local refs dropped and a frame awaited
  - Then: every core `is_instance_valid` and reference count above 0
- **AC-6**: `_ready` order via spy

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/composition_root/composition_root_construction_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001, Story 003; map-loader epic (`WorldGeometry`), platform-services, save-persistence, settings-accessibility and run-state-restart epics (fakes until they land)
- Unlocks: Story 007, Story 010
