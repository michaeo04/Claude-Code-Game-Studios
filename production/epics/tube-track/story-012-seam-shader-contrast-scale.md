# Story 012: Seam shader band and per-frame seam_contrast_scale

> **Epic**: Tube Track
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-014`, `TR-tube-track-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0003: Renderer choice and tube render route (primary, Decision 2 and 6); ADR-0013: Distance precision and the render origin (shader world-z rule); ADR-0009: Test framework and CI (shader import check)
**ADR Decision Summary**: The seam is a segment-local analytic shader pattern, identical in every segment, with no per-frame `s` uniform. Tube Track pulls the Settings `seam_contrast_scale` getter every frame in every state and writes the material only when the value changed.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Shader preprocessor restrictions in 4.7 (no `#include`, only simple `#define`). MSAA does not smooth shader stripes: use `smoothstep` with `fwidth()`. Never read `TIME`. No `WORLD_POSITION`/`MODEL_MATRIX[3]` unless the period divides `REBASE_SEGMENTS * L`. SPIR-V compilation is verified on device only; `godot --headless --import` parses the shader in CI.
**Control Manifest Rules (this layer)**:
- Required: dynamic shared inputs on the tube material limited to `seam_contrast_scale`, the per-event progress uniforms, the two ADR-0012 global shader parameters and the near-miss ball-position uniform; `seam_contrast_scale` sampled every frame in every state and on `setting_changed`.
- Forbidden: `TIME` in `assets/shaders/**`; `#include`; texture uniforms for the seam; a per-frame `s` uniform; sampling the scale only at `load_map` or `begin_run`.
- Guardrail: seam flat band (normal tilt and albedo shift), no geometric relief; contrast band [1.15, 1.25] at scale 1, `L_seam_eff = L_tube + scale * (L_seam - L_tube)`.

## Acceptance Criteria
- [ ] **AC-23a** In Idle, then Paused, then Running, with the injected `seam_contrast_scale` getter switched between 1.0 and 0.0: the seam contrast written on the next view update is 1.0 and 0.0 respectively in each state, with no restart and no half-applied value; a mutation that samples only at `load_map` or `begin_run` fails; the material is written only on change.
- [ ] **AC-26a** (Config/Data smoke, ADVISORY, runs once a seam colour exists) the WCAG ratio of the seam colour to Mist Sage (#A9BFB0) is in [1.15, 1.25]; the seam is lighter than the tube; its luminance is below Haze Top (0.635 on Map 1); its chroma is at most 0.05; hazard/seam and ball/seam at least 4:1, pickup/seam at least 3:1. The ratio helper has its own test: white against black 21.0, equal colours 1.0 (+/- 1e-9).

## Implementation Notes
`assets/shaders/tube.gdshader` (spatial, unshaded or flat-lit per the Environment epic), seam position from the vertex/model-space z (segment-local), `SP`-periodic via `fract`/`mod` on the model-space coordinate and the `n_seams` uniform; contrast uniform `seam_contrast_scale`. The view exposes `set_seam_contrast_scale(v)` called by `GameRoot` every frame (the Settings getter is injected, not read by the view); it compares with the last written value and calls `set_shader_parameter` only on change. A small pure `ContrastMath` (WCAG ratio, relative luminance with the sRGB wrapper for authored `Color`) lives in `src/core/` for AC-26a. Palette values come from the Environment epic; this story uses the art bible constants as fixture data.

## Out of Scope
- Story 011: slots and mesh
- Story 014: pixel-level seam checks and the AC-27 playtest
- environment-theming epic: final colours and fog

## QA Test Cases
- **AC-23a**: every-frame sampling
  - Given: a view with a fake material recording writes and a mutable getter. When: in each of Idle, Paused, Running toggle the value and call the per-frame update. Then: recorded contrast 1.0/0.0 after the next update; no write when unchanged. Edge cases: value changed in Paused with no phase change; NaN/out-of-range clamps to [0, 1].
- **AC-26a**: palette smoke
  - Given: palette constants. When: compute ratios. Then: within the listed bounds. Edge cases: helper identity (white/black 21.0).

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tube_track/tube_seam_contrast_test.gd`; advisory `tests/advisory/tube_track/tube_seam_palette_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 011, Story 002 (F5)
- Unlocks: Story 013, Story 014
