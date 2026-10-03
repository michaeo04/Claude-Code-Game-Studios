## Run State & Restart core: the single owner of the game phase (GDD `design/gdd/run-state-restart.md`,
## ADR-0002).
##
## A `RefCounted` with no engine call: time comes only from the injected `clock_us: Callable` (returns
## microseconds as an int) and from the arguments of `tick()`. Other systems send requests with the
## `request_*` methods; a request is queued and processed at the next `tick()`, except
## `request_pause(APP_INTERRUPTED)`, which is applied when it is sent. Changes are announced with the
## signals declared here; the specific event is emitted first and `phase_changed(new, old)` last, and
## inside any handler `phase` already reads the new phase.
##
## Contracts for callers:
## - Handlers connect immediately (never `CONNECT_DEFERRED`), never `await` in a `run_reset` handler and
##   never send a request or call `tick()` from inside a handler or a tick. One re-entrancy flag covers the
##   whole `tick()` and each immediate application; such a call is rejected with one error-level log line.
##   (The test plan, Open Question 17, suggests narrowing the guard to the `emit()` calls; the wider guard
##   also rejects a request sent from the injected clock or log sink during a tick, which is stricter and
##   keeps the rule simple.)
## - Contact reports (`request_hit`) must be level-triggered: a hit that this core discards (stale `run_id`,
##   settling tick, stall guard, Paused) is never remembered, so the collision owner keeps reporting an
##   overlap on every tick until one report is accepted or the overlap ends (GDD Core Rule 7).
## - Press stamps (`press_us`) come from the same injected clock domain; there is no buffering of presses.
class_name RunStateCore
extends RefCounted

## The six phases. Run State is the only owner of the phase (GDD Core Rule 1); the game starts in BOOT.
enum Phase { BOOT, MENU, RUNNING, PAUSED, RESUMING, HIT }
## Why a run was paused. `APP_INTERRUPTED` is applied when sent; the others are queued.
enum PauseSource { BUTTON, BACK, APP_INTERRUPTED, SENSOR_LOST }
## Request classes, in the processing priority order of GDD Core Rule 3, step 3.
enum RequestKind { HIT, PAUSE, RESUME, MENU, RESTART, MAP_READY, START }

## A new run is about to start; every system resets synchronously in the pinned subscriber order.
signal run_reset(run_id: int)
## Emitted after every `run_reset` handler returned; the next tick is a settling tick.
signal run_started(run_id: int)
## The run was paused; `source` is a `PauseSource` value.
signal run_paused(source: PauseSource)
## The resume countdown started; carries its length in milliseconds.
signal run_resuming(duration_ms: int)
## The countdown ended and play continues; the next tick is a settling tick.
signal run_resumed(run_id: int)
## A hit ended the run; carries the killer's `hazard_id` (-1 when unknown) and the run clock in ms.
signal run_ended(run_id: int, hazard_id: int, run_time_ms: int)
## The player left a paused run by restart or menu; carries the run clock in ms.
signal run_abandoned(run_id: int, run_time_ms: int)
## The Hit restart lock expired (once per Hit); only for the HUD prompt, never accompanied by `phase_changed`.
signal restart_unlocked(run_id: int)
## Emitted last for every accepted phase change, after the effects are complete.
signal phase_changed(new_phase: Phase, old_phase: Phase)

## The current phase (read-only).
var phase: Phase:
	get:
		return _phase

## Id of the current run: 0 before the first `run_reset`, +1 on every `run_reset`, never reused (read-only).
var run_id: int:
	get:
		return _run_id

## Seconds spent in Running since the last `run_reset`, advanced only by `dt_eff` (read-only).
var run_time: float:
	get:
		return _run_time

var _config: RunConfig
var _clock_us: Callable
var _log_sink: Callable

var _phase: Phase = Phase.BOOT
var _run_id: int = 0
var _run_time: float = 0.0

var _queue: Array[_Request] = []
var _busy: bool = false
var _tick_settling: bool = false
var _settling_pending: bool = false
## Phases left by an accepted request earlier in the current tick (for the debug class of GDD Core Rule 3).
var _tick_prior_phases: Array[int] = []

var _hit_us: int = 0
var _unlock_emitted: bool = false
var _paused_us: int = 0
var _resume_us: int = 0
var _last_dt_warning_us: int = 0
var _dt_warning_given: bool = false


## Builds a core in Boot with `run_id` 0. Construction emits nothing (GDD Core Rule 15).
## `config` is validated into a clamped copy (a null config means defaults); `clock_us` returns the
## monotonic time in microseconds; `log_sink` is called as `log_sink(level: int, message: String)`.
func _init(config: RunConfig, clock_us: Callable, log_sink: Callable) -> void:
	_clock_us = clock_us
	_log_sink = log_sink
	var source: RunConfig = config if config != null else RunConfig.new()
	_config = source.validated(log_sink)


## `map_ready`: the loader has loaded the map; Boot to Menu.
func request_map_ready() -> void:
	_enqueue(_make_request(RequestKind.MAP_READY))


## `start_requested`: Menu to Running.
func request_start() -> void:
	_enqueue(_make_request(RequestKind.START))


## `hit_reported(hazard_id, run_id)`: `hazard_id` is 0 or more, or -1 when unknown; `report_run_id` is the id
## the sender took from the last `run_reset`.
func request_hit(hazard_id: int, report_run_id: int) -> void:
	var req: _Request = _make_request(RequestKind.HIT)
	req.hazard_id = hazard_id
	req.run_id = report_run_id
	_enqueue(req)


## `pause_requested(source)`. `APP_INTERRUPTED` is applied at once (OS notifications arrive between frames);
## every other source is queued until the next tick.
func request_pause(source: PauseSource) -> void:
	if source == PauseSource.APP_INTERRUPTED:
		_apply_app_interrupted()
		return
	var req: _Request = _make_request(RequestKind.PAUSE)
	req.source = source
	_enqueue(req)


## `resume_requested`: Paused to Resuming. Never guarded.
func request_resume() -> void:
	_enqueue(_make_request(RequestKind.RESUME))


## `restart_requested(press_us)`: `press_us` is the press-down time stamped in the input handler with the
## injected clock. Accepted in Hit after the lock and in Paused after the guard.
func request_restart(press_us: int) -> void:
	var req: _Request = _make_request(RequestKind.RESTART)
	req.press_us = press_us
	_enqueue(req)


## `menu_requested(press_us)`: same locks as `request_restart`; goes to Menu.
func request_menu(press_us: int) -> void:
	var req: _Request = _make_request(RequestKind.MENU)
	req.press_us = press_us
	_enqueue(req)


## One frame (GDD Core Rule 3): queued requests in class priority order, then timers, then commit.
## Returns `dt_eff`, the world step of this frame: non-zero only for a tick that begins and ends in Running
## and is not a settling tick. The owner passes the same value on to Ball Movement.
func tick(world_dt: float, _real_dt: float) -> float:
	if _busy:
		_log(RunStateMath.LogLevel.ERROR, RunStateMath.LOG_REQUEST_NESTED, "tick() called from inside a handler or a tick")
		return 0.0
	_busy = true
	var now_us: int = _clock_us.call()
	var start_phase: Phase = _phase
	_tick_settling = _settling_pending
	_settling_pending = false
	_tick_prior_phases.clear()

	var step: float = 0.0
	if start_phase == Phase.RUNNING and not _tick_settling:
		step = _step_candidate(world_dt, now_us)

	_process_requests(now_us)
	_process_timers(now_us)

	var dt_eff: float = 0.0
	if start_phase == Phase.RUNNING and _phase == Phase.RUNNING:
		dt_eff = step
		_run_time += dt_eff
	_tick_prior_phases.clear()
	_busy = false
	return dt_eff


## `round(run_time * 1000)`, the integer form carried in events.
func run_time_ms() -> int:
	return RunStateMath.seconds_to_ms(_run_time)


## Seconds left of the resume countdown (F5); 0 outside Resuming.
func resume_remaining() -> float:
	if _phase != Phase.RESUMING:
		return 0.0
	var elapsed_s: float = float(RunStateMath.elapsed_us(_clock_us.call(), _resume_us)) / RunStateMath.US_PER_S
	return maxf(0.0, _config.resume_countdown - elapsed_s)


## Progress of the resume countdown in [0, 1] (F5); 0 outside Resuming.
func resume_progress() -> float:
	if _phase != Phase.RESUMING:
		return 0.0
	return RunStateCore.progress_for(_config.resume_countdown, _config.resume_countdown - resume_remaining())


## Pure countdown helper (F5): `1 - remaining / duration`; 1 when the duration is 0 or less.
## Named `progress_for` because a static and an instance function cannot share a name in GDScript.
static func progress_for(duration: float, elapsed: float) -> float:
	return RunStateMath.progress_for(duration, elapsed)


func _enqueue(req: _Request) -> void:
	if _busy:
		_log(
			RunStateMath.LogLevel.ERROR,
			RunStateMath.LOG_REQUEST_NESTED,
			"%s sent from inside a handler or a tick" % _request_name(req.kind)
		)
		return
	_queue.append(req)


func _make_request(kind: RequestKind) -> _Request:
	var req: _Request = _Request.new()
	req.kind = kind
	return req


func _apply_app_interrupted() -> void:
	if _busy:
		_log(
			RunStateMath.LogLevel.ERROR,
			RunStateMath.LOG_REQUEST_NESTED,
			"pause(app_interrupted) sent from inside a handler or a tick"
		)
		return
	if _phase != Phase.RUNNING and _phase != Phase.RESUMING:
		return # silent no-op (GDD Core Rule 3)
	_busy = true
	var now_us: int = _clock_us.call()
	_tick_prior_phases.clear()
	_enter_paused(PauseSource.APP_INTERRUPTED, now_us)
	_tick_prior_phases.clear()
	_busy = false


## F1 step candidate with the rate-limited warning for a bad input (at most one per second of injected time).
func _step_candidate(world_dt: float, now_us: int) -> float:
	if not RunStateMath.is_valid_dt(world_dt):
		_warn_bad_dt(now_us, world_dt)
		return 0.0
	return RunStateMath.clamp_step(world_dt, _config.dt_max)


func _warn_bad_dt(now_us: int, value: float) -> void:
	if _dt_warning_given and RunStateMath.elapsed_us(now_us, _last_dt_warning_us) < RunStateMath.seconds_to_us(1.0):
		return
	_dt_warning_given = true
	_last_dt_warning_us = now_us
	_log(RunStateMath.LogLevel.WARNING, RunStateMath.LOG_DT_INVALID, "world_dt=%s is not finite and non-negative" % value)


func _process_requests(now_us: int) -> void:
	var pending: Array[_Request] = _queue.duplicate()
	_queue.clear()
	var hits: Array[_Request] = []
	for req: _Request in pending:
		if req.kind == RequestKind.HIT:
			hits.append(req)
	_resolve_hits(hits, now_us)
	for kind: RequestKind in [
		RequestKind.PAUSE,
		RequestKind.RESUME,
		RequestKind.MENU,
		RequestKind.RESTART,
		RequestKind.MAP_READY,
		RequestKind.START,
	]:
		for req: _Request in pending:
			if req.kind == kind:
				_handle(req, now_us)


func _handle(req: _Request, now_us: int) -> void:
	match req.kind:
		RequestKind.PAUSE:
			if _phase == Phase.RUNNING or _phase == Phase.RESUMING:
				_enter_paused(req.source as PauseSource, now_us)
			else:
				_reject(req)
		RequestKind.RESUME:
			if _phase == Phase.PAUSED:
				_enter_resuming(now_us)
			else:
				_reject(req)
		RequestKind.MENU:
			_handle_leave(req, now_us, false)
		RequestKind.RESTART:
			_handle_leave(req, now_us, true)
		RequestKind.MAP_READY:
			if _phase == Phase.BOOT:
				var old: Phase = _set_phase(Phase.MENU)
				phase_changed.emit(_phase, old)
			else:
				_reject(req)
		RequestKind.START:
			if _phase == Phase.MENU:
				_begin_new_run(Phase.MENU)
			else:
				_reject(req)


## Restart and menu share the Hit lock and the Paused guard (F3); `restart` starts a run, otherwise go to Menu.
func _handle_leave(req: _Request, now_us: int, restart: bool) -> void:
	if _phase != Phase.HIT and _phase != Phase.PAUSED:
		_reject(req)
		return
	var press_us: int = _normalized_press(req, now_us)
	var anchor_us: int = _hit_us if _phase == Phase.HIT else _paused_us
	var limit_us: int = _config.restart_lock_us() if _phase == Phase.HIT else _config.pause_input_guard_us()
	if press_us - anchor_us < limit_us:
		_log(
			RunStateMath.LogLevel.DEBUG,
			RunStateMath.LOG_REQUEST_LOCKED,
			"%s press_us=%d inside the %s (anchor_us=%d, limit_us=%d)"
			% [_request_name(req.kind), press_us, "lock" if _phase == Phase.HIT else "guard", anchor_us, limit_us]
		)
		return
	var old_phase: Phase = _phase
	if restart:
		_begin_new_run(old_phase)
		return
	var old_id: int = _run_id
	var old_ms: int = run_time_ms()
	_set_phase(Phase.MENU)
	if old_phase == Phase.PAUSED:
		run_abandoned.emit(old_id, old_ms)
	phase_changed.emit(_phase, old_phase)


## Hit selection (GDD Core Rule 3 step 3, Core Rule 7, Edge Cases): stale `run_id` first, the settling tick
## ignores the rest, then the lowest non-negative `hazard_id` wins and -1 only if no known id is present.
func _resolve_hits(hits: Array[_Request], now_us: int) -> void:
	if hits.is_empty():
		return
	if _phase != Phase.RUNNING:
		for req: _Request in hits:
			_reject(req)
		return
	var candidates: Array[_Request] = []
	for req: _Request in hits:
		if req.run_id != _run_id:
			_log(
				RunStateMath.LogLevel.DEBUG,
				RunStateMath.LOG_HIT_STALE,
				"hit run_id=%d is not the current run_id=%d" % [req.run_id, _run_id]
			)
		elif _tick_settling:
			_log(RunStateMath.LogLevel.DEBUG, RunStateMath.LOG_HIT_SETTLING, "hit ignored on a settling tick")
		else:
			candidates.append(req)
	if candidates.is_empty():
		return
	var winner: int = -1
	for req: _Request in candidates:
		var hazard_id: int = req.hazard_id
		if hazard_id < -1:
			_log(
				RunStateMath.LogLevel.WARNING, RunStateMath.LOG_HIT_BAD_ID, "hazard_id=%d treated as -1" % hazard_id
			)
			hazard_id = -1
		if hazard_id >= 0 and (winner < 0 or hazard_id < winner):
			winner = hazard_id
	for _loser in range(candidates.size() - 1):
		_log(RunStateMath.LogLevel.DEBUG, RunStateMath.LOG_HIT_IGNORED, "hit lost the same-tick tie-break")
	_enter_hit(winner, now_us)


func _enter_hit(hazard_id: int, now_us: int) -> void:
	_hit_us = now_us
	_unlock_emitted = false
	var old: Phase = _set_phase(Phase.HIT)
	run_ended.emit(_run_id, hazard_id, run_time_ms())
	phase_changed.emit(_phase, old)


func _enter_paused(source: PauseSource, now_us: int) -> void:
	_paused_us = now_us
	var old: Phase = _set_phase(Phase.PAUSED)
	run_paused.emit(source)
	phase_changed.emit(_phase, old)


func _enter_resuming(now_us: int) -> void:
	_resume_us = now_us
	var old: Phase = _set_phase(Phase.RESUMING)
	run_resuming.emit(_config.resume_countdown_ms())
	phase_changed.emit(_phase, old)


## Two-step start (GDD Core Rule 4): `run_reset` for every handler, then `run_started`, in the same tick.
## A start from Paused first abandons the run.
func _begin_new_run(old_phase: Phase) -> void:
	var old_id: int = _run_id
	var old_ms: int = run_time_ms()
	_set_phase(Phase.RUNNING)
	if old_phase == Phase.PAUSED:
		run_abandoned.emit(old_id, old_ms)
	_run_id += 1
	_run_time = 0.0
	run_reset.emit(_run_id)
	_settling_pending = true
	run_started.emit(_run_id)
	phase_changed.emit(_phase, old_phase)


func _process_timers(now_us: int) -> void:
	match _phase:
		Phase.HIT:
			if not _unlock_emitted and RunStateMath.elapsed_us(now_us, _hit_us) >= _config.restart_lock_us():
				_unlock_emitted = true
				restart_unlocked.emit(_run_id)
		Phase.RESUMING:
			if RunStateMath.elapsed_us(now_us, _resume_us) >= _config.resume_countdown_us():
				var old: Phase = _set_phase(Phase.RUNNING)
				_settling_pending = true
				run_resumed.emit(_run_id)
				phase_changed.emit(_phase, old)


func _set_phase(new_phase: Phase) -> Phase:
	var old: Phase = _phase
	_tick_prior_phases.append(old)
	_phase = new_phase
	return old


## A missing or non-positive `press_us` is replaced by `now_us`, a future one is clamped to `now_us`, each
## with one error (F3): a bad stamp can neither bypass the lock nor block Hit forever.
func _normalized_press(req: _Request, now_us: int) -> int:
	if req.press_us <= 0:
		_log(
			RunStateMath.LogLevel.ERROR,
			RunStateMath.LOG_PRESS_US_INVALID,
			"%s press_us=%d is missing or not positive; using now_us" % [_request_name(req.kind), req.press_us]
		)
		return now_us
	if req.press_us > now_us:
		_log(
			RunStateMath.LogLevel.ERROR,
			RunStateMath.LOG_PRESS_US_INVALID,
			"%s press_us=%d is in the future; clamped to now_us=%d" % [_request_name(req.kind), req.press_us, now_us]
		)
		return now_us
	return req.press_us


## Logs a request that is not valid in the current phase, at the class level of GDD Core Rule 3.
func _reject(req: _Request) -> void:
	var level: int = _reject_level(req)
	if level < 0:
		return
	_log(
		level,
		RunStateMath.LOG_REQUEST_REJECTED,
		"%s rejected in phase %s" % [_request_name(req.kind), Phase.keys()[_phase]]
	)


## -1 is the silent class, otherwise a `RunStateMath.LogLevel` value.
func _reject_level(req: _Request) -> int:
	var level: int = RunStateMath.LogLevel.WARNING
	match req.kind:
		RequestKind.HIT:
			if _phase == Phase.PAUSED or _phase == Phase.RESUMING or _phase == Phase.HIT:
				level = RunStateMath.LogLevel.DEBUG
		RequestKind.PAUSE:
			if req.source != PauseSource.BUTTON:
				return -1
			if _phase == Phase.PAUSED:
				level = RunStateMath.LogLevel.DEBUG
		RequestKind.RESUME:
			if _phase == Phase.RESUMING:
				level = RunStateMath.LogLevel.DEBUG
		RequestKind.RESTART:
			if _phase == Phase.RUNNING:
				level = RunStateMath.LogLevel.DEBUG
		_:
			pass
	if level == RunStateMath.LogLevel.WARNING and _was_valid_earlier_this_tick(req):
		level = RunStateMath.LogLevel.DEBUG
	return level


## True when an earlier accepted request on this tick left a phase in which `req` would have been valid.
func _was_valid_earlier_this_tick(req: _Request) -> bool:
	for prior: int in _tick_prior_phases:
		if _is_valid_in(req, prior as Phase):
			return true
	return false


func _is_valid_in(req: _Request, in_phase: Phase) -> bool:
	match req.kind:
		RequestKind.MAP_READY:
			return in_phase == Phase.BOOT
		RequestKind.START:
			return in_phase == Phase.MENU
		RequestKind.HIT:
			return in_phase == Phase.RUNNING
		RequestKind.PAUSE:
			return in_phase == Phase.RUNNING or in_phase == Phase.RESUMING
		RequestKind.RESUME:
			return in_phase == Phase.PAUSED
		RequestKind.RESTART, RequestKind.MENU:
			return in_phase == Phase.HIT or in_phase == Phase.PAUSED
	return false


func _request_name(kind: RequestKind) -> String:
	return String(RequestKind.keys()[kind]).to_lower()


func _log(level: int, code: StringName, detail: String) -> void:
	if _log_sink.is_valid():
		_log_sink.call(level, "%s %s" % [code, detail])


## A queued request: only the fields of its kind are meaningful.
class _Request:
	extends RefCounted

	var kind: RequestKind = RequestKind.HIT
	var source: int = PauseSource.BUTTON
	var hazard_id: int = -1
	var run_id: int = 0
	var press_us: int = 0
