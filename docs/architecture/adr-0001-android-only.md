# ADR-0001: Android only (iOS out of scope)

## Status

Accepted

## Date

2026-10-01

## Last Verified

2026-10-02

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

The project began with "Mobile (iOS/Android)" as its target, which doubles device testing and spike work for a solo project. The game targets **Android only**; iOS is out of scope for the MVP and for planning.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (platform and export) |
| **Knowledge Risk** | HIGH: Android export, lifecycle, Back handling, 16 KB pages and OBB removal all changed after 4.3 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.5 Android 16 KB pages, 4.7 OBB removed), `current-best-practices.md` (Android edge-to-edge) |
| **Post-Cutoff APIs Used** | None directly; the decision narrows which platform APIs later ADRs must verify |
| **Verification Required** | Platform Services spikes PS-1, PS-2, PS-4 (lifecycle sequences, `PAUSED/RESUMED` under Vulkan, Back on Android 16 / SDK 36) on Android devices |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0006 (Android integration), ADR-0005 (sensor source and input pipeline) |
| **Blocks** | None |
| **Ordering Note** | Written first; every platform ADR assumes it |

## Context

### Problem Statement

`technical-preferences.md`, the concept and several GDDs listed iOS and Android. Platform Services, Tilt Input, the UX specs and the QA plan each carried iOS-specific design (lifecycle ordering, iPhone haptics, cutouts, 44 pt targets, no-`quit()`), and a device matrix that needed an iPhone.

### Current State

Before this decision iOS content existed in five GDDs and three UX specs, all unbuilt and untested.

### Constraints

- Solo project; weeks-to-months timeline.
- Device procurement and spikes are owned by the user.

### Requirements

- One platform to design, build, test and certify.

## Decision

The game targets **Android only**. iOS is out of scope for the MVP and for planning. Godot's Android export and Android device checks are the only platform work. iOS content was removed from the GDDs on 2026-10-01 (commit 5dd42eb).

### Architecture

```
Platform layer: Godot 4.7.2 Android export only (no iOS export preset, no iOS code paths)
```

### Key Interfaces

None. `PlatformServices` still isolates every OS call, so a future platform would add an adapter rather than change callers.

### Implementation Guidelines

- No iOS branches, strings, test devices or spike rows.
- `quit()` and the confirm-quit dialog apply on every screen that offers them.
- Touch targets use the 48 dp floor; gesture edges are Android's (back-swipe strip, notification shade, gesture bar).

## Alternatives Considered

### Alternative 1: iOS and Android

- **Description**: the previous target.
- **Pros**: more reach.
- **Cons**: double device and spike work; iOS-only lifecycle and haptics behavior to design and verify.
- **Estimated Effort**: roughly twice the platform work.
- **Rejection Reason**: scope for a solo project.

### Alternative 2: Delete every iOS mention at once

- **Description**: strip iOS text everywhere in one pass.
- **Pros**: clean documents.
- **Cons**: edits two reviewed GDDs in bulk.
- **Rejection Reason**: done instead as a controlled pass (5dd42eb).

## Consequences

### Positive

- One device matrix, fewer spikes (PS-3 and PS-7 removed), simpler lifecycle model (focus implies suspend is fixed true).

### Negative

- No iOS audience; reversing the decision needs a new ADR and re-adding the removed design.

### Neutral

- `quit()` is available everywhere.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| iOS is wanted later | Low | Medium | `PlatformServices` isolates OS calls; supersede this ADR |
| Android fragmentation (lifecycle under Vulkan, Android 16 Back) | Medium | High | spikes PS-1, PS-2, PS-4 are blocking for the first playable |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | n/a | no change | 16.6 ms |
| Memory | n/a | no change | 512 MB (mid-tier Android) |
| Load Time | n/a | no change | n/a |

## Migration Plan

1. Update `technical-preferences.md`, the concept and `designated-gates.md` (done 2026-10-01).
2. Remove iOS branches from the UX specs (done).
3. Remove iOS content from Platform Services, Tilt Input, Ball Movement, Save & Persistence and Run State (done, 5dd42eb).

**Rollback plan**: supersede this ADR and re-add an iOS export preset, adapter and device matrix.

## Validation Criteria

- [x] No iOS text remains in GDDs or UX specs except the ADR reference and "removed" markers.
- [ ] Platform spikes PS-1, PS-2 and PS-4 pass on at least two Android makers.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/platform-services.md` | Platform Services | lifecycle model, FIS fixed per platform | FIS is true (Android) for every release build |
| `design/gdd/tilt-input.md` | Tilt Input | sensor source and device matrix | Android sensor path only |
| `design/gdd/menus-screen-flow.md` | Menus & Screen Flow | `quit()` ownership (Rule 6) | `quit()` and confirm-quit apply on every screen that offers them |
| `design/gdd/hud.md` | HUD | touch-target floor | 48 dp only |
| `design/gdd/save-persistence.md`, `design/gdd/run-state-restart.md`, `design/gdd/ball-movement.md` | Save, Run State, Ball Movement | device checks and spike plans | Android devices only |

## Related

- `design/gdd/gdd-cross-review-2026-10-01.md` and `-rerun.md` (consistency checks after the removal).
- Future: ADR-0005 (sensor source and input pipeline) and ADR-0006 (Android integration) build on this decision.
