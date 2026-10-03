# Epic: Test Harness & CI

> **Layer**: Foundation
> **GDD**: none (defined by ADRs and `docs/architecture/architecture.md`)
> **Architecture Module**: Test infrastructure (tools/ci, tests/)
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 11 stories (see table)

## Overview

The GUT test harness and the CI entry command of ADR-0009: vendored and pinned GUT, `.gutconfig.json`, `tests/support/` (framework-free fixtures), `tools/ci/run_ci.py`, the lint runner and rule table, and the manual-then-automatic `ci.yml`. Spikes T-1 (GUT on 4.7.2) and T-2 (first green CI run) are its validation gates and block the first Logic story of every other epic.

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |

**Engine risk of the epic: MEDIUM** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

This module has no GDD, so no `TR-` ids are registered for it. Its requirements are the Decision and Validation Criteria sections of the governing ADRs above; `/create-stories` takes its acceptance criteria from them.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All Validation Criteria of the governing ADRs that concern this module are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Verify project scaffold (project.godot, .gitattributes, .gdignore) | Config/Data | Complete | ADR-0009 |
| 002 | Spike T-1: GUT on Godot 4.7.2 | Integration | Complete | ADR-0009 |
| 003 | Vendor GUT, .gutconfig.json, tests/support skeleton | Config/Data | Complete | ADR-0009 |
| 004 | Verify and harden run_ci.py | Integration | Complete | ADR-0009 |
| 005 | Harden the GDScript comment and string stripper | Logic | Complete | ADR-0009 |
| 006 | Harden lint rule kinds and registered rule table | Logic | Complete | ADR-0009 |
| 007 | Per-rule pass/fail fixtures and self-check | Logic | Complete | ADR-0009 |
| 008 | Registry coverage meta-rule | Logic | Complete | ADR-0009 |
| 009 | GitHub Actions workflow ci.yml and triggers | Config/Data | Ready | ADR-0009 |
| 010 | Spike T-2: first green CI run and negative controls | Integration | Ready | ADR-0009 |
| 011 | Document and skill synchronization (Decision 8) | Config/Data | Ready | ADR-0009 |

## Next Step

Run `/story-readiness production/epics/test-harness-ci/story-001-verify-scaffold.md`, then `/dev-story`.
