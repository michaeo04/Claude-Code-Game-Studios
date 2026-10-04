# Epic: Near-Miss Detection

> **Layer**: Feature
> **GDD**: design/gdd/near-miss-detection.md
> **Architecture Module**: Near-Miss Detection
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 12 stories (see table)

## Overview

Near-Miss Detection owns the per-hazard near-zone state and emits `near_miss_detected(hazard_id, run_id)` for a close dodge. It runs after the Obstacle test in the fixed tick order so that a hit is applied before the exit-edge check; it reads the ball state and the three Obstacle signals and calls nothing back (Juice owns the presentation).

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0002: Game loop, Composition Root and tick order | This ADR makes one scene-root node, `GameRoot`, the Composition Root and the **only** node that runs a per-frame `_process`; it calls every system in one fixed order, builds them in one fixed order, and registers the... | Accepted | LOW |
| ADR-0008: Hazard, collision and content format | This ADR fixes them. **Authored** content is a typed Resource tree (`ChunkLibrary` > `ChunkDef` > `HazardPlacement` > `HazardPiece`, `.tres`, edited in the Godot editor). | Accepted | MEDIUM |
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |

**Engine risk of the epic: MEDIUM** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

19 requirements registered for this system: 9 covered by an ADR, 1 partial, 0 gap, 9 GDD-owned (specified fully by the GDD, no ADR needed).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-near-miss-detection-001 | Logic is split into static `NearMissMath` (F1-NM, a two-call wrapper that calls `ObstacleMath` F2, and the F3-NM validator), `NearMissCore` (RefCounted with `log_sink` and read-only accessors), and `NearMissConfig.validated(log... | GDD-owned |
| TR-near-miss-detection-002 | Per-hazard state is `{hit_ever_true, was_in_near_zone}` keyed by `hazard_id`, created on `hazard_bound` and discarded on `hazard_released`. | GDD-owned |
| TR-near-miss-detection-003 | `near_zone = hit_zone expanded by NEAR_MISS_ANGLE_MARGIN = COEFF*BALL_HALF_ANGLE` and `NEAR_MISS_S_MARGIN = COEFF*D/2`. `NEAR_MISS_CANDIDATE = NEAR_ZONE and not HIT_ZONE`. The swept values `dtheta/swept_start/swept_width` are c... | GDD-owned |
| TR-near-miss-detection-004 | Output is edge-triggered: exactly one `near_miss_detected(hazard_id:int, run_id:int)` on the near-zone true->false edge, or on a release with `released_by_reset==false`. Never fires while merely inside the zone (no output acros... | ADR-0008, ADR-0002 ✅ Covered |
| TR-near-miss-detection-005 | A hit overrides: `hit_reported` sets `hit_ever_true`, and the hazard never emits a near-miss. Within a tick, `hit_reported` is applied before the exit-edge check, regardless of driver delivery order. | ADR-0008, ADR-0002 ✅ Covered |
| TR-near-miss-detection-006 | A release with `released_by_reset==true` emits nothing (reset, re-prime, to-idle, Paused to Restart/Menu). Suppression is at the source. | ADR-0008, ADR-0002 ✅ Covered |
| TR-near-miss-detection-007 | One report per hazard, not per piece (multi-piece hazards share one state entry). | GDD-owned |
| TR-near-miss-detection-008 | The `near_miss_detected` payload is exactly `{hazard_id, run_id}` (strict allowlist, no closeness value). `run_id` is read from the last `run_reset` seen. | ADR-0008, ADR-0002 ✅ Covered |
| TR-near-miss-detection-009 | Config guard: `NEAR_MISS_ANGLE_COEFF` or `NEAR_MISS_S_COEFF` <= 0 gives `NEAR_MISS_MARGIN_NONPOSITIVE`. Strict containment of the hit zone in the near zone is the invariant. | GDD-owned |
| TR-near-miss-detection-010 | Preflight `NEAR_ZONE_OVERLAP` covers the 3+ pieces sharing a critical `s0` case. It is checked on angularly adjacent neighbors, including the wraparound pair, over the whole library, using near zones. It must not fire for non-a... | ADR-0008, ADR-0002 ✅ Covered |
| TR-near-miss-detection-011 | The test runs every tick in every phase (stationary degenerate case). A non-finite `theta` or `s` is a no-op frame (hold last good, log one error). | ADR-0008, ADR-0002 ✅ Covered |
| TR-near-miss-detection-012 | Along-track margin time budget is `S_MARGIN/v_max`: 16 ms at defaults, about 5 ms at the worst legal corner, so near-zone detection can be lost to a dropped frame. | GDD-owned |
| TR-near-miss-detection-013 | Same-tick `hazard_bound` plus `hazard_released` creates then tears down with no emit. A release on the same tick as a natural exit emits exactly once. | ADR-0008, ADR-0002 ✅ Covered |
| TR-near-miss-detection-014 | No side effects. Nothing is sent to Ball Movement, Obstacle or Run State. Inputs: `theta`, `theta_prev`, `s`, `s_prev`, the three Obstacle signals, `run_id`. | GDD-owned |
| TR-near-miss-detection-015 | Determinism: no randomness; bit-identical streams over a 500-tick script; no shared static state. | GDD-owned |
| TR-near-miss-detection-016 | Lint (engine-coupling regex family, as Obstacle) plus a reuse-not-reimplement guard (no second `arc_overlap`, and a behavioral parity check against `ObstacleMath` on the AC-3..AC-6 poses). Fixtures `make_near_miss_fixture`, `ma... | ADR-0009 ✅ Covered |
| TR-near-miss-detection-017 | NM-1 on-device check, BLOCKING at first-playable: near-miss-to-hazard-passed ratio within +/-20% between early (<20 s) and late (>T_RAMP) bands, at least 30 hazards passed per band. Failure response: adjust the coefficients ins... | ADR-0009 ✅ Covered |
| TR-near-miss-detection-018 | None. Tuning in `NearMissConfig.tres` (AC-27 advisory). | GDD-owned |
| TR-near-miss-detection-019 | None owned. Juice owns the VFX/audio/haptic. A coalescing requirement is handed to Juice (two near-misses within a short window must merge into one cue). | (Juice) ⚠️ Partial |

**Partial or gap requirements:** stories for these carry the open point named in `docs/architecture/architecture-traceability.md` (Partial Coverage) and are marked Blocked until it is closed.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/near-miss-detection.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [NearMissConfig, validation and test fixtures](story-001-near-miss-config-and-fixtures.md) | Logic | Complete | ADR-0008 |
| 002 | [NearMissMath near-zone expansion (F1-NM)](story-002-near-zone-expansion.md) | Logic | Complete | ADR-0008 |
| 003 | [Two-invocation swept test: HIT_ZONE and NEAR_MISS_CANDIDATE (F2 reused)](story-003-swept-near-zone-test.md) | Logic | Complete | ADR-0008 |
| 004 | [F3-NM preflight validator: NEAR_ZONE_OVERLAP](story-004-near-zone-overlap-validator.md) | Logic | Complete | ADR-0008 |
| 005 | [NearMissCore per-hazard state and edge-triggered output](story-005-near-miss-core-state-and-edge-output.md) | Logic | Complete | ADR-0002 |
| 006 | [Hit overrides near-miss and same-tick order](story-006-hit-override.md) | Logic | Ready | ADR-0002 |
| 007 | [Release by reset suppression and same-tick bind and release](story-007-reset-release-and-same-tick.md) | Logic | Complete | ADR-0002 |
| 008 | [Non-finite ball state is a no-op frame](story-008-non-finite-state-guard.md) | Logic | Complete | ADR-0008 |
| 009 | [Determinism and no side effects](story-009-determinism-and-no-side-effects.md) | Logic | Ready | ADR-0008 |
| 010 | [Engine-coupling lint and reuse-not-reimplement guard](story-010-lint-and-reuse-guard.md) | Logic | Ready | ADR-0009 |
| 011 | [Wire NearMissCore to real Ball, Obstacle, Run State and Juice](story-011-integration-wiring.md) | Integration | Ready | ADR-0002 |
| 012 | [NM-1 on-device near-miss rate speed-invariance check](story-012-nm1-device-check.md) | Integration | Ready | ADR-0009 |

## Next Step

Run `/story-readiness production/epics/near-miss-detection/story-001-near-miss-config-and-fixtures.md`, then `/dev-story`.
