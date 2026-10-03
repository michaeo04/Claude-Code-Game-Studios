# Story 006: PlatformCore Back signal and display facts

> **Epic**: Platform Services
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/platform-services.md`
**Requirement**: `TR-platform-services-006`, `TR-platform-services-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (Decisions 4 and 6)
**ADR Decision Summary**: `NOTIFICATION_WM_GO_BACK_REQUEST` emits `back_pressed` and decides nothing; display facts are read at construction and on each regaining edge before the signals, with an empty safe area replaced by the full screen rectangle in pixels.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The core is engine-free (display read through an injected `display_source`). Delivery of Back on Android 13+ predictive back / Android 16 SDK 36 and asynchronous safe-area insets are NEEDS VERIFICATION on device (Stories 014 and 016); TR-006 is Partial until PS-4 closes. This story's logic does not depend on that result.
**Control Manifest Rules (this layer)**:
- Required: handle Back only through `NOTIFICATION_WM_GO_BACK_REQUEST` (core method `on_back_requested`); read display facts at construction and on each regaining edge (`app_foregrounded`, `app_returned`); empty safe area becomes `Rect2i(Vector2i.ZERO, screen size)`.
- Forbidden: no `ui_cancel` or `KEY_BACK` mapping; core never calls `quit`; no Android plugin to work around Back.
- Guardrail: system gesture insets are not exposed; UI keeps the 40 dp and 16 dp starting margins.

## Acceptance Criteria
- [ ] **AC-9 [C]** (R5) Each `on_back_requested()` emits exactly one BACK in all four lifecycle states, changes no getter, never calls `quit`, and replaying the same event sequence with and without a BACK gives the same lifecycle signals; two calls give two BACK, and a second listener receives each.
- [ ] **AC-10 [C]** (R7) `display_source` is read once at construction with no signal. An event with no regaining edge reads nothing; one with a regaining edge reads once, before its first signal (recorded order `read, FG, RET`; with `fis` false, `FI` after `FO` gives `read, RET`), and a handler sees the new values (refresh 120 then 60: the RET handler sees 60). An empty safe area (`Rect2i()`) with screen 1080x1920 is exposed as `Rect2i(0, 0, 1080, 1920)`; `Rect2i(0, 132, 1080, 1788)` unchanged; viewport size 540x960 exposed unconverted; refresh rate 0 or -1 exposed raw and F4 gives `max_fps`.

## Implementation Notes
`display_source` returns a Dictionary with keys `safe_area`, `screen_size`, `viewport_size`, `refresh_rate` (a typed `DisplayFacts` object and `screen_dpi` are deferred polish, GDD OQ 21; ADR-0006 Decision 6 adds `screen_dpi: int` for ADR-0011, carry it as an extra key without changing the four existing ones). Read-only getters `safe_area`, `screen_size`, `viewport_size`, `refresh_rate`. Reading on the size-changed trigger is wired by the node (Story 008). Fixture screen 1080x1920 and viewport 540x960 are different so a swap fails. `back_pressed` is emitted synchronously, one per call, regardless of lifecycle state; consumers are idempotent.

## Out of Scope
- Story 008: node forwarding of `WM_GO_BACK_REQUEST`, `quit_on_go_back` boot set and `quit()`
- Story 014: PS-4 device verification (release blocker if Back is never delivered)
- Story 016: PS-8 safe-area device record

## QA Test Cases
- **AC-9**: Back signal
  - Given: a fresh core in each of the four lifecycle states
  - When: `on_back_requested()` is called once, then twice, with two listeners
  - Then: exactly one BACK per call, each listener receives each, getters unchanged, `quit` spy uncalled
  - Edge cases: same event sequence with and without BACK yields identical lifecycle signals
- **AC-10**: display facts
  - Given: a `display_source` stub returning controllable values and a recording order log
  - When: construction, a no-edge event, a regaining event and the listed fixtures are exercised
  - Then: read counts and order match (`read, FG, RET`); handler sees the new value; empty safe area becomes the full screen rect; non-empty unchanged; viewport unconverted
  - Edge cases: `fis` false `FO` then `FI` gives `read, RET`; refresh 0 and -1 exposed raw

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/platform_services/platform_services_core_back_display_test.gd` (must pass)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 004
- Unlocks: Story 008, Story 012
