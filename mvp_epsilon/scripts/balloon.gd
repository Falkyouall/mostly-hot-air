class_name Balloon
extends Node3D
## M2-E6 — the balloon as a unit: drifts with wind, lifts under Brenner, runs
## on a single fuel pool, dies to ground-contact-without-fuel or hull damage.
##
## FRAMES OF REFERENCE — the one thing this file has to get right.
##
##   Balloon (this node)   world position. NEVER rotates.
##   ├─ Envelope           the mass that actually holds the sky up
##   └─ Swing              pivots at the envelope centre. THIS is what leans.
##      └─ Basket          hangs SWING_ARM below the pivot → swings on an arc
##         └─ Players      basket-local XZ; their feet ARE the floor plane
##
## Two things fall out of this, and both are load-bearing:
##
## 1. The root never rotates, so balloon-local XZ == world XZ. Wind, drift and
##    nudges need no basis conversion anywhere in this file.
## 2. Avatars are basket children, so they inherit the lean for free: at any
##    altitude and any angle their feet sit exactly on the floor. player.gd
##    never touches world space — see its header.

signal fuel_changed(current: float, maximum: float)
signal hull_changed(hits_remaining: int)
signal nudge_used(remaining_cooldown: float)
signal ballast_dropped(remaining: int)
signal run_won
signal run_lost(reason: StringName)

# --- Vertical physics (m/s) — tuned in mvp_delta ---
const ACTIVE_RISE := 14.0
const PASSIVE_SINK := 8.0
# Two-speed burner ramp implements "winding up the balloon":
# • UP is fast (you commit to burning), DOWN is slow (banked energy you can
#   spend steering after leaving the central Brenner station).
const BURNER_RAMP_UP := 0.4
const BURNER_RAMP_DOWN := 2.5
const NUDGE_VELOCITY := 22.0
const NUDGE_DURATION := 0.45
const NUDGE_COOLDOWN := 3.5       # H2_DESIGN §5.3 — slower than delta on purpose
const HIT_DEBOUNCE := 1.0         # i-frames after a mountain hit

# --- Weight-Is-The-Wheel steering ---
# Where avatars stand in the basket steers the balloon. The COM (basket-local)
# pushes the balloon horizontally, scaled by burner_power: burner = the energy
# the steering spends. No burner, no steering.
const STEER_GAIN := 4.0

# --- Pendulum swing ---
# The basket hangs under the envelope and swings beneath it. Unlike the
# steering force, the swing is NOT gated on the burner: gravity is always on,
# so weight always tips the basket. That is what keeps a slope under the
# avatars' feet even while coasting — see player.gd `_slope_accel`.
const SWING_ARM := 11.0                 # pivot height = envelope centre
const SWING_RAD_PER_M := 0.16           # COM offset → rest angle
const MAX_SWING_RAD := deg_to_rad(18.0)
const SWING_STIFFNESS := 9.0            # spring k
const SWING_DAMPING := 3.0              # c — under 2·√k (= 6), so it overshoots
const SWING_KICK_NUDGE := 1.6           # rad/s impulse when the Ruder fires
const SWING_KICK_BALLAST := 1.2         # rad/s lurch when a bag leaves

# --- Resources ---
const FUEL_MAX := 100.0
const FUEL_BURN_RATE := 3.0       # units/sec while burner held
const HULL_MAX := 3
const BALLAST_MAX := 3
const BALLAST_BOOST := 18.0       # m/s instant vertical kick

@export var level: Level

@onready var swing: Node3D = $Swing
@onready var basket: Node3D = $Swing/Basket
@onready var envelope: MeshInstance3D = $Envelope
@onready var burner_flame: MeshInstance3D = $Swing/Basket/BurnerFlame
@onready var brenner: Station = $Swing/Basket/Stations/Station_Brenner
@onready var ruder: Station = $Swing/Basket/Stations/Station_Ruder
@onready var ballast: Station = $Swing/Basket/Stations/Station_Ballast

var velocity: Vector3 = Vector3.ZERO
var burner_power: float = 0.0
var fuel: float = FUEL_MAX
var hull_hits: int = HULL_MAX
var ballast_remaining: int = BALLAST_MAX

var _nudge_active: float = 0.0
var _nudge_cooldown: float = 0.0
var _nudge_dir: Vector3 = Vector3.ZERO
var _hit_cooldown: float = 0.0
var _swing: Vector2 = Vector2.ZERO       # Swing node's (rotation.x, rotation.z)
var _swing_vel: Vector2 = Vector2.ZERO
var _finished: bool = false


func _ready() -> void:
	add_to_group(&"balloon")
	# Subscribe to functional stations.
	if ruder is StationRuder:
		(ruder as StationRuder).nudge_requested.connect(_on_nudge_requested)
	if ballast is StationBallast:
		(ballast as StationBallast).ballast_requested.connect(_on_ballast_requested)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_update_burner(delta)
	_update_fuel(delta)
	_update_timers(delta)
	# COM is read once and shared: the same weight vector drives both the
	# steering force and the lean, so they can never disagree.
	var com := _compute_basket_com()
	_update_wind_drift(com, delta)
	_update_swing(com, delta)
	_update_vertical(delta)
	_apply_motion(delta)
	_update_visuals()
	_check_outcomes()


func _update_burner(delta: float) -> void:
	var want_burn := false
	if brenner is StationBrenner and (brenner as StationBrenner).is_burning() and fuel > 0.0:
		want_burn = true
	var ramp := BURNER_RAMP_UP if want_burn else BURNER_RAMP_DOWN
	var target := 1.0 if want_burn else 0.0
	burner_power = move_toward(burner_power, target, delta / ramp)


func _update_fuel(delta: float) -> void:
	if burner_power > 0.0 and fuel > 0.0:
		fuel = maxf(0.0, fuel - FUEL_BURN_RATE * burner_power * delta)
		fuel_changed.emit(fuel, FUEL_MAX)


func _update_timers(delta: float) -> void:
	_nudge_cooldown = maxf(0.0, _nudge_cooldown - delta)
	_nudge_active = maxf(0.0, _nudge_active - delta)
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)


func _update_wind_drift(com: Vector3, delta: float) -> void:
	if level == null:
		return
	var wind := level.wind_at(global_position)
	# Steering = COM offset × burner energy. The burner provides the lift that
	# *makes* the lean translate into drift; no burner, no steering.
	var steer := Vector3(com.x, 0.0, com.z) * STEER_GAIN * burner_power
	var target_xz := wind + steer
	velocity.x = lerpf(velocity.x, target_xz.x, clampf(delta * 0.9, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target_xz.z, clampf(delta * 0.9, 0.0, 1.0))
	if _nudge_active > 0.0:
		velocity += _nudge_dir * NUDGE_VELOCITY


# Centre of mass in basket-local XZ. With one player and no ballast in the
# weight model yet, this is just the player's basket-local position. The
# central burner pillar blocks avatars from reaching exact (0, 0), so even
# "standing at the Brenner" leaves a residual COM — hence a standing lean, and
# hence a slope the avatar has to brace against just to keep burning.
func _compute_basket_com() -> Vector3:
	var com := Vector3.ZERO
	var n := 0.0
	for child in basket.get_children():
		if child is Player:
			com += Vector3(child.position.x, 0.0, child.position.z)
			n += 1.0
	if n > 0.01:
		com /= n
	return com


# The basket as a damped harmonic oscillator hanging off the envelope. A
# first-order lerp would ease to the target and stop dead; a spring overshoots
# and settles, so a weight shift lands with a lurch you can feel — and so the
# Ruder, the Ballast and a mountain strike can all kick it.
func _update_swing(com: Vector3, delta: float) -> void:
	# +Z heavy → tip forward around X. +X heavy → tip around -Z.
	var rest := Vector2(
		clampf(com.z * SWING_RAD_PER_M, -MAX_SWING_RAD, MAX_SWING_RAD),
		clampf(-com.x * SWING_RAD_PER_M, -MAX_SWING_RAD, MAX_SWING_RAD),
	)
	var accel := (rest - _swing) * SWING_STIFFNESS - _swing_vel * SWING_DAMPING
	_swing_vel += accel * delta
	_swing += _swing_vel * delta
	# Clamp the angle AND kill the velocity that drove it past the stop —
	# otherwise the spring keeps winding up against the clamp and snaps back
	# the moment the load eases.
	if absf(_swing.x) > MAX_SWING_RAD:
		_swing.x = signf(_swing.x) * MAX_SWING_RAD
		_swing_vel.x = 0.0
	if absf(_swing.y) > MAX_SWING_RAD:
		_swing.y = signf(_swing.y) * MAX_SWING_RAD
		_swing_vel.y = 0.0
	swing.rotation.x = _swing.x
	swing.rotation.z = _swing.y


func _update_vertical(delta: float) -> void:
	var target_y: float
	if burner_power > 0.0:
		target_y = lerpf(-PASSIVE_SINK, ACTIVE_RISE, burner_power)
	else:
		target_y = -PASSIVE_SINK
	velocity.y = lerpf(velocity.y, target_y, clampf(delta * 1.2, 0.0, 1.0))


func _apply_motion(delta: float) -> void:
	global_position += velocity * delta


func _update_visuals() -> void:
	burner_flame.visible = burner_power > 0.05
	burner_flame.scale = Vector3.ONE * lerpf(0.4, 1.2, burner_power)


func _check_outcomes() -> void:
	# Mountain collision: balloon's body intersects a peak.
	if level:
		var hit := level.mountain_hit(global_position)
		if not hit.is_empty():
			_take_hit()
	# Ground contact ends the run one way or the other.
	if global_position.y <= 0.0:
		_land()


func _take_hit() -> void:
	if _hit_cooldown > 0.0:
		return
	hull_hits -= 1
	hull_changed.emit(hull_hits)
	_hit_cooldown = HIT_DEBOUNCE
	# Bounce upward so the player can recover, and rattle the basket.
	velocity.y = maxf(velocity.y, 6.0)
	_swing_vel += Vector2(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	).normalized() * SWING_KICK_NUDGE
	if hull_hits <= 0:
		_lose(&"hull_destroyed")


func _land() -> void:
	global_position.y = 0.0
	velocity = Vector3.ZERO
	if level and level.is_in_goal(global_position):
		_win()
	else:
		_lose(&"crashed")


func _win() -> void:
	_finished = true
	run_won.emit()


func _lose(reason: StringName) -> void:
	_finished = true
	run_lost.emit(reason)


# --- Station callbacks ---

## `intent` is a WORLD-space XZ direction — the stick mapped through the same
## camera basis the avatar walks by, so one stick push means one thing whether
## you are walking or steering.
func _on_nudge_requested(intent: Vector3) -> void:
	if _finished or _nudge_active > 0.0 or _nudge_cooldown > 0.0:
		return
	# H2_DESIGN §5.3: the impulse is PERPENDICULAR to the local stream. The
	# stick only picks which side; you cannot shove up- or downstream. That
	# keeps the Ruder a stream-change tool instead of quietly becoming a
	# throttle that outruns the wind field.
	var flow := Vector2.RIGHT
	if level:
		var wind := level.wind_at(global_position)
		if Vector2(wind.x, wind.z).length() > 0.01:
			flow = Vector2(wind.x, wind.z).normalized()
	var perp := Vector2(-flow.y, flow.x)          # left of the flow
	if perp.dot(Vector2(intent.x, intent.z)) < 0.0:
		perp = -perp

	# The root never rotates, so this XZ is already world XZ.
	_nudge_dir = Vector3(perp.x, 0.0, perp.y)
	_nudge_active = NUDGE_DURATION
	_nudge_cooldown = NUDGE_COOLDOWN
	# The shove lands on the basket, not the envelope — so the basket swings.
	_swing_vel += Vector2(perp.y, -perp.x) * SWING_KICK_NUDGE
	nudge_used.emit(NUDGE_COOLDOWN)


func _on_ballast_requested() -> void:
	if _finished or ballast_remaining <= 0:
		return
	ballast_remaining -= 1
	velocity.y = maxf(velocity.y, 0.0) + BALLAST_BOOST
	# A bag leaving one side of the basket lurches it the other way.
	var at := Vector2(ballast.position.x, ballast.position.z)
	if at.length() > 0.01:
		at = at.normalized()
		_swing_vel += Vector2(-at.y, at.x) * SWING_KICK_BALLAST
	ballast_dropped.emit(ballast_remaining)


# --- Run lifecycle ---
func reset_run() -> void:
	if level == null:
		return
	global_position = level.START_POS
	velocity = Vector3.ZERO
	burner_power = 0.0
	fuel = FUEL_MAX
	hull_hits = HULL_MAX
	ballast_remaining = BALLAST_MAX
	_nudge_active = 0.0
	_nudge_cooldown = 0.0
	_hit_cooldown = 0.0
	_swing = Vector2.ZERO
	_swing_vel = Vector2.ZERO
	swing.rotation = Vector3.ZERO
	_finished = false
	fuel_changed.emit(fuel, FUEL_MAX)
	hull_changed.emit(hull_hits)
	ballast_dropped.emit(ballast_remaining)
