class_name Mountain
extends Node3D
## Visual only — actual hit-detection lives in Level.mountain_hit() so the
## footprint maths is single-source-of-truth (mvp_delta principle).

@export var peak_height: float = 200.0:
	set(value):
		peak_height = value
		_rebuild()
@export var base_radius: float = 60.0:
	set(value):
		base_radius = value
		_rebuild()
@export var rock_color: Color = Color(0.49, 0.37, 0.23)


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var mesh := $Cone as MeshInstance3D
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = base_radius
	cm.height = peak_height
	mesh.mesh = cm
	mesh.position.y = peak_height * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = rock_color
	mat.roughness = 0.95
	mesh.material_override = mat
