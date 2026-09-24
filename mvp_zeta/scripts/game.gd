extends Node3D
# MVP Zeta — "Wolkenpost". Run orchestration: builds the scene in code, owns
# run state, scoring, camera and the glue between basket, balloon and world.
#
# Debug flags (after `--`):  --seed=N  --autostart  --bot  --playtest
#   --x=N --z=N --alt=N   start position      --village=I  start just west of village I
#   --carry=rot|blau|gelb start holding a finished parcel --scope      force the Fernrohr view
#   --finish=landed|crash|…                     jump straight to the result screen
#   --shot=/abs/file.png --shot-at=SECONDS      save a screenshot and quit

enum State { INTRO, FLYING, ENDED }

const WorldScript := preload("res://scripts/world.gd")
const BalloonScript := preload("res://scripts/balloon.gd")
const BasketScript := preload("res://scripts/basket.gd")
const ParcelScript := preload("res://scripts/parcel.gd")
const HudScript := preload("res://scripts/hud.gd")
const Wares := preload("res://scripts/wares.gd")

const START_ALTITUDE := 75.0
# Wide lens on purpose: the envelope has to loom into the top of the frame
# (moodboard 04) while the ground straight below stays visible for aiming.
const CAM_OFFSET := Vector3(0.0, 9.5, 7.5)
const CAM_AIM := Vector3(0.0, -2.0, -1.5)
const SCOPE_CAM := Vector3(0.0, 230.0, 160.0)
const SCOPE_HOLE := 140.0
const SIGHT_RANGE := 150.0
# The run only ends this far past the harbour — the Rückströmung can still
# carry an overshot balloon back.
const OVERSHOOT_DISTANCE := 380.0
const HARD_LANDING := 7.0
# Vorhalt: where the balloon will be in this many seconds at its current
# ground speed. The gap between it and the Pinne is the wind, made visible.
const LEAD_SECONDS := 10.0

var state := State.INTRO
var world: Node3D
var balloon: Node3D
var basket: Node3D
var camera: Camera3D
var hud: Control

var score := 0
var bullseyes := 0
var threat_height := 0.0
var toast_text := ""
var toast_age := 99.0
var result := {}  # filled by _finish()

var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _lead: MeshInstance3D
var _scope_t := 0.0
var _shake := 0.0
var _time := 0.0
var _args := {}


func _ready() -> void:
	_parse_args()
	_setup_input()
	_build_environment()

	world = WorldScript.new()
	add_child(world)
	world.build(int(_args.get("seed", randi() % 100000)))

	balloon = BalloonScript.new()
	balloon.world = world
	balloon.position = Vector3(float(_args.get("x", 0.0)), float(_args.get("alt", START_ALTITUDE)), float(_args.get("z", 0.0)))
	add_child(balloon)
	balloon.hull_changed.connect(_on_hull_changed)
	balloon.bumped.connect(_on_bumped)
	balloon.touched_down.connect(_on_touched_down)

	basket = BasketScript.new()
	basket.balloon = balloon
	balloon.visual.add_child(basket)
	basket.thrown.connect(_on_thrown)
	basket.note.connect(show_toast)

	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.3
	camera.far = 6000.0
	add_child(camera)
	camera.make_current()
	_build_marker()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.game = self
	layer.add_child(hud)

	if _args.has("village"):
		var v: Dictionary = world.villages[int(_args["village"])]
		balloon.position = Vector3(v.pos.x - 45.0, balloon.position.y, v.pos.z + 5.0)
	if _args.has("carry"):
		basket.debug_give({"kind": "paket", "color": _args["carry"], "chute": true})
	_update_camera(1.0)
	if _args.has("autostart") or _args.has("bot") or _args.has("playtest"):
		_start()
	if _args.has("finish"):
		_finish(_args["finish"])
	for driver in ["bot", "playtest"]:
		if _args.has(driver):
			var node: Node = load("res://tests/%s.gd" % driver).new()
			node.game = self
			add_child(node)


func _physics_process(delta: float) -> void:
	_time += delta
	toast_age += delta
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	match state:
		State.INTRO:
			if Input.is_action_just_pressed("interact"):
				_start()
		State.FLYING:
			_check_villages()
			_reveal_orders()
			_check_overshoot()
			threat_height = _scan_threat()
	Sfx.set_burner(state == State.FLYING and balloon.is_flame_on())
	Sfx.set_motor(balloon.motor_speed() / balloon.MOTOR_SPEED[2] if state == State.FLYING else 0.0)
	_update_marker()
	_update_lead()
	if _args.has("shot") and _time >= float(_args.get("shot-at", 2.0)):
		get_viewport().get_texture().get_image().save_png(_args["shot"])
		get_tree().quit()


func _process(delta: float) -> void:
	_update_camera(delta)


func show_toast(text: String) -> void:
	toast_text = text
	toast_age = 0.0


func target_position() -> Vector3:
	var v := target_village()
	return world.goal_pos if v.is_empty() else v.pos


func target_name() -> String:
	var v := target_village()
	return world.GOAL_NAME if v.is_empty() else v.name


func heading_home() -> bool:
	return target_village().is_empty()


func target_village() -> Dictionary:
	return world.target_village(balloon.position.x, balloon.velocity.x < -1.0)


func throw_item(item: Dictionary, local_pos: Vector3) -> void:
	_on_thrown(item, local_pos)


# --- Run flow -------------------------------------------------------------------

func _start() -> void:
	state = State.FLYING
	balloon.active = true
	basket.enabled = true
	show_toast("Erstes Ziel: %s" % target_name())


func _finish(outcome: String) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	balloon.active = false
	basket.enabled = false
	var delivered: int = world.delivered_count()
	var landed := outcome == "landed"
	var fuel_left: float = balloon.fuel + basket.stock["kanister"] * basket.CANISTER_FUEL
	if outcome != "crash":
		score += (200 if landed else 0) + balloon.hull * 30 + int(fuel_left * 0.5)
	var stars := 0
	if outcome != "crash":
		if delivered >= 3:
			stars = 1
		if delivered >= 4 and landed:
			stars = 2
		if delivered >= world.villages.size() and landed:
			stars = 3
	result = {"outcome": outcome, "delivered": delivered, "stars": stars, "score": score, "bullseyes": bullseyes}
	Sfx.play("win" if stars > 0 else "lose")


func _check_villages() -> void:
	for v in world.villages:
		if v.state == "open" and not v.has("warned") and balloon.position.x > v.pos.x + world.PASS_DISTANCE:
			v["warned"] = true
			show_toast("%s verpasst — ganz oben weht es zurück!" % v.name)
			Sfx.play("miss")


func _check_overshoot() -> void:
	if balloon.position.x > world.goal_pos.x + OVERSHOOT_DISTANCE:
		_finish("overshoot")


# Rock within the next ~24 s: a corridor along the ground track, not just the
# line — gusts and rotors bend the path, so the shoulders count too.
func _scan_threat() -> float:
	var worst := 0.0
	var flat := Vector3(balloon.velocity.x, 0.0, balloon.velocity.z)
	var side := Vector3(-flat.z, 0.0, flat.x).normalized() * 25.0
	for i in range(1, 13):
		for k in [-1.0, 0.0, 1.0]:
			var p: Vector3 = balloon.position + flat * (i * 2.0) + side * k
			worst = maxf(worst, world.mountain_height(p.x, p.z))
	return worst


func _on_touched_down(sink_speed: float) -> void:
	if state != State.FLYING:
		return
	var to_goal := Vector2(balloon.position.x - world.goal_pos.x, balloon.position.z - world.goal_pos.z).length()
	if to_goal <= world.GOAL_RADIUS:
		if sink_speed > HARD_LANDING:
			balloon.damage("ground")
		if balloon.hull > 0:
			_finish("landed")
		return
	var can_relight: bool = balloon.fuel > 0.0 or basket.stock["kanister"] > 0 or basket.carrying("kanister")
	if not can_relight:
		_finish("stranded")
		return
	balloon.damage("ground")
	balloon.bounce()


func _on_hull_changed(hull: int) -> void:
	if hull <= 0:
		_finish("crash")


func _on_bumped(what: String) -> void:
	_shake = 1.0
	Sfx.play("hit")
	show_toast("Felswand! Hülle beschädigt" if what == "mountain" else "Aufgesetzt! Hülle beschädigt")


func _on_thrown(item: Dictionary, local_pos: Vector3) -> void:
	var falling := ParcelScript.new()
	add_child(falling)
	falling.setup(world, item, BasketScript.make_item(item))
	falling.position = balloon.position + local_pos
	falling.landed.connect(_on_landed)
	match item.kind:
		"sack":
			balloon.drop_weight(balloon.LIFT_PER_SACK)
			show_toast("Ballast ab — der Ballon steigt!")
		"kanister":
			balloon.drop_weight(0.5)
			show_toast("Ups. Das war Brennstoff.")
		"schirm":
			show_toast("Da segelt er hin, der Fallschirm …")
		"ware":
			balloon.drop_weight(0.25)
			show_toast("Unverpackt über Bord — %s ist hin." % Wares.label(item.color))
		"paket":
			balloon.drop_weight(0.25)


func _on_landed(item: Dictionary, pos: Vector3, drop_height: float) -> void:
	if item.kind != "paket":
		return
	var best := {}
	var best_d := INF
	for v in world.villages:
		var d := Vector2(pos.x - v.pos.x, pos.z - v.pos.z).length()
		if v.state != "done" and d < best_d:
			best = v
			best_d = d
	var hit: bool = not best.is_empty() and best_d <= world.VILLAGE_RADIUS
	if not item.chute and drop_height > ParcelScript.CHUTELESS_MAX_HEIGHT:
		show_toast("Ohne Fallschirm aus %d m — zerschellt!" % int(drop_height))
		Sfx.play("miss")
	elif hit and item.color != best.order:
		best.known = true
		show_toast("Falsche Lieferung! %s wollte %s." % [best.name, Wares.label(best.order)])
		Sfx.play("miss")
	elif hit:
		world.mark_delivered(best)
		var bull: bool = best_d <= world.BULLSEYE_RADIUS
		score += 150 if bull else 100
		bullseyes += 1 if bull else 0
		show_toast(("VOLLTREFFER in %s! +150" if bull else "Zugestellt in %s! +100") % best.name)
		Sfx.play("bullseye" if bull else "deliver")
		_confetti(pos)
	elif pos.y > 1.0:
		show_toast("Paket am Berg zerschellt")
		Sfx.play("miss")
	elif world.is_water(pos.x, pos.z):
		show_toast("Platsch! Paket versenkt")
		Sfx.play("miss")
	else:
		show_toast("Daneben! %d m am Ziel vorbei" % int(best_d - world.VILLAGE_RADIUS) if best_d < 200.0 else "Paket im Nirgendwo gelandet")
		Sfx.play("miss")


# A village's order becomes known once the crew has actually seen its colours:
# through the Fernrohr's cloud hole, or up close from below the cloud deck.
func _reveal_orders() -> void:
	var b: Vector3 = balloon.position
	var scope_spot: Vector2 = Vector2(b.x, b.z) + basket.scope_offset
	for v in world.villages:
		if v.known:
			continue
		var flat := Vector2(v.pos.x, v.pos.z)
		var by_scope: bool = _scope_t > 0.8 and flat.distance_to(scope_spot) < SCOPE_HOLE * 0.85
		var by_eye: bool = b.y < world.CLOUD_Y_MIN - 10.0 and flat.distance_to(Vector2(b.x, b.z)) < SIGHT_RANGE
		if by_scope or by_eye:
			v.known = true
			if v.state == "open":
				show_toast("%s will %s!" % [v.name, Wares.label(v.order)])
				Sfx.play("pickup")


# --- Camera, marker, effects --------------------------------------------------------

func _update_camera(delta: float) -> void:
	var scoping: bool = basket.scope_active or _args.has("scope")
	_scope_t = move_toward(_scope_t, 1.0 if scoping else 0.0, delta * 2.2)
	_shake = maxf(_shake - delta * 2.0, 0.0)
	var t := smoothstep(0.0, 1.0, _scope_t)
	var b: Vector3 = balloon.position
	var g := Vector3(b.x + basket.scope_offset.x, 0.0, b.z + basket.scope_offset.y)
	var pos := (b + CAM_OFFSET).lerp(g + SCOPE_CAM, t)
	var look := (b + CAM_AIM).lerp(g, t)
	pos += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * _shake * 0.5
	camera.position = pos
	camera.look_at(look)
	world.set_cloud_focus(b)
	world.set_cloud_hole(Vector2(g.x, g.z), Vector2(0.0, SCOPE_CAM.z / SCOPE_CAM.y), SCOPE_HOLE * t)


func _update_marker() -> void:
	_marker.visible = state == State.FLYING and basket.carrying("paket")
	if not _marker.visible:
		return
	var p: Vector3 = ParcelScript.predict_landing(world, balloon.position, basket.carried.chute)
	var on_target := false
	for v in world.villages:
		if v.state != "done" and Vector2(p.x - v.pos.x, p.z - v.pos.z).length() <= world.VILLAGE_RADIUS:
			on_target = true
	var pulse := 1.0 + 0.12 * sin(_time * (14.0 if on_target else 5.0))
	_marker.position = p + Vector3(0.0, 1.2, 0.0)
	_marker.scale = Vector3(1.0, 0.05, 1.0) * (1.0 + balloon.position.y / 50.0) * pulse
	var too_high: bool = not basket.carried.chute and balloon.position.y > ParcelScript.CHUTELESS_MAX_HEIGHT
	_marker_mat.albedo_color = Color(0.3, 1.0, 0.35) if on_target else Color(1.0, 0.35, 0.2)
	if too_high:
		_marker_mat.albedo_color = Color(0.35, 0.35, 0.4)


func lead_position() -> Vector3:
	var b: Vector3 = balloon.position
	var p := b + Vector3(balloon.velocity.x, 0.0, balloon.velocity.z) * LEAD_SECONDS
	p.y = maxf(0.0, world.mountain_height(p.x, p.z)) + 1.0
	return p


func _update_lead() -> void:
	_lead.visible = state == State.FLYING and not basket.scope_active
	if not _lead.visible:
		return
	_lead.position = lead_position()
	_lead.scale = Vector3(1.0, 0.05, 1.0) * (0.6 + balloon.position.y / 80.0)


func _build_marker() -> void:
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := TorusMesh.new()
	ring.inner_radius = 3.4
	ring.outer_radius = 4.6
	ring.rings = 32
	ring.ring_segments = 6
	_marker = MeshInstance3D.new()
	_marker.mesh = ring
	_marker.material_override = _marker_mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)

	var lead_mat := StandardMaterial3D.new()
	lead_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lead_mat.albedo_color = Color(0.85, 0.93, 1.0, 0.8)
	lead_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var disc := CylinderMesh.new()
	disc.top_radius = 2.2
	disc.bottom_radius = 2.2
	disc.height = 1.0
	_lead = MeshInstance3D.new()
	_lead.mesh = disc
	_lead.material_override = lead_mat
	_lead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lead.visible = false
	add_child(_lead)


func _confetti(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 90
	p.lifetime = 2.2
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector3(0.0, -30.0, 0.0)
	var quad := BoxMesh.new()
	quad.size = Vector3(1.6, 1.6, 0.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.mesh = quad
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.2), Color(0.3, 0.9, 0.5), Color(0.3, 0.6, 1.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	p.color_initial_ramp = ramp
	p.position = at + Vector3(0.0, 2.0, 0.0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(4.0).timeout.connect(p.queue_free)


# --- Setup -------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.80, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.78, 0.92)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.80, 0.92)
	env.fog_density = 0.0005
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.86)
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 420.0
	add_child(sun)


# Twin-stick at the Pilotenstand: left stick / WASD walks, right stick / arrows
# set the Pinne, triggers (Leertaste / Umschalt) work Brenner and Ventil. All
# of it only counts while standing at the column — basket.gd checks reach.
func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A],
		"move_right": [KEY_D],
		"move_up": [KEY_W],
		"move_down": [KEY_S],
		"helm_left": [KEY_LEFT],
		"helm_right": [KEY_RIGHT],
		"helm_up": [KEY_UP],
		"helm_down": [KEY_DOWN],
		"burn": [KEY_SPACE],
		"vent": [KEY_SHIFT],
		"interact": [KEY_E],
		"restart": [KEY_R],
	}
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
		"helm_left": [JOY_AXIS_RIGHT_X, -1.0], "helm_right": [JOY_AXIS_RIGHT_X, 1.0],
		"helm_up": [JOY_AXIS_RIGHT_Y, -1.0], "helm_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"burn": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "vent": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	}
	var buttons := {"interact": JOY_BUTTON_A, "restart": JOY_BUTTON_START}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.3)
		for code in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
		if axes.has(action):
			# New joypad events only match device 0; -1 means any pad. Chrome
			# often hands a controller index 1 or higher.
			var motion := InputEventJoypadMotion.new()
			motion.device = -1
			motion.axis = axes[action][0]
			motion.axis_value = axes[action][1]
			InputMap.action_add_event(action, motion)
		if buttons.has(action):
			var btn := InputEventJoypadButton.new()
			btn.device = -1
			btn.button_index = buttons[action]
			InputMap.action_add_event(action, btn)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=")
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
