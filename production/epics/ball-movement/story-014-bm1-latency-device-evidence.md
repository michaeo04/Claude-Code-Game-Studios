# Story 014: BM-1a and BM-1b latency device evidence (first-playable gate)

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 4 h plus device time
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md` (BM-1a, BM-1b; F5b)
**Requirement**: `TR-ball-movement-018`, `TR-ball-movement-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (device evidence at a named gate); ADR-0005: Sensor source and input pipeline (P-1/P-2 poll cost and end-to-end latency, secondary)
**ADR Decision Summary**: A numeric on-device check is Integration evidence executed on a device and is BLOCKING at its named gate. BM-1a and BM-1b are BLOCKING for the first-playable gate only, signed by qa-lead and technical-director (designation ratified by producer 2026-09-22; verify against `production/session-logs/agent-audit.log` before citing).
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `Input.get_gravity()` is unverified on 4.7.2; Tilt Input spike V-1 must have run first. Sensor refresh believed about 50 Hz.
**Control Manifest Rules (this layer)**:
- Required: median of 20 trials; 30 Hz is recorded, not failed; evidence in `bm-1a.md` and `bm-1b.md`.
- Forbidden: loosening `T_VIS_MIN` or `T_DODGE_180_MAX` on a miss; skipping a trial without a written reason.
- Guardrail: pre-committed failure response is lowering `V_MAX` toward about 22 u/s.

## Acceptance Criteria
- [ ] **BM-1a Latency, software** (BLOCKING first playable): synthetic 10 degree gravity step through the adapter with per-frame `theta` logged, time to 63% interpolated: median of 20 at most 0.13 s at 60 Hz (nominal 0.118 s); 30 Hz recorded, not failed. Run first, on the first day any single device is available.
- [ ] **BM-1b Latency, end to end** (BLOCKING first playable): 240 fps camera on a jig, median of 20 at most 0.20 s and worst at most 0.25 s at 60 Hz; 30 Hz recorded, not failed.
- [ ] Evidence files signed by qa-lead and technical-director (invoked, and the invocation verified in the audit log), or a recorded miss with the pre-committed response applied.

## Implementation Notes
Use the Story 013 recorder and injector. The 0.11 s latency stack figure in F5a is a guess pending this measurement; record the measured value so the GDD can bound or replace it. 60 Hz only is fairness-gated (30 Hz declaration B10).

## Out of Scope
- BM-3 (Story 015), BM-2 (Story 016)
- 30 Hz fairness derivation (live GDD gap)

## QA Test Cases
- **BM-1a**
  - Given: dev build on a mid-tier Android device at 60 Hz
  - When: 20 synthetic 10 degree steps
  - Then: median time to 63% at most 0.13 s
  - Edge cases: also at 30 Hz, recorded only
- **BM-1b**
  - Given: jig with a 240 fps camera
  - When: 20 physical tilt steps
  - Then: median at most 0.20 s, worst at most 0.25 s
  - Edge cases: device refresh 120 Hz recorded

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/ball-movement/bm-1a.md` and `bm-1b.md` with raw logs and sign-off
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 013; tilt-input spike V-1
- Unlocks: first-playable gate; Story 016 (tuning lock)
