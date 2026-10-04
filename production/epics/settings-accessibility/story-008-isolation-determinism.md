# Story 008: No consumer seams, closed call surface and determinism

> **Epic**: Settings & Accessibility
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: Systems are read by consumers through getters and signals wired in `GameRoot._wire()`; a core never calls its consumers. ADR-0009 requires deterministic tests with no generated seeds.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Constructor parameters can be enumerated through `get_script().get_script_method_list()` for `_init`.
**Control Manifest Rules (this layer)**:
- Required: constructor takes only `get_value_seam`, `set_value_seam`, `log_sink`, `sensitivity_min`, `sensitivity_max`, `default_sensitivity`.
- Forbidden: any callable shaped like Platform Services, Tilt Input or Tube Track; randomness; time-dependent assertions.
- Guardrail: exact `==` on call logs.

## Acceptance Criteria
- [ ] **AC-15** The full `_init` parameter list is exactly the six names above; nothing consumer-shaped is accepted, so an added unused seam fails.
- [ ] **AC-16** Over a scripted session (construction, actual changes, no-ops, an unknown key, an out-of-range value, a failed write), the only seam calls are `get_value_seam` (exactly 5, at construction), `set_value_seam` (only on actual changes) and `log_sink` (only `SETTING_CLAMPED`/`UNKNOWN_SETTING_KEY`); no seam is called with a section other than `"settings"`.
- [ ] **AC-17** Running the identical scripted sequence through two independently constructed cores yields identical getter returns, `setting_changed` emissions and `log_sink` calls, call for call.

## Implementation Notes
`SettingsCore` has no other constructor parameters, no `randf`, no clock. Build the scripted session once in a test helper in `tests/support/` (a plain function returning the recorded logs) and reuse it for AC-16 and AC-17. Compare recorded logs with `==` on arrays of arrays.

## Out of Scope
- Story 009: static source scan.
- Story 012: real consumers.

## QA Test Cases
- **AC-15**: closed constructor
  - Given: `SettingsCore` script
  - When: read the `_init` argument names
  - Then: equal to the six names, in order
  - Edge cases: an extra defaulted argument fails.
- **AC-16**: seam call surface
  - Given: spies on all three seams
  - When: run the scripted session
  - Then: five reads, writes equal to the number of actual changes, logs only of the two codes, section always `"settings"`
  - Edge cases: a write on a no-op or a failed `set_value` for an unknown key fails.
- **AC-17**: determinism
  - Given: two fresh cores and identical script
  - When: run both
  - Then: recorded sequences equal
  - Edge cases: none.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/settings_accessibility/settings_accessibility_isolation_test.gd`
**Status**: [x] Created and passing
**Evidence**: tests/unit/settings_accessibility/settings_accessibility_isolation_test.gd: test_ac15_*, test_ac16_*, test_ac17_*

## Dependencies
- Depends on: Story 005, Story 006, Story 007
- Unlocks: Story 009
