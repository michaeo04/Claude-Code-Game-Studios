# ADR-0009: Test framework and CI

## Status

Proposed

## Date

2026-10-02

## Last Verified

2026-10-02

## Decision Makers

The user (project owner), with Claude Code agents.

## Summary

Six GDDs and `technical-preferences.md` assume **GUT**, while the project's test skills (`/test-setup`, `/smoke-check`, `/test-helpers`, `/test-flakiness`) and the CI line in `coding-standards.md` assume **gdUnit4**, and the repository has no `project.godot`, no test addon and no workflow. Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on a Linux runner** with a pinned Godot 4.7.2 binary and one entry command, `python tools/ci/run_ci.py`; a **Python 3 (stdlib only) lint runner** driven by a declarative rule table that implements the lints registered by the other ADRs and checks that every lint-able registry pattern has a rule; a **three-folder test layout** (`unit`, `integration`, `advisory`) mapped to the evidence classes of the testing standards; and **no line-coverage gate**, because the gate is AC traceability plus required tests and lints. The Godot specialist found one small blocker (GUT's default file prefix does not match the project's `*_test.gd` naming) and several CI-hygiene notes, all folded in below.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Tooling and testing (outside the engine runtime) |
| **Knowledge Risk** | MEDIUM: nothing in the engine reference covers GUT, gdUnit4 or JUnit output; compatibility of either addon with 4.7.2, the headless command-line options and the exit-code behavior are unverified. Verified on the 4.7.2 binary (`current-best-practices.md`): `class_name` needs a class cache, so `godot --headless --import` must run before a headless test run |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `current-best-practices.md` (GDScript gotchas verified on 4.7.2, headless import), `breaking-changes.md`, `.claude/docs/coding-standards.md` (testing standards, evidence table, CI rules), `.claude/docs/technical-preferences.md`, `.claude/docs/git-workflow.md` |
| **Post-Cutoff APIs Used** | None in game code. GUT 9.x must parse under the 4.5 to 4.7 GDScript changes (variadics, `@abstract`), which is verification item 1 |
| **Verification Required** | **NEEDS VERIFICATION (spike T-1, before the first story, on Windows and Linux with 4.7.2):** (1) the chosen GUT release loads and runs on 4.7.2 without parse errors; (2) the exact headless command and its option names (`-s addons/gut/gut_cmdln.gd`, `-gdir`, `-ginclude_subdirs`, `-gexit`, `-gjunit_xml_file`, or a `.gutconfig.json`); (3) that the process exit code is non-zero on any failing test and zero on success; (4) that a JUnit XML report is written and that `/test-flakiness` can read it; (5) that a test needing a `SceneTree` (an `[N]` node test, `add_child_autofree`) runs under `--headless`; (6) that `class_name` fixtures resolve after `--import`; (7) the time of `--import` on a fresh checkout and whether caching `.godot/` is safe; (8) that the Godot 4.7.2 Linux binary runs headless on the Ubuntu runner without a display; (9) the official download URL and the checksum file for the 4.7.2 Linux archive (expected: the `godotengine/godot-builds` release `4.7.2-stable`, file `Godot_v4.7.2-stable_linux.x86_64.zip`, `SHA512-SUMS.txt`); (10) that GUT discovers `*_test.gd` files once `prefix` is set to empty and `suffix` to `_test.gd` (its default prefix is `test_`, which would find none); (11) that GUT's command line works without enabling the plugin in `project.godot`; (12) whether `--import` needs a second pass on a clean clone for the global class cache; (13) whether a Godot run prints `SCRIPT ERROR` or `Parse Error` and still exits 0; (14) which GUT release to use: the newest whose notes name 4.5 or later, otherwise the latest tested on 4.7.2 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (cores are `RefCounted`, no autoload, so unit tests need no `SceneTree`), ADR-0007 (the fake `SaveFs`; no real file system in unit tests), ADR-0004 and ADR-0008 (the `ResourceLoader` lint, the content preflight test) |
| **Enables** | `/test-setup`, `/create-control-manifest`, required status checks on `main`, every Logic story's test gate |
| **Blocks** | Every story that needs a test to be Done (Logic and Integration evidence is BLOCKING); the first implementation sprint |
| **Ordering Note** | Spike T-1 (framework on 4.7.2) and T-2 (first green CI run) come before the first implementation story; the project must exist (`project.godot`) before T-1 |

## Context

### Problem Statement

The testing standards make Logic and Integration evidence BLOCKING and say "no merge if tests fail", but no framework, runner, CI workflow or lint harness exists, and the project documents disagree on the framework. Eight ADRs and about thirty GDD acceptance criteria rely on lints (`[L]`) and on a headless run, and the engine reference warns that `class_name` types do not resolve without an import pass. Until one framework, one entry command and one place for lints are fixed, no story can honestly be marked Done.

### Constraints

- Godot 4.7.2 only; the repository is **public**, so CI minutes are free but any secret or unpinned third-party code is a supply-chain and disclosure risk.
- Cores are `RefCounted` with injected seams, so most tests need neither a `SceneTree` nor files (ADR-0002, ADR-0007).
- Dev host is Windows 11; CI is Linux. Behavior that differs by OS (file rename semantics, paths) is proven on a device (ADR-0007 SP-1), never by CI alone.
- Tests are deterministic, isolated and independent (testing standards): no real time, no unseeded randomness, no external calls, no file I/O in unit tests.
- Never disable or skip a failing test to pass CI (CI rules).

### Requirements

- One framework, one command locally and in CI, one report format.
- Every lint registered by an ADR or GDD is implemented once, with its own tests.
- Test folders map to evidence classes so a story's required evidence is unambiguous.
- Pinned, verifiable CI inputs; minimal permissions.

## Decision

### 1. Framework: GUT 9.x, vendored and pinned

- **GUT** (MIT) is vendored under `addons/gut/` at a pinned release tag; the tag and a checksum of the archive are recorded in `tools/ci/versions.json`. The addon is added to the allowed-libraries list in `technical-preferences.md` (the only allowed addon in the MVP).
- **Discovery:** `.gutconfig.json` sets `"prefix": ""` and `"suffix": "_test.gd"` (GUT's default prefix `test_` would match none of the project's `[system]_[feature]_test.gd` files); the runner also fails on **zero tests executed** and on an executed count lower than the number of `*_test.gd` files, because a test script with a parse error can be skipped while the run stays green.
- Test files are `[system]_[feature]_test.gd`, classes `extends GutTest`, functions `test_[scenario]_[expected]` (testing standards).
- **Framework independence of fixtures:** factories and fakes live in `tests/support/` as plain `RefCounted` classes and functions with **no GUT base class and no GUT call** (`make_save_fixture()`, `make_obstacle_fixture()`, `FakeSaveFs`, `make_clock_stub`, signal-log recorders). Only the `*_test.gd` files touch GUT, so a switch to gdUnit4 is a mechanical port of test files. Test files reference support code with `const X = preload("res://tests/support/x.gd")`, which needs no class cache and is robust headless; `class_name` in `tests/support/` is allowed only with a unique prefix and is not used by tests. Fakes are not named like GUT classes (`Double`, `Spy`). GUT's command line is expected to work without enabling the plugin; no `[editor_plugins]` entry is added unless the editor panel is wanted (then the `project_setting` lints allow it).
- **Spike T-1 (before the first story, blocking):** install the chosen GUT release into a throwaway project on 4.7.2 and, on Windows and Linux, run one passing, one failing and one `[N]` `SceneTree` test headless; confirm the verification items 1 to 7. **Release choice:** the newest GUT release whose notes name 4.5 or later, otherwise the latest tested on 4.7.2. **Pre-committed failure response:** if GUT cannot meet items 1 to 5 on 4.7.2, switch to gdUnit4 (its CLI, JUnit XML and GitHub action exist), keep `tests/support/` unchanged, and port the test files; this ADR is then superseded by a short amendment, not rewritten.

### 2. Test layout and the evidence classes

```text
tests/
  unit/<system>/<system>_<feature>_test.gd         Logic evidence: BLOCKING. Fakes only, no file I/O, no SceneTree
                                                    except [N] node tests (thin Node drivers)
  integration/<system>/<system>_<feature>_test.gd   Integration and Content evidence: BLOCKING. Real .tres, real temp files,
                                                    several real cores wired, the content preflight (ADR-0008)
  advisory/<system>/<system>_<feature>_test.gd      ADVISORY: shipped-defaults smoke checks (for example AC-23),
                                                    statistical tests (chi-square shuffle fairness)
  support/                                          fixtures, fakes, recorders; no framework dependency
production/qa/evidence/                             Visual/Feel and device evidence (spikes SP-1.., PS-.., BM-.., NM-1, OB-1, MS-1)
tools/ci/                                           run_ci.py, lint_runner.py, lint_rules.json, versions.json, tests/
```

| Evidence class (testing standards) | Where it lives | In CI |
|---|---|---|
| Logic (formulas, AI, state machines, cores, signal wiring `[N]`) | `tests/unit/` | BLOCKING |
| Integration headless-capable (multi-core wiring, content preflight, `.tres` load, golden sequences) | `tests/integration/` | BLOCKING |
| Integration that needs a device (spikes SP-1, SP-2, SP-3, PS-1.., BM-1, NM-1, OB-1, MS-1) | `production/qa/evidence/` | not run; blocking at its named gate (`designated-gates.md`) |
| Lints `[L]` | `tools/ci/lint_rules.json` | BLOCKING unless the rule says ADVISORY |
| Config/Data smoke and statistical | `tests/advisory/` | ADVISORY (reported, never fails the job) |
| Visual/Feel, UI walkthroughs | `production/qa/evidence/` | not run; ADVISORY unless a designation applies |

Rules: unit tests never touch the real file system, `ResourceLoader` or `Time`; integration tests may read shipped `.tres` and write only under a per-test temporary directory they delete; a test that needs a real device is not written as a GUT test. Integration tests that use `user://` work under a **unique per-test subdirectory** removed in `after_each`. No test asserts visual fidelity, feel or shader output ("what not to automate"). A node test that touches rendering classes runs under the dummy headless renderer and asserts structure only.

### 3. One entry command

`python tools/ci/run_ci.py [--only unit|integration|advisory|lint|all]` (default `all`) runs, in order, and stops reporting at the first BLOCKING failure only after finishing the step it is in:

1. `godot --headless --path . --import` (once per checkout; `.godot/` is gitignored; if T-1 shows a second pass is needed for the class cache, the script runs it twice as a build step, not as a test retry)
2. GUT over `tests/unit/` then `tests/integration/` with a committed `.gutconfig.json` (directories, recursion, `-gexit`, a JUnit XML path under `build/test-reports/`)
3. GUT over `tests/advisory/` (its failure is reported as a warning)
4. `python tools/ci/lint_runner.py`

**Mandatory result checks (a green exit code is not trusted):** every Godot call runs under a timeout wrapper in `run_ci.py`; the JUnit XML must exist, report more than zero tests and at least as many as there are `*_test.gd` files, and report zero failures and errors; the captured output is scanned and the step fails on `SCRIPT ERROR` or `Parse Error` even when the exit code is 0. The Godot binary path comes from `GODOT` (an environment variable) or `tools/ci/versions.json`; the script prints the engine version and fails if it is not exactly `4.7.2`. The same command is what `/smoke-check` calls (`--only unit`); the CI line in `coding-standards.md` (`godot --headless --script tests/gdunit4_runner.gd`) is replaced by it.

### 4. CI workflow (GitHub Actions, Linux)

`.github/workflows/ci.yml`:

- **Hardening:** `actions/checkout` with `persist-credentials: false`; a `concurrency` group that cancels superseded runs; `timeout-minutes` on the job; `python3` (the SHA-pinned `actions/setup-python`, since `python` is not guaranteed on the runner); a routine (Dependabot or a manual review) for updating the action SHAs. `.gitattributes` forces `eol=lf` for `*.gd`, `*.tres`, `*.tscn`, `*.json`, `*.py` so checksums and lint line numbers match on Windows and Linux. Linux CI also catches wrong-case `res://` paths that pass on Windows.
- **Triggers:** `push` to `dev` and `main`, and `pull_request` into `main` (and `dev`). Workflow-level `permissions: contents: read`; no secrets are used or needed.
- **Runner:** `ubuntu-latest`. Steps: checkout; Python 3 (preinstalled, stdlib only); download the **official Godot 4.7.2-stable Linux archive** and verify its SHA-512 against the value **committed by hand** in `tools/ci/versions.json` (the checksum file is never fetched from the same release at run time, which would not detect a tampered release) before it is unpacked; `.godot/` is **not cached** in the MVP (it holds the class and import cache and the project has no imported art, so `--import` is fast); `python tools/ci/run_ci.py`; upload `build/test-reports/` as an artifact.
- **Pinning:** every third-party action is pinned to a commit SHA, never a moving tag; no third-party Godot container image is used (version lag and supply-chain surface); GUT is vendored, not downloaded in CI; the committed `addons/gut` tree is the source of truth and `versions.json` records the release tag, the upstream commit SHA and the licence file.
- **Status check:** the job is named `ci`. After the first green run (spike T-2) the project owner may enable it as a **required status check on `main`** (git-workflow: "Required status checks are added once CI exists"); that is a repository setting and needs the owner's explicit approval, so this ADR only prepares it. `dev` pushes run CI but a short-lived red `dev` stays allowed by the git workflow.
- **Out of scope here:** Android export in CI (export templates, keystore decoded from a secret to a temporary path, ADR-0006) is a separate, later workflow with its own review.
- **OS caveat:** CI on Linux gives POSIX behavior; ADR-0007's SP-1 (rename atomicity) and every device spike stay device evidence. The Windows prerequisite check of `rename_absolute` in ADR-0007 is run once by hand on the dev host.
- **Budget:** a full CI run in at most 5 minutes after the cache is warm.

### 5. Lint framework

`tools/ci/lint_runner.py` (Python 3, stdlib only) reads `tools/ci/lint_rules.json`. Each rule has: `id`, `source` (ADR or GDD reference), `severity` (`BLOCKING` or `ADVISORY`), `kind`, `scope` (globs), the pattern fields, and a `message`. GDScript files are scanned after **comments and string literals are stripped** (`#` comments, single, double and triple quotes), so a banned token in a comment or a message does not trigger a rule. The stripper is **one left-to-right state machine** (not sequential regex passes): it handles `#` and `##` comments and a `#` inside a string, triple-quoted strings (`"""` and `'''`), escapes, raw strings `r"..."`, `&"name"` and `^"path"` literals, and `$Node/Path` and `%Unique` (not strings), keeps the quotes (`""`) so rules that look for string arguments (`connect("x", ...)`, `Callable(obj, "m")`) still work, preserves newlines so reported line numbers stay correct, and accepts CRLF and LF. `_process` is matched as `func\s+_(physics_)?process\b` (a `set_process(...)` call or a mention in a name does not trigger it). A scene-file rule scans `.tscn` `[connection ...]` entries for the deferred flag.

| Kind | Meaning | Examples (from the registered ADRs) |
|---|---|---|
| `forbid` | the regex must not match in `scope` | `_process`/`_physics_process` outside `game_root.gd`; `CONNECT_DEFERRED` on control signals; `Engine.time_scale` writes; `SceneTree.paused`; `duplicate_deep`; `Vector4` in hazard code; `randf`, `randomize`, global `shuffle` in Pattern; `CollisionObject3D`, `Area3D`, `RayCast3D`, `PhysicsServer`; `OS.is_debug_build()` in dev-input code; `Input.is_action_*` in gameplay; ADR-0010 presentation-time rules: `TIME` in `assets/shaders/**` and in particle process materials, `create_tween` or `AnimationPlayer` outside the ADR-0011 UI motion views, a presentation timer that adds `real_dt`, and `call_deferred`, a Tween callback or an `await` that moves the tube; ADR-0013: a `Vector3(` built from `s`, `s_offset` or `snapshot.s` outside `world_frame.gd` in view code (ADVISORY, rule `forbidden:raw_s_in_vector3`) |
| `only_in` | the regex may match only in the listed files | `ConfigFile`, `FileAccess`, `DirAccess` only in `save_service.gd`; `ResourceLoader` only in `map_loader.gd`; `get_gravity`, `get_accelerometer`, `get_gyroscope`, `get_magnetometer` only in `tilt_input.gd`; `RenderingServer.global_shader_parameter_set` only in `render_globals.gd` (ADR-0012) |
| `project_setting` | a `project.godot` key has a required value | no `[autoload]` entries for game systems; `emulate_mouse_from_touch` and `emulate_touch_from_mouse` true; only `enable_gravity` among the sensor flags; `quit_on_go_back` false; handheld orientation 1; `physics/common/physics_interpolation` false (ADR-0013) |
| `manifest` | `export_presets.cfg` and the merged release manifest | one Vulkan 1.1 `uses-feature`, VIBRATE only, `allowBackup=false`, and `exclude_filter` covering `tests/*`, `addons/gut/*`, `tools/*`, `build/*` (the draft's "nothing ships" claim is true only with this filter); skipped with a warning until the first preset exists (ADR-0006) |
| `secret` | no keystore, alias or password in the repository | `*.keystore`, `*.jks`, `keystore/password` patterns in presets |
| `custom` | a named Python function for what a regex cannot say | Pattern seeds the `RandomNumberGenerator` before its first draw; typed method references (no string-built `Callable`) at the composition root; Scoring's reflection check |

- **Fixtures that are deliberately invalid GDScript** live as `.txt` files or under a folder with a `.gdignore`; `build/` and `tools/` carry a `.gdignore` so Godot never imports them (an intentional parse error would otherwise break `--import` and the editor).
- **Registry coverage meta-rule (ADVISORY):** the runner reads `docs/registry/architecture.yaml` and reports every `forbidden_patterns` entry that has no rule `forbidden:<pattern>` and is not marked `review_only` in the rule table, so a banned pattern cannot go unenforced unnoticed.
- **Rules apply to `src/` and, where stated, `tests/` and `tools/`.** A rule whose scope has no file yet passes with a note, so rules can be committed before the code exists.
- **The lints are tested:** `tools/ci/tests/` holds Python `unittest` cases with one passing and one failing fixture file per rule; a rule without both fixtures fails the runner's self-check. The Python tests run in `run_ci.py` as step 4a.
- Rule ownership stays with the ADR or GDD named in `source`; this ADR owns only the harness.

### 6. Coverage and gates

There is **no line-coverage gate** (GUT has no built-in coverage, third-party tools are unverified on 4.7.2, and the cores are pure functions whose acceptance criteria are far more specific than a percentage). The gate is: every Logic story has automated tests that map to its GDD acceptance criteria (`/story-done` and `/test-evidence-review` check the mapping); the unit and integration suites and the lints pass; advisory tests are reported. `technical-preferences.md` "Minimum Coverage" is set to this policy.

### 7. Determinism, flakiness and isolation

- No retry, no skip, no `pending` to get a green run; a failing test is fixed, or deleted with a written reason. A test that is flaky is a defect in the test or in the code and is fixed first (`/test-flakiness` reads the JUnit XML).
- Random behavior is tested through the seeded generator and a **hardcoded seed list**; no generated seeds; no time-dependent assertion; closures that capture a counter use an `Array` or a member (a closure captures a primitive by value).
- Exact `==` for integers, codes and counts; `1e-6` for floats unless an AC states otherwise.
- Fixtures use distinct non-shipped values where a GDD says so (for example schema version 3, retention 3), with an advisory smoke test asserting the shipped defaults.

### 8. Document and skill synchronization (after this ADR is Accepted)

- `coding-standards.md`: replace the CI line with `python tools/ci/run_ci.py`; state `tests/integration` and `tests/advisory`.
- `technical-preferences.md`: Allowed libraries (GUT, MIT, pinned), Testing (GUT, coverage policy), Forbidden patterns (the registry list), Architecture Decisions Log.
- The `/test-setup`, `/smoke-check`, `/test-helpers` and `/test-flakiness` skills: replace the gdUnit4 scaffolding and commands with the GUT ones above (they are project-owned files).
- Systems-index note "GUT vs gdUnit4 must be settled before Technical Setup" is closed; the GDD open questions (Ball Movement 12, Obstacle 9, Platform Services 18, Tilt Input 16) are marked resolved.

### Architecture Diagram

```text
developer / agent                           GitHub Actions (ubuntu-latest)
   │                                              │
   └── python tools/ci/run_ci.py  <───── same ────┘   (pinned Godot 4.7.2, checksum verified)
          1  godot --headless --import
          2  GUT  tests/unit  ──► BLOCKING            tests/support/ (no framework dependency)
             GUT  tests/integration ──► BLOCKING
          3  GUT  tests/advisory ──► warning
          4  lint_runner.py  ◄── lint_rules.json  ◄── registered by ADR-0002..0008
             └─ registry coverage check ◄── docs/registry/architecture.yaml
          reports: build/test-reports/*.xml (artifact)

device evidence (not CI): production/qa/evidence/  SP-1 SP-2 SP-3 PS-* BM-1 NM-1 OB-1 MS-1
```

### Key Interfaces

```text
Commands
  python tools/ci/run_ci.py [--only unit|integration|advisory|lint|all]
  python tools/ci/lint_runner.py [--rule <id>] [--list]
  godot --headless --import                         # first step in every environment
Files
  .gutconfig.json   .github/workflows/ci.yml   tools/ci/{run_ci.py, lint_runner.py, lint_rules.json, versions.json, tests/}
Rule record (lint_rules.json)
  { "id": "only_in:ConfigFile", "source": "ADR-0007", "severity": "BLOCKING", "kind": "only_in",
    "scope": ["src/**/*.gd"], "pattern": "\\b(ConfigFile|FileAccess|DirAccess)\\b",
    "allow": ["src/**/save_service.gd"], "message": "Real file I/O belongs to SaveService only" }
```

## Alternatives Considered

### Alternative 1: gdUnit4

- **Pros**: matches the project's test skills and the old CI line; JUnit XML, a CLI and a GitHub action exist.
- **Cons**: contradicts `technical-preferences.md` and six GDDs' fixture and file conventions; its Godot 4.7 compatibility is equally unverified.
- **Rejection Reason**: the GDDs and technical preferences are the project's own decision; the skills are templates and project-owned. Kept as the **pre-committed fallback** if spike T-1 fails.

### Alternative 2: A custom minimal runner on `SceneTree`

- **Pros**: no addon, nothing to pin.
- **Cons**: assertions, reports, node tests, discovery and JUnit output all built and maintained by us.
- **Rejection Reason**: reinvents a solved problem with no benefit for a solo project.

### Alternative 3: Windows runner, or a third-party Godot Docker image, or local scripts only

- **Rejection Reason**: Windows runners are slower and costlier with no gain (OS-dependent behavior is device evidence anyway); a third-party image lags engine versions and widens the supply chain; local-only scripts cannot gate a merge to `main`.

### Alternative 4: Lints in GDScript or shell

- **Pros**: one toolchain (GDScript); fast to start (shell).
- **Cons**: comment and string stripping and glob handling are long and fragile in both; shell is poor on the Windows dev host; neither is easy to unit test.
- **Rejection Reason**: Python 3 stdlib is already on every runner and dev machine and makes the lints themselves testable.

### Alternative 5: A line-coverage gate for `src/`

- **Rejection Reason**: needs an unverified third-party tool and tends to produce tests that only touch lines; acceptance-criteria traceability is a stronger and already specified gate.

## Consequences

### Positive

- One framework, one command (local and CI), one report format; the open question that five GDDs carry is closed.
- Every registered lint has an owner file, fixtures and a severity; a banned pattern without a rule is reported.
- The evidence table of the testing standards maps one to one onto folders, so a story's required evidence is unambiguous.
- Pinned and checksummed CI inputs on a public repository, with read-only permissions.

### Negative

- New repository content: a vendored addon, `tools/ci/` (Python), a workflow, `.gutconfig.json`, three test folders, and a second runtime (Python) in CI.
- Four project skills and two docs need edits to drop their gdUnit4 assumptions.
- GUT on 4.7.2 is a bet until T-1 passes; a failure costs a port of the test files only.
- Lint rules are regexes over stripped text, not a parser, so a determined obfuscation could evade them; code review stays the second line.

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| GUT does not run on 4.7.2 | Medium | Medium (a port) | spike T-1; fallback gdUnit4; framework-free `tests/support/` |
| Headless exit code is zero on a failing test | Medium | High (a false green) | verification item 3; `run_ci.py` also parses the JUnit XML and fails on any failure or error count |
| `.godot/` cache makes a stale class cache | Low | Medium | cache key from the engine version and the `project.godot` hash; `--import` always runs |
| A lint regex has false positives that people suppress | Medium | Medium | per-rule fixtures; an explicit allowlist field, never an inline ignore comment |
| GUT finds no tests (prefix mismatch) or skips a broken test file | Medium | High (a false green) | `prefix`/`suffix` config; zero-tests and executed-count checks; `SCRIPT ERROR` scan |
| A Godot run hangs on a runner | Low | Medium | per-call timeout in `run_ci.py`, `timeout-minutes` on the job |
| Windows and Linux differ (paths, rename) | Medium | Medium | device spikes for OS-dependent behavior; one manual Windows run of ADR-0007's prerequisite |
| Unpinned or tampered CI dependency | Low | High | SHA-pinned actions, checksum-verified Godot, vendored GUT, `contents: read` |
| CI runtime grows past the budget | Low | Low | cache; split advisory tests into a separate job if needed |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| ball-movement.md | OQ12: GUT versus gdUnit4; `tools/ci/` script language for the AC-25 lint | Decisions 1 and 5 |
| obstacle-system.md | OQ9: framework; AC-24 lint over `ObstacleMath/Core/Config` and dependencies | Decisions 1 and 5 (`forbid` rules, scope globs) |
| platform-services.md | OQ18: framework; lint scripts live in `tools/ci/` (AC-12a, AC-13) | Decisions 1 and 5 (`only_in`, `project_setting`, `manifest` rules) |
| tilt-input.md | OQ16: framework and CI line; `godot --headless --import` before tests | Decisions 1, 3 and 4 |
| tube-track.md | Test types `[U]` BLOCKING; GUT with `class_name` fixtures | Decisions 1 to 3 |
| save-persistence.md | AC-16/AC-17 lints, fixtures with non-shipped values, AC-23 advisory smoke | Decisions 2, 5 and 7 |
| scoring-personal-best.md | CI lints (autoload ban BLOCKING, deny-list ADVISORY), typed-binding scan | Decision 5 (`project_setting`, `custom` rules) |
| pattern-difficulty.md | Seed-before-first-draw lint, advisory statistical test | Decisions 2 and 5 |
| near-miss-detection.md | Reuse-not-reimplement guard, engine-coupling lint | Decision 5 |
| systems-index.md | "GUT vs gdUnit4 must be settled before Technical Setup" | Decision 1 and 8 |
| coding-standards.md (project) | Testing standards, CI rules ("no merge if tests fail", never skip failing tests) | Decisions 2, 4 and 7 |

## Performance Implications

- **CPU**: CI only; target at most 5 minutes with a warm cache (the unit suite is pure and fast; `--import` and the integration suite dominate).
- **Memory**: runner only; nothing ships in the game (the addon is excluded from exports).
- **Load Time**: none in the game; `addons/gut` and `tests/` are excluded from the export presets.
- **Network**: CI downloads one checksum-verified Godot archive per cache miss.

## Migration Plan

1. Create `project.godot` (needed before T-1), then spike T-1 in a throwaway project under `prototypes/` (allowed before Acceptance, P-1) and record the exact GUT release, command and exit-code behavior.
2. Add `addons/gut/` (pinned), `.gutconfig.json`, `tests/support/`, `tools/ci/` and the first lint rules from the registered ADRs.
3. Add `.github/workflows/ci.yml`; spike T-2 is the first green run on `dev`.
4. Update the documents and skills of Decision 8 (skills are project-owned).
5. Ask the project owner whether to enable the `ci` job as a required status check on `main` (a repository setting; explicit approval needed).
6. Add the export exclusion (`exclude_filter="tests/*, addons/gut/*, tools/*, build/*"`) when the first export preset is created (ADR-0006); the `manifest` lint enforces it. Add `.gitattributes` (`eol=lf`) and the `.gdignore` files with the first scaffold commit.

## Validation Criteria

- [ ] T-1: on Windows and Linux with 4.7.2, one passing, one failing and one `SceneTree` test behave as expected headless; a non-zero exit code on failure; a JUnit XML report; `class_name` fixtures resolve after `--import`.
- [ ] T-2: the workflow runs green on a trivial test and the lint runner on `dev`, within the time budget, with checksum-verified Godot and SHA-pinned actions.
- [ ] A deliberately failing test and a deliberately violating file each turn the `ci` job red (negative controls), then are removed.
- [ ] Every lint rule has a passing and a failing fixture; the runner's self-check fails otherwise.
- [ ] The registry coverage report lists no lint-able `forbidden_patterns` entry without a rule or an explicit `review_only` mark.
- [ ] `/smoke-check` runs `python tools/ci/run_ci.py --only unit` successfully.

## Related Decisions

- ADR-0002 (no autoload, cores without engine calls), ADR-0004 (`ResourceLoader` lint, boot spike), ADR-0005 and ADR-0006 (sensor, project-setting and manifest lints), ADR-0007 (fake `SaveFs`, no file I/O in unit tests, SP-1 on a device), ADR-0008 (content preflight test, determinism lints)
- `.claude/docs/coding-standards.md`, `.claude/docs/technical-preferences.md`, `.claude/docs/git-workflow.md`
- `docs/architecture/tr-baseline/` (every Testing requirement), `design/gdd/systems-index.md`
