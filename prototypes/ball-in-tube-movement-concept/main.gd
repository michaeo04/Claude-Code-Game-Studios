# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does a follow-camera that orbits with the ball's angular position
# around the OUTSIDE of a tube, without rolling, keep obstacle dodging
# readable and feel physical?
# Date: 2026-09-14
extends Node3D

const TUBE_RADIUS := 3.0
const TUBE_VISUAL_LENGTH := 160.0
const LOOP_LENGTH := 140.0
const FORWARD_SPEED := 6.0
const ANGULAR_SPEED := 3.0
const BALL_RADIUS := 0.4
const CAMERA_BACK_DISTANCE := 6.0
const CAMERA_RADIUS_OFFSET := 3.0
const CAMERA_LOOK_AHEAD := 12.0
const CAMERA_FOLLOW_SPEED := 3.0 # lower = camera lags more behind the ball's angle
const HIT_FLASH_DURATION := 0.6

var theta := 0.0
var cam_theta := 0.0
var z := 0.0
var hit_flash_time := 0.0
var hit_count := 0

var ball: MeshInstance3D
var ball_material: StandardMaterial3D
var cam: Camera3D
var label: Label

var obstacles := [
	{"theta": 0.0, "z": 20.0, "half_theta": 0.35, "half_z": 1.2},
	{"theta": PI, "z": 40.0, "half_theta": 0.35, "half_z": 1.2},
	{"theta": PI / 2.0, "z": 60.0, "half_theta": 0.35, "half_z": 1.2},
	{"theta": -PI / 2.0, "z": 80.0, "half_theta": 0.35, "half_z": 1.2},
	{"theta": PI / 4.0, "z": 100.0, "half_theta": 0.35, "half_z": 1.2},
	{"theta": -PI / 4.0, "z": 120.0, "half_theta": 0.35, "half_z": 1.2},
]

func _ready() -> void:
	_build_tube()
	_build_obstacles()
	_build_ball()
	_build_camera()
	_build_ui()

func _build_tube() -> void:
	var tube := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = TUBE_RADIUS
	mesh.bottom_radius = TUBE_RADIUS
	mesh.height = TUBE_VISUAL_LENGTH
	mesh.radial_segments = 24
	tube.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.38, 0.42)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tube.material_override = mat
	# CylinderMesh height axis is local Y; rotate 90 deg around X so the
	# tube's length axis aligns with world Z (forward).
	tube.rotation.x = PI / 2.0
	tube.position = Vector3(0, 0, TUBE_VISUAL_LENGTH / 2.0)
	add_child(tube)

func _build_obstacles() -> void:
	for ob in obstacles:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.4, 1.0, 2.0 * ob["half_z"])
		box.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.15, 0.15)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box.material_override = mat
		box.position = _surface_position(ob["theta"], ob["z"], 0.5)
		add_child(box)

func _surface_position(t: float, zpos: float, extra_radius: float = 0.0) -> Vector3:
	var r := TUBE_RADIUS + extra_radius
	return Vector3(r * sin(t), r * cos(t), zpos)

func _build_ball() -> void:
	ball = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = BALL_RADIUS
	mesh.height = BALL_RADIUS * 2.0
	ball.mesh = mesh
	ball_material = StandardMaterial3D.new()
	ball_material.albedo_color = Color(1.0, 0.55, 0.1)
	ball_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball.material_override = ball_material
	add_child(ball)

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.current = true
	add_child(cam)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 22)
	layer.add_child(label)
	add_child(layer)

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		theta += ANGULAR_SPEED * delta
	if Input.is_action_pressed("ui_right"):
		theta -= ANGULAR_SPEED * delta

	z += FORWARD_SPEED * delta
	if z > LOOP_LENGTH:
		z -= LOOP_LENGTH

	var ball_pos := _surface_position(theta, z, BALL_RADIUS)
	ball.position = ball_pos

	# Camera angle chases the ball's angle with a lag. The camera rolls with its
	# orbit (up = radial outward from the tube axis) and looks at the axis, so
	# the tube looks identical every frame (static, centered) while the ball
	# and obstacles travel around it.
	cam_theta += _angle_diff(theta, cam_theta) * (1.0 - exp(-CAMERA_FOLLOW_SPEED * delta))
	cam.position = _surface_position(cam_theta, z - CAMERA_BACK_DISTANCE, CAMERA_RADIUS_OFFSET)
	var radial_up := Vector3(sin(cam_theta), cos(cam_theta), 0.0)
	cam.look_at(Vector3(0.0, 0.0, z + CAMERA_LOOK_AHEAD), radial_up)

	_check_collisions()

	if hit_flash_time > 0.0:
		hit_flash_time -= delta
		ball_material.albedo_color = Color(1.0, 0.1, 0.1)
	else:
		ball_material.albedo_color = Color(1.0, 0.55, 0.1)

	label.text = "Left/Right arrows to dodge\nHits: %d" % hit_count

func _check_collisions() -> void:
	if hit_flash_time > 0.0:
		return
	for ob in obstacles:
		var dz: float = abs(z - ob["z"])
		if dz > ob["half_z"]:
			continue
		var dtheta: float = _angle_diff(theta, ob["theta"])
		if abs(dtheta) < ob["half_theta"]:
			_on_hit()
			return

func _angle_diff(a: float, b: float) -> float:
	var d: float = fmod(a - b, TAU)
	if d > PI:
		d -= TAU
	elif d < -PI:
		d += TAU
	return d

func _on_hit() -> void:
	hit_flash_time = HIT_FLASH_DURATION
	hit_count += 1
	z = 0.0
	theta = 0.0
	cam_theta = 0.0
	print("HIT — reset. Total hits: %d" % hit_count)
