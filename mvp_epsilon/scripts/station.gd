class_name Station
extends Node3D
## M2-E5 — a rollenless station.
##
## Any Player may occupy it; the station does not know or care which "role"
## the occupant plays. Functional behaviour (Brenner, Fernrohr, Stoss-Ruder,
## Ballast) is layered on in M2-E6 and later — for E5 a station only tracks
## occupancy and shows it.

signal occupied(by: Player)
signal released(by: Player)

@export var station_name: StringName = &"Station"
@export var free_color: Color = Color(0.46, 0.40, 0.32)
@export var occupied_color: Color = Color(1.0, 0.72, 0.25)

@onready var _marker: MeshInstance3D = $Marker
@onready var _label: Label3D = $NameLabel

var _occupant: Player = null
var _material: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"stations")
	_label.text = String(station_name)
	_material = StandardMaterial3D.new()
	_marker.material_override = _material
	_refresh()


func is_free() -> bool:
	return _occupant == null


func try_occupy(by: Player) -> bool:
	if _occupant != null:
		return false
	_occupant = by
	_refresh()
	occupied.emit(by)
	return true


func release(by: Player) -> void:
	if _occupant != by:
		return
	_occupant = null
	_refresh()
	released.emit(by)


func _refresh() -> void:
	var taken := _occupant != null
	_material.albedo_color = occupied_color if taken else free_color
	_material.emission_enabled = taken
	_material.emission = occupied_color
	_material.emission_energy_multiplier = 0.7
