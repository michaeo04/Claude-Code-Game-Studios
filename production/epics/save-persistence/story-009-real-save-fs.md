# Story 009: Real SaveFs implementation and file round trip

> **Epic**: Save & Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-008`, `TR-save-persistence-019` (SaveService is the sole file with the real calls)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: The real `SaveFs` is an inner class of `SaveService`: `write_config` builds a `ConfigFile`, `set_value` per key, `save(path) == OK`; `read_config` builds a fresh `ConfigFile` per read, `ERR_FILE_NOT_FOUND` -> `MISSING`, any other non-`OK` -> `PARSE_ERROR`; `rename` is `DirAccess.rename_absolute`, `delete` is `remove_absolute`, `size` is `FileAccess.open(READ).get_length()` (-1 if null), `list_backups` is `DirAccess.open(dir).get_files()` filtered by prefix.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION on 4.7.2 (not in the engine reference): `ConfigFile.save` non-`OK` on failure (item 2/10), `get_length()` is cheap (4), `get_files()` lists backups (5), int vs float preserved on round trip (8), stable section order (9), empty file loads `OK` with no sections (11), `OS.get_user_data_dir()` logged once (12). Record each result in the evidence doc.
**Control Manifest Rules (this layer)**:
- Required: real calls only in `save_service.gd`; integration tests write only under a unique per-test temporary directory (including `user://`) deleted in `after_each`.
- Forbidden: reusing a `ConfigFile` across reads; `.cfg` at another path; a JSON/SQLite store.
- Guardrail: test files never touch the player's real `user://save.cfg`.

## Acceptance Criteria
- [ ] Round trip through the real `SaveFs` in a temp directory: `int`, `float`, `bool`, `String`, `Vector2` written by `write_config` read back by `read_config` with the same `typeof` (ADR-0007 Validation Criteria: int and float preserved).
- [ ] An empty file reads as status `OK` with no sections; a missing path reads `MISSING`; a garbage file reads `PARSE_ERROR`; `size` returns -1 for an absent path and the byte length otherwise.
- [ ] `rename` over an existing destination succeeds and leaves the new content; `delete` removes a file; `list_backups` returns exactly the `save.cfg.corrupt-` names.
- [ ] A full `SaveCore` + real `SaveFs` cycle: `set_value`, new core, `boot_load`, `get_value` returns the value (end-to-end, in the temp directory).

## Implementation Notes
Inner class in `src/core/persistence/save_service.gd`; paths are injectable so tests use a per-test directory (the GDD's `REAL`/`TMP` constants stay the production defaults). Call `OS.get_user_data_dir()` once in a log line. Results of the verification items go to `production/qa/evidence/save-persistence-real-fs-notes.md`.

## Out of Scope
- Story 011: hostile files and the parser side-effect question.
- Story 012: kill tests and the Windows rename prerequisite.

## QA Test Cases
- **Round trip**: Given a temp dir; When writing and reading a mixed-type map; Then equal values and `typeof`; Edge: `1` versus `1.0`.
- **Statuses**: Given empty, absent and garbage files; When `read_config`; Then `OK`/empty, `MISSING`, `PARSE_ERROR`; Edge: a failed read does not leak sections into the next read.
- **File ops**: Given an existing destination; When `rename`; Then content replaced and source gone.
- **End to end**: Given a fresh core, one `set_value`, a second core; Then value persists.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/save_persistence/save_persistence_real_fs_test.gd` plus `production/qa/evidence/save-persistence-real-fs-notes.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 004, Story 007, Story 008
- Unlocks: Stories 011, 012, 013
