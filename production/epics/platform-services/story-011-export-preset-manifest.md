# Story 011: First Android export preset and merged-manifest verification

> **Epic**: Platform Services
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/platform-services.md` (Core Rule 8, AC-13 export part, Open Question 17)
**Requirement**: `TR-platform-services-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (Decisions 7, 8, 9; Validation Criteria)
**ADR Decision Summary**: Gradle build on, AAB for Play and APK for sideload, `arm64-v8a`, minSdk 28 and explicit target SDK, one Vulkan 1.1 `uses-feature` replacing Godot's default, accelerometer feature, `VIBRATE` only, portrait, immersive on, PiP off, no OBB, 16 KB alignment; keystore outside the repo.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: NEEDS VERIFICATION: preset key names (Gradle, AAB, min/target SDK, architectures, immersive, orientation, permissions); `uses-feature` keys; 4.7.2 templates 16 KB aligned; Godot 4.7 supports `minSdk 28`; `android:enableOnBackInvokedCallback` and how `android:allowBackup` is applied (ADR-0007). Record the verified key names in this story's evidence and update the Story 010 lint entries.
**Control Manifest Rules (this layer)**:
- Required: commit `export_presets.cfg` in the same commit that removes it from `.gitignore`; add `exclude_filter="tests/*, addons/gut/*, tools/*, build/*"`; exactly one Vulkan `uses-feature` (`0x401000`, required); permissions `VIBRATE` only; release builds linted on the merged manifest.
- Forbidden: default export with no manifest management; two Vulkan entries; `INTERNET`/storage in release; an OBB; a committed keystore, alias, password or debug keystore.
- Guardrail: minSdk 28, arm64-v8a only, 16 KB page alignment, target SDK 36 expected (confirm at release).

## Acceptance Criteria
- [ ] `export_presets.cfg` exists with the ADR-0006 Decision 8 settings and is committed with the `.gitignore` line removed in the same commit; no credentials in the file (signing sits in `.godot/export_credentials.cfg` or environment variables).
- [ ] The exported APK/AAB merged manifest declares only `VIBRATE`, one Vulkan 1.1 entry and the accelerometer feature; `zipalign -c -P 16` and an ELF alignment check on `.so` files pass; recorded with the `enableOnBackInvokedCallback` value.
- [ ] The Story 010 lint's preset part is now active and passes on the committed preset; its key names match the verified ones.
- [ ] Picture-in-Picture off is confirmed in the custom build template (feeds PS-5); how 4.7.2 exposes it is recorded.
- [ ] The verified Godot preset key names and any difference from the assumed ones are recorded in `production/qa/evidence/platform-services/export-preset.md`.

## Implementation Notes
Follow ADR-0006 Decision 8 verbatim: Gradle build on (custom build template), AAB and APK, `arm64-v8a`, min SDK 28 and target SDK set explicitly, portrait with `display/window/handheld/orientation = 1`, immersive on, PiP off, large screens restricted to phones in the Play Console (a release step, not a preset key). Replace Godot's default Vulkan 1.0 `uses-feature` rather than adding a second. Keep SDK values in the preset only. Release signing is outside the repository (Play App Signing with an upload key). Debug exports may add `INTERNET`; only release is linted for permissions.

## Out of Scope
- Story 010: lint implementation
- Story 015: PS-5/PS-6/PS-11 device checks
- CI Android export workflow (a later separate workflow, ADR-0009)

## QA Test Cases
- **Smoke check**: preset and merged manifest
  - Setup: Android build tools and JDK installed; run `python tools/ci/lint_runner.py` and export a release AAB/APK
  - Verify: merged manifest (via `aapt2 dump`), alignment checks, lint output
  - Pass condition: manifest contains only the permitted entries, alignment passes, lint green

## Test Evidence
**Story Type**: Config/Data
**Required evidence**: smoke check pass at `production/qa/smoke-[date].md` plus `production/qa/evidence/platform-services/export-preset.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 008, Story 010
- Unlocks: Stories 013, 014, 015, 016 (every device story needs an installable build)
