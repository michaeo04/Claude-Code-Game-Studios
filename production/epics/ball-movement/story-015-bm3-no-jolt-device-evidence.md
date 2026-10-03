# Story 015: BM-3 no jolt at start and resume (first-playable gate)

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3 h plus device time
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md` (BM-3; Core Rule 5; Edge Cases, Start/resume)
**Requirement**: `TR-ball-movement-021`, `TR-ball-movement-007`, `TR-ball-movement-023`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (device evidence at a named gate); ADR-0002: Game loop, Composition Root and tick order (restart and resume paths)
**ADR Decision Summary**: A device check with a numeric threshold is Integration evidence, BLOCKING at the named gate (first playable). Pre-committed failure response: lower `V_MAX` toward about 22 u/s, do not loosen `T_VIS_MIN` or `T_DODGE_180_MAX`.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: depends on Tilt neutral capture timing at Menu-to-Play, restart and `run_resumed` (Tilt AC-27/41); unverified on device until V-1 and V-2.
**Control Manifest Rules (this layer)**:
- Required: the two "held still" conditions (restarts, resumes) each run at n = 30 and reported separately, never pooled; glide conditions at n = 10 each.
- Forbidden: pooling conditions; repeating trials until clean; editing thresholds after seeing results.
- Guardrail: designation expires when the first-playable gate is passed.

## Acceptance Criteria
- [ ] **BM-3 held still**: 30 restarts and 30 resumes, reported separately: `|theta|` stays 0 for the first 1 s; zero unasked movements in each condition's own 30 trials.
- [ ] **BM-3 held tilt (glide)**: 10 restarts and 10 resumes with a 10 degree held tilt: per-frame move at most 0.05 rad; restart glide completes within `T_DODGE_180` (1.064 s) at worst; resume shows no slide from the moved neutral.
- [ ] Qualitative glide-feel rating (1-5, "reads as weight" vs "reads as lag or correction") collected on these trials.
- [ ] Evidence `production/qa/evidence/ball-movement/bm-3.md` signed by qa-lead and technical-director, or a recorded miss with the pre-committed response applied.

## Implementation Notes
Use the Story 013 recorder to log `theta` per frame. The segment(s) spanning `s` = 0 to at least 11 u must be hazard-free (TR-023): confirm with the chunk content in the test build and note it in the evidence; the check itself belongs to Pattern & Difficulty content.

## Out of Scope
- BM-1 (Story 014); BM-2/5 (Story 016)

## QA Test Cases
- **BM-3 held still**
  - Given: device in hand at rest, dev build
  - When: 30 restarts, then 30 resumes
  - Then: `|theta|` 0 for 1 s in every trial
  - Edge cases: first tick after `run_started`/`run_resumed` is a settling tick
- **BM-3 held tilt**
  - Given: 10 degree held tilt
  - When: 10 restarts, 10 resumes
  - Then: per-frame move at most 0.05 rad; no resume slide
  - Edge cases: glide rating logged

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/ball-movement/bm-3.md` with raw logs and sign-off
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 013; tilt-input spikes V-1/V-2; run-state-restart and composition-root running builds
- Unlocks: first-playable gate
