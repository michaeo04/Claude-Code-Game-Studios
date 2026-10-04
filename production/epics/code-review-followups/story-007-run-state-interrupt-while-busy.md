# Story 007: RunStateCore must not drop an app interrupt while busy

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

- [ ] An `app_interrupted` request that arrives while a handler is running is queued and applied after the current emission completes (or rejected deterministically per the Run State GDD), never silently lost.
- [ ] Test: a handler of `run_started` that triggers an interrupt results in the Paused phase on the same tick's end.

---

## Implementation Notes

Finding 10. Check `design/gdd/run-state-restart.md` re-entrancy rule first: the GDD says a request sent from inside a handler is rejected; if so the fix is to make the rejection visible (error log plus a counter) instead of silent.

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
