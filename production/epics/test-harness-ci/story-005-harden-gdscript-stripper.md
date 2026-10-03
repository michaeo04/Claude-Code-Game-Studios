# Story 005: Harden the GDScript comment and string stripper

> **Epic**: Test Harness & CI
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0009
**Requirement**: `TR-test-???`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Decision 5, stripper paragraph)
**ADR Decision Summary**: GDScript is scanned after comments and strings are stripped by one left-to-right state machine, not sequential regex passes; quotes are kept (`""`), newlines preserved, CRLF and LF accepted.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Python 3 stdlib only. `lint_runner.py` exists (written by another agent); this story reviews it against the spec and fixes gaps.
**Control Manifest Rules (this layer)**:
- Required: handle `#` and `##` comments, `#` inside strings, triple-quoted strings (`"""`, `'''`), escapes, raw `r"..."`, `&"name"`, `^"path"`; `$Node/Path` and `%Unique` are not strings; keep quotes; preserve newlines; CRLF and LF.
- Forbidden: lints written in GDScript or shell; sequential regex stripping.
- Guardrail: line numbers of reported matches equal source line numbers.

## Acceptance Criteria
- [ ] Each construct listed above has a Python `unittest` case with an exact expected output (stripped text), including a string containing `#`, an escaped quote, a triple-quoted string spanning lines, and `r"\"` style raw strings.
- [ ] Line count and per-line offsets of stripped output equal the input, for LF and CRLF files.
- [ ] A banned token inside a comment, a string, a doc comment or a message string does not match; the same token in code does.
- [ ] `func\s+_(physics_)?process\b` matches `func _process` and `func _physics_process` and does not match `set_process(true)` or `my_process_x`.
- [ ] An unterminated string or triple-quote at end of file does not crash and does not swallow later files.

## Implementation Notes
Single pass state machine with states code / line-comment / single / double / triple-single / triple-double, with an escape flag; raw prefixes only change escape handling. Replace string bodies by nothing between kept quotes. Do not use inline ignore comments.

## Out of Scope
- Story 006: rule kinds and scope matching
- `.tscn` scanning (Story 006)

## QA Test Cases
- **AC-1**: for each construct
  - Given: a one-line or multi-line GDScript snippet
  - When: strip
  - Then: exact expected string
  - Edge cases: `"a#b"` keeps `""`; `'''x"""y'''`; `&"n"`; `^"res://p"`; `$A/B`; `%U`
- **AC-2**: CRLF input keeps `\r\n`
- **AC-3/4**: rule-level checks via the `forbid` path
- **AC-5**: truncated file fixtures

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tools/ci/tests/test_lint_stripper.py` (Python `unittest`, run as step 4a of `run_ci.py`); Logic gate BLOCKING
**Status**: [ ] Not yet created

## Dependencies
- Depends on: None (Python only)
- Unlocks: Story 006, 007
