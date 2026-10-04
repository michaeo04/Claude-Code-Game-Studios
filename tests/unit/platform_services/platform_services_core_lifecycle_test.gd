## PlatformCore lifecycle model and edge signals (platform-services story 004; GDD AC-1, AC-2).
extends GutTest

const Rig = preload("res://tests/support/platform_rig.gd")

const FO: int = 0
const FI: int = 1
const P: int = 2
const R: int = 3
const EVENT_NAMES: Array[String] = ["FO", "FI", "P", "R"]
const NOOP_KEYS: Array[String] = ["FOCUS_OUT", "FOCUS_IN", "PAUSED", "RESUMED"]


func _send(core: PlatformCore, event: int) -> void:
	match event:
		FO:
			core.on_focus_out()
		FI:
			core.on_focus_in()
		P:
			core.on_paused()
		R:
			core.on_resumed()


## Runs the event string (e.g. "FO,P,FI,R") and returns the per-event signals joined with " | ".
func _run(fis: bool, events: String) -> Array:
	var rig: Rig = Rig.new(fis)
	var per_event: Array[String] = []
	for name: String in events.split(","):
		_send(rig.core, EVENT_NAMES.find(name))
		per_event.append(rig.take())
	return [rig, per_event]


func _check(fis: bool, events: String, expected: Array[String], noops: int) -> void:
	var res: Array = _run(fis, events)
	assert_eq(res[1], expected, "fis=%s %s" % [fis, events])
	assert_eq((res[0] as Rig).sink.count(), noops, "noop logs fis=%s %s" % [fis, events])


func test_construction_emits_nothing_and_starts_attentive() -> void:
	for fis: bool in [false, true]:
		var rig: Rig = Rig.new(fis)
		assert_true(rig.core.attentive)
		assert_false(rig.core.suspended)
		assert_eq(rig.take(), "-")
		assert_eq(rig.sink.count(), 0)


func test_fis_false_rows_match_gdd() -> void:
	_check(false, "FO,P,FI,R", ["INT", "BG", "-", "FG,RET"], 0)
	_check(false, "FO,P,R,FI", ["INT", "BG", "FG", "RET"], 0)
	_check(false, "FO,FI", ["INT", "RET"], 0)
	_check(false, "FO,FO,P,FI,R", ["INT", "-", "BG", "-", "FG,RET"], 1)
	_check(false, "P,P", ["INT,BG", "-"], 1)


func test_android_rows_match_gdd() -> void:
	_check(true, "FO,FI", ["INT,BG", "FG,RET"], 0)
	_check(true, "FO,P,FI,R", ["INT,BG", "-", "FG,RET", "-"], 2)
	_check(true, "P,FO,R,FI", ["-", "INT,BG", "-", "FG,RET"], 2)
	_check(true, "FO,P,FI", ["INT,BG", "-", "FG,RET"], 1)
	_check(true, "FO,FI,P,R", ["INT,BG", "FG,RET", "-", "-"], 2)


func test_resume_or_focus_in_on_fresh_core_logs_one_noop_with_event_key() -> void:
	for fis: bool in [false, true]:
		for pair: Array in [[R, "RESUMED"], [FI, "FOCUS_IN"]]:
			var res: Array = _run(fis, EVENT_NAMES[pair[0]])
			var rig: Rig = res[0]
			assert_eq(res[1], ["-"])
			assert_eq(rig.sink.count(), 1)
			assert_eq(rig.sink.entries[0][0], LogLevel.DEBUG)
			assert_eq(rig.sink.entries[0][1], RateLimitedLog.LIFECYCLE_NOOP)
			assert_eq(rig.sink.entries[0][2], pair[1])


func test_repeated_events_log_noop_and_change_nothing() -> void:
	var res: Array = _run(false, "FO,FO")
	assert_eq(res[1], ["INT", "-"])
	assert_eq((res[0] as Rig).sink.entries[0][2], "FOCUS_OUT")
	res = _run(false, "P,P")
	assert_eq((res[0] as Rig).sink.entries[0][2], "PAUSED")
	res = _run(true, "P")
	assert_eq((res[0] as Rig).sink.entries[0][2], "PAUSED")
	res = _run(true, "R")
	assert_eq((res[0] as Rig).sink.entries[0][2], "RESUMED")


func test_signal_is_recorded_before_the_handler_returns() -> void:
	var rig: Rig = Rig.new(true)
	rig.core.on_focus_out()
	assert_eq(rig.signals, ["INT", "BG"] as Array[String])
	assert_false(rig.core.attentive)
	assert_true(rig.core.suspended)


## state label -> events reaching it from a fresh core: (focused, paused).
func _reach(fis: bool, focused: bool, paused: bool) -> Array[int]:
	var path: Array[int] = []
	if not focused:
		path.append(FO)
	if paused and not fis:
		path.append(P)
	return path


func test_transition_table_matches_literal_expectations() -> void:
	# [fis, focused, paused, event, signals, next_focused, next_paused]
	var table: Array = [
		[false, true, false, FO, "INT", false, false],
		[false, true, false, FI, "-", true, false],
		[false, true, false, P, "INT,BG", true, true],
		[false, true, false, R, "-", true, false],
		[false, false, false, FO, "-", false, false],
		[false, false, false, FI, "RET", true, false],
		[false, false, false, P, "BG", false, true],
		[false, false, false, R, "-", false, false],
		[false, true, true, FO, "-", false, true],
		[false, true, true, FI, "-", true, true],
		[false, true, true, P, "-", true, true],
		[false, true, true, R, "FG,RET", true, false],
		[false, false, true, FO, "-", false, true],
		[false, false, true, FI, "-", true, true],
		[false, false, true, P, "-", false, true],
		[false, false, true, R, "FG", false, false],
		[true, true, false, FO, "INT,BG", false, false],
		[true, true, false, FI, "-", true, false],
		[true, true, false, P, "-", true, false],
		[true, true, false, R, "-", true, false],
		[true, false, false, FO, "-", false, false],
		[true, false, false, FI, "FG,RET", true, false],
		[true, false, false, P, "-", false, false],
		[true, false, false, R, "-", false, false],
	]
	for row: Array in table:
		var rig: Rig = Rig.new(row[0])
		for e: int in _reach(row[0], row[1], row[2]):
			_send(rig.core, e)
		rig.take()
		assert_eq(rig.core.attentive, row[1] and not row[2], "precondition %s" % [row])
		_send(rig.core, row[3])
		assert_eq(rig.take(), row[4], "signals %s" % [row])
		assert_eq(rig.core.attentive, row[5] and not row[6], "attentive %s" % [row])
		var susp: bool = row[6] or (row[0] and not row[5])
		assert_eq(rig.core.suspended, susp, "suspended %s" % [row])


## All 4+16+64+256+1024+4096 = 5460 sequences of 1-6 events, fixed enumeration order.
func test_exhaustive_sequences_hold_invariants() -> void:
	var count: int = 0
	for fis: bool in [false, true]:
		for length in range(1, 7):
			var total: int = 1 << (2 * length)
			for code in range(total):
				var seq: Array[int] = []
				for i in range(length):
					seq.append((code >> (2 * i)) & 3)
				if _check_sequence(fis, seq):
					count += 1
	assert_eq(count, 2 * 5460)


func _check_sequence(fis: bool, seq: Array[int]) -> bool:
	var rig: Rig = Rig.new(fis)
	var label: String = "fis=%s seq=%s" % [fis, ",".join(seq.map(func(e: int) -> String: return EVENT_NAMES[e]))]
	var ints: int = 0
	var bgs: int = 0
	var ok: bool = true
	for e: int in seq:
		var before_a: bool = rig.core.attentive
		var before_s: bool = rig.core.suspended
		_send(rig.core, e)
		var sigs: Array[String] = rig.signals.duplicate()
		rig.signals.clear()
		ok = ok and _expect(sigs.size() <= 2, label + " at most 2 signals")
		ok = ok and _expect(not (sigs.has("INT") and sigs.has("RET")), label + " INT with RET")
		ok = ok and _expect(not (sigs.has("BG") and sigs.has("FG")), label + " BG with FG")
		var order: Array[int] = []
		for s: String in sigs:
			order.append(["INT", "BG", "FG", "RET"].find(s))
		var sorted: Array[int] = order.duplicate()
		sorted.sort()
		ok = ok and _expect(order == sorted, label + " signal order")
		ints += int(sigs.has("INT")) - int(sigs.has("RET"))
		bgs += int(sigs.has("BG")) - int(sigs.has("FG"))
		ok = ok and _expect(ints == (0 if rig.core.attentive else 1), label + " INT/RET count")
		ok = ok and _expect(bgs == (1 if rig.core.suspended else 0), label + " BG/FG count")
		if fis:
			ok = ok and _expect(sigs.has("INT") == sigs.has("BG"), label + " INT/BG share an event")
			ok = ok and _expect(sigs.has("FG") == sigs.has("RET"), label + " FG/RET share an event")
			if e == P or e == R:
				ok = ok and _expect(before_a == rig.core.attentive and before_s == rig.core.suspended, label + " P/R changed a getter")
	rig.core.on_focus_in()
	rig.core.on_resumed()
	ok = ok and _expect(rig.core.attentive and not rig.core.suspended, label + " liveness")
	return ok


func _expect(cond: bool, message: String) -> bool:
	assert_true(cond, message)
	return cond


func test_redundant_lifecycle_1000_calls_log_one_line_per_window() -> void:
	var rig: Rig = Rig.new(true)
	for i: int in range(1000):
		rig.clock.now_us = i * 1000
		rig.core.on_resumed()
	assert_eq(rig.sink.count(), 1, "1000 redundant resumes in one window are one line")
