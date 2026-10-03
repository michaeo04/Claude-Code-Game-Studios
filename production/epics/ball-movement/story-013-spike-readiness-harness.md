# Story 013: Spike readiness (theta logging, jig plan, evidence folder)

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md` (Device and playtest checks, Producer note, ratification condition 3)
**Requirement**: `TR-ball-movement-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary; a test needing a real device is device evidence, not a GUT test); ADR-0002: Game loop (the harness is wired through `GameRoot`)
**ADR Decision Summary**: A device test is evidence in `production/qa/evidence/`, blocking at its named gate. `GameRoot` stays wiring only.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: per-frame logging must not add file I/O inside the frame in release builds (debug/dev build flag only); do not use `OS.is_debug_build()` to gate dev input (lint). Android file write path `user://` pulled with adb.
**Control Manifest Rules (this layer)**:
- Required: per-frame `theta` (and `dt_eff`, `steer`) logging behind a dev-build seam; evidence files at `production/qa/evidence/ball-movement/bm-N.md` with device, build, date, raw log, result.
- Forbidden: `OS.is_debug_build()` gating of dev input; shipping the logger in release; secrets or personal data in logs (repository is public).
- Guardrail: logging overhead must not change measured latency; recorded alongside the result.

## Acceptance Criteria
- [ ] **TR-021 harness**: a dev-build-only recorder writes per-frame `theta`, `steer`, `dt_eff`, frame index to a file, plus a synthetic 10 degree gravity step injector through the adapter (for BM-1a).
- [ ] A written jig plan (240 fps camera, display-synced marker, how end-to-end latency is read) exists for BM-1b, with the device list (at least 2 Android makers) tracked as an owned external dependency (user is procuring; date to be confirmed).
- [ ] `production/qa/evidence/ball-movement/` exists with a `README.md` template for `bm-N.md` (device, build, date, raw log, result, sign-off line) and the AC-27 reset-timing placeholder.
- [ ] A risk-register entry set is proposed (device availability High/High owner user; BM-1 retune cascade Medium/High owner producer + game-designer with pre-committed response lower `V_MAX` toward about 22, never loosen `T_VIS_MIN`/`T_DODGE_180_MAX`) for the producer to adopt.
- [ ] The AC-27 device timing (max over 1000 `reset()` calls at most 1 ms) can be measured with the harness.

## Implementation Notes
Keep the recorder a separate dev-only node/object injected by `GameRoot` under a dev feature tag, not in `BallCore`. Android export for the spike needs the platform-services preset (cross-epic). Decision on retune cascade is the GDD's strategic note (2026-09-22): no pre-emptive `V_MAX` change before the spike.

## Out of Scope
- Story 014/015/016/017: the measurements themselves
- Buying devices

## QA Test Cases
- **Harness**
  - Given: dev build on a desktop run
  - When: 600 frames run with the recorder on
  - Then: 600 rows with monotone frame index and finite `theta`
  - Edge cases: recorder off in a release-tag build (no file written)
- **Evidence folder**
  - Given: the repo
  - When: the folder is listed
  - Then: README template present with every required field
  - Edge cases: no raw logs committed above a sane size

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/ball_movement/ball_movement_recorder_test.gd` (must pass) and `production/qa/evidence/ball-movement/README.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 010; composition-root (dev-only wiring); platform-services (Android export preset); tilt-input (V-1 sample source)
- Unlocks: Story 014, Story 015, Story 016, Story 017
