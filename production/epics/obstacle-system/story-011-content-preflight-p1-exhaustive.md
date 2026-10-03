# Story 011: ContentPreflight P1, exhaustive and deterministic

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/obstacle-system.md` (Edge Cases "When validation actually runs"; AC-32, AC-37)
**Requirement**: `TR-obstacle-system-012`, `TR-obstacle-system-013`, `TR-obstacle-system-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (Decision 5); ADR-0009: Test framework and CI (secondary)
**ADR Decision Summary**: `ContentPreflight` is a pure `RefCounted` in `src/` composing the `ObstacleMath` / `PatternMath` / `NearMissMath` validators and the real sequencer. It returns every violation as `{code, chunk_id, other_chunk_id, detail}` in a deterministic order, never a partial application. P1 checks each chunk alone.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION (ADR-0008 items 5, 9): run headless via `godot --headless --script ...` after `--import`, and as an `EditorScript`; in the editor a non-`@tool` Resource loads as a placeholder, so the `EditorScript` reads the authored classes as data only.
**Control Manifest Rules (this layer)**:
- Required: exhaustive, deterministic, structured records; `run(library, cfg: ContentPreflightConfig) -> Array[Dictionary]`; in debug builds the full preflight also runs at map load as an assertion.
- Forbidden: running the full preflight (P1 to P3) on the device in a release build; fail-fast; unordered traversal.
- Guardrail: preflight is offline (CI, editor, debug build).

## Acceptance Criteria
- [ ] **AC-32 [K]** one fixture engineered to fail `FOOTPRINT_INVALID_ORDER` (a piece with `s_end < s_start`) and `NO_SAFE_GAP` elsewhere reports both records in one call; a stop-at-first mutation fails.
- [ ] **AC-37 [K]** the AC-32 fixture run twice independently reports identical records (same codes, `s0` / piece-set values, order); a non-deterministic-iteration mutation fails.
- [ ] `ContentPreflight.run` P1 composes the Story 003 to 006 validators over every chunk, plus the new `SOLUTION_NOT_IN_GAP` (a stored `solution_angles` entry outside every safe gap).
- [ ] An `EditorScript` entry prints the records so a designer can check a chunk while authoring.

## Implementation Notes
P1 code list (ADR-0008): `FOOTPRINT_NOT_FINITE`, `FOOTPRINT_INVALID_ORDER`, `FOOTPRINT_TOO_WIDE`, `FOOTPRINT_EFF_TOO_WIDE`, `HOME_SEGMENT_MISMATCH`, `NO_SAFE_GAP`, `TOO_MANY_PIECES`, `TOO_DENSE`, `HAZARD_OVERLAP`, `HIDDEN_CONTENT_FORBIDDEN`, `EXIT_BEYOND_VISIBLE_ARC`, `HIDDEN_UNFAIR`, `SWEEP_INVARIANT_VIOLATED`, `NEAR_ZONE_OVERLAP`, `DODGE_RECOVERY_VIOLATION` (within the chunk), `GRACE_ZONE_VIOLATION`, `SOLUTION_NOT_IN_GAP`. `NEAR_ZONE_OVERLAP` and `DODGE_RECOVERY_VIOLATION` come from the near-miss-detection and pattern-difficulty epics; compose them when those validators exist and note the gap in the story record. The live `hazards_for_segment` may re-run the checks only as a debug assertion and never rejects mid-run (TR-013). `ContentPreflightConfig` is data-driven.

## Out of Scope
- Story 012: P2, P3 and the blocking CI test over `chunk_library_01.tres`.
- Real chunk authoring; the footprint debug overlay (Story 015).

## QA Test Cases
- **AC-32**: Given the two-failure fixture built with `.new()`. When `run` executes. Then the result contains both codes with structured detail.
- **AC-37**: Given the same fixture run twice. Then `result_a == result_b` element by element, order included.
  - Edge cases: two violations at the same `s0` keep a stable order (sorted by chunk id, then code).
- **SOLUTION_NOT_IN_GAP**: Given a stored angle inside an occupied arc. Then one record names the chunk and angle.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/obstacle_system/obstacle_system_preflight_p1_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 001, 004, 005, 006
- Unlocks: Story 012, Story 015 (authoring), pattern-difficulty epic
