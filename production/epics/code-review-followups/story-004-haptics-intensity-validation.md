# Story 004: Validate `haptics_intensity` in SettingsCore

> **Epic**: Code Review Follow-ups
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context

**GDD**: none (code review finding, `production/qa/code-review-2026-10-04.md`)
**Requirement**: `TR-code-review-???`
**ADR Governing Implementation**: ADR-0002 (injected sinks, single tick driver); ADR-0009 (test rules)
**ADR Decision Summary**: cores are pure RefCounted classes that receive time, sinks and seams by injection; the composition root is the only place that wires them.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none (GDScript only)
**Control Manifest Rules (this layer)**:
- Required: static typing; pure cores with no engine calls; values from config.
- Forbidden: autoloads; `CONNECT_DEFERRED`; editing `tools/ci/lint_rules.json` to turn a lint green (a story that needs a new rule adds it with fixtures).
- Guardrail: `python tools/ci/run_ci.py --only all` stays green and finishes in about 15 s.

---

## Acceptance Criteria

- [x] A stored `haptics_intensity` outside the Platform Services range, or non-finite, is replaced by the nearest bound or the default at boot with one `SETTING_CLAMPED` log.
- [x] `set_value("haptics_intensity", NAN)` and out-of-range values are rejected or clamped exactly as the Settings GDD specifies for sensitivity (same code path), memory and the persisted value never differ.
- [x] The range comes from `HapticsConfig` (single source), not a copy.

---

## Implementation Notes

Finding 4. Decide reject vs clamp by following the existing tilt sensitivity rule (Settings Core Rule 4).

---

## Out of Scope

- Anything not named in the acceptance criteria; other findings have their own stories.

---

## QA Test Cases

One test per acceptance criterion above (Given the pre-fix behaviour described in the finding, When the scenario runs, Then the corrected behaviour). Each test fails on the pre-fix code and passes after.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/` test file named in the story, must exist and pass
**Status**: [x] Created and passing
**Evidence**: `tests/unit/settings_accessibility/settings_accessibility_haptics_intensity_test.gd` (boot clamp/NaN/zero tests, set_value NaN/out-of-range tests, test_range_comes_from_haptics_config)

---

## Dependencies

- Depends on: None
- Unlocks: the real wiring stories of the composition-root epic
