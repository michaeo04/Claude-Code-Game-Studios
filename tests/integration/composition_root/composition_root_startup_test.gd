## Story CR-010: map load hand-off and loop start through the real `GameRoot._ready()` (ADR-0002 Decision 5).
extends GutTest

const Spy = preload("res://tests/support/system_spy.gd")
const Fake = preload("res://tests/support/map_loader_fake_seams.gd")
const TEMP_PATH: String = "user://cr010_startup_fixture.tres"
const STEP_US: int = 16667

var _root: GameRoot
var _rs: RunStateCore
var _seams: LoggingSeams
var _menus: MenusProbe
var _log: Array[String] = []
var _emissions: Array[String] = []
var _wired_at_emission: Array[bool] = []
var _now_us: Array[int] = [0]
var _map_path: String = TEMP_PATH


class LoggingSeams extends Fake:
	var order: Array[String]
	var run_state: RunStateCore

	func tube_load(cfg: TubeConfig) -> bool:
		order.append("load_map")
		return super.tube_load(cfg)

	func send_map_ready() -> void:
		order.append("map_ready")
		super.send_map_ready()
		run_state.request_map_ready()


class MenusProbe extends RefCounted:
	var order: Array[String]
	var failures: Array[PackedStringArray] = []
	var ticks: Array[int] = [0]

	func bind_map_loader(failed: Signal, _retry: Callable) -> void:
		failed.connect(on_map_load_failed)

	func on_map_load_failed(codes: PackedStringArray) -> void:
		failures.append(codes)

	func tick() -> void:
		ticks[0] += 1
		order.append("tick")


func before_each() -> void:
	_log.clear()
	_emissions.clear()
	_wired_at_emission.clear()
	_now_us[0] = 0
	_map_path = TEMP_PATH
	assert_eq(ResourceSaver.save(Fake.valid_definition(), TEMP_PATH), OK)
	_rs = RunStateCore.new(RunConfig.new(), func() -> int: return _now_us[0], Callable())
	_rs.phase_changed.connect(_on_phase_changed)
	_rs.run_reset.connect(_on_run_reset)
	_seams = LoggingSeams.new()
	_seams.run_state = _rs
	_menus = MenusProbe.new()
	_seams.order = _log
	_menus.order = _log


func after_each() -> void:
	if _root != null:
		_root.free()
		_root = null
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func _on_phase_changed(_n: RunStateCore.Phase, _o: RunStateCore.Phase) -> void:
	_emissions.append("phase_changed")
	_wired_at_emission.append(_root.construction_trace.has(&"wire"))


func _on_run_reset(_run_id: int) -> void:
	_emissions.append("run_reset")


func _build_root() -> void:
	_root = GameRoot.new(func() -> int:
		_now_us[0] += STEP_US
		return _now_us[0], func() -> String: return "mobile")
	_root.quit_on_fatal = false
	_root.configure(_factory())


func _factory() -> Dictionary:
	var ball: BallConfig = BallConfig.new()
	var factory: Dictionary = {
		&"tube_config": TubeConfig.new(), &"ball_config": ball, &"world_frame_config": WorldFrameConfig.new(),
		&"slot_count": 20,
	}
	for step: StringName in GameRoot.CONSTRUCTION_ORDER:
		if step == &"preflight":
			continue
		factory[step] = func() -> Object:
			_log.append("construct:%s" % step)
			return Spy.new(String(step), _log)
	factory[&"run_state"] = func() -> Object:
		_log.append("construct:run_state")
		return _rs
	factory[&"menus"] = func() -> Object:
		_log.append("construct:menus")
		return _menus
	factory[&"core_systems"] = func() -> Dictionary:
		var out: Dictionary = {}
		for key: StringName in [&"tilt_input", &"tilt_adapter", &"ball", &"tube_track", &"tube_view", &"obstacle",
				&"near_miss", &"camera"]:
			out[key] = Spy.new(String(key), _log)
		return out
	factory[&"map_loader"] = func(config: MapLoaderConfig) -> Object:
		config.map_path = _map_path
		return MapLoader.new(config, _seams)
	return factory


func _boot_and_tick(ticks: int) -> void:
	_build_root()
	add_child(_root)
	for i: int in ticks:
		_root._process(0.016)


func test_order_is_construct_wire_load_map_ready_then_first_tick() -> void:
	_boot_and_tick(60)
	assert_eq(_root.construction_trace.slice(-3), [&"wire", &"map_loader", &"map_loader.start"] as Array[StringName])
	var load_at: int = _log.find("load_map")
	var ready_at: int = _log.find("map_ready")
	var first_tick: int = _log.find("tilt_input.poll")
	assert_gt(load_at, _log.find("construct:menus"), "load attempt after every construction step")
	assert_gt(ready_at, load_at)
	assert_gt(first_tick, ready_at, "no tick before the load attempt and map_ready")
	assert_eq(_log.count("tilt_input.poll"), 60)


func test_failing_load_sends_no_map_ready_and_menus_hears_it_once() -> void:
	_seams.fail["tube_load"] = true
	_boot_and_tick(0)
	assert_eq(_seams.count("map_ready"), 0)
	assert_eq(_rs.phase, RunStateCore.Phase.BOOT)
	assert_eq(_menus.failures.size(), 1)
	assert_true(_menus.failures[0].size() >= 1)
	assert_eq(_emissions.size(), 0)


func test_boot_phase_still_ticks_with_zero_effective_dt() -> void:
	_seams.fail["tube_load"] = true
	_boot_and_tick(10)
	assert_eq(_menus.ticks[0], 10, "Menus ticks in Boot")
	assert_eq(_log.count("tilt_input.poll"), 10, "Tilt and Platform-side ticks run in Boot")
	assert_eq(_rs.tick(0.016, 0.016), 0.0, "dt_eff is zero outside Running")
	assert_eq(_rs.phase, RunStateCore.Phase.BOOT)


func test_headless_smoke_sixty_ticks_without_script_error() -> void:
	_boot_and_tick(60)
	assert_eq(_menus.ticks[0], 60)
	assert_eq(_rs.phase, RunStateCore.Phase.MENU)
	for step: StringName in GameRoot.CONSTRUCTION_ORDER:
		if step != &"preflight" and step != &"core_systems":
			assert_true(_log.has("construct:%s" % step), "built %s" % step)


func test_map_ready_is_the_first_run_state_emission_after_every_connect() -> void:
	_boot_and_tick(1)
	assert_gt(_emissions.size(), 0)
	assert_eq(_emissions[0], "phase_changed", "Boot to Menu is first")
	assert_eq(_wired_at_emission[0], true, "arrived after _wire()")
	assert_eq(_rs.phase, RunStateCore.Phase.MENU)
