# Test Infrastructure

**Engine**: Godot 4.7.2 (GDScript, Android only)
**Test framework**: GUT 9.x, vendored under `addons/gut/` and pinned (ADR-0009, Proposed). Not installed yet: spike T-1 picks and verifies the release.
**CI**: `.github/workflows/ci.yml` (manual trigger only until spike T-2 is green)
**Setup date**: 2026-10-03

## Status

This is a scaffold. Nothing here runs yet:

| Missing | Needed for | Owner step |
|---|---|---|
| `project.godot` | every headless run | first scaffold story |
| `addons/gut/` and the GUT release tag | running any test | spike T-1 (ADR-0009) |
| `tools/ci/run_ci.py`, `lint_runner.py`, `lint_rules.json` | the one entry command | ADR-0009 Migration Plan step 2 |
| `godot.sha512` in `tools/ci/versions.json` | CI Godot download | project owner, by hand |

`.gutconfig.json` option names (`dirs`, `include_subdirs`, `prefix`, `suffix`, `should_exit`, `junit_xml_file`) are the expected GUT 9 names and are **unverified on 4.7.2** until T-1.

## Directory Layout

```text
tests/
  unit/<system>/<system>_<feature>_test.gd          Logic evidence, BLOCKING. Fakes only, no file I/O, no SceneTree except [N] node tests
  integration/<system>/<system>_<feature>_test.gd   Integration and content evidence, BLOCKING
  advisory/<system>/<system>_<feature>_test.gd      Shipped-defaults smoke and statistical tests, ADVISORY
  support/                                          Fixtures, fakes, recorders: plain RefCounted, no GUT dependency
  smoke/critical-paths.md                           15-minute manual gate read by /smoke-check
production/qa/evidence/                             Visual/Feel, UI and device-spike evidence (not run in CI)
tools/ci/                                           run_ci.py, lint_runner.py, lint_rules.json, versions.json
```

## Running Tests (once T-1 and `run_ci.py` exist)

```bash
godot --headless --path . --import        # first, in every environment (class cache for class_name)
python tools/ci/run_ci.py                 # all: unit, integration, advisory, lints
python tools/ci/run_ci.py --only unit     # what /smoke-check calls
```

A green exit code is not trusted: `run_ci.py` checks the JUnit XML (more than zero tests, at least as many as `*_test.gd` files, zero failures) and scans the output for `SCRIPT ERROR` and `Parse Error`.

## Test Naming

- **Files**: `[system]_[feature]_test.gd` (GUT's default prefix is `test_`, so `.gutconfig.json` sets prefix `""` and suffix `_test.gd`)
- **Classes**: `extends GutTest`
- **Functions**: `test_[scenario]_[expected]`
- **Support code**: `const X = preload("res://tests/support/x.gd")`; no GUT call inside `tests/support/`

## Story Type to Test Evidence

| Story Type | Required Evidence | Location | In CI |
|---|---|---|---|
| Logic | Automated unit test, must pass | `tests/unit/[system]/` | BLOCKING |
| Integration | Integration test or documented playtest | `tests/integration/[system]/` | BLOCKING |
| Integration needing a device (spikes) | Device evidence at its named gate | `production/qa/evidence/` | not run |
| Visual/Feel | Screenshot and lead sign-off | `production/qa/evidence/` | ADVISORY |
| UI | Manual walkthrough or interaction test | `production/qa/evidence/` | ADVISORY |
| Config/Data | Smoke check pass | `production/qa/smoke-[date].md`, `tests/advisory/` | ADVISORY |

## Rules (testing standards and ADR-0009)

- Deterministic: no real time, no unseeded randomness; hardcoded seed lists.
- Isolated: each test sets up and tears down its own state; no order dependence.
- No retry, no skip, no `pending` to get a green run.
- Unit tests never touch the real file system, `ResourceLoader` or `Time`.
- There is no line-coverage gate; the gate is acceptance-criteria traceability, the suites and the lints.
