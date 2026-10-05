# SP-2 evidence: real ConfigFile parser against hostile save files

**Story**: SP-011 | **Gate**: first-playable (BLOCKING) | **Godot**: 4.7.2 stable | **Platform**: Windows 11, headless (editor binary)
**Test**: `tests/integration/save_persistence/save_persistence_hostile_files_test.gd` (12 tests, green)
**Fixtures**: `tests/support/hostile_saves/` (oversized and binary payloads are generated deterministically in the test)

## Open Question 1 answer (parsing-time side effect): CONFIRMED

Payload `object_script_payload.cfg`:

```
[settings]
x=Object(RefCounted,"script":Resource("res://tests/support/hostile_saves/sp2_side_effect_probe.gd"))
```

Without a sniff, `ConfigFile.load` instantiated the probe script during parsing (`sp2_side_effect_probe.gd` `_init` ran, `fired == true`) before any Rule 7 check. Pre-committed response applied: `PersistMath.has_object_constructor(text)` (pure, unit-tested) rejects any file naming `Object(`, `Resource(`, `ExtResource(` or `SubResource(` (conservative: also inside strings), called by `SaveService.RealSaveFs.read_config` before `ConfigFile.load`. The sweep was re-run and is green: probe not fired, code `FILE_UNREADABLE`.

## Results (desktop, headless editor binary)

| Case | Outcome | Code | Backup |
|---|---|---|---|
| schema_version String / Array / bool | rejected | SCHEMA_INCOMPATIBLE | yes |
| empty file | rejected | SCHEMA_INCOMPATIBLE | yes |
| typed constructors as plain values (Vector2, Color, PackedByteArray, Array[int]) | loads cleanly, values intact | none | no |
| `Object(Node, ...)` | rejected by sniff, no object created | FILE_UNREADABLE | yes |
| `Object(RefCounted,"script":Resource(...))` | rejected by sniff, script never runs | FILE_UNREADABLE | yes |
| truncated (unterminated string) | rejected, one engine parse error | FILE_UNREADABLE | yes |
| 4096 bytes of binary garbage | parser reads it as an empty config, no engine error; rejected | SCHEMA_INCOMPATIBLE | yes |
| exactly `SAVE_FILE_SIZE_MAX` (65536) bytes | parsed, loads cleanly (1 `read_config` call) | none | no |
| `SAVE_FILE_SIZE_MAX` + 1 and 4 MiB | rejected, 0 `read_config` calls | FILE_UNREADABLE | yes |

Every case ran well under the 2000 ms bound; no crash, hang or escaping exception.

## Still open (story stays Ready)

- Export build run and a real Android device run of the same battery (owner/device item).
- Producer/QA sign-off of the evidence for the first-playable gate.
