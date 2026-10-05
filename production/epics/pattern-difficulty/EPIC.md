# Epic: Pattern & Difficulty

> **Layer**: Feature
> **GDD**: design/gdd/pattern-difficulty.md
> **Architecture Module**: Pattern & Difficulty
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 14 stories (see table)

## Overview

Pattern & Difficulty owns the chunk-based hazard sequencer: the hazard provider (`hazards_for_segment`), tiered chunk pools with bag shuffling and a seeded PRNG that is reseeded on `run_reset`, the read-history and `t_dodge_worst` supply, the generalized cross-chunk spacing rule and the offline content preflight (P1 to P3) over `chunk_library_01.tres` (ADR-0008). It plugs into the Obstacle System through the `HazardContentProvider` seam. The technical-director review asked for a Pattern/Obstacle design review before this epic starts (see production/owner-actions.md).

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0004: Map Loader and MapConfig | This ADR defines it. An authored `MapDefinition` resource (`.tres`) holds the Environment values and the chunk library; `GameRoot` derives the three Camera values with pure `CameraMath`, and the `MapLoader` builds an... | Accepted | MEDIUM |
| ADR-0008: Hazard, collision and content format | This ADR fixes them. **Authored** content is a typed Resource tree (`ChunkLibrary` > `ChunkDef` > `HazardPlacement` > `HazardPiece`, `.tres`, edited in the Godot editor). | Accepted | MEDIUM |
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |

**Engine risk of the epic: MEDIUM** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

21 requirements registered for this system: 10 covered by an ADR, 2 partial, 0 gap, 9 GDD-owned (specified fully by the GDD, no ADR needed).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-pattern-difficulty-001 | Logic is split into static `PatternMath` (F1 tier, F2 opposing/spacing, F3 cost ratio, F4 bag bounds), `PatternCore` (RefCounted: provider impl, seeded RNG, bags, read history, padding), and `PatternConfig.validated(log_sink)`... | GDD-owned |
| TR-pattern-difficulty-002 | Chunk record: `{chunk_id, tier, segment_count 1-3, hazard_placements:[(local_segment_index, hazard_type, footprint_pieces)]}` in chunk-local coordinates. At `base`, pieces are translated by `base*L` in `s`. Whole-segment alignm... | ADR-0008 ✅ Covered |
| TR-pattern-difficulty-003 | PatternCore is the `HazardContentProvider`: `hazards_for_segment(index)` returns empty for `index<0`, the next local segment's translated pieces mid-chunk, empty while padding, else it draws a new chunk. | ADR-0008 ✅ Covered |
| TR-pattern-difficulty-004 | Tier is a pure function of `run_time`: INTRO `<TIER_INTRO_DURATION`, RAMP `<TIER_RAMP_DURATION`, FULL after, with the upper boundary inclusive. Pools are supersets (RAMP includes INTRO, FULL includes all). Tier changes lazily a... | GDD-owned |
| TR-pattern-difficulty-005 | Per tier, a bag is shuffled with a PRNG seeded from `run_id`, drawn without replacement, and reshuffled on empty. The reshuffled first draw must differ from the previous last draw (waived at N=1). `min_gap`=2, `max_gap`=2N-1 fo... | GDD-owned |
| TR-pattern-difficulty-006 | The PRNG is a `RandomNumberGenerator` with an explicit `seed` set from `run_id` before the first draw, never `randomize()`. Fisher-Yates is implemented by the module itself (the shuffle must use this RNG instance). | ADR-0008 ✅ Covered |
| TR-pattern-difficulty-007 | On `run_reset(run_id)` Pattern reseeds, reshuffles all three bags, discards in-progress chunk state and clears the read history. It must run first among `run_reset` subscribers. | ADR-0008 ✅ Covered |
| TR-pattern-difficulty-008 | The first chunk draw of a run is restricted to grace-compliant INTRO chunks (translated `s_start>=11` at base 0). Later draws are unrestricted. `GRACE_POOL_TOO_SMALL` requires at least 2 compliant chunks. | GDD-owned |
| TR-pattern-difficulty-009 | The preflight inherits Obstacle's gates. Every authored piece must pass `HIDDEN_CONTENT_FORBIDDEN` (per piece) and `EXIT_BEYOND_VISIBLE_ARC` (per `theta_solution`). | ADR-0008 ✅ Covered |
| TR-pattern-difficulty-010 | Solution angles: Wall and Near-Ring have one (gap midpoint), Double Gate has two, Spike has none (exempt). Two reads are opposing if any angle pair has `abs(delta_theta)>ANGULAR_REVERSAL_THRESHOLD` (strict `>`). Opposing pairs... | GDD-owned |
| TR-pattern-difficulty-011 | Cross-chunk spacing is enforced by sequencer padding. A pruned read history holds `(s_start, theta_solution_set)` for non-Spike reads (pruned to `s_start >= frontier - DODGE_RECOVERY_S`). Every non-Spike read of a drawn chunk i... | ADR-0008 ⚠️ Partial |
| TR-pattern-difficulty-012 | F3 must delegate to Ball Movement's `BallMath.T` (three-branch F5a), not restate the middle branch (NaN/wrong value when `BALL_LAG_TAU<=eps/OMEGA_MAX`). | GDD-owned |
| TR-pattern-difficulty-013 | The pool clustering statistic `opposing_pair_fraction` is computed per tier. A value above `MAX_OPPOSING_FRACTION` logs an ADVISORY `EXCESSIVE_ANGULAR_CLUSTERING` (load still succeeds). It is 0.0 (no NaN) when fewer than 2 non-... | GDD-owned |
| TR-pattern-difficulty-014 | Config guards: `TIER_ORDER_INVALID`, `TIER_DURATION_OUT_OF_RANGE` (intro 8-20, ramp 45-240, checked first), `ANGULAR_THRESHOLD_OUT_OF_RANGE`. `t_dodge_worst` = `T_DODGE_180` is supplied to Tube Track as a config value, never de... | ADR-0004 ⚠️ Partial |
| TR-pattern-difficulty-015 | Determinism: the same `run_id` and the same call script give bit-identical chunk sequences. A different `run_id` changes the first draw. No side effects; Run State and Tube Track are read-only. | ADR-0008 ✅ Covered |
| TR-pattern-difficulty-016 | Obstacle must call `hazards_for_segment` in increasing index order, once each. PatternCore state (mid-chunk, mid-padding) depends on call order. Tier is sampled at window-entry time (ahead of the ball). | ADR-0008 ✅ Covered |
| TR-pattern-difficulty-017 | Per-call cost is small (bag draw plus history check against a short pruned history). No explicit budget is given. | GDD-owned |
| TR-pattern-difficulty-018 | Lint bans the engine-coupling tokens except `RandomNumberGenerator` with an explicit seed (the lint must verify seed-before-first-draw). The 8-chunk fixture with INTRO={W1-W4}, RAMP=+{SP1,DG1}, FULL=+{NR1,REV2} drives the tests... | ADR-0009 ✅ Covered |
| TR-pattern-difficulty-019 | The statistical shuffle-fairness test is ADVISORY: chi-square over 500 `run_id`s, N=8, p>0.01. Use a fixed hardcoded seed list, not generated seeds. | ADR-0009 ✅ Covered |
| TR-pattern-difficulty-020 | No persistence. All chunk and sequence state is per-run and in-memory. | GDD-owned |
| TR-pattern-difficulty-021 | The chunk-library data format is only logically specified (the record in TR-002). The on-disk format and the `PatternConfig.tres` fields beyond the three knobs are not fixed. | ADR-0008 ✅ Covered |

**Partial or gap requirements:** stories for these carry the open point named in `docs/architecture/architecture-traceability.md` (Partial Coverage) and are marked Blocked until it is closed.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/pattern-difficulty.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [PatternConfig, tier selection, config guards and fixture](story-001-pattern-config-tier-selection-guards.md) | Logic | Complete | ADR-0008, ADR-0009 |
| 002 | [Dodge-recovery math, opposing test and cost ratio](story-002-dodge-recovery-math-and-cost-ratio.md) | Logic | Complete | ADR-0008 |
| 003 | [ChunkLibraryCompiler, CompiledLibrary and structural checks](story-003-chunk-library-compiler-structural-checks.md) | Logic | Complete | ADR-0008, ADR-0004 |
| 004 | [Within-chunk validators (hidden, exit, dodge-recovery)](story-004-within-chunk-validators.md) | Logic | Complete | ADR-0008 |
| 005 | [Seeded PRNG, Fisher-Yates and tiered bags](story-005-seeded-prng-fisher-yates-bags.md) | Logic | Complete | ADR-0008 |
| 006 | [PatternCore as HazardContentProvider](story-006-hazard-provider-chunk-delivery.md) | Logic | Complete | ADR-0008, ADR-0004 |
| 007 | [run_reset reseed, determinism and no side effects](story-007-run-reset-determinism-no-side-effects.md) | Logic | Ready | ADR-0008, ADR-0002 |
| 008 | [Angular clustering fraction and pool advisories](story-008-angular-clustering-and-pool-advisories.md) | Logic | Complete | ADR-0008 |
| 009 | [Shipped PatternConfig.tres](story-009-shipped-pattern-config-tres.md) | Config/Data | Complete | ADR-0004 |
| 010 | [Sequencer padding with generalized history](story-010-sequencer-padding-generalized-history.md) | Logic | Blocked (TR-011 Partial, Pattern design review) | ADR-0008 |
| 011 | [t_dodge_worst config supply](story-011-t-dodge-worst-supply.md) | Logic | Blocked (TR-014 Partial, ADR-0004 carrier) | ADR-0004 |
| 012 | [No-engine-coupling lint](story-012-no-engine-coupling-lint.md) | Logic | Complete | ADR-0009, ADR-0008 |
| 013 | [Integration wiring and golden sequence](story-013-integration-wiring-golden-sequence.md) | Integration | Ready | ADR-0008, ADR-0002 |
| 014 | [Real chunk library and PD-1 playtest](story-014-real-chunk-library-and-recognition-playtest.md) | Integration | Blocked (content, Story 010) | ADR-0008 |

`ContentPreflight` (P1 to P3) is owned by the Obstacle System epic (stories 011 and 012); this epic supplies the compiler, validators and sequencer it composes.

## Next Step

Run `/story-readiness production/epics/pattern-difficulty/story-001-pattern-config-tier-selection-guards.md`, then `/dev-story`.
