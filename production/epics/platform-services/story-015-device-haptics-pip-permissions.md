# Story 015: Advisory device checks PS-5, PS-6 and PS-11 (PiP, haptics, permissions)

> **Epic**: Platform Services
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3 h (plus device time)
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/platform-services.md` (Device checks PS-5, PS-6, PS-11)
**Requirement**: `TR-platform-services-018`, `TR-platform-services-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (Decisions 5 and 8; Validation Criteria, manifest permissions)
**ADR Decision Summary**: `haptic(kind)` calls `Input.vibrate_handheld` with the `VIBRATE` permission declared; the manifest declares `VIBRATE` only, no prompts; Picture-in-Picture is off.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION: `Input.vibrate_handheld(duration_ms, amplitude)` amplitude behaviour and the VIBRATE permission; Picture-in-Picture exposure in the 4.7.2 build template.
**Control Manifest Rules (this layer)**:
- Required: permissions `VIBRATE` only; device evidence file per item in `production/qa/evidence/platform-services/`.
- Forbidden: no extra permissions or runtime permission prompts in release.
- Guardrail: these checks are ADVISORY (blocking only at their named gate); defaults are guesses until measured.

## Acceptance Criteria
- [ ] **PS-5** Picture-in-Picture: 10 Home presses during a run; hypothesis 0 enter PiP.
- [ ] **PS-6** `VIBRATE` checked versus unchecked, HIT x10 (vibrator dump, or 3 testers): 10/10 versus 0/10; also observe amplitude levels 0.5, 0 and 1 (expected 127, 1, 255) and a NEAR_MISS of 30 ms on Android.
- [ ] **PS-11** 3 fresh installs per device, 60 s of play: zero permission prompts; the Android manifest lists only `VIBRATE`.

## Implementation Notes
Use the Story 011 build and the Story 013 logger scene plus a haptic test button calling the node's `haptic(kind)`. Record raw observations (vibrator dump or tester notes), the matrix device, OS and date per item. A deviation from the hypothesis is a finding that goes back to the GDD (a Tuning Knobs value or the HIT/NEAR_MISS priority), not a test failure.

## Out of Scope
- Story 014: Back; Story 013: lifecycle
- Perception check for "felt with the visual cue" (device spike per GDD OQ 16, Juice & Feedback)

## QA Test Cases
- **PS-5**: Setup / Verify / Pass condition
  - Setup: install the build; start a run
  - Verify: press Home 10 times
  - Pass condition: PiP is entered 0 times
- **PS-6**: Setup / Verify / Pass condition
  - Setup: one build with VIBRATE and one without; trigger HIT x10, amplitude 0.5, 0, 1 and a 30 ms NEAR_MISS
  - Verify: vibrator dump or 3 testers
  - Pass condition: 10/10 with, 0/10 without; levels near 127, 1, 255; NEAR_MISS perceptible or recorded as a finding
- **PS-11**: Setup / Verify / Pass condition
  - Setup: 3 fresh installs per device
  - Verify: 60 s of play, then inspect the installed manifest
  - Pass condition: zero permission prompts and only `VIBRATE`

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/platform-services/ps-5.md`, `ps-6.md`, `ps-11.md` (device evidence, ADVISORY)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 005, 008, 011, 013
- Unlocks: finalizing HapticsConfig defaults; closes AC-18 advisory confidence
