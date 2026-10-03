# Story 007: Corrupt-file backup, rotation and oversize guard

> **Epic**: Save & Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-013`, `TR-save-persistence-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: On a file-level failure the old file is renamed to `save.cfg.corrupt-<wall_clock()>-<n>` (n zero-based, incremented while that name exists), then `list_backups` is sorted by name and the oldest are deleted until at most `CORRUPT_BACKUP_RETENTION` remain. A file whose `size(REAL)` exceeds `SAVE_FILE_SIZE_MAX` is treated as `PARSE_ERROR` without calling `read_config`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Real `DirAccess.open("user://").get_files()` listing and `FileAccess.get_length()` cost are verification items 4-5, covered by Story 009. Use `wall_clock()` (Unix seconds int), never `clock()` and never `Time.`.
**Control Manifest Rules (this layer)**:
- Required: oversize check uses `fs.size`; rename aside before any new write; sort backups by name.
- Forbidden: parsing an oversized file; overwriting an existing backup; `Time.` in the core.
- Guardrail: `SAVE_FILE_SIZE_MAX` 64 KB, retention default 5 (test value 3).

## Acceptance Criteria
- [ ] **AC-15 [C]** On a `PARSE_ERROR` load, `rename` moves the old file to `save.cfg.corrupt-<wall_clock()>-<n>` before any new write; two events on the same scripted second differ only in `<n>` (0 then 1); at retention 3 the fourth corruption triggers exactly one `delete` of the oldest prior backup, the first three trigger none.
- [ ] **Edge Case (oversized file, no AC id in the GDD)** `size(REAL) > SAVE_FILE_SIZE_MAX`: `read_config` is never called, the load is a `FILE_UNREADABLE` ("oversized"), the file is backed up aside by the same naming; a file exactly at the limit is read normally.

## Implementation Notes
Extend `boot_load` (ADR-0007 Decision 3 steps 2 and 5). After a file-level failure the in-memory state is empty and the first `set_value` creates a fresh file with `[_meta]`. Counter `n` is found by asking `exists(candidate)` until false. Rotation reads `list_backups("user://", "save.cfg.corrupt-")`, sorts by name, deletes from the front. Name-sort matches age order only while the timestamp has equal digit count; note this in a code comment and test with 10-digit stamps.

## Out of Scope
- Story 006: the logging codes and per-key behaviour.
- Story 011: real oversized files through the real parser.

## QA Test Cases
- **AC-15**: Given `PARSE_ERROR` and scripted `wall_clock` 1700000000 twice; When two cores boot against one recording fake; Then rename targets `...-1700000000-0` and `...-1700000000-1`; Given retention 3 and four events; Then delete called once at the fourth, none before; Edge: backup listing returned unsorted.
- **Oversize**: Given `size` returns `SAVE_FILE_SIZE_MAX + 1`; When `boot_load`; Then `read_config` absent from the log, rename aside present, defaults returned; Edge: size equals the max reads normally; `size` -1 with `exists` true is treated as unreadable.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/save_persistence/save_persistence_corrupt_backup_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 003, Story 004 (Story 006 recommended first for the codes)
- Unlocks: Story 009, Story 011
