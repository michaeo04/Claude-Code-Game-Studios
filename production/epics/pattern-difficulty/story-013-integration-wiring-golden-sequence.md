# Story 013: Integration wiring and golden-sequence test

> **Epic**: Pattern & Difficulty
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/pattern-difficulty.md` (AC-25, AC-26; Core Rules 3, 11)
**Requirement**: `TR-pattern-difficulty-003`, `TR-pattern-difficulty-015`, `TR-pattern-difficulty-016`, `TR-pattern-difficulty-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0008: Hazard, collision and content format (primary); ADR-0002: Game loop and Composition Root; ADR-0004: Map Loader and MapConfig (Phase B3 `Pattern.apply_map`)
**ADR Decision Summary**: `apply_map` is configuration only; Pattern reseeds on `run_reset` (rank 1) before Tube Track primes the window; Obstacle calls `hazards_for_segment` once per `segment_entered_window`, in increasing order. A golden-sequence unit test fixes the expected chunk order for a hardcoded seed list, reloads the library from disk, and runs once on an Android device build.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION (item 4): the seeded `RandomNumberGenerator` sequence matches between Android ARM64 and desktop; re-run the golden test on every engine upgrade. Typed Resource arrays round-trip in an export (items 1, 2).
**Control Manifest Rules (this layer)**:
- Required: Pattern wired in the composition root `_wire()` table, immediate connections only; `run_reset` rank 1 precedes rank 2 (Tube Track adapter and Obstacle); `Obstacle.test` then `NearMiss.step` after `TubeTrack.advance`.
- Forbidden: `CONNECT_DEFERRED`; autoload; Pattern calling Run State or Tube Track.
- Guardrail: per-call cost is a bag pop plus a short history check (TR-017: no explicit budget; record the measured per-call time in the evidence).

## Acceptance Criteria
- [ ] **AC-25** With the real `RunStateCore`, `run_reset(run_id)` reaches Pattern first among subscribers and `run_time` drives the tier; the same `run_id` replays the same chunk sequence.
- [ ] **AC-26** With the real Tube Track `SEGMENT_LENGTH` and the real Obstacle System, `hazards_for_segment` is called once per `segment_entered_window`, in increasing index order, never re-queried for an already-bound segment; hazards bound by Obstacle from the 8-chunk fixture match the chunk placement.
- [ ] **Golden sequence (ADR-0008 Decision 8)** the expected chunk order for a hardcoded seed list is fixed in a unit test that reloads the library from disk; the same list is run on an Android device build and the result recorded.

## Implementation Notes
Register `apply_map` in the map-loader Phase B3 seam and `on_run_reset` in `_wire()` (rank 1 with `WorldFrame`) if the composition-root epic has not done so; use `wire_spy` / `system_spy` from `tests/support/`. The golden sequence list is a constant under `tests/support/data/`. Padding is included in the integration only once Story 010 is unblocked; until then run with the zero-padding seam and mark the padded golden rows pending. The device run uses the evidence doc `production/qa/evidence/pattern-difficulty/golden-sequence-android.md` (spike-style: device model, build, expected vs observed order).

## Out of Scope
- Story 014: the real chunk library. Story 010: padding mechanics.

## QA Test Cases
- **AC-25**: Given: real Run State core, fixture library. When: runs reset with two `run_id`s. Then: Pattern first in the handler order, identical sequences for equal ids.
- **AC-26**: Given: real Tube Track and Obstacle windows. When: the window advances 20 segments. Then: one call per entered segment, ascending, none repeated.
- **Golden**: Given: seeds list. When: desktop and Android build run. Then: identical chunk order; mismatch fails and is recorded.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/pattern_difficulty/pattern_difficulty_wiring_test.gd` (AC-25, AC-26), `tests/unit/pattern_difficulty/pattern_difficulty_golden_sequence_test.gd`, and `production/qa/evidence/pattern-difficulty/golden-sequence-android.md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Stories 005, 006, 007, 009, 012; composition-root, run-state-restart, tube-track and obstacle-system epics (code exists)
- Unlocks: Story 014
