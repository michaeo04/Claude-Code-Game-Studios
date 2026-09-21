# Review Log: run-state-restart.md

## Review — 2026-09-20 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, ux-designer; creative-director (senior)
Blocking items: 10 (plus 1 user decision on the art bible) | Recommended: about 12 (deferred ones tracked in Open Question 15)
Summary: The GDD was structurally complete (8/8 sections) and its arithmetic checked out
(F2, F4, F5 and the AC-1 case count were re-verified by three reviewers), but the run-ends-only-
when-I-lose fantasy did not hold: a hit on a stall tick won, a queued `app_interrupted` lost to
a hit on the return frame, a stale physics contact could kill the new run, and a clamped hitch
could move the ball 6.25 u unseen. The restart budget was also defined over two different
intervals (from the stamp and from the touch), the tick order left ties undefined (AC-18 was
false as written), and the acceptance criteria had no named test seam, a wrong AC-7, a
tautological AC-15 and an overstated coverage line. The GDD read the art bible's "restart in
under 1 s" as tap-to-controllable, which conflicted with the locked line "a hit and the restart
are one state".
Prior verdict resolved: First review

### Resolution (2026-09-20, same session)
All 10 blocking items were addressed in one revision pass.
Design decisions taken by the user:
- Tap-to-restart is kept over auto-restart; the tap to the first controllable frame is the
  binding reading of the 1 s budget; the art bible mood-state-5 lines were edited (Section 2,
  three lines) to "the hit and the next run are one continuous state; the restart takes under
  1 s from the player's tap".
- The shared `DT_MAX` default was lowered from 0.25 s to 0.1 s (one shared constant, safe range
  0.05-0.45). Tube Track's F3 table, F9 range and AC-11, AC-12 and AC-21 were recomputed (A for
  L = 6, F = 48 went from 11 to 10; `F_max` from 125.75 to 129.5).
- Tilt Input: Run State commits only to an ordering guarantee (rule 14); the mechanism is
  decided in the Tilt Input GDD after the on-device spike.
Decisions taken from the review without a separate question (creative-director rulings):
`app_interrupted` is applied synchronously when sent (the one request not queued); the stall
guard discards hits queued on its tick; `hit_reported` carries `run_id`; `STALL_PAUSE_THRESHOLD`
lowered to 0.5 s; one `press_us` stamp point (input handler) and one restart interval (touch to
first presented frame); `real_dt` comes from the injected clock; Android Back added
(`pause_requested(back)`); total class order for same-tick requests; a named test seam and
AC-1 to AC-27 renumbered. Added by the main review, not by a specialist: `tick()` returns
`dt_eff`, and the first tick after `run_started` and after `run_resumed` is a settling tick
(`dt_eff` 0, no stall guard, hits ignored), so the reset hitch is absorbed and Tilt Input gets
one still frame to sample.

Specialist disagreements recorded: stall/interrupt versus hit (game-designer: pause outranks
hit; qa-lead and systems-designer: keep "hit wins" but enqueue; godot-specialist: apply
synchronously) was resolved by the creative-director as synchronous for `app_interrupted` plus
discard on stall ticks; splitting the DT constant (game-designer) was rejected in favor of one
lower shared value; press buffering in the last 100-150 ms of the lock (game-designer,
ux-designer) was rejected because it reintroduces the panic-tap skip; `press_us` severity
(systems-designer blocking, godot-specialist recommended) was resolved as a spec bug in the
interval definition, not a stamping bug; persistence (game-designer) was rejected for the MVP
and Fantasy #2 was softened, with provisional score on interrupt left to Open Question 6.

Open after revision: engine claims (input events without timestamps, monotonic clock during
device sleep, notification names, `Engine.time_scale` and `_process`) are UNVERIFIED against
4.7; registry YAML was not machine-validated; Tilt Input mechanism, hit-to-controllable p95
(target under 1.7 s) and the on-device restart measurement (AC-27) are still to be done.

Not yet re-reviewed. Run `/design-review design/gdd/run-state-restart.md` in a fresh session,
then `/design-review design/gdd/tube-track.md`.

---

## Review — 2026-09-20 (second review) — Verdict: NEEDS REVISION
Scope signal: L for implementation; the revision itself was S/M
Specialists: game-designer, systems-designer, qa-lead, godot-specialist (ran the real 4.7.2 binary), ux-designer; creative-director (senior)
Blocking items: 6 | Recommended: about 20 (deferred ones tracked in Open Question 17)
Summary: All 10 prior blockers were substantively resolved, and no new finding is a regression of a
prior ruling. The new findings sit in the mechanisms the first revision added (settling tick,
`tick()` returning `dt_eff`, stall guard, `press_us` lock), so the document is converging.
The 6 blockers: (1) `tick()` fixed `dt_eff` before requests ran, so a hit, a button pause or a
restart tick returned a non-zero step while the phase had already changed and the owner then called
Tube Track's `advance()`, which rejects it (every hit and pause would log an error; AC-11
contradicted itself); (2) the lock was silent, a press held across the unlock never converted, and
the fire point was not stated; (3) a hit discarded by the stall guard, a settling tick or Paused had
no aftermath, so a contact could vanish or re-fire with zero reaction time; (4) `DT_MAX` up to 0.45
against a stall threshold of 0.5 let a 0.49 s frame move the ball 11 u and still count a hit, and the
engine caps `_process` delta at about 0.133 s, so F1's example was unreachable; (5) the test seam did
not parse (a static and an instance `resume_progress`) and `force_phase` left the settling flag, the
unlock latch, `run_id` and the clock undefined; (6) AC-19 and AC-20 contradicted rule 3 on ordering
inside the hit class, and AC-1 and AC-18 contradicted rule 3 on log levels.
Prior verdict resolved: Yes (2026-09-20, first review: NEEDS REVISION, 10 blockers)

### Resolution (2026-09-20, same session)
All 6 blockers plus the Paused guard were addressed in one revision pass; nothing else was added
(spec freeze, per the creative-director).
Decisions taken by the user: scope = 6 blockers plus the Paused guard (other recommended items go to
Open Question 17); `dt_eff` is 0 whenever the phase changes during the tick and `run_time` is applied
at the end of the tick (rule 3 steps 2 and 5, F1); `DT_MAX` safe range narrowed to 0.05-0.25 with
`STALL_PAUSE_THRESHOLD >= 2 x DT_MAX`; the test seam moved to `tests/unit/run_state/test-plan.md`.
Decisions taken from the creative-director's rulings without a separate question: restart fires on
press-down of a press stamped at or after the unlock, and a press held across it does not convert;
no buffering; a locked-state cue from `run_ended` and an acknowledgement of a rejected press-down
(UI Requirements, D2); contact reports must be level-triggered (rule 7, D4); Fantasy #2 softened to
"an interruption or a long freeze never ends a run, a short hitch costs time, never a jump";
`PAUSE_INPUT_GUARD` 0.3 s for restart and menu in Paused with resume winning same-tick ties (new
class order: hit, pause, resume, menu, restart, map_ready, start; F3, AC-28); one log-level table in
rule 3; the hit-class tie-break stated in rule 3.

Specialist disagreements recorded: latch a press at the unlock (game-designer) versus strict rejection
with a cue (ux-designer), resolved for the cue, no buffering; mercy for every tick with
`real_dt > DT_MAX` (game-designer) versus fixing the band (systems-designer), resolved for the band;
Resuming early-out (game-designer) and cancel button (ux-designer), resolved for no early-out and a
recommended cancel (Open Question 17); confirm before abandoning from Paused (ux-designer), deferred to
`/ux-design`.

Caveats to remember:
- The creative-director said the narrowed band keeps the largest un-mercied hitch at 2.5 u. That holds
  at the default `DT_MAX` 0.1 only; at the top of the range it is 25 x 0.25 = 6.25 u. The GDD states
  both numbers.
- Engine claims moved from UNVERIFIED to VERIFIED on the 4.7.2 binary for `Engine.time_scale`, the
  `delta` cap, `get_script_signal_list`, synchronous signals, `CONNECT_DEFERRED`, the missing input
  timestamp, the duplicate `emulate_mouse_from_touch` event, lifecycle constants and `quit_on_go_back`
  (default true). Still unverified without a device: the clock in device sleep, real notification
  delivery, the Back gesture, physics interpolation on a restart teleport. Those facts are not yet in
  `docs/engine-reference/`.
- The registry YAML was patched (CRLF file) and not machine-validated (no YAML parser installed).
- The godot-specialist stopped at its 20-turn limit; its hand-back report was complete.

Not yet re-reviewed. The creative-director recommends a blocker-only re-review
(`/design-review design/gdd/run-state-restart.md --depth lean`) in a fresh session, then
`/design-review design/gdd/tube-track.md` (its `t_lat` safe range changed to 0.05-0.25, no computed
number changed).

---

## Review — 2026-09-20 (third review, `--depth lean`) — Verdict: NEEDS REVISION
Scope signal: L for implementation; the revision itself was S
Specialists: none (lean, single session; no senior review)
Blocking items: 1 | Recommended: 6 (4 applied in the same session, 2 left for the user)
Summary: All 6 blockers of the second review and the Paused guard were verified closed against the text
(AC-1 recounted: 46 cases = 10 accepted + 10 debug + 26 warning; F2, F4, F5, the AC-24 flash bound and the
2.5 u / 6.25 u figures re-computed; the Tube Track adapter mapping checked against its state table). The one
new blocker sat in the newest mechanism: `paused_us` was a tick snapshot, but `app_interrupted` is applied
between ticks, and the guard is anchored to the entry to Paused, not to the player's return, so it could not
cover the "stray tap on returning from a call" that rule 10 and Edge Cases claimed.
Prior verdict resolved: Yes (second review, 6 blockers)

### Resolution (2026-09-20, same session)
Decision taken by the user: narrow the promise (option A) rather than add an `app_returned` request. `paused_us` for
`app_interrupted` is the injected clock at send; the guard now claims only a double tap on the pause button and a
touch just after the pause screen appears; the `app_returned` re-anchor and a confirm before abandoning are
recorded in Open Question 17. Rule 10, F3 (and its variable table), Edge Cases, the Tuning Knobs row, AC-28 and
the registry note were edited to match.
Recommended items applied: the log-level clause of rule 3 now says "valid before the earlier request changed the
phase" (so a `resume` sent from Running with a hit is a warning) and the AC-19 Running row of the test plan is 3
debug + 1 warning, not 4 debug; a `press_us` in the future logs one error like a missing one (rule 8, F3, AC-12);
the owner contract says Ball Movement integrates `s` with `dt_eff` and hands `s` to Tube Track's `advance(s)` (Tube
Track takes a distance, not a dt); status line, "Core layer" naming (the systems index says Core).
Left for the user: (a) `DT_MAX` above the engine's `delta` cap of about 0.133 s is inert at the project defaults,
so the reachable worst hitch is about 3.3 u, not 6.25 u, unless `max_physics_steps_per_frame` or `time_scale`
changes: state the reachable bound next to 6.25 u; (b) copy the engine facts verified on 4.7.2 into
`docs/engine-reference/godot/`. Not changed on purpose: the order of AC-28 (renumbering would break the
cross-references).

Specialist disagreements: none. Not re-reviewed after this revision; the fix is a text change that a read of rule 10,
F3, Edge Cases and AC-28 verifies. Next: `/design-review design/gdd/tube-track.md`.

Marked Approved by the user on 2026-09-20 after the revision (no fourth review); `systems-index.md` updated.
