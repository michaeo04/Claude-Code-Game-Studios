# Story 006: Failure reporting, map_load_failed and Retry

> **Epic**: Map Loader & MapConfig
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0004
**Requirement**: `TR-map-loader-???` (related: `TR-menus-screen-flow-009`, `TR-run-state-restart-020`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig
**ADR Decision Summary**: On failure the core sets `FAILED`, stores `last_codes`, logs each code and emits `map_load_failed(codes)` once per attempt; `retry()` is valid only in `FAILED` and re-runs the whole sequence including a fresh re-read.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: A cache-mode re-read on Retry has low value because a failure is deterministic (verification item 2, low priority; handled in Story 008).
**Control Manifest Rules (this layer)**:
- Required: signal `map_load_failed(codes: PackedStringArray)` on `MapLoaderCore`, once per attempt; codes logged through the reused `RateLimitedLog`
- Required: `retry()` in `FAILED` re-runs everything; in `READY` ignored with one log line; in `NOT_LOADED` behaves as the first attempt; one `_attempting` flag makes `attempt()` and `retry()` non-reentrant
- Forbidden: attempt cap or debounce on Retry; freeing/recreating Tube Track slots on Retry; relying on deferred connections
- Guardrail: Run State stays in Boot and emits nothing on failure

## Acceptance Criteria
- [ ] Any Phase A or Phase B failure sets `status = FAILED`, stores `last_codes`, and emits `map_load_failed` exactly once with the right code set (ADR-0004 Validation)
- [ ] Each code is passed to `log_sink(level, code, key, message)` and a repeated failure goes through the rate limiter; the player-facing signal carries codes only, no prose
- [ ] A successful attempt emits no `map_load_failed` and leaves `last_codes` empty
- [ ] `retry()` in `FAILED` re-runs the whole sequence including calling `load_definition` again (the fake counts reads) and can end in `READY` with `map_ready` sent once
- [ ] `retry()` in `READY` is a no-op that logs one line, calls no seam, emits nothing
- [ ] `retry()` in `NOT_LOADED` behaves as the first `attempt`
- [ ] A re-entrant call from inside a seam (`attempt` or `retry` while `_attempting`) is rejected without running (spy)
- [ ] Repeated Retry on bad data repeats the same failure and emits the signal once per attempt (no cap, no debounce)

## Implementation Notes
Keep the last path in the core so `retry()` takes no argument. Emission happens after state is written (`status`, `last_codes` set before `emit_signal`), so a subscriber reading them sees the final values. Do not catch the signal in the core. The `RateLimitedLog` is the existing foundation class; take it through `log_sink`, do not construct it here. The `READY` no-op log line uses a stable code (`RETRY_IGNORED_READY`, an INFO).

## Out of Scope
- Story 004/005: Phase A and B
- Story 009: Menus subscription and the `request_map_retry` Callable
- The `MAP_LOAD_TIMEOUT` backup (Menus epic)

## QA Test Cases
- **AC-1**: single emission
  - Given: a signal watcher, a failing Phase A
  - When: `attempt` runs
  - Then: emitted once with the code set; `status == FAILED`; `last_codes` equal
- **AC-2**: logging
  - Given: a recording log sink
  - When: two identical failures run
  - Then: one entry per code per attempt reaches the sink (rate limiting is the sink's job; assert the call)
- **AC-3**: success clean
  - Given: all-true seams
  - When: `attempt` runs
  - Then: no emission; `last_codes` empty
- **AC-4**: retry recovers
  - Given: first read returns null, second returns a valid definition
  - When: `attempt` then `retry`
  - Then: two reads; `READY`; `map_ready` once
- **AC-5/6**: retry states
  - Given: a `READY` core; a fresh core
  - When: `retry()` each
  - Then: `READY` no-op with one log line and no seam call; fresh core acts as `attempt`
- **AC-7**: reentrancy
  - Given: a seam that calls `retry()`
  - When: `attempt` runs
  - Then: inner call returns false, no second sequence
- **AC-8**: repeated retry
  - Given: permanently bad data
  - When: `retry()` 5 times
  - Then: 5 emissions, same codes

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/map_loader/map_loader_failure_retry_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 004, Story 005
- Unlocks: Story 008, Story 009
