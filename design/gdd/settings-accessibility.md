# Settings & Accessibility

> **Status**: Designed (2026-09-29), pending independent `/design-review`. Revised 2026-10-01 after `/review-all-gdds` (S4): the getter plus `setting_changed` are now required for both live consumers.
> **Author**: user + agents
> **Last Updated**: 2026-10-01
> **Implements Pillar**: Pillar 4 (One-Thumb Simplicity) — secondary; no pillar names accessibility directly, but this system exists to keep game-concept.md's own Target Player Profile ("what would turn them away": controls that require two hands, disorienting camera) from actually turning anyone away.

## Overview

Settings & Accessibility holds the small set of player-adjustable preferences that make the game playable the way a given player needs it to be — a haptics on/off switch, a reduced-haptics intensity slider, a tilt sensitivity multiplier for players with limited wrist range, a reduced-motion toggle, and a colorblind-safe toggle — and supplies each one, read-only, to whichever system already defined the hook for it: Platform Services' `haptics_enabled` switch and `haptics_intensity` scalar, Tilt Input's `sensitivity` divisor, and Tube Track's `seam_contrast_scale` reduced-motion hook. It owns nothing about what a setting *does* once supplied — Tilt Input decides what a sensitivity of 2.0 actually changes about the steering math, Tube Track decides what a flattened seam looks like — this system only owns which value each toggle currently holds, and getting the player's chosen values in and out of Save & Persistence's own `[settings]` section correctly. It exists because game-concept.md's own Target Player Profile names players who'd be turned away by "controls that require two hands" or "unfair/random deaths," and because a game that locks reduced-motion or colorblind support behind nothing at all excludes players this genre otherwise welcomes — without this system, every upstream GDD's already-reserved accessibility hook (Tube Track's Open Question 11 on the seam flash rate, Tilt Input's sensitivity range) would have nothing supplying it a real value. It decides nothing about hazard silhouette design (Obstacle System / the art bible), the tilt math itself (Tilt Input), or how a settings screen looks (Menus & Screen Flow) — it owns exactly the current value of each toggle, and moving that value to and from disk.

## Player Fantasy

**The fantasy.** The game meets me where I am — I'm not fighting my own wrist, my own eyes, or a phone buzzing in my pocket just to play it the way everyone else does.

**What the player feels.**
- **My reach isn't the limit.** If my wrist doesn't move as far as someone else's, a sensitivity setting closes that gap instead of asking me to somehow tilt further (Tilt Input's own reasoning: "useful for players with limited wrist range").
- **The world doesn't have to pulse at me.** If a flashing, moving seam pattern is uncomfortable or disorienting rather than readable, reduced motion turns it into something calmer without changing what actually kills me.
- **What I need to see, I can see.** A colorblind-safe toggle means hazard identification never quietly depends on me having ordinary color vision — the game already promises this "never relies on hue alone" (game-concept.md); this setting is where that promise becomes something the player can actually confirm and adjust for their own eyes.
- **Once I set it, it's set.** Every toggle is exactly where I left it the next time I open the game — I'm never re-explaining my own needs to the game every session (Save & Persistence's own promise; this system decides what gets asked for).

**Feelings to avoid.** A setting that resets or silently reverts; an accessibility toggle that feels like an afterthought bolted onto a settings screen rather than something the game actually respects everywhere it applies; a sensitivity or reduced-motion value that doesn't visibly do anything, leaving the player unsure whether it "worked."

**Serves the pillars.** No single pillar names accessibility directly, but Pillar 4 (One-Thumb Simplicity) and the Target Player Profile's own "what would turn them away" list (controls that require two hands, disorienting camera) both describe exactly the players this system exists to keep from being turned away.

## Detailed Design

### Core Rules

1. **Five settings, each a section-scoped key with a name, type, and default.** `haptics_enabled` (bool, default `true` — Platform Services' own default); `haptics_intensity` (float, default `1.0` — Platform Services' own default, added 2026-09-29 resolving Platform Services' own Open Question 16); `tilt_sensitivity` (float, default `1.0` — matches Tilt Input's own `sensitivity` default); `reduced_motion_enabled` (bool, default `false`); `colorblind_safe_enabled` (bool, default `false`). All five live in Save & Persistence's `[settings]` section.
2. **Naming resolved: `tilt_sensitivity` in storage, `sensitivity` at the Tilt Input boundary — the same value, two names for two different contexts.** Save & Persistence's own already-shipped fixture names the stored key `tilt_sensitivity`; Tilt Input's own GDD names its runtime hook `sensitivity`. This GDD is the source of truth for the stored name — `tilt_sensitivity` — and Tilt Input's own consuming code reads it under its own internal name; this is a naming boundary, not a data conflict, and no cross-file rename is needed on either side.
3. **Read at boot, synchronously, right after Save & Persistence, through three named, injected seams.** `SettingsCore` is constructed immediately after Save & Persistence loads (mirroring Save & Persistence's own Rule 4 "read at boot, before any dependent system starts"), driven entirely through `get_value_seam(section, key, default) -> Variant`, `set_value_seam(section, key, value) -> bool`, and `log_sink(level, code, key, message)` — three named `Callable`s standing in for Save & Persistence's own `get_value`/`set_value` (mirroring Save & Persistence's own Core Rule 2 and Scoring & Personal Best's Core Rule 7 named-seam pattern). At construction, all five values are read via `get_value_seam("settings", key, default)` — one call per key, each falling back to its own default on a missing key, a type mismatch, or a corrupt file (Save & Persistence's own per-key fallback, Save & Persistence Rule 7), with no extra logic needed here beyond supplying the right default per key.
4. **`tilt_sensitivity` is validated against Tilt Input's own registered safe range (F2) both at boot and on every runtime change — layered defense, not a duplicate requirement.** `SettingsCore`'s constructor accepts `sensitivity_min`, `sensitivity_max`, and `default_sensitivity` as parameters (defaulting to Tilt Input's own shipped `SENSITIVITY_MIN`/`SENSITIVITY_MAX`, 0.5/2.0, and this system's own `1.0`) rather than hardcoding them, so they can be exercised at a fixture-distinct range in tests without touching the shipped constants. F2's validation runs both when the stored value is read at boot **and** whenever `set_value("tilt_sensitivity", new_value)` is called at runtime (Rule 5) — a value outside range, non-finite, zero, or negative is corrected the same way in both cases, logged once (`SETTING_CLAMPED`, level `WARNING`) each time a correction actually happens. Tilt Input's own Edge Cases already clamp a bad `sensitivity` defensively (NaN/zero/negative → 1) — this rule means that backstop should rarely, if ever, fire in practice, not that it becomes redundant or removable.
5. **Write immediately on every actual change, never on a no-op.** *(Revised 2026-10-03, ADR-0007 Decision 5 and ADR-0011: for a slider, the "change" is the committed value; Menus and Settings call `set_value` on the slider's `drag_ended`, never on every `value_changed`, because `set_value` has no coalescing and every call is a synchronous file write. Toggles commit on press.)* `set_value(key, new_value)` compares `new_value` against the current in-memory value first; if they're equal, nothing happens — no write, no event. If they differ, the in-memory value updates (passing `tilt_sensitivity` through F2 first, Rule 4), `set_value_seam("settings", key, new_value)` is called immediately (mirroring Save & Persistence's own Rule 5, "write immediately on every change," never deferred to a flush signal), and `setting_changed(key, new_value)` is emitted once.
6. **Consumers read the current value through six read-only getters, and the two live consumers also react to `setting_changed`; both are required for them.** Every setting has a typed getter — `get_haptics_enabled()`, `get_haptics_intensity()`, `get_tilt_sensitivity()`, `get_reduced_motion_enabled()`, `get_colorblind_safe_enabled()` — plus a sixth, `get_seam_contrast_scale()` (Rule 7), all callable at any time, and none of the six ever touches a seam after construction. `setting_changed` (Rule 5) is **required**, alongside the getter, for the two consumers that must take effect immediately while the game is already running or paused (review item S4): Tube Track (`get_seam_contrast_scale()`, read every frame or on `setting_changed`, so `reduced_motion_enabled` applies at once) and Environment & Theming (`get_colorblind_safe_enabled()` plus `setting_changed`, so the ball's luminance changes at once, which is visible in the Menu preview behind Settings). Both live consumers also read the getter when they are constructed (or the map loads), so they must not rely on `setting_changed` alone: a persisted value is in effect on the first frame (re-run W3). Every other consumer (Platform Services, Tilt Input, Menus) may use the getter alone.
7. **`seam_contrast_scale` is a derived value this system computes and exposes through its own getter, not a stored preference of its own.** Tube Track's own `seam_contrast_scale` tuning knob (range `[0, 1]`, "set by Settings") is produced here from the stored `reduced_motion_enabled` boolean via `get_seam_contrast_scale()` (Rule 6): `0.0` when `reduced_motion_enabled` is `true` (flattens the seam to match the tube surface, Tube Track's own description), `1.0` (Tube Track's own shipped default, unchanged) when `false`; Tube Track reads it every frame (or on `setting_changed`), so the change is immediate — resolving Tube Track's Open Question 11 as a binary opt-in, not a partial-scale slider: the general-population default stays at Tube Track's own already-Approved `SEAM_HZ_MAX` (3 Hz), and reduced motion is where a player who wants it removed entirely gets it removed entirely (user decision — see this GDD's own status note).
8. **`colorblind_safe_enabled` now has a real consumer.** Resolved 2026-09-29 (`environment-theming.md` Formula F3): Environment & Theming reads this value (getter plus `setting_changed`, both required, Rule 6) and applies the boosted luminance to the ball's own material immediately (Environment owns colours and materials in the MVP; Ball Movement is not a consumer), against the one flagged ball-vs-hazard contrast risk. Save & Persistence's `[settings]` section already reserved the slot before this consumer existed.
9. **No side effects beyond one write per actual change; deterministic.** Settings sends no requests to Platform Services, Tilt Input, or Tube Track — they read from it, never the reverse. It uses no randomness; given the same stored values, it always produces the same getter results and the same `seam_contrast_scale` derivation. It has no run-lifecycle awareness of its own — no phase, no `run_reset` handling — a setting can be read or changed regardless of what Run State's current phase is; whichever system owns the settings screen (Menus & Screen Flow) decides when the player is allowed to open it.

### States and Transitions

Settings & Accessibility has no phase or run-lifecycle of its own — unlike Ball Movement or Scoring, it is never gated by Run State's phase.

| Situation | Event | Settings does |
|-----------|-------|----------------|
| Boot | none | Reads all five settings from Save & Persistence, clamping `tilt_sensitivity` if out of range (Rules 3-4) |
| Any time after boot | `set_value(key, new_value)` | Updates memory and writes to disk immediately, only if the value actually changed (Rule 5); emits `setting_changed` |
| Any time after boot | a getter call (`get_*`) | Returns the current in-memory value; never touches disk |

### Interactions with Other Systems

| System | Direction | Data / events | Note |
|--------|-----------|----------------|------|
| Save & Persistence (Approved) | out / in | `get_value`/`set_value` for `[settings]`'s five keys | Hard dependency; read once at boot (Rule 3), written immediately on each actual change (Rule 5) |
| Platform Services (Approved) | out | `haptics_enabled`, `haptics_intensity` | Platform Services' own Dependencies table already lists this as a soft dependency; `haptics_intensity` added 2026-09-29, resolving its own Open Question 16 |
| Tilt Input (In Review) | out (provisional) | `tilt_sensitivity`, exposed under Tilt Input's own `sensitivity` name (Rule 2) | Tilt Input's own Dependencies table already lists this as a soft dependency; no change needed there |
| Tube Track (Approved) | out (provisional) | `seam_contrast_scale`, derived (Rule 7) | Tube Track's own Dependencies table already lists this as a soft dependency; the derivation itself (Rule 7) is new and resolves its Open Question 11. Tube Track reads it every frame or on `setting_changed` (both required, Rule 6), so reduced motion applies immediately |
| Menus & Screen Flow (Designed) | in / out | Reads every getter to populate a settings screen; calls `set_value` on every toggle/slider change | Hard dependency, per systems-index's own Dependency Map; resolved 2026-09-29 — Menu-only reachability (`menus-screen-flow.md` Core Rule 4) |
| Environment & Theming (Designed) | out | `colorblind_safe_enabled` (getter plus `setting_changed`, both required) | Resolved 2026-09-29 — consumed in `environment-theming.md` Formula F3 (ball-luminance boost, applied by Environment to the ball material); applies immediately (2026-10-01, S4); Rule 8's named gap is closed |

## Formulas

This system's logic is boolean/comparison, not continuous math — like Platform Services' F1/F2 and Save & Persistence's F1/F2, no specialist consultation was needed for this section.

**F1. `seam_contrast_scale` derivation (Core Rule 7)**

```
seam_contrast_scale = 0.0 if reduced_motion_enabled else 1.0
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `reduced_motion_enabled` | bool | `{true, false}` | The stored preference (Core Rule 1) |
| `seam_contrast_scale` | float | `{0.0, 1.0}` | The value handed to Tube Track's own `seam_contrast_scale` knob |

**Output range:** exactly `{0.0, 1.0}` — a strict two-valued function, never anything in between. Tube Track's own knob technically accepts the full `[0, 1]` range, but this system only ever produces the two endpoints for the MVP: a partial-scale slider was considered and rejected in favor of a binary opt-in (this GDD's own flash-safety decision, Core Rule 7) — the general-population default stays at Tube Track's own already-Approved 3 Hz seam rate, unaffected by this system.

**Example:** `reduced_motion_enabled` = `false` → `1.0` (Tube Track's own shipped default, unaffected); `reduced_motion_enabled` = `true` → `0.0` (the seam flattens to match the tube surface, Tube Track's own description of that value).

**F2. `tilt_sensitivity` read-time validation (Core Rule 4)**

```
is_valid          = is_finite(raw_value) and raw_value > 0
tilt_sensitivity  = clamp(raw_value, SENSITIVITY_MIN, SENSITIVITY_MAX) if is_valid else DEFAULT_SENSITIVITY
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `raw_value` | float | any (untrusted, from Save & Persistence's `get_value`) | The stored `tilt_sensitivity` exactly as read from disk, before validation |
| `SENSITIVITY_MIN` / `SENSITIVITY_MAX` | float | `0.5` / `2.0` shipped (Tilt Input's own registered safe range, referenced not owned — accepted as constructor parameters, Core Rule 4, so tests can exercise a fixture-distinct range) | Bounds for the clamp branch |
| `DEFAULT_SENSITIVITY` | float | `1.0` shipped (also a constructor parameter) | This system's own default (Core Rule 1) |
| `tilt_sensitivity` | float | `[0.5, 2.0]`, always | The value exposed to Tilt Input |

**Output range:** `[SENSITIVITY_MIN, SENSITIVITY_MAX]` = `[0.5, 2.0]`, unconditionally — `DEFAULT_SENSITIVITY` (1.0) itself already lies inside that range, so a `NaN`/`Infinity`/zero/negative `raw_value` still resolves to an in-range output, never a value the caller has to guard against separately. Any correction (whether a clamp or a fallback to default) is logged once, `SETTING_CLAMPED`, naming the key.

**Example:** `raw_value` = 1.0 → `1.0` (no correction, no log); `raw_value` = 5.0 → `2.0` (clamped, logged); `raw_value` = -1.0 → `1.0` (invalid, replaced by default, logged); `raw_value` = `NaN` → `1.0` (invalid, replaced by default, logged).

## Edge Cases

- **If no save file exists yet (first-ever launch)**: all five settings resolve to their own defaults (`haptics_enabled` = `true`, `haptics_intensity` = `1.0`, `tilt_sensitivity` = `1.0`, `reduced_motion_enabled` = `false`, `colorblind_safe_enabled` = `false`) via Save & Persistence's own "not an error, every `get_value` call returns the caller's default" contract — no special first-launch logic of its own (mirrors Scoring & Personal Best's own identical edge case).
- **If `Save & Persistence.set_value("settings", key, new_value)` fails (disk full, permission error — `WRITE_FAILED`)**: the in-memory value this system holds is still updated to the new value (Save & Persistence's own Core Rule 6 guarantee), and `setting_changed` still fires within the current session — only a cold boot before the next successful write would read back the old value from disk. This system does not retry or special-case the failure, trusting Save & Persistence's own contract (mirrors Scoring & Personal Best's identical edge case).
- **If a stored `tilt_sensitivity` is outside `[SENSITIVITY_MIN, SENSITIVITY_MAX]`, non-finite, zero, or negative (a hand-edited save file)**: F2 clamps it to the nearest bound, or replaces it with `DEFAULT_SENSITIVITY` (1.0) if it's non-finite/non-positive, logging one `SETTING_CLAMPED` either way — this happens once, at boot read time (Core Rule 4), not on every getter call.
- **If a stored value's type doesn't match what this system expects (`TYPE_MISMATCH`, e.g. `haptics_enabled` stored as a String)**: that one key falls back to its own default in isolation — a bad `haptics_enabled` does not also lose a good `tilt_sensitivity` or a good `reduced_motion_enabled` (Save & Persistence's own per-key fallback, Save & Persistence Rule 7 / F2).
- **If `set_value(key, new_value)` is called with a value equal to the current one**: a true no-op — no write to Save & Persistence, no `setting_changed` event (Core Rule 5). This is not an error; a settings screen that re-sends the current value on every frame the slider is held (rather than only on release) should not spam writes.
- **If `set_value` is called with a key this system doesn't recognize (a typo, or a future setting referenced before this GDD is updated to own it)**: rejected with one `UNKNOWN_SETTING_KEY` warning naming the key; no write happens and no new setting is silently created — the five keys in Core Rule 1 are the complete, fixed set for the MVP.
- **If `set_value("tilt_sensitivity", new_value)` is called at runtime with a value outside range, non-finite, zero, or negative** (e.g. a UI bug feeding a bad slider value): F2 corrects it the same way the boot read does (Rule 4) — clamped to the nearest bound if it's a finite positive out-of-range value, replaced by `default_sensitivity` otherwise — and logs one `SETTING_CLAMPED`; the corrected value, not the raw one, is what gets written and what `get_tilt_sensitivity()` returns afterward.
- **If `colorblind_safe_enabled` is toggled**: the stored value and its getter update normally (Core Rule 5); Environment & Theming's own Formula F3 now consumes it and re-derives the ball's own luminance (Core Rule 8, resolved 2026-09-29) and applies it to the ball material **immediately**, in any phase including the Menu preview behind Settings, on `setting_changed` (review item S4; `environment-theming.md` Open Question 4 resolved). Likewise `reduced_motion_enabled` takes effect at once because Tube Track reads `get_seam_contrast_scale()` every frame or on `setting_changed`.

## Dependencies

**Upstream (Settings & Accessibility needs these)**

| System | Type | What it needs | Note |
|--------|------|----------------|------|
| Save & Persistence (Approved) | Hard | `get_value`/`set_value` for `[settings]`'s five keys | Read once at boot (Rule 3), written immediately on each actual change (Rule 5) |
| Tilt Input (In Review) | Soft, reference-only | `SENSITIVITY_MIN`/`SENSITIVITY_MAX` (0.5/2.0) | Read as external constants for F2's clamp, never called at runtime |

**Downstream (these need Settings & Accessibility)**

| System | Type | What it needs |
|--------|------|-------|
| Platform Services (Approved) | Soft | `haptics_enabled`, `haptics_intensity` |
| Tilt Input (In Review) | Soft | `tilt_sensitivity`, under its own `sensitivity` name (Rule 2) |
| Tube Track (Approved) | Soft | `seam_contrast_scale`, derived (F1); getter plus `setting_changed` required (Rule 6) |
| Menus & Screen Flow (Designed) | Hard | Every getter, to populate a settings screen; `set_value` on every toggle change |
| Environment & Theming (Designed) | Soft | `colorblind_safe_enabled` (resolved 2026-09-29, Rule 8); getter plus `setting_changed` required (Rule 6) |

**Bidirectional consistency (checked against the existing GDDs)**
- **Save & Persistence:** already lists Settings & Accessibility as a Hard downstream dependent needing `get_value`/`set_value` for `[settings]` — consistent. Its own fixture and AC-11 previously referenced a placeholder `[settings].accessibility_mode` String key (default `"off"`) that this GDD's Core Rule 1 replaces with two independent booleans (`reduced_motion_enabled`, `colorblind_safe_enabled`) — the cross-file edit updating that fixture/AC to `[settings].reduced_motion_enabled` (bool, default `false`) has been applied.
- **Platform Services:** already lists Settings & Accessibility as an "in (soft)" dependency for `haptics_enabled` — consistent. `haptics_intensity` added 2026-09-29 (Juice & Feedback's own Formula/Tuning-Knobs session, resolving Platform Services' own Open Question 16's reduced-haptics half) — the cross-file edit to `platform-services.md` (Tuning Knobs, Formula F3, UI Requirements, Open Question 16) has been applied.
- **Tilt Input:** already lists Settings & Accessibility as an "in (soft)" dependency for `sensitivity` with the correct range (0.5–2.0, default 1) — consistent; the storage-name-vs-runtime-name distinction (Rule 2) is documentation only and needs no contract change there.
- **Tube Track:** already lists Settings & Accessibility as an "in" dependency for `seam_contrast_scale`, "Settings owns the value" — consistent. Its own Open Question 11 (the seam-flash-rate ruling) is resolved here (Formulas F1, Core Rule 7) — the cross-file edit marking it RESOLVED has been applied.
- **Systems index:** the Dependency Map already lists Settings & Accessibility as depending on Save & Persistence, Tube Track (soft), and Tilt Input (soft) — consistent with this GDD's own upstream table (Tube Track is referenced for its `seam_contrast_scale` semantics, the same reference-only relationship Tilt Input has); no edit needed.

**Provisional assumptions**: none remaining — Environment & Theming's own consumption of `colorblind_safe_enabled` and Menus & Screen Flow's own consumption shape (Menu-only, all 5 getters) are both resolved as of 2026-09-29.

## Tuning Knobs

**No designer tuning knobs today.** The five values this system holds (`haptics_enabled`, `haptics_intensity`, `tilt_sensitivity`, `reduced_motion_enabled`, `colorblind_safe_enabled`) are player-facing preferences, not designer-adjustable balance values — a player sets them, this system stores and supplies them, and there is nothing here for a designer to tune independently of what the player chooses. The two numeric ranges involved (`SENSITIVITY_MIN`/`SENSITIVITY_MAX`, 0.5–2.0, and `haptics_intensity`'s own `[0, 1]` range) are owned by Tilt Input and Platform Services respectively, only referenced here (F2 for the former) — widening or narrowing either is that owning GDD's decision, not this GDD's; Platform Services' own generic knob validation at load already clamps a bad `haptics_intensity` defensively, so no `F2`-style validation of it is needed here (unlike `tilt_sensitivity`, whose bad values would otherwise reach Tilt Input's own math unclamped).

**Fixed constants (not tuning knobs):** the five defaults (`haptics_enabled` = `true`, `haptics_intensity` = `1.0`, `tilt_sensitivity` = `1.0`, `reduced_motion_enabled` = `false`, `colorblind_safe_enabled` = `false`) — each chosen to match the value the consuming system already shipped as its own default (Platform Services' `haptics_enabled`/`haptics_intensity`, Tilt Input's `sensitivity`), not a value this GDD invented; `DEFAULT_SENSITIVITY` (F2, same as the `tilt_sensitivity` default).

**Sources of truth elsewhere:** `SENSITIVITY_MIN`/`SENSITIVITY_MAX` (Tilt Input); `seam_contrast_scale`'s own `[0, 1]` range and shipped default of `1.0` (Tube Track); `haptics_enabled`'s and `haptics_intensity`'s defaults and ranges (Platform Services).

## Visual/Audio Requirements

None owned here. Settings & Accessibility stores values and exposes getters and one event (`setting_changed`) — it renders nothing and plays no sound of its own. Whatever a settings screen looks or sounds like belongs entirely to Menus & Screen Flow.

## UI Requirements

No player-facing UI of its own — Menus & Screen Flow owns the actual settings screen. **UX Flag**: this system's five values are exactly the content a settings screen needs to exist for (a haptics toggle, a reduced-haptics intensity slider, a sensitivity slider, a reduced-motion toggle, a colorblind-safe toggle) — in Pre-Production, run `/ux-design` for the settings screen before writing epics, the same way Tilt Input flagged its own sensor-unavailable and sensitivity-setting needs. Stories that reference the settings screen should cite that UX spec, not this GDD directly.

## Acceptance Criteria

**Targets:** **[M]** `SettingsMath` — static pure functions: `seam_contrast_scale(reduced_motion_enabled)` (F1), `tilt_sensitivity_validate(raw_value, min, max, default) -> {value, was_corrected}` (F2). **[C]** `SettingsCore` (`RefCounted`) driven entirely through the three named seams (Core Rule 3) — `get_value_seam`, `set_value_seam`, `log_sink` — plus `sensitivity_min`/`sensitivity_max`/`default_sensitivity` accepted as constructor parameters (Core Rule 4). A real `SaveCore` is never touched. **No `[K]` tier**: Tuning Knobs states no designer-tunable knobs and no `*Config` resource exist for this GDD — nothing to preflight-validate. **[L]**: one architectural lint proving Rule 9 (no calls into Platform Services/Tilt Input/Tube Track — they only ever read from `SettingsCore`, never the reverse) and no engine coupling. **[I]** deferred: real Save & Persistence wiring; real consumer wiring. **No `[N]` tier**: Section C names no thin Node of its own — `SettingsCore` is constructed and driven directly by the composition root and by whatever calls `set_value` (Menus & Screen Flow), the same no-Node shape Scoring & Personal Best uses. **No `[V]`/device tier**: no continuous math beyond F1/F2, no rendering, no device-dependent behavior owned here. Tests live in `tests/unit/settings_accessibility/` and `tests/integration/settings_accessibility/`, named `settings_accessibility_[feature]_test.gd`. Exact `==` for bools, log codes, and `setting_changed` call counts; 1e-6 for `tilt_sensitivity` floats. A fresh core per case.

**Fixture** (`make_settings_fixture()`, a named factory, no `.tres` load): `SENSITIVITY_MIN_TEST` = 0.4, `SENSITIVITY_MAX_TEST` = 2.6, `TILT_SENSITIVITY_DEFAULT_TEST` = 1.3 (shipped: 0.5/2.0/1.0 — deliberately different so no AC can pass against a hardcoded shipped range). Stored raw values, deliberately different from Core Rule 1's shipped defaults so a "getter silently returns the default instead of the stored value" bug is caught: `HAPTICS_STORED_TEST` = `false` (shipped default `true`); `HAPTICS_INTENSITY_STORED_TEST` = `0.6` (shipped default `1.0`); `TILT_SENSITIVITY_STORED_TEST` = 1.75 (in-range under the fixture's own min/max); `REDUCED_MOTION_STORED_TEST` = `true` (shipped default `false`); `COLORBLIND_STORED_TEST` = `true` (shipped default `false`). `make_get_value_stub(stored: Dictionary)` returns a `get_value_seam` `Callable` plus a spy recording `(section, key, default)` per call; returns `stored[key]` if present, else the passed-in `default`. `make_set_value_stub(succeeds := true)` returns a `set_value_seam` `Callable` plus a spy recording `(section, key, value)` per call; returns `succeeds`. `make_log_spy()` records `(level, code, key, message)` tuples. `make_settings_core(get_value_seam, set_value_seam, log_sink, min := 0.5, max := 2.0, default := 1.0)` constructs a fresh `SettingsCore`.

**F1 — binary derivation (Core Rule 7)**
- **AC-1 [M]** `seam_contrast_scale(false)` == `1.0` exactly; `seam_contrast_scale(true)` == `0.0` exactly; both outputs individually asserted to be a member of the exact set `{0.0, 1.0}`, never anything between — a mutation that lerps or scales by any factor other than the two literal endpoints must fail.

**F2 — clamp/fallback (Core Rule 4)**
- **AC-2 [M]** `tilt_sensitivity_validate` table against `SENSITIVITY_MIN_TEST`/`SENSITIVITY_MAX_TEST`/`TILT_SENSITIVITY_DEFAULT_TEST` (0.4/2.6/1.3): `1.5` (mid-range) → `value=1.5, was_corrected=false`; `0.4` (== MIN, boundary inclusive) → `value=0.4, was_corrected=false`; `2.6` (== MAX, boundary inclusive) → `value=2.6, was_corrected=false`; `5.0` (above MAX) → `value=2.6, was_corrected=true`; `0.1` (positive, finite, below MIN) → `value=0.4, was_corrected=true` — clamped to MIN, **not** replaced by default; a mutation routing any below-MIN-but-positive value to DEFAULT instead of MIN must fail this row; `0.0` (not `> 0`) → `value=1.3, was_corrected=true`; `-2.0` → `value=1.3, was_corrected=true`; `NAN` → `value=1.3, was_corrected=true`; `INF` → `value=1.3, was_corrected=true`. A mutation that clamps `NAN`/`INF`/`0`/negative to MIN instead of falling back to DEFAULT must fail those four rows — this is the `is_valid` gate's own boundary, not the clamp's.
- **AC-3 [M]** Log behavior: the three no-correction rows (1.5, 0.4, 2.6) each produce zero `log_sink` calls; each of the six corrected rows produces exactly one `SETTING_CLAMPED` log (level `WARNING`) naming key=`"tilt_sensitivity"` — verified via call count and args, not inferred from the returned value alone.

**Boot read of all five settings, per-key isolation (Core Rule 3)**
- **AC-4 [C]** Construction calls `get_value_seam` exactly five times — once each for `("settings","haptics_enabled",true)`, `("settings","haptics_intensity",1.0)`, `("settings","tilt_sensitivity",TILT_SENSITIVITY_DEFAULT_TEST)`, `("settings","reduced_motion_enabled",false)`, `("settings","colorblind_safe_enabled",false)` — verified via spy call args, not merely call count; no single batched call for the whole section exists. A mutation that fetches all five in one call, omits a key, or passes the wrong default for any key must fail.
- **AC-5 [C]** Correct values on a fully-populated stub: constructed against `make_get_value_stub` with the fixture's five stored values — every getter returns exactly the fixture's stored value, never a default.
- **AC-6 [C]** Per-key isolation on a simulated missing/corrupt file (mirrors Save & Persistence's own per-key fallback): stub configured so `get_value_seam` returns the caller's own default for `"haptics_enabled"` only (simulating that key's `TYPE_MISMATCH` already resolved upstream by Save & Persistence) while the other four keys return their real fixture-stored values — `get_haptics_enabled()` reads back `true`; the other four getters are unaffected, still returning their real stored values. A companion row configures all five keys to return their defaults (a fully missing/corrupt file) and confirms all five getters read back Core Rule 1's own defaults with no cross-contamination or thrown error.

**Clamp applies once, at boot, not on every getter call (Core Rule 4, Edge Cases)**
- **AC-7 [C]** Construct with a stored `tilt_sensitivity` of `5.0` (above the fixture's MAX): `get_tilt_sensitivity()` returns the clamped value (`2.6`) on every one of several repeated calls, and `log_sink` records exactly one `SETTING_CLAMPED` call total across all of them — not one per getter call. A mutation that re-validates on every getter call must fail (it would either re-log, or diverge from the boot-time result if it re-derives from a stale raw value).

**Getters never touch disk (Core Rule 6, States table)**
- **AC-8 [C]** After construction (which legitimately calls `get_value_seam` five times, AC-4), call every one of the six typed getters (including `get_seam_contrast_scale()`) several times each (at least 10 calls total) — `get_value_seam`'s call count remains exactly 5 throughout, never incrementing after construction. A mutation that re-reads from the seam on any getter call must fail this AC by call count alone.

**Write immediately on actual change; no-op on an unchanged value (Core Rule 5)**
- **AC-9 [C]** `set_value("haptics_enabled", false)` where the current in-memory value is already `true`: `set_value_seam` is called exactly once with `("settings","haptics_enabled",false)`; the in-memory value updates; a subsequent `get_haptics_enabled()` returns `false`.
- **AC-10 [C]** `set_value("haptics_enabled", true)` called twice in a row where the current value is already `true` (a true no-op, both calls): zero `set_value_seam` calls and zero `setting_changed` emissions across both calls; a companion row exercises this for every one of the five keys, not just `haptics_enabled`, since Rule 5's no-op guarantee is stated as universal. A mutation that always writes regardless of equality must fail every row.

**`setting_changed` fires exactly once per actual change, never on a no-op (Core Rule 5)**
- **AC-11 [C]** A single actual change to any one key emits exactly one `setting_changed(key, new_value)` call with the correct key/value; the no-op scenario (AC-10) emits zero. A companion row sends three actual changes to three different keys in sequence and confirms three separate emissions, each with the correct key/value pair, not a batched or coalesced single emission.

**`tilt_sensitivity` validated on every runtime write, not only at boot (Core Rule 4, Edge Cases)**
- **AC-12 [C]** `set_value("tilt_sensitivity", 5.0)` (above the fixture's MAX, where the current value is in-range): the in-memory value becomes the clamped `2.6`, not the raw `5.0`; `set_value_seam` is called once with the **corrected** value, not the raw one; exactly one `SETTING_CLAMPED` log fires; `setting_changed` fires once with the corrected value. A mutation that writes the raw out-of-range value through unclamped must fail this AC.

**Unknown-key rejection (Edge Cases)**
- **AC-13 [C]** `set_value("haptics_enable", true)` (a typo) and `set_value("brightness", 0.5)` (a plausible future key not yet owned): both calls return failure, log exactly one `UNKNOWN_SETTING_KEY` warning naming the offending key, call zero `set_value_seam`, emit zero `setting_changed`, and leave every one of the six real getters completely unchanged from their pre-call values — no new setting is created and no existing one is perturbed. A mutation that silently no-ops without logging must fail the log-count assertion; a mutation that creates a new in-memory slot must fail a companion row checking the getter surface is still exactly the six named methods.

**Save & Persistence write-failure edge case (mirrors Scoring & Personal Best AC-14)**
- **AC-14 [C]** `make_set_value_stub(succeeds := false)`; `set_value("reduced_motion_enabled", true)` where the current value is `false`: `set_value_seam` is called once and returns `false`; the in-memory value still updates to `true` immediately (a subsequent `get_reduced_motion_enabled()` in the same session returns `true`, not the old value); `setting_changed` still fires once within the session. A mutation that rolls back the in-memory value on a failed write must fail this AC.

**No side effects beyond Core Rule 9's permitted calls**
- **AC-15 [C]** Enumerate `SettingsCore.new(...)`'s full constructor parameter list — only `get_value_seam`, `set_value_seam`, `log_sink`, `sensitivity_min`, `sensitivity_max`, `default_sensitivity` are ever accepted; nothing Platform-Services-, Tilt-Input-, or Tube-Track-shaped exists as a settable callable, mirroring Scoring & Personal Best's AC-11. A mutation that adds an unused, never-called seam shaped like one of those systems must still fail this AC — Rule 9 is "sends no requests... at all," not merely "never observed to."
- **AC-16 [C]** Across a full scripted session (construction, several `set_value` calls mixing actual changes, no-ops, an unknown key, an out-of-range value, and a failed write), spy every seam: the only calls made are `get_value_seam` (exactly 5, all at construction, AC-4/AC-8), `set_value_seam` (only on actual changes, AC-9/AC-10/AC-12/AC-14), and `log_sink` (only on `SETTING_CLAMPED`/`UNKNOWN_SETTING_KEY` events) — no other method or seam is ever invoked, and no seam is called with a section other than `"settings"`.

**Determinism (Core Rule 9)**
- **AC-17 [C]** Run the identical scripted sequence of boot values and `set_value` calls twice through two independently constructed cores — both cores' full sequence of getter return values, `setting_changed` emissions, and `log_sink` calls are identical call-for-call. No randomness is used anywhere in the fixture, so this is structural, not incidental.

**Architecture & coupling [L]**
- **AC-18 [L]** Static scan of `SettingsCore`'s and `SettingsMath`'s source: zero matches for `ConfigFile`, `FileAccess`, `DirAccess`, `Input.`, `DisplayServer.`, `Engine.`, `Time.`, `OS.`, `get_tree`, and zero direct references to Platform-Services-, Tilt-Input-, or Tube-Track-shaped symbols beyond the opaque key strings (`"haptics_enabled"` etc.) — no `[autoload]` entry for either class.

**Integration [I], deferred**
- **AC-19 [I], deferred** — real Save & Persistence wiring: a real `SaveCore` (not a stub) receiving `SettingsCore`'s `get_value`/`set_value` calls through the actual seam, confirming a changed setting round-trips through a real save/load cycle. No owner/date yet.
- **AC-20 [I], deferred** — real consumer wiring: Platform Services reading `get_haptics_enabled()`, Tilt Input reading `get_tilt_sensitivity()` under its own `sensitivity` name, and Tube Track reading `get_seam_contrast_scale()` each actually reflect a live setting change. No owner/date yet.

**Config/Data smoke, ADVISORY**
- **AC-21 [K, ADVISORY]** Shipped defaults and constants match Core Rule 1/Formulas: `haptics_enabled` default `true`; `haptics_intensity` default `1.0`; `tilt_sensitivity` default `1.0` (== `DEFAULT_SENSITIVITY`); `reduced_motion_enabled` default `false`; `colorblind_safe_enabled` default `false`; `SENSITIVITY_MIN`/`SENSITIVITY_MAX` referenced as 0.5/2.0 — the fixture deliberately uses 0.4/2.6/1.3 instead, so this smoke check is the only place the real shipped numbers are asserted.

**Gate policy.** AC-1 through AC-3 (`[M]`) and AC-4 through AC-17 (`[C]`) are Logic evidence — a pure-function/formula pair plus a dependency-injected state-holder core, the same bar Scoring & Personal Best's and Save & Persistence's own `[M]`/`[C]` rows set — **BLOCKING**, per `coding-standards.md`'s Logic row, no exceptions. AC-18 (`[L]`) is BLOCKING under the same Logic row, not a new category — identical precedent to Save & Persistence's AC-16/17 and Scoring's AC-10, both of which state `[L]` "is not a new evidence category." AC-19 and AC-20 (`[I]`) are Integration evidence with no named owner+date yet, so they remain **deferred**, not BLOCKING, per `coding-standards.md`'s Integration row — each becomes BLOCKING the moment it acquires a named owner and date. AC-21 (`[K]`, ADVISORY) is the sole Config/Data-row check in this set: Settings & Accessibility has no `*Config` resource and no designer tuning knobs, so this is the only place the four shipped defaults and the referenced `SENSITIVITY_MIN`/`MAX` get checked against a real number rather than a fixture-substituted one. There is no Visual/Feel or UI row — Visual/Audio Requirements and UI Requirements both state this system owns neither.

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | RESOLVED 2026-09-29 (`environment-theming.md` Core Rule 9 / Formula F3): `colorblind_safe_enabled` boosts the ball's own luminance (applied live to the ball material by Environment, 2026-10-01) away from the one flagged risk spot (ball-vs-hazard contrast, 1.03:1 base) to ≈1.4:1 — the achievable ceiling given both colors' already-locked floors elsewhere — never a full alternate palette or a UI-only recolor | — | Resolved |
| 2 | The exact settings-screen UX (layout, whether it's a single screen or split across tabs, how a slider vs. a toggle is presented) | ux-designer | `/ux-design`, Pre-Production |
| 3 | RESOLVED 2026-09-29 (`menus-screen-flow.md` Core Rule 4): Menu-only — the Settings screen is not reachable from the Paused screen or mid-run. This GDD's own Core Rule 9 places no phase restriction of its own; the restriction is Menus & Screen Flow's choice, not a change to this GDD's own contract | — | Resolved |
| 4 | On-device confirmation that a `tilt_sensitivity` value supplied through this system's clamp (F2) actually produces the intended feel change in Tilt Input, across the full 0.5–2.0 range | user, whoever runs the Tilt Input device spike | Alongside the Tilt Input on-device spike |
| 5 | Whether more accessibility toggles (text scaling, a one-handed control remap, a colorblind palette beyond the boolean flag) belong here post-MVP — this GDD scopes only the five values existing GDDs already anticipated, deliberately not a general accessibility platform | user | Post-MVP accessibility review |
| 6 | RESOLVED 2026-09-29 (`platform-services.md` Formula F3, Tuning Knobs, Open Question 16): `haptics_intensity` (float, 0-1, default 1.0) added as this GDD's fifth setting, supplying Platform Services' own reduced-haptics-intensity scalar; deliberately separate from `reduced_motion_enabled` (Juice & Feedback Core Rule 12 — haptic amplitude carries no photosensitivity risk) | — | Resolved |
