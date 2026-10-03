# Epic: Map Loader & MapConfig

> **Layer**: Foundation
> **GDD**: none (defined by ADRs and `docs/architecture/architecture.md`)
> **Architecture Module**: Map Loader
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 11 stories (see table)

## Overview

The Map Loader runs the validate-first, apply-second load sequence (Phase A: read, validate, build `MapConfig`; Phase B apply steps B1 to B5, then `map_ready` only on success), reports failures through `map_load_failed`, and supports Retry (ADR-0004). It has no GDD; `MapDefinition`, `MapConfig` and the `hazard_style` and `camera_far` fields are defined by ADR-0004 and ADR-0014.

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0004: Map Loader and MapConfig | This ADR defines it. An authored `MapDefinition` resource (`.tres`) holds the Environment values and the chunk library; `GameRoot` derives the three Camera values with pure `CameraMath`, and the `MapLoader` builds an... | Accepted | MEDIUM |
| ADR-0008: Hazard, collision and content format | This ADR fixes them. **Authored** content is a typed Resource tree (`ChunkLibrary` > `ChunkDef` > `HazardPlacement` > `HazardPiece`, `.tres`, edited in the Godot editor). | Accepted | MEDIUM |
| ADR-0014: Hazard render route and view node tree | This ADR decides: **one `MeshInstance3D` per hazard** (not per piece), taken from a pool built once at map load; the pieces of one hazard are merged into **one `ArrayMesh` per `HazardSpec`**, built once by a pure `Haz... | Accepted | HIGH |

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
| 001 | MapDefinition, MapConfig and loader seam types | Logic | Ready | ADR-0004 |
| 002 | HazardStyle validation and TubeConfig.from_map | Logic | Ready | ADR-0004, ADR-0014 |
| 003 | MapConfig.build with Camera values and camera_far | Logic | Ready | ADR-0004, ADR-0014 |
| 004 | Phase A validation sequence | Logic | Ready | ADR-0004 |
| 005 | Phase B apply order and map_ready | Logic | Ready | ADR-0004 |
| 006 | Failure reporting, map_load_failed and Retry | Logic | Ready | ADR-0004 |
| 007 | Author map_01.tres and its round-trip test | Config/Data | Ready | ADR-0004, ADR-0008, ADR-0014 |
| 008 | map_loader.gd driver and ResourceLoader lint | Integration | Ready | ADR-0004 |
| 009 | Loader wiring order, map_load_failed to Menus, Retry Callable | Integration | Ready | ADR-0004 |
| 010 | Android export smoke test (load and corrupted copy) | Integration | Ready | ADR-0004, ADR-0008 |
| 011 | MS-1 boot sequence time on a mid-tier phone | Integration | Ready | ADR-0004, ADR-0014 |

## Next Step

Run `/story-readiness production/epics/map-loader/story-001-map-types-and-seams.md`, then `/dev-story`.
