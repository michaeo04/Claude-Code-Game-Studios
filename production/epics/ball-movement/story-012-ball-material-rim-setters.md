# Story 012: Ball material, fresnel rim, BallStyle and the three BallView setters

> **Epic**: Ball Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/ball-movement.md` (Visual/Audio Requirements)
**Requirement**: `TR-ball-movement-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0012: Ball material and world chroma (primary); ADR-0010: Presentation time (`set_ball_visible` is JuiceView's sink)
**ADR Decision Summary**: `BallView` owns the ball's one `ShaderMaterial` (`ball.gdshader`): unshaded, opaque, depth fog on, uniform `albedo` with luminance exactly `L_ball`, cool-white fresnel rim. Two single-purpose setters (`set_luminance_target` for Environment, `set_rim_glow` for Juice) plus `set_ball_visible` for Juice; none writes unless the value changed.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0012 NEEDS VERIFICATION (device, gate R-1): items 4 (unshaded ball plus fresnel renders `L_ball` after tonemap), 10 (additive terms on `unshaded` go through `ALBEDO`), 11 (depth fog applies to the unshaded ball on Mobile), 12 (luminance measured at the disc centre), 13 (globals only in `fragment()`), 15 (round sphere). Do not name the method `set_visible`. No `#include` in shaders (4.7 preprocessor restrictions).
**Control Manifest Rules (this layer)**:
- Required: `BallStyle` is a scalar-only Resource (`assets/data/ball_style.tres`: `base_color`, `rim_color`, `edge_color`, `rim_power`, `rim_strength`, `rim_glow_max`, `roll_scale`, `lean_max`), validated; `BallMath.albedo_for_luminance(base, l_base, l_target)` returns its input unchanged when `l_target == l_base`; `base_luminance()` is `ChromaMath.luma_srgb(style.base_color)`.
- Forbidden: a lit ball; a chroma or grey uniform on the ball; Environment writing the material directly; `BallView.tick` or Environment writing `visible`; any shader declaring `world_chroma`/`hit_grey` for the ball.
- Guardrail: 1 draw call (allocation 4); setters write only on change.

## Acceptance Criteria
- [ ] (Unit) `BallMath.albedo_for_luminance` hits the target luminance and is bit-identical when `l_target == l_base`; Environment F3 fixtures (0.0421 and the toggle-off identity) pass through `BallView.set_luminance_target` with a fake material sink.
- [ ] (Unit/Integration) `set_luminance_target`, `set_rim_glow` (v in [0, 1]) and `set_ball_visible` write only on change; `run_reset` restores `visible` true; no other path writes visibility; `ball.gdshader` declares neither global.
- [ ] (Visual/Feel) Screenshot evidence: resting cool-white rim and the near-miss/glow rim, ball body reads as a smooth sphere (art bible: only solid sphere, rim kept, no warm hue); ball chroma 0.08-0.12 and contrast at least 4:1 against the tube (art bible Numbers).

## Implementation Notes
Files: `assets/shaders/ball/ball.gdshader`, `assets/data/ball_style.tres`, additions to `ball_view.gd` and `ball_math.gd` (note: `albedo_for_luminance` lives on `BallMath` per ADR-0012; the Story 009 BallMath lint applies to it, so no `const` containers). Rim: `pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power)` mixed toward `rim_color` at `rim_strength`; `rim_glow` raises strength and adds `edge_color` in the outer band on the same term. Setters are injected to Environment/Juice as Callable seams (`ball_luminance_sink`, `rim_glow_sink`). Evidence: art-director review of the rim (ADR-0012 Risks).

## Out of Scope
- Story 013: device checks 1-6/8-15 of R-1 beyond the ball screenshots
- Environment and Juice cores that call the setters (their epics)
- Skin patterns

## QA Test Cases
- **Setter behaviour (logic part)**
  - Given: fake material sink recording writes
  - When: each setter is called twice with the same value, then a different one
  - Then: one write per distinct value; visibility true after `run_reset`
  - Edge cases: `rim_glow` outside [0,1] clamped
- **Visual**: Setup: device build, ball at rest and during a near-miss glow, one screenshot each. Verify: rim visible, body flat-coloured, silhouette unchanged by glow. Pass condition: art director sign-off, luminance at the disc centre equals `L_ball` within the R-1 tolerance.

## Test Evidence
**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/ball-movement/ball-view-rim.md` with screenshots and art-director sign-off, plus `tests/unit/ball_movement/ball_movement_view_math_test.gd` for the logic part
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 011; gate R-1 (device)
- Unlocks: environment-theming and juice-feedback epics (setters); Story 013
