# Save & Persistence

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-09-28
> **Implements Pillar**: Pillar 5 (Skill First, Cosmetics Only) — makes personal progress durable across sessions without introducing purchasable advantage.

## Overview

Save & Persistence is the Core-layer system that turns a handful of small, cross-session facts — the personal best score/distance, the player's settings (haptics on/off, tilt sensitivity, accessibility toggles), and later cosmetic unlocks (Content Expansion tier) — into a file on disk, and reads them back at boot so a fresh launch starts where the last session left off. It is fully automatic: the player never sees a "Save" button or a loading spinner; the only thing they can feel is that a personal best they set an hour ago is still there. It exists because game-concept.md's own Session-Level retention hook — "die → see distance/score → immediately retry, chasing a personal best" — has no teeth if that personal best resets every cold start; without this system, the single most load-bearing long-term hook the MVP has (Pillar 5's "skill mastery is the primary long-term hook") would not survive being closed and reopened. It decides nothing about what the values *mean*: Scoring & Personal Best owns how a personal best is computed and when it updates, Settings & Accessibility owns what each preference does, and Cosmetics & Unlocks (later) owns what an unlock unlocks — this system only owns getting their values onto disk correctly, atomically, and back again, and telling those systems when a save has happened so they don't have to guess. Whether an in-progress run itself is ever persisted across an OS termination is not assumed here (run-state-restart.md's own Open Question 6 leaves it as "default: no" and hands the decision to this GDD) — Detailed Design resolves it as a real choice, not a silent default.

## Player Fantasy

**The fantasy.** None of its own. The player never sees this system, and its best result is that they never think about it. What they feel is what it makes possible: the phone remembers.

**What the player feels (indirectly).**
- **My personal best is mine, permanently.** The score/distance I fought for is exactly where I left it the next time I open the game — cold start, phone restart, app update, doesn't matter (Pillar 5: skill mastery as the primary long-term hook only works if the record of that mastery survives).
- **My settings stay set.** Haptics, tilt sensitivity, accessibility toggles — set once, never re-asked, never silently reset.
- **A crash or a forced-quit costs me at most the run I was mid-way through, never my history.** Losing an in-progress run to an OS kill is an accepted, bounded cost (Pillar 2 already treats an interruption as "never the player's fault" at the run level); losing yesterday's personal best to the same event would not be bounded, and this system's whole job is making sure that never happens.

**Feelings to avoid.** A personal best that resets after an update; a setting that silently reverts; a save that corrupts and takes the *entire* profile down with it (rather than failing safe to defaults); any save operation the player can feel as a stutter or a loading pause mid-session.

**Serves the pillars.** *Pillar 5, Skill First, Cosmetics Only*: this is the system that makes "skill mastery is the primary long-term hook" literally true across sessions, not just within one. It carries no direct fantasy of its own, the same way Platform Services does not — its value is entirely in what it lets Scoring, Settings, and (later) Cosmetics promise the player without that promise being a lie after a restart.

## Detailed Design

### Core Rules

1. **What is persisted, and by whom.** Save & Persistence stores a small set of key-value facts, grouped by section, one section per owning system: `[scoring]` (personal best value + the run's `run_id` or a timestamp, owned by Scoring & Personal Best), `[settings]` (haptics on/off, tilt sensitivity, accessibility toggles, owned by Settings & Accessibility), and — Content Expansion tier only, not MVP — `[cosmetics]` (unlock flags, owned by Cosmetics & Unlocks). Save & Persistence never invents a value or a default for another system's section; it stores exactly what that system hands it and returns exactly what it stored.
2. **Shape.** `PersistMath` (static functions, no state) holds the pure logic: `schema_compatible` (F1), `read_valid` and `read_error_code` (F2), `is_serializable_type`. `SaveCore` (`RefCounted`, no Node, no direct engine calls) holds the read/write orchestration against six injected seams — `config_reader(path)`, `config_writer(path, sections)`, `path_exists(path)`, `path_rename(from, to)`, `path_delete(path)` (each a `Callable`, faked in tests so the real filesystem is never touched), plus a monotonic `clock()` (for `SAVE_LOG_RATE_LIMIT`, real-time, never simulation time — the same rule Platform Services' own `clock` seam follows) and a `log_sink(level, code, key, message)`. A second, separate wall-clock source (`Time.get_datetime_string_from_system()` or equivalent, not the monotonic `clock()`) supplies the human-readable timestamp used in a corrupt-backup filename (Rule 7) — these are two different clocks with two different guarantees and must not be conflated. `SaveCore` wraps its own rate-limiting by reusing Platform Services' `RateLimitedLog` (its Core Rule 2) rather than reimplementing equivalent per-(code, key) windowing logic — one rate-limiter class, not two. A thin `SaveService` node in the main scene owns the real `ConfigFile`/`FileAccess`/`DirAccess` calls behind those seams, listens for Platform Services' `app_backgrounded`, and is the only thing that touches `user://`. No autoload: the composition root creates it and injects it into the systems that need it (coding standards: dependency injection over singletons), the same pattern Platform Services and every other Core-layer system already uses.
3. **Storage format: `ConfigFile`.** One file, `user://save.cfg`, one `ConfigFile` section per owning system (`[scoring]`, `[settings]`, `[cosmetics]`) plus one reserved section `[_meta]` holding `schema_version` (an integer, starts at 1). `ConfigFile` is Godot's own key-value persistence format, built for exactly this scale of data; using it (rather than hand-rolled JSON over raw `FileAccess`) avoids re-implementing parsing and gets Godot's own escaping/typing for free.
4. **Read at boot, synchronously, before any dependent system starts.** The composition root constructs `SaveService`, which loads `user://save.cfg` (if present) into memory before any of `Scoring & Personal Best`, `Settings & Accessibility`, or `Cosmetics & Unlocks` are constructed. Those systems read their section's values through `SaveCore`'s typed getters (`get_value(section, key, default)`) at their own construction time — no "save loaded" signal is needed, because the read has already completed by the time anything could ask.
5. **Write immediately on every change, plus a redundant safety flush on `app_backgrounded`.** Whenever an owning system calls `SaveCore.set_value(section, key, value)`, the write to disk happens right away (write-to-temp-then-rename, Rule 6) — the file is a few hundred bytes, so the cost is negligible and there is no reason to risk losing a same-session personal best waiting for a flush signal that might never come. Platform Services' `app_backgrounded` (its Core Rule 10: "the only flush signal Save & Persistence uses") is still honored — `SaveService` calls the same persist path on it — but it is a safety net against an internal bug that deferred a write, not the primary write trigger.
6. **Write-to-temp-then-rename.** A write serializes the in-memory `ConfigFile` to `user://save.cfg.tmp`, calls `ConfigFile.save()` on the temp path, checks its `Error` return (and, per the Godot 4.4+ `FileAccess.store_*` change, treats a `false`/non-`OK` return the same as a thrown error — never silently ignored), and only then renames `user://save.cfg.tmp` over `user://save.cfg` via `DirAccess.rename()`. A crash or power loss between "wrote temp" and "renamed" leaves the previous, valid `save.cfg` untouched; a crash before the temp write completes leaves it untouched too. The rename step itself is the only non-recoverable instant, and it is the shortest possible operation (a filesystem rename, not a data write). Either seam call failing (`config_writer` or `path_rename` returning false/non-OK) logs one `WRITE_FAILED` error, rate-limited per section+key (Rule 2's shared `RateLimitedLog`), and reports failure to the caller; the in-memory value is still updated (Edge Cases).
7. **Corrupt or unreadable save: fail safe to defaults, never crash.** If `user://save.cfg` fails to parse (`FILE_UNREADABLE`) or its schema is incompatible (`SCHEMA_INCOMPATIBLE`, F1) the whole file is treated as invalid and every key returns its caller-supplied default; if the file parses and the schema is compatible but one specific key's stored type doesn't match what the caller expects (`TYPE_MISMATCH`), only that key falls back to its default — a bad `[settings].haptics_enabled` value does not also lose a good `[settings].tilt_sensitivity` or a good `[scoring]` section. A key that is simply absent (never written yet, e.g. a new key added mid-development with no migration) is not an error at all and logs nothing (Edge Cases) — this is normal, expected growth, not corruption. The old corrupt or incompatible file is renamed aside — `save.cfg.corrupt-<unix_time_from_the_wall_clock>-<n>`, where `<n>` is a zero-based counter that increments only if a backup with that exact second's timestamp already exists (so two corruptions inside the same wall-clock second never collide and silently overwrite each other) — rather than being overwritten immediately, so it survives for a bug report. `CORRUPT_BACKUP_RETENTION` (Tuning Knobs) caps how many such backups accumulate; the oldest is deleted once the cap is exceeded.
8. **No mid-run persistence (resolves run-state-restart.md Open Question 6: "no").** Save & Persistence has no interface to Run State & Restart and reads no in-run values (`theta`, `s`, phase, etc.). An in-progress run killed by the OS is lost entirely, exactly as Run State's own Open Question 6 default already assumed; only a run's *result*, once it reaches Scoring & Personal Best, is ever persisted. This is a deliberate scope decision, not an oversight: it keeps this system's failure surface small (a handful of scalar values, not a live simulation snapshot) and nothing in the game's pillars asks for resumable runs.
9. **No side effects beyond storage.** Save & Persistence never calls into Scoring, Settings, or Cosmetics; those systems call into it. It owns no game logic and makes no judgment about whether a value is "good" (e.g. it never compares a new score against the old personal best — that comparison is Scoring's).

### States and Transitions

Save & Persistence has no run-phase awareness of its own (it does not know or care about Run State's phase); its only lifecycle is the load-then-ready sequence below.

| Situation | Event | Save & Persistence does |
|-----------|-------|--------------------------|
| Boot | none | Loads `user://save.cfg` synchronously (Rule 4), before dependent systems are constructed |
| Any time after boot | `set_value(section, key, value)` | Updates memory, writes to disk immediately (Rules 5-6) |
| Any time after boot | `app_backgrounded` (from Platform Services) | Redundant safety flush; a no-op if nothing is pending |
| At boot, or at any read | file missing, corrupt, or schema mismatch | Whole file treated as invalid, every key returns its default (`FILE_UNREADABLE`/`SCHEMA_INCOMPATIBLE`); a single key with the wrong stored type falls back alone (`TYPE_MISMATCH`), siblings unaffected (Rule 7); never crashes |
| A write fails (disk full, permission error) | mid-write I/O error | Logs one `WRITE_FAILED`, keeps the last known-good in-memory values and the last known-good file on disk untouched (Rule 6); the caller's `set_value` reports failure so the owning system can decide whether to retry or warn |

### Interactions with Other Systems

| System | Direction | Data / events | Note |
|--------|-----------|----------------|------|
| Platform Services | in | `app_backgrounded` | The one external signal this system listens for (Rule 5); Save & Persistence never calls back into Platform Services |
| Scoring & Personal Best | in/out | `get_value`/`set_value` for the `[scoring]` section | Scoring decides what counts as a new personal best; Save & Persistence only stores the result |
| Settings & Accessibility | in/out | `get_value`/`set_value` for the `[settings]` section | |
| Cosmetics & Unlocks (Content Expansion) | in/out | `get_value`/`set_value` for the `[cosmetics]` section | Not read or written until that system exists; the section is reserved, not created early |
| Run State & Restart | none | — | Explicitly no interface (Rule 8); resolves Run State's Open Question 6 |

## Formulas

This system's logic is boolean/comparison, not continuous math — like Platform Services' F1/F2, no specialist consultation was needed for this section.

**F1. Schema compatibility check**

```
compatible = (0 < schema_version <= CURRENT_SCHEMA_VERSION)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Read schema version | `schema_version` | int | any (untrusted, from disk) | the `[_meta].schema_version` value found in the loaded file, or 0 if the key is missing |
| Current schema version | `CURRENT_SCHEMA_VERSION` | int | `>= 1`, fixed per build | the schema this build's code understands; 1 at MVP |

**Output range:** boolean. `schema_version` of 0 (missing key) or negative (corrupt) is never compatible. `schema_version > CURRENT_SCHEMA_VERSION` (a save written by a newer build, e.g. after a downgrade) is never compatible — treated the same as corrupt (Rule 7), never partially trusted. A future `schema_version < CURRENT_SCHEMA_VERSION` is where a migration step would run (none exists yet at `CURRENT_SCHEMA_VERSION = 1`; this is the seam Content Expansion's schema growth will use). **Example:** at MVP, `CURRENT_SCHEMA_VERSION = 1`; a file with `schema_version = 1` is compatible; a file with `schema_version = 2` (a future build's save opened by this one) or `schema_version = 0`/missing is not.

**F2. Per-key read validity**

```
valid(section, key) = file_parsed_ok and compatible and has_key(section, key) and type_matches(section, key, expected_type)
```

A value is only ever handed to a caller when `valid` is true; otherwise `get_value(section, key, default)` returns the caller's own `default`. Three of the four factors, when false, log one error naming the section/key/reason (`FILE_UNREADABLE`, `SCHEMA_INCOMPATIBLE`, `TYPE_MISMATCH`, checked in that precedence order when more than one is false at once — a parse failure or schema mismatch is reported once for the file, not repeated per key). `has_key` being false logs nothing at all (Rule 7, Edge Cases): a key simply not present yet is normal growth, not a failure, and is never confused with a key that is present but wrong-typed.

| Variable | Symbol | Type | Description |
|----------|--------|------|-------------|
| Parse result | `file_parsed_ok` | bool | true iff `ConfigFile.load()` returned `OK` |
| Schema check | `compatible` | bool | F1 |
| Key presence | `has_key(section, key)` | bool | true iff the section/key pair exists in the parsed file |
| Type check | `type_matches(...)` | bool | true iff the stored `Variant` type matches what the caller declared it expects |

**Output range:** boolean, per key, evaluated independently — this is why Rule 7's fallback is per-key, not all-or-nothing: one key failing `type_matches` does not make a sibling key in the same section invalid.

## Edge Cases

- **If no save file exists yet (first-ever launch)**: not an error — every `get_value` call returns the caller's default, `[_meta].schema_version` is treated as absent (F1: not compatible, but for the specific reason "no file", logged once at `INFO` not `ERROR`), and the very first `set_value` call creates `user://save.cfg` for the first time via the normal write-to-temp-then-rename path.
- **If the app is killed between writing `save.cfg.tmp` and renaming it over `save.cfg`**: the old `save.cfg` is untouched and loads normally next launch; the orphaned `.tmp` file is deleted (if found) the next time a write starts, before the new temp write begins.
- **If the app is killed during the temp-file write itself (mid-`ConfigFile.save()`)**: the temp file may be partial or invalid; `save.cfg` itself was never touched, so it still loads normally. The stale/partial `.tmp` is deleted on the next write attempt (same as above).
- **If `user://` itself is not writable (rare: storage full, permission revoked)**: every `set_value` call fails with one `WRITE_FAILED` (Rule 6), rate-limited per section+key via the shared `RateLimitedLog` (Rule 2) so ten rapid calls for the same key log once, not ten times, and the in-memory value is still updated so the current session behaves correctly — only the *next* launch loses the unsaved change.
- **If a section is written by more than one system (a mistake — ownership is meant to be one system per section)**: Save & Persistence does not detect or prevent this at runtime (it has no manifest of "which system owns which section," unlike Platform Services' settings manifest); this is a code-review/architecture concern, not a Save & Persistence check. Flagged in Open Questions as a possible future CI lint if it becomes a real problem.
- **If a caller asks for a key that was never written (a new key added mid-development, no migration yet)**: behaves exactly like a missing file — the caller's default is returned, no error is logged (this is the normal, expected way new settings/values are introduced; only a *type mismatch* on an *existing* key is logged as `TYPE_MISMATCH`).
- **If `set_value` is called with a value type Godot's `ConfigFile` cannot serialize (e.g. a raw `Object` reference)**: rejected before any write is attempted, with one `UNSERIALIZABLE_VALUE` error naming the section/key; the in-memory store is not updated either, so a caller cannot end up in a state where memory and disk silently disagree about a value's type.
- **If `app_backgrounded` fires while a `set_value`-triggered write is already in progress**: impossible in practice (GDScript is single-threaded and writes are synchronous, Rule 5/6), so the safety flush simply finds nothing pending and no-ops; stated here so a future async rewrite doesn't silently introduce a race this design never had.

## Dependencies

**Upstream (Save & Persistence needs these)**

| System | Type | What it needs | Note |
|--------|------|----------------|------|
| Platform Services (Approved) | Soft | `app_backgrounded` signal | Redundant safety flush only (Rule 5); Save & Persistence works correctly even if this signal never arrives, since every write is already immediate |

**Downstream (these need Save & Persistence)**

| System | Type | What it needs |
|--------|------|-------|
| Scoring & Personal Best | Hard | `get_value`/`set_value` for `[scoring]` |
| Settings & Accessibility | Hard | `get_value`/`set_value` for `[settings]` |
| Menus & Screen Flow | Soft | Reads settings values indirectly through Settings & Accessibility, not directly from Save & Persistence |
| Cosmetics & Unlocks (Content Expansion) | Hard, not yet active | `get_value`/`set_value` for `[cosmetics]`, reserved but unused until that GDD exists |

**Bidirectional consistency (checked against the existing GDDs)**
- **Platform Services**: already lists Save & Persistence as a "Hard (index)" dependent needing `app_backgrounded` as the flush signal (its Dependents table) and states in its own Core Rule 10 that it "does no saving and does not wait for it." Consistent — no edit needed. This GDD's Rule 5 is stricter than Platform Services requires (writes immediately, treats the signal as a safety net, not the trigger), which satisfies Platform Services' contract without depending on it.
- **Run State & Restart**: its Open Question 6 ("is a run in progress persisted across OS termination? default: no") is resolved by this GDD's Core Rule 8 as "no" — no interface exists between the two systems. A cross-file edit to `run-state-restart.md` (marking Open Question 6 RESOLVED, pointing here) is proposed at the end of this session.
- **Systems index**: row for Save & Persistence already lists "Platform Services" as its sole dependency — consistent, no edit needed there. Scoring & Personal Best, Settings & Accessibility, and Cosmetics & Unlocks already list Save & Persistence as a dependency in the Dependency Map — consistent.

**Provisional assumptions**: the exact `get_value`/`set_value` call signature (typed accessors vs. a generic `Variant`-typed pair) is fixed here as a seam, but Scoring/Settings/Cosmetics's own GDDs, once authored, may want typed wrapper methods layered on top — that's their choice to make, not a change to this contract. The composition-root wiring order (Save & Persistence constructed and loaded before Scoring/Settings/Cosmetics) is asserted here (Rule 4) but not yet owned by any written game-loop/composition ADR.

## Tuning Knobs

| Knob | Default | Safe range | Affects | Too low | Too high |
|------|---------|------------|---------|---------|----------|
| `SAVE_LOG_RATE_LIMIT` | 1.0 s | 0.5-5.0 | Minimum time between two identical error logs for the same section+key (Edge Cases: repeated write failures) | Log spam on a sustained failure (e.g. storage full while the player keeps adjusting a settings slider) | A real, ongoing failure goes unnoticed for longer between log lines |
| `CORRUPT_BACKUP_RETENTION` | 5 | 1-20 | How many `save.cfg.corrupt-<timestamp>` files are kept before the oldest is deleted (Edge Cases, Rule 7) | Loses an old corrupt-save bug report sooner | Unbounded disk growth if corruption recurs across many sessions |

**Fixed constants (not tuning knobs):** `CURRENT_SCHEMA_VERSION` (1 at MVP — a build-locked value, not a designer knob; bumping it is a data-format decision, not tuning); the save file path (`user://save.cfg`); the section names (`[scoring]`, `[settings]`, `[cosmetics]`, `[_meta]`) — these are correctness-critical identifiers, not values to tune.

**Knob interactions:** none — these two knobs are independent of each other and of every other system's tuning knobs (this system introduces no shared constants with Ball Movement, Tube Track, or any gameplay system).

**Sources of truth elsewhere:** none — Save & Persistence owns both knobs outright; no other GDD references or constrains them.

## Visual/Audio Requirements

None. Save & Persistence has no visuals and no audio of its own, the same as Platform Services — nothing about a save or load is ever presented to the player directly (no loading spinner, no "saved" toast). If a future system wants a "settings saved" confirmation cue, that cue belongs to whichever UI system requests it (Menus & Screen Flow / HUD), not to this system.

## UI Requirements

No player-facing UI of its own. No requests to other systems beyond what Dependencies already states (`get_value`/`set_value` calls from Scoring, Settings, and later Cosmetics). No UX Flag: there is no screen or HUD element of its own to specify.

## Acceptance Criteria

**Targets:** **[M]** `PersistMath` static pure functions (F1 `schema_compatible`, F2 `read_valid` and `read_error_code`, `is_serializable_type`); **[C]** `SaveCore` (`RefCounted`) with injected seams `config_reader(path)`, `config_writer(path, sections)`, `path_exists(path)`, `path_rename(from, to)`, `path_delete(path)`, `clock()`, `log_sink(level, code, key, message)` — all fakes/spies, the real filesystem is never touched; **[N]** the thin `SaveService` node with a spy `SaveCore` and a stub signal source standing in for Platform Services; **[I]** integration, deferred; **[L]** CI lint in `tools/ci/`. Tests live in `tests/unit/save_persistence/` and `tests/integration/save_persistence/`, named `save_persistence_[feature]_test.gd`. Exact `==` for log codes, counts and integers; 1e-6 for other floats. A fresh core per case.

**Fixture** (`make_save_fixture()`, a named factory, no `.tres` load): `CURRENT_SCHEMA_VERSION_TEST` = 3 (shipped default is 1 — deliberately different so no AC can pass against a hardcoded "1"); `SAVE_LOG_RATE_LIMIT_TEST` = 0.05 s (shipped default 1.0 s); `CORRUPT_BACKUP_RETENTION_TEST` = 3 (shipped default 5). Keys: `[scoring].personal_best` (int, default 0), `[settings].haptics_enabled` (bool, default true), `[settings].tilt_sensitivity` (float, default 1.0), `[settings].accessibility_mode` (String, default `"off"`, deliberately never present in the loaded fixture file — the "new key, no migration" case), `[_meta].schema_version` (int). Paths: `REAL_PATH` = `user://save.cfg`, `TMP_PATH` = `user://save.cfg.tmp`. `config_reader` returns `{status: "OK"|"MISSING"|"PARSE_ERROR", sections: Dictionary}`; `config_writer`/`path_rename` return bool (false = the "treat as thrown error" case, Rule 6).

**Schema & read validity (F1, F2)**
- **AC-1 [M]** `schema_compatible(schema_version, CURRENT_SCHEMA_VERSION_TEST=3)`: 0 (missing key) -> false; -1 -> false; 1, 2, 3 -> true (a past version is compatible with no migration, per F1's own stated seam); 4 -> false (a newer build's save, never partially trusted).
- **AC-2 [M]** `read_valid(file_parsed_ok, compatible, has_key, type_matches)` truth table: all true -> true; each single factor false (others true) -> false, one row per factor; all false -> false — confirms independent per-key AND semantics, not short-circuit-only coverage.
- **AC-3 [M]** `read_error_code(...)` precedence (fixed 2026-09-28: `file_parsed_ok` > `compatible` > `type_matches`; `has_key` false is never logged, per Rule 7/Edge Cases): `(false, true, true, true)` -> `FILE_UNREADABLE`; `(true, false, true, true)` -> `SCHEMA_INCOMPATIBLE`; `(true, true, false, true)` -> no code, no log; `(true, true, true, false)` -> `TYPE_MISMATCH`; `(false, false, true, true)` -> `FILE_UNREADABLE` (higher precedence wins).

**Storage & write path (Core Rules 1, 3, 5, 6)**
- **AC-4 [C]** Section ownership, no invented defaults (Rule 1): `get_value`/`set_value` round-trip for `[scoring]`, `[settings]` and `[cosmetics]` each return exactly what was stored; on any read failure, the returned value is exactly the caller's own `default` argument, never a value `SaveCore` supplies on its own.
- **AC-5 [C]** Synchronous boot read (Rule 4): construct `SaveCore` with `config_reader` returning a populated fixture file; immediately, with no signal and no frame elapsed, `get_value` for every fixture key returns the loaded value — proving the load is complete before any dependent system's construction could possibly ask.
- **AC-6 [C]** Immediate write, no batching (Rule 5): one `set_value` call synchronously calls, in order, `config_writer(TMP_PATH, sections)` then `path_rename(TMP_PATH, REAL_PATH)`, both before `set_value` returns; `sections` includes the changed key's section plus `[_meta].schema_version`; no timer or frame-count mechanism is exercised.
- **AC-7 [C]** Safety flush is a true no-op today (Rule 5, Edge Case 8): calling the `app_backgrounded` persist-path with nothing pending (writes are already synchronous) produces zero seam calls — this is the tested behavior backing the GDD's "impossible in practice" claim, so a future async rewrite that silently introduces a race fails this AC.
- **AC-8 [C]** Write-to-temp-then-rename error handling (Rule 6): `config_writer` returning false stops the sequence — `path_rename` is never called, `set_value` returns failure to the caller, one `WRITE_FAILED` is logged — but the **in-memory value is still updated** to the new value (Edge Case 4: only the *next* launch loses it, the current session behaves correctly); `path_rename` returning false likewise reports failure (`WRITE_FAILED`) without corrupting the in-memory state.
- **AC-9 [C]** Orphaned `.tmp` cleanup before the next write (Edge Cases: crash during/between temp-write and rename): if `path_exists(TMP_PATH)` returns true, the next `set_value` call invokes `path_delete(TMP_PATH)` before `config_writer(TMP_PATH, ...)`; if it returns false, `path_delete` is never called. This is the recoverable, next-write half of both crash edge cases; whether a real crash truly leaves `save.cfg` untouched on a real filesystem is Integration/device (AC-20, deferred).

**Corrupt/unreadable recovery (Core Rule 7, per-key fallback isolation)**
- **AC-10 [C]** Whole-file failure vs. per-key failure, three fixture rows: (1) `config_reader` status `PARSE_ERROR` -> every requested key across every section returns its default, one `FILE_UNREADABLE` per requested key at **ERROR**; (2) status `OK`, `[_meta].schema_version` = 4 (incompatible against `CURRENT_SCHEMA_VERSION_TEST` = 3) -> every requested key still returns its default (schema incompatibility invalidates the whole file, since F1 gates F2 for every key), one `SCHEMA_INCOMPATIBLE` per requested key; (3) status `OK`, compatible schema, `[settings].haptics_enabled` stored as a String -> `get_value("settings","haptics_enabled",...)` returns its default with one `TYPE_MISMATCH`, while `get_value("settings","tilt_sensitivity",...)` (same section, correctly typed) returns its real stored value with **no** error — the explicit per-key isolation case.
- **AC-11 [C]** Missing-key vs. corrupt-key distinction: `get_value("settings","accessibility_mode","off")` on a key never written in an otherwise valid file returns `"off"` and logs nothing; `get_value("settings","haptics_enabled",true)` where the key exists with the wrong type returns `true` and logs exactly one `TYPE_MISMATCH`.
- **AC-12 [C]** First launch / no file (Edge Case 1): `config_reader` status `MISSING` -> every `get_value` returns its default, exactly one log line at **INFO** (not ERROR — distinct from AC-10 row 1's `PARSE_ERROR`/ERROR case); the first `set_value` call afterward runs AC-9's cleanup check (finds nothing) then AC-6's normal write sequence, creating the file for the first time.

**Unwritable storage & backup rotation (Edge Cases, Tuning Knobs)**
- **AC-13 [M]/[C]** Unserializable value rejection: `PersistMath.is_serializable_type(value)` [M] is false for a raw `Object`/`RefCounted` reference, true for `int`, `float`, `String`, `bool`, `Vector2`, `Array`, `Dictionary`; `SaveCore.set_value` [C] given an unserializable value calls **no** seam at all, does **not** update the in-memory store (a later `get_value` for that key is unchanged from before the rejected call), logs exactly one `UNSERIALIZABLE_VALUE` naming section/key, and returns failure.
- **AC-14 [C]** Unwritable storage, rate-limited logging: with `config_writer`/`path_rename` seam-returning false on every call, ten consecutive `set_value` calls for the *same* section+key within `SAVE_LOG_RATE_LIMIT_TEST` (0.05 s) of each other on the injected clock produce exactly one `WRITE_FAILED` log for that section+key (not ten, via the shared `RateLimitedLog`); every one of the ten still updates the in-memory value (the tenth call's value is what a same-session `get_value` returns) and reports failure to its own caller. An eleventh call for a *different* key at the same clock stamp produces its own separate log line (keyed per section+key, not global).
- **AC-15 [C]** Corrupt-backup rotation and collision-safe naming (`CORRUPT_BACKUP_RETENTION`, Rule 7): on a `PARSE_ERROR` load, `path_rename` is called moving the old file to `save.cfg.corrupt-<wall_clock_unix_time>-<n>` before any new write proceeds; two corruption events whose injected wall-clock stamps land in the same second produce backup names differing only in `<n>` (0, then 1), never overwriting each other. At `CORRUPT_BACKUP_RETENTION_TEST` = 3, a fourth corruption event (four sequential cores against one recording seam) triggers exactly one `path_delete` for the oldest of the three prior backups; the first three trigger none.

**Architecture & coupling [L]**
- **AC-16 [L]** No engine coupling (Rules 2, 8, 9): `SaveCore` and `PersistMath` extend `RefCounted` or are static, and contain none of `ConfigFile`, `FileAccess`, `DirAccess`, `Input.`, `DisplayServer.`, `Engine.`, `Time.`, `OS.`, `get_tree`; neither references Run State & Restart's own symbols (`theta`, `phase`, `RunState`) beyond the opaque `run_id`/timestamp value Scoring hands it as a stored `[scoring]` value; no `[autoload]` entry exists for either class.
- **AC-17 [L]** `SaveService` is the sole file matching `ConfigFile`, `FileAccess`, `DirAccess` (an allowlist, mirroring Platform Services AC-12a) — confirmed both ways: present here, absent everywhere else in `src/`.

**Node [N]**
- **AC-18 [N]** Signal wiring: a spy core plus a stub Platform-Services-shaped signal source: emitting `app_backgrounded` calls the spy's flush method exactly once; emitting `app_foregrounded`, `app_interrupted`, or `app_returned` calls it zero times (a swapped connection fails this AC).
- **AC-19 [N]** Boot ordering: `_ready` calls the real load path exactly once, before the node is observable as ready by anything else in the scene tree.

**Integration [I], deferred**
- **AC-20 [I], deferred** — real `ConfigFile.save()`/`DirAccess.rename()` behavior: that a real disk-full or permission-revoked condition truly returns a non-OK `Error` rather than a silent partial write, and that a real rename is atomic against an actual killed process. Not achievable with a fake seam; device or CI-sandbox test, owner TBD at `/create-stories`. Blocks nothing today — AC-8/AC-9/AC-14 already prove `SaveCore`'s own call sequence is correct given whatever the real calls return.
- **AC-21 [I], deferred** — real Platform Services wiring: `app_backgrounded` from a real `PlatformServices` node reaches a real `SaveService` exactly once per background transition, within whatever flush-time budget Platform Services' own PS-10 device check ends up measuring (Open Questions).
- **AC-22 [I], deferred** — schema migration: no migration step exists at `CURRENT_SCHEMA_VERSION` = 1; placeholder for when Content Expansion first bumps the version and a real migration path needs an end-to-end test.

**Config/Data smoke, ADVISORY**
- **AC-23 [K, ADVISORY]** Shipped defaults match the Tuning Knobs table: `SAVE_LOG_RATE_LIMIT` = 1.0 s, `CORRUPT_BACKUP_RETENTION` = 5, `CURRENT_SCHEMA_VERSION` = 1 — the fixture deliberately uses 0.05 s / 3 / 3 instead, so this smoke check is the only place the real shipped numbers are asserted.

**Gate policy.** AC-1 through AC-19 are Logic, Config-validation and Node evidence, BLOCKING — each has a real testable oracle today via an injected seam, with no unresolved external dependency, matching the bar this project sets for Logic/Integration stories. AC-20 through AC-22 are Integration, deferred: they need real `ConfigFile`/`DirAccess`/`FileAccess` behavior or a real Platform Services signal, neither of which a unit-level fake seam can honestly stand in for; none is BLOCKING today per the standing rule (no named owner-and-date pair exists yet in this GDD's Dependencies section). AC-23 is ADVISORY per the Config/Data row of the Testing Standards table. The Edge Case "a section is written by more than one system" is explicitly not covered by any AC — the GDD itself says this is a code-review concern, not a runtime check, and proposes a possible future CI lint only if it becomes a real problem; that stays an Open Question, not a gap in this AC set.

## Open Questions

| # | Question | Owner | Resolve when |
|---|----------|-------|--------------|
| 1 | No `docs/engine-reference/godot/modules/core.md` or `io.md` exists at all — `ConfigFile`/`FileAccess`/`DirAccess` behavior on 4.7.2 for this system's Core Rules is unverified against any written reference | godot-specialist | Before implementation |
| 2 | Whether a real `DirAccess.rename()` is truly atomic against a killed process on Android/iOS export targets, and whether a real disk-full/permission-revoked condition returns a clean non-OK `Error` rather than a silent partial write (AC-20) | godot-specialist | Device spike, before implementation |
| 3 | Platform Services' PS-10 device check names a flush-time budget for `app_backgrounded` consumers; this GDD's own write path is synchronous and expected to complete well under any reasonable budget, but no number is asserted here (AC-21) | user, Platform Services GDD | Alongside the Platform Services device spike |
| 4 | Schema migration path design — no migration step exists yet at `CURRENT_SCHEMA_VERSION` = 1; the seam (F1) is defined but never exercised (AC-22, Open Gap) | whichever GDD first bumps the schema (likely Cosmetics & Unlocks) | When Content Expansion begins |
| 5 | Whether a CI lint should enforce "one section, one owning system" (Edge Cases: a section written by more than one system is not detected at runtime) | technical-director | If this becomes a real problem in practice |
| 6 | Cloud save / platform account sync (Google Play Games, Game Center) — not scoped for MVP (single-player, no leaderboard); would add a second write path with conflict-resolution semantics this GDD does not address | user | Post-MVP platform strategy discussion |
| 7 | Whether a future Web export (game-concept.md: "considered post-MVP") needs a different persistence backend than `user://` (browsers sandbox storage differently); out of scope while MVP is mobile-only | user, whoever scopes the Web tier | If/when the Web version is scoped |
