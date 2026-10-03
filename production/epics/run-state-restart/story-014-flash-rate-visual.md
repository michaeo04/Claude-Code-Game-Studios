# Story 014: Hit-restart flash rate on device (AC-26)

> **Epic**: Run State & Restart
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Estimate**: 1-2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-025`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0010: Presentation time, hit-stop and the Ink cover (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: Presentation effects are pure functions of a microsecond stamp and the injected `clock_us`; a presentation never delays a phase change; the flash cap is enforced through the lock bound (Story 011) and Juice's flash register.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: counting flashes from video is unreliable (test-plan section 6): add a debug flash-trigger log so the count comes from the log and the recording is corroboration.
**Control Manifest Rules (this layer)**:
- Required: Visual/Feel evidence is ADVISORY (not designated as a sole falsification gate) with screenshot or recording and lead sign-off
- Forbidden: presentation timers adding `real_dt`; shader `TIME` in hit effects
- Guardrail: at most 3 flashes in any 1.0 s window (art bible)

## Acceptance Criteria
- [ ] **AC-26** (ADVISORY, needs Juice & Feedback, D1): on the reference device a bot that dies and restarts at the earliest allowed moment for 30 s shows at most 3 flashes in any 1.0 s window, counted from the debug flash-trigger log and confirmed on a screen recording

## Implementation Notes
Uses the bot of Story 011 driven in the real game with the debug log from Juice's flash register. Result feeds GDD Open Question 13 (guessed values to replace by measurement). If it fails, the lock or Juice flash behaviour is retuned in their own stories, not here.

## Out of Scope
- Story 011: the logic bound on `run_ended` frequency
- Juice & Feedback epic: the flash implementation

## QA Test Cases
- **AC-26**: Setup / Verify / Pass condition
  - Setup: build with Juice, bot running 30 s of die-and-restart at the earliest allowed press, debug flash log on, screen recording
  - Verify: slide a 1.0 s window across the log, take the maximum count
  - Pass condition: maximum at most 3, recording agrees with the log, lead sign-off recorded

## Test Evidence
**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/run-state-restart-flash-rate-[date].md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 011; juice-feedback epic (flash register), hud epic (tap-anywhere restart)
- Unlocks: none
