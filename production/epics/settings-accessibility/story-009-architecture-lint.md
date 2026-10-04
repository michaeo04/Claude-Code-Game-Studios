# Story 009: Architecture and coupling lint for SettingsCore and SettingsMath

> **Epic**: Settings & Accessibility
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: Lints are Python 3 stdlib rules in `tools/ci/lint_rules.json`, read by `tools/ci/lint_runner.py`, with comments and strings stripped first and an explicit `allow` list per rule; each rule needs one passing and one failing fixture.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Fixtures that are deliberately invalid GDScript live as `.txt` or under a `.gdignore` folder.
**Control Manifest Rules (this layer)**:
- Required: rule `kind`, `scope`, `severity` BLOCKING, `message`; tests in `tools/ci/tests/` with a passing and a failing fixture.
- Forbidden: inline ignore comments; lints written in GDScript or shell; `[autoload]` entries for game systems.
- Guardrail: full CI run at most 5 minutes.

## Acceptance Criteria
- [ ] **AC-18** A static scan of `SettingsCore` and `SettingsMath` finds zero matches for `ConfigFile`, `FileAccess`, `DirAccess`, `Input.`, `DisplayServer.`, `Engine.`, `Time.`, `OS.`, `get_tree`, and zero references to Platform-Services-, Tilt-Input- or Tube-Track-shaped symbols beyond the opaque key strings; `project.godot` has no `[autoload]` entry for either class.

## Implementation Notes
Add a `forbid` rule scoped to `src/**/settings_core.gd` and `src/**/settings_math.gd` (final paths per composition-root) with the engine-call regex, plus a second rule forbidding symbols such as `PlatformServices`, `PlatformCore`, `TiltInput`, `TubeTrack`; the existing `project_setting` no-autoload rule already covers the autoload part, so assert it is in force. Per ADR-0009, a rule whose scope has no file yet passes with a note. Add the two fixtures per rule under `tools/ci/tests/`. Check whether `tools/ci/lint_runner.py` (currently untracked) is already committed by test-harness-ci before editing.

## Out of Scope
- Story 008: runtime call-surface checks.
- The registry-wide lints owned by test-harness-ci.

## QA Test Cases
- **AC-18**: coupling lint
  - Given: a clean `SettingsCore` fixture and a fixture containing `OS.get_name()` and `TiltInput`
  - When: run `python tools/ci/lint_runner.py`
  - Then: the clean fixture passes; the dirty fixture fails with the rule id; the real source passes
  - Edge cases: a banned word inside a comment or string must not trigger (stripper); `Time.` must not match `Timer`/`SomeTime.`.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tools/ci/tests/` unit cases for the two rules, plus a green `python tools/ci/run_ci.py --only lint`
**Evidence**: `tools/ci/tests/test_lint_settings_rules.py` (token, Timer/SomeTime, comment/string, CRLF, real sources, no-autoload rule and project.godot) plus fixtures `forbidden_settings_core_purity` and `forbidden_settings_core_coupling` (rules of the same ids in `tools/ci/lint_rules.json`).
**Status**: [x] Created and passing

## Dependencies
- Depends on: Story 002 (source files exist); test-harness-ci epic (lint runner)
- Unlocks: None
