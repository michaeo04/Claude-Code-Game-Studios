# Story 008: PlatformServices node, notification mapping, thread rule and boot

> **Epic**: Platform Services
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/platform-services.md`
**Requirement**: `TR-platform-services-001`, `TR-platform-services-005`, `TR-platform-services-006`, `TR-platform-services-013`, `TR-platform-services-020`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (Decisions 1, 3, 4, 7); ADR-0009: Test framework and CI
**ADR Decision Summary**: One thin `PlatformServices` node forwards notifications to the core through `_marshal` (synchronous on the main thread, `call_deferred` on any other thread), sets `quit_on_go_back = false` and `screen_set_keep_on(true)` at boot, exposes `quit()` and is the only owner of OS calls.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `NOTIFICATION_WM_GO_BACK_REQUEST`, `OS.get_thread_caller_id()` / `OS.get_main_thread_id()`, `DisplayServer.screen_set_keep_on` behaviour and the callback thread on Android are NEEDS VERIFICATION on device (Stories 013 and 014). `node.notification(X)` drives the node in a headless test against a spy core.
**Control Manifest Rules (this layer)**:
- Required: `PlatformServices` created first in the ADR-0002 construction order (no autoload); each lifecycle handler checks `OS.get_thread_caller_id() == OS.get_main_thread_id()`, synchronous on main, `call_deferred` otherwise; `get_tree().quit_on_go_back = false` at boot; `screen_set_keep_on(true)` once; injected `keep_on` and `read_setting` Callables in tests.
- Forbidden: never turn `screen_set_keep_on` off; no `ui_cancel`/`KEY_BACK` mapping; no autoload; never `call_deferred` on the main thread.
- Guardrail: handlers never send requests from inside a Run State tick or handler.

## Acceptance Criteria
- [ ] **AC-19 [N]** `node.notification(X)` against a spy core: `APPLICATION_FOCUS_OUT`, `APPLICATION_FOCUS_IN`, `APPLICATION_PAUSED`, `APPLICATION_RESUMED` and `WM_GO_BACK_REQUEST` call exactly `on_focus_out`, `on_focus_in`, `on_paused`, `on_resumed` and `on_back_requested` once each and nothing else (a swapped mapping fails). **[M]** `fis_for_platform("Android")` is true; `"Windows"`, `"macOS"`, `"Linux"`, `"Web"` and `""` are false.
- [ ] **AC-20 [N]** `_ready` (boot) calls the injected `keep_on(true)` exactly once and never `keep_on(false)`; the boot check passes the injected `read_setting` to `PlatformSettings.mismatches` once.
- [ ] **ADR-0006 Validation (PS-12 test half)** The thread rule passes both cases in a test: a handler on the main thread calls the core synchronously; a handler reported off-thread is marshalled with `call_deferred` (thread id injected or a worker thread in the test).

## Implementation Notes
Node exposes the five signals (re-emitted from the core), `haptic(kind)`, `set_haptics_enabled`, `set_haptics_intensity`, `quit()`; `_notification` maps per ADR-0006 Key Interfaces through `_marshal(fn: Callable)`. Keep `PAUSED/RESUMED` handlers as no-ops that log at debug level on Android (they still call `on_paused/on_resumed`, which the core ignores under FIS). The node builds the core with `fis_for_platform(OS.get_name())`, the real `clock` (`Time.get_ticks_usec`), `Input.vibrate_handheld` as `vibrate`, a `display_source` over `DisplayServer` (safe area, `screen_get_size`, viewport size, `screen_get_refresh_rate`, `screen_get_dpi`), and re-reads facts when the window size changes. Boot: set `quit_on_go_back`, call `keep_on(true)` once, run the manifest check (log only; repair `quit_on_go_back` alone). `quit()` calls `get_tree().quit()` only when Menus asks. This is the only file allowed the OS calls (Story 009 allowlist).

## Out of Scope
- Story 009: lint that enforces the allowlist
- Story 012: production adapter wiring to Run State, Save and Tilt Input (composition-root epic)
- Stories 013 and 014: real-device lifecycle and Back results

## QA Test Cases
- **AC-19**: mapping
  - Given: a node built with a spy core
  - When: `notification(X)` is called for each of the five constants
  - Then: exactly the matching `on_*` once, no other method
  - Edge cases: swapped mapping fails; `fis_for_platform` for the five non-Android names is false
- **AC-20**: boot
  - Given: injected `keep_on` and `read_setting` spies
  - When: the node enters the tree
  - Then: `keep_on(true)` once, never `false`; `mismatches` receives the injected reader once; `quit_on_go_back` set false
  - Edge cases: wrong setting value logs `SETTINGS_MISMATCH` and is not repaired (except `quit_on_go_back`)
- **Thread rule**: main thread vs other thread
  - Given: caller id equals main id, then differs
  - When: a lifecycle notification arrives
  - Then: synchronous core call, then a deferred core call
  - Edge cases: a deferred call never runs inside a Run State tick

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/platform_services/platform_services_node_test.gd` (must pass; SceneTree `[N]` test under `--headless`)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 001, 004, 005, 006, 007
- Unlocks: Stories 009, 011, 012, 013 (composition-root builds this node first)
