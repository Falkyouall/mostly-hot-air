class_name Player
extends CharacterBody3D
## M2-E5 — avatar that walks in the basket and occupies stations.
##
## Rollenless by design: this script never special-cases *which* station it
## occupies. Any player can take any station; specialisation is meant to
## emerge from spatial scarcity, not from code (H2_DESIGN §4.1).

const PLAYER_COLORS: Array[Color] = [
	Color(0.95, 0.55, 0.20), # P1 orange
	Color(0.35, 0.65, 0.95), # P2 blue
	Color(0.55, 0.80, 0.40), # P3 green
	Color(0.90, 0.45, 0.75), # P4 pink
]

@export var speed: float = 4.0
@export var acceleration: float = 22.0

## Assigned by the spawner (0..3). M2-E5 only ever spawns index 0.
var player_index: int = 0
## Basket bounds, supplied by the spawner — keeps the avatar on the floor.
var basket_center: Vector3 = Vector3.ZERO
var basket_radius: float = 3.0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _sensor: Area3D = $InteractionSensor

var _occupied_station: Station = null


func _ready() -> void:
	add_to_group(&"players")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLAYER_COLORS[player_index % PLAYER_COLORS.size()]
	_mesh.material_override = mat


func _physics_process(delta: float) -> void:
	_move(delta)
	_update_station()


func _move(delta: float) -> void:
	# Camera looks down -Z at 45°, so world XZ maps directly to screen.
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target := Vector3(input.x, 0.0, input.y) * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	velocity.y = 0.0
	move_and_slide()
	_clamp_to_basket()


func _clamp_to_basket() -> void:
	var offset := global_position - basket_center
	offset.y = 0.0
	if offset.length() > basket_radius:
		offset = offset.normalized() * basket_radius
		global_position.x = basket_center.x + offset.x
		global_position.z = basket_center.z + offset.z


func _update_station() -> void:
	if not Input.is_action_pressed("interact"):
		_release()
		return
	if _occupied_station != null:
		# Still holding — drop the station if we walked out of range.
		if not _in_range(_occupied_station):
			_release()
		return
	var station := _nearest_free_station()
	if station != null and station.try_occupy(self):
		_occupied_station = station


func _release() -> void:
	if _occupied_station != null:
		_occupied_station.release(self)
		_occupied_station = null


func _nearest_free_station() -> Station:
	var best: Station = null
	var best_dist := INF
	for area in _sensor.get_overlapping_areas():
		var station := area.get_parent() as Station
		if station == null or not station.is_free():
			continue
		var d := global_position.distance_squared_to(station.global_position)
		if d < best_dist:
			best_dist = d
			best = station
	return best


func _in_range(station: Station) -> bool:
	for area in _sensor.get_overlapping_areas():
		if area.get_parent() == station:
			return true
	return false
