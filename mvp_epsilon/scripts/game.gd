extends Node3D
## M2-E6 root — wires the level, balloon, camera, HUD and spawner together,
## owns the run lifecycle (start, reset, win/lose logging).

@onready var level: Level = $Level
@onready var balloon: Balloon = $Balloon
@onready var camera: Camera3D = $Camera3D
@onready var hud: CanvasLayer = $HUD
@onready var spawner: PlayerSpawner = $Balloon/Swing/Basket/PlayerSpawner


func _ready() -> void:
	balloon.level = level
	balloon.global_position = level.START_POS
	camera.follow = balloon
	camera.goal_position = level.GOAL_POS
	# Snap the camera's damped-Y to the balloon's start so frame 0 frames it.
	camera.snap_to_follow()
	hud.balloon = balloon
	hud.level = level
	# Refresh HUD now that balloon ref is set (its own _ready ran first).
	hud._on_fuel_changed(balloon.fuel, balloon.FUEL_MAX)
	hud._on_hull_changed(balloon.hull_hits)
	hud._on_ballast(balloon.ballast_remaining)

	var players := spawner.spawn()
	balloon.run_won.connect(_on_won)
	balloon.run_lost.connect(_on_lost)

	print("[M2-E6] Mostly Hot Air — MVP Epsilon")
	print("[M2-E6] Controls: WASD walks · hold Space/E at the central pillar to burn · WHERE you stand steers · F nudge/ballast · R reset")
	print("[M2-E6] spawned %d player(s); flight begins at %s, goal at %s" %
		[players.size(), level.START_POS, level.GOAL_POS])

	for station in get_tree().get_nodes_in_group(&"stations"):
		station.occupied.connect(_on_station_occupied.bind(station))
		station.released.connect(_on_station_released.bind(station))


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reset_run"):
		_reset()


func _reset() -> void:
	balloon.reset_run()
	hud.hide_banner()
	print("[M2-E6] run reset")


func _on_won() -> void:
	print("[M2-E6] WIN — landed in zone at %s" % balloon.global_position)


func _on_lost(reason: StringName) -> void:
	print("[M2-E6] LOSS (%s) at %s" % [reason, balloon.global_position])


func _on_station_occupied(by: Player, station: Station) -> void:
	print("[M2-E6] %s -> occupied by player %d" % [station.station_name, by.player_index])


func _on_station_released(by: Player, station: Station) -> void:
	print("[M2-E6] %s -> released by player %d" % [station.station_name, by.player_index])
