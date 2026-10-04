# Story 010: CI lints: identifier, deny-list and typed-binding scans

> **Epic**: Scoring & Personal Best
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/scoring-personal-best.md`
**Requirement**: `TR-scoring-personal-best-015`, `TR-scoring-personal-best-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: Lint rules live in `tools/ci/lint_rules.json` (`project_setting`, regex and `custom` rule kinds) and run in the CI lint job via `python tools/ci/run_ci.py`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Scans read source text, not unit-test state; tokenize so comments (`#`, `##`) and string literals are skipped. No engine API risk.
**Control Manifest Rules (this layer)**:
- Required: Scoring is built early (RunStateCore and ScoreService, construction emits nothing), connects before Run State emits, and is not an autoload (ADR-0002 Decision 5); per-frame order `Obstacle.test`, `NearMiss.step`, `Scoring.step`, after `TubeTrack.advance` and `WorldFrame step` (ADR-0002 Decision 6); `run_ended` rank: Juice; Scoring; HUD; the rest, and `run_abandoned`: Juice; Scoring; the rest (ADR-0002 Decision 7)
- Forbidden: Never make Scoring an autoload; no `_process`/`_physics_process` outside `GameRoot`; no `CONNECT_DEFERRED` on control signals; no `Engine.time_scale` or `SceneTree.paused`
- Guardrail: 60 FPS / 16.6 ms frame; the death frame carries Juice, Scoring, HUD freeze and the save write in one tick (ADR-0007 Decision 5, spike SP-3 budget p95 <= 3 ms)

## Acceptance Criteria
- [ ] **AC-10** (ADVISORY lint) Identifier-only scan of `score_math.gd` and `score_core.gd` finds zero `near_miss`, `NearMiss` or `NearMissDetection`-shaped identifiers, skipping comments and string literals; `hazard_id` is NOT flagged; a companion check confirms `hazard_id` is a parameter of `on_run_ended` but never read inside either ending handler body.
- [ ] **AC-12b** (ADVISORY lint) Zero references in `ScoreCore` and `ScoreMath` method bodies to any `[autoload]`-registered class name or to the deny-list `Engine.`, `OS.`, `ProjectSettings`, `FileAccess`, `get_tree`, `get_node`; an injected unrelated side effect must fail it.
- [ ] **AC-11a typed-binding row** (ADVISORY lint, needs the composition root) The composition root builds each of the three seams from a direct method reference (`obj.method`), never `Callable(obj, "name")` with a string-built name.

## Implementation Notes
- Add the rules to `tools/ci/lint_rules.json` following the existing entries; the BLOCKING `[autoload]` check for `ScoreService`/`ScoreCore` is delivered in story 009 and only referenced here.
- Prove each rule with a unit test that feeds good and mutated source fixtures (strings or fixture files under `tests/`), so the lint is itself tested; a comment such as `## Rule 8: near_miss events are never consumed here.` must NOT trigger AC-10.
- Rule list lives in `docs/registry/architecture.yaml` `forbidden_patterns` (ADR-0009); keep both in step if a new pattern is added.

## Out of Scope
- Story 009: the blocking autoload lint. Story 008: the reflection-based surface check.

## QA Test Cases
- **AC-10**: identifier scan
  - Given: clean source and mutated copies (near-miss parameter, near-miss method, near-miss only in a comment)
  - When: the lint runs on each
  - Then: only the code-identifier mutations fail
  - Edge cases: `hazard_id` and string literals never flagged
- **AC-12b**: deny-list scan
  - Given: clean source and a copy calling `OS.get_ticks_msec()` or an autoload name
  - When: the lint runs
  - Then: the mutated copy fails
  - Edge cases: `Time.` and `Vector3.` stay legal
- **AC-11a typed binding**: composition-root scan
  - Given: the composition root source and a copy using `Callable(save, "get_value")`
  - When: the lint runs
  - Then: only the string-built copy fails
  - Edge cases: none

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/scoring_personal_best/scoring_personal_best_lint_rules_test.gd` and a clean `python tools/ci/run_ci.py` lint run
**Evidence**: `tools/ci/tests/test_lint_scoring_rules.py` (good and mutated sources for AC-10, AC-12b, AC-11a; run by run_ci step 4a) and four new rules with pass/fail fixtures; clean lint run. Deviation: Python unit test instead of a GUT file, matching the existing lint-rule tests.

## Dependencies
- Depends on: Story 008; story 011 for the typed-binding row
- Unlocks: None
