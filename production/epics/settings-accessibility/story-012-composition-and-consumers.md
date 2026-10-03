# Story 012: Composition wiring, haptics push and live consumer reads

> **Epic**: Settings & Accessibility
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

> **Note**: GDD AC-20 is deferred (no owner/date). BLOCKING only once an owner and date are named. Consumers of other epics (Tilt Input, Tube Track, Environment) may not exist yet; rows for a missing consumer are written against its published interface and marked pending in the evidence doc, never skipped in code.

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-009`, `TR-settings-accessibility-012`, `TR-settings-accessibility-007`, `TR-settings-accessibility-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0006: Android platform integration; ADR-0003: Renderer choice and tube render route; ADR-0011: UI architecture
**ADR Decision Summary**: Construction order is `PlatformServices`, `SaveService`, `SettingsCore` (push `haptics_*` to Platform Services), then the rest. Tube Track pulls `get_seam_contrast_scale()` every frame in every state and writes its material only on change; Environment reads `colorblind_safe_enabled` by getter plus `setting_changed`. Menus slider rows use `UiSlider` and commit on drag end.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0003/0006/0011 are HIGH; nothing here calls a post-cutoff API directly, but the shader parameter write and the `drag_ended` commit are exercised on those paths. Both live consumers read the getter at construction or map load as well as on `setting_changed`, since signals are not replayed.
**Control Manifest Rules (this layer)**:
- Required: `SettingsCore` built after `SaveService.boot_load()` and before `RunStateCore`; `set_haptics_enabled` pushed at construction; `_wire()` rows typed; sliders commit on `drag_ended`.
- Forbidden: `_process` in Settings; an autoload; Settings calling Platform Services after construction beyond the push.
- Guardrail: `_tick()` spy test asserts the construction order.

## Acceptance Criteria
- [ ] **AC-20 (deferred)** Platform Services reading `get_haptics_enabled()`, Tilt Input reading `get_tilt_sensitivity()` under its own `sensitivity` name, and Tube Track reading `get_seam_contrast_scale()` each reflect a live setting change.
- [ ] GDD Core Rules 6 and 8 (no AC id; covered by `TR-settings-accessibility-009`): after a stored `reduced_motion_enabled` true, the first frame already has seam scale 0.0 (getter read at construction), and after a runtime change both live consumers update without relying on the signal alone.

## Implementation Notes
In the composition-root story's `GameRoot`, construct `SettingsCore` with `save.get_value`, `save.set_value` and the shared `log_sink`, then call `platform.set_haptics_enabled(settings.get_haptics_enabled())` and the intensity setter (named by platform-services). Add a `_wire()` row for `setting_changed` to the haptics push (rank per ADR-0002 table). Tests: a headless composition spy with real `SettingsCore` and fake consumers asserting the construction order, the first-frame reads, and that a `set_value` produces the expected consumer reads. The Menus settings screen belongs to menus-screen-flow; record the slider drag-end contract in the evidence doc only.

## Out of Scope
- Story 011: Save round trip.
- The Settings screen layout (menus-screen-flow epic, which cites its UX spec).

## QA Test Cases
- **AC-20**: live consumers
  - Given: composed core with fake Platform, Tilt, Tube Track and Environment consumers reading the getters
  - When: `set_value` for each of haptics, sensitivity, reduced motion, colorblind
  - Then: each consumer's next read returns the new value; Tube Track's first frame with a stored `true` reads 0.0
  - Edge cases: `setting_changed` missed before wiring; the getter read at construction still gives the correct value.
- **Construction order**
  - Given: the `GameRoot` construction spy
  - When: composition runs
  - Then: `PlatformServices`, `SaveService`, `SettingsCore` in that order, haptics pushed once before `RunStateCore` exists
  - Edge cases: none.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/settings_accessibility/settings_accessibility_consumers_test.gd`; pending rows documented in `production/qa/evidence/settings-accessibility-consumers.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 004, Story 005, Story 011; cross-epic: composition-root (`GameRoot` and `_wire()`), platform-services, tilt-input, tube-track
- Unlocks: Epic completion
