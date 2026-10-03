# Story 014: Device spike PS-4 (Back on Android 13+ and Android 16 / SDK 36)

> **Epic**: Platform Services
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3 h (plus device time)
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

> **Blocked note**: `TR-platform-services-006` is Partial (Back on Android 16 / SDK 36 unverified; `docs/architecture/architecture-traceability.md`). The story is blocked until the Story 011 export preset exists and an Android 13+ and an Android 16 device are available.

## Context
**GDD**: `design/gdd/platform-services.md` (Core Rule 5, PS-4, Open Question 9)
**Requirement**: `TR-platform-services-006`, `TR-platform-services-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (Decision 4; Validation Criteria PS-4)
**ADR Decision Summary**: Back is handled only through `NOTIFICATION_WM_GO_BACK_REQUEST` with `quit_on_go_back = false`. If Back is not delivered, it must send the app to the background (pause, no run lost) and the missing `back_pressed` is a release blocker; no Android plugin is written to work around it.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: NEEDS VERIFICATION: `WM_GO_BACK_REQUEST` delivery with predictive back on Android 13+ and with target SDK 36 on Android 16; `quit_on_go_back` semantics; `android:enableOnBackInvokedCallback` opt-in versus opt-out; that the same press never arrives twice.
**Control Manifest Rules (this layer)**:
- Required: run PS-4 with target SDK 36 and predictive back both on and off; inspect the generated manifest; PS-4 is BLOCKING for the first playable.
- Forbidden: no `ui_cancel` or `KEY_BACK` mapping; no Android plugin or GDExtension to work around Back in the MVP (escalation path only after PS-4 proves Godot cannot deliver Back).
- Guardrail: exactly one `back_pressed` per press.

## Acceptance Criteria
- [ ] **PS-4** Back on 3-button and gesture navigation, predictive back on, Android 16 with target SDK 36 and the generated manifest inspected: 10 presses give 10 BACK, 10 cancelled gestures give 0, the Menu is not closed.
- [ ] Predictive back both on and off is recorded with the `android:enableOnBackInvokedCallback` value; the Story 010 manifest lint covers that value.
- [ ] If BACK is never delivered: Back backgrounds the app (pause, no run lost), the missing `back_pressed` is recorded as a release blocker and escalated to the technical-director (Alternative 1, Kotlin plugin, is the only escalation path).

## Implementation Notes
Reuse the Story 013 logger with a `back_pressed` counter and a Menu stub. Record device, OS, navigation mode, target SDK, predictive-back setting, and the merged manifest line. The result closes the Partial status of TR-006 in the traceability document (updated by the user or `/architecture-review`, not by this story). Evidence file: `production/qa/evidence/platform-services/ps-4.md`.

## Out of Scope
- Story 013: lifecycle sequences
- Menus & Screen Flow's meaning of Back in each phase (Menus epic)

## QA Test Cases
- **PS-4**: Setup / Verify / Pass condition
  - Setup: Story 011 build with target SDK 36 on an Android 16 phone and an Android 13+ phone; predictive back on and then off
  - Verify: press Back 10 times and cancel the gesture 10 times in each navigation mode; read the logged count and the merged manifest
  - Pass condition: 10 BACK for 10 presses, 0 for cancels, no duplicate, Menu not closed; otherwise the fallback behaviour and the release-blocker flag are recorded

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/platform-services/ps-4.md` (device evidence, BLOCKING for the first-playable gate)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 008, 011, 013 (logger)
- Unlocks: first playable; closes TR-platform-services-006 Partial
