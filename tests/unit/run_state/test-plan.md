# Run State & Restart: Test Plan

> **Status**: Draft (moved out of the GDD on 2026-09-20 after the second `/design-review`)
> **Governs**: `design/gdd/run-state-restart.md`, section Acceptance Criteria (AC-1 to AC-28, D1 to D8)
> **Framework**: GUT (the CI command in `coding-standards.md` names gdunit4; settle before Technical Setup)

The GDD states behaviour. This file holds what a test needs to run it: the seam, the state factory,
the recorder, the per-row expectations and the known gaps found by the QA review.

## 1. Test seam

`RunStateCore` is a `RefCounted` built with `(config, clock: Callable -> now_us, log_sink: Callable(level, message))`.
It has no `SceneTree`, no autoload and no `Time.` or `Engine.` call: the clock is injected.
A test asserts `core is RefCounted and not core is Node` (an instance cannot be tested "without a
SceneTree" from inside GUT).

Public API (names proposed; the implementation story may rename them but keeps the one-to-one mapping):

| Call | Meaning |
|------|---------|
| `request_map_ready()` | `map_ready` |
| `request_start()` | `start_requested` |
| `request_hit(hazard_id, run_id)` | `hit_reported` |
| `request_pause(source)` | `pause_requested`, source `button`, `back` or `app_interrupted` (`app_interrupted` is applied when sent) |
| `request_resume()` | `resume_requested` |
| `request_restart(press_us)` | `restart_requested` |
| `request_menu(press_us)` | `menu_requested` |
| `tick(world_dt, real_dt) -> dt_eff` | one frame (rule 3) |
| read-only `phase`, `run_id`, `run_time`, `run_time_ms()`, `resume_remaining()`, `resume_progress()` | state |
| `static progress_for(duration, elapsed)` | the pure countdown helper (renamed from `resume_progress`: Godot 4.7.2 rejects a static and an instance function with the same name) |

There is **no test-only hook** in the core (`force_phase` is removed; AC-9 lints for it).

Config fields (proposal): `restart_lock`, `pause_input_guard`, `resume_countdown`, `dt_max`,
`stall_pause_threshold`, `hitstop_actual` (injected by the composition root), and `t_restart_30fps`
(a field, not a constant, so that the `LOCK_MIN > LOCK_MAX` case of AC-14 is reachable through the seam).
Constants used by F4: `HITSTOP_MAX`, `T_READ`, `T_REACT`, `T_STOP`, `FRICTION_MAX`, `RESTART_BUDGET`.

Note: `class_name` did not resolve on 4.7.2 without a project or a class cache. Tests `preload` the core,
and headless CI runs an import pass first.

## 2. State factory `core_in(phase)`

Every phase is reached through the public API from a fresh core, so the state is realistic. The injected
clock starts at 1,000,000 us (a `press_us` of 0 means "missing"). After the factory returns, the
recorder and the log list are cleared, so a test asserts only on what it sends.

| Phase | Built by |
|-------|----------|
| Boot | new core |
| Menu | `request_map_ready()`, `tick` |
| Running | Menu, `request_start()`, `tick` (settling tick), `tick` (a live tick): `run_id` 1, settling flag consumed |
| Paused, inside the guard | Running, `request_pause(button)`, `tick`; the clock is not advanced |
| Paused, after the guard | the same, then the clock is advanced by `PAUSE_INPUT_GUARD_us`, `tick` |
| Resuming | Paused after the guard, `request_resume()`, `tick` |
| Hit, locked | Running, `request_hit(id, 1)`, `tick`; the clock is not advanced |
| Hit, unlocked | Hit, then the clock is advanced by `RESTART_LOCK_us`, `tick` (`restart_unlocked` already emitted and cleared) |

A press "after the lock" or "after the guard" is stamped `anchor + limit`; "inside" is `anchor + limit - 1`.

## 3. Signal recorder

One shared ordered `Array` of `[name, args]`, appended by a handler connected to each of the 9 signals,
so cross-signal order is preserved (GUT's `watch_signals` does not keep it). For variable arity use one
lambda per signal, or a variadic `func _rec(...args)` with `bind(name)` (the bound name arrives last).
Lambdas capture locals by value, so the shared `Array` is passed by reference.
AC-8 checks argument types with `type == TYPE_INT` (an enum-typed argument reports `TYPE_INT` with a
`class_name` in 4.7.2).

## 4. AC-1 table (46 cases, 10 accepted, 36 rejected) with the expected log level

`A` = accepted, `W` = warning, `D` = debug, `S` = silent. "lock" and "guard" rows are the inside case;
the after case is accepted. Each rejected row asserts: phase, `run_id` and `run_time` unchanged, no event
(including `phase_changed`), exactly one log line at the listed level.

| Phase \ request | map_ready | start | hit (current id, not settling) | pause(button) | resume | restart | menu |
|-----------------|-----------|-------|-------------------------------|---------------|--------|---------|------|
| Boot | A | W | W | W | W | W | W |
| Menu | W | A | W | W | W | W | W |
| Running | W | W | A | A | W | D (repeated tap) | W |
| Paused | W | W | D | D (repeated tap) | A | guard D / after A | guard D / after A |
| Resuming | W | W | D | A | D (repeated tap) | W | W |
| Hit | W | W | D | W | W | lock D / after A | lock D / after A |

Counts: 10 accepted, 10 debug, 26 warning. Accepted rows also assert the resulting phase.

## 5. AC-19 expected outcomes (hard-coded, not computed by sorting)

For each of the 120 orderings of {hit, pause(button), menu, restart, resume}, sent in one tick, `press_us`
stamped after the lock or the guard where one applies:

| Start | Final phase | Events, in order | Log lines |
|-------|-------------|------------------|-----------|
| Running | Hit | `run_ended(id, hazard, ms)`, `phase_changed(Hit, Running)` | 3 debug (pause: valid in Running, rejected only because the hit changed the phase; menu and restart: inside the lock, `press_us` clamped to `now_us`), 1 warning (resume: invalid in Running and in Hit) |
| Paused, after the guard | Resuming | `run_resuming(2000)`, `phase_changed(Resuming, Paused)` | 4 debug (hit, pause repeated tap, menu and restart rejected because the phase changed) |
| Hit, unlocked | Menu | `phase_changed(Menu, Hit)` only | 1 debug (hit), 2 warning (pause(button), resume: invalid in Hit, before any change), 1 debug (restart after the change) |

Arrival order inside one class is checked by separate rows: two pause sources (`app_interrupted` first,
`button` first), two restarts, and two `hit_reported` (AC-20).

## 6. Known gaps and fixes from the QA review (to resolve when the tests are written)

Blockers already closed in the GDD: `force_phase` removed, log levels fixed in rule 3, tie-break and
arrival order reconciled, `resume_progress` renamed. Still to do:

- **AC-5:** add `pause(app_interrupted)` (its own code path, applied at send) and the "sent from inside a
  tick" case: 9 events x 9 requests (7 requests, pause with 3 sources).
- **AC-13:** 300 ticks at 1/60 s is 5 s. Fix the step at 16,667 us and assert `restart_unlocked` at tick 30
  exactly (not 29) and `run_resumed` at tick 120 exactly. Add the row: Resuming, `real_dt` 0.6, clock past
  the expiry gives Paused and no `run_resumed`.
- **AC-14:** list the config fields (section 1); add rows for the cap case (`hitstop_actual` 0.5, so the
  lock is capped at 0.60 and the invariant cannot hold) and for `LOCK_MIN > LOCK_MAX` through
  `t_restart_30fps`; decide one source for `LOCK_MIN`'s hitstop term (constant `HITSTOP_MAX` in F4 versus
  the injected `hitstop_actual` in Tuning Knobs).
- **AC-17:** replace with "clock advanced by 5 s inside a `run_reset` handler: `run_started` still comes in
  that tick and the next tick, a settling tick, absorbs the hitch".
- **AC-24:** state the fixed run time; assert exact counts (a cycle of 32 ticks gives exactly 2 hits per
  closed second at the default lock, 29 ticks exactly 3 at the minimum lock 0.45: re-derive before
  coding); sweep the lock {0.45, 0.5, 0.6} and the fps {30, 60, 120} instead of 300 identical cycles.
- **AC-12, AC-28 (third review):** a `press_us` in the future logs one error, like a missing or non-positive one (assert the log); add the `app_interrupted` row for `paused_us` (the clock at send, not at the next tick).
- **AC-27:** the endpoint disagrees with F2 and rule 9 (it measures to the frame after `run_started`, but
  the first controllable frame is the tick after the settling tick); add the `N_present` term or define
  the endpoint; do not mix percentiles ("p95 of (a) plus the median of (b)"); check that
  `Input.parse_input_event` buffering is comparable to a real touch. Move it to the milestone gate: Run
  State's story cannot close on a measurement that needs Ball, Obstacle, Camera and Juice.
- **AC-10, AC-16:** "at most one warning per 1.0 s" passes with zero warnings: assert exactly one for the
  first bad input, none within 1.0 s of injected clock, one again after it. Use 1.2346 s to tell `round()`
  from `int()` (expect 1235). Use almost-equal for floats.
- **AC-7:** test the stale `run_id` on a non-settling tick, so the two checks are isolated; assert the log
  level of the settling-tick hit and the `run_time_ms` value.
- **AC-8, AC-9:** split AC-8 into four assertions. AC-9 reads the source file, which is file I/O in a unit
  test: run it as a CI grep lint instead, and extend its token list with `ResourceSaver`, `DirAccess`,
  `OS.` and `ProjectSettings.save`.
- **AC-15:** the 5 s row is unreachable in the core (the countdown ends at 2.0 s): keep it on the static
  helper only; add an elapsed of -1 row (F5 has no negative-elapsed clamp yet, Open Question 17).
- **AC-25:** the doubles verify themselves and duplicate AC-5 and AC-6; drop it or fold it in.
- **AC-26:** counting flashes from video is unreliable; add a debug flash-trigger log.
- **Coverage gaps** (no AC yet): "Hit never times out"; "a queued request has no effect before the tick";
  `app_interrupted` emits at send, before any tick; the driver that computes `real_dt` and forwards `dt_eff`
  (add **D9**: a driver test with `Engine.time_scale` 0.1); the duplicate emulated tap (exactly one request
  per tap); the F4 invalid-config path; R12 beyond the lint.
- **Naming and CI:** GUT's default prefix is `test_`, the project naming standard says `[system]_[feature]_test`;
  `technical-preferences.md` names GUT while `coding-standards.md` runs `gdunit4_runner.gd`.
