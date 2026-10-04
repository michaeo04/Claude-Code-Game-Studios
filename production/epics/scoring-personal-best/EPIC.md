# Epic: Scoring & Personal Best

> **Layer**: Feature
> **GDD**: design/gdd/scoring-personal-best.md
> **Architecture Module**: Scoring & Personal Best
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 13 stories (see table)

## Overview

Scoring & Personal Best owns `current_score = floori(s)`, the personal best, `personal_best_updated`, `personal_best_passed` and `milestone_crossed`. It writes the best synchronously inside its `run_ended` handler through Save & Persistence (ADR-0007) and finalizes before the HUD reads the score (subscriber order, ADR-0002).

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0002: Game loop, Composition Root and tick order | This ADR makes one scene-root node, `GameRoot`, the Composition Root and the **only** node that runs a per-frame `_process`; it calls every system in one fixed order, builds them in one fixed order, and registers the... | Accepted | LOW |
| ADR-0007: Persistence implementation | This ADR keeps the GDD's format and write protocol, replaces the eight loose seams with **one `SaveFs` facade plus three Callables**, adds the file-size and backup-listing operations the GDD already requires, keeps th... | Accepted | MEDIUM |
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |

**Engine risk of the epic: MEDIUM** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

20 requirements registered for this system: 5 covered by an ADR, 1 partial, 0 gap, 14 GDD-owned (specified fully by the GDD, no ADR needed).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-scoring-personal-best-001 | Logic is split into static `ScoreMath` (`score(s)`, `is_new_best`), `ScoreCore` (RefCounted), and the `ScoreService` driver node (no autoload). | GDD-owned |
| TR-scoring-personal-best-002 | `ScoreCore.new(s_seam, get_value_seam, set_value_seam, milestone_distances: Array[int])` takes three Callable seams plus one data array. The static `validate_seams(s,g,s2)->bool` uses `Callable.is_valid()`; `_init` asserts it (... | GDD-owned |
| TR-scoring-personal-best-003 | The public surface is exactly six non-underscore methods: `step()`, `on_run_reset()`, `on_run_ended(run_id,hazard_id,run_time_ms)`, `on_run_abandoned(run_id,run_time_ms)`, `get_current_score()`, `get_personal_best()`. Getters a... | ADR-0009 ⚠️ Partial |
| TR-scoring-personal-best-004 | `current_score = floori(s)` (an int), recomputed from `s` each `step()`, never accumulated. It is monotone non-decreasing and frozen automatically when `s` is frozen (no phase argument). | GDD-owned |
| TR-scoring-personal-best-005 | `step()` guard order is `is_finite(s) and s>=0.0 and s<=9.2e18`, then `floori(s)`, then hold if `floori(s) < current_score`. Check before converting, never after. A violation holds `current_score`. There is no separate `last_s`... | GDD-owned |
| TR-scoring-personal-best-006 | `on_run_reset()` zeroes `current_score`, the `has_passed_this_run` latch and `next_milestone_index` synchronously. It is non-deferred and runs before `run_started`. | GDD-owned |
| TR-scoring-personal-best-007 | `run_ended` and `run_abandoned` finalize identically, from the stored `current_score` (not re-read `s`; `hazard_id` and `run_time_ms` ignored). `is_new_best = final_score > personal_best` (strict, tie is false). A duplicate end... | GDD-owned |
| TR-scoring-personal-best-008 | The only persistence is `[scoring].personal_best` in `save.cfg` via Save & Persistence. It is read once at construction (`get_value("scoring","personal_best",0)`, coerced to int, clamped `max(0,...)`, an oversized value deliber... | ADR-0007 ✅ Covered |
| TR-scoring-personal-best-009 | `personal_best_updated(final_score)` fires once, after the in-memory best is updated and synchronously inside the `run_ended`/`run_abandoned` handler. | GDD-owned |
| TR-scoring-personal-best-010 | `personal_best_passed(personal_best)` fires once per run on the first tick `current_score > personal_best` (strict), never while in-memory `personal_best==0`, and re-arms on reset. | GDD-owned |
| TR-scoring-personal-best-011 | `milestone_crossed(threshold)` uses an index latch with a `while` loop, so several thresholds can fire in one `step()` in ascending order. An empty array disables it. | GDD-owned |
| TR-scoring-personal-best-012 | `ScoringConfig` Resource (`@export var milestone_distances: Array[int]`). A pure `validate_milestones(Array)->Array[String]` rejects non-ascending, duplicate, non-positive and non-integer entries. The composition root refuses t... | GDD-owned |
| TR-scoring-personal-best-013 | `ScoreService.step()` runs once per tick strictly after Ball Movement's step, using the same callback type (`_physics_process` vs `_process` must match). Run State emits the ending and forces that tick's `dt_eff` to 0. `final_s... | ADR-0002 ✅ Covered |
| TR-scoring-personal-best-014 | `ScoreService` connects at composition-root construction, before Run State's first emit (Godot drops signals emitted before `connect()`), and is registered per Run State's pinned order. | ADR-0002 ✅ Covered |
| TR-scoring-personal-best-015 | Scoring never reads `near_miss_detected`. There is no near-miss-shaped constructor parameter, method or identifier. | GDD-owned |
| TR-scoring-personal-best-016 | No side effects beyond the one `set_value`. The only seam calls are one `s_seam` read per `step()` (none from reset or ending handlers), one `get_value` at construction, and `set_value` on a new best. | GDD-owned |
| TR-scoring-personal-best-017 | Determinism: no randomness; identical scripts and starting best give bit-identical sequences and verdicts. | GDD-owned |
| TR-scoring-personal-best-018 | Fixtures: `PERSONAL_BEST_FIXTURE_DEFAULT`=500, `make_s_stub` (index in a member, because GDScript closures capture primitives by value), `make_save_stub(initial_best, write_succeeds)`, `make_signal_log`, `make_fake_run_state`,... | GDD-owned |
| TR-scoring-personal-best-019 | CI lints. BLOCKING: no `[autoload]` entry for `ScoreService`/`ScoreCore`. ADVISORY: identifier-only near-miss scan (skips comments and strings), deny-list scan (`Engine.`, `OS.`, `ProjectSettings`, `FileAccess`, `get_tree`, `ge... | ADR-0009 ✅ Covered |
| TR-scoring-personal-best-020 | Integration, BLOCKING at first-playable (owner user): AC-21 real SaveCore round trip including cold-boot-reverts-a-failed-write, AC-22 real Ball Movement + Run State, AC-26 pinned `run_ended` order (Juice handler, then Scoring,... | ADR-0009 ✅ Covered |

**Partial or gap requirements:** stories for these carry the open point named in `docs/architecture/architecture-traceability.md` (Partial Coverage) and are marked Blocked until it is closed.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/scoring-personal-best.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [ScoreMath: floor score and strict new-best comparison](story-001-score-math.md) | Logic | Complete | ADR-0002, ADR-0009 |
| 002 | [ScoreCore construction, seams, boot read and accessors](story-002-score-core-construction.md) | Logic | Complete | ADR-0007 |
| 003 | [step(): live score, frozen score and run reset](story-003-step-live-frozen-reset.md) | Logic | Complete | ADR-0002 |
| 004 | [step(): non-finite, negative, over-range and decreasing s](story-004-out-of-contract-s-guards.md) | Logic | Complete | ADR-0002 |
| 005 | [Run endings: finalize, new-best write and personal_best_updated](story-005-run-endings-and-personal-best-write.md) | Logic | Complete | ADR-0007 |
| 006 | [personal_best_passed: once-per-run live crossing](story-006-personal-best-passed.md) | Logic | Complete | ADR-0002 |
| 007 | [milestone_crossed, ScoringConfig and validate_milestones](story-007-milestones-and-scoring-config.md) | Logic | Complete | ADR-0002 |
| 008 | [Public surface, determinism and no side effects](story-008-surface-determinism-no-side-effects.md) | Logic | Complete | ADR-0009 |
| 009 | [ScoreService driver and Run State wiring against a fake source](story-009-score-service-driver.md) | Logic | Complete | ADR-0002 |
| 010 | [CI lints: identifier, deny-list and typed-binding scans](story-010-ci-lints.md) | Logic | Complete | ADR-0009 |
| 011 | [Composition Root: construct, wire rows, tick call and milestone preflight](story-011-composition-root-wiring.md) | Integration | Complete | ADR-0002 |
| 012 | [Integration: real SaveCore round trip (AC-21)](story-012-real-save-round-trip.md) | Integration | Ready | ADR-0007 |
| 013 | [Integration: real Ball Movement and Run State lifecycle (AC-22, AC-26)](story-013-real-run-state-and-ball-integration.md) | Integration | Ready | ADR-0002 |

## Next Step

Run `/story-readiness production/epics/scoring-personal-best/story-001-score-math.md`, then `/dev-story`.
