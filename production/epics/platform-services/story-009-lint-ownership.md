# Story 009: CI lint for OS-call ownership (AC-12)

> **Epic**: Platform Services
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/platform-services.md`
**Requirement**: `TR-platform-services-001`, `TR-platform-services-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Decision 5 lint framework: `only_in` and `forbid` rules); ADR-0006: Android platform integration (Decision 1)
**ADR Decision Summary**: Lints are Python 3 stdlib rules in `tools/ci/lint_rules.json` run by `tools/ci/lint_runner.py` over comment- and string-stripped GDScript, with an explicit allowlist field (never inline ignore comments) and a passing and failing fixture per rule.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No engine API. Existing related rules in `lint_rules.json` (`forbidden:pause_resume_as_pause_signal`, `forbidden:always_deferred_lifecycle_flush`, `forbidden:ui_cancel_for_back`) must not be duplicated; add only what AC-12 needs.
**Control Manifest Rules (this layer)**:
- Required: lints in Python 3 stdlib, rule table driven; each rule has a pass and a fail fixture or the runner self-check fails; the lint is a blocking CI gate before the first Platform Services story is Done.
- Forbidden: lints in GDScript or shell; inline ignore comments; lint of `tests/` (scope is `src/` only).
- Guardrail: full CI run at most 5 minutes.

## Acceptance Criteria
- [ ] **AC-12a [L]** `NOTIFICATION_APPLICATION_(FOCUS_IN|FOCUS_OUT|PAUSED|RESUMED)`, `NOTIFICATION_WM_GO_BACK_REQUEST`, `Input\.vibrate_handheld`, `DisplayServer\.(get_display_safe_area|screen_get_refresh_rate|screen_get_size|screen_set_keep_on)` and `ProjectSettings\.` match only the `PlatformServices` node file (path allowlist). Tilt Input rule 9 is edited first so both agree.
- [ ] **AC-12b [L]** `PlatformCore`, `PlatformMath` and `RateLimitedLog` extend `RefCounted` (or are static), not Node, and contain no `Input.`, `DisplayServer.`, `ProjectSettings.`, `Engine.`, `Time.`, `OS.` or `get_tree`.
- [ ] Each lint has a fixture self-test on `src/` only: a violation reports file and line; a violation inside a comment passes.

## Implementation Notes
Add two rules to `tools/ci/lint_rules.json` (`only_in` for 12a with the allowlist `src/**/platform_services.gd` or the path chosen by Story 008; `forbid` with scope globs on the three core files for 12b) and fixtures under `tools/ci/tests/`. Mind the allowlists already granted to other rules (Tilt Input owns sensor reads, Save owns file I/O). The stripper keeps `""` quotes and preserves newlines so line numbers are correct. Fixtures cover the comment case, a violation in another file, and the allowed file.

## Out of Scope
- Story 010: manifest/project-setting lint (AC-13)
- Tokenizer hardening listed in GDD OQ 22 (`"""`, `#` in strings, aliases, `call()`, `Engine.get_singleton`) unless the runner already covers it

## QA Test Cases
- **AC-12a**: ownership allowlist
  - Given: fixture `src/` files with each banned token in the allowed node file and elsewhere
  - When: `python tools/ci/lint_runner.py --rule <id>` runs
  - Then: elsewhere reports file and line; the allowed node file and comments pass
  - Edge cases: token in a comment or string passes
- **AC-12b**: core purity
  - Given: fixtures of a core extending `Node` and one calling `Time.`
  - When: the rule runs
  - Then: both fail with file and line; a clean RefCounted core passes
  - Edge cases: `get_tree` substring inside another identifier is not flagged by word-boundary regex

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tools/ci/tests/` unittest cases with one passing and one failing fixture per rule (ADR-0009 Decision 5); run by `python tools/ci/run_ci.py --only lint`
**Evidence**: `tools/ci/tests/test_lint_platform_rules.py` (OwnershipTest, PurityTest) plus pass/fail fixtures for `forbidden:platform_os_calls_outside_platform_services`, `forbidden:project_settings_outside_platform_services`, `forbidden:platform_core_purity`.

## Dependencies
- Depends on: Story 008; test-harness-ci lint runner stories
- Unlocks: Done status of every Platform Services story (the lint gate precedes first Done)
