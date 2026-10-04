# Story 008: Boot rendering-method check through an injected getter

> **Epic**: Composition Root & Game Loop
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: none, defined by ADR-0003
**Requirement**: `TR-composition-root-???` (ADR-0003 Decision 1; ADR-0002 Decision 4)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0003: Renderer choice and tube render route; secondary ADR-0002 (seam injection)
**ADR Decision Summary**: `GameRoot` checks `RenderingServer.get_current_rendering_method()` at boot through `rendering_method_getter: Callable` and refuses to run if the result is not `mobile`; headless test runs inject a fake so a CI test that builds `GameRoot` does not die.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `RenderingServer.get_current_rendering_method()` return values, and what the headless driver returns, are recorded by spike T-1 (test-harness-ci). 4.6 made D3D12 default on Windows: pin `rendering/rendering_device/driver.windows` to `"vulkan"`. A device without Vulkan never reaches the check (OpenGL fallback off; guard is the Play manifest, ADR-0006). Renderer changes need an editor restart.
**Control Manifest Rules (this layer)**:
- Required: `rendering/renderer/rendering_method="mobile"` and `rendering/renderer/rendering_method.mobile="mobile"`; `rendering/rendering_device/fallback_to_opengl3` off; `driver.windows="vulkan"`; the check is injected the same way as `clock_us`; rollback value is `rendering_method.mobile="forward_plus"` (changing only `rendering_method` does not affect Android).
- Forbidden: Compatibility (OpenGL); downgrading silently; calling `RenderingServer` directly from a Core.
- Guardrail: none beyond R-1 (owned by tube-track).

## Acceptance Criteria
- [ ] With the getter returning `"mobile"`, boot continues; with `"forward_plus"`, `"gl_compatibility"` or an empty string, boot is refused with a logged error and the loop never starts (ADR-0003 Decision 1)
- [ ] A test that builds `GameRoot` with an injected fake getter returning `"mobile"` runs headless without dying (Decision 1)
- [ ] The production binding wraps `RenderingServer.get_current_rendering_method()` and is bound in one place only (ADR-0002 Decision 4)
- [ ] `project.godot` carries `rendering_method="mobile"`, `rendering_method.mobile="mobile"`, `fallback_to_opengl3` false and `driver.windows="vulkan"`, asserted by a settings-file test (Decision 1)
- [ ] `RenderingServer.get_current_rendering_method()` reports `mobile` on every test device and a non-Vulkan device is blocked, not downgraded (ADR-0003 VC "reports mobile"; device row of the evidence doc)
- [ ] The value the headless driver returns is recorded from T-1 and the real-getter smoke test accepts or skips accordingly (Decision 1)

## Implementation Notes
Add `rendering_method_getter: Callable` to the `GameRoot` construction inputs beside `clock_us`; run the check first in `_construct()` (before any step that needs the renderer). Parse `project.godot` in the settings test as text (no ConfigFile on `res://` mocks needed: read via an injected path). `project.godot` is currently untracked in the repository: this story also owns committing the rendering keys. The device row is filled when the first Android export exists (platform-services epic).

## Out of Scope
- tube-track epic: gate R-1 and any Forward+ rollback
- platform-services epic: Vulkan `uses-feature` manifest entry

## QA Test Cases
- **AC-1/2**: getter values
  - Given: fake getter returning each value
  - When: boot check runs
  - Then: only `"mobile"` passes; refusal logs one error
  - Edge cases: getter not valid Callable refuses
- **AC-3**: single binding (grep-style test over `game_root.gd`)
- **AC-4**: settings keys
  - Given: `project.godot` text
  - When: parsed
  - Then: the four keys hold the pinned values
- **AC-5/6**: device and headless
  - Given: a release export on two makers; one headless run
  - When: the real getter is logged
  - Then: `mobile` on devices; headless value recorded in the evidence doc

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/composition_root/composition_root_rendering_seam_test.gd`; device row in `production/qa/evidence/composition-root-rendering-method-device.md`
**Evidence**: `tests/integration/composition_root/composition_root_rendering_seam_test.gd` (AC-1 to AC-4, AC-6 proven). **Gap**: AC-5 device row (`composition-root-rendering-method-device.md`) needs an Android export; story stays Ready.

## Dependencies
- Depends on: Story 001; test-harness-ci (spike T-1 result for the headless value)
- Unlocks: Story 010; tube-track R-1 gate
