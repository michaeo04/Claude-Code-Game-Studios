# ADR-0001: Android only (iOS out of scope)

## Status

Accepted by the user, 2026-10-01.

## Context

The project began with "Mobile (iOS/Android)" as its target. Several approved or drafted documents carry iOS-specific design: Platform Services (lifecycle order, haptics on iPhone, safe-area cutouts, spikes PS-3, PS-7, PS-9), Tilt Input (CoreMotion, motion usage string), the UX specs (44 pt targets, Control Center edge, no-`quit()` rule). Supporting two platforms doubles device testing and spike work for a solo project.

## Decision

The game targets **Android only**. iOS is out of scope for the MVP and for planning. Godot's Android export and Android device checks are the only platform work.

## Consequences

- `quit()` and the confirm-quit dialog apply on every screen that offers them (the earlier "iOS has no quit" rule is dropped).
- Touch targets use the 48 dp floor only; gesture edges are Android's (back-swipe strip, notification shade, gesture bar).
- Device procurement for the Ball Movement spike needs Android devices only (at least 2 makers).
- iOS content in Platform Services, Tilt Input, Ball Movement, Save & Persistence and Run State is **reference only** and carries a "Platform scope" note. Removing it is a separate pass (`/propagate-design-change`), not done yet.
- Spikes PS-3 (iOS lifecycle), PS-7 (iPhone haptics) and the iOS half of PS-8/PS-9 are no longer required.

## Alternatives considered

- **iOS and Android (the previous target):** more reach, double the device and spike work. Rejected for scope.
- **Delete all iOS text now:** cleaner documents but edits two already-reviewed GDDs in bulk. Deferred.

## Follow-up

- Clean the iOS sections of `platform-services.md` and `tilt-input.md` and re-run `/consistency-check`.
- Revisit this ADR if iOS is ever reconsidered.
