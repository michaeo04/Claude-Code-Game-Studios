# Epic: Code Review Follow-ups

> **Layer**: Foundation
> **GDD**: none (defects and contract mismatches found by the code review of 2026-10-04, `production/qa/code-review-2026-10-04.md`)
> **Architecture Module**: cross-cutting (`src/core/`)
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 7 stories (see table)

## Overview

Defects and contract mismatches between modules that were written separately and that the module-level unit tests cannot see. CRF-001 and CRF-002 are HIGH and come first in Sprint 4: they decide whether the real cores can be wired together at all.

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0002: Game loop, Composition Root and tick order | One tick driver, fixed per-frame order, injected clock and sinks | Accepted | LOW |
| ADR-0009: Test framework and CI | Fixtures framework-free in `tests/support/`; lint rules registered by the owning story | Accepted | MEDIUM |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | One log-sink contract and one level enum for every core | Logic | Ready | ADR-0002 |
| 002 | GameRoot `_tick` against the real core APIs (strict test doubles) | Integration | Ready | ADR-0002 |
| 003 | Live tilt sensitivity update from Settings to TiltCore | Integration | Ready | ADR-0002 |
| 004 | Validate `haptics_intensity` in SettingsCore | Logic | Ready | ADR-0007 |
| 005 | SaveCore backup ordering and wall-clock robustness | Logic | Ready | ADR-0007 |
| 006 | Remove duplicated and hard-coded tuning values | Config/Data | Ready | ADR-0002 |
| 007 | RunStateCore must not drop an app interrupt while busy | Logic | Ready | ADR-0002 |

## Definition of Done

- All stories Complete with a passing test or recorded evidence each; `python tools/ci/run_ci.py --only all` green.
- Findings 1 to 10 of `production/qa/code-review-2026-10-04.md` have a disposition that is closed or recorded in `production/owner-actions.md`.
