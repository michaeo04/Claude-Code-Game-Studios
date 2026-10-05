# Story 010: Architecture and coupling lints

> **Epic**: Save & Persistence
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-05

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-019`, `TR-save-persistence-021` (no interface to Run State)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary); ADR-0007: Persistence implementation
**ADR Decision Summary**: Lints are rules in `tools/ci/lint_rules.json` run by `tools/ci/lint_runner.py` (stdlib only), each with a passing and a failing fixture. `ConfigFile`/`FileAccess`/`DirAccess` are `only_in` `save_service.gd`; no autoload entry for game systems.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Lints scan GDScript after comments and strings are stripped by the shared state machine; fixtures that are deliberately invalid GDScript live as `.txt` files.
**Control Manifest Rules (this layer)**:
- Required: each rule has `id`, `source`, `severity`, `kind`, `scope`, pattern fields, `message`; an explicit `allow` list; a rule whose scope has no file yet passes with a note.
- Forbidden: a rule without both fixtures; scanning raw text without stripping comments and strings.
- Guardrail: lint failures are BLOCKING.

## Acceptance Criteria
- [x] **AC-16 [L]** `SaveCore` and `PersistMath` (and the `SaveFs` base class) extend `RefCounted` or are static and contain none of `ConfigFile`, `FileAccess`, `DirAccess`, `Input.`, `DisplayServer.`, `Engine.`, `Time.`, `OS.`, `get_tree`; neither references `theta`, `phase` or `RunState`; no `[autoload]` entry exists for either class.
- [x] **AC-17 [L]** `SaveService` (`save_service.gd`) is the sole file in `src/` matching `ConfigFile`, `FileAccess`, `DirAccess`, confirmed both ways: present there, absent everywhere else.

## Implementation Notes
Add the `forbid` rule (scope `src/core/persistence/{persist_math,save_core,save_fs}.gd`) and the `only_in` rule from ADR-0009 Decision 5; extend the `project_setting` autoload rule if it does not already name the two classes. Python `unittest` cases in `tools/ci/tests/` with one passing and one failing fixture per rule. Note the existing untracked `tools/ci/lint_runner.py` belongs to the test-harness-ci epic; add rules, do not fork the runner.

## Out of Scope
- test-harness-ci epic: the runner itself.
- Story 014: the `allowBackup` manifest rule.

## QA Test Cases
- **AC-16**: Given a failing fixture `save_core_bad.txt` containing `Time.get_unix_time_from_system()`; When the rule runs; Then BLOCKING failure naming the file and line; Given the real files; Then pass; Edge: a banned word inside a comment or string is ignored.
- **AC-17**: Given a fixture where another file uses `FileAccess`; Then failure; Given only `save_service.gd` uses it; Then pass; Edge: the allow list is exact-path.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tools/ci/tests/test_save_persistence_lints.py` (run by `python tools/ci/lint_runner.py` step 4a)
**Status**: [x] Created
**Evidence**: `tools/ci/tests/test_save_persistence_lints.py` (PurityTest, IoOnlyInSaveServiceTest; 9 tests), rule `forbidden:save_core_purity`, fixtures `tools/ci/tests/fixtures/forbidden_save_core_purity/`; AC-17 uses the existing rule `forbidden:save_io_outside_save_service`.

## Dependencies
- Depends on: Story 002 (files exist); cross-epic: test-harness-ci (lint runner)
- Unlocks: Story 014
