# Epic: Test Harness & CI

> **Layer**: Foundation
> **GDD**: none (defined by ADRs and `docs/architecture/architecture.md`)
> **Architecture Module**: Test infrastructure (tools/ci, tests/)
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: Not yet created. Run `/create-stories test-harness-ci`

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

## Next Step

Run `/create-stories test-harness-ci` to break this epic into implementable stories.
