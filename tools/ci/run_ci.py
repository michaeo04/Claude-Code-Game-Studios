#!/usr/bin/env python3
"""One entry command for tests and lints (ADR-0009 Decision 3). Python 3, standard library only.

Usage:
    python tools/ci/run_ci.py [--only unit|integration|advisory|lint|all]

Steps, in order (`all`):
    1   godot --headless --path . --import
    2   GUT over tests/unit, then tests/integration            (BLOCKING)
    3   GUT over tests/advisory                                (failure is a warning)
    4a  Python unittest in tools/ci/tests/                     (BLOCKING, offline)
    4   python tools/ci/lint_runner.py                         (BLOCKING, offline)

A GUT run without step 1 is invalid: `class_name` types (GameRoot, the cores) do not resolve without the import
pass, and the suites are skipped when step 1 fails.

`--only unit` / `integration` / `advisory` run step 1 plus that suite. `--only lint` runs 4a and 4
only, needs no Godot, and works before project.godot exists.

Godot binary: env GODOT, else versions.json `godot.local_path`, else `godot` on PATH. The engine
version must be exactly the one pinned in versions.json (4.7.2).

A green exit code is never trusted. For every GUT run: the JUnit XML must exist (stale reports are
deleted first), report more than zero tests, at least as many tests as there are *_test.gd files,
and zero failures, errors and skips; the output is scanned for "SCRIPT ERROR" and "Parse Error".
Every Godot call runs under a timeout (env CI_GODOT_TIMEOUT seconds, default 600).

Exit code: 0 all green, 1 a BLOCKING failure, 2 a prerequisite is missing (project.godot,
addons/gut, Godot binary) and nothing else failed. GUT option names are the expected GUT 9 names,
unverified on 4.7.2 until spike T-1.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

CI_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(CI_DIR))
VERSIONS_PATH = os.path.join(CI_DIR, "versions.json")
REPORT_DIR = os.path.join("build", "test-reports")
ERROR_MARKERS = ("SCRIPT ERROR", "Parse Error")
SUITES = {
    "unit": ("tests/unit", True),
    "integration": ("tests/integration", True),
    "advisory": ("tests/advisory", False),
}


class Prerequisite(Exception):
    """A required tool or file is missing; the message tells the user what to do."""


def load_versions(path: str = VERSIONS_PATH) -> dict:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError) as exc:
        raise Prerequisite(f"cannot read {path}: {exc}")


def expected_engine_version(versions: dict) -> str:
    return str(versions.get("godot", {}).get("version", "4.7.2-stable")).split("-")[0]


def timeout_seconds() -> int:
    try:
        return int(os.environ.get("CI_GODOT_TIMEOUT", "600"))
    except ValueError:
        return 600


def find_godot(versions: dict, env=None) -> str:
    """Resolve the Godot binary: env GODOT, versions.json godot.local_path, then PATH."""
    env = os.environ if env is None else env
    candidates = [env.get("GODOT"), versions.get("godot", {}).get("local_path")]
    for c in candidates:
        if c:
            if os.path.isfile(c):
                return c
            raise Prerequisite(f"Godot binary not found at {c!r} (from GODOT or versions.json godot.local_path)")
    from shutil import which
    found = which("godot")
    if found:
        return found
    raise Prerequisite("Godot binary not found: set the GODOT environment variable to the Godot 4.7.2 executable "
                       "(or godot.local_path in tools/ci/versions.json, or put `godot` on PATH)")


def run_with_timeout(cmd, cwd, timeout):
    """Run a command, capture combined output; returns (exit_code, output, timed_out)."""
    try:
        proc = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        return proc.returncode, proc.stdout.decode("utf-8", errors="replace"), False
    except subprocess.TimeoutExpired as exc:
        out = (exc.stdout or b"").decode("utf-8", errors="replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        return -1, out, True
    except OSError as exc:
        return -1, f"cannot start {cmd[0]!r}: {exc}", False


def check_engine_version(godot: str, versions: dict) -> str:
    code, out, timed_out = run_with_timeout([godot, "--version"], REPO_ROOT, 60)
    want = expected_engine_version(versions)
    if timed_out or code != 0:
        raise Prerequisite(f"`{godot} --version` failed (exit {code}): {out.strip()[:200]}")
    m = re.match(r"\s*(\d+\.\d+\.\d+)", out)
    got = m.group(1) if m else out.strip()[:40]
    print(f"Godot engine version: {out.strip()} (required {want})")
    if got != want:
        raise Prerequisite(f"engine version {got!r} is not the pinned {want!r}")
    return out.strip()


def count_test_files(directory: str) -> int:
    total = 0
    for _dp, _dn, files in os.walk(directory):
        total += sum(1 for f in files if f.endswith("_test.gd"))
    return total


def scan_output(output: str) -> list[str]:
    """Lines containing SCRIPT ERROR or Parse Error (a failing signal even with exit code 0)."""
    return [ln.strip() for ln in output.splitlines() if any(m in ln for m in ERROR_MARKERS)]


def check_junit(xml_path: str, test_files: int) -> list[str]:
    """Return a list of problems with a JUnit report (empty when it is trustworthy)."""
    if not os.path.isfile(xml_path):
        return [f"JUnit report missing: {xml_path}"]
    try:
        root = ET.parse(xml_path).getroot()
    except ET.ParseError as exc:
        return [f"JUnit report unreadable: {exc}"]
    cases = list(root.iter("testcase"))
    problems = []
    if len(cases) == 0:
        problems.append("JUnit report has zero tests")
    elif len(cases) < test_files:
        problems.append(f"JUnit report has {len(cases)} test(s) but there are {test_files} *_test.gd file(s): a script was skipped or failed to parse")
    bad = [c for c in cases if c.find("failure") is not None or c.find("error") is not None]
    skipped = [c for c in cases if c.find("skipped") is not None]
    attr_fail = 0
    for suite in root.iter("testsuite"):
        for attr in ("failures", "errors"):
            try:
                attr_fail += int(suite.get(attr, "0"))
            except ValueError:
                pass
    if bad or attr_fail:
        names = ", ".join(c.get("name", "?") for c in bad[:5])
        problems.append(f"{max(len(bad), attr_fail)} failing test(s) in report: {names}")
    if skipped:
        problems.append(f"{len(skipped)} skipped/pending test(s): skipping is not allowed")
    return problems


class Runner:
    def __init__(self, only: str):
        self.only = only
        self.blocking_failed = False
        self.missing_prereq = False
        self.warnings: list[str] = []
        self.summary: list[str] = []
        self.godot: str | None = None
        self.versions: dict | None = None

    # ---- bookkeeping
    def record(self, name: str, status: str, detail: str = ""):
        line = f"{status:8} {name}" + (f"  {detail}" if detail else "")
        self.summary.append(line)
        print(line)

    def fail(self, name: str, detail: str):
        self.blocking_failed = True
        self.record(name, "FAIL", detail)

    def prereq(self, name: str, message: str):
        self.missing_prereq = True
        self.record(name, "MISSING", message)
        print(f"error: {message}", file=sys.stderr)

    # ---- godot steps
    def godot_ready(self) -> bool:
        """Check project.godot, binary and version once. Returns False (and records why) when not runnable."""
        if self.godot:
            return True
        if not os.path.isfile(os.path.join(REPO_ROOT, "project.godot")):
            self.prereq("godot", "project.godot not found: create the project first (ADR-0009 Migration Plan step 1); "
                                 "Godot steps skipped. `--only lint` works without it.")
            return False
        try:
            self.versions = load_versions()
            godot = find_godot(self.versions)
            check_engine_version(godot, self.versions)
        except Prerequisite as exc:
            self.prereq("godot", str(exc))
            return False
        self.godot = godot
        return True

    def step_import(self) -> bool:
        if not self.godot_ready():
            return False
        print("== step 1: godot --headless --path . --import")
        code, out, timed_out = run_with_timeout([self.godot, "--headless", "--path", ".", "--import"], REPO_ROOT, timeout_seconds())
        self._write_log("import", out)
        errors = scan_output(out)
        if timed_out:
            self.fail("import", f"timed out after {timeout_seconds()}s")
        elif code != 0:
            self.fail("import", f"exit code {code}")
        elif errors:
            self.fail("import", f"{len(errors)} error line(s), first: {errors[0]}")
        else:
            self.record("import", "ok")
            return True
        return False

    def step_suite(self, suite: str) -> None:
        directory, blocking = SUITES[suite]
        abs_dir = os.path.join(REPO_ROOT, directory)
        files = count_test_files(abs_dir) if os.path.isdir(abs_dir) else 0
        label = f"gut:{suite}"
        if not os.path.isfile(os.path.join(REPO_ROOT, "addons", "gut", "gut_cmdln.gd")):
            self.prereq(label, "addons/gut/gut_cmdln.gd not found: GUT is not vendored yet (spike T-1, ADR-0009)")
            return
        if files == 0:
            if blocking and suite == "unit":
                self.fail(label, f"no *_test.gd file under {directory}: zero tests is a failure (ADR-0009)")
            else:
                self.record(label, "skipped", f"no *_test.gd file under {directory}")
            return
        print(f"== GUT {suite} ({files} test file(s))")
        xml_rel = f"{REPORT_DIR}/{suite}.xml".replace("\\", "/")
        os.makedirs(os.path.join(REPO_ROOT, REPORT_DIR), exist_ok=True)
        xml_abs = os.path.join(REPO_ROOT, xml_rel)
        if os.path.exists(xml_abs):
            os.remove(xml_abs)  # never trust a stale report
        cmd = [self.godot, "--headless", "--path", ".", "-s", "addons/gut/gut_cmdln.gd",
               "-gconfig=res://.gutconfig.json", f"-gdir=res://{directory}/", "-ginclude_subdirs", "-gexit",
               f"-gjunit_xml_file=res://{xml_rel}"]
        code, out, timed_out = run_with_timeout(cmd, REPO_ROOT, timeout_seconds())
        self._write_log(suite, out)
        problems = []
        if timed_out:
            problems.append(f"timed out after {timeout_seconds()}s")
        elif code != 0:
            problems.append(f"exit code {code}")
        errors = scan_output(out)
        if errors:
            problems.append(f"{len(errors)} SCRIPT ERROR/Parse Error line(s), first: {errors[0]}")
        problems.extend(check_junit(xml_abs, files))
        if not problems:
            self.record(label, "ok")
        elif blocking:
            self.fail(label, "; ".join(problems))
        else:
            msg = "; ".join(problems)
            self.warnings.append(f"{label}: {msg}")
            self.record(label, "WARN", msg)

    def _write_log(self, name: str, output: str) -> None:
        try:
            os.makedirs(os.path.join(REPO_ROOT, REPORT_DIR), exist_ok=True)
            gdignore = os.path.join(REPO_ROOT, "build", ".gdignore")
            if not os.path.exists(gdignore):
                with open(gdignore, "w", encoding="utf-8") as fh:
                    fh.write("# Generated output; Godot must never import this folder.\n")
            with open(os.path.join(REPO_ROOT, REPORT_DIR, f"{name}.log"), "w", encoding="utf-8") as fh:
                fh.write(output)
        except OSError:
            pass

    # ---- offline steps
    def step_python_tests(self) -> None:
        print("== step 4a: python unittest tools/ci/tests")
        code, out, _t = run_with_timeout([sys.executable, "-m", "unittest", "discover", "-s", os.path.join("tools", "ci", "tests")],
                                         REPO_ROOT, 300)
        if code != 0:
            print(out)
            self.fail("python-tests", f"exit code {code}")
        else:
            tail = out.strip().splitlines()[-1:] or [""]
            self.record("python-tests", "ok", tail[0])

    def step_lint(self) -> None:
        print("== step 4: lint_runner.py")
        code, out, _t = run_with_timeout([sys.executable, os.path.join("tools", "ci", "lint_runner.py")], REPO_ROOT, 300)
        print(out.rstrip())
        if code != 0:
            self.fail("lint", f"exit code {code}")
        else:
            self.record("lint", "ok")

    # ---- driver
    def run(self) -> int:
        started = time.time()
        only = self.only
        wanted_suites = ["unit", "integration", "advisory"] if only == "all" else ([only] if only in SUITES else [])
        if wanted_suites:
            imported = self.step_import()
            if imported:
                for s in wanted_suites:
                    if s == "advisory" or not self.blocking_failed:
                        self.step_suite(s)
                    else:
                        self.record(f"gut:{s}", "skipped", "an earlier BLOCKING step failed")
        if only in ("all", "lint"):
            self.step_python_tests()  # offline steps always run: cheap and independent of Godot
            self.step_lint()
        print("\n== summary")
        for line in self.summary:
            print(line)
        for w in self.warnings:
            print(f"warning: {w}")
        print(f"elapsed: {time.time() - started:.1f}s")
        if self.blocking_failed:
            print("CI RESULT: FAIL")
            return 1
        if self.missing_prereq:
            print("CI RESULT: INCOMPLETE (a prerequisite is missing, see messages above)")
            return 2
        print("CI RESULT: OK")
        return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Run the project tests and lints (ADR-0009 Decision 3)")
    ap.add_argument("--only", choices=["unit", "integration", "advisory", "lint", "all"], default="all")
    args = ap.parse_args(argv)
    return Runner(args.only).run()


if __name__ == "__main__":
    sys.exit(main())
