# Story 014: Spike V-1 and V-5, sensor sign and units on devices

> **Epic**: Tilt Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 h (plus device time)
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-026`, `TR-tilt-input-017`, `TR-tilt-input-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0005: Sensor source and input pipeline; ADR-0006: Android platform integration (device floor, export)
**ADR Decision Summary**: `Input.get_gravity()` is the only source; `SENSOR_SIGN` is expected -1 and units m/s^2, both unverified; V-1 runs on a real device before any tilt tuning value is locked and is BLOCKING for the first playable.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0005 Verification Required (1)-(3): `get_gravity()` returns m/s^2 on Android 4.7.2 and the zero vector without a gravity sensor; ~50 Hz refresh; not covered by the engine reference. Needs the first Android export (Platform Services / ADR-0006) and a throwaway logger scene in `prototypes/`.
**Control Manifest Rules (this layer)**:
- Required: V-1 on at least two Android makers is blocking for the first playable and runs before any tilt tuning value is locked; device evidence lives under `production/qa/evidence/tilt-input/`.
- Forbidden: reading sensors in `src/` outside `tilt_input.gd` (the logger lives in `prototypes/`, isolated from `src/`).
- Guardrail: log at 60 Hz without affecting frame time.

## Acceptance Criteria
- [ ] **V-1** (BLOCKING for the first playable): raw `g.x` sign at the shipped orientation, right edge lowered about 30 deg and then the left edge, 5 trials each way per device, logged at 60 Hz, at least 2 Android vendors. Pass: the sign is the same in 5 of 5 trials per device and direction and opposite between the two directions; `SENSOR_SIGN` is set so F1 gives `phi > 0` for the right edge lowered (expected -1).
- [ ] **V-5**: reported units and `|g|` at rest are within [9.0, 10.6] m/s^2 on every device in the matrix (hypothesis; record any deviation) and no zero vector.
- [ ] Evidence file `production/qa/evidence/tilt-input/v1-sign.md` records device, date, raw log and result and is signed by the qa-lead and the technical-director (verify each sign-off against `production/session-logs/agent-audit.log` before recording it).
- [ ] A device without a gravity sensor (if available) reaches Unavailable within `SENSOR_START_TIMEOUT`; otherwise record that none was tested (ADR-0005 Validation Criteria).

## Implementation Notes
Matrix: a mid-tier Android (target), a low-end Android without a gyroscope (where `TYPE_GRAVITY` is synthesized from the accelerometer), and a foldable or tablet if in scope; report every result, do not average away a failure. Use a protractor or photo for the 30 deg tilt. The end-to-end check (right edge lowered, ball moves right, 10 of 10) is AC-40, owned by the Ball Movement epic on the first playable build; V-1 is its device counterpart. The result sets `SENSOR_SIGN` in `TiltConfig`; if the sign is not -1 on some devices, stop and escalate (ADR-0005 Alternative 1 supersession).

## Out of Scope
- Story 015: latency and poll cost; Story 016: noise, jolt, feel and posture spikes.
- Ball Movement epic: AC-40.

## QA Test Cases
- **V-1**
  - Setup: debug APK with the logger, device flat then tilted right edge down ~30 deg, then left edge down, 5 trials each
  - Verify: sign of `g.x` per trial; photo of the protractor; `SENSOR_SIGN` chosen
  - Pass condition: 5 of 5 same sign per direction per device, opposite across directions, on at least 2 vendors
- **V-5**
  - Setup: phone at rest in several poses
  - Verify: `|g|` per device
  - Pass condition: within [9.0, 10.6] m/s^2, never the zero vector

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/tilt-input/v1-sign.md` (V-1) and `production/qa/evidence/tilt-input/v5-units.md` (V-5), signed
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 013; platform-services (first Android export preset, ADR-0006 spikes PS-1/PS-2/PS-4)
- Unlocks: Story 015, Story 016; the first playable gate; Ball Movement AC-40
