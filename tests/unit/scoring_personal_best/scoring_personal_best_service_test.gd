## Story SPB-009: ScoreService forwards the Run State signals to ScoreCore, non-deferred, no scene tree (AC-19).
extends GutTest

const Fixtures = preload("res://tests/support/scoring_fixtures.gd")


## Records the handler calls and their arguments; the seams are valid but unused.
class SpyCore:
	extends ScoreCore
	var calls: Array[Array] = []
	var step_calls: int = 0

	func on_run_reset(run_id: int = 0) -> void:
		calls.append(["reset", run_id])

	func on_run_ended(run_id: int, hazard_id: int, run_time_ms: int) -> void:
		calls.append(["ended", run_id, hazard_id, run_time_ms])

	func on_run_abandoned(run_id: int, run_time_ms: int) -> void:
		calls.append(["abandoned", run_id, run_time_ms])

	func step() -> void:
		step_calls += 1


## The three-signal source of Run State, nothing else.
class FakeRunState:
	extends RefCounted
	signal run_reset(run_id: int)
	signal run_ended(run_id: int, hazard_id: int, run_time_ms: int)
	signal run_abandoned(run_id: int, run_time_ms: int)


func _spy_core() -> SpyCore:
	var s_stub: Fixtures.SStub = Fixtures.make_s_stub([])
	var save: Fixtures.SaveStub = Fixtures.make_save_stub(0)
	return SpyCore.new(s_stub.read, save.get_value, save.set_value, [] as Array[int])


func test_each_signal_reaches_its_handler_with_arguments_before_emit_returns() -> void:
	var core: SpyCore = _spy_core()
	var source: FakeRunState = FakeRunState.new()
	var service: ScoreService = ScoreService.new(core, source)
	autofree(service)
	assert_false(service.is_inside_tree(), "no scene tree is needed")
	source.run_reset.emit(7)
	assert_eq(core.calls, [["reset", 7]] as Array[Array])
	source.run_ended.emit(7, 3, 12345)
	assert_eq(core.calls[1], ["ended", 7, 3, 12345])
	source.run_abandoned.emit(8, 999)
	assert_eq(core.calls[2], ["abandoned", 8, 999])
	assert_eq(core.calls.size(), 3)


func test_step_forwards_once_per_call() -> void:
	var core: SpyCore = _spy_core()
	var service: ScoreService = ScoreService.new(core, null)
	autofree(service)
	service.step()
	service.step()
	assert_eq(core.step_calls, 2)
	assert_eq(service.get_core(), core)


func test_connections_are_not_deferred_and_have_no_per_frame_callback() -> void:
	var source: FakeRunState = FakeRunState.new()
	var service: ScoreService = ScoreService.new(_spy_core(), source)
	autofree(service)
	for connection: Dictionary in source.run_ended.get_connections():
		assert_eq((connection["flags"] as int) & CONNECT_DEFERRED, 0)
	assert_false(service.has_method(&"_process"))
	assert_false(service.has_method(&"_physics_process"))
	assert_false(service.is_processing())


func test_source_without_the_signals_is_tolerated() -> void:
	var service: ScoreService = ScoreService.new(_spy_core(), RefCounted.new())
	autofree(service)
	assert_not_null(service)


func test_real_core_reaches_a_best_through_the_service() -> void:
	var s_stub: Fixtures.SStub = Fixtures.make_s_stub([42.5])
	var save: Fixtures.SaveStub = Fixtures.make_save_stub(0)
	var core: ScoreCore = Fixtures.make_core(s_stub, save)
	var source: FakeRunState = FakeRunState.new()
	var service: ScoreService = ScoreService.new(core, source)
	autofree(service)
	service.step()
	source.run_ended.emit(1, 2, 3)
	assert_eq(core.final_score, 42)
	assert_eq(save.last_set_args, ["scoring", "personal_best", 42])


func test_no_autoload_entry_for_scoring_classes() -> void:
	for autoload_name: String in ["ScoreService", "ScoreCore"]:
		assert_false(ProjectSettings.has_setting("autoload/" + autoload_name), autoload_name)

