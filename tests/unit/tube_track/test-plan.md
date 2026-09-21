# Tube Track: Test Plan

> **Status**: Draft (written 2026-09-20 after the fourth `/design-review`; structured like `tests/unit/run_state/test-plan.md`)
> **Governs**: `design/gdd/tube-track.md`, section Acceptance Criteria (AC-1 to AC-30, including AC-20a)
> **Framework**: GUT (the CI command in `coding-standards.md` names gdunit4; settle before Technical Setup)

The GDD states behaviour and holds the numeric oracles (F1-F9 examples, the AC-12 code-set table, the F3 table).
This file holds what a test needs to run them: the seam, the factories, the recorder, the state matrix, the
file layout and the known gaps. Names are proposals; the implementation story may rename them but keeps the
one-to-one mapping with the GDD.

## 1. Test seam

Three `RefCounted` classes, no `SceneTree`, no autoload, no `Engine.` or `Time.` call. A test asserts
`core is RefCounted and not core is Node`.

| Class | Built with | Role |
|-------|------------|------|
| `TubeMath` | static functions | `wrap_angle(a, log_sink)`, `delta_theta(a, b, log_sink)`, `to_world(theta, s, h, R, log_sink)` (`P` in the GDD), F3 `required_a` / `required_b`, F4 `ulp32`, F5 `seam_s`, F6 `lane_width` / `lane_count`, F7 `facet_gap`, F8 `idle_step(s_idle, v_idle, dt, t_lat, L)`, F9 `t_vis`, `segment_content(config, index)` |
| `TubeConfig` | `Resource`, every knob and the `MapConfig` fields Tube Track reads | `validate() -> Array` of records `{code: String, ...}` (a record, not message text: `SEAM_HZ` carries `max_n_seams`, `L_INVALID` carries `l_min`, `NO_VALID_F` carries the range) |
| `TubeWindow` | `(config: TubeConfig, log_sink: Callable(level, message), slot_binder: Callable(slot_index: int, segment_index: int))` | The lifecycle state machine and the window |

`TubeWindow` public API: `load_map(config)`, `unload_map()`, `begin_run()`, `advance(s)`, `pause()`, `resume()`,
`end_run()`, `to_idle()`, `tick_idle(dt)`; read-only `state`, `s`, `s_idle`, `first_index`, `last_index`,
`far_end_s`; signals `state_changed(new_state, old_state)`, `window_primed(first_index, last_index)`,
`segment_entered_window(index)`, `segment_left_window(index)`. There is **no test-only hook** (no `force_state`):
every state is reached through the public API (section 2). The view node `TubeTrack` is not unit-tested here.

Config fields (proposal): `R`, `D`, `L`, `A`, `B`, `n_seams`, `F`, `F_read`, `d_cam`, `v_max`, `t_lat`,
`C_b`, `M_cam`, `fog_mode`, `fog_depth_begin`, `fog_depth_curve`, `fog_density`, `seam_pattern_id`,
`seam_contrast_scale`, `idle_scroll_speed`, `t_vis_min`, `seam_hz_max`, `s_precision_limit`.

**Fixtures.** One constants file, `tests/unit/tube_track/tube_track_fixtures.gd`, holds the GDD defaults
(R 3, D 0.8, L 12, n_seams 1, A 6, B 2, N 9, F 48, F_read 46, d_cam 8, v_max 25, t_lat 0.1, C_b 6, M_cam 2,
`fog_mode` depth, `fog_depth_begin` 10, `fog_depth_curve` 1.0, `fog_density` 1.0) and a factory
`valid_config(overrides: Dictionary = {}) -> TubeConfig`. No test writes these numbers inline, except a
boundary test where the exact number is the point (test standards).

**Engine notes that shape the tests** (verified on 4.7.2, see `docs/engine-reference/godot/current-best-practices.md`):
- `class_name` did not resolve without a project and a class cache: tests `preload` the classes, and headless
  CI runs `godot --headless --import` first. There is no `project.godot` yet.
- A parameter named `log` shadows the global `log()` function: the GDD names it `log`, the code should use
  `log_sink` (open item, section 6).
- An unset `Callable()` errors when called: the log sink and the binder default to a no-op only when the test
  does not care; a test that counts must pass its own.
- No `nextafter`: boundary values use the literal `11.999999999999998` (AC-7).

## 2. State factory `window_in(state)`

Every state is reached through the public API from a fresh `TubeWindow` built with `valid_config()`, a counting
log sink and a recording binder. After the factory returns, the recorder, the binder log and the log list are
cleared, so a test asserts only on what it sends.

| State | Built by |
|-------|----------|
| Uninitialized | new window |
| Idle | `load_map(valid_config())` |
| Running, `s` = 0 | Idle, `begin_run()` |
| Running, `s` = 1234.5 (segment 102, window 100..108) | Running, then `advance` in steps of at most N - 1 segments (a single jump re-primes) |
| Paused | Running, `pause()` |
| Ended | Running, `end_run()` |

## 3. Signal recorder and log sink

One shared ordered `Array` of `[name, args]`, appended by a handler connected to each of the 4 signals, so
cross-signal order is preserved (GUT's `watch_signals` does not keep it; AC-8, AC-19 and AC-20 need order).
- Handlers are **untyped** (`func(...)`) so the recorded arguments are exactly what was emitted: a handler
  declared `func h(v: int)` coerces a float to an int and hides a wrong argument type.
- Lambdas capture a primitive by value: count through the shared `Array` (or a recorder object), never through
  a local `int`.
- All connections in AC-19/20 are **immediate**. `CONNECT_DEFERRED` handlers run after `emit()` returns and
  are outside the re-entrancy guard; that case is not covered (section 6).
- The log sink appends `[level, message]`; "one error" means exactly one entry with level `error`.
- The binder records `[slot_index, segment_index]`; AC-20 and AC-20a assert `slot_index == posmod(segment_index, 9)`.

## 4. AC-19 state matrix (40 pairs: 16 accepted, 24 rejected)

Each **rejected** row asserts: state, `s`, `s_idle`, window and binder log unchanged, no signal, exactly one
`error` log line. Each **accepted** row asserts the next state and exactly the signals listed, in order.
`(-2, 6)` is the default window `-B .. A`.

| State \ event | load_map | unload_map | begin_run | advance | pause | resume | end_run | to_idle |
|---------------|----------|------------|-----------|---------|-------|--------|---------|---------|
| Uninitialized | Idle | R | R | R | R | R | R | R |
| Idle | R | Uninitialized | Running | R | R | R | R | R |
| Running | R | Uninitialized | Running | Running | Paused | R | Ended | Idle |
| Paused | R | Uninitialized | Running | R | R | Running | R | Idle |
| Ended | R | Uninitialized | Running | R | R | R | R | Idle |

`R` = rejected (counts: Uninitialized 7, Idle 6, Running 2, Paused 4, Ended 5 = 24). Accepted effects:

| Accepted pair | Signals, in order | Also asserts |
|---------------|-------------------|--------------|
| Uninitialized `load_map` (valid) | `window_primed(-2, 6)`, `state_changed(Idle, Uninitialized)` | binder called 9 times, `segment_index` -2..6; an invalid config: nothing, state stays Uninitialized (AC-20a) |
| Idle `begin_run` | `window_primed(-2, 6)`, `state_changed(Running, Idle)` | `s` = 0; binder 9 times; no `segment_*` (AC-8) |
| Running `begin_run` (restart) | `window_primed(-2, 6)` only | `s` = 0; no `state_changed` (state does not change) |
| Paused / Ended `begin_run` | `window_primed(-2, 6)`, `state_changed(Running, old)` | `s` = 0 |
| Running `advance` | none, or per crossed boundary `segment_left_window(k - B)` then `segment_entered_window(k + 1 + A)` | AC-8, AC-9; unchanged `s` is a silent no-op |
| Running `pause` / `end_run` | `state_changed(Paused / Ended, Running)` | window and `s` unchanged |
| Paused `resume` | `state_changed(Running, Paused)` | `s` unchanged |
| Running / Paused / Ended `to_idle` | `window_primed(-2, 6)`, `state_changed(Idle, old)` | `s_idle` = 0; binder 9 times; the run's `s` discarded (AC-20a) |
| any loaded state `unload_map` | `state_changed(Uninitialized, old)` | no `window_primed`; slot bindings released (how this is observed is open, section 6) |

## 5. File layout and AC mapping

Files are named `tube_track_[feature]_test.gd` (project naming standard), functions `test_tube_track_[scenario]_[expected]`
(`.claude/rules/test-standards.md`). GUT's default prefix is `test_`: set the prefix and suffix in the GUT config
when `/test-setup` runs.

| File | ACs | Notes |
|------|-----|-------|
| `tube_track_math_test.gd` | AC-1..6, 14, 16, 17 (`idle_step`), 15 (`ulp32` only) | pure functions; injected `log_sink` counts warnings and errors |
| `tube_track_config_validation_test.gd` | AC-11, 12, 13 | table-driven from the GDD's AC-12 table; compare code **sets**, not ordered lists |
| `tube_track_window_states_test.gd` | AC-8, 10, 19, 20, 20a | the section 4 matrix, one row per test |
| `tube_track_window_recycling_test.gd` | AC-7, 9, 15 (warning), 21, 22, 23 | the 300 s simulation at dt = 1/64 |
| `tube_track_idle_test.gd` | AC-17 (state part), 20a (Idle part) | `tick_idle` through the window |
| `tube_track_determinism_test.gd` | AC-18 | by absolute index |
| CI grep lint (not a GUT test) | AC-25, `randf` / `RandomNumberGenerator` in `TubeMath` | file reads do not belong in a unit test |

Not automated here: AC-24 (deferred until the mesh exists), AC-26a (smoke check when a seam colour exists), AC-26b and
AC-27 (screenshot and playtest evidence in `production/qa/evidence/`), AC-28..30 (on-device, ADVISORY).

## 6. Known gaps (from Open Questions 17 and 18 and this review; resolve when the tests are written)

**Split into single behaviours** (one behaviour per test, arrange/act/assert): AC-2, 6, 8, 9, 15 and 20 each bundle
several behaviours.

**Values and assertions**
- AC-1 never checks the surface normal `(sin(theta), cos(theta), 0)`; add it. The default tolerance 1e-6 covers the
  rounding noise of about 4e-16 in `P(PI, ...)`.
- AC-13: assert a structured `{code, max_n_seams}` record, not message text. (The relief clause and the `RELIEF`
  code were removed on 2026-09-20: seams have no geometric relief; do not add a relief test.)
- AC-26a: add the seam-luminance-below-sky clause (Haze Top 0.635 on Map 1) to the smoke check; the band is now
  [1.15, 1.25] and the ceiling is an art-director ruling awaiting a device check.
- AC-17: use `dt` = 1/64; 3840 ticks add exactly 6.0.
- AC-18 needs a real oracle: assert the recorded binder calls and `segment_content` equal between a continuous run and a
  re-prime; add the CI lint for `randf` and `RandomNumberGenerator`. AC-21 and AC-22 restate the window definition; add an
  independent check (for example every recycled slot's far edge against `rear_extent` from the camera double).
- AC-26b: sample the tube at 5 angles including the darkest facet, tolerance +-2/255 per channel, and a pass rule for the fog
  decay. AC-27: power is low (about 35-55% at the margin), so a fail is weak evidence; add "what drew your eye first".
- AC-29's 10-minute soak reaches `s` of about 15,000, below 16,384, and Open Question 13's on-device precision check has no AC.
- AC-30: a synchronous `advance` cannot exclude its handlers; connect no-op listeners and report the p99 with them attached.
- AC-28: pin the measurement setup (an empty scene did not reproduce a baseline of 68; it read 0 in a SubViewport run).

**Coverage gaps (no AC yet)**
- `NOT_FINITE` for the ten numeric inputs not in AC-12; `delta_theta(NaN)`; an unknown `seam_pattern_id`; `h = +INF`.
- Idle to Running; `begin_run` at `s` > 0 from Running, Paused and Ended; pause and resume leave `s` unchanged.
- `unload_map` releasing every slot binding (needs an observable: a binder call with a release marker, or a getter for bound slots).
- Backgrounding mid-run; rule 4 (one caller, the caller's dt clamp); the `seam_contrast_scale` clamp and NaN, and duplicating a
  cached shared `.tres` before applying it.
- The Run State adapter, an [I] test against the real core (Run State D8): Boot -> Menu -> Running -> Paused -> Resuming -> Paused ->
  Menu, Running -> Hit -> Menu, Hit -> Running, Paused -> Running each leave Tube Track with zero rejected-call log lines, and the
  driver never calls `advance` outside Running.
- The AC-25 lint token list: add `transform.origin.z`, `global_position[2]`.
- `CONNECT_DEFERRED` handlers and awaiting handlers run outside the re-entrancy guard; state that the guarantee holds for immediate
  connections only. Handlers of a multi-recycle `advance` see an intermediate window.
- Validation codes for the config's own knobs do not exist yet (`SEAM_HZ_MAX` above 3, `T_VIS_MIN` = 0, `t_lat`, `M_cam`,
  `S_PRECISION_LIMIT`, `IDLE_SCROLL_SPEED` NaN), so nothing can be asserted (GDD Open Question 18).
- A typed `@export` int cannot hold 2.5: the not-an-integer check applies to Variant or Dictionary input, so AC-13 feeds the
  validator a `Dictionary`, not a `TubeConfig` field.

**Naming and CI**
- The GDD's `log` parameter should be `log_sink` in code; `P` should be `to_world` (snake_case).
- `technical-preferences.md` names GUT while `coding-standards.md` runs `gdunit4_runner.gd`; settle before Technical Setup.
- CI needs the import pass (`godot --headless --import`) before GUT, and a `project.godot` does not exist yet.
