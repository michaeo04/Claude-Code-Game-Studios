# Story 008: Registry coverage meta-rule

> **Epic**: Test Harness & CI
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0009
**Requirement**: `TR-test-???`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Decision 5 "Registry coverage meta-rule"; Validation Criteria)
**ADR Decision Summary**: The runner reads `docs/registry/architecture.yaml` and reports every `forbidden_patterns` entry that has no rule `forbidden:<pattern>` and is not marked `review_only` in the rule table (ADVISORY), so a banned pattern cannot go unenforced unnoticed.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Python stdlib has no YAML parser; the reader must parse the registry's `forbidden_patterns` section with a small purpose-built parser (no third-party package), tested against the real file's shape.
**Control Manifest Rules (this layer)**:
- Required: ADVISORY severity; `review_only` mark in the rule table for patterns that only review can check.
- Forbidden: third-party Python packages in CI (stdlib only).
- Guardrail: parser tolerates LF and CRLF.

## Acceptance Criteria
- [ ] The runner lists each `forbidden_patterns` entry lacking both a `forbidden:<pattern>` rule and a `review_only` mark; the run still exits 0 (ADVISORY).
- [ ] Adding a rule or a `review_only` mark for an entry removes it from the report.
- [ ] Validation Criterion: against the real `docs/registry/architecture.yaml` the report is either empty or every listed entry is triaged (rule added or `review_only` set) in this story.
- [ ] A missing or malformed registry file yields a warning, not a crash.
- [ ] `--list` or a `--coverage` option prints the coverage table for review.

## Implementation Notes
Parse only the keys needed (`forbidden_patterns` list names). Do not edit the registry from this story.

## Out of Scope
- Story 006: the rules themselves
- Editing `docs/registry/architecture.yaml` (owned by `/architecture-decision`)

## QA Test Cases
- **AC-1/2**: temp registry with three patterns and two rules; Then the third reported, then fixed
- **AC-3**: run on the real registry; record the result
- **AC-4**: absent / garbage file
- **AC-5**: option output contains each pattern once

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tools/ci/tests/test_lint_registry_coverage.py`; Logic gate BLOCKING
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 006
- Unlocks: Story 010
