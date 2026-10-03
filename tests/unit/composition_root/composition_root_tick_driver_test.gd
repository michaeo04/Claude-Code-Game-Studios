## Story CR-001: GameRoot clock injection and single tick driver.
extends GutTest

const ClockStub = preload("res://tests/support/clock_stub.gd")


## GameRoot whose `_tick` only records its arguments.
class SpyRoot:
	extends GameRoot
	var calls: Array[Array] = []

	func _tick(real_dt: float, world_dt: float) -> void:
		calls.append([real_dt, world_dt])


var _clocks: Array[ClockStub] = []


func _make(clock: ClockStub) -> SpyRoot:
	_clocks.append(clock) # the stub is RefCounted: keep it alive for the callable
	var root: SpyRoot = SpyRoot.new(clock.as_callable())
	autofree(root)
	return root


func test_node_class_and_process_mode_always() -> void:
	var root: GameRoot = GameRoot.new()
	autofree(root)
	assert_eq(root.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_true(root is Node)


func test_engine_delta_is_ignored() -> void:
	var results: Array[float] = []
	for engine_delta: float in [0.001, 0.133]:
		var clock: ClockStub = ClockStub.new(1_000_000)
		var root: SpyRoot = _make(clock)
		root._process(engine_delta)
		clock.advance_us(16_000)
		root._process(engine_delta)
		results.append(root.calls[1][0] as float)
	assert_eq(results[0], results[1])
	assert_almost_eq(results[0], 0.016, 1e-9)


func test_gap_of_5_seconds_is_not_clamped() -> void:
	var clock: ClockStub = ClockStub.new(0)
	var root: SpyRoot = _make(clock)
	root._process(0.016)
	clock.advance_s(5.0)
	root._process(0.016)
	assert_eq(root.calls[1][0] as float, 5.0)
	assert_eq(root.calls[1][1] as float, 5.0, "world_dt equals real_dt")


func test_first_tick_yields_zero_not_boot_gap() -> void:
	var root: SpyRoot = _make(ClockStub.new(987_654_321))
	root._process(0.016)
	assert_eq(root.calls[0][0] as float, 0.0)


func test_non_monotone_clock_does_not_crash() -> void:
	var clock: ClockStub = ClockStub.new(2_000_000)
	var root: SpyRoot = _make(clock)
	root._process(0.0)
	clock.advance_us(-500_000)
	root._process(0.0)
	assert_eq(root.calls.size(), 2)
	assert_almost_eq(root.calls[1][0] as float, -0.5, 1e-9)


func test_tick_called_once_per_process_with_equal_args() -> void:
	var clock: ClockStub = ClockStub.new(0)
	var root: SpyRoot = _make(clock)
	clock.advance_us(1000)
	root._process(0.016)
	assert_eq(root.calls.size(), 1)
	assert_eq(root.calls[0][0] as float, root.calls[0][1] as float)


func test_default_clock_is_valid_without_injection() -> void:
	var root: GameRoot = GameRoot.new()
	autofree(root)
	assert_true(root.clock_us.is_valid())


func test_register_view_disables_processing() -> void:
	var root: GameRoot = GameRoot.new()
	autofree(root)
	var view: Node = Node.new()
	autofree(view)
	view.set_process(true)
	view.set_physics_process(true)
	root.register_view(view)
	assert_false(view.is_processing())
	assert_false(view.is_physics_processing())


func test_ticking_never_pauses_tree_or_changes_time_scale() -> void:
	var scale_before: float = Engine.time_scale
	var clock: ClockStub = ClockStub.new(0)
	var root: SpyRoot = _make(clock)
	add_child(root)
	for i: int in range(3):
		clock.advance_us(16_000)
		root._process(0.016)
	assert_false(get_tree().paused)
	assert_eq(Engine.time_scale, scale_before)
