# Story 005: PlatformCore haptic call flow, drop causes and counters

> **Epic**: Platform Services
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/platform-services.md`
**Requirement**: `TR-platform-services-007`, `TR-platform-services-008`, `TR-platform-services-009`, `TR-platform-services-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (Decision 5); ADR-0009: Test framework and CI
**ADR Decision Summary**: `haptic(kind)` goes through the Platform Services gate (enabled, attentive, not zero, throttled, priority) and calls `Input.vibrate_handheld(duration_ms, amplitude)` through the injected `vibrate` Callable; devices without amplitude control play a fixed pulse.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `vibrate_handheld` amplitude behaviour and the VIBRATE permission are NEEDS VERIFICATION on device (Story 015, PS-6); the core only calls the injected Callable.
**Control Manifest Rules (this layer)**:
- Required: `haptic(kind)` calls the injected `vibrate(duration_ms, amplitude)` only; `HIT` outranks `NEAR_MISS` and `UI_TAP`; drop causes counted per cause (`haptic_drops(cause)`).
- Forbidden: no `Input.vibrate_handheld` in the core (lint AC-12b); only the node file may call it.
- Guardrail: haptic pulse never queued while not attentive; no log for disabled/not-attentive/zero-duration drops.

## Acceptance Criteria
- [ ] **AC-4 [C]** HIT at stamp 0 plays (`vibrate` receives 80, 1.0); NEAR_MISS at 30000 drops (`THROTTLED`, `last_played_us` unchanged), at 79999 drops (past interval, inside the HIT pulse) and at 80000 plays. Fresh core: NEAR_MISS at 0 plays, HIT at 20000 plays (priority 2 over 1; `vibrate` receives 80, 1.0), HIT at 40000 drops (equal priority, inside interval), NEAR_MISS at 60000 drops (HIT of 20000 ends at 100000). NEAR_MISS at 0, NEAR_MISS at 40000 drops and at 50000 plays; UI_TAP within a NEAR_MISS's interval drops. After each other drop cause (disabled, not attentive, duration 0 through `UI_TAP` set to 0, unknown kind) an allowed call at the same stamp on the same fresh core plays; drop order `UNKNOWN_KIND`, `DISABLED`, `NOT_ATTENTIVE`, `ZERO_DURATION`, `THROTTLED`, each incrementing exactly its `haptic_drops` counter; disabled, not-attentive and zero-duration drops log nothing; an unknown kind logs one `UNKNOWN_HAPTIC_KIND` error and does not call `vibrate`. Each drop cause has its own test.

## Implementation Notes
Evaluate in the GDD order; the first matching cause drops the call and increments that cause's counter. Use `PlatformMath.haptic_gate` and `effective` (Story 001) and the validated `HapticsConfig` (Story 003). When played: set `last_played_us = now`, `last_end_us = now + dur_eff * 1000`, `last_prio = prio`, then `vibrate.call(dur_eff, amp_eff)` where `amp_eff` applies `haptics_intensity` after the -1 sentinel check. A dropped call changes none of the three stamps. A clock anomaly (`now < last_played_us`) plays and re-bases the stamps. `set_haptics_enabled(bool)` is a core setter; disabling mid-pulse makes no extra `vibrate` call. Use method Callables, not self-capturing lambdas.

## Out of Scope
- Story 008: the node's `haptic()` forwarding and real `Input.vibrate_handheld`
- Story 015: device observation of amplitude levels (127, 1, 255) and VIBRATE permission

## QA Test Cases
- **AC-4**: gate behaviour and drop causes
  - Given: the fixture config (0.05 s, NEAR_MISS 30/0.5/1, HIT 80/1.0/2, UI_TAP 15/0.3/0), a stub clock, a recording `vibrate` and sink
  - When: the listed haptic calls are made at the listed microsecond stamps on fresh cores
  - Then: plays/drops and `vibrate` arguments match; the matching `haptic_drops` counter is exactly incremented; only unknown kind logs
  - Edge cases: priority preemption of a running pulse; equal priority inside interval drops; one drop cause removed per case then the allowed call plays at the same stamp

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/platform_services/platform_services_core_haptics_test.gd` (must pass)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 001, 003, 004
- Unlocks: Story 008, Story 015
