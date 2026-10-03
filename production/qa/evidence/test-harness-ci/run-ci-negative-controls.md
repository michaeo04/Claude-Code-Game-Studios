# run_ci.py negative controls (story TH-004)

> **Date**: 2026-10-03. **Host**: Windows 11, Godot 4.7.2 headless, GUT v9.7.1, `python tools/ci/run_ci.py --only unit`.
> **Purpose**: show that each result guard of ADR-0009 Decision 3 makes the command fail, because the Godot exit code alone cannot be trusted (spike T-1 items 3 and 13).

| # | Control (temporary, removed afterwards) | Godot's own exit code | `run_ci.py` result |
|---|---|---|---|
| 1 | one deliberately failing test **and** one test script with a parse error | 1 | **FAIL**, exit 1: "1 SCRIPT ERROR/Parse Error line(s) ... 1 failing test(s) in report: test_deliberate_failure" |
| 2 | only the parse-error test script next to the passing smoke test | **0** | **FAIL**, exit 1: "1 SCRIPT ERROR/Parse Error line(s), first: SCRIPT ERROR: Parse Error: Expected closing ")" after call arguments." (this is the trap: Godot exits 0 and the remaining tests are green) |
| 3 | zero test files under `tests/unit` | 0 | **FAIL**, exit 1: "no *_test.gd file under tests/unit: zero tests is a failure (ADR-0009)" |
| 4 | `CI_GODOT_TIMEOUT=1` (a Godot call that cannot finish in time) | killed by the wrapper | **FAIL**, exit 1: "import timed out after 1s" |
| 5 | `GODOT` pointing at a script that reports engine `4.6.0` | n/a | **not OK**, exit 2: "engine version '4.6.0' is not the pinned '4.7.2'", result `INCOMPLETE` |
| 6 | all controls removed | 0 | **OK**, exit 0, 3 tests passing |

Controls covered by Python unit tests (`tools/ci/tests/test_run_ci.py`) rather than re-run here: the timeout wrapper (`test_timeout_kills_a_hung_process`), a JUnit file with fewer tests than `*_test.gd` files, a missing JUnit file, a missing Godot binary (clear message, exit 2, no traceback). The expected version value (`expected_engine_version` returns `4.7.2`) is unit-tested.

Not covered by this evidence: the `integration` and `advisory` suites (no test files exist yet; `integration` is skipped with a note, `advisory` failure is a warning by design), and the second-import-pass decision, which T-1 settled as "one pass is enough".
