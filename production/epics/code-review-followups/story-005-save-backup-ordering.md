# Story 005: SaveCore backup ordering and wall-clock robustness

> **Epic**: Code Review Follow-ups
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context

**GDD**: none (code review finding, `production/qa/code-review-2026-10-04.md`)
**Requirement**: `TR-code-review-???`
**ADR Governing Implementation**: ADR-0002 (injected sinks, single tick driver); ADR-0009 (test rules)
**ADR Decision Summary**: cores are pure RefCounted classes that receive time, sinks and seams by injection; the composition root is the only place that wires them.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: none (GDScript only)
**Control Manifest Rules (this layer)**:
- Required: static typing; pure cores with no engine calls; values from config.
- Forbidden: autoloads; `CONNECT_DEFERRED`; editing `tools/ci/lint_rules.json` to turn a lint green (a story that needs a new rule adds it with fixtures).
- Guardrail: `python tools/ci/run_ci.py --only all` stays green and finishes in about 15 s.

---

## Acceptance Criteria

- [ ] Backup names are ordered by their numeric (timestamp, counter) pair, not as strings: 11 backups within one second rotate the oldest first.
- [ ] A wall clock of 0 or one that moves backwards does not make the newest backup look oldest (the order falls back to a monotonic counter in the name).
- [ ] The bounded name probe from 2026-10-04 stays; a test covers the exhausted-names case.

---

## Implementation Notes

Finding 9.

---

## Out of Scope

- Anything not named in the acceptance criteria; other findings have their own stories.

---

## QA Test Cases

One test per acceptance criterion above (Given the pre-fix behaviour described in the finding, When the scenario runs, Then the corrected behaviour). Each test fails on the pre-fix code and passes after.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/` test file named in the story, must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: the real wiring stories of the composition-root epic
