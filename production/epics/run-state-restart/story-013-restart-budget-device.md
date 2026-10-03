# Story 013: Restart budget measurement on device (AC-27)

> **Epic**: Run State & Restart
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

> **Blocked**: `TR-run-state-restart-022` is Partial in `docs/architecture/architecture-traceability.md` (t_reset shares unverified for N = 12; Environment, Settings and Near-Miss shares missing). Unblock when the `t_reset` / `t_track` shares are re-costed (GDD F2 note C1) and the first playable build runs with Ball, Obstacle, Camera and Juice.

## Context
**GDD**: `design/gdd/run-state-restart.md`
**Requirement**: `TR-run-state-restart-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (partial coverage); ADR-0005: Sensor source and input pipeline (P-1, P-2 latency)
**ADR Decision Summary**: One main-thread tick, orchestration under 0.1 ms; end-to-end input latency budget 100 ms (P-2); `poll()` p95 at most 0.1 ms (P-1).
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `frame_post_draw` fires after submission, not at display, so keep the `N_present` term; `Input.parse_input_event` buffering must be shown comparable to a real touch (test-plan section 6).
**Control Manifest Rules (this layer)**:
- Required: a test that needs a real device is device evidence in `production/qa/evidence/`, blocking at its named gate
- Forbidden: writing this as a GUT test; mixing percentiles
- Guardrail: 10-minute run, no orchestration frame drops at 60 Hz and on a 120 Hz device; frame 16.6 ms

## Acceptance Criteria
- [ ] **AC-27 (a)**: on a mid-tier Android device (model and refresh rate recorded) with a release export, at 60 and at 30 fps (`Engine.max_fps`): 100 scripted restarts, first 10 discarded, taps injected through the real input path, timed from `press_us` to `frame_post_draw` of the first frame after `run_started`, with per-handler `Time.get_ticks_usec` deltas for `t_reset`; report p50, p95, max
- [ ] **AC-27 (b)**: 20 samples of `t_in` with a 240 fps camera (touch to the first frame showing a debug flash toggled in the input handler, minus the engine's handler-to-`frame_post_draw` time for that frame); use the median
- [ ] Pass: p95 of (a) plus the median of (b) at most 0.4 s (ADVISORY); max of (a) plus max of (b) at most 1.0 s (BLOCKING at the first-playable milestone gate); the endpoint is defined consistently with F2 and rule 9 (add the `N_present` term)

## Implementation Notes
Add a debug-only measurement hook outside the core (core stays pure). Record per-system `t_reset` shares including the Near-Miss, Environment and Settings handlers missing from the GDD list; feed the numbers back into GDD F2 and the traceability Partial row. Run state's story cannot close on this alone: it is the milestone gate item (test-plan section 6).

## Out of Scope
- Stories 001 to 012: all logic work
- Story 014: flash count

## QA Test Cases
- **AC-27**: Setup / Verify / Pass condition
  - Setup: release export on the reference device; scripted restart runner; 240 fps camera
  - Verify: percentiles of (a) and median of (b) computed from raw logs stored with the evidence
  - Pass condition: the thresholds above, device model and refresh rate recorded

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/run-state-restart-budget-[date].md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 012; ball-movement, obstacle-system, camera and juice epics (first playable); Platform Services export preset
- Unlocks: closing the epic's performance gate
