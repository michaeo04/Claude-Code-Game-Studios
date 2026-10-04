# Story 010: App lifecycle handling (background, resume settle)

> **Epic**: Tilt Input
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/tilt-input.md`
**Requirement**: `TR-tilt-input-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (primary); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: Platform Services owns every OS call; on Android `NOTIFICATION_APPLICATION_FOCUS_OUT` emits `app_interrupted` then `app_backgrounded`, `FOCUS_IN` emits `app_foregrounded` then `app_returned`; PAUSED/RESUMED are ignored. Tilt Input consumes `app_backgrounded` and `app_foregrounded`.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Lifecycle sequences are unverified on devices: spikes PS-1 and PS-2 (Platform Services epic) record them; this story is the pure-core half only and does not wait for them. Godot keeps the last gravity vector after Android unregisters the listener, hence the settle.
**Control Manifest Rules (this layer)**:
- Required: lifecycle comes from Platform Services signals `app_backgrounded`/`app_foregrounded`, no OS notification read in Tilt Input; connections are immediate, not `CONNECT_DEFERRED`.
- Forbidden: `CONNECT_DEFERRED` on control signals; reading `NOTIFICATION_APPLICATION_*` in Tilt Input.
- Guardrail: backgrounding clears the buffer (no stale window at resume).

## Acceptance Criteria
- [ ] **AC-24 [C]**: **24a** from Live `on_app_backgrounded()` clears the buffer (`sample_count` 0), sets `neutral_stale`, moves to Acquiring and emits `availability_changed(false)`; **24b** from Unavailable (sensor lost) it moves to Acquiring with no signal; **24c** in Acquiring it clears the buffer and restarts the settle with no state change and no signal; **24d** after `on_app_foregrounded()` at stamp F, polls at F + 299999 us append nothing and the state stays Acquiring, the poll at F + 300000 us is accepted (Live, `availability_changed(true)`, `phi_f = phi_r`), and the start timeout counts from the first post-settle poll; **24e** with `run_resumed` at F + 1000000 us the window holds post-settle samples (`N >= N_min`, pending false); **24f** `on_app_foregrounded()` with no prior background changes nothing; **24g** two `on_app_backgrounded()` in a row equal one; both events change nothing in Live `FALLBACK` and in a release-build configuration error.
- [ ] **AC-49 [C]**: a core that was Live with `SENSOR`, then `on_app_backgrounded()` and `on_app_foregrounded()`, with no valid sample for `SENSOR_START_TIMEOUT` after the settle, goes to Unavailable (not `FALLBACK`) with one `SENSOR_TIMEOUT`; `input_source` stays `SENSOR` and `steer` is 0; a later valid sample returns to Live with one `availability_changed(true)` and `neutral_stale` still true.

## Implementation Notes
On backgrounded: clear the buffer, set `neutral_stale`, return to Acquiring; in Acquiring still clear the buffer and restart the settle with no state change or signal. On foregrounded: discard samples for `SENSOR_RESUME_SETTLE` (default 0.3 s, converted to integer microseconds). Rule 14 guarantees `SETTLE + G + W <= 1.0` so the window at `run_resumed` (at least 1.0 s later) holds post-settle samples. Timeout with `sensor_ever_live` true leaves Acquiring for Unavailable (one `SENSOR_TIMEOUT`); the control scheme never changes mid-session. The wiring of Platform Services' signals to these methods is in Story 012 (adapter) and the composition root (`_wire()`).

## Out of Scope
- Platform Services epic: PS-1/PS-2 device lifecycle evidence, `app_interrupted` handling by Run State.
- Story 015: P-3 (30 s background, no steer spike) on a device.

## QA Test Cases
- **AC-24a-g**: Given Live / Unavailable / Acquiring / `FALLBACK` / release-config cores with explicit stamps; When lifecycle events and polls at the listed offsets; Then state, `sample_count`, flags and signal counts exactly as listed
  - Edge cases: 299999 vs 300000 us boundary; double background; foreground without background
- **AC-49**: Given a previously Live core; When background, foreground, 2 s without a valid sample; Then Unavailable with one error, `input_source` SENSOR; a later valid sample returns to Live

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tilt_input/tilt_core_app_lifecycle_test.gd`
**Evidence**: `tests/unit/tilt_input/tilt_core_app_lifecycle_test.gd` (passing)

## Dependencies
- Depends on: Story 005, Story 007, Story 008; platform-services (signals `app_backgrounded`/`app_foregrounded`, wiring only)
- Unlocks: Story 011, Story 012
