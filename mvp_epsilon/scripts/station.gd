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
## Visual marker on top of the station. False for the Brenner, whose marker is
## the central pillar already; the floating box would just clip into it.
@export var show_marker: bool = true
## Radius (basket-plane metres) inside which an avatar may use this station.
## THE single source of truth: the usability check (Player._target_station) and
## the ring drawn on the floor both read this one number, so they can never
## disagree. Keep it under half the distance to the nearest station (2.4 m at
## the tightest, Brenner↔Ruder/Ballast) so no two activation zones overlap.
@export var activation_radius: float = 1.1

## Floor top in basket-local Y (basket.tscn: floor cylinder half-height). The
## ring is laid just above it.
const FLOOR_Y := 0.1

@onready var _marker: MeshInstance3D = $Marker
@onready var _label: Label3D = $NameLabel

var _ring_material: StandardMaterial3D

var _occupant: Player = null
## True while some avatar is standing inside this station's activation radius —
## i.e. a press right now would occupy it. Purely cosmetic; the bright ring is
## how the player sees that they're in a usable zone.
var _targeted: bool = false
var _material: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"stations")
	_label.text = String(station_name)
	_material = StandardMaterial3D.new()
	_marker.material_override = _material
	_marker.visible = show_marker
	_build_ring()
	_refresh()


# The activation zone, drawn as a thin flat ring on the floor. Built from
# activation_radius so it always matches the usability check exactly. It is a
# child of the station, so it rides the basket's pendulum lean and stays flush
# with the (tilting) floor.
func _build_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.02, activation_radius - 0.05)
	torus.outer_radius = activation_radius + 0.05
	var ring := MeshInstance3D.new()
	ring.name = "ActivationRing"
	ring.mesh = torus
	# Sit just above the floor. The station's own local Y varies (the Brenner
	# is up on the pillar), so subtract it to land the ring back on the floor.
	ring.position = Vector3(0.0, FLOOR_Y + 0.015 - position.y, 0.0)
	_ring_material = StandardMaterial3D.new()
	_ring_material.emission_enabled = true
	ring.material_override = _ring_material
	add_child(ring)


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


## Set by whichever avatar currently has this station in front of it and in
## range. Idempotent — cheap to call every frame.
func set_targeted(on: bool) -> void:
	if _targeted == on:
		return
	_targeted = on
	_refresh()


func _refresh() -> void:
	var taken := _occupant != null
	var hot := _targeted and not taken
	_material.albedo_color = occupied_color if taken else free_color
	# Emit when occupied (steady) or targeted (a "you can grab this" pre-glow).
	_material.emission_enabled = taken or hot
	_material.emission = occupied_color
	_material.emission_energy_multiplier = 0.7 if taken else 0.5
	# The Brenner shows no marker (its cue is the central pillar), so the label
	# is the fallback highlight that works for every station.
	_label.modulate = Color(1.0, 1.0, 0.55) if hot else Color(1.0, 1.0, 1.0)
	# Ring brightness reads as three states at a glance: faint = the zone is
	# there (plan your walk), bright = step in and you can use it right now,
	# mid = someone is on it.
	if _ring_material:
		_ring_material.albedo_color = occupied_color
		_ring_material.emission = occupied_color
		var energy := 0.18
		if hot:
			energy = 1.3
		elif taken:
			energy = 0.6
		_ring_material.emission_energy_multiplier = energy
