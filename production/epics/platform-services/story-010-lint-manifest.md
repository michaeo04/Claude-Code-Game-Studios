# Story 010: CI manifest lint for project.godot and export preset (AC-13)

> **Epic**: Platform Services
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/platform-services.md`
**Requirement**: `TR-platform-services-014`, `TR-platform-services-015`, `TR-platform-services-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (Decision 9); ADR-0009: Test framework and CI (Decision 5: `project_setting` and `manifest` rules)
**ADR Decision Summary**: CI lints `project.godot` and, once it exists, `export_presets.cfg` against the `PlatformSettings` data entries; for release builds it also reads the merged `AndroidManifest.xml`. Until the first preset exists the preset part is skipped with a loud warning.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Export preset key names (`permissions/vibrate`, immersive mode, Picture-in-Picture, `android:enableOnBackInvokedCallback`) are NEEDS VERIFICATION until the first preset exists (Story 011). Existing rules `project_setting:quit_on_go_back`, `project_setting:handheld_orientation`, `manifest:*`, `forbidden:duplicate_vulkan_uses_feature`, `forbidden:internet_permission_in_release` are already registered; extend and unify rather than duplicate.
**Control Manifest Rules (this layer)**:
- Required: a missing key fails (defaults are orientation 0, `quit_on_go_back` true, `max_fps` 0, sensors off); release lint reads the merged manifest (`aapt2 dump`), permissions linted for release builds only; the skip is BLOCKING from the first Android build.
- Forbidden: lints in GDScript or shell; inline ignore comments; `INTERNET`/storage permissions in release.
- Guardrail: INI sections matter (a right key in the wrong section fails).

## Acceptance Criteria
- [ ] **AC-13 [L]** Manifest lint (`tools/ci/` Python, driven by `PlatformSettings` entries: section, key, expected, owner tag). A missing key fails. By INI section: `[display]` `window/handheld/orientation` = 1; `[application]` `config/quit_on_go_back` = false and `run/max_fps` = 60; `[input_devices]` `sensors/enable_gravity` = true (and the ADR-0005 touch-emulation keys; no `enable_accelerometer`); `export_presets.cfg`: each Android preset has `permissions/vibrate=true`, immersive mode on and Picture-in-Picture off (key names confirmed at the first preset). Self-test: each entry x {missing, wrong} = 2 x manifest length failures, a right key in the wrong section fails, a valid file passes. Export checks are skipped with a loud warning while no preset exists, and an Android export run with no preset fails; the skip is BLOCKING from the first Android build. Tilt Input AC-37d delegates to this script for entries tagged `tilt`.

## Implementation Notes
Read the same entries as Story 007 (a shared data file, e.g. JSON under `tools/ci/` or the manifest resource) so the lint and the boot check cannot drift. Parse `project.godot` and `export_presets.cfg` with stdlib `configparser`-style handling tolerant of Godot's `key=value` syntax. `max_fps` and `quit_on_go_back` entries here must agree with the already-registered `project_setting` rules. The release-only merged-manifest part (single Vulkan 1.1 entry `0x401000`, accelerometer feature, `VIBRATE` only, `enableOnBackInvokedCallback` value) is activated by Story 011; implement it as a rule that skips with a warning when no AAB/APK is supplied.

## Out of Scope
- Story 011: creating the first preset and confirming key names
- Story 007: runtime `mismatches` at boot
- Tilt Input's own `steer_left`/`steer_right` action check

## QA Test Cases
- **AC-13**: manifest lint
  - Given: fixture `project.godot` files (valid, each entry missing, each entry wrong, right key in wrong section) and no preset
  - When: the lint runs
  - Then: a valid file passes; 2 x manifest length fixtures fail with key and file; preset checks skip with a loud warning; running with `--android-export` and no preset fails
  - Edge cases: a preset present with `permissions/vibrate=false` fails; keys tagged `tilt` are reported under that owner

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tools/ci/tests/` unittest fixtures (passing and failing per entry); run by `python tools/ci/run_ci.py --only lint`
**Evidence (partial)**: `tools/ci/tests/test_lint_platform_rules.py` (ManifestLintTest). Gap: `emulate_mouse_from_touch` stays optional in the registered ADR-0005 rule (an existing unit test requires that), so a missing key for it does not fail; export-preset key names are unverified (owner-actions E14).

## Dependencies
- Depends on: Story 007; test-harness-ci lint runner stories
- Unlocks: Story 011 (activates the preset checks)
