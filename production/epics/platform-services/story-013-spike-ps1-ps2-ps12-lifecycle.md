# Story 013: Device spike PS-1, PS-2 and PS-12 (lifecycle sequences and thread)

> **Epic**: Platform Services
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 4 h (plus device time)
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/platform-services.md` (Device checks PS-1, PS-2, PS-12)
**Requirement**: `TR-platform-services-018`, `TR-platform-services-005`, `TR-platform-services-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (Decisions 2, 3, 7; Validation Criteria PS-1, PS-2, PS-12)
**ADR Decision Summary**: `FOCUS_OUT` is the primary pause signal and `PAUSED/RESUMED` are ignored; the thread rule defers only off the main thread. The spikes record what Android actually sends.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: NEEDS VERIFICATION on device: order and presence of `FOCUS_OUT/IN` and `PAUSED/RESUMED` under Vulkan; thread of Android lifecycle callbacks; shade/heads-up/split-screen behaviour; `screen_set_keep_on` against a 30 s screen timeout. The spike logger records all eight notifications plus `WM_WINDOW_FOCUS_IN/OUT` and `WM_SIZE_CHANGED`.
**Control Manifest Rules (this layer)**:
- Required: PS-1, PS-2, PS-4 are BLOCKING for the first playable, signed by qa-lead and technical-director; matrix: Android 13+ mid-tier, a second Android vendor on Android 12 or lower, a 120 Hz Android; 10 trials per scenario per device, 10 of 10 required, every trial reported.
- Forbidden: never record a sign-off as complete without verifying it; no native plugin to work around a missing focus event (post-spike escalation to the technical-director).
- Guardrail: a deviation is a finding, not a failure of the spike: it adds an AC-1 row and a recorded decision.

## Acceptance Criteria
- [ ] **PS-1** Android Home, notification shade, screen lock, heads-up call, full-screen call, app switcher, low-battery dialog, ANR dialog, split-screen, and Android 16 on a display of 600 dp or more: sequences recorded; hypothesis shade, heads-up, dialogs and split-screen emit nothing, the others give A1. With sticky immersive mode on, a first top-edge swipe must not reach the play area with the shade. A 3-minute tilt-only run with a 30 s device screen timeout: the screen must not dim.
- [ ] **PS-2** Android Vulkan: count PAUSED/RESUMED over 10 Home cycles (hypothesis 0); the replay equals A1 either way.
- [ ] **PS-12** The thread id in each handler over 59 Home cycles is always the main thread and outside a tick; otherwise the node uses `call_deferred` (recorded).
- [ ] Each trial passes iff the recorded sequence yields exactly a named AC-1 row; deviations are recorded as findings with a decision; raw traces are kept as AC-17 fixtures (the AC-17 replay test itself is deferred).

## Implementation Notes
Build a throwaway logger scene (under `prototypes/` or a spike scene excluded from export) using the Story 011 preset, logging notification names, timestamps and `OS.get_thread_caller_id()` for each event. Use one evidence file per item: `production/qa/evidence/platform-services/ps-1.md`, `ps-2.md`, `ps-12.md` (device, OS, date, raw log, result). Reliability claims need 59 trials with zero failures per device. Findings that change the model (e.g. the shade emits nothing) feed GDD Open Question 2 and the technical-director.

## Out of Scope
- Story 014: PS-4 Back
- AC-17 replay test (deferred; owner this story's fixtures then the epics named in the GDD)

## QA Test Cases
- **PS-1/PS-2/PS-12**: Setup / Verify / Pass condition
  - Setup: install the Story 011 build with the logger on each matrix device
  - Verify: run each scenario 10 times, compare each trial's sequence to the AC-1 rows, record thread ids
  - Pass condition: 10/10 trials per scenario match a named row, the thread is main every time (or the deferred fallback is recorded), no screen dim in the 3-minute run; signed by qa-lead and technical-director before the first-playable gate

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/platform-services/ps-1.md`, `ps-2.md`, `ps-12.md` (device evidence, BLOCKING for the first-playable gate)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 008, 011; user phones
- Unlocks: first playable; Save epic confidence in the `app_backgrounded` flush; AC-17 fixtures
