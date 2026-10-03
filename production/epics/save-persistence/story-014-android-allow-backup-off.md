# Story 014: Android allowBackup disabled and manifest lint

> **Epic**: Save & Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0007
**Requirement**: `TR-save-persistence-001` (the file on disk is only ever one this build wrote)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation, Decision 7 (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: The export preset and merged manifest set `android:allowBackup="false"` so Auto Backup never restores an old or other-schema save or a half-written `.tmp`/`.corrupt-*` file. Cost accepted: the personal best does not follow the player to a new phone. The ADR-0006 manifest lint gains one assertion.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION (item 7): how the attribute is set is unknown (the template may already set it; the preset may have no key; a custom Gradle build template manifest edit is the likely route). Read the merged manifest of the first export before deciding. Also check whether Android 12+ data-extraction rules need a separate entry.
**Control Manifest Rules (this layer)**:
- Required: merged release manifest contains `android:allowBackup="false"`; the `manifest` lint rule covers it and Android 12+ data extraction.
- Forbidden: leaving `android:allowBackup` true.
- Guardrail: `export_presets.cfg` is committed in the same commit that removes it from `.gitignore`.

## Acceptance Criteria
- [ ] The merged release `AndroidManifest.xml` of the first export contains `android:allowBackup="false"` (verified with `aapt2 dump`), and the mechanism used (preset key or Gradle manifest edit) is recorded.
- [ ] Android 12+ data extraction is checked and any needed `dataExtractionRules`/`fullBackupContent` entry added.
- [ ] The `manifest` lint rule asserts `allowBackup=false` and has a passing and a failing fixture; it is skipped with a warning until the first preset exists.

## Implementation Notes
Depends on the first export preset existing (Platform Services/ADR-0006 work). If the preset has no key, add a manifest fragment in the Gradle build template and note it in ADR-0006's follow-up list. Keep the lint in `tools/ci/lint_rules.json` as kind `manifest`.

## Out of Scope
- Cloud save (GDD Open Question 6).
- Other manifest assertions (Vulkan, permissions): platform-services epic.

## QA Test Cases
- **Setup**: export a release AAB/APK with the first preset; dump the merged manifest.
- **Verify**: `allowBackup` attribute value; data extraction rules; lint output on the real and a tampered manifest.
- **Pass condition**: attribute is false in the merged manifest and the lint fails on the tampered fixture.
- Edge cases: debug build may differ; only release builds are linted.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/save-persistence-allow-backup.md` plus lint fixtures in `tools/ci/tests/`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 010; cross-epic: platform-services (first export preset)
- Unlocks: release candidate checks
