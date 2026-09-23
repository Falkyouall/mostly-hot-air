extends Node
## Headless check of the one invariant the basket rig has to hold:
##
##   The avatar's feet lie exactly on the basket floor plane — at ANY altitude,
##   at ANY lean, including mid-swing while the pendulum is still moving.
##
## Run:  godot --path mvp_epsilon --headless res://tests/alignment_test.tscn
##
## It drives the real main scene (no mocks), parks the avatar off-centre so the
## basket leans to its stop, and samples every physics frame while the balloon
## climbs, sinks and swings.

const FRAMES := 400
const EPSILON := 0.001        # metres — this should be float noise, nothing more

var _max_plane_dist := 0.0    # |distance from the floor plane|  → must be ~0
var _max_local_y := 0.0       # |basket-local y|                 → must be ~0
var _max_lean := 0.0          # radians actually reached
var _min_alt := INF
var _max_alt := -INF
var _min_clear := INF         # closest approach to the pillar surface
var _max_reach := 0.0         # furthest the body edge got from centre
var _failures := 0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame

	var balloon: Balloon = main.get_node("Balloon")
	var basket: Node3D = balloon.basket
	var player: Player = basket.get_node("Player")

	# --- Phase A: extreme lean, sweeping altitude ---
	# Park the avatar hard off-centre: COM 2.5 m out drives the swing past its
	# 18° stop, so we sample the extreme, not a gentle lean.
	player.position = Vector3(2.5, 0.0, 0.0)

	for i in FRAMES:
		# Halfway through, kick the balloon upward to sweep a different
		# altitude band and confirm vertical motion doesn't disturb the feet.
		if i == FRAMES / 2:
			balloon.velocity.y = 20.0
		await get_tree().physics_frame
		_sample(balloon, basket, player)

	# --- Phase B: walk straight into the central pillar, from all sides ---
	# H2_DESIGN §8.3 makes the central element load-bearing: it must force paths
	# *around* the middle. The old CharacterBody3D tunnelled through it (the
	# pillar teleports 0.23 m between physics syncs at full climb). Drive the
	# avatar dead at it from 16 headings and prove it never gets inside.
	for i in FRAMES:
		var heading := TAU * float(i % 16) / 16.0
		var at := Vector2(cos(heading), sin(heading))
		if i % 25 == 0:
			player.position = Vector3(at.x * 2.0, 0.0, at.y * 2.0)
		# Hold the stick straight at the centre, hard.
		player.local_velocity = -Vector2(player.position.x, player.position.z).normalized() * 6.0
		await get_tree().physics_frame
		_sample(balloon, basket, player)

	_report(player)
	get_tree().quit(1 if _failures > 0 else 0)


func _sample(balloon: Balloon, basket: Node3D, player: Player) -> void:
	# THE invariant: the avatar sits on the basket's floor plane. Measured in
	# world space, through the full parent chain, so it catches any frame
	# mismatch between the balloon, the swing and the avatar.
	var up := basket.global_transform.basis.y
	var to_player := player.global_position - basket.global_position
	var plane_dist := absf(to_player.dot(up))
	_max_plane_dist = maxf(_max_plane_dist, plane_dist)
	if plane_dist > EPSILON:
		_failures += 1

	_max_local_y = maxf(_max_local_y, absf(player.position.y))
	if absf(player.position.y) > EPSILON:
		_failures += 1

	var lean := basket.global_transform.basis.y.angle_to(Vector3.UP)
	_max_lean = maxf(_max_lean, lean)
	_min_alt = minf(_min_alt, balloon.global_position.y)
	_max_alt = maxf(_max_alt, balloon.global_position.y)

	# Containment: never inside the pillar, never through the rim.
	var r := Vector2(player.position.x, player.position.z).length()
	var clearance := r - Player.BODY_RADIUS - Player.PILLAR_RADIUS
	var reach := r + Player.BODY_RADIUS
	_min_clear = minf(_min_clear, clearance)
	_max_reach = maxf(_max_reach, reach)
	if clearance < -EPSILON:
		_failures += 1
	if reach > player.basket_radius + EPSILON:
		_failures += 1


func _report(player: Player) -> void:
	print("")
	print("--- basket alignment ---------------------------------------------")
	print("  feet off floor plane   max %.6f m   (tol %.3f)" % [_max_plane_dist, EPSILON])
	print("  basket-local y         max %.6f m   (tol %.3f)" % [_max_local_y, EPSILON])
	print("--- conditions actually exercised --------------------------------")
	print("  lean reached           max %.2f°  (cap %.2f°)" % [
		rad_to_deg(_max_lean), rad_to_deg(Balloon.MAX_SWING_RAD)])
	print("  altitude swept         %.1f m → %.1f m" % [_min_alt, _max_alt])
	print("--- containment --------------------------------------------------")
	print("  clearance from pillar  min %+.3f m  (must be >= 0)" % _min_clear)
	print("  body edge from centre  max %.3f m   (rim at %.2f)" % [_max_reach, player.basket_radius])
	print("------------------------------------------------------------------")
	if _failures > 0:
		print("FAIL — %d sample(s) off the floor plane" % _failures)
	else:
		print("PASS — feet on the floor plane in all %d samples" % FRAMES)
	print("")
