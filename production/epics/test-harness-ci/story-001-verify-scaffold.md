# Story 001: Verify project scaffold (project.godot, .gitattributes, .gdignore)

> **Epic**: Test Harness & CI
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-03 (completed; evidence in production/qa/)

## Context
**GDD**: none, defined by ADR-0009
**Requirement**: `TR-test-???` (no TR-ID registered for this module)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Migration Plan steps 1 and 6; Decision 4 hardening; Decision 5 fixtures note)
**ADR Decision Summary**: `project.godot` must exist before spike T-1. `.gitattributes` forces `eol=lf` and `build/` and `tools/` carry a `.gdignore`, added with the first scaffold commit.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: This is a VERIFICATION story. `project.godot` already exists (hand-written, unverified, untracked). It must be opened/imported by the real 4.7.2 binary; a hand-written file may carry wrong keys or format version.
**Control Manifest Rules (this layer)**:
- Required: `.gitattributes` forces `eol=lf` for `*.gd`, `*.tres`, `*.tscn`, `*.json`, `*.py`; `build/` and `tools/` carry a `.gdignore`.
- Forbidden: no `[autoload]` entries for game systems; never let Godot import `build/` or `tools/`; no `[editor_plugins]` entry unless the editor panel is wanted.
- Guardrail: engine version must be exactly `4.7.2`.

## Acceptance Criteria
- [ ] `godot --headless --path . --import` on the existing `project.godot` exits 0 with no `SCRIPT ERROR` / `Parse Error` / unknown-key warnings; any hand-written key that 4.7.2 rewrites or rejects is corrected.
- [ ] `project.godot` values match the registered `project_setting` expectations that already apply (no game autoloads; `physics/common/physics_interpolation` false; `quit_on_go_back` false; handheld orientation 1; touch emulation flags; only `enable_gravity` among sensor flags) or the difference is recorded as owned by a later epic.
- [ ] `.gitattributes` exists with `eol=lf` for the five patterns; `.gdignore` exists in `build/` and `tools/`.
- [ ] A second `--import` on a clean clone is checked and the result recorded (feeds T-1 item 12).
- [ ] `project.godot` is committed together with these files (unit of work), `.godot/` stays ignored.

## Implementation Notes
Open the project once with the 4.7.2 binary and diff what Godot rewrites against the hand-written file; commit the Godot-normalised version. Keep `tools/` and `build/` out of import via `.gdignore` so deliberately invalid fixtures never break `--import`. Do not add game autoloads or an `[editor_plugins]` entry.

## Out of Scope
- Story 002: GUT spike on 4.7.2
- Story 003: vendoring GUT and `.gutconfig.json`
- Export presets (ADR-0006 epic)

## QA Test Cases
- **AC-1**: import is clean
  - Given: fresh clone, 4.7.2 binary at `GODOT`
  - When: `godot --headless --path . --import`
  - Then: exit 0, output free of `SCRIPT ERROR`, `Parse Error`, `ERROR`
  - Edge cases: run twice; record whether the second pass changes the class cache
- **AC-2**: settings match lint expectations
  - Given: committed `project.godot`
  - When: read the keys listed in the AC
  - Then: each equals the required value or has a recorded owner
  - Edge cases: missing key means default; confirm the default is acceptable
- **AC-3**: `git check-attr eol *.gd *.json *.py` reports `lf`; `.gdignore` present
  - Given/When/Then as stated; Edge cases: CRLF checkout on Windows normalises
- **AC-4/5**: recorded in the smoke note

## Test Evidence
**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-[date].md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: None
- Unlocks: Story 002 (T-1 needs a project), Story 003
