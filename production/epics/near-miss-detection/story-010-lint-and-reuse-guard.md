# Story 010: Engine-coupling lint and reuse-not-reimplement guard

> **Epic**: Near-Miss Detection
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/near-miss-detection.md`
**Requirement**: `TR-near-miss-detection-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI; ADR-0008: Hazard, collision and content format
**ADR Decision Summary**: ADR-0009 drives a declarative rule table (`tools/ci/lint_rules.json`) with fixtures under `tools/ci/tests/fixtures/<safe_id>/{pass,fail}.txt`; ADR-0008 Decision 3 keeps one overlap implementation.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Add rules and fixtures via the lint runner; silence only through allow/exclude, never inline comments. Reuse the Obstacle epic's AC-24 regex family, scoped to `src/core/near_miss/`.
**Control Manifest Rules (this layer)**:
- Required: per-frame order `Obstacle.test`, then `NearMiss.step`, then `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step`; `NearMissMath` keeps the approved world-space float64 formulas on the flat footprint array with no offset arithmetic; cores are RefCounted with an injected `log_sink` (`LogLevel`, 4-argument sink)
- Forbidden: calling `Obstacle.test` after `NearMiss.step`; autoloads for game systems; `_process`/`_physics_process` outside `GameRoot`; `CONNECT_DEFERRED` on control signals; `CollisionObject3D`/`Area3D`/`RayCast3D` (ADR-0008)
- Guardrail: `Obstacle.test` plus `NearMiss.step` at most 0.4 ms per tick at the 192-piece worst case (spike OB-1, advisory until the first-playable profiling pass)

## Acceptance Criteria
- [ ] AC-21 [L]: over `NearMissMath`, `NearMissCore`, `NearMissConfig` and transitive dependencies none contains `CollisionObject3D`, `CharacterBody3D`, `Area3D`, `RayCast3D`, `ShapeCast3D`, `PhysicsServer`, `Input.`, `Engine.`, `Time.`, `OS.`, `DisplayServer.`, `get_tree`, `_process`, `_physics_process`, `randi`, `randf`, `randi_range`, `randf_range`, `randomize`, `seed(`, `RandomNumberGenerator`; code-review sign-off is required evidence in the story record (heuristic scan).
- [ ] AC-22 [L]: (a) static scan: `NearMissMath` has no second definition of `arc_overlap` or of a function matching `ObstacleMath` F2's signature shape, it calls into `ObstacleMath` (code-review sign-off required); (b) behavioral parity: every AC-3 to AC-6 pose gives identical booleans from `ObstacleMath` and from `NearMissCore`'s `HIT_ZONE` (evidence of parity, not proof of reuse).

## Implementation Notes
- Lint fixtures: one pass and one fail text per new rule, with the `#@path:` first line. The parity test iterates the same pose table as Story 003 (share it from `tests/support/`).

## Out of Scope
- Story 003: the poses' own assertions.

## QA Test Cases
- **AC-21**: see criterion above
  - Given: lint runner over `src/core/near_miss/`
  - When: `python tools/ci/run_ci.py`
  - Then: no hit; the fail fixture triggers the rule
  - Edge cases: note the acknowledged heuristic limit
- **AC-22**: see criterion above
  - Given: scan plus parity test
  - When: run
  - Then: no second `arc_overlap`; parity on every pose
  - Edge cases: reviewer sign-off recorded

## Test Evidence
**Story Type**: Logic
**Required evidence**: tests/unit/near_miss_detection/near_miss_detection_lint_parity_test.gd (plus lint fixtures under tools/ci/tests/fixtures/)
**Evidence**: tests/unit/near_miss_detection/near_miss_detection_lint_parity_test.gd (AC-22b parity, pose table tests/support/near_miss_pose_table.gd); lint rules forbidden:near_miss_core_purity (AC-21) and forbidden:near_miss_second_arc_overlap (AC-22a) with pass/fail fixtures under tools/ci/tests/fixtures/. Heuristic scan limit acknowledged; the code-review sign-off is still to be recorded by /code-review.
**Status**: [x] Created, passing

## Dependencies
- Depends on: Stories 003, 005
- Unlocks: None

> **Reopened 2026-10-05**: AC-21 and AC-22a require a recorded code-review sign-off, which does not exist yet (the 2026-10-04 review covered only the modules that existed then). Lint and parity tests pass. Close this story when the sign-off is recorded in `production/qa/` (owner-actions C7).
