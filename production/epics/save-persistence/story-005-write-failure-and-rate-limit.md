# Story 005: Write failure handling and rate-limited logging

> **Epic**: Save & Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-008`, `TR-save-persistence-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: A failed `write_config`, a zero-size temp file or a failed `rename` logs one `WRITE_FAILED`, rate limited per section and key by the reused `RateLimitedLog`, returns false, and keeps the in-memory value updated.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Whether the real `ConfigFile.save` returns non-`OK` on disk full (verification item 2/10) is confirmed in Story 009/012; here the seams are faked. The injected `clock` is real-time seconds, never simulation time.
**Control Manifest Rules (this layer)**:
- Required: reuse Platform Services' `RateLimitedLog` on the injected `clock`, keyed per section+key; `set_value` returns false on failure.
- Forbidden: a second rate-limiter class; throwing or crashing on a failed write; reading `Time.` in the core.
- Guardrail: `SAVE_LOG_RATE_LIMIT` default 1.0 s, test value 0.05 s.

## Acceptance Criteria
- [ ] **AC-8 [C]** `write_config` returning false stops the sequence (`rename` never called), `set_value` returns false, one `WRITE_FAILED` is logged, and the in-memory value is still updated; `rename` returning false likewise reports `WRITE_FAILED` without corrupting in-memory state.
- [ ] **AC-14 [C]** With `write_config`/`rename` returning false on every call, ten consecutive `set_value` calls for the same section+key within 0.05 s of the injected clock produce exactly one `WRITE_FAILED` for that key; all ten update memory (the tenth value is read back) and report failure; an eleventh call for a different key at the same stamp logs its own line.

## Implementation Notes
Wire `RateLimitedLog` (from the platform-services epic) around `log_sink` inside `SaveCore`'s constructor; the key for the limiter is `section + "/" + key`. A `size(TMP) <= 0` after a "successful" write is treated as a write failure (ADR-0007 Decision 4 step 4). If `RateLimitedLog` is not yet implemented, this story waits for it rather than duplicating it.

## Out of Scope
- Story 004: the success path.
- Story 006: read-side logging (per load, per key).
- Story 012: real kill behaviour.

## QA Test Cases
- **AC-8**: Given `write_config` scripted false; When `set_value("scoring","personal_best",700)`; Then false, `rename` not in call log, one `WRITE_FAILED`, `get_value` -> 700; Edge: `rename` scripted false with writer true gives the same outcome; `size(TMP)` 0 also fails.
- **AC-14**: Given failing seams and a fake clock advancing 0.001 s per call; When ten `set_value` on one key then one on another; Then exactly two `WRITE_FAILED` logs total, tenth value readable; Edge: a call after the clock passes 0.05 s logs again.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/save_persistence/save_persistence_write_failure_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 004; cross-epic: platform-services (`RateLimitedLog` story)
- Unlocks: Story 008
