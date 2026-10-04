# Epic: Ball Movement

> **Layer**: Core
> **GDD**: design/gdd/ball-movement.md
> **Architecture Module**: Ball Movement
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 17 stories (see table)

## Overview

Ball Movement owns the ball state (`theta`, `theta_prev`, `s`, `s_prev`, `speed`, `omega`) and the speed curve: an exact integral of the ramp, the angular tracking (RATE mode with `OMEGA_MAX` and `BALL_LAG_TAU`) and `BallConfig.validated()`. `step(dt_eff, steer, valid, input_source)` runs once per tick; `s` is a float64 that never wraps or caps (ADR-0013). The view (`BallView`) belongs to the Presentation layer.

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0002: Game loop, Composition Root and tick order | This ADR makes one scene-root node, `GameRoot`, the Composition Root and the **only** node that runs a per-frame `_process`; it calls every system in one fixed order, builds them in one fixed order, and registers the... | Accepted | LOW |
| ADR-0008: Hazard, collision and content format | This ADR fixes them. **Authored** content is a typed Resource tree (`ChunkLibrary` > `ChunkDef` > `HazardPlacement` > `HazardPiece`, `.tres`, edited in the Godot editor). | Accepted | MEDIUM |
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |
| ADR-0012: Ball material and world chroma | This ADR decides: **`BallView` owns the ball node and its one `ShaderMaterial`**, with two single-purpose setters (`set_luminance_target` for Environment, `set_rim_glow` for Juice); the ball body is **unshaded** with... | Accepted | HIGH |
| ADR-0013: Distance precision and the render origin (WorldFrame) | A 32-bit render position is not: world z = `-s` loses precision as a run gets long (0.0024 u, half a pixel at the ball's distance, is exceeded at `s` = 16384 under the 2-ulp model and at 4096 under the 8-ulp model). T... | Accepted | HIGH |

**Engine risk of the epic: HIGH** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

23 requirements registered for this system: 5 covered by an ADR, 0 partial, 0 gap, 18 GDD-owned (specified fully by the GDD, no ADR needed).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ball-movement-001 | BallMath static class holds F1 step, F2 speed and S, wrap_angle (shared verbatim with Tube Track) and F5 T(X,eps); the token wrapf( is forbidden in its file | GDD-owned |
| TR-ball-movement-002 | BallCore (RefCounted, no engine calls) takes a validated BallConfig, injected dt_max and a log_sink Callable(level,code,message); events reset(), on_resumed(), step(dt_eff,steer,valid,input_source) | GDD-owned |
| TR-ball-movement-003 | BallConfig (Resource) holds every knob; validated(log_sink) returns a clamped copy and leaves the shipped resource untouched; NaN/INF takes the default; one KNOB_CLAMPED per change | GDD-owned |
| TR-ball-movement-004 | validated() also runs a derived check: if T(PI,0.05)>1.14 s it lowers BALL_LAG_TAU by bisection (/err/<=1e-9 or 60 iterations), never OMEGA_MAX, and logs one KNOB_CLAMPED | GDD-owned |
| TR-ball-movement-005 | step() is called once per rendered frame, after Run State tick() and Tilt poll/flush, in every phase; dt_eff<=0 or non-finite is a no-op (prev=current, omega=0); dt_eff>dt_max is clamped with DT_OVER_MAX | ADR-0002 ✅ Covered |
| TR-ball-movement-006 | Position mapping (POSITION default): phi_target=phi_anchor+STEER_ARC*clamp(steer); e=wrap_angle(target-phi); alpha=1-exp(-dt/tau) (1 if tau<1e-4); step clamped to +-OMEGA_MAX*dt; snap when /e-step/<1e-6 | GDD-owned |
| TR-ball-movement-007 | Anchor rules: phi_anchor=0 at reset; the first moving step after on_resumed re-bases phi_anchor=phi-STEER_ARC*steer; phi and anchor shift together by multiples of 2PI when /phi/>2PI | GDD-owned |
| TR-ball-movement-008 | Speed is the exact integral S(t) of the ramp, s+=S(t_new)-S(t_old), with the T_RAMP<=0 sentinel checked first; t_run is integrated internally and must equal Run State run_time | GDD-owned |
| TR-ball-movement-009 | Published read-only state after each step: theta, theta_prev, s, s_prev, speed, omega, radius (D/2); omega=(phi_new-phi_old)/dt taken before the 2PI shift; consumers read after the step | GDD-owned |
| TR-ball-movement-010 | Held-steer semantics: valid=false or non-finite steer holds the last accepted steer (BAD_STEER for non-finite only); steer is clamped to [-1,1]; a no-op step never updates the held value | GDD-owned |
| TR-ball-movement-011 | reset() is synchronous with no loop, allocation or .new()/load() in the body; it zeroes everything, clears the mode latch and held steer, and sets speed=speed(0) | GDD-owned |
| TR-ball-movement-012 | RATE mode and the FALLBACK latch stay in BallCore (latched on the first dt>0 step after reset) but the MVP driver never passes FALLBACK; a no-sensor device is blocked at HUD/Menus | GDD-owned |
| TR-ball-movement-013 | Contact is not detected here: no collider, CharacterBody3D or hit_reported; Obstacle System owns swept overlap using (theta_prev,s_prev)->(theta,s) and must derive bounds from the loaded config | ADR-0008 ✅ Covered |
| TR-ball-movement-014 | Ball placement is by the driver using Tube Track P(theta,s,h) with h=D/2 (ring radius R+D/2); Ball Movement never reads raw world Z (lint: position.z, global_position.z, global_transform.origin) | GDD-owned |
| TR-ball-movement-015 | Same input sequence gives the same output, bit-identical; no randomness, no shared static state; no const container or top-level subscript assignment in BallMath | GDD-owned |
| TR-ball-movement-016 | Phase-free inertness: dt_eff=0 on settling ticks (after run_started and run_resumed), Hit, Paused and Resuming freezes everything bit-identically | GDD-owned |
| TR-ball-movement-017 | dt and angle are 64-bit; /s-S(t_run)/<=1e-6 after 100,000 frames | GDD-owned |
| TR-ball-movement-018 | The 60 Hz fairness contract: software response<=0.13 s and end-to-end<=0.20 s at 60 Hz; 30 Hz is recorded but not fairness-gated; latency stack is 0.11 s on top of T_DODGE_180 | GDD-owned |
| TR-ball-movement-019 | Ball view is a smooth-shaded sphere with a cool-white rim; cosmetic roll rate speed/radius and a capped lean from omega are derived in the view layer (no state in core); no speed VFX on the ball | ADR-0012 ✅ Covered |
| TR-ball-movement-020 | Oracles come from tools/reference-sim/ball_movement.js; fixture make_ball_fixture(), make_core(cfg,dt_max=0.1), make_sink(); steer tables in one constants file; LCG for pseudo-random tables; each row is its own test with a fres... | ADR-0009 ✅ Covered |
| TR-ball-movement-021 | Device gates need a measurable harness: per-frame theta logging, a 240 fps jig, evidence files under production/qa/evidence/ball-movement/bm-N.md; BM-1a, BM-1b, BM-3 BLOCK the first playable | ADR-0009 ✅ Covered |
| TR-ball-movement-022 | No persisted state; per-run state only (reset each run) | GDD-owned |
| TR-ball-movement-023 | Reset glide: segment(s) covering s=0..>=11 u must be hazard-free because reset glide is up to T(PI,0.05)=1.064 s | GDD-owned |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/ball-movement.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [BallMath pure functions](story-001-ball-math.md) | Logic | Complete | ADR-0009 |
| 002 | [BallConfig resource and fixtures](story-002-ball-config-fixtures.md) | Config/Data | Complete | ADR-0009 |
| 003 | [BallConfig.validated() and derived check](story-003-ball-config-validated.md) | Logic | Complete | ADR-0009 |
| 004 | [BallCore shell, speed and distance](story-004-ballcore-speed-distance.md) | Logic | Complete | ADR-0002 |
| 005 | [Position tracking, dt guards, held steer](story-005-position-tracking-dt-steer.md) | Logic | Complete | ADR-0002 |
| 006 | [Anchor, resume, published state](story-006-anchor-resume-published-state.md) | Logic | Complete | ADR-0002 |
| 007 | [RATE mapping and latch](story-007-rate-mode-latch.md) | Logic | Complete | ADR-0009 |
| 008 | [Reset conformance, logs, determinism](story-008-reset-logs-determinism.md) | Logic | Ready | ADR-0009 |
| 009 | [CI lint rules for the ball core](story-009-ball-lint-rules.md) | Logic | Complete | ADR-0009 |
| 010 | [Sign and driver-order integration](story-010-sign-driver-order-integration.md) | Integration | Complete | ADR-0002 |
| 011 | [BallView node and placement](story-011-ball-view-node-placement.md) | Integration | Ready | ADR-0012 |
| 012 | [Ball material, rim, setters](story-012-ball-material-rim-setters.md) | Visual/Feel | Ready | ADR-0012 |
| 013 | [Spike readiness harness](story-013-spike-readiness-harness.md) | Integration | Ready | ADR-0009 |
| 014 | [BM-1a/1b latency evidence](story-014-bm1-latency-device-evidence.md) | Integration | Ready | ADR-0009 |
| 015 | [BM-3 no jolt evidence](story-015-bm3-no-jolt-device-evidence.md) | Integration | Ready | ADR-0009 |
| 016 | [BM-2 and BM-5 tuning lock](story-016-bm2-bm5-tuning-lock.md) | Integration | Ready | ADR-0009 |
| 017 | [BM-4, BM-6 and rest traces (AC-32)](story-017-advisory-playtests-rest-traces.md) | Integration | Ready | ADR-0009 |

## Next Step

Run `/story-readiness production/epics/ball-movement/story-001-ball-math.md`, then `/dev-story`.
