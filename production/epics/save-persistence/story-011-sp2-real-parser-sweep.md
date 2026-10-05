# Story 011: SP-2 real-parser sweep against hostile files

> **Epic**: Save & Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-05

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-020`, `TR-save-persistence-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: SP-2 is BLOCKING at first-playable. Hand-crafted files go through the real `SaveService` boot-load path. Pre-committed failure response: if a parsing-time side effect is confirmed, add a pre-parse content sniff that rejects the file before `ConfigFile.load`.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Whether `VariantParser` (used by `ConfigFile`) can instantiate objects or typed constructors while parsing is unverified for 4.7.2. Behaviour on truncated, binary, oversized files is unverified (verification item 3).
**Control Manifest Rules (this layer)**:
- Required: oversized files never reach `read_config`; every case ends loaded cleanly or rejected with the right error code.
- Forbidden: parsing a file over `SAVE_FILE_SIZE_MAX`; weakening Rule 7 to hide a failure.
- Guardrail: 512 MB mobile ceiling; files over 64 KB rejected before parsing.

## Acceptance Criteria
- [ ] **SP-2** Battery run on desktop Godot 4.7.2 (editor and export) and, if available, a device: `[_meta].schema_version` stored as String, Array and bool; a typed-constructor-style entry in a value position; files at and just over `SAVE_FILE_SIZE_MAX`; a truncated file and a binary-garbage file. Pass: each case loads cleanly or is rejected with the correct Rule 7 code, no crash, hang or escaping exception, and no oversized file reaches `read_config`. Fail: any crash/hang/exception, or an oversized file reaching `read_config`.
- [x] The parser side-effect question (GDD Open Question 1) is answered in the evidence with the exact payload used; if confirmed, the pre-parse sniff is added and the sweep re-run.
- [x] Each hostile file is added as a fixture under `tests/support/hostile_saves/` so an automated regression test (integration) re-runs the desktop part.

## Implementation Notes
Drive the real `SaveService` with a path override pointing at a temp directory (Story 009). Record timing per case to spot hangs. Record the result under `production/qa/evidence/save-persistence-sp2.md` with Godot version, platform, payloads, outcomes. Gate: first-playable.

## Out of Scope
- Story 012: kill tests. Story 013: latency.
- Logic of backup naming (Story 007).

## QA Test Cases
- **Setup**: build the files listed above; boot `SaveService` per file in a fresh process or scene.
- **Verify**: observed log code, defaults returned, backup file present, process alive, wall time under a stated bound.
- **Pass condition**: every row meets the Pass line above; any Fail row blocks first-playable.
- Edge cases: file of exactly `SAVE_FILE_SIZE_MAX` bytes; empty file (expects `SCHEMA_INCOMPATIBLE`, backed up).

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/save-persistence-sp2.md` plus `tests/integration/save_persistence/save_persistence_hostile_files_test.gd` (desktop part)
**Status**: [~] Desktop part created and green; export and device runs outstanding (story stays Ready)
**Evidence**: `production/qa/evidence/save-persistence-sp2.md`, `tests/integration/save_persistence/save_persistence_hostile_files_test.gd` (12 tests)

## Dependencies
- Depends on: Story 007, Story 009
- Unlocks: first-playable gate (blocking)
