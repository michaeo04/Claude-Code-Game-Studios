# Story 004: PlatformCore lifecycle model and edge signals

> **Epic**: Platform Services
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/platform-services.md`
**Requirement**: `TR-platform-services-003`, `TR-platform-services-004`, `TR-platform-services-011`, `TR-platform-services-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (Decision 2); ADR-0009: Test framework and CI
**ADR Decision Summary**: `focus_implies_suspend` is true on Android; `FOCUS_OUT` emits `app_interrupted` then `app_backgrounded`, `FOCUS_IN` emits `app_foregrounded` then `app_returned`; `PAUSED/RESUMED` are ignored on Android. `app_backgrounded` is the only flush signal.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Core is engine-free, so the logic is deterministic in tests. Real notification order and presence under Vulkan is NEEDS VERIFICATION on device (Story 013, PS-1/PS-2); the core must not depend on it.
**Control Manifest Rules (this layer)**:
- Required: `FOCUS_OUT` is the primary pause signal; keep `PAUSED/RESUMED` handlers no-ops that log at debug level on Android; `PlatformCore` is built with injected `focus_implies_suspend`, `clock`, `log_sink`, `vibrate`, `display_source`, validated `HapticsConfig`.
- Forbidden: never use `PAUSED/RESUMED` as the primary lifecycle signal or read them on Android; never `call_deferred` lifecycle handlers on the main thread.
- Guardrail: signals emitted synchronously inside the handler; nothing emitted at construction; signals are not replayed.

## Acceptance Criteria
- [x] **AC-1 [C]** Signals per event for `fis` false and for Android (`fis` true) rows as in the GDD: `fis` false: `FO,P,FI,R` gives INT | BG | - | FG,RET; `FO,P,R,FI` gives INT | BG | FG | RET; `FO,FI` gives INT | RET; `FO,FO,P,FI,R` gives INT | - | BG | - | FG,RET; `P,P` gives INT,BG | -. Android: A1 `FO,FI` gives INT,BG | FG,RET; A2 `FO,P,FI,R` gives INT,BG | - | FG,RET | -; A3 `P,FO,R,FI` gives - | INT,BG | - | FG,RET; A4 `FO,P,FI` gives INT,BG | - | FG,RET; A5 `FO,FI,P,R` gives INT,BG | FG,RET | - | -. Both: `R` or `FI` on a fresh core emits nothing and logs one `LIFECYCLE_NOOP` (key = event name); so do `FO,FO`, `P,P` and every Android `P`/`R`; construction emits nothing (`attentive` true, `suspended` false); each signal is recorded before the `on_*` call returns.
- [x] **AC-2 [C]** Exhaustive, both `fis`: all 5460 sequences of 1-6 events in fixed enumeration order that prints `fis` and the sequence on failure: at most 2 signals per event, never a losing and regaining signal together, order INT, BG, FG, RET; running INT-RET and BG-FG counts stay in {0,1} and equal 1 iff not `attentive` (respectively iff `suspended`); with `fis` true INT/BG (and FG/RET) always share an event and P/R never change a getter; liveness: FI then R gives `attentive` true and `suspended` false from every reachable flag state; plus an independent literal transition table (state x event x `fis`).

## Implementation Notes
Flags `focused` (true at start) and `paused` (false); `attentive = focused and not paused`; `suspended = paused or (FIS and not focused)`. Under FIS, `on_paused/on_resumed` never change `paused` and log `LIFECYCLE_NOOP`. After each event evaluate `(a0,s0)` vs `(a1,s1)` and emit `app_interrupted` iff `a0 and not a1`, `app_backgrounded` iff `not s0 and s1`, `app_foregrounded` iff `s0 and not s1`, `app_returned` iff `not a0 and a1`, in that order. A repeated event changes nothing, logs one debug `LIFECYCLE_NOOP` (event name as key). Getters `attentive` and `suspended` let late consumers read state on connect (signals are not replayed). PlatformCore does no saving and never waits for receivers. Display facts reading before the regaining signals is Story 006.

## Out of Scope
- Story 006: `display_source` read on regaining edges and Back
- Story 008: thread marshalling and notification-to-method mapping
- Story 013: real-device sequences

## QA Test Cases
- **AC-1**: named rows
  - Given: a fresh core per case with a recording sink; `fis` false and true
  - When: each event sequence is delivered one event at a time
  - Then: the recorded signals per event equal the GDD row exactly; `LIFECYCLE_NOOP` count and key match
  - Edge cases: `R`/`FI` on fresh core emit nothing; late `P,R` after `FI` (A5) gives no second interruption
- **AC-2**: exhaustive invariants
  - Given: both `fis` values, all 5460 sequences of length 1-6, plus the literal transition table
  - When: each sequence runs on a fresh core
  - Then: all invariants hold and the failure message prints `fis` and the sequence
  - Edge cases: liveness (FI then R) from every reachable flag state

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/platform_services/platform_services_core_lifecycle_test.gd` (must pass)
**Status**: [x] Created and passing
**Evidence**: `tests/unit/platform_services/platform_services_core_lifecycle_test.gd`: test_fis_false_rows_match_gdd, test_android_rows_match_gdd, test_exhaustive_sequences_hold_invariants, test_transition_table_matches_literal_expectations

## Dependencies
- Depends on: Story 002
- Unlocks: Story 005, Story 006, Story 008, Story 012
