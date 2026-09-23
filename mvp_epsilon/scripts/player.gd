class_name Player
extends Node3D
## M2-E6 — avatar walking in the basket, occupying stations.
##
## Rollenless by design: this script never looks at *which* station it occupies.
## Specialisation is meant to emerge from spatial scarcity, not from code
## (H2_DESIGN §4.1).
##
## THE AVATAR NEVER TOUCHES WORLD SPACE.
##
## Its position is basket-local (x, 0, z) — `y` is pinned to zero, forever. The
## basket floor IS the local XZ plane, so the feet are planted on it by
## construction: at any altitude, at any lean, with no code. The balloon's world
## motion and the pendulum lean arrive purely as the parent transform.
##
## That is also why this is a plain Node3D and not a CharacterBody3D. A
## CharacterBody3D's `move_and_slide` is a *world-space* operation; used inside
## a rig that translates at 14 m/s and swings 18°, it fights the parent
## transform (feet drift off a leaning floor) and tunnels through a pillar that
## teleports 0.23 m between physics syncs. The basket interior is two circles —
## the burner pillar and the rim — so we resolve it analytically in 2D instead.
## It is both simpler and strictly more robust than the physics server here.
##
## The one thing the lean DOES do to the avatar is tilt the floor under it:
## `_slope_accel` pulls you downhill, and you have to brace. See `slide_speed`.

const PLAYER_COLORS: Array[Color] = [
	Color(0.95, 0.55, 0.20), # P1 orange
	Color(0.35, 0.65, 0.95), # P2 blue
	Color(0.55, 0.80, 0.40), # P3 green
	Color(0.90, 0.45, 0.75), # P4 pink
]

const BODY_RADIUS := 0.35
const PILLAR_RADIUS := 0.62      # central burner column, from basket.tscn
# Unrailed's avatars snap to the push direction almost instantly. TURN_RATE is
# high on purpose: at 60 Hz this covers ~90° in ~4 frames — reads as "instant"
# without the single-frame pop that looks robotic.
const TURN_RATE := 22.0
# Once occupying, you keep the station until you leave its radius plus this
# margin — a little hysteresis so brushing the zone's edge doesn't drop you.
const RETAIN_MARGIN := 0.25

## Top walking speed (m/s). Reached when accel and friction balance.
@export var speed: float = 4.0
## Viscous drag (1/s). Also sets how fast you stop, and the terminal slide.
@export var friction: float = 8.0
## Downhill drift (m/s) you settle at on a fully leaned floor, standing still.
## Kept well under `speed` on purpose: the lean is a tax on crossing the basket,
## never a loss of control — you can always out-walk your own slide. Set to 0.0
## to make the lean purely cosmetic.
@export var slide_speed: float = 1.3
## How much of the slide survives while you are gripping a station. Standing at
## a post means holding on; the brace is meant to bite during the *walk* between
## stations — that walk is the physical form of the triage (H2_DESIGN §8.3).
@export_range(0.0, 1.0) var station_brace: float = 0.15

## Assigned by the spawner (0..3). M2-E6 only ever spawns index 0.
var player_index: int = 0
## Inner radius of the rim, from basket.tscn. The body is kept inside it.
var basket_radius: float = 3.35

## Basket-local XZ velocity. There is no third component — the floor is a plane.
var local_velocity: Vector2 = Vector2.ZERO

@onready var _mesh: MeshInstance3D = $Mesh

var _occupied_station: Station = null
var _targeted_station: Station = null


func _ready() -> void:
	add_to_group(&"players")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLAYER_COLORS[player_index % PLAYER_COLORS.size()]
	_mesh.material_override = mat


func _physics_process(delta: float) -> void:
	_move(delta)
	_update_station()
	if Input.is_action_just_pressed("secondary") and _occupied_station != null:
		if _occupied_station.has_method("on_secondary"):
			_occupied_station.on_secondary(self)


func _move(delta: float) -> void:
	var wish := _wish_local()
	var accel := wish * (speed * friction) + _slope_accel()
	local_velocity += accel * delta
	# Viscous drag, not a constant brake: terminal speed = accel / friction, so
	# the same drag that stops you also caps the downhill slide at a value we
	# can state up front (`slide_speed`) instead of one that emerges by luck.
	local_velocity -= local_velocity * clampf(friction * delta, 0.0, 1.0)

	var next := _plane_pos() + local_velocity * delta
	next = _resolve(next)
	# y stays 0 — the feet are the floor. This is the whole alignment story.
	position = Vector3(next.x, 0.0, next.y)
	# Face where the stick points, not where velocity ends up — so a floor-slope
	# slide doesn't spin the avatar away from the way you're actually pushing.
	# Purely cosmetic: facing does NOT affect which tool you can use.
	_face(wish, delta)


## The stick in WORLD XZ, camera-relative — W is always "up on screen",
## whatever the camera is doing. The Stoss-Ruder reads this too, so the stick
## means the same thing whether you are walking or steering.
func world_wish_dir() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() < 0.01:
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var fwd := -cam.global_transform.basis.z
	var right := cam.global_transform.basis.x
	fwd.y = 0.0
	right.y = 0.0
	if fwd.length() < 0.001 or right.length() < 0.001:
		return Vector3.ZERO
	# input.y = -1 when W is held, so screen-forward = -input.y * fwd.
	var wish := fwd.normalized() * -input.y + right.normalized() * input.x
	return wish.limit_length(1.0)


# The stick, projected onto the (leaning) floor and expressed in basket-local
# XZ. Dropping the component normal to the floor is what makes "forward" mean
# forward *along the floor* rather than along the world horizontal — without
# this, walking on a leaning floor drifts you off it.
func _wish_local() -> Vector2:
	var wish := world_wish_dir()
	if wish.length() < 0.001:
		return Vector2.ZERO
	var local := _basket_basis().inverse() * wish
	var flat := Vector2(local.x, local.z)
	if flat.length() < 0.001:
		return Vector2.ZERO
	# Renormalise to the stick's magnitude: the projection shortens the vector
	# on a steep floor, and we don't want the lean to also slow you down.
	return flat.normalized() * wish.length()


# Downhill pull, in basket-local XZ. World-down expressed in basket space has
# an XZ component whose magnitude is exactly sin(lean) — so this is the true
# slope of the floor, and it goes to zero when the basket hangs level.
func _slope_accel() -> Vector2:
	var down_local := _basket_basis().inverse() * Vector3.DOWN
	var slope := Vector2(down_local.x, down_local.z)
	var gain := slide_speed * friction / sin(Balloon.MAX_SWING_RAD)
	if _occupied_station != null:
		gain *= station_brace
	return slope * gain


func _basket_basis() -> Basis:
	var parent := get_parent_node_3d()
	if parent == null:
		return Basis.IDENTITY
	return parent.global_transform.basis.orthonormalized()


func _plane_pos() -> Vector2:
	return Vector2(position.x, position.z)


# The basket interior, resolved analytically: push out of the central pillar,
# clamp inside the rim, and separate from the other avatars. Each contact kills
# only the velocity going *into* the surface, so you slide along the pillar and
# walk around it — which is exactly the walk-around cost H2_DESIGN §8.3 asks
# the central element to impose.
func _resolve(p: Vector2) -> Vector2:
	var pillar := PILLAR_RADIUS + BODY_RADIUS
	if p.length() < pillar:
		# Degenerate only if something spawned dead-centre inside the column.
		var out := p.normalized() if p.length() > 0.001 else Vector2.RIGHT
		p = out * pillar
		_cancel_into(out)

	var rim := basket_radius - BODY_RADIUS
	if p.length() > rim:
		var inward := -p.normalized()
		p = -inward * rim
		_cancel_into(inward)

	for other in get_parent().get_children():
		if other == self or not (other is Player):
			continue
		var away := p - (other as Player)._plane_pos()
		var min_gap := BODY_RADIUS * 2.0
		if away.length() < min_gap:
			# Two avatars exactly co-located: shove apart along a per-index
			# axis so they never agree on a direction and lock.
			if away.length() < 0.001:
				away = Vector2.RIGHT.rotated(float(player_index))
			p = (other as Player)._plane_pos() + away.normalized() * min_gap
	return p


# Remove the part of the velocity heading into a surface, keeping the part
# running along it.
func _cancel_into(normal: Vector2) -> void:
	var into := local_velocity.dot(normal)
	if into < 0.0:
		local_velocity -= normal * into


func _face(wish: Vector2, delta: float) -> void:
	# No push → hold the last heading (Unrailed keeps facing when idle).
	if wish.length() < 0.15:
		return
	# Godot's forward is -Z, hence the negations.
	var yaw := atan2(-wish.x, -wish.y)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * TURN_RATE, 0.0, 1.0))


## Basket-local XZ unit vector the avatar's face points along — the look
## direction only (which way the visor points). It does NOT gate tool use;
## it's exposed so the facing behaviour can be asserted in tests.
func facing_local() -> Vector2:
	return Vector2(-sin(rotation.y), -cos(rotation.y))


func _update_station() -> void:
	# What could I grab right now? Recomputed every frame so the ring highlight
	# lights up the instant you step into a zone.
	var target := _target_station()
	_set_target(target if _occupied_station == null else null)

	if not Input.is_action_pressed("interact"):
		_release()
		return
	if _occupied_station != null:
		if not _in_range(_occupied_station):
			_release()
		return
	if target != null and target.try_occupy(self):
		_occupied_station = target
		_set_target(null)


func _release() -> void:
	if _occupied_station != null:
		_occupied_station.release(self)
		_occupied_station = null


## The nearest free station whose activation radius the avatar is standing
## inside. Range is the only condition — step into a tool's ring and it's
## usable, no matter which way you face. Range is the station's own drawn ring
## (no Area3D overlap), so what the player sees is exactly what the check uses.
func _target_station() -> Station:
	var best: Station = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(&"stations"):
		var station := node as Station
		if station == null or not station.is_free():
			continue
		var dist := _to_station(station).length()
		if dist > station.activation_radius:
			continue
		if dist < best_dist:
			best_dist = dist
			best = station
	return best


# Vector from the avatar to a station, in basket-local XZ (metres). The root
# doesn't rotate but the basket leans, so we project through the basket basis
# to measure distance in the floor plane, not the world plane.
func _to_station(station: Station) -> Vector2:
	var d3 := _basket_basis().inverse() * (station.global_position - global_position)
	return Vector2(d3.x, d3.z)


func _set_target(station: Station) -> void:
	if station == _targeted_station:
		return
	if _targeted_station != null:
		_targeted_station.set_targeted(false)
	_targeted_station = station
	if station != null:
		station.set_targeted(true)


# Retention range for an already-occupied station: its radius plus a small
# margin of hysteresis so brushing the zone's edge doesn't drop the post.
func _in_range(station: Station) -> bool:
	return _to_station(station).length() <= station.activation_radius + RETAIN_MARGIN
