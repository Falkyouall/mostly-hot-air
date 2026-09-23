extends Node3D
# The lone crew member. Moves in basket-local XZ; basket.gd owns collision
# circles and decides what the interact button means.

const SPEED := 3.3
const CARRY_SPEED := 2.8
const RADIUS := 0.28

var locked := false  # true while looking through the Fernrohr
var carry_anchor: Node3D

var _model: Node3D
var _walk_phase := 0.0
var _squash := 0.0
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	var jacket := _mat(Color(0.30, 0.50, 0.36))
	var skin := _mat(Color(0.96, 0.78, 0.64))
	var cap := _mat(Color(0.96, 0.96, 0.94))
	var boots := _mat(Color(0.30, 0.22, 0.18))

	var body := CapsuleMesh.new()
	body.radius = 0.2
	body.height = 0.56
	_part(body, jacket, Vector3(0.0, 0.40, 0.0))
	var feet := BoxMesh.new()
	feet.size = Vector3(0.3, 0.12, 0.26)
	_part(feet, boots, Vector3(0.0, 0.07, 0.0))
	var head := SphereMesh.new()
	head.radius = 0.21
	head.height = 0.42
	_part(head, skin, Vector3(0.0, 0.84, 0.0))
	var hat := SphereMesh.new()
	hat.radius = 0.235
	hat.height = 0.3
	_part(hat, cap, Vector3(0.0, 0.97, 0.0))
	var brim := CylinderMesh.new()
	brim.top_radius = 0.16
	brim.bottom_radius = 0.16
	brim.height = 0.04
	_part(brim, cap, Vector3(0.0, 0.93, -0.17))
	var hand := SphereMesh.new()
	hand.radius = 0.08
	hand.height = 0.16
	_arm_l = _part(hand, skin, Vector3(-0.27, 0.42, 0.0))
	_arm_r = _part(hand, skin, Vector3(0.27, 0.42, 0.0))

	carry_anchor = Node3D.new()
	carry_anchor.position = Vector3(0.0, 1.25, 0.0)
	_model.add_child(carry_anchor)


func wish_direction() -> Vector3:
	if locked:
		return Vector3.ZERO
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return Vector3(v.x, 0.0, v.y)


func step(delta: float, carrying: bool) -> void:
	var dir := wish_direction()
	position += dir * (CARRY_SPEED if carrying else SPEED) * delta
	if dir.length() > 0.1:
		# Model faces -Z by default (brim points forward).
		var target_yaw := atan2(-dir.x, -dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-14.0 * delta))
		_walk_phase += delta * 14.0
	else:
		_walk_phase = 0.0
	_squash = lerpf(_squash, 0.0, 1.0 - exp(-10.0 * delta))
	var bob := absf(sin(_walk_phase)) * 0.06
	_model.position.y = bob
	_model.scale = Vector3(1.0 + _squash * 0.25, 1.0 - _squash * 0.3, 1.0 + _squash * 0.25)
	var swing := sin(_walk_phase) * 0.12
	var hands_y := 1.08 if carrying else 0.42
	_arm_l.position = Vector3(-0.27, hands_y, -swing if not carrying else 0.0)
	_arm_r.position = Vector3(0.27, hands_y, swing if not carrying else 0.0)


func face_towards(local_target: Vector3, delta: float) -> void:
	var d := local_target - position
	if d.length() > 0.05:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-10.0 * delta))


func pop() -> void:
	_squash = 1.0


func _part(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_model.add_child(mi)
	return mi


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m
