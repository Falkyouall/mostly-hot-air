class_name PlayerSpawner
extends Node3D
## Spawns 1–4 players. M2-E5 runs with player_count = 1 (the solo test), but
## the spawn path is identical for 4 — going multiplayer is a config change,
## not a rewrite (H2_DESIGN §4.3).

@export var player_scene: PackedScene
@export_range(1, 4) var player_count: int = 1
@export var basket_center: Vector3 = Vector3.ZERO
@export var basket_radius: float = 3.0
## Radius of the ring the avatars spawn on.
@export var spawn_ring: float = 1.5


func spawn(into: Node) -> Array[Player]:
	var players: Array[Player] = []
	for i in player_count:
		var player := player_scene.instantiate() as Player
		player.player_index = i
		player.basket_center = basket_center
		player.basket_radius = basket_radius
		var angle := TAU * float(i) / float(player_count)
		player.position = basket_center + Vector3(
			cos(angle) * spawn_ring, 0.0, sin(angle) * spawn_ring)
		into.add_child(player)
		players.append(player)
	return players
