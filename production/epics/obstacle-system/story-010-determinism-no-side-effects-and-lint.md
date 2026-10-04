# Story 010: Determinism, no side effects and the engine-coupling lint

> **Epic**: Obstacle System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/obstacle-system.md` (Core Rules 6, 9; AC-23, AC-24, AC-39)
**Requirement**: `TR-obstacle-system-018`, `TR-obstacle-system-019`, `TR-obstacle-system-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (Decision 5 lint framework); ADR-0008: Hazard, collision and content format (Validation lint); ADR-0002 (secondary)
**ADR Decision Summary**: Lints are declarative rules in `tools/ci/lint_rules.json` run by `tools/ci/lint_runner.py` (Python 3 stdlib), each with a passing and a failing fixture; GDScript is scanned after comments and strings are stripped.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Lint rules are regexes over stripped text, not a parser; a determined obfuscation (`load()` / `ClassDB.instantiate()` from a string, `Callable` indirection) can evade them, so code review stays the second line.
**Control Manifest Rules (this layer)**:
- Required: no randomness and no static shared state in the core; lint rules have an owner file, fixtures and severity; the runner self-check fails a rule without both fixtures.
- Forbidden: `CollisionObject3D`, `Area3D`, `RayCast3D`, `PhysicsServer`, `duplicate_deep`, `Vector4` in hazard code; inline lint-ignore comments (use an explicit allowlist field).
- Guardrail: CI full run at most 5 minutes with a warm cache.

## Acceptance Criteria
- [ ] **AC-23 [C]** two fresh `ObstacleCore` instances fed an identical 500-tick script (window signals interleaved with ball ticks, resets, no-ops, hits) produce bit-identical `hit_reported` streams (ids, order, tick indices); a third interleaved instance changes neither stream.
- [ ] **AC-39 [C]** doubles for Ball Movement and Tube Track record every call; replayed over the AC-16 / AC-19 / AC-20 / AC-21 / AC-23 scripts, neither receives anything beyond the named read-only accessors and inbound signals; no mutating method is ever invoked.
- [ ] **AC-24 [L]** lint over `ObstacleMath`, `ObstacleCore`, `ObstacleConfig` and their transitive dependencies bans `CollisionObject3D`, `CharacterBody3D`, `Area3D`, `RayCast3D`, `ShapeCast3D`, `PhysicsServer`, `Input.`, `Engine.`, `Time.`, `OS.`, `DisplayServer.`, `get_tree`, `_process`, `_physics_process`, `randi`, `randf`, `randi_range`, `randf_range`, `randomize`, `seed(`, `RandomNumberGenerator`, plus the raw-world-Z regex (`position.z`, `global_position.z`, `global_transform.origin`). A recorded code-review sign-off in the story record is required evidence.

## Implementation Notes
Register the AC-24 rule in `lint_rules.json` with scope globs over the three files and their imports; add one passing and one failing fixture and a Python `unittest` case under `tools/ci/tests/`. The GDD names the limit explicitly: a heuristic scan, paired with code review. Add the ADR-0008 hazard-code bans (`duplicate_deep`, `Vector4`) as a separate rule if not already registered by another epic (check first; do not duplicate). Determinism: no `RandomNumberGenerator`, ordered containers only, instance fields only.

## Out of Scope
- Story 009 behaviour; Story 011 preflight determinism (AC-37).
- Pattern's PRNG lints (Pattern epic).

## QA Test Cases
- **AC-23**: Given a seeded scripted sequence (hardcoded, no randomness). When two (then three) instances run. Then streams are equal element by element.
- **AC-39**: Given recording doubles. When the scripts replay. Then the recorded call list is a subset of the allowed accessors.
- **AC-24**: Given fixture files containing each banned token and a clean file. When `lint_runner.py --rule <id>` runs. Then failing fixture reports each token, passing fixture is clean, real scope is clean.
  - Edge cases: banned token inside a comment or string is not flagged (stripper).

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/obstacle_system/obstacle_system_determinism_test.gd` (AC-23, AC-39); lint rule + fixtures in `tools/ci/` (AC-24) with a recorded code-review sign-off
**Evidence (partial)**: `tests/unit/obstacle_system/obstacle_system_determinism_test.gd` (AC-23, AC-39 passing); lint rule `forbidden:obstacle_core_purity` with fixtures in `tools/ci/`. Gap: AC-24 needs the recorded code-review sign-off, not yet given.

## Dependencies
- Depends on: Stories 007, 008, 009; test-harness-ci epic (lint runner)
- Unlocks: Story 013
