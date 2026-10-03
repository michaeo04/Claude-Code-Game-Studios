# Story 003: HapticsConfig validation and shipped defaults

> **Epic**: Platform Services
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/platform-services.md`
**Requirement**: `TR-platform-services-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (primary, Decision 1 module shape); ADR-0009: Test framework and CI
**ADR Decision Summary**: Haptic values live in a `HapticsConfig` Resource (data-driven), validated at load; the Resource carries scalar fields only.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: A `.tres` coerces an `int` written into a `float` field; declare floats and write `1.0` in the file. Tests build the config from a named factory function (no `.tres` load) with non-shipped fixture values.
**Control Manifest Rules (this layer)**:
- Required: gameplay values data-driven (external config), never hardcoded; fixtures use distinct non-shipped values with an advisory smoke test asserting shipped defaults.
- Forbidden: no `.tres` load in unit tests (no `ResourceLoader`); no generated seeds.
- Guardrail: exact `==` for integers/codes/counts, `1e-6` for floats.

## Acceptance Criteria
- [ ] **AC-7 [C]** One row per knob; an out-of-range value gives one `KNOB_CLAMPED` and the boundary gives none: `HAPTIC_MIN_INTERVAL` -0.01 and 0.51 become 0 and 0.5; `HAPTIC_MAX_MS` 49 and 501 become 50 and 500; NEAR_MISS and HIT duration 9 and 201 become 10 and 200; UI_TAP duration -1 becomes 0 and 201 becomes 200; amplitude 1.1 becomes 1 and -0.5 becomes 0; priority -1 and 10 become 0 and 9; a NaN or infinite value takes its default (error key `<kind>.<field>`). `HAPTIC_MAX_MS` is validated first: with 50 and HIT 80, HIT becomes 50, one error, and `vibrate` receives 50.
- [ ] **AC-18 [C]** (Config smoke, ADVISORY) The shipped `HapticsConfig` defaults equal the Tuning Knobs table (0.08 s, 200 ms, NEAR_MISS 30/0.5/1, HIT 80/1.0/2, UI_TAP 15/0.3/0); the fixture uses 0.05 so no AC can depend on the wrong one.

## Implementation Notes
Order: `HAPTIC_MAX_MS` first, then per-kind values (duration upper bound is the already-validated `HAPTIC_MAX_MS`). Clamp to the safe range; one `KNOB_CLAMPED` error per value changed through the rate-limited sink; NaN/inf takes the default. Ranges: MIN_INTERVAL 0-0.5; MAX_MS 50-500; NEAR_MISS/HIT duration 10-MAX_MS, UI_TAP 0-MAX_MS; amplitude 0-1; priority 0-9 (int). `HAPTIC_MIN_INTERVAL` is converted once with `roundi(x * 1e6)` (`PlatformMath.interval_us`, Story 001); fractional durations are rounded with `roundi` at load. Validation returns a validated copy; the loaded Resource is never mutated.

## Out of Scope
- Story 005: using the config in the haptic call flow
- `haptics_enabled` / `haptics_intensity` setters (Settings & Accessibility epic supplies them)

## QA Test Cases
- **AC-7**: clamp and NaN handling
  - Given: a fixture config, a recording sink
  - When: each knob is set to the listed out-of-range value and validated
  - Then: the clamped value matches and exactly one `KNOB_CLAMPED` with key `<kind>.<field>` is logged; boundary values log nothing
  - Edge cases: NaN and +inf take the default; MAX_MS 50 with HIT 80 gives HIT 50, one error, `vibrate` receives 50
- **AC-18**: shipped defaults
  - Given: the shipped default `HapticsConfig`
  - When: values are read
  - Then: they equal the Tuning Knobs table
  - Edge cases: fixture value 0.05 differs from shipped 0.08

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/platform_services/platform_services_haptics_config_test.gd` (must pass; AC-18 reported ADVISORY)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001, Story 002
- Unlocks: Story 005
