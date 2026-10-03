# Story 006: Harden lint rule kinds and the registered rule table

> **Epic**: Test Harness & CI
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0009
**Requirement**: `TR-test-???`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Decision 5 table and rules; Risks "false positives")
**ADR Decision Summary**: A declarative table `lint_rules.json` drives kinds `forbid`, `only_in`, `project_setting`, `manifest`, `secret`, `custom`; each rule has id, source, severity, kind, scope globs, pattern fields, message and an explicit `allow` list.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `lint_runner.py` and `lint_rules.json` exist (written by another agent). This story verifies every kind and every registered rule against the ADR/manifest lists and closes gaps. Rules owned by later epics' ADRs (0010-0014 additions) are added when those ADRs' code lands; here only the registered list is required.
**Control Manifest Rules (this layer)**:
- Required: `forbid`, `only_in`, `project_setting`, `manifest` (skipped with a warning until the first preset exists), `secret`, `custom`; scene rule scans `.tscn` `[connection ...]` for the deferred flag; a rule whose scope has no file passes with a note; explicit `allow` list per rule.
- Forbidden: inline ignore comments; lints in GDScript or shell.
- Guardrail: BLOCKING vs ADVISORY severity respected in the exit code; `raw_s_in_vector3` is ADVISORY.

## Acceptance Criteria
- [ ] Every rule named in ADR-0009 Decision 5 and the manifest (forbid, only_in, project_setting, manifest, secret, custom lists) exists in `lint_rules.json` with a `source` ADR, or the missing one is added.
- [ ] `--list` prints all rules; `--rule <id>` runs one; an unknown id exits non-zero.
- [ ] `only_in` honours the `allow` glob list; matches in an allowed file pass, in any other fail.
- [ ] `project_setting` parses `project.godot` keys under sections (including nested `[autoload]`) and compares values.
- [ ] A `.tscn` `[connection ...]` with the deferred flag (value 1 in `flags`) fails; without it passes.
- [ ] `manifest` rules skip with a warning when `export_presets.cfg` is absent; `secret` finds keystore files and password keys.
- [ ] ADVISORY findings print but leave exit code 0; BLOCKING findings give non-zero.
- [ ] Each `custom` rule named in the ADR has a named Python function or is listed as pending its owning epic (not silently dropped).

## Implementation Notes
Globs use forward slashes and are matched on repo-relative paths so Windows and Linux agree. Reading files uses LF/CRLF-tolerant decoding. Message text may mention banned tokens; the stripper guarantees they do not self-trigger.

## Out of Scope
- Story 005: stripper
- Story 007: fixtures and self-check
- Story 008: registry coverage meta-rule

## QA Test Cases
- **AC-1**: compare rule ids with the list in ADR-0009 Decision 5 (checked by a unittest reading the JSON)
- **AC-3**: only_in, Given a violation in an allowed and a non-allowed path, Then pass / fail respectively
- **AC-4**: project.godot with and without `[autoload] Game="*res://..."`
- **AC-5**: two `.tscn` snippets
- **AC-6/7**: temp-dir repo with and without presets, severity exit codes
- **AC-8**: custom rule registry test

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tools/ci/tests/test_lint_rule_kinds.py` (Python `unittest`); Logic gate BLOCKING
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 005
- Unlocks: Story 007, 008
