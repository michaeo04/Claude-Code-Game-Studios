# Story 011: MS-1 boot sequence time on a mid-tier phone

> **Epic**: Map Loader & MapConfig
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0004
**Requirement**: `TR-map-loader-???`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (spike MS-1); ADR-0014 (spike HV-1 shares the budget)
**ADR Decision Summary**: The synchronous boot sequence (load, validate, apply, prime) targets at most 100 ms on a mid-tier phone; the hazard prewarm shares that budget; threaded `load_definition` only if exceeded.
**Engine**: Godot 4.7.2 | **Risk**: HIGH (shared with ADR-0014 mesh build)
**Engine Notes**: Time with `Time.get_ticks_usec()` around `attempt()` in a debug build on device; an `ArrayMesh` cannot be built off the main thread, so the HV-1 remedy is fewer triangles or a lazy build in a loading frame (ADR-0014 risks).
**Control Manifest Rules (this layer)**:
- Required: threaded `load_definition` only if MS-1 shows the sequence is too slow; keep Phase A and B unchanged (pre-committed response)
- Required: if sum with prewarm misses 100 ms, re-derive the MS-1 number with the prewarm included (ADR-0014 Decision 4)
- Forbidden: threaded loading unless MS-1 exceeds the target
- Guardrail: boot map-load at most 100 ms (load, validate, prime), measured, not estimated

## Acceptance Criteria
- [ ] Boot `attempt()` time is recorded on a mid-tier Android phone: total and per phase (A1 load, rest of A, B1 to B4 split with hazard prewarm, B5 prime), median and max of at least 10 cold starts (ADR-0004 Validation MS-1)
- [ ] Result compared with the 100 ms target; PASS, or FAIL with the pre-committed response chosen (threaded `load_definition` seam) and a follow-up story filed
- [ ] The hazard prewarm share (HV-1) is separated so ADR-0014's budget claim is checked, including memory of the mesh cache for the shipped library
- [ ] A Retry timing (second attempt on a good map after one forced failure) is recorded

## Implementation Notes
Add debug-only timing hooks via the `log_sink`/a debug label, no new gameplay code, no timing in release. Run after the hazard view and Pattern `apply_map` exist; before then record A-phase and B5 only and mark the rest "not yet measurable". Use the same device session as the other first-playable spikes where practical.

## Out of Scope
- Story 010: export correctness
- Implementing the threaded seam (only if this story's result requires it; separate story)
- Per-tick costs (OB-1)

## QA Test Cases
- **AC-1/2**: timing
  - Setup: debug APK, `adb logcat`, 10 cold starts, device idle, battery saver off
  - Verify: the logged phase times and total
  - Pass condition: median and max at most 100 ms; otherwise recorded as FAIL with remedy
- **AC-3**: prewarm and memory share recorded
- **AC-4**: Retry timing recorded

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/map-loader-ms1-boot-time.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 009; obstacle-system epic (HazardView `apply_map`) and pattern-difficulty epic for the full figure
- Unlocks: lock of the 100 ms boot guardrail; possible threaded-seam story
