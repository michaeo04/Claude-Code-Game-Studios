# Save & Persistence: real SaveFs verification notes (story SP-009, Godot 4.7.2)

Implementation: `SaveService.RealSaveFs` (inner class, `src/core/persistence/save_service.gd`). Tests: `tests/integration/save_persistence/save_persistence_real_fs_test.gd`, per-test directory under `user://` removed in `after_each`; `RealSaveFs.new(dir)` remaps `user://` paths under that directory.

| Item | Result on 4.7.2 |
|------|-----------------|
| int vs float preserved on round trip (item 8) | Confirmed: `1` stays `TYPE_INT`, `1.0` stays `TYPE_FLOAT` |
| Empty file loads `OK` with no sections (item 11) | Confirmed |
| Missing file -> `ERR_FILE_NOT_FOUND` -> `MISSING` | Confirmed |
| Garbage file -> non-OK -> `PARSE_ERROR` | Confirmed; the engine also logs a "ConfigFile parse error" engine error (GUT must expect it with `assert_engine_error`) |
| `size` -1 when absent, byte length otherwise (item 4) | Confirmed |
| `rename_absolute` over an existing destination replaces it | Confirmed on Windows 4.7.2 (story 012 still owns the kill-test prerequisite) |
| `get_files()` lists backups by prefix (item 5) | Confirmed; returns bare file names, as `SaveCore` expects |
| `ConfigFile.save` non-OK on failure (item 2/10) | Not exercised here (needs an unwritable path) |
| Stable section order (item 9) | Not asserted |
| `OS.get_user_data_dir()` logged once (item 12) | NOT done: the call is not in `SaveService` yet (open gap) |
