## Story RS-001: shape of `RunStateCore` (GDD AC-8): signals, base class, instance independence, initial state.
## AC-9 (source purity) is the CI lint rule `forbidden:run_state_core_purity` with its fixtures.
extends GutTest

const Factory = preload("res://tests/support/run_state_factory.gd")
const ClockStub = preload("res://tests/support/clock_stub.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const EXPECTED_SIGNALS: Array[String] = [
	"phase_changed",
	"restart_unlocked",
	"run_abandoned",
	"run_ended",
	"run_paused",
	"run_reset",
	"run_resumed",
	"run_resuming",
	"run_started",
]


func _new_core() -> RunStateCore:
	var clock: ClockStub = ClockStub.new(Factory.START_US)
	var logs: LogSink = LogSink.new()
	return RunStateCore.new(RunConfig.new(), clock.as_callable(), logs.sink)


func test_signal_list_is_exactly_the_nine_events() -> void:
	var core: RunStateCore = _new_core()
	var script: Script = core.get_script() as Script
	var names: Array[String] = []
	for entry: Dictionary in script.get_script_signal_list():
		names.append(entry["name"] as String)
	names.sort()
	assert_eq(names, EXPECTED_SIGNALS)


func test_signal_arguments_are_all_int_typed() -> void:
	var core: RunStateCore = _new_core()
	var script: Script = core.get_script() as Script
	var checked: int = 0
	for entry: Dictionary in script.get_script_signal_list():
		for arg: Dictionary in entry["args"]:
			assert_eq(arg["type"], TYPE_INT, "%s.%s must report TYPE_INT" % [entry["name"], arg["name"]])
			checked += 1
	assert_eq(checked, 13, "run_reset, run_started, run_paused, run_resuming, run_resumed, restart_unlocked: 1 each; "
		+ "run_abandoned and phase_changed: 2 each; run_ended: 3")


func test_enum_typed_arguments_report_type_int() -> void:
	var core: RunStateCore = _new_core()
	var script: Script = core.get_script() as Script
	var found: Dictionary = {}
	for entry: Dictionary in script.get_script_signal_list():
		if entry["name"] == "run_paused" or entry["name"] == "phase_changed":
			found[entry["name"]] = (entry["args"] as Array)[0]["type"]
	assert_eq(found.get("run_paused"), TYPE_INT)
	assert_eq(found.get("phase_changed"), TYPE_INT)


func test_core_is_ref_counted_and_not_a_node() -> void:
	var core: RunStateCore = _new_core()
	var as_object: Object = core
	assert_true(as_object is RefCounted)
	assert_false(as_object is Node)


func test_new_instance_is_boot_with_run_id_zero() -> void:
	var core: RunStateCore = _new_core()
	assert_eq(core.phase, RunStateCore.Phase.BOOT)
	assert_eq(core.run_id, 0)
	assert_eq(core.run_time, 0.0)


func test_phase_enum_has_six_values_and_starts_at_boot() -> void:
	assert_eq(RunStateCore.Phase.size(), 6)
	assert_eq(RunStateCore.Phase.BOOT, 0)


func test_two_instances_share_no_state() -> void:
	var rig_a: Factory = Factory.new()
	var rig_b: Factory = Factory.new()
	rig_a.core_in(Factory.State.RUNNING)
	assert_eq(rig_a.core.phase, RunStateCore.Phase.RUNNING)
	assert_eq(rig_a.core.run_id, 1)
	assert_eq(rig_b.core.phase, RunStateCore.Phase.BOOT)
	assert_eq(rig_b.core.run_id, 0)
	assert_eq(rig_b.recorder.events.size(), 0)


func test_construction_emits_no_signal_and_logs_nothing() -> void:
	var rig: Factory = Factory.new()
	assert_eq(rig.recorder.events.size(), 0)
	assert_eq(rig.logs.count(), 0)
