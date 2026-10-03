# Spike T-1: GUT on Godot 4.7.2

> **Story**: `production/epics/test-harness-ci/story-002-spike-t1-gut-on-4-7-2.md`
> **ADR**: ADR-0009 (Decision 1, Verification Required items 1 to 14)
> **Date**: 2026-10-03
> **Host**: Windows 11, `Godot_v4.7.2-stable_win64_console.exe` (`4.7.2.stable.official.ed1daf0bf`), run headless
> **Method**: throwaway project outside the repository (`.../scratchpad/t1/proj`: a copy of the repo's `project.godot` and `.gutconfig.json`, GUT copied to `addons/gut/`, no `[editor_plugins]` entry), then the same GUT tree vendored into the repository (story 003)
> **Verdict**: **PASS for items 1 to 7, 10 to 14 on Windows. Items 8 and 9 (Linux) are NOT tested here** (no Linux host in this session); the Linux archive name and checksum line are recorded below. ADR-0009's failure response (gdUnit4) is **not** invoked.

## Choice of GUT release (item 14)

| Field | Value |
|---|---|
| Release tag | `v9.7.1` (published 2026-07-10) |
| Upstream commit | `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605` (tag `v9.7.1` resolved through the GitHub API, object type `commit`) |
| Archive | `https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.zip` |
| Archive SHA-512 | `f3af191deb56e5512aa36223fbe3d961eb30e1e651ec02baeb8e1646182d60cc86501f1d3b21216ea9e139ad1fe79afee5d21ac31a093fe0b04e012f25c0f20c` (also in `tools/ci/versions.json`) |
| Licence | MIT |
| Why | Newest release. The release notes of v9.7.0 say "Compatibility changes for Godot 4.7"; v9.6.0 says 4.6; v9.5.0 requires 4.5. v9.7.1 is the patch release on top of 9.7.0. |

Note from the 9.7.0 release notes: Godot 4.7 has stricter return-type checking, and GUT doubles now return a type default instead of `null`. Tests that double a method and rely on a `null` return must account for that.

## Results per verification item

| # | Item | Result |
|---|---|---|
| 1 | GUT loads and runs on 4.7.2 without parse errors | **PASS.** The addon imports (`update_scripts_classes` lists `GutErrorTracker`, `GutTrackedError`); 3 sample scripts ran. |
| 2 | Exact headless command | **PASS.** `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json` after `godot --headless --path . --import`. The `.gutconfig.json` option names `dirs`, `include_subdirs`, `prefix`, `suffix`, `should_exit`, `junit_xml_file`, `log_level` were all accepted as written. |
| 3 | Exit code | **PASS with a trap.** One failing test: exit **1**. All passing: exit **0**. **No test found** (`-gdir=res://tests/none`): exit **0**. A script with a parse error: exit **0** (see item 13). So `run_ci.py` must not trust the exit code. |
| 4 | JUnit XML written and readable | **PASS.** `build/test-reports/gut.xml` is written (`<testsuites ... failures= tests=>`, `<testsuite name=path tests= failures=>`, `<testcase name= status="pass\|fail" classname=>`, `<failure message=...><![CDATA[...]]>`). It has `<testcase name=` and `<failure` as `/test-flakiness` greps for. |
| 5 | `[N]` node test under `--headless` | **PASS.** `add_child_autofree(Node.new())` then `await get_tree().process_frame` and `assert_true(n.is_inside_tree())`. |
| 6 | `class_name` fixtures resolve after `--import` | **PASS after import, FAIL before.** Without `--import` on a fresh `.godot/`: `Parse Error: Identifier "FxThingSupport" not declared in the current scope`, the test script is skipped, **exit 0**. After one `--import`: resolved. This confirms the ADR's `preload()` rule for support code. |
| 7 | `--import` time on a fresh checkout; is caching `.godot/` safe | Fresh `.godot/` (renamed away first): **4.0 s** for a project with GUT only. Caching is unnecessary at this size; not evaluated beyond that. |
| 8 | Linux binary runs headless on Ubuntu | **NOT TESTED** (no Linux host). Test in story 009/010 on the runner. |
| 9 | Official URL and checksum file for the 4.7.2 Linux archive | URL form confirmed reachable: `github.com/godotengine/godot-builds/releases/download/4.7.2-stable/`. `SHA512-SUMS.txt` is published in the same release. Linux line: `9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65  Godot_v4.7.2-stable_linux.x86_64.zip`. **ADR-0009 requires the project owner to commit `godot.sha512` by hand; this value is a candidate for the owner to compare, not a commit.** The Windows archive was verified against its own line of the same file before use (match). |
| 10 | Discovery with `prefix` "" and `suffix` `_test.gd` | **PASS.** All `*_test.gd` files were found (3, then 5 scripts in the larger run). |
| 11 | CLI works without enabling the plugin | **PASS.** No `[editor_plugins]` entry in `project.godot`; the run worked. |
| 12 | Does `--import` need a second pass on a clean clone | **NO.** One pass was enough (run C below). |
| 13 | A Godot run prints `SCRIPT ERROR` / `Parse Error` and still exits 0 | **YES, confirmed.** A test script with a syntax error prints `SCRIPT ERROR: Parse Error: Expected closing ")" after call arguments.` and `ERROR: Failed to load script ... with error "Parse error"`, is **skipped**, and the run exits **0** with the remaining tests green. The JUnit file does not list the skipped script. So `run_ci.py`'s three guards (scan output for `SCRIPT ERROR`/`Parse Error`; JUnit test count at least the number of `*_test.gd` files; zero tests fails) are all required. |
| 14 | Release choice | v9.7.1 (above). |

## Rendering method under the headless driver (ADR-0003 Decision 1)

`RenderingServer.get_current_rendering_method()` returned **`mobile`** under `--headless` with the repository's `project.godot` (`rendering/renderer/rendering_method="mobile"`). So a headless run passes the boot check as written; ADR-0003's injected `rendering_method_getter` seam is still the right design (a test must be able to simulate `forward_plus` and `gl_compatibility`).

## Raw runs (condensed)

- Run 1 (3 scripts: pass, `[N]` node, deliberate failure): `Tests 4, Passing 3, Failing 1`, exit 1, XML written.
- Run 2 (failure file renamed away): `tests="3" failures="0"`, exit 0.
- Run 3 (`-gdir=res://tests/none`): exit 0, no tests.
- Run A (stale class cache, extra `class_name` fixture and a broken script added, no re-import): 2 parse errors printed, 2 scripts skipped, `Tests 3 Passing 3`, **exit 0**.
- Run B (`.godot/` removed, `--import`): 4.0 s.
- Run C (after import): the `class_name` script loads; the broken script still prints `Parse Error` and is skipped; `Tests 5 Passing 5` (the rendering-method test included), **exit 0**.

## Consequences for the neighbouring stories

- **Story 003 (vendor GUT)**: vendor `v9.7.1`; record the tag, commit and the archive SHA-512 in `tools/ci/versions.json`; `.gutconfig.json` needs no change.
- **Story 004 (`run_ci.py`)**: keep all three result guards; add a negative control for each (parse-error script, empty directory, stale class cache).
- **Story 009/010 (CI)**: item 8 (Linux headless) and the owner's `godot.sha512` are still open.
- **ADR-0009**: no amendment is needed. ADR-0003 may note that the headless value is `mobile`.
