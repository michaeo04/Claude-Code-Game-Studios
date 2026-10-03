# Story 014: Seam visual checks and speed-cue playtest

> **Epic**: Tube Track
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: 3 h plus playtest session
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-014`, `TR-tube-track-015`, `TR-tube-track-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0003: Renderer choice and tube render route (primary); ADR-0009: Test framework and CI (Visual/Feel evidence rule)
**ADR Decision Summary**: Seams are a flat shading band with no geometric relief; fog and contrast are measured after tonemapping with the tonemapper at linear; the speed claim of seams stays a hypothesis until AC-27.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Needs a GPU renderer (not `--headless`) and, for the playtest, a device. Desktop screenshots do not represent the device unless the Mobile renderer is forced. Pixel samples are in linear-tonemapped output.
**Control Manifest Rules (this layer)**:
- Required: `seam_contrast_scale` = 0 makes the seam surface match the tube; pixels at the far window edge at maximum fog within 1/255 of `fog_color`.
- Forbidden: fixing a failed playtest by making the seam louder (the GDD says the design leans on hazard rate, FOV and Juice instead).
- Guardrail: seam frequency at `v_max` at most 3 Hz; contrast within [1.15, 1.25].

## Acceptance Criteria
- [ ] **AC-26b** [V] On rendered pixels sampled at the ball's screen position at rest: seam/tube ratio is at least 1.15, hazard/seam at least 4:1, pickup/seam at least 3:1 (fog decay of seam visibility measured at the same point with fog on and off); with `seam_contrast_scale` = 0 the seam surface matches the tube; pixels at the far window edge at maximum fog are within 1/255 of `fog_color` (Haze Low on Map 1). Sampling at several tube angles including the darkest facet, tolerance +/- 2/255 per channel.
- [ ] **AC-27** [V] First-playable exit test on a device: 8 testers, 6 clip pairs per arm (seams on and off, 48 trials per arm), 6 s clips with hazards and the FOV effect in both arms, pair speeds differing by 20 percent, tester picks the faster. Pass: seams-on at least 36 of 48 and seams-on minus seams-off at least 6 of 48; both counts reported; add the question "what drew your eye first". ADVISORY: a fail keeps the speed claim a hypothesis.

## Implementation Notes
Capture frames with a debug-only screenshot route, sample with a small Python script under `tools/` (stdlib plus Pillow only if already approved; otherwise read PNG with Godot `Image` in an editor script). Record numbers in `production/qa/evidence/tube-seams-<date>.md` and the playtest in `production/qa/evidence/tube-seams-playtest-<date>.md` using the playtest-report template. Power is low (about 35-55 percent at the marginal effect); say so in the report. Palette values come from `environment-theming.md`.

## Out of Scope
- Story 012: palette smoke test (AC-26a)
- Story 013: R-1 fog verification and performance
- Juice & Feedback epic: flash-budget validation

## QA Test Cases
- **AC-26b**: Setup: Mobile renderer build, fixed camera at rest, seams on, `seam_contrast_scale` 1 and 0. Verify: sample ball-position pixels at five angles, seam vs tube, hazard vs seam, pickup vs seam, fog edge colour. Pass condition: all listed thresholds met; any miss is recorded with the number and raised to art-director.
- **AC-27**: Setup: 8 testers on a device with the clip pairs. Verify: correct picks per arm and the eye-draw question. Pass condition: both counts reported and the pass rule evaluated; failure is advisory.

## Test Evidence
**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/` screenshots plus the two documents named above, lead sign-off (art-director for AC-26b)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 012, Story 013
- Unlocks: Environment & Theming sign-off of seam values
