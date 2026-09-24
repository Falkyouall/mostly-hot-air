extends Node
# Balance probe, not a unit test. Flies a whole run at the balloon level
# (no walking) and prints the outcome, to check that a seed is winnable and the
# fuel budget is sane. A human loses time running between stations, which the
# bot approximates with BUSY_AFTER_ACTION — and while busy, nobody is at the
# Pilotenstand: the Pinne stays where it was and the wind has its say.
#
#   godot --headless --path mvp_zeta -- --bot --seed=3
#   ... --bot --bot-return   deliberately sails past the first village, then
#                            motors back west for it (what does a miss cost?)

const ParcelScript := preload("res://scripts/parcel.gd")
const BUSY_AFTER_ACTION := 3.0
# Making one parcel (scope, fetch ware, pack, chute, walk to the rail) as
# hands-off-the-burner time, done in short stints with burner breaks between.
const PARCEL_WORK := 11.0
const WORK_STINT := 3.0
const WORK_BREAK := 2.0
# Good play packs ahead (Ablage) as soon as the next order is known.
const PREP_DISTANCE := 600.0
const LOW_ALT := 32.0

var game: Node3D
var _busy := 0.0
var _elapsed := 0.0
var _burn_time := 0.0
var _best_aim := INF
var _parcel_airborne := 0.0
var _work_left := 0.0
var _break := 0.0
var _ready_parcel := {}  # finished parcel in hand, tagged with the village it is for
var _return_phase := "off"  # off → skipping → riding → done
var _motor_time: Array[float] = [0.0, 0.0, 0.0]  # seconds per throttle notch


func _ready() -> void:
	Engine.time_scale = 20.0
	Engine.max_physics_steps_per_frame = 40
	if OS.get_cmdline_user_args().has("--bot-return"):
		_return_phase = "skipping"
	game.balloon.bumped.connect(func(what: String) -> void:
		var b: Node3D = game.balloon
		print("  HIT %s at t=%d x=%d z=%d alt=%d vy=%.1f hull=%d gas=%d target=%s threat=%d" % [what, int(_elapsed), int(b.position.x), int(b.position.z), int(b.position.y), b.vy, b.hull, b.throttle, game.target_name(), int(game.threat_height)]))


func _physics_process(delta: float) -> void:
	if game.state == game.State.ENDED:
		var r: Dictionary = game.result
		print("BOT seed-result outcome=%s delivered=%d stars=%d score=%d time=%ds burn=%ds halbgas=%ds vollgas=%ds hull=%d fuel=%d kanister=%d return=%s first=%s" % [
			r.outcome, r.delivered, r.stars, r.score, int(_elapsed), int(_burn_time), int(_motor_time[1]), int(_motor_time[2]),
			game.balloon.hull, int(game.balloon.fuel), game.basket.stock["kanister"],
			_return_phase, game.world.villages[0].state])
		get_tree().quit()
		set_physics_process(false)
		return
	_elapsed += delta
	_busy = maxf(_busy - delta, 0.0)
	_parcel_airborne = maxf(_parcel_airborne - delta, 0.0)
	var b: Node3D = game.balloon
	var w: Node3D = game.world
	var target: Vector3 = game.target_position()
	var heading_home: bool = game.heading_home()

	# Fetch a canister before the tank runs dry, and not while sinking towards
	# the ground — the walk to the Kanister is burner-off time.
	if b.fuel < 30.0 and game.basket.stock["kanister"] > 0 and _busy <= 0.0 and (b.position.y > 24.0 or b.vy > 0.0):
		game.basket.stock["kanister"] -= 1
		b.refuel(game.basket.CANISTER_FUEL)
		_busy = BUSY_AFTER_ACTION

	for v in w.villages:
		if v.state == "open" and b.position.x > v.pos.x + w.PASS_DISTANCE and not v.has("logged"):
			v["logged"] = true
			print("  missed %s: village z=%d, balloon z=%d alt=%d  parcel=%s work_left=%.1f stock=%s chutes=%d" % [v.name, int(v.pos.z), int(b.position.z), int(b.position.y), _ready_parcel.get("for", "-"), _work_left, game.basket.stock, game.basket.chutes])
	var first: Dictionary = w.villages[0]
	if _return_phase == "skipping":
		# Sail past on purpose: aim well east of the first village.
		target = Vector3(first.pos.x + 400.0, 0.0, first.pos.z)
		if b.position.x > first.pos.x + w.PASS_DISTANCE:
			_return_phase = "riding"
	if _return_phase == "riding":
		target = first.pos
		if b.position.x < first.pos.x + 20.0:
			_return_phase = "done"
	var want := _wanted_altitude(b, w, target, heading_home)
	var lookahead: float = b.position.y + b.vy * 2.5
	b.burning = _busy <= 0.0 and lookahead < want - 2.0
	# Passive cooling tails off at low heat, so descents need the vent early.
	b.venting = _busy <= 0.0 and lookahead > want + 3.0
	if _busy <= 0.0:
		_steer(b, w, target, heading_home)
	if b.is_flame_on():
		_burn_time += delta
	_motor_time[b.throttle] += delta
	if OS.get_cmdline_user_args().has("--trace") and int(_elapsed * 60.0) % 180 == 0:
		print("  t=%d x=%d z=%d alt=%d want=%d gas=%d pinne=(%.1f,%.1f) threat=%d target=%s dz=%d fuel=%d busy=%.1f air=%.1f best=%.0f" % [int(_elapsed), int(b.position.x), int(b.position.z), int(b.position.y), int(want), b.throttle, b.thrust_dir.x, b.thrust_dir.y, int(game.threat_height), game.target_name(), int(target.z - b.position.z), int(b.fuel), _busy, _parcel_airborne, _best_aim])

	var may_drop := _return_phase == "off" or _return_phase == "done"
	if may_drop and not heading_home:
		_prepare_parcel(delta, b, want)
		if _busy <= 0.0 and _parcel_airborne <= 0.0 and _ready_parcel.get("for", "") == game.target_name():
			_maybe_drop(b, w, target)


# Pinne: point the ground track at the target, wind compensated. Vollgas only
# while clearly off the line or heading against the band; Halbgas otherwise.
func _steer(b: Node3D, w: Node3D, target: Vector3, heading_home: bool) -> void:
	var to := Vector2(target.x - b.position.x, target.z - b.position.z)
	var dist := to.length()
	if dist < 1.0:
		return
	var dir := to / dist
	# Rock ahead is cheaper to go round than over: bend the course away from
	# any cone in the corridor that is taller than we are.
	var avoid := _avoidance(b, w, dir)
	if avoid.length() > 0.01:
		dir = (dir + avoid).normalized()
	var wind: Vector3 = w.wind_at(b.position, true)
	var flat := Vector2(wind.x, wind.z)
	var along: float = flat.dot(dir)  # wind helping (+) or fighting (−)
	var perp: float = absf(flat.cross(dir))  # wind pushing off the line
	if heading_home and dist < w.GOAL_RADIUS * 0.8:
		b.throttle = 0
	elif along < 0.0 or perp > b.MOTOR_SPEED[1] * 0.8 or avoid.length() > 0.3:
		b.throttle = 2
	else:
		b.throttle = 1
	# Thrust so that thrust + wind runs along `dir`: k = along + sqrt(v² − perp²).
	# If the motor is weaker than the crosswind, it at least cancels what it can.
	var speed: float = b.MOTOR_SPEED[maxi(b.throttle, 1)]
	var k: float = along + sqrt(maxf(speed * speed - perp * perp, 0.0))
	var pinne := dir * k - flat
	b.thrust_dir = pinne.normalized() if pinne.length() > 0.1 else dir


func _avoidance(b: Node3D, w: Node3D, dir: Vector2) -> Vector2:
	var here := Vector2(b.position.x, b.position.z)
	var side_axis := dir.orthogonal()
	var avoid := Vector2.ZERO
	for c in w.cones:
		if c.height < b.position.y + 15.0:
			continue
		var rel: Vector2 = c.pos - here
		var ahead: float = rel.dot(dir)
		var side: float = rel.dot(side_axis)
		var margin: float = c.radius + 45.0
		if ahead < -c.radius or ahead > 350.0 or absf(side) > margin:
			continue
		var urgency: float = (1.0 - maxf(ahead, 0.0) / 350.0) * (1.0 - absf(side) / margin)
		avoid -= side_axis * signf(side if absf(side) > 1.0 else 1.0) * urgency * 1.5
	return avoid


func _wanted_altitude(b: Node3D, w: Node3D, target: Vector3, heading_home: bool) -> float:
	# With the motor doing the steering, every band change is burner fuel spent
	# for a few m/s of tailwind — it never pays over these distances. So: stay
	# low (short chute drift, chuteless drops), climb only for rock ahead.
	var want := LOW_ALT
	if heading_home:
		var dx: float = target.x - b.position.x
		var dz: float = target.z - b.position.z
		if dx < 300.0:
			# Never touch down outside the ring — that only shreds the hull.
			var floor_alt := 0.0 if Vector2(dx, dz).length() < w.GOAL_RADIUS * 0.85 else 18.0
			want = maxf((dx - 30.0) * 0.3, floor_alt)
	if game.threat_height > 1.0 and game.threat_height > want - 12.0:
		want = game.threat_height + 14.0
	return want


func _prepare_parcel(delta: float, b: Node3D, want: float) -> void:
	_break = maxf(_break - delta, 0.0)
	var v: Dictionary = game.target_village()
	var basket: Node3D = game.basket
	if _ready_parcel.get("for", "") == v.name:
		return
	if _work_left <= 0.0:
		if v.pos.x - b.position.x > PREP_DISTANCE or basket.stock[v.order] <= 0:
			return
		_work_left = PARCEL_WORK
	# Only step away from the burner while the altitude is roughly where it should be.
	# (The low/mid blend zone is only ±8 m — a sloppier gate loses the steering.)
	# And nobody packs parcels with a rock face coming up.
	if _busy > 0.0 or _break > 0.0 or absf(b.position.y - want) > 6.0 or absf(b.vy) > 3.5 or game.threat_height > 1.0:
		return
	var stint := minf(WORK_STINT, _work_left)
	_busy = stint
	_break = stint + WORK_BREAK
	_work_left -= stint
	if _work_left <= 0.0:
		basket.stock[v.order] -= 1
		var has_chute: bool = basket.chutes > 0
		basket.chutes -= 1 if has_chute else 0
		_ready_parcel = {"kind": "paket", "color": v.order, "chute": has_chute, "for": v.name}


func _maybe_drop(b: Node3D, w: Node3D, target: Vector3) -> void:
	var p: Vector3 = ParcelScript.predict_landing(w, b.position, _ready_parcel.chute)
	var miss := Vector2(p.x - target.x, p.z - target.z).length()
	# Drop at the closest approach, as long as it is inside the ring.
	if miss < _best_aim:
		_best_aim = miss
		return
	if _best_aim <= w.VILLAGE_RADIUS - 3.0:
		game.throw_item(_ready_parcel, Vector3(0.0, -1.0, 0.0))
		_ready_parcel = {}
		_busy = BUSY_AFTER_ACTION
		_parcel_airborne = 8.0
	if miss > _best_aim + 40.0 or _busy > 0.0:
		_best_aim = INF
