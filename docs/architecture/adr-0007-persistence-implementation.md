# ADR-0007: Persistence implementation

## Status

Proposed

## Date

2026-10-02

## Last Verified

2026-10-02

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

Save & Persistence is approved as a design (one `ConfigFile` at `user://save.cfg`, written to a temp file and renamed, read synchronously at boot) but its GDD leaves the implementation shape open: the seam list (the GDD says seven and lists eight, and two seams are missing), the cost of a synchronous write on the death frame, how often a file-level error is logged, and what Android does with the file. This ADR keeps the GDD's format and write protocol, replaces the eight loose seams with **one `SaveFs` facade plus three Callables**, adds the file-size and backup-listing operations the GDD already requires, keeps the write synchronous inside `set_value` and adds a measured budget (spike SP-3) with a pre-committed deferred-flush fallback, logs a file-level failure once per load, and turns Android Auto Backup **off**. The Godot specialist found no blocker; its notes are folded in below (the `load` rename, the post-save size check, the `Error` classification, the backup key). It also records what must be verified on Godot 4.7.2 before any of this is trusted: `rename_absolute` overwrite semantics, `ConfigFile` parsing of hostile files, and write latency on a real device.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (file I/O) |
| **Knowledge Risk** | MEDIUM to HIGH: `FileAccess.store_*` returns `bool` since 4.4; the reference has no module for `ConfigFile`, `FileAccess` or `DirAccess`, and nothing about `user://` on Android, rename semantics or `VariantParser` |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.4 `FileAccess.store_*` returns `bool`), `deprecated-apis.md`, `design/gdd/save-persistence.md` |
| **Post-Cutoff APIs Used** | `FileAccess.store_*` returning `bool` (4.4), only if a future change replaces `ConfigFile.save()` with a hand-written writer (this ADR does not). Everything else used here (`ConfigFile.load/save/get_value/set_value/get_sections/get_section_keys`, `FileAccess.open/get_length/get_open_error`, `DirAccess.rename_absolute/remove_absolute/open/get_files`) predates the cutoff |
| **Verification Required** | **NEEDS VERIFICATION, none of it in the reference:** (1) whether `DirAccess.rename_absolute(from, to)` replaces an existing destination in one filesystem step on Android, and what it does on Windows (the editor and the CI host): a delete-then-rename implementation would open a window with no `save.cfg` (spike SP-1 prerequisite); (2) that `ConfigFile.save(path)` returns a non-`OK` `Error` on disk full or permission failure rather than a silent partial write; (3) the `Error` and typing behavior of `ConfigFile.load(path)` on a truncated, binary, oversized or hand-crafted file, and whether `VariantParser` can instantiate objects while parsing (SP-2, already BLOCKING in the GDD); (4) that `FileAccess.open(path, READ).get_length()` is cheap and does not parse; (5) that `DirAccess.open("user://")` and `get_files()` list the backup names; (6) write latency of the full `set_value` path on a mid-tier Android phone (SP-3, new); (7) that `user://` resolves to the app's private internal storage and how `android:allowBackup="false"` is applied: the preset key name is unknown, Godot's template may already set it, and a custom Gradle build template with a manifest edit is the likely route; read the merged manifest of the first export before deciding anything, and check whether Android 12+ data-extraction rules need a separate entry; (8) whether `ConfigFile` preserves `int` versus `float` for values such as `1` and `1.0` on a save and load round trip (the `typeof(default)` check depends on it); (9) whether `ConfigFile.save` writes sections in a stable order; (10) that `ConfigFile.save` reports a short write or a full disk as a non-`OK` `Error` (it may return `OK` with a truncated file, hence the size check in Decision 4); (11) that an empty file loads as `OK` with no sections; (12) that `OS.get_user_data_dir()` is the app-private files directory on Android (logged once in the spike) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Android only), ADR-0002 (Save is built second, no autoload, injected `clock_us`), ADR-0006 (the `app_backgrounded` flush must be small and synchronous; the manifest lint) |
| **Enables** | ADR-0009 (the fake `SaveFs` and the lint allowlist), the Scoring and Settings epics |
| **Blocks** | Save & Persistence epic; first playable (SP-1, SP-2 and SP-3 are blocking) |
| **Ordering Note** | SP-1 must run its Windows prerequisite check before any CI run of SP-1; SP-3 runs on the same device session as SP-1 |

## Context

### Problem Statement

The GDD fixes the behavior (Core Rules 1 to 10) but cannot decide what the module looks like in code or what the engine will really do. Four points are open: the seam shape (and two missing operations, file size and backup listing), the cost of the synchronous write that Scoring triggers on the death frame (Open Question 4 of the architecture), a contradiction between F2 ("a parse failure is reported once for the file") and AC-10 ("one log per requested key"), and the Android backup policy, which neither the GDD nor ADR-0006 mentions.

### Constraints

- Android only, 512 MB, 60 FPS; the death frame carries the Juice hit, Scoring, HUD freeze and the save write in one tick (ADR-0002).
- No autoload; `SaveService` is built second by `GameRoot` and is the only file with `ConfigFile`, `FileAccess` or `DirAccess` (AC-17); `SaveCore` and `PersistMath` hold no engine calls (AC-16).
- GDScript cannot `fsync`, so the guarantee is app-termination only, not power loss (GDD Rule 6).
- The save is plain and unsigned (Rule 10); the MVP has no network.
- The file holds a few hundred bytes: the personal best, five settings, the schema version.

### Requirements

- A personal best set on the death frame is on disk before the next frame, or the loss is bounded to that one write.
- A corrupt, oversized or newer-schema file never crashes the game and never takes the whole profile down; it is moved aside and the defaults are used.
- All of `SaveCore` is testable with a fake file system and no real I/O.
- A write never blocks the frame long enough to be felt.

## Decision

### 1. Module shape

```text
PersistMath   (static)       schema_compatible, read_valid, read_error_code, is_serializable_type
SaveCore      (RefCounted)   in-memory sections, get_value, set_value, boot_load, flush, backup rotation
SaveFs        (RefCounted)   the file-system facade; base class with failing defaults, faked in tests
SaveService   (Node)         builds the real SaveFs, owns the only ConfigFile/FileAccess/DirAccess calls,
                             connects app_backgrounded, converts clock_us to seconds
```

`SaveCore` is constructed with `(fs: SaveFs, clock: Callable, wall_clock: Callable, log_sink: Callable, config: SaveConfig)`. The eight seams of the GDD become **one facade and three Callables**:

| Seam | Form | Notes |
|------|------|-------|
| `read_config(path) -> Dictionary` | `SaveFs` method | `{status: "OK" or "MISSING" or "PARSE_ERROR", sections: Dictionary}` as in the GDD fixture |
| `write_config(path, sections) -> bool` | `SaveFs` method | the real one builds a `ConfigFile`, `set_value` for every key, `save(path) == OK` |
| `exists(path) -> bool` | `SaveFs` method | |
| `size(path) -> int` | `SaveFs` method, **new** | `-1` when absent; real: `FileAccess.open(READ).get_length()`, closed at once |
| `rename(from, to) -> bool` | `SaveFs` method | real: `DirAccess.rename_absolute(from, to) == OK` |
| `delete(path) -> bool` | `SaveFs` method | real: `DirAccess.remove_absolute(path) == OK` |
| `list_backups(dir, prefix) -> PackedStringArray` | `SaveFs` method, **new** | names only, sorted by the core; real: `DirAccess.open(dir).get_files()` filtered by prefix |
| `clock() -> float` | Callable | monotonic seconds, for `RateLimitedLog`; `SaveService` builds it from the injected `clock_us` |
| `wall_clock() -> int` | Callable | Unix seconds (`Time.get_unix_time_from_system()` cast to `int`), used only for the backup name |
| `log_sink(level, code, key, message)` | Callable | |

The GDD's wording "seven seams" is corrected to "one facade and three Callables" (GDD follow-up). `SaveFs` is a plain base class whose methods return failure values (`false`, `-1`, an empty result with status `"PARSE_ERROR"`); `@abstract` (4.5) is not used. The real implementation is an inner class of `SaveService`, so AC-17 holds without an allowlist change. A test fake extends `SaveFs`, records the calls in order and scripts the return values.

### 2. File format and layout

One file, `user://save.cfg`, a `ConfigFile` with sections `[scoring]` (`personal_best` int), `[settings]`, the reserved `[cosmetics]` and `[_meta]` (`schema_version` int, 1 at MVP), exactly as GDD Rule 3. Temp file `user://save.cfg.tmp`; corrupt backups `user://save.cfg.corrupt-<wall_clock>-<n>`. No `.cfg` is read from any other path and no other file type is written.

### 3. Boot load

`SaveCore.boot_load()` runs once, in `SaveService._ready`-equivalent construction order (ADR-0002 step 2), before Scoring and Settings exist:

1. `fs.exists(REAL)` false: status `MISSING`, defaults for every key, one `INFO` log (`FILE_MISSING`), nothing else.
2. `fs.size(REAL) > SAVE_FILE_SIZE_MAX`: treated as `PARSE_ERROR` **without** calling `read_config`; code `FILE_UNREADABLE` with the message "oversized"; the file is backed up aside (step 5).
3. Otherwise `fs.read_config(REAL)`. The real implementation builds a **fresh `ConfigFile` per read** and discards it on error (a failed parse may leave partial sections); `ERR_FILE_NOT_FOUND` maps to `MISSING`, **every other** non-`OK` `Error` maps to `PARSE_ERROR`. `FileAccess.open` returning `null` makes `size()` return `-1`. An empty file loads as `OK` with no sections; its missing `[_meta].schema_version` makes it `SCHEMA_INCOMPATIBLE` (F1), so it is backed up aside like any other unusable file.
4. `PARSE_ERROR` gives `FILE_UNREADABLE`; an incompatible `[_meta].schema_version` (F1) gives `SCHEMA_INCOMPATIBLE`. Either invalidates the whole file: every `get_value` returns the caller's default. **Each is logged once per load (ERROR), not once per key** (a change from AC-10, see Consequences). `TYPE_MISMATCH` stays per key, logged when that key is first read.
5. On a file-level failure the old file is renamed to `save.cfg.corrupt-<wall_clock()>-<n>` (`n` zero-based, incremented while that exact name exists), then `list_backups` is read, sorted by name, and the oldest are deleted until at most `CORRUPT_BACKUP_RETENTION` remain. The in-memory state is then empty (defaults) and the first `set_value` creates a fresh file.
6. On success the parsed sections become the in-memory state, including keys that fail the type check (carried forward byte for byte, Rule 6).

`type_matches(section, key, expected)` compares `typeof(stored) == typeof(default)` where `default` is the caller's own argument; the GDD's open mechanism is closed this way (architecture Phase 4). A stored `int` where the caller declared a `float` is a `TYPE_MISMATCH` (the default is returned and the stored value is kept until rewritten); callers that want a float must declare a float default.

### 4. Write path

`set_value(section, key, value) -> bool`, synchronous:

1. `PersistMath.is_serializable_type(value)` false (a raw `Object`, and also a `float` that is NaN or infinite, which round-trip badly): `UNSERIALIZABLE_VALUE`, no memory update, no seam call, return `false`.
2. Update the in-memory map.
3. If `fs.exists(TMP)`: `fs.delete(TMP)`.
4. `fs.write_config(TMP, complete_sections)`, then `fs.size(TMP) > 0` (a guard against `ConfigFile.save` returning `OK` after a short write on a full disk, which would otherwise let a truncated temp file replace the good save); either failing: log `WRITE_FAILED` (rate limited per section and key by the reused `RateLimitedLog`), return `false`; the memory value stays updated.
5. `fs.rename(TMP, REAL)`; false: same `WRITE_FAILED`, return `false`.
6. Return `true`.

Step 3 is redundant for the real `ConfigFile.save` (it truncates) but is kept because GDD AC-9 specifies it and it costs two cheap calls. `complete_sections` is always the whole map (GDD Rule 6, AC-6, AC-6b). `flush()`, called by `SaveService` on `app_backgrounded`, is a no-op because every write is already synchronous (AC-7); it exists so a future change cannot add a race silently. The call comes from the `app_backgrounded` handler that ADR-0006 already keeps small and synchronous.

### 5. The write on the death frame (user decision)

The write stays **inside `set_value`**, so Scoring's `personal_best` is on disk before the tick ends. The cost is measured, not assumed: a new blocking spike **SP-3** measures the whole `set_value` path (build the `ConfigFile`, `save`, `rename`) on a mid-tier Android phone. **Budget:** p95 at most 3 ms over at least 1000 writes (the maximum is reported and must stay at most 8 ms, but journal stalls show only in the tail, so the maximum alone does not fail the spike), once with the app idle and once during a hit-frame replay with the Juice effects running. **Pre-committed failure response, decided before the result is known:** `set_value` only marks the core dirty and `GameRoot` calls `save.flush_dirty()` as the **last step of the same tick** (after `Menus.tick` in the ADR-0002 order, still before the next frame, so nothing is lost and AC-6 changes from "writes before `set_value` returns" to "writes before the tick returns"). A write-behind to `app_backgrounded` is rejected (a process killed without a callback would lose the best).

**Continuous controls.** `set_value` has no coalescing. Settings and Menus must call it for a slider **on drag end** (the `drag_ended` signal), never on every `value_changed`: a slider drag at 60 events per second would write the file 60 times a second and wear the flash. This is a constraint on the Settings GDD (Core Rule 5 says it writes on every change) and on the Menus slider pattern, and is added to the follow-up list; SP-3 includes a 10-second slider-drag run as the negative control.

### 6. Failure modes and their answers

| Failure | What the code does | Evidence |
|---------|--------------------|----------|
| Process killed before, during or after the temp write | `save.cfg` is untouched or fully replaced; the orphan `.tmp` is deleted on the next write | SP-1 (3 kill points, 20 repetitions each) |
| `rename_absolute` is delete-then-rename on the platform | Window with no `save.cfg` but a valid `.tmp`. Pre-committed response (not adopted now): at boot, if `REAL` is missing and `TMP` parses and is compatible, rename `TMP` to `REAL` after the same parse and schema checks as a normal load, and log `INFO`; if SP-1 still fails, adopt the GDD's A/B-slot scheme | SP-1 prerequisite check on Android and on the Windows CI host |
| Power loss or kernel panic | not covered (no `fsync` from GDScript); the file may read back empty or garbage, which is then treated as `FILE_UNREADABLE`: defaults, backup, a fresh file | GDD Rule 6 |
| Disk full or permission error | `write_config` or `rename` returns false: one `WRITE_FAILED`, the session continues with the in-memory value, only the next launch loses it | AC-8, AC-14 |
| Oversized, truncated, binary or hand-crafted file | size guard before parsing; `PARSE_ERROR` path; backup aside | AC-10, SP-2 |
| Parsing-time side effect in `VariantParser` | pre-parse content sniff (reject the file before `ConfigFile.load`) | SP-2 pre-committed response |

### 7. Android storage and backup (user decision)

`user://` is the app's private internal storage (verify, item 7). The export preset and the merged manifest set `android:allowBackup="false"`, so Auto Backup never restores an old save, a save of another schema, or a half-written `.tmp` or `.corrupt-*` file onto a new device. The cost is accepted: **a personal best does not follow the player to a new phone** in the MVP; cloud save is the GDD's Open Question 6. The ADR-0006 manifest lint (release builds read the merged manifest) gains one assertion for this attribute. How the attribute is set is **not yet known**: Godot's template may already set it, the preset may have no key for it, and the likely route is a custom Gradle build template with a manifest edit. The merged manifest of the first export decides (verification item 7); the lint is the backstop either way. Disabling backup also disables Android 12+ device-to-device data extraction, which the same check covers.

### 8. Registry and lint

- The AC-16 lint (no `ConfigFile`, `FileAccess`, `DirAccess`, `Time.`, `OS.` in `SaveCore` and `PersistMath`) is unchanged; `SaveFs` and its fake are covered by the same rule (the base class has no engine calls); the real inner class lives only in `save_service.gd` (AC-17).
- `SaveConfig` (a `Resource`, `validated(log_sink)`) holds `SAVE_LOG_RATE_LIMIT`, `CORRUPT_BACKUP_RETENTION`, `SAVE_FILE_SIZE_MAX` and `CURRENT_SCHEMA_VERSION` is a constant.

### Key Interfaces

```gdscript
# save_fs.gd
class_name SaveFs
extends RefCounted

func read_config(_path: String) -> Dictionary: return {"status": "PARSE_ERROR", "sections": {}}
func write_config(_path: String, _sections: Dictionary) -> bool: return false
func exists(_path: String) -> bool: return false
func size(_path: String) -> int: return -1
func rename(_from: String, _to: String) -> bool: return false
func delete(_path: String) -> bool: return false
func list_backups(_dir: String, _prefix: String) -> PackedStringArray: return PackedStringArray()

# save_core.gd
class_name SaveCore
extends RefCounted

func _init(fs: SaveFs, clock: Callable, wall_clock: Callable, log_sink: Callable, config: SaveConfig) -> void
func boot_load() -> void                              # once, at boot (not `load`: that shadows the global load())
func get_value(section: String, key: String, default: Variant) -> Variant
func set_value(section: String, key: String, value: Variant) -> bool
func flush() -> void                                  # no-op today (every write is synchronous)
```

## Alternatives Considered

### Alternative 1: A custom JSON file over `FileAccess`

- **Description**: write and parse the profile with `JSON` and `FileAccess`.
- **Pros**: full control of parsing and size, no `VariantParser` side-effect question, stable text format.
- **Cons**: re-implements escaping and typing that `ConfigFile` gives; JSON turns every number into a float (`personal_best` needs a cast and a range check); rewrites the approved GDD and ACs; `FileAccess.store_*` returns `bool` since 4.4, which is exactly the post-cutoff surface we would add.
- **Rejection Reason**: the GDD, ACs and the fake seam are written for `ConfigFile`; SP-2 already answers the parser risk and has a pre-committed fix. Revisit only if SP-2 fails and the pre-parse sniff is not enough.

### Alternative 2: `ConfigFile` with a deferred or write-behind flush

- **Description**: `set_value` marks dirty; the file is written at end of frame or on `app_backgrounded`.
- **Pros**: no I/O inside the death-frame tick; coalesces slider spam for free.
- **Cons**: changes GDD Rule 5 and AC-6; write-behind to the background loses the best if the process dies without a callback.
- **Rejection Reason**: not rejected for end-of-frame; it is the **pre-committed fallback** if SP-3 misses its budget. Write-behind to the background is rejected.

### Alternative 3: Eight loose Callables (the GDD's shape plus two new ones)

- **Description**: ten `Callable` constructor parameters.
- **Pros**: matches Platform Services' seam style.
- **Cons**: a ten-argument constructor, ten fakes per test, easy to wire in the wrong order.
- **Rejection Reason**: one facade object is easier to fake and to read; the clocks and the log sink stay Callables because other modules share them.

### Alternative 4: SQLite or a GDExtension store

- **Rejection Reason**: a few hundred bytes of data; a native dependency would add a 16 KB-page, arm64 and signing surface for nothing.

## Consequences

### Positive

- One small module with a faked file system: every write, recovery and rotation rule is a unit test with no real I/O.
- The oversized-file guard and the backup rotation have the seams they were missing.
- The death-frame cost has a number, a test and a pre-decided fallback.
- No hidden backup restore path: the file on disk is only ever the file this build wrote.

### Negative

- AC-10 and F2 change: a file-level failure logs once per load, not once per key (GDD edit).
- The GDD's seam count and AC wording change from "seven seams" to one facade and three Callables; AC-6 gets a conditional rewording if SP-3 fails.
- No Auto Backup: a new phone starts with no personal best.
- Settings and Menus must commit sliders on drag end (new constraint on two GDDs).
- Android's allowBackup mechanism is still an open verification item.
- `type_matches` by `typeof(default)` rejects an `int` stored where a `float` is declared, so a hand-edited `1` is ignored.

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `rename_absolute` is not an atomic replace on the platform | Medium | High (the best is lost in one write) | SP-1 prerequisite; boot-time `.tmp` promotion; A/B slots as the last resort |
| `ConfigFile.load` has a side effect or a crash on a hostile file | Low | Medium | size guard; SP-2; pre-parse sniff |
| Write latency on the death frame is felt | Medium | Medium | SP-3 budget; end-of-frame flush fallback |
| Slider drag spams the file | Medium | Medium | commit on `drag_ended`; SP-3 negative control |
| `allowBackup=false` is not applied by the preset | Low | Low | merged-manifest lint; custom manifest fragment |
| `ConfigFile` changes `int` and `float` on a round trip | Low | Medium | verification item 8; a round-trip test per type |
| Power loss leaves an empty `save.cfg` | Low | Medium | scoped out in the GDD; the fail-safe path recovers to defaults |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| save-persistence.md | CR1, CR3: one `ConfigFile`, sections `[scoring]`, `[settings]`, `[cosmetics]`, `[_meta]` | Decision 2 |
| save-persistence.md | CR2, AC-16, AC-17: pure core, injected seams, one node with the real calls | Decision 1 (facade plus three Callables; real class inside `SaveService`) |
| save-persistence.md | CR4, AC-5, AC-19: synchronous boot read before dependents | Decision 3 and the ADR-0002 order |
| save-persistence.md | CR5, CR6, AC-6, AC-6b, AC-7, AC-8, AC-9: immediate write, temp then rename, complete map, no-op flush | Decision 4 |
| save-persistence.md | CR7, AC-10 to AC-15: fail safe to defaults, per-key fallback, backup naming and retention | Decision 3 (log once per load; per-key `TYPE_MISMATCH`) |
| save-persistence.md | Edge Case "unexpectedly large file", `SAVE_FILE_SIZE_MAX` | `SaveFs.size` and the guard in Decision 3 |
| save-persistence.md | SP-1, SP-2 and the pre-committed responses | Decision 6 table; SP-3 added |
| save-persistence.md | CR8, CR10: no mid-run persistence, no signing | unchanged |
| scoring-personal-best.md | CR6, AC-21: the best is written on the run end | Decision 5 (synchronous, budget, fallback) |
| settings-accessibility.md | CR5: write on every change | Decision 5 continuous-control rule (a Settings edit) |
| platform-services.md | CR10: `app_backgrounded` flush, PS-10 budget | Decision 4 (`flush()` no-op; synchronous) |
| run-state-restart.md | OQ6: no run persistence | unchanged (CR8) |

## Performance Implications

- **CPU**: one `set_value` is a handful of dictionary writes plus one `ConfigFile.save` of well under 1 KB and one rename; expected 1 to 3 ms on flash storage, to be measured (SP-3). Boot adds one `size` and one `read_config`.
- **Memory**: a few KB; the size guard caps a hostile file at 64 KB before it is parsed.
- **Load Time**: negligible; the read is synchronous at boot.
- **Network**: none.

## Migration Plan

New code. The only edits to existing documents (after the ADR is Accepted): the GDD seam wording, F2 and AC-10 (log once per load), Rule 5 and the Settings GDD for slider commits, the ADR-0006 manifest lint for `allowBackup`, Menus slider pattern, architecture.md Open Question on the death-frame write.

## Validation Criteria

- [ ] AC-1 to AC-19, AC-23 pass against the fake `SaveFs`, with AC-10 reworded to one log per load.
- [ ] SP-1: zero corrupted `save.cfg` over 3 kill points and 20 repetitions each on a real device, after the Windows prerequisite check of `rename_absolute`.
- [ ] SP-2: the hostile-file battery loads or is rejected cleanly, and no oversized file reaches `read_config`.
- [ ] SP-3: `set_value` p95 at most 3 ms over 1000 writes, maximum reported (at most 8 ms expected), on a mid-tier phone, idle and during a hit replay; a 10-second slider drag with commit on drag end writes once.
- [ ] The merged release manifest contains `android:allowBackup="false"`.
- [ ] An `int` and a `float` value round trip with their types preserved.

## Related Decisions

- ADR-0001 Android only; ADR-0002 game loop and Composition Root (build order, `clock_us`); ADR-0006 Android platform integration (`app_backgrounded`, manifest lint)
- `design/gdd/save-persistence.md`, `design/gdd/scoring-personal-best.md`, `design/gdd/settings-accessibility.md`, `design/gdd/platform-services.md`
- `docs/architecture/tr-baseline/foundation.md` (TR-save-persistence-001 to 022)
