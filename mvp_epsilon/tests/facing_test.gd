extends Node
## Headless check of station usability, which is RADIUS-ONLY:
##
##   A station is usable exactly when the avatar stands inside its activation
##   radius. Which way the avatar faces must NOT matter.
##
## Also checks the two supporting properties: the avatar's look direction tracks
## its yaw (cosmetic facing), and no two activation zones overlap.
##
## Run:  godot --path mvp_epsilon --headless res://tests/facing_test.tscn

var _failures := 0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame

	var balloon: Balloon = main.get_node("Balloon")
	var basket: Node3D = balloon.basket
	var player: Player = basket.get_node("Player")
	var ruder: Station = balloon.ruder     # basket-local +X ≈ 2.4

	# Look direction (cosmetic) must match the yaw the model is rotated to.
	player.rotation.y = 0.0
	_expect_vec("looks +local-Z at yaw 0", player.facing_local(), Vector2(0, -1))
	player.rotation.y = -PI / 2.0
	_expect_vec("looks +local-X at yaw -90°", player.facing_local(), Vector2(1, 0))

	# Non-interference: no two activation zones may overlap, or "which tool" is
	# ambiguous. Check every pair directly against the radii the rings are drawn
	# from — so this proves the property for whatever radii are configured.
	var stations := get_tree().get_nodes_in_group(&"stations")
	for i in stations.size():
		for j in range(i + 1, stations.size()):
			var a: Station = stations[i]
			var b: Station = stations[j]
			# HORIZONTAL gap — the rings live on the floor and activation is a
			# basket-plane test, so Y (the Brenner is up on the pillar) must not
			# count toward the separation.
			var da := a.global_position - b.global_position
			var gap := Vector2(da.x, da.z).length()
			var reach := a.activation_radius + b.activation_radius
			_expect("%s ↔ %s zones disjoint (gap %.2f > reach %.2f)" % [
				a.station_name, b.station_name, gap, reach], gap > reach)

	# Stand inside the Ruder's ring only (x = 2.0: 0.4 m from the Ruder, 2.0 m
	# from the Brenner — well outside every other zone). Position held fixed;
	# only orientation changes between the two probes.
	var spot := Vector3(2.0, 0.0, 0.0)
	for i in 4:                       # re-pin against the floor's slope drift
		player.position = spot
		player.local_velocity = Vector2.ZERO
		await get_tree().physics_frame
	player.position = spot

	# In the ring, facing straight at it → usable.
	player.rotation.y = -PI / 2.0
	_expect("in ring, facing toward → usable", player._target_station() == ruder)

	# Same spot, facing dead away → STILL usable. This is the whole point:
	# radius decides, orientation does not.
	player.rotation.y = PI / 2.0
	_expect("in ring, facing away → STILL usable", player._target_station() == ruder)

	# Step into the gap between the Brenner and Ruder rings → no zone at all,
	# regardless of facing.
	player.position = Vector3(1.2, 0.0, 0.0)
	player.rotation.y = -PI / 2.0
	_expect("between rings → nothing usable", player._target_station() == null)

	print("")
	if _failures > 0:
		print("FAIL — %d check(s) failed" % _failures)
	else:
		print("PASS — radius alone gates usability; facing is cosmetic")
	print("")
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(label: String, ok: bool) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1


func _expect_vec(label: String, got: Vector2, want: Vector2) -> void:
	_expect("%s  (got %.2v)" % [label, got], got.distance_to(want) < 0.01)
