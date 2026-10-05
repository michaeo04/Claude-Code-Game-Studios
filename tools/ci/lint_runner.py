#!/usr/bin/env python3
"""Lint runner for the project (ADR-0009 Decision 5). Python 3, standard library only.

Usage:
    python tools/ci/lint_runner.py [--rule <id>] [--list] [--coverage] [--verbose] [--root <dir>] [--fixtures-dir <dir>]

Reads tools/ci/lint_rules.json (rule table) and scans the repository.
GDScript files are scanned after comments and string literals are stripped by ONE
left-to-right state machine (strip_gdscript). Quotes are kept as "" so rules that
look for string arguments still work. Newlines are preserved, so line numbers match.

Rule kinds: forbid, only_in, project_setting, manifest, secret, custom.
Severity: BLOCKING (fails the run) or ADVISORY (reported, never fails).

Rule record fields (see tools/ci/lint_rules.json):
    id, source, severity, kind, message              always
    scope [globs], exclude [globs], allow [globs]    forbid / only_in / secret / custom
    pattern (regex, MULTILINE), pattern_on "raw"     forbid / only_in / secret
    keep_strings true                                keep string contents (comments still stripped)
    stub true                                        custom stub: needs only a passing fixture
    vacuous_pass_ok true                             the passing fixture may be out of scope

Silencing a rule is done ONLY with the `allow` / `exclude` fields (registry pattern
`lint_ignore_comment`); inline ignore comments are not supported.

Self-check: every rule needs tools/ci/tests/fixtures/<safe_id>/pass.txt and fail.txt
(first line `#@path: <virtual repo path>`). The passing fixture must produce no
violation of its rule (and be in scope); the failing one must produce at least one.

Exit code: 1 on a BLOCKING violation or a self-check failure, 2 on a broken rule table, else 0.
"""
from __future__ import annotations

import argparse
import functools
import json
import os
import re
import sys
from dataclasses import dataclass

CI_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(CI_DIR))
RULES_PATH = os.path.join(CI_DIR, "lint_rules.json")
FIXTURES_DIR = os.path.join(CI_DIR, "tests", "fixtures")
REGISTRY_REL = "docs/registry/architecture.yaml"

# Directories never scanned (vendored, generated, throwaway).
SKIP_DIRS = {".git", ".godot", "build", "prototypes", "node_modules", "__pycache__", "addons"}
KINDS = ("forbid", "only_in", "project_setting", "manifest", "secret", "custom")
SEVERITIES = ("BLOCKING", "ADVISORY")
FIXTURE_HEADER = "#@path:"


# --------------------------------------------------------------------------- stripping

def strip_gdscript(text: str, keep_strings: bool = False) -> str:
    """Remove comments and string literals from GDScript with one state machine.

    Handles `#` and `##` comments, `#` inside strings, single, double and triple
    quoted strings, backslash escapes, and the r"..", &"..", ^".." prefixes. `$Node/Path`
    and `%Unique` are not strings and pass through. String bodies become "" (quotes kept)
    unless keep_strings is true. Newlines are preserved. CRLF and LF both work.
    """
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == "#":
            while i < n and text[i] not in "\r\n":
                i += 1
            continue
        j = i
        prefix = ""
        if c in "r&^" and i + 1 < n and text[i + 1] in "\"'":
            prev = text[i - 1] if i > 0 else ""
            if not (c == "r" and (prev.isalnum() or prev == "_")):
                prefix = c
                j = i + 1
        if j < n and text[j] in "\"'":
            q = text[j]
            triple = text.startswith(q * 3, j)
            k = j + (3 if triple else 1)
            body_start = k
            while k < n:
                ch = text[k]
                if ch == "\\":
                    k += 3 if text.startswith("\r\n", k + 1) else 2
                    continue
                if triple:
                    if text.startswith(q * 3, k):
                        break
                else:
                    if ch == q or ch == "\n":
                        break
                k += 1
            k = min(k, n)
            body = text[body_start:k]
            closed = False
            if triple and text.startswith(q * 3, k):
                end, closed = k + 3, True
            elif not triple and k < n and text[k] == q:
                end, closed = k + 1, True
            else:
                end = k
            if keep_strings:
                opener = q * (3 if triple else 1)
                out.append(prefix + opener + body + (opener if closed else ""))
            else:
                out.append(prefix + '""' + "".join(re.findall(r"\r?\n", body)))
            i = end
            continue
        out.append(c)
        i += 1
    return "".join(out)


def strip_c_style(text: str, keep_strings: bool = False) -> str:
    """Same idea for shader files: `//` and `/* */` comments and "strings"."""
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if text.startswith("//", i):
            while i < n and text[i] not in "\r\n":
                i += 1
            continue
        if text.startswith("/*", i):
            end = text.find("*/", i + 2)
            end = n if end == -1 else end + 2
            out.append(" " + "\n" * text.count("\n", i, end))
            i = end
            continue
        if c == '"':
            k = i + 1
            while k < n and text[k] != '"' and text[k] != "\n":
                k += 2 if text[k] == "\\" else 1
            k = min(k, n)
            body = text[i + 1:k]
            closed = k < n and text[k] == '"'
            if keep_strings:
                out.append('"' + body + ('"' if closed else ""))
            else:
                out.append('""' + "\n" * body.count("\n"))
            i = k + 1 if closed else k
            continue
        out.append(c)
        i += 1
    return "".join(out)


def prepare_text(path: str, text: str, rule: dict) -> str:
    """Return the text a rule's regex scans (stripped for .gd / shaders, raw otherwise)."""
    if rule.get("pattern_on") == "raw":
        return text
    keep = bool(rule.get("keep_strings"))
    if path.endswith(".gd"):
        return strip_gdscript(text, keep)
    if path.endswith((".gdshader", ".gdshaderinc")):
        return strip_c_style(text, keep)
    return text


# --------------------------------------------------------------------------- globs and sources

@functools.lru_cache(maxsize=None)
def glob_to_regex(glob: str) -> "re.Pattern[str]":
    """Glob with `**` (any depth, including none after `**/`), `*` and `?` to a regex."""
    out = ""
    i = 0
    while i < len(glob):
        if glob.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif glob.startswith("**", i):
            out += ".*"
            i += 2
        elif glob[i] == "*":
            out += "[^/]*"
            i += 1
        elif glob[i] == "?":
            out += "[^/]"
            i += 1
        else:
            out += re.escape(glob[i])
            i += 1
    return re.compile("^" + out + "$")


def matches_any(path: str, globs) -> bool:
    return any(glob_to_regex(g).match(path) for g in globs or [])


class MemSource:
    """In-memory file set (used by fixtures and unit tests). Paths use forward slashes."""

    def __init__(self, files: dict):
        self._files = dict(files)

    def all_paths(self):
        return sorted(self._files)

    def read(self, path: str) -> str:
        return self._files[path]

    def exists(self, path: str) -> bool:
        return path in self._files

    def files(self, scope, exclude=()):
        return [p for p in self.all_paths() if matches_any(p, scope) and not matches_any(p, exclude)]


class FsSource(MemSource):
    """File-system source rooted at the repository root."""

    def __init__(self, root: str):
        self.root = root
        self._paths = None
        self._cache: dict = {}

    def all_paths(self):
        if self._paths is None:
            found = []
            for dirpath, dirnames, filenames in os.walk(self.root):
                dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
                for name in filenames:
                    rel = os.path.relpath(os.path.join(dirpath, name), self.root)
                    found.append(rel.replace(os.sep, "/"))
            self._paths = sorted(found)
        return self._paths

    def read(self, path: str) -> str:
        if path not in self._cache:
            with open(os.path.join(self.root, path), "r", encoding="utf-8", errors="replace", newline="") as fh:
                self._cache[path] = fh.read()
        return self._cache[path]

    def exists(self, path: str) -> bool:
        return os.path.isfile(os.path.join(self.root, path))


# --------------------------------------------------------------------------- results

@dataclass
class Violation:
    rule_id: str
    severity: str
    path: str
    line: int
    message: str

    def format(self) -> str:
        return f"{self.path}:{self.line}: [{self.severity}] {self.rule_id}: {self.message}"


class Result:
    def __init__(self):
        self.violations: list[Violation] = []
        self.notes: list[str] = []


def _line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def _viol(rule: dict, path: str, line: int, message: str | None = None) -> Violation:
    return Violation(rule["id"], rule["severity"], path, line, message or rule["message"])


# --------------------------------------------------------------------------- kinds

def eval_pattern_rule(rule: dict, source) -> Result:
    """kind forbid / only_in / secret (content): regex must not match outside `allow`."""
    res = Result()
    files = source.files(rule.get("scope", []), rule.get("exclude", []))
    if not files:
        res.notes.append(f"{rule['id']}: no file in scope, passes")
        return res
    rx = re.compile(rule["pattern"], re.MULTILINE)
    for path in files:
        if matches_any(path, rule.get("allow", [])):
            continue
        scanned = prepare_text(path, source.read(path), rule)
        for m in rx.finditer(scanned):
            res.violations.append(_viol(rule, path, _line_of(scanned, m.start())))
    return res


def eval_secret(rule: dict, source) -> Result:
    if not rule.get("names_only"):
        return eval_pattern_rule(rule, source)
    res = Result()
    files = source.files(rule.get("scope", []), rule.get("exclude", []))
    if not files:
        res.notes.append(f"{rule['id']}: no file in scope, passes")
    for path in files:
        res.violations.append(_viol(rule, path, 1))
    return res


def parse_project_godot(text: str):
    """Parse project.godot / .cfg into (section, key, value, line) tuples (single-line values)."""
    entries = []
    section = ""
    depth = 0  # open [ / { / ( of a value that continues on the next lines (input maps, arrays)
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if depth > 0:
            depth += _bracket_delta(line)
            continue
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            continue
        if "=" in line:
            key, _, value = line.partition("=")
            entries.append((section, key.strip(), value.strip(), number))
            depth = max(0, _bracket_delta(value))
    return entries


def _bracket_delta(fragment: str) -> int:
    """Net count of opening minus closing brackets outside double-quoted strings."""
    delta = 0
    in_str = False
    escaped = False
    for ch in fragment:
        if in_str:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch in "[{(":
            delta += 1
        elif ch in "]})":
            delta -= 1
    return delta


def _norm(value: str) -> str:
    return value.strip().strip('"').strip().lower()


def eval_project_setting(rule: dict, source) -> Result:
    res = Result()
    fname = rule.get("file", "project.godot")
    if not source.exists(fname):
        res.notes.append(f"{rule['id']}: {fname} not found, passes (rule applies once the project exists)")
        return res
    entries = parse_project_godot(source.read(fname))
    full = [((f"{s}/{k}" if s else k), s, v, ln) for s, k, v, ln in entries]
    check = rule["check"]
    if check == "equals":
        hits = [(k, v, ln) for k, s, v, ln in full if k == rule["key"]]
        if not hits:
            if rule.get("required", True):
                res.violations.append(_viol(rule, fname, 1, f"{rule['key']} is missing; expected {rule['value']}. {rule['message']}"))
        for k, v, ln in hits:
            if _norm(v) != _norm(str(rule["value"])):
                res.violations.append(_viol(rule, fname, ln, f"{k}={v}, expected {rule['value']}. {rule['message']}"))
    elif check == "present":
        if not any(k == rule["key"] for k, s, v, ln in full) and rule.get("required", True):
            res.violations.append(_viol(rule, fname, 1, f"{rule['key']} is missing. {rule['message']}"))
    elif check == "section_empty":
        allowed = set(rule.get("allow_keys", []))
        for k, s, v, ln in full:
            if s == rule["section"] and k.split("/", 1)[-1] not in allowed:
                res.violations.append(_viol(rule, fname, ln, f"[{s}] entry {k.split('/', 1)[-1]}: {rule['message']}"))
    elif check == "only_true":
        allowed = set(rule.get("allow_keys", []))
        for k, s, v, ln in full:
            if k.startswith(rule["prefix"]) and _norm(v) == "true" and k not in allowed:
                res.violations.append(_viol(rule, fname, ln, f"{k}=true: {rule['message']}"))
    else:
        raise ValueError(f"unknown project_setting check {check!r}")
    return res


def eval_manifest(rule: dict, source) -> Result:
    res = Result()
    fname = rule.get("file", "export_presets.cfg")
    if not source.exists(fname):
        res.notes.append(f"{rule['id']}: WARNING {fname} not found, skipped until the first export preset exists (ADR-0006)")
        return res
    text = source.read(fname)
    for pattern in rule.get("forbid", []):
        for m in re.finditer(pattern, text, re.MULTILINE):
            res.violations.append(_viol(rule, fname, _line_of(text, m.start())))
    for pattern in rule.get("require", []):
        if not re.search(pattern, text, re.MULTILINE):
            res.violations.append(_viol(rule, fname, 1, f"required entry /{pattern}/ not found. {rule['message']}"))
    for spec in rule.get("max_matches", []):
        found = list(re.finditer(spec["pattern"], text, re.MULTILINE))
        if len(found) > spec["max"]:
            res.violations.append(_viol(rule, fname, _line_of(text, found[spec["max"]].start()),
                                        f"{len(found)} matches of /{spec['pattern']}/, at most {spec['max']}. {rule['message']}"))
    for spec in rule.get("lines_require", []):
        lines = [(n, ln) for n, ln in enumerate(text.splitlines(), start=1) if re.search(spec["line_pattern"], ln)]
        if not lines:
            res.violations.append(_viol(rule, fname, 1, f"no line matches /{spec['line_pattern']}/. {rule['message']}"))
        for n, ln in lines:
            for needle in spec["contains"]:
                if needle not in ln:
                    res.violations.append(_viol(rule, fname, n, f"missing {needle!r}. {rule['message']}"))
    return res


# ---- custom functions (named in the rule's `function` field)

def custom_tscn_connection_deferred(rule: dict, source) -> Result:
    """Scene-file rule: a [connection] on a control signal must not carry the deferred flag (bit 1)."""
    res = Result()
    files = source.files(rule.get("scope", ["**/*.tscn"]), rule.get("exclude", []))
    if not files:
        res.notes.append(f"{rule['id']}: no file in scope, passes")
        return res
    sig_rx = re.compile(rule.get("signal_pattern", r"^(run_\w+|hit_reported|window_\w+)$"))
    for path in files:
        text = source.read(path)
        for number, line in enumerate(text.splitlines(), start=1):
            if not line.startswith("[connection"):
                continue
            sig = re.search(r'\bsignal="([^"]*)"', line)
            flags = re.search(r"\bflags=(\d+)", line)
            if sig and flags and sig_rx.match(sig.group(1)) and int(flags.group(1)) & 1:
                res.violations.append(_viol(rule, path, number))
    return res


def custom_rng_seeded_before_draw(rule: dict, source) -> Result:
    """Textual-order heuristic: a RandomNumberGenerator draw must come after a seed assignment."""
    res = Result()
    files = source.files(rule.get("scope", []), rule.get("exclude", []))
    if not files:
        res.notes.append(f"{rule['id']}: no file in scope, passes")
        return res
    draw = re.compile(r"\.(?:randi|randf|randi_range|randf_range|rand_weighted|randfn)\s*\(")
    seed = re.compile(r"\.seed\s*=(?!=)|\bset_seed\s*\(|\.state\s*=(?!=)")
    for path in files:
        text = strip_gdscript(source.read(path))
        d = draw.search(text)
        if not d:
            continue
        s = seed.search(text)
        if s is None or s.start() > d.start():
            res.violations.append(_viol(rule, path, _line_of(text, d.start())))
    return res


def custom_rng_construction_seeded(rule: dict, source) -> Result:
    """Each `RandomNumberGenerator.new()` needs a seed assignment after it, before any draw and before the next
    construction (textual-order heuristic; the replay test is the real backstop)."""
    res = Result()
    files = source.files(rule.get("scope", []), rule.get("exclude", []))
    if not files:
        res.notes.append(f"{rule['id']}: no file in scope, passes")
        return res
    ctor = re.compile(r"\bRandomNumberGenerator\s*\.\s*new\s*\(")
    draw = re.compile(r"\.(?:randi|randf|randi_range|randf_range|rand_weighted|randfn)\s*\(")
    seed = re.compile(r"\.seed\s*=(?!=)|\bset_seed\s*\(")
    for path in files:
        text = strip_gdscript(source.read(path))
        starts = [m.start() for m in ctor.finditer(text)]
        for k, pos in enumerate(starts):
            end = starts[k + 1] if k + 1 < len(starts) else len(text)
            seg = text[pos:end]
            s_m = seed.search(seg)
            d_m = draw.search(seg)
            if s_m is None or (d_m is not None and d_m.start() < s_m.start()):
                res.violations.append(_viol(rule, path, _line_of(text, pos)))
    return res


def custom_noninteractive_mouse_filter(rule: dict, source) -> Result:
    """A Panel / PanelContainer / ColorRect node in a scene must set mouse_filter to PASS (1) or IGNORE (2)
    unless its name marks it as interactive (scrim, tap catcher, ink cover)."""
    res = Result()
    files = source.files(rule.get("scope", ["**/*.tscn"]), rule.get("exclude", []))
    if not files:
        res.notes.append(f"{rule['id']}: no file in scope, passes")
        return res
    types = set(rule.get("types", ["Panel", "PanelContainer", "ColorRect"]))
    interactive = re.compile(rule.get("interactive_names", r"(?i)(scrim|tap_?catcher|ink_?cover)"))
    for path in files:
        blocks = []  # (line, name, type, body)
        for number, line in enumerate(source.read(path).splitlines(), start=1):
            if line.startswith("[node "):
                name = re.search(r'name="([^"]*)"', line)
                ntype = re.search(r'\btype="([^"]*)"', line)
                blocks.append([number, name.group(1) if name else "", ntype.group(1) if ntype else "", []])
            elif line.startswith("["):
                blocks.append([number, "", "", []])
            elif blocks:
                blocks[-1][3].append(line)
        for number, name, ntype, body in blocks:
            if ntype not in types or interactive.search(name):
                continue
            if not any(re.match(r"\s*mouse_filter\s*=\s*[12]\s*$", b) for b in body):
                res.violations.append(_viol(rule, path, number, f"node {name} ({ntype}) keeps mouse_filter STOP. {rule['message']}"))
    return res


def custom_scoring_reflection_check(rule: dict, source) -> Result:
    """Stub: Scoring's reflection check is not specified precisely enough to implement yet."""
    res = Result()
    res.notes.append(f"{rule['id']}: stub (Scoring reflection check not implemented), passes")
    return res


def custom_function_body_forbid(rule: dict, source) -> Result:
    """The body of `func <function_name>(` (up to the next top-level line) must not match `pattern`.
    A same-named function in a nested class counts too; other functions in the file are ignored."""
    res = Result()
    files = source.files(rule.get("scope", []), rule.get("exclude", []))
    if not files:
        res.notes.append(f"{rule['id']}: no file in scope, passes")
        return res
    head = re.compile(r"^(?:static\s+)?func\s+" + re.escape(rule["function_name"]) + r"\s*\(")
    rx = re.compile(rule["pattern"])
    for path in files:
        lines = strip_gdscript(source.read(path)).split("\n")
        i = 0
        found = False
        while i < len(lines):
            if not head.match(lines[i]):
                i += 1
                continue
            found = True
            j = i
            while True:
                if j > i and rx.search(lines[j]):
                    res.violations.append(_viol(rule, path, j + 1))
                j += 1
                if j >= len(lines) or (lines[j].strip() and not lines[j][0].isspace()):
                    break
            i = j
        if not found:
            res.notes.append(f"{rule['id']}: func {rule['function_name']} not found in {path}")
    return res


CUSTOM = {
    "function_body_forbid": custom_function_body_forbid,
    "tscn_connection_deferred": custom_tscn_connection_deferred,
    "rng_seeded_before_draw": custom_rng_seeded_before_draw,
    "rng_construction_seeded": custom_rng_construction_seeded,
    "noninteractive_mouse_filter": custom_noninteractive_mouse_filter,
    "scoring_reflection_check": custom_scoring_reflection_check,
}


def evaluate(rule: dict, source) -> Result:
    """Evaluate one rule against a source and return its violations and notes."""
    kind = rule["kind"]
    if kind in ("forbid", "only_in"):
        return eval_pattern_rule(rule, source)
    if kind == "secret":
        return eval_secret(rule, source)
    if kind == "project_setting":
        return eval_project_setting(rule, source)
    if kind == "manifest":
        return eval_manifest(rule, source)
    if kind == "custom":
        return CUSTOM[rule["function"]](rule, source)
    raise ValueError(f"unknown kind {kind!r}")


# --------------------------------------------------------------------------- rule table

def load_table(path: str = RULES_PATH) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def validate_table(table: dict) -> list[str]:
    """Return a list of schema errors in the rule table (empty when valid)."""
    errors: list[str] = []
    seen: set = set()
    for rule in table.get("rules", []):
        rid = rule.get("id", "<no id>")
        for field in ("id", "source", "severity", "kind", "message"):
            if not rule.get(field):
                errors.append(f"{rid}: missing field {field}")
        if rid in seen:
            errors.append(f"{rid}: duplicate id")
        seen.add(rid)
        kind = rule.get("kind")
        if kind not in KINDS:
            errors.append(f"{rid}: unknown kind {kind!r}")
            continue
        if rule.get("severity") not in SEVERITIES:
            errors.append(f"{rid}: severity must be BLOCKING or ADVISORY")
        if kind in ("forbid", "only_in") or (kind == "secret" and not rule.get("names_only")):
            if not rule.get("scope"):
                errors.append(f"{rid}: scope is required")
            try:
                re.compile(rule.get("pattern", ""), re.MULTILINE)
            except re.error as exc:
                errors.append(f"{rid}: bad regex: {exc}")
            if not rule.get("pattern"):
                errors.append(f"{rid}: pattern is required")
        if kind == "only_in" and not rule.get("allow"):
            errors.append(f"{rid}: only_in needs a non-empty allow list")
        if kind == "secret" and rule.get("names_only") and not rule.get("scope"):
            errors.append(f"{rid}: scope is required")
        if kind == "project_setting" and rule.get("check") not in ("equals", "present", "section_empty", "only_true"):
            errors.append(f"{rid}: check must be equals, present, section_empty or only_true")
        if kind == "custom" and rule.get("function") not in CUSTOM:
            errors.append(f"{rid}: unknown custom function {rule.get('function')!r}")
    for entry in table.get("review_only", []):
        if not entry.get("pattern") or not entry.get("reason"):
            errors.append(f"review_only entry needs pattern and reason: {entry}")
    return errors


# --------------------------------------------------------------------------- self-check

def safe_id(rule_id: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]", "_", rule_id)


def load_fixture(path: str):
    """Return (virtual_path, text) from a fixture file with a `#@path:` first line, else (None, text)."""
    with open(path, "r", encoding="utf-8", newline="") as fh:
        text = fh.read()
    first, sep, rest = text.partition("\n")
    if first.startswith(FIXTURE_HEADER):
        return first[len(FIXTURE_HEADER):].strip(), rest
    return None, text


def check_rule_fixtures(rule: dict, fixtures_dir: str = FIXTURES_DIR) -> list[str]:
    """Self-check one rule: a passing and a failing fixture must exist and behave."""
    errors: list[str] = []
    folder = os.path.join(fixtures_dir, safe_id(rule["id"]))
    stub = bool(rule.get("stub"))
    outcomes = {}
    for name in ("pass", "fail"):
        fpath = os.path.join(folder, name + ".txt")
        if not os.path.isfile(fpath):
            if name == "fail" and stub:
                continue
            errors.append(f"{rule['id']}: missing {name} fixture {os.path.relpath(fpath, REPO_ROOT)}")
            continue
        vpath, text = load_fixture(fpath)
        if not vpath:
            errors.append(f"{rule['id']}: {name}.txt needs a first line '{FIXTURE_HEADER} <path>'")
            continue
        try:
            outcomes[name] = evaluate(rule, MemSource({vpath: text}))
        except Exception as exc:  # a fixture must never crash a rule
            errors.append(f"{rule['id']}: {name} fixture raised {type(exc).__name__}: {exc}")
    pas = outcomes.get("pass")
    if pas is not None:
        if pas.violations:
            errors.append(f"{rule['id']}: passing fixture violates the rule ({pas.violations[0].format()})")
        elif any("no file in scope" in n or "not found" in n for n in pas.notes) and not (
                rule.get("vacuous_pass_ok") or rule.get("stub") or rule.get("names_only")):
            errors.append(f"{rule['id']}: passing fixture is out of scope, so it proves nothing")
    fail = outcomes.get("fail")
    if fail is not None and not fail.violations:
        errors.append(f"{rule['id']}: failing fixture produced no violation")
    return errors


def self_check(rules, fixtures_dir: str = FIXTURES_DIR) -> list[str]:
    errors: list[str] = []
    for rule in rules:
        errors.extend(check_rule_fixtures(rule, fixtures_dir))
    return errors


# --------------------------------------------------------------------------- registry coverage

def read_registry_forbidden_patterns(yaml_text: str):
    """Tiny reader for the `forbidden_patterns:` section: returns [(pattern, status)].

    Purpose-built (stdlib has no YAML parser); accepts LF and CRLF, quoted names and trailing comments.
    """
    patterns = []
    in_section = False
    for line in yaml_text.splitlines():
        if not in_section:
            if re.match(r"^forbidden_patterns:\s*(#.*)?$", line):
                in_section = True
            continue
        if line.strip() and not line.startswith((" ", "	", "#")):
            break  # next top-level key
        m = re.match(r"""^\s+-\s+pattern:\s*["']?([\w.-]+)["']?\s*(#.*)?$""", line)
        if m:
            patterns.append([m.group(1), "active"])
            continue
        m = re.match(r"""^\s+status:\s*["']?([\w-]+)""", line)
        if m and patterns:
            patterns[-1][1] = m.group(1)
    return [(p, s) for p, s in patterns]


def coverage_rows(table: dict, yaml_text: str):
    """Return [(pattern, status, coverage)] with coverage 'rule', 'review_only', 'retired' or 'MISSING'."""
    ids = {r["id"] for r in table.get("rules", [])}
    review = {e["pattern"] for e in table.get("review_only", [])}
    rows = []
    for p, status in read_registry_forbidden_patterns(yaml_text):
        if status != "active":
            cov = "retired"
        elif f"forbidden:{p}" in ids:
            cov = "rule"
        elif p in review:
            cov = "review_only"
        else:
            cov = "MISSING"
        rows.append((p, status, cov))
    return rows


def registry_coverage(table: dict, yaml_text: str) -> list[str]:
    """Return active registry patterns with neither a `forbidden:<pattern>` rule nor a review_only mark."""
    return [p for p, _s, cov in coverage_rows(table, yaml_text) if cov == "MISSING"]


def load_registry_rows(root: str, table: dict):
    """Return (rows, warning). A missing, unreadable or malformed registry gives a warning, never a crash."""
    path = os.path.join(root, REGISTRY_REL)
    if not os.path.isfile(path):
        return [], f"{REGISTRY_REL} not found, coverage not checked"
    try:
        with open(path, "r", encoding="utf-8", errors="replace", newline="") as fh:
            text = fh.read()
        rows = coverage_rows(table, text)
    except (OSError, ValueError, KeyError) as exc:
        return [], f"{REGISTRY_REL} unreadable ({type(exc).__name__}: {exc}), coverage not checked"
    if not rows:
        return [], f"{REGISTRY_REL} has no parsable forbidden_patterns section, coverage not checked"
    return rows, None


def print_coverage(root: str, table: dict, out) -> int:
    """`--coverage`: print one line per registry pattern. Always exit 0 (ADVISORY)."""
    rows, warning = load_registry_rows(root, table)
    if warning:
        print(f"warning: registry:coverage: {warning}", file=out)
    for p, status, cov in rows:
        print(f"{p}	{status}	{cov}", file=out)
    missing = sum(1 for _p, _s, c in rows if c == "MISSING")
    print(f"coverage: {len(rows)} pattern(s), {missing} unenforced and not review_only", file=out)
    return 0


# --------------------------------------------------------------------------- main

def run(root: str, table: dict, only_rule: str | None = None, verbose: bool = False, out=None,
        fixtures_dir: str | None = None, android_export: bool = False) -> int:
    out = sys.stdout if out is None else out
    rules = table["rules"]
    if only_rule:
        rules = [r for r in rules if r["id"] == only_rule]
        if not rules:
            print(f"error: no rule with id {only_rule!r} (see --list)", file=out)
            return 2
    failed = False

    errors = self_check(rules) if fixtures_dir is None else self_check(rules, fixtures_dir)
    for err in errors:
        print(f"SELF-CHECK FAILED: {err}", file=out)
    failed = failed or bool(errors)

    source = FsSource(root)
    blocking = advisory = 0
    notes: list[str] = []
    for rule in rules:
        res = evaluate(rule, source)
        if android_export and rule["kind"] == "manifest" and not source.exists(rule.get("file", "export_presets.cfg")):
            # The skip is BLOCKING from the first Android build (story PS-010): no preset means no export.
            res.violations.append(_viol(rule, rule.get("file", "export_presets.cfg"), 1,
                                        "Android export requested but the export preset file does not exist"))
        notes.extend(res.notes)
        for v in res.violations:
            print(v.format(), file=out)
            if v.severity == "BLOCKING":
                blocking += 1
            else:
                advisory += 1

    if not only_rule:
        rows, warning = load_registry_rows(root, table)
        if warning:
            print(f"warning: registry:coverage: {warning}", file=out)
        for p, _s, cov in rows:
            if cov == "MISSING":
                print(f"{REGISTRY_REL}:1: [ADVISORY] registry:coverage: forbidden pattern {p!r} has no rule "
                      f"'forbidden:{p}' and is not review_only", file=out)
                advisory += 1

    if notes:
        if verbose:
            for n in notes:
                print(f"note: {n}", file=out)
        else:
            print(f"note: {len(notes)} rule(s) passed with a note (no file in scope or file absent); use --verbose to list", file=out)
    print(f"lint: {len(rules)} rule(s), {blocking} BLOCKING violation(s), {advisory} ADVISORY, "
          f"{len(errors)} self-check failure(s)", file=out)
    return 1 if (blocking or failed) else 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Project lint runner (ADR-0009 Decision 5)")
    ap.add_argument("--rule", help="run a single rule id")
    ap.add_argument("--list", action="store_true", help="list rules and exit")
    ap.add_argument("--coverage", action="store_true", help="print the registry forbidden_patterns coverage table and exit")
    ap.add_argument("--fixtures-dir", default=None, help="fixture folder for the self-check (default tools/ci/tests/fixtures)")
    ap.add_argument("--verbose", action="store_true", help="list rules that passed with a note")
    ap.add_argument("--android-export", action="store_true",
                    help="an Android export is being built: a missing export_presets.cfg fails the manifest rules")
    ap.add_argument("--root", default=REPO_ROOT, help="repository root to scan")
    args = ap.parse_args(argv)
    try:
        table = load_table()
    except (OSError, ValueError) as exc:
        print(f"error: cannot read {RULES_PATH}: {exc}")
        return 2
    errors = validate_table(table)
    if errors:
        for e in errors:
            print(f"error: rule table: {e}")
        return 2
    if args.list:
        for r in table["rules"]:
            print(f"{r['id']}\t{r['kind']}\t{r['severity']}\t{r['source']}")
        for e in table.get("review_only", []):
            print(f"{'forbidden:' + e['pattern']}\treview_only\t-\t{e['reason']}")
        return 0
    if args.coverage:
        return print_coverage(os.path.abspath(args.root), table, sys.stdout)
    return run(os.path.abspath(args.root), table, args.rule, args.verbose, fixtures_dir=args.fixtures_dir,
               android_export=args.android_export)


if __name__ == "__main__":
    sys.exit(main())
