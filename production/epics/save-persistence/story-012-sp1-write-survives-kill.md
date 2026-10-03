# Story 012: SP-1 write survives a kill (device)

> **Epic**: Save & Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-010`, `TR-save-persistence-008` (rename semantics)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: The crash guarantee covers app-termination only, not power loss. SP-1 runs on a real Android device: kill the process at three points, at least 20 repetitions each, zero corrupted `save.cfg`. The Windows `rename_absolute` prerequisite check runs before any CI run of SP-1.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: NEEDS VERIFICATION: whether `DirAccess.rename_absolute` replaces an existing destination in one filesystem step on Android and on Windows (verification item 1). A delete-then-rename implementation opens a window with no `save.cfg`.
**Control Manifest Rules (this layer)**:
- Required: Windows prerequisite check first; device-first run; pre-committed response if rename is delete-then-rename: at boot, if `REAL` is missing and `TMP` parses and is compatible, promote `TMP` after the same checks (INFO log); if SP-1 still fails, adopt the A/B-slot scheme.
- Forbidden: weakening Rule 7's fail-safe-to-defaults; claiming power-loss safety.
- Guardrail: SP-3 runs in the same device session.

## Acceptance Criteria
- [ ] **SP-1 prerequisite** Windows (dev host) check recorded: does `rename_absolute` atomically replace an existing destination; same check on the Android device.
- [ ] **SP-1** Scripted `set_value` with kills before the temp write, mid-temp-write and between temp write and rename: at least 20 repetitions per kill point on a real Android target; after each, `save.cfg` is the old valid file or the new valid file, never partial, empty or holding an unwritten value. Pass: zero corrupted outcomes at every kill point. Fail: any repetition where the renamed `save.cfg` is unreadable, empty or wrong.
- [ ] Result recorded, with the pre-committed failure response named and applied if SP-1 fails.

## Implementation Notes
Add a debug-only harness scene under `prototypes/` or `tools/` (not `src/`) that writes in a loop and signals a kill point via a flag file; the kill is `adb shell am force-stop`. Count the three outcomes per repetition from a post-restart read. Designation status: proposed by creative-director, producer ratification pending (see `production/qa/designated-gates.md`); the story is BLOCKING on its Integration classification regardless. Gate: first-playable. Owner: godot-specialist.

## Out of Scope
- Story 013: latency (same session). Power-loss testing (not covered by the guarantee).

## QA Test Cases
- **Setup**: debug APK with the harness; device connected; prerequisite check done on Windows and device.
- **Verify**: 3 kill points x 20 repetitions; per repetition, boot and classify `save.cfg` as old-valid, new-valid or corrupt; log the `.tmp` state.
- **Pass condition**: 0 corrupt in 60+ repetitions.
- Edge cases: kill during the rename call; orphan `.tmp` cleaned on next write.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/save-persistence-sp1.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 009; cross-epic: an Android export preset and debug build (platform-services/composition-root)
- Unlocks: first-playable gate (blocking)
