# Story 002: RateLimitedLog and log codes

> **Epic**: Platform Services
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/platform-services.md`
**Requirement**: `TR-platform-services-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (primary, module shape); ADR-0009: Test framework and CI
**ADR Decision Summary**: `PlatformCore` takes an injected `log_sink` and `clock`; `RateLimitedLog` (RefCounted) wraps a sink with the 1.0 s per (code, key) limit. GDD-owned behaviour, no ADR change.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure GDScript. Use method Callables, not lambdas capturing `self` in a RefCounted (reference cycle).
**Control Manifest Rules (this layer)**:
- Required: inject the clock as `clock_us: Callable` (integer microseconds); cores never call `Time.`; exact `==` for codes and counts.
- Forbidden: no `Time.`, `OS.`, `Engine.` in `RateLimitedLog`; no inline lint ignore comments.
- Guardrail: log rate limit is a fixed constant of 1.0 s, not a tuning knob.

## Acceptance Criteria
- [x] **AC-6 [R]** Log codes are exactly `UNKNOWN_HAPTIC_KIND`, `KNOB_CLAMPED`, `SETTINGS_MISMATCH` (error level) and `LIFECYCLE_NOOP` (debug). `RateLimitedLog` passes one message per (code, key) per 1.0 s of the injected clock, the window running from the last message that passed: at 0 passes; same key at 999999 us does not; at 1000000 us does; two different keys (or codes) at one stamp both pass; a clock that goes backwards passes the message and re-bases the window; the level is preserved.

## Implementation Notes
Code constants live in one place (a small constants class or `PlatformCore` constants) so other stories import them. Window `RATE_LIMIT_US = 1_000_000` is a fixed constant. Key per code: kind id for `UNKNOWN_HAPTIC_KIND`, `<kind>.<field>` for `KNOB_CLAMPED`, the setting key for `SETTINGS_MISMATCH`, the event name for `LIFECYCLE_NOOP`. Store `last_passed_us` per (code, key); a message passes when none stored, `now < last` (re-base) or `now - last >= 1_000_000`. AC-1, AC-4 and AC-7 use a recording sink without the limiter, so the limiter stays optional in `PlatformCore` construction.

## Out of Scope
- Story 003, Story 004, Story 005, Story 007: which events emit which codes

## QA Test Cases
- **AC-6**: rate limiting
  - Given: a recording sink and a stub clock
  - When: messages are sent at 0, 999999 and 1000000 us for one key, then two keys at one stamp, then a backwards clock
  - Then: 0 passes, 999999 dropped, 1000000 passes; both different keys pass (unknown kind 99 twice within 1 s gives one log, kind 98 a second); backwards clock passes and re-bases; level preserved
  - Edge cases: same key different code passes; window measured from last passed message, not first

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/platform_services/platform_services_rate_limited_log_test.gd` (must pass)
**Status**: [x] Created and passing (`python tools/ci/run_ci.py --only all`)
**Evidence**: `tests/unit/platform_services/platform_services_rate_limited_log_test.gd` (10 tests: AC-6)

## Dependencies
- Depends on: test-harness-ci story 002 (GUT confirmed on 4.7.2)
- Unlocks: Stories 003, 004, 005, 007, 008
