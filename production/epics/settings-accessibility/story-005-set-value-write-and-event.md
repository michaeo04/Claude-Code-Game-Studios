# Story 005: set_value writes on change, no-ops on equal, emits setting_changed once

> **Epic**: Settings & Accessibility
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

> **Unblocked 2026-10-03**: the GDD Core Rule 5 amendment landed (a slider commits its value on `drag_ended`; `set_value` is never called per `value_changed`), so the Partial coverage of `TR-settings-accessibility-005` is closed.

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: `set_value` is synchronous and has no coalescing; Settings and Menus must commit a slider on `drag_ended`, never on every `value_changed`. Signals are declared on the owning core.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `setting_changed(key: String, value: Variant)` is declared on `SettingsCore`; handlers are typed (ADR-0002 Decision 7). Test signals with GUT `watch_signals` or a recording Callable.
**Control Manifest Rules (this layer)**:
- Required: `set_value_seam("settings", key, value)` called immediately and synchronously on an actual change.
- Forbidden: calling `set_value` from every slider `value_changed` (a Menus constraint, noted in Implementation Notes); deferring the write.
- Guardrail: exact `==` for call counts; `1e-6` for floats.

## Acceptance Criteria
- [ ] **AC-9** `set_value("haptics_enabled", false)` with current `true`: `set_value_seam` is called exactly once with `("settings","haptics_enabled",false)`; `get_haptics_enabled()` then returns `false`.
- [ ] **AC-10** `set_value("haptics_enabled", true)` twice with current `true`: zero `set_value_seam` calls and zero `setting_changed` emissions; a companion row covers all five keys.
- [ ] **AC-11** One actual change emits exactly one `setting_changed(key, new_value)` with the right pair; a sequence of three changes to three keys emits three separate emissions, each correct; the no-op emits none.

## Implementation Notes
Order inside `set_value(key, value) -> bool`: reject unknown key (story 006); compare with current in-memory value and return without effect when equal; update memory; call `set_value_seam` immediately; emit `setting_changed(key, new_value)` once. Return `true` for a recognised key even on a no-op. Equality is by value and type. `tilt_sensitivity` is routed through F2 first (story 006). Menus (not this core) owns drag-end commit; record that in the doc comment.

## Out of Scope
- Story 006: unknown keys and runtime sensitivity validation.
- Story 007: failed write behaviour.

## QA Test Cases
- **AC-9**: write once
  - Given: fixture core, stored `haptics_enabled` true, set spy
  - When: `set_value("haptics_enabled", false)`
  - Then: one spy entry `("settings","haptics_enabled",false)`; getter false
  - Edge cases: none.
- **AC-10**: no-op on equal
  - Given: current values equal to the sent ones, for each of five keys
  - When: `set_value` twice with the current value
  - Then: zero seam calls, zero signal emissions
  - Edge cases: always-write mutation fails every row.
- **AC-11**: one event per change
  - Given: signal watcher
  - When: change three different keys in turn; then repeat a no-op
  - Then: three emissions with correct key/value; none for the no-op
  - Edge cases: batching or coalescing fails.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/settings_accessibility/settings_accessibility_set_value_test.gd`
**Status**: [x] Created and passing
**Evidence**: tests/unit/settings_accessibility/settings_accessibility_set_value_test.gd: test_ac9_*, test_ac10_*, test_ac11_*

## Dependencies
- Depends on: Story 002; Story 002 (the GDD Core Rule 5 amendment is done)
- Unlocks: Story 006, Story 007, Story 008, Story 011
