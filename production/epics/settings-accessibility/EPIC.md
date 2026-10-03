# Epic: Settings & Accessibility

> **Layer**: Foundation
> **GDD**: design/gdd/settings-accessibility.md
> **Architecture Module**: Settings & Accessibility
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 12 stories (see table)

## Overview

Settings & Accessibility keeps the five settings in memory (haptics enabled and intensity, tilt sensitivity, reduced motion, colourblind-safe), persists them through Save & Persistence and publishes getters plus `setting_changed`. It pushes `haptics_*` to Platform Services at construction and has no engine calls.

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0002: Game loop, Composition Root and tick order | This ADR makes one scene-root node, `GameRoot`, the Composition Root and the **only** node that runs a per-frame `_process`; it calls every system in one fixed order, builds them in one fixed order, and registers the... | Accepted | LOW |
| ADR-0003: Renderer choice and tube render route | This ADR picks the **Mobile renderer** for the Android build behind a measured device gate (R-1) with **Forward+ as the fallback**, renders the tube as **one `MeshInstance3D` per segment slot sharing one Mesh and one... | Accepted | HIGH |
| ADR-0006: Android platform integration | This ADR keeps one GDScript `PlatformServices` node as the only owner of OS calls, fixes the lifecycle and Back policy, sets the device floor (Android 9+, Vulkan 1.1) and defines the export preset (Gradle build, AAB,... | Accepted | HIGH |
| ADR-0007: Persistence implementation | This ADR keeps the GDD's format and write protocol, replaces the eight loose seams with **one `SaveFs` facade plus three Callables**, adds the file-size and backup-listing operations the GDD already requires, keeps th... | Accepted | MEDIUM |
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |
| ADR-0011: UI architecture | This ADR decides: **stretch mode `canvas_items` with `Window.content_scale_factor = dpi / 160`**, so layouts are written directly in dp (one viewport unit is one dp); a fixed **layer stack** (5 flash, 10 HUD, 20 Menus... | Accepted | HIGH |

**Engine risk of the epic: HIGH** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

15 requirements registered for this system: 5 covered by an ADR, 1 partial, 0 gap, 9 GDD-owned (specified fully by the GDD, no ADR needed).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-settings-accessibility-001 | Exactly five settings in Save [settings]: haptics_enabled bool true, haptics_intensity float 1.0, tilt_sensitivity float 1.0, reduced_motion_enabled bool false, colorblind_safe_enabled bool false; unknown keys rejected with one... | GDD-owned |
| TR-settings-accessibility-002 | SettingsCore (RefCounted, no Node) built through three injected Callables get_value_seam(section,key,default)->Variant, set_value_seam(section,key,value)->bool, log_sink(level,code,key,message) plus constructor params sensitivi... | ADR-0002 ✅ Covered |
| TR-settings-accessibility-003 | Boot read: exactly five get_value_seam calls (one per key, each with its own default), no batching, constructed immediately after Save loads and before consumers | ADR-0002 ✅ Covered |
| TR-settings-accessibility-004 | F2 tilt_sensitivity_validate: valid iff finite and > 0; clamp to [min,max] if valid else default; was_corrected logged once as SETTING_CLAMPED (WARNING, key tilt_sensitivity); applied at boot and on every runtime set_value; cor... | GDD-owned |
| TR-settings-accessibility-005 | set_value(key,value): no-op if equal to current (no write, no event); else update memory, call set_value_seam immediately, emit setting_changed(key, new_value) once; returns failure for unknown key | ADR-0007 ⚠️ Partial |
| TR-settings-accessibility-006 | If set_value_seam returns false the in-memory value still updates and setting_changed still fires (no rollback, no retry) | GDD-owned |
| TR-settings-accessibility-007 | Six typed getters get_haptics_enabled, get_haptics_intensity, get_tilt_sensitivity, get_reduced_motion_enabled, get_colorblind_safe_enabled, get_seam_contrast_scale; none touches a seam after construction | GDD-owned |
| TR-settings-accessibility-008 | seam_contrast_scale = 0.0 if reduced_motion_enabled else 1.0 (SettingsMath static, binary, never intermediate); derived, not stored | GDD-owned |
| TR-settings-accessibility-009 | setting_changed(key, value) signal plus getter are both REQUIRED for the two live consumers (Tube Track seam scale, Environment ball luminance); both consumers also read the getter at construction/map load (no reliance on signa... | ADR-0003 ✅ Covered |
| TR-settings-accessibility-010 | Settings sends no requests to Platform Services/Tilt Input/Tube Track and has no run-phase awareness; constructor accepts no consumer-shaped seams; deterministic (no randomness) | GDD-owned |
| TR-settings-accessibility-011 | SettingsCore/SettingsMath contain no ConfigFile, FileAccess, DirAccess, Input., DisplayServer., Engine., Time., OS., get_tree and no autoload entry | GDD-owned |
| TR-settings-accessibility-012 | haptics_enabled and haptics_intensity are supplied to PlatformCore (set_haptics_enabled setter; intensity setter unnamed); Platform Services clamps haptics_intensity itself, so Settings does not validate it | ADR-0006 ✅ Covered |
| TR-settings-accessibility-013 | Shipped defaults and SENSITIVITY_MIN/MAX referenced as 0.5/2.0 are checked only by an ADVISORY smoke test; fixture uses 0.4/2.6/1.3 and stored values differing from defaults | GDD-owned |
| TR-settings-accessibility-014 | Settings screen owned by Menus & Screen Flow (Menu-only reachability); Menus reads all getters and calls set_value on each toggle/slider change | GDD-owned |
| TR-settings-accessibility-015 | Fixture factories make_settings_fixture, make_get_value_stub, make_set_value_stub(succeeds), make_log_spy, make_settings_core; tests in tests/unit/settings_accessibility/ named settings_accessibility_[feature]_test.gd; no [N] o... | ADR-0009 ✅ Covered |

**Partial or gap requirements:** stories for these carry the open point named in `docs/architecture/architecture-traceability.md` (Partial Coverage) and are marked Blocked until it is closed.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/settings-accessibility.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [SettingsMath (seam contrast, sensitivity validation)](story-001-settings-math.md) | Logic | Complete | ADR-0002 |
| 002 | [SettingsCore construction, fixtures, boot read](story-002-core-construction-boot-read.md) | Logic | Complete | ADR-0002 |
| 003 | [Boot-time sensitivity validation and logging](story-003-boot-sensitivity-clamp.md) | Logic | Ready | ADR-0002 |
| 004 | [Typed getters, no seam access after construction](story-004-getters.md) | Logic | Ready | ADR-0002 |
| 005 | [set_value write, no-op, setting_changed](story-005-set-value-write-and-event.md) | Logic | Ready (GDD Core Rule 5 amended 2026-10-03) | ADR-0007 |
| 006 | [Runtime sensitivity validation, unknown key](story-006-runtime-validation-unknown-key.md) | Logic | Ready | ADR-0002 |
| 007 | [Failed write keeps in-memory value](story-007-write-failure.md) | Logic | Ready | ADR-0007 |
| 008 | [No consumer seams, call surface, determinism](story-008-isolation-determinism.md) | Logic | Ready | ADR-0002 |
| 009 | [Architecture and coupling lint](story-009-architecture-lint.md) | Logic | Ready | ADR-0009 |
| 010 | [Shipped defaults smoke (advisory)](story-010-defaults-smoke.md) | Config/Data | Ready | ADR-0009 |
| 011 | [Real Save round trip](story-011-save-roundtrip-integration.md) | Integration | Ready | ADR-0007 |
| 012 | [Composition wiring, haptics push, live consumers](story-012-composition-and-consumers.md) | Integration | Ready | ADR-0002 |

## Next Step

Run `/story-readiness production/epics/settings-accessibility/story-001-settings-math.md`, then `/dev-story`.
