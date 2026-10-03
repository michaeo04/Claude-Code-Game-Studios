# Story 016: Advisory device checks PS-8, PS-9 and PS-10 (safe area, frame cap, background time)

> **Epic**: Platform Services
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 4 h (plus device time)
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/platform-services.md` (Device checks PS-8, PS-9, PS-10)
**Requirement**: `TR-platform-services-018`, `TR-platform-services-012`, `TR-platform-services-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (Decisions 3, 6, 7; Risks)
**ADR Decision Summary**: Display facts are re-read on regaining edges and size change (insets can arrive late); `max_fps = 60` with a pacing test on a 120 Hz device; the `app_backgrounded` flush must finish inside the time Android grants.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: NEEDS VERIFICATION: `DisplayServer.get_display_safe_area()` under edge-to-edge (asynchronous insets); `screen_get_refresh_rate()`; whether a 60 cap holds on a 120 Hz device (`max_fps` is not vsync-locked); how long the OS lets the app run after `app_backgrounded`. Fallback if the cap fails: `Engine.max_fps` or Swappy frame pacing, recorded for the technical-director.
**Control Manifest Rules (this layer)**:
- Required: frame cap `application/run/max_fps = 60`, frame time 16.6 ms; the minimum background time is at least 5 x Save & Persistence's flush budget (provisional 100 ms, so 500 ms); PS-10 blocks the Save & Persistence epic although ADVISORY here.
- Forbidden: do not widen the cap range or add a native plugin to change pacing without the technical-director.
- Guardrail: 59 trials per case for PS-10; 3600 frames for PS-9.

## Acceptance Criteria
- [ ] **PS-8** Safe area: raw `Rect2i` and pixels recorded; an Android cutout is excluded (screenshot); Android status-bar and gesture-bar insets recorded; when insets arrive (construction versus regain edge versus size change) recorded.
- [ ] **PS-9** 120 Hz Android, 3600 frames (60 s at 60): mean 58.2-61.8 fps (60 +/- 3%), no interval under 8.5 ms (120 Hz is 8.33 ms); a frame-time variance or p99 note is added (GDD Open Question 12).
- [ ] **PS-10** Background time: a 10 ms heartbeat after BG from a worker thread, 59 Home and 59 lock cases; the minimum is at least 500 ms (5 x the provisional 100 ms flush budget); the result is delivered to the Save & Persistence epic.

## Implementation Notes
Extend the Story 013 logger with a safe-area overlay, a frame-time recorder (microsecond intervals from `Time.get_ticks_usec` in the spike scene only, not in `PlatformCore`) and a worker-thread heartbeat started on `app_backgrounded`. Findings go in `production/qa/evidence/platform-services/ps-8.md`, `ps-9.md`, `ps-10.md` (device, OS, date, raw log, result). Any change to a Tuning Knob or to the display-facts read points goes back to the GDD.

## Out of Scope
- Story 013 and Story 014: blocking lifecycle and Back spikes
- Safe-area conversion helper from pixels to stretch units (GDD Open Question 23, HUD/Camera stories)

## QA Test Cases
- **PS-8**: Setup / Verify / Pass condition
  - Setup: a notch/cutout phone and a gesture-navigation phone with the spike overlay
  - Verify: log the raw rect and screenshot after launch, after a Home cycle and after a size change
  - Pass condition: values recorded and the cutout excluded; late-arriving insets documented
- **PS-9**: Setup / Verify / Pass condition
  - Setup: 120 Hz device, `max_fps = 60`, 60 s run
  - Verify: frame intervals over 3600 frames
  - Pass condition: mean 58.2-61.8 fps and no interval under 8.5 ms
- **PS-10**: Setup / Verify / Pass condition
  - Setup: heartbeat from a worker thread after BG; 59 Home and 59 lock cases
  - Verify: the longest silent gap or last heartbeat time per case
  - Pass condition: minimum at least 500 ms

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/platform-services/ps-8.md`, `ps-9.md`, `ps-10.md` (device evidence, ADVISORY; PS-10 blocks the Save & Persistence epic)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 006, 008, 011, 013
- Unlocks: Save & Persistence epic (PS-10); HUD/Camera safe-area decisions
