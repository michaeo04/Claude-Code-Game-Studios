# Story 011: Orchestration soak on device (60 Hz and 120 Hz)

> **Epic**: Composition Root & Game Loop
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h (plus device time)
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0002
**Requirement**: `TR-composition-root-???` (ADR-0002 Validation Criteria, Risks; spikes PS-1/PS-2/PS-9 cross-reference)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: `real_dt` equals the rendered-frame interval and follows refresh rate, vsync and `Engine.max_fps`; orchestration must cost under 0.1 ms and cause no dropped frames.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION on device: `_process` behaviour through FOCUS_OUT/FOCUS_IN and while backgrounded (PS-1, PS-2, owned by platform-services; this story records only what the running loop sees); whether `Time.get_ticks_usec()` stands still across deep sleep (Run State Open Question 5); `Tween`, `AnimationPlayer`, `GPUParticles3D` and shader time while `dt_eff = 0` (ADR-0010). `max_fps` 60 on a 120 Hz panel is UNVERIFIED (PS-9).
**Control Manifest Rules (this layer)**:
- Required: record vsync mode and refresh rate with each run; test at 60 and 120 Hz; the tick log reports per-step cost.
- Forbidden: tuning that assumes a 16.6 ms frame; treating a debug-build result as the gate.
- Guardrail: orchestration under 0.1 ms; simulation steps provisional 3 ms; 10-minute run with no dropped frames attributable to orchestration; 60 FPS, 512 MB.

## Acceptance Criteria
- [ ] A 10-minute run on a mid-tier Android phone at 60 Hz shows no dropped frames attributable to orchestration (ADR-0002 VC-4)
- [ ] The same run on a 120 Hz device records vsync mode and refresh rate and shows no dropped frames attributable to orchestration (VC-4)
- [ ] Orchestration cost (the sum of `_tick` call overhead excluding the systems' own steps) is reported with p50 and p95 and is under 0.1 ms (ADR-0002 Performance Implications)
- [ ] Observed `real_dt` distribution is reported per refresh rate, and any `real_dt` above the stall-guard threshold during the run is explained (Consequences)
- [ ] The doc records what the loop observed across a Home press and return (`_process` continues or stops, size of the first `real_dt` after return), cross-referenced to PS-1/PS-2 (Decision 9)

## Implementation Notes
Add a debug-only frame-timing probe to `GameRoot` (compiled out of release by `OS.is_debug_build()` is acceptable for this probe, unlike the editor steering) that records per-frame `real_dt` and the time spent in `_tick`; export to a log file in `user://`. Use a release export for the gate numbers if the probe can be enabled by a feature tag; otherwise note the debug-build caveat in the doc. Run only after Story 010 and at least one real system in the loop (otherwise the cost is not representative); record which systems were present.

## Out of Scope
- platform-services epic: PS-1, PS-2, PS-4, PS-9, PS-12
- Story 012: rebase frame capture
- run-state-restart epic: stall guard behaviour

## QA Test Cases
- **AC-1/2**: 10-minute runs
  - Setup: release export on two devices (one 60 Hz, one 120 Hz), scripted or steady play
  - Verify: frame-time capture and the probe log
  - Pass condition: no frame over budget attributable to `GameRoot` orchestration; settings recorded
- **AC-3**: cost
  - Setup: probe log from AC-1
  - Verify: p50 and p95 of orchestration time
  - Pass condition: under 0.1 ms
- **AC-4/5**: `real_dt` and focus loss
  - Setup: press Home mid-run, return after 5 s and after 60 s
  - Verify: first `real_dt` after return; whether `_process` stopped
  - Pass condition: recorded in the doc and consistent with the stall guard plus FOCUS_OUT design

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/composition-root-orchestration-soak.md` (device-evidence doc with device models, Android versions, refresh rate, vsync mode, numbers)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 010; platform-services epic (export preset); at least one system epic in the loop
- Unlocks: first-playable gate; the `max_fps` decision of PS-9
