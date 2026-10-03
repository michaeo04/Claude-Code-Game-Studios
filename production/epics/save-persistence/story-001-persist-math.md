# Story 001: PersistMath pure functions

> **Epic**: Save & Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-003`, `TR-save-persistence-011`, `TR-save-persistence-016` (the `is_serializable_type` part)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `PersistMath` is a static, stateless class holding `schema_compatible` (F1), `read_valid`, `read_error_code` (F2) and `is_serializable_type`. A raw `Object` and a NaN or infinite `float` are not serializable.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. Pure GDScript: the `is_int` guard must use `typeof(x) == TYPE_INT` (a `bool` is not an `int` in `typeof`), never a bare `<` against an untrusted Variant.
**Control Manifest Rules (this layer)**:
- Required: `PersistMath` static; tests are `[system]_[feature]_test.gd`, `extends GutTest`, fixtures built by a factory in `tests/support/`.
- Forbidden: `ConfigFile`, `FileAccess`, `DirAccess`, `Time.`, `OS.` in `PersistMath`; any `[autoload]` entry.
- Guardrail: unit tests never touch the real file system.

## Acceptance Criteria
- [ ] **AC-1 [M]** `schema_compatible(v, 3)`: 0 -> false, -1 -> false, 1/2/3 -> true, 4 -> false; type-guard rows `"1"`, `true`, `[1]` -> false with no runtime error (the comparison is never attempted on a non-int).
- [ ] **AC-2 [M]** `read_valid(parsed_ok, compatible, has_key, type_matches)` truth table: all true -> true; each single factor false -> false (one row per factor); all false -> false.
- [ ] **AC-3 [M]** `read_error_code` precedence: `(false,true,true,true)` -> `FILE_UNREADABLE`; `(true,false,true,true)` -> `SCHEMA_INCOMPATIBLE`; `(true,true,false,true)` -> no code; `(true,true,true,false)` -> `TYPE_MISMATCH`; `(false,false,true,true)` -> `FILE_UNREADABLE`.
- [ ] **AC-13 [M]** `is_serializable_type` is false for a raw `Object`/`RefCounted` (and, per ADR-0007 Decision 4, for NaN/infinite `float`), true for `int`, `float`, `String`, `bool`, `Vector2`, `Array`, `Dictionary`. (The `SaveCore.set_value` half of AC-13 is Story 004.)

## Implementation Notes
Create `src/core/persistence/persist_math.gd` (`class_name PersistMath`, static funcs, doc comments on every public function). Use `CURRENT_SCHEMA_VERSION` as a parameter to F1 so tests pass 3 while the shipped constant is 1. `read_error_code` returns an empty string for "no code". Log code names are string constants on `PersistMath` (`FILE_UNREADABLE`, `SCHEMA_INCOMPATIBLE`, `TYPE_MISMATCH`, `UNSERIALIZABLE_VALUE`, `WRITE_FAILED`, `FILE_MISSING`). The per-key once-per-load logging change (TR-012 open point) does not affect these pure functions: the precedence order is unchanged. Test inputs for AC-1 must go through the same entry point `SaveCore` will use, with a `Variant` parameter.

## Out of Scope
- Story 002: `SaveFs`, `SaveConfig`, test fixture factory.
- Story 003/004: any `SaveCore` behaviour.
- Story 006: how and how often the codes are logged.

## QA Test Cases
- **AC-1**: schema compatibility
  - Given: `CURRENT_SCHEMA_VERSION_TEST` = 3
  - When: `schema_compatible` is called with 0, -1, 1, 2, 3, 4, `"1"`, `true`, `[1]`
  - Then: false, false, true, true, true, false, false, false, false; no error raised
  - Edge cases: a mutation that skips the type guard must fail by throwing on the String/Array rows
- **AC-2**: `read_valid` truth table; Given each factor combination; Then exact `==` bool; Edge: all-false row.
- **AC-3**: error precedence; Given the five tuples; Then the stated codes; Edge: absent key returns no code.
- **AC-13 [M]**: Given values of each listed type plus `Object.new()`, `NAN`, `INF`; Then bool as stated; Edge: free the `Object` in the test.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/save_persistence/save_persistence_persist_math_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: None (cross-epic: test-harness-ci spike T-1 must be passed so GUT runs)
- Unlocks: Stories 003, 004, 006
