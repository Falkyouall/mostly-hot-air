extends Node3D
# Anything that goes over the railing. A parcel with a parachute floats down
# and drifts with the wind it falls through; everything else just drops —
# a parcel without a chute only survives that from tree-top height.

signal landed(item: Dictionary, pos: Vector3, drop_height: float)

const PARCEL_FALL := 16.0
const PARCEL_DRIFT := 0.7
const DEADWEIGHT_FALL := 45.0
const CHUTELESS_MAX_HEIGHT := 30.0

var world: Node3D
var item := {}
var _floating := false
var _chute: MeshInstance3D
var _age := 0.0
var _drop_height := 0.0


# Same integration as _physics_process, so the aim marker is exact.
static func predict_landing(w: Node3D, from: Vector3, with_chute: bool) -> Vector3:
	var p := from
	if with_chute:
		var step := 0.1
		while p.y > 0.0 and p.y > w.mountain_height(p.x, p.z):
			var wind: Vector3 = w.wind_at(p) * PARCEL_DRIFT
			p += Vector3(wind.x, -PARCEL_FALL, wind.z) * step
	p.y = 0.0
	return p


func setup(world_ref: Node3D, thrown_item: Dictionary, item_mesh: Node3D) -> void:
	world = world_ref
	item = thrown_item
	_floating = item.kind == "paket" and item.chute
	add_child(item_mesh)
	item_mesh.position = Vector3.ZERO
	item_mesh.scale = Vector3.ONE * 3.0  # readable from up high
	if not _floating:
		return
	var dome := SphereMesh.new()
	dome.radius = 3.2
	dome.height = 3.2
	dome.is_hemisphere = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.97, 0.93, 0.85)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_chute = MeshInstance3D.new()
	_chute.mesh = dome
	_chute.material_override = mat
	_chute.position = Vector3(0.0, 4.0, 0.0)
	_chute.scale = Vector3.ONE * 0.05
	add_child(_chute)


func _physics_process(delta: float) -> void:
	if _age == 0.0:
		_drop_height = position.y
	_age += delta
	if _floating:
		var wind: Vector3 = world.wind_at(position) * PARCEL_DRIFT
		position += Vector3(wind.x, -PARCEL_FALL, wind.z) * delta
		_chute.scale = Vector3.ONE * minf(_age * 3.0, 1.0)
		rotation.z = sin(_age * 3.0) * 0.15
	else:
		position.y -= DEADWEIGHT_FALL * delta
		rotation.x += delta * 4.0
	if position.y <= maxf(0.0, world.mountain_height(position.x, position.z)):
		landed.emit(item, position, _drop_height)
		queue_free()
