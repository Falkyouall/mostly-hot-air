extends Node3D
## M2-E5 root.
##
## Spawns the player(s) and logs occupy/release so the testable behaviour —
## "the avatar walks in the basket and occupies/leaves stations" — is
## observable from the console without a HUD yet.

@onready var _spawner: PlayerSpawner = $PlayerSpawner


func _ready() -> void:
	var players := _spawner.spawn(self)
	print("[M2-E5] Mostly Hot Air — MVP Epsilon")
	print("[M2-E5] Controls: WASD / arrows / left stick to move, hold Space / E / A to occupy a station.")
	print("[M2-E5] spawned %d player(s)" % players.size())

	for station in get_tree().get_nodes_in_group(&"stations"):
		station.occupied.connect(_on_station_occupied.bind(station))
		station.released.connect(_on_station_released.bind(station))


func _on_station_occupied(by: Player, station: Station) -> void:
	print("[M2-E5] %s  ->  occupied by player %d" % [station.station_name, by.player_index])


func _on_station_released(by: Player, station: Station) -> void:
	print("[M2-E5] %s  ->  released by player %d" % [station.station_name, by.player_index])
