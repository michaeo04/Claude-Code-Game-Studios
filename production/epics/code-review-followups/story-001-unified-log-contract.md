# Story 001: One log-sink contract and one level enum for every core

> **Epic**: Code Review Follow-ups
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
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

- [ ] One `LogLevel` enum (DEBUG, INFO, WARNING, ERROR) and one sink signature `(level: int, code: StringName, key: String, message: String)` are defined once (for example `src/core/log/`), documented, and used by every core and config in `src/core/`.
- [ ] `RunStateCore`, `RunConfig`, `WorldFrameConfig` (two-argument sinks), `BallCore`, `BallConfig`, `TiltCore`, `TiltConfig` (three-argument) and the four-argument modules all call the same signature; no module defines its own level numbers.
- [ ] `RateLimitedLog.Level` is replaced by or aliased to the shared enum; `SaveConfig.LEVEL_ERROR`, `SettingsCore.LEVEL_WARNING` and `RunStateMath` WARNING constants are removed.
- [ ] A single recording sink in `tests/support/` serves every module's tests; no existing assertion on a log code or level is weakened.
- [ ] A lint rule `forbidden:private_log_level_constants` flags a new `LEVEL_` constant in `src/core/` (with pass and fail fixtures).
- [ ] `PlatformCore` routes repeating diagnostics through `RateLimitedLog` (finding 5): an unknown haptic kind logged on 1000 consecutive ticks produces at most one line per window.

---

## Implementation Notes

Findings 1 and 5. Mechanical but wide: change the sink signature behind one adapter at a time, keep CI green after each module.

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
