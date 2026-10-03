# Story 015: Real Platform Services wiring integration

> **Epic**: Save & Persistence
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-018`, `TR-save-persistence-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0006 (Android platform integration, `app_backgrounded`)
**ADR Decision Summary**: `PlatformServices` is built first, `SaveService` second and connects `app_backgrounded`; the flush stays small and synchronous. On Android `FOCUS_OUT` emits `app_interrupted` then `app_backgrounded`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Platform Services does not replay signals; `focus_implies_suspend` is true on Android. The PS-10 flush-time budget is measured by Platform Services' own device spike (GDD Open Question 3); no number is asserted here.
**Control Manifest Rules (this layer)**:
- Required: construction order `PlatformServices` then `SaveService`; the `app_backgrounded` handler runs on the main thread synchronously.
- Forbidden: `SaveService` calling back into Platform Services; replay assumptions.
- Guardrail: no autoload; wiring only through the composition root.

## Acceptance Criteria
- [ ] **AC-21 [I]** (deferred in the GDD until Platform Services' real node exists) A real `PlatformServices` node emits `app_backgrounded` on a simulated `NOTIFICATION_APPLICATION_FOCUS_OUT` and the real `SaveService` receives it exactly once per background transition; `app_foregrounded` and `app_returned` do not reach the persist path.
- [ ] The flush-time number from Platform Services PS-10 is referenced in the evidence when it exists; until then the test asserts only the call count, and the evidence states that no budget is asserted.

## Implementation Notes
Integration test builds the two real nodes in the ADR-0002 order inside a test scene (dummy renderer) and uses `notification(NOTIFICATION_APPLICATION_FOCUS_OUT)`. Uses a per-test temp directory for the save path. AC-22 (schema migration) is intentionally not covered: no migration exists at schema 1.

## Out of Scope
- Platform Services PS-10 device measurement (platform-services epic).
- Story 008: spy-based wiring.

## QA Test Cases
- **AC-21**: Given real `PlatformServices` and `SaveService` wired in order; When a focus-out then focus-in notification is delivered; Then `flush()` is invoked exactly once; Then no write occurs; Edge: two background transitions give two calls.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/save_persistence/save_persistence_platform_wiring_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 008, Story 009; cross-epic: platform-services (real `PlatformServices` node story)
- Unlocks: epic Definition of Done for AC-21
