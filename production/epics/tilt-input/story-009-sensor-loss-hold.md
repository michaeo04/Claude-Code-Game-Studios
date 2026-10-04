# Story 009: Sensor-loss dropout hold (F6)

> **Epic**: Tilt Input
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0005: Sensor source and input pipeline; ADR-0002: Game loop, Composition Root and tick order (secondary)
**ADR Decision Summary**: `TiltCore` owns validity: a run never plays on a dead sensor; the poll runs every rendered frame and time is the injected clock.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API; all comparisons run on integer microseconds.
**Control Manifest Rules (this layer)**:
- Required: injected `clock_us`; `DT_MAX` clamp per poll; typed signal `availability_changed(available: bool)`.
- Forbidden: `Time.` in the core; holding a dead sensor indefinitely.
- Guardrail: no allocation per invalid poll.

## Acceptance Criteria
- [ ] **AC-30 [C]** (50 Hz): `live_core(0, 20000)` then 50 ticks at 20.3 (`steer` 0.8), then invalid samples: through the 5th invalid poll (`invalid_us` 100000) `steer` stays 0.8, `valid` true, state Live, no signal (also for a single invalid poll); at the 6th (120000) the state is Unavailable, `valid` false, `steer` 0, `neutral_stale` true and exactly one `availability_changed(false)`, with no second signal on later polls.
- [ ] **AC-31 [C]**: valid samples returning within the hold continue the filter (no restart; the valid sample uses one clamped poll `dt`, 0.02 s at 50 Hz, and the invalid polls did not move `phi_f`); from Unavailable a valid sample gives Live, one `availability_changed(true)`, `phi_f = phi_r` and `neutral_stale` still true; invalid polls advance `previous_now`.
- [ ] **AC-44 [C]**: **44a** a single invalid poll stamped 0.2 s after the previous leaves Live and `valid` true; **44b** three consecutive invalid polls 0.1 s apart (`invalid_us` 300000) give Unavailable on the third; **44c** with `HOLD = 0` the first and second invalid polls hold and the third gives Unavailable; **44d** with `HOLD` 0.3, after valid samples a 0.5 s hitch stamps the first of three invalid polls (`invalid_us` clamped to 100000), then two more 0.02 s apart: `invalid_us` is 140000 and the state is still Live on the third poll; a poll rejected by the stamp rule counts neither `invalid_us` nor `invalid_polls`.

## Implementation Notes
F6: consecutive invalid polls accumulate `invalid_us += min(dt_us, DT_MAX_us)` and `invalid_polls += 1`; a valid sample resets both. While `invalid_us <= HOLD_us` OR `invalid_polls < DROPOUT_MIN_POLLS` (3) the last `steer` is held, `valid` stays true, state Live. Otherwise Unavailable: `valid` false, `steer` 0, `neutral_stale` set, one `availability_changed(false)`. A frame hitch counts as at most `DT_MAX` and one poll, so a hitch plus one invalid sample never pauses the run. A valid sample from Unavailable returns to Live and the next capture event takes a fresh neutral. Applies to Live `SENSOR` only. Whether the sensor-lost pause is sent is Story 012.

## Out of Scope
- Story 012: the level-triggered `pause_requested(sensor_lost)` and `flush()`.
- Story 010: loss caused by the app being backgrounded.
- Story 016: V-8 spurious `sensor_lost` pauses on a device.

## QA Test Cases
- **AC-30**: Given a 50 Hz Live core at steer 0.8; When 1..6 invalid polls; Then held through the 5th, Unavailable on the 6th with one signal
- **AC-31**: Given a return inside the hold / from Unavailable; Then filter continues / `phi_f = phi_r`, one `true`, stale still true
- **AC-44**: the four sub-cases with explicit stamps; Edge cases: stamp-rule rejects count nothing; hitch clamp to `DT_MAX`

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tilt_input/tilt_core_sensor_loss_hold_test.gd`
**Evidence**: `tests/unit/tilt_input/tilt_core_sensor_loss_hold_test.gd` (passing)

## Dependencies
- Depends on: Story 006, Story 008
- Unlocks: Story 011, Story 012
