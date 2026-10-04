## Story ML-009: loader wiring order, `map_load_failed` to Menus, the Retry Callable (ADR-0004, ADR-0002).
extends GutTest

const Fakes = preload("res://tests/support/rebase_fakes.gd")
const Fake = preload("res://tests/support/map_loader_fake_seams.gd")
const TEMP_PATH: String = "user://ml009_wiring_fixture.tres"

var _root: GameRoot
var _rs: RunStateCore
var _menus: MenusSpy
var _seams: RunStateSeams
var _map_path: String = "res://nope.tres"
var _phase_changes: Array[int] = []


class RunStateSeams extends Fake:
	var run_state: RunStateCore

	func send_map_ready() -> void:
		super.send_map_ready()
		run_state.request_map_ready()


class MenusSpy extends RefCounted:
	var codes_received: Array[PackedStringArray] = []
	var retry: Callable
	var flags: Array[int] = []
	var failure_screen_visible: bool = false
	var ticks_at_failure: int = -1
	var tick_counter: Array[int] = [0]

	func bind_map_loader(failed: Signal, request_map_retry: Callable) -> void:
		failed.connect(on_map_load_failed)
		for conn: Dictionary in failed.get_connections():
			flags.append(conn["flags"] as int)
		retry = request_map_retry

	func bind_run_state(rs: RunStateCore) -> void:
		rs.phase_changed.connect(on_phase_changed)

	func on_map_load_failed(codes: PackedStringArray) -> void:
		codes_received.append(codes)
		failure_screen_visible = true
		ticks_at_failure = tick_counter[0]

	func on_phase_changed(new_phase: RunStateCore.Phase, _old: RunStateCore.Phase) -> void:
		if new_phase == RunStateCore.Phase.MENU:
			failure_screen_visible = false


func before_each() -> void:
	_phase_changes.clear()
	_map_path = "res://nope.tres"
	_rs = RunStateCore.new(RunConfig.new(), func() -> int: return 0, Callable())
	_rs.phase_changed.connect(func(_n: RunStateCore.Phase, _o: RunStateCore.Phase) -> void: _phase_changes.append(1))
	_menus = MenusSpy.new()
	_menus.bind_run_state(_rs)
	_seams = RunStateSeams.new()
	_seams.run_state = _rs
	_root = GameRoot.new(Callable())
	_root.quit_on_fatal = false
	_root.configure(_factory())


func after_each() -> void:
	_root.free()
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func _factory() -> Dictionary:
	var ball: BallConfig = BallConfig.new()
	var factory: Dictionary = {
		&"tube_config": TubeConfig.new(), &"ball_config": ball, &"world_frame_config": WorldFrameConfig.new(),
		&"slot_count": 20,
	}
	for step: StringName in GameRoot.CONSTRUCTION_ORDER:
		if step == &"preflight":
			continue
		factory[step] = func() -> Object: return Fakes.Stub.new()
	factory[&"run_state"] = func() -> Object: return _rs
	factory[&"menus"] = func() -> Object: return _menus
	factory[&"core_systems"] = func() -> Dictionary:
		var out: Dictionary = {}
		for key: StringName in [&"tilt_input", &"tilt_adapter", &"ball", &"tube_track", &"tube_view", &"obstacle",
				&"near_miss", &"camera"]:
			out[key] = Fakes.Stub.new()
		return out
	factory[&"map_loader"] = func(config: MapLoaderConfig) -> Object:
		config.map_path = _map_path
		return MapLoader.new(config, _seams)
	return factory


func _boot() -> void:
	add_child(_root)
	remove_child(_root)


func test_loader_attempts_after_wire_and_before_the_first_tick() -> void:
	_boot()

	assert_eq(_root.construction_trace.slice(-3), [&"wire", &"map_loader", &"map_loader.start"] as Array[StringName])
	assert_eq(_menus.ticks_at_failure, 0, "the attempt ran before any tick")
	assert_eq(_rs.phase, RunStateCore.Phase.BOOT)


func test_failing_map_reaches_menus_in_the_same_call() -> void:
	_boot()

	assert_eq(_menus.codes_received.size(), 1)
	assert_eq(_menus.codes_received[0], PackedStringArray(["MAP_RESOURCE_MISSING"]))
	assert_true(_menus.failure_screen_visible)


func test_failure_connection_is_immediate() -> void:
	_boot()

	assert_eq(_menus.flags.size(), 1)
	assert_eq(_menus.flags[0] & CONNECT_DEFERRED, 0)


func test_boot_after_failure_rejects_start_and_emits_nothing() -> void:
	_boot()

	_rs.request_start()
	_rs.tick(0.016, 0.016)

	assert_eq(_rs.phase, RunStateCore.Phase.BOOT)
	assert_eq(_phase_changes.size(), 0)


func test_retry_callable_reruns_the_sequence_and_goes_to_menu_once() -> void:
	_map_path = TEMP_PATH
	assert_eq(ResourceSaver.save(Resource.new(), TEMP_PATH), OK)
	_boot()
	assert_true(_menus.failure_screen_visible)
	assert_true(_menus.retry.is_valid())
	assert_eq(ResourceSaver.save(Fake.valid_definition(), TEMP_PATH), OK)

	assert_true(_menus.retry.call() as bool)
	_rs.tick(0.016, 0.016)

	assert_eq(_seams.count("map_ready"), 1)
	assert_eq(_rs.phase, RunStateCore.Phase.MENU)
	assert_eq(_phase_changes.size(), 1, "phase_changed emitted once")
	assert_false(_menus.failure_screen_visible)


func test_timeout_backup_is_not_needed_when_the_signal_fired() -> void:
	_boot()

	assert_eq(_menus.codes_received.size(), 1, "the screen state is set by the signal alone, no timer involved")
