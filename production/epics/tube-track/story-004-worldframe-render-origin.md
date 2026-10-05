# Story 004: WorldFrame render origin and rebase lint

> **Epic**: Tube Track
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-05

## Context
**GDD**: `design/gdd/tube-track.md`
**Requirement**: `TR-tube-track-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0013: Distance precision and the render origin (primary); ADR-0009: Test framework and CI (lint rule)
**ADR Decision Summary**: `s` stays float64 and unbounded. A pure `WorldFrame` holds `origin_s` (a whole number of segments), `render_z(s) = -(s - origin_s)` and `maybe_rebase(s)`; `WorldFrameConfig` is validated (`REBASE_SEGMENTS` default 84, range [24, 128]; `Z_RENDER_MAX` 2048 a constant). ADR-0013 Migration Plan creates `WorldFrame` with the first Tube View work; no other epic owns it.
**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Float32 error model (8 ulp) is measured on device by PRC-1 (device evidence, Story 013 session). `floor((s - origin_s) / L)` must not misround at an exact boundary: reuse the literal `11.999999999999998` test. GDScript `float` is 64-bit; only `render_z` output meets a `Vector3`.
**Control Manifest Rules (this layer)**:
- Required: `WorldFrame` is a pure engine-free `RefCounted`; `maybe_rebase` returns true once per crossing, `origin_s` stays an exact multiple of `L`; `on_run_reset(run_id)` and `reset()` set `origin_s = 0`; `GameRoot` validates `(REBASE_SEGMENTS + A + 1) * L <= Z_RENDER_MAX` else `REBASE_Z_EXCEEDS_BUDGET`; `render_z` asserts `abs(result) <= 2 * Z_RENDER_MAX` in debug builds.
- Forbidden: capping, wrapping or ending a run at `S_PRECISION_LIMIT`; `Vector3(` built from `s`, `s_offset` or `snapshot.s` outside `world_frame.gd` in view code; `physics/common/physics_interpolation` true.
- Guardrail: error at the ball's distance at most 0.0024 u for any run length.

## Acceptance Criteria
- [ ] **AC-15** (superseded by the ADR-0013 Validation Criteria) `render_z` equals `-(s - origin_s)` in float64; `maybe_rebase` keeps `origin_s` a multiple of `L` with `s - origin_s` in `[0, L)`, returns true once per crossing and false below the threshold, including one ulp below a multiple of `L`; `on_run_reset` and `reset` zero the origin; `REBASE_Z_EXCEEDS_BUDGET` fires for `REBASE_SEGMENTS` 128 at `L` 24; a host float64 soak of 3600 s at `V_MAX` keeps every placed `abs(z)` below 2048 for nodes ahead of and behind the ball. The `ulp32` derivation rows (ulp32(700) 6.1e-5, (7500) 4.9e-4, (16384) 1.95e-3, (1e6) 0.0625) are kept as a documentation check.
- [ ] **AC-25** (deferred, non-gating) The ADR-0013 ADVISORY lint `forbidden:raw_s_in_vector3` exists in `tools/ci/lint_rules.json` and its passing and failing fixtures pass (Ball Movement and Obstacle System scripts are scanned when they exist; their findings belong to those epics).

## Implementation Notes
**Scope note (2026-10-03):** the `WorldFrame` and `WorldFrameConfig` code is built by `composition-root` story 003 (and `TubeMath.local_point` by its story 004); this story does NOT re-implement them. It adds the Tube Track conformance test for AC-15 against that code (`tests/unit/tube_track/`) and the ADVISORY lint `forbidden:raw_s_in_vector3` (AC-25), and cannot start before `composition-root` story 003 is Done.

`src/core/world/world_frame.gd` (`class_name WorldFrame`), `world_frame_config.gd` (`validated(log_sink)` returns a clamped copy via `duplicate()`). `_init(config, geometry)`; `geometry` supplies `L` and `A` (immutable `WorldGeometry` is built by `GameRoot`; use a test double here). Rebase: `origin_s += floor((s - origin_s) / L) * L`. The `_wire()` rows (rank 1 for `on_run_reset`) belong to the composition-root epic. Lint rules registered by ADR-0009 are verified, not authored, unless missing.

## Out of Scope
- Story 011: `TubeView.rebase()`
- Story 010: calling `WorldFrame.reset()` before `to_idle()`
- composition-root epic: `WorldFrame step` in `_tick` and its spy test

## QA Test Cases
- **AC-15**: render_z, rebase, soak
  - Given: L 12, REBASE_SEGMENTS 84. When: s crosses 1008, then one ulp below a multiple. Then: origin 1008 (multiple of 12), remainder in [0, 12); true once. Edge cases: REBASE_SEGMENTS 128 at L 24 fires the budget code; 3600 s soak both signs of z.
- **AC-25**: lint fixtures
  - Given: pass and fail fixtures. When: lint runner executes. Then: rule fails the bad fixture, passes the good one. Edge cases: rule scope with no files passes with a note.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/tube_track/world_frame_test.gd`
**Evidence**: `tests/unit/tube_track/world_frame_test.gd` (8 tests, AC-15); AC-25 lint `forbidden:raw_s_in_vector3` already registered with fixtures.

## Dependencies
- Depends on: test-harness-ci (lint runner story)
- Unlocks: Story 010, Story 011, composition-root epic (WorldFrame construction), ball-movement and obstacle-system view stories
