## Story CR-004: TubeMath.local_point and the logical-frame reference (ADR-0013 VC-5).
extends GutTest

const Reference = preload("res://tests/support/tube_logical_frame.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const R: float = 3.0
const D: float = 2.0
const CAMERA_RADIUS: float = 4.5
const CAMERA_BACK_DISTANCE: float = 6.0
const CAMERA_LOOK_AHEAD: float = 10.0
const TOL_9: float = 1e-9
const S_BALL: float = 1200.5
const PHI_CAM: float = 0.7


func test_local_point_matches_reference_on_fixture_table() -> void:
	for theta: float in [0.0, PI / 2.0, PI, -PI / 2.0, TAU]:
		for h: float in [0.0, D / 2.0, CAMERA_RADIUS - R, -0.5]:
			var p: Vector3 = Reference.logical_p(theta, 17.0, h, R)
			var q: Vector2 = TubeMath.local_point(theta, h, R)
			assert_almost_eq(q.x, p.x, TOL_9)
			assert_almost_eq(q.y, p.y, TOL_9)


func test_local_point_theta_zero_is_top_of_tube() -> void:
	var q: Vector2 = TubeMath.local_point(0.0, 0.0, R)
	assert_almost_eq(q.x, 0.0, TOL_9)
	assert_almost_eq(q.y, R, TOL_9)


func test_camera_eye_matches_reference_shifted_by_origin() -> void:
	for origin: float in [0.0, 1008.0]:
		var frame: WorldFrame = WorldFrame.new(WorldFrameConfig.new(), WorldGeometry.new(R, D, 20, 12.0, 9))
		frame.origin_s = origin
		var xy: Vector2 = TubeMath.local_point(PHI_CAM, CAMERA_RADIUS - R, R)
		var eye: Vector3 = Vector3(xy.x, xy.y, frame.render_z(S_BALL) + CAMERA_BACK_DISTANCE)
		var ref: Vector3 = Reference.logical_p(PHI_CAM, S_BALL - CAMERA_BACK_DISTANCE, CAMERA_RADIUS - R, R)
		assert_almost_eq(eye.x, ref.x, TOL_9)
		assert_almost_eq(eye.y, ref.y, TOL_9)
		assert_almost_eq(eye.z, ref.z + origin, TOL_9)


func test_camera_look_at_on_axis_matches_reference_shifted_by_origin() -> void:
	for origin: float in [0.0, 1008.0]:
		var frame: WorldFrame = WorldFrame.new(WorldFrameConfig.new(), WorldGeometry.new(R, D, 20, 12.0, 9))
		frame.origin_s = origin
		var look: Vector3 = Vector3(0.0, 0.0, frame.render_z(S_BALL) - CAMERA_LOOK_AHEAD)
		var ref: Vector3 = Reference.logical_p(0.0, S_BALL + CAMERA_LOOK_AHEAD, -R, R)
		assert_almost_eq(look.x, ref.x, TOL_9)
		assert_almost_eq(look.y, ref.y, TOL_9)
		assert_almost_eq(look.z, ref.z + origin, TOL_9)


func test_non_finite_theta_or_h_returns_zero_and_logs_once_each() -> void:
	for pair: Array in [[NAN, 0.0], [INF, 0.0], [0.0, NAN], [0.0, -INF]]:
		var sink: RefCounted = LogSink.new()
		var q: Vector2 = TubeMath.local_point(pair[0], pair[1], R, sink.sink)
		assert_eq(q, Vector2.ZERO)
		assert_eq(sink.count(), 1)
		assert_eq(sink.entries[0][1], TubeMath.NON_FINITE_INPUT)


func test_non_finite_without_sink_returns_zero() -> void:
	assert_eq(TubeMath.local_point(NAN, 0.0, R), Vector2.ZERO)


func test_finite_input_logs_nothing() -> void:
	var sink: RefCounted = LogSink.new()
	TubeMath.local_point(1.0, 0.0, R, sink.sink)
	assert_eq(sink.count(), 0)


func test_no_tube_math_method_returns_vector3() -> void:
	var script: Script = load("res://src/core/tube_track/tube_math.gd")
	var methods: Array[Dictionary] = script.get_script_method_list()
	assert_gt(methods.size(), 0)
	for m: Dictionary in methods:
		assert_ne(m["return"]["type"], TYPE_VECTOR3, "%s returns Vector3" % m["name"])
