extends GutTest

const Fixture = preload("res://tests/support/near_miss_fixture.gd")
const Script500 = preload("res://tests/support/near_miss_script.gd")


func _driver(id_base: int = 0) -> Script500.Driver:
	return Script500.Driver.new(Fixture.make_core(NearMissConfig.new()),
			Fixture.make_ball_state_stub(0.0, 0.0, 0.0, 0.0), id_base)


func _solo() -> Array[Array]:
	var d: Script500.Driver = _driver()
	for i: int in Script500.TICKS:
		d.advance()
	return d.stream


func test_ac19_two_fresh_cores_give_bit_identical_streams() -> void:
	var a: Array[Array] = _solo()
	var b: Array[Array] = _solo()
	assert_gte(a.size(), 5, "the script produces near misses")
	assert_eq(a, b)


func test_ac19_interleaved_third_instance_changes_neither_stream() -> void:
	var solo: Array[Array] = _solo()
	var a: Script500.Driver = _driver()
	var b: Script500.Driver = _driver()
	var c: Script500.Driver = _driver(5000)
	for i: int in Script500.TICKS:
		a.advance()
		c.advance()
		b.advance()
	assert_eq(a.stream, solo)
	assert_eq(b.stream, solo)
	assert_eq(c.stream, solo, "the third instance sees the same stream up to its own id offset")


func test_ac19_script_covers_hits_releases_and_resets() -> void:
	var run_ids: Dictionary = {}
	var hazards: Dictionary = {}
	for e: Array in _solo():
		run_ids[e[2]] = true
		hazards[e[1]] = true
	assert_gt(run_ids.size(), 2, "several run ids appear")
	assert_false(hazards.has(1001), "cycle 1 (hit) never emits")
	assert_false(hazards.has(1003), "cycle 3 (reset release) never emits")
	assert_true(hazards.has(1000) and hazards.has(1002), "cycles 0 and 2 emit")


func test_ac20_core_only_reads_the_four_pose_properties_and_never_writes() -> void:
	var spy: Script500.SpyBall = Script500.SpyBall.new()
	var d: Script500.Driver = Script500.Driver.new(Fixture.make_core(NearMissConfig.new()), spy)
	for i: int in Script500.TICKS:
		d.advance()
	assert_gt(spy.reads.size(), 0)
	var allowed: Array[StringName] = [&"theta", &"theta_prev", &"s", &"s_prev"]
	for r: StringName in spy.reads:
		assert_true(allowed.has(r), "read %s is an allowed accessor" % r)
	assert_eq(spy.writes.size(), 0, "the core writes nothing to the ball")
	assert_gte(d.stream.size(), 5, "the replay still produced its near misses")


func test_ac20_only_outbound_surface_is_the_two_field_signal() -> void:
	# The core is built from config numbers only (no Obstacle or Run State reference); Obstacle and Run State
	# reach it only as handler calls, so its only outbound surface is its own signal.
	var core: NearMissCore = Fixture.make_core(NearMissConfig.new())
	var found: int = 0
	for sig: Dictionary in core.get_script().get_script_signal_list():
		found += 1
		assert_eq(sig["name"], &"near_miss_detected")
		assert_eq((sig["args"] as Array).size(), 2)
	assert_eq(found, 1)
