# Story 003: Live tilt sensitivity update from Settings to TiltCore

> **Epic**: Code Review Follow-ups
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-3 h
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

- [x] `TiltCore.set_sensitivity(value)` exists (validated against `TiltConfig` bounds, one `SETTING_CLAMPED` log when corrected, no effect on the ring buffer or the neutral).
- [x] Wiring (adapter in `src/core/`): `SettingsCore.setting_changed("tilt_sensitivity", v)` calls `TiltCore.set_sensitivity` before the next `poll`.
- [x] Integration test: change the sensitivity mid-run; the next published `steer` scales accordingly and no other output changes.

---

## Implementation Notes

Finding 3. GDD `settings-accessibility.md` rule 6: the two live consumers must react to `setting_changed`.

---

## Out of Scope

- Anything not named in the acceptance criteria; other findings have their own stories.

---

## QA Test Cases

One test per acceptance criterion above (Given the pre-fix behaviour described in the finding, When the scenario runs, Then the corrected behaviour). Each test fails on the pre-fix code and passes after.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/composition_root/` test
**Status**: [x] Created and passing
**Evidence**: `tests/integration/composition_root/composition_root_live_sensitivity_test.gd` (test_mid_run_change_scales_next_steer_and_nothing_else, test_set_sensitivity_out_of_range_clamps_with_one_log, test_other_keys_are_ignored)

---

## Dependencies

- Depends on: CRF-002 (the wiring pattern)
- Unlocks: the real wiring stories of the composition-root epic
