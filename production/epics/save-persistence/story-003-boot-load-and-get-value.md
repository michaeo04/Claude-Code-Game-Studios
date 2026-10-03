# Story 003: SaveCore boot load, get_value and first launch

> **Epic**: Save & Persistence
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-001`, `TR-save-persistence-004`, `TR-save-persistence-005`, `TR-save-persistence-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `SaveCore.boot_load()` runs once, synchronously, before Scoring and Settings exist. Missing file gives `MISSING`, defaults and one INFO `FILE_MISSING`. Successful parse populates the in-memory sections, including keys that fail the type check.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Name is `boot_load`, never `load` (shadows the global). No engine calls in `SaveCore`; everything goes through the injected `SaveFs`.
**Control Manifest Rules (this layer)**:
- Required: constructor `(fs: SaveFs, clock: Callable, wall_clock: Callable, log_sink: Callable, config: SaveConfig)`; getters return exactly the stored value or the caller's own default; no "loaded" signal.
- Forbidden: `ConfigFile`/`FileAccess`/`DirAccess`/`Time.`/`OS.` in `SaveCore`; `SaveCore` inventing a default; autoload.
- Guardrail: construction order puts `SaveService` second, before Scoring/Settings.

## Acceptance Criteria
- [x] **AC-4 [C]** `get_value`/`set_value` round-trip for `[scoring]` and `[settings]` returns exactly what was stored; on any read failure the returned value is exactly the caller's `default`, never a `SaveCore`-supplied one. `[cosmetics]` is not exercised.
- [x] **AC-5 [C]** Constructing `SaveCore` with a `read_config` returning a populated fixture and calling `boot_load()`: immediately, with no signal and no frame, `get_value` for every fixture key returns the loaded value.
- [x] **AC-12 [C]** `read_config` status `MISSING` (via `exists` false): every `get_value` returns its default, exactly one INFO log (not ERROR); the first `set_value` afterwards runs the orphan-`.tmp` check (finds nothing) then the normal write sequence, creating the file (write sequence verified in Story 004).

## Implementation Notes
Create `src/core/persistence/save_core.gd`. Boot order per ADR-0007 Decision 3: `exists(REAL)` false -> `MISSING` and one INFO `FILE_MISSING`; else `read_config(REAL)`; parsed sections become memory, schema read through `PersistMath.schema_compatible` (an unreadable or incompatible file is handled in Stories 006-007; here the happy path and MISSING). `get_value(section, key, default)` returns the stored value when present and typeof-equal, else `default`; it adds nothing of its own. First-launch memory is empty; `[_meta].schema_version` is written by the first `set_value` (Story 004) at `CURRENT_SCHEMA_VERSION`.

## Out of Scope
- Story 004: write path.
- Story 006: failure branches of the read and per-key logging.
- Story 007: oversize guard, backup rotation.

## QA Test Cases
- **AC-4**: round trip and default fidelity
  - Given: a fixture with `personal_best` 500 and `tilt_sensitivity` 1.5; a second core on a `PARSE_ERROR` reader
  - When: `get_value` is called with distinct caller defaults (e.g. 77, 9.5)
  - Then: stored values on the first core; exactly 77 and 9.5 on the second
  - Edge cases: default of a different type than stored is returned unchanged
- **AC-5**: Given populated fixture; When `boot_load()` then `get_value` in the same call stack; Then all keys equal fixture; Edge: no `await` or signal used.
- **AC-12**: Given `exists` false; When `boot_load()`, `get_value` x3; Then defaults, one INFO log with code `FILE_MISSING`, zero ERROR logs; Edge: second `boot_load()` is not required to log again.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/save_persistence/save_persistence_boot_load_test.gd`
**Status**: Passing
**Evidence**: save_persistence_boot_load_test.gd: test_get_value_returns_stored_values_after_boot_load, test_get_value_returns_caller_default_on_parse_error, test_boot_load_is_synchronous_and_every_fixture_key_is_readable, test_missing_file_gives_defaults_and_one_info_file_missing, test_missing_file_first_set_value_checks_tmp_then_writes (7 tests)

## Dependencies
- Depends on: Story 001, Story 002
- Unlocks: Stories 004, 006, 007, 008
