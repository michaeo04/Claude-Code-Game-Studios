# Epic: Composition Root & Game Loop

> **Layer**: Foundation
> **GDD**: none (defined by ADRs and `docs/architecture/architecture.md`)
> **Architecture Module**: Composition Root (GameRoot)
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 12 stories (see table)

## Overview

`GameRoot` is the scene root and the only node with a `_process`: it owns the injected microsecond clock, the construction order (including the immutable `WorldGeometry` and `WorldFrame`, validated together), the fixed per-frame `_tick` order and the single `_wire()` table of `[signal, handler, rank]` rows (ADR-0002, ADR-0013). It has no GDD; its rules are the ADRs and `architecture.md`. This epic also covers the `WorldFrame` render-origin shift, `TubeMath.local_point` and the boot rendering-method check through an injected getter (ADR-0003).

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0002: Game loop, Composition Root and tick order | This ADR makes one scene-root node, `GameRoot`, the Composition Root and the **only** node that runs a per-frame `_process`; it calls every system in one fixed order, builds them in one fixed order, and registers the... | Accepted | LOW |
| ADR-0003: Renderer choice and tube render route | This ADR picks the **Mobile renderer** for the Android build behind a measured device gate (R-1) with **Forward+ as the fallback**, renders the tube as **one `MeshInstance3D` per segment slot sharing one Mesh and one... | Accepted | HIGH |
| ADR-0004: Map Loader and MapConfig | This ADR defines it. An authored `MapDefinition` resource (`.tres`) holds the Environment values and the chunk library; `GameRoot` derives the three Camera values with pure `CameraMath`, and the `MapLoader` builds an... | Accepted | MEDIUM |
| ADR-0013: Distance precision and the render origin (WorldFrame) | A 32-bit render position is not: world z = `-s` loses precision as a run gets long (0.0024 u, half a pixel at the ball's distance, is exceeded at `s` = 16384 under the 2-ulp model and at 4096 under the 8-ulp model). T... | Accepted | HIGH |

**Engine risk of the epic: HIGH** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

This module has no GDD, so no `TR-` ids are registered for it. Its requirements are the Decision and Validation Criteria sections of the governing ADRs above; `/create-stories` takes its acceptance criteria from them.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All Validation Criteria of the governing ADRs that concern this module are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [GameRoot clock injection and single tick driver](story-001-game-root-clock-and-tick-driver.md) | Logic | Ready | ADR-0002 |
| 002 | [Fixed per-frame order in `_tick()`](story-002-per-frame-tick-order.md) | Logic | Ready | ADR-0002, ADR-0013 |
| 003 | [WorldFrame, WorldFrameConfig and render-origin math](story-003-world-frame-core.md) | Logic | Ready | ADR-0013 |
| 004 | [`TubeMath.local_point` and logical-frame reference](story-004-tube-math-local-point.md) | Logic | Ready | ADR-0013 |
| 005 | [Rebase contract for views, reset wiring and soak](story-005-world-frame-rebase-contract.md) | Integration | Ready | ADR-0013 |
| 006 | [Construction order and WorldGeometry/WorldFrame preflight](story-006-construction-order-and-validation.md) | Integration | Ready | ADR-0002, ADR-0013 |
| 007 | [`_wire()` row table and pinned subscriber order](story-007-wire-table-subscriber-order.md) | Integration | Ready | ADR-0002 |
| 008 | [Boot rendering-method check through injected getter](story-008-boot-rendering-method-seam.md) | Integration | Ready | ADR-0003 |
| 009 | [Composition-root lint rules and import-before-test](story-009-ci-lints-and-import-order.md) | Logic | Ready | ADR-0002, ADR-0013 |
| 010 | [Map load hand-off and loop start](story-010-map-load-handoff-and-loop-start.md) | Integration | Ready | ADR-0002, ADR-0004 |
| 011 | [Orchestration soak on device (60/120 Hz)](story-011-orchestration-device-soak.md) | Integration | Ready | ADR-0002 |
| 012 | [PRC-1 rebase spike on device](story-012-rebase-device-spike-prc1.md) | Integration | Ready | ADR-0013 |

## Next Step

Run `/story-readiness production/epics/composition-root/story-001-game-root-clock-and-tick-driver.md`, then `/dev-story`.
