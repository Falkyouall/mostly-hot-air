class_name PlayerSpawner
extends Node3D
## Spawns 1–4 players inside a basket node. M2-E6 runs with player_count = 1
## (the solo test), but the same code path is used for 4 — multiplayer is a
## config change, not a rewrite (H2_DESIGN §4.3).

@export var player_scene: PackedScene
@export_range(1, 4) var player_count: int = 1
## Node the avatars are parented under. They walk in its local frame, so they
## move with whatever moves it (typically the basket inside a balloon).
@export var parent_path: NodePath
## Inner radius of the basket rim. Avatars are kept inside it, body included.
@export var basket_radius: float = 3.35
@export var spawn_ring: float = 1.5


func spawn() -> Array[Player]:
	var holder: Node = get_node(parent_path) if not parent_path.is_empty() else get_parent()
	var players: Array[Player] = []
	for i in player_count:
		var player := player_scene.instantiate() as Player
		player.player_index = i
		player.basket_radius = basket_radius
		var angle := TAU * float(i) / float(player_count)
		player.position = Vector3(cos(angle) * spawn_ring, 0.0, sin(angle) * spawn_ring)
		holder.add_child(player)
		players.append(player)
	return players
