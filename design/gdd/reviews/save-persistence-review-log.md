# Save & Persistence — Review Log

## Review — 2026-09-28 — Verdict: NEEDS REVISION (first full-mode pass)
Scope signal: M
Specialists: godot-specialist, security-engineer, qa-lead, creative-director
Summary: First full `/design-review`. Added a seventh `wall_clock()` seam (resolving a three-way contradiction between Rule 2, Rule 7, AC-15 and AC-16); promoted the write-survives-a-kill test to a named, owned, BLOCKING device check (SP-1, replacing deferred AC-20); narrowed Rule 6's crash-safety claim to app-termination only (not power loss); added a type guard to F1's schema-version comparison; named the real `DirAccess.rename_absolute()`/`remove_absolute()` API; recorded no-signing/no-encryption as a deliberate decision. Resolved same session.
Prior verdict resolved: First review

## Review — 2026-09-28 — Verdict: NEEDS REVISION (re-review, second full-mode pass)
Scope signal: M
Specialists: godot-specialist, security-engineer, qa-lead, creative-director
Blocking items: 4 | Recommended: 3
Summary: Two specialists (godot-specialist, qa-lead) independently converged on the same defect: AC-6's oracle permitted an implementation that silently drops every section but the one just changed on each write, contradicting Rule 6's "serialize the complete in-memory state" intent. security-engineer found Rule 7's unconditional "never crashes" claim was unproven against the real `ConfigFile`/`VariantParser` (all ACs stub the reader) and that an oversized hand-edited file was only an optional mitigation despite the 512 MB mobile memory ceiling. qa-lead additionally found AC-4 claimed to exercise `[cosmetics]` with no fixture key for it, and that SP-1's CI-sandbox allowance didn't account for Windows' non-POSIX rename-replace semantics on this project's own dev/CI host.
Resolved same session: Rule 6 + AC-6 reworded to require the complete in-memory section map on every write, with new AC-6b proving cross-section preservation; AC-4 scoped down to `[scoring]`/`[settings]` only, with a new Open Question for `[cosmetics]`; Rule 7's claim narrowed to what is actually proven, with a new BLOCKING device check SP-2 for the real parser path plus a required, newly-named `SAVE_FILE_SIZE_MAX` size guard; SP-1 made device-first with the CI-sandbox path made conditional on a `rename_absolute` overwrite-semantics prerequisite check.
Prior verdict resolved: Yes
