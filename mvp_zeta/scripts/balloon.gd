extends Node3D
# The balloon as a vehicle: heat → lift, wind → drift, hull, fuel tank.
# It has no idea who is pulling which lever; basket.gd sets `burning`/`venting`.

signal hull_changed(hull: int)
signal bumped(what: String)
signal touched_down(sink_speed: float)

const BASKET_RADIUS := 3.0
const WALL_HEIGHT := 0.85
const ENVELOPE_Y := 13.0
const ENVELOPE_RADIUS := 6.0
const GROUND_CLEARANCE := 3.0

const HEAT_BURN := 0.38
const HEAT_VENT := 0.6
# Cooling scales with heat (a hotter envelope loses more). At the no-ballast
# hover point (heat 0.45) this equals the old flat 0.085/s; every sandbag
# lowers the hover heat and with it the fuel needed to stay up.
const HEAT_COOL := 0.19
const VY_COLD := -9.0
const VY_HOT := 11.0
const VENT_SINK := 5.0
const FUEL_PER_SEC := 3.0
const TANK_MAX := 100.0
const LIFT_PER_SACK := 1.5
const MAX_HULL := 3

var world: Node3D
var active := false
var burning := false
var venting := false

var heat := 0.47
var vy := 0.0
var velocity := Vector3.ZERO
var fuel := TANK_MAX
var hull := MAX_HULL
var extra_lift := 0.0

var visual: Node3D
var _envelope_mat: ShaderMaterial
var _flame: Node3D
var _flame_light: OmniLight3D
var _invuln := 0.0
var _flame_amount := 0.0
var _time := 0.0


func _ready() -> void:
	visual = Node3D.new()
	add_child(visual)
	_build_basket_shell()
	_build_envelope()
	_build_flame()


func is_flame_on() -> bool:
	return burning and fuel > 0.0


func equilibrium_heat() -> float:
	return clampf(inverse_lerp(VY_COLD, VY_HOT, -extra_lift), 0.0, 1.0)


func refuel(amount: float) -> void:
	fuel = minf(fuel + amount, TANK_MAX)


func drop_weight(lift: float) -> void:
	extra_lift += lift
	vy += lift * 3.0


func bounce() -> void:
	vy = 7.0
	heat = minf(heat + 0.2, 1.0)
	position.y = GROUND_CLEARANCE + 0.2


func damage(what: String) -> void:
	if _invuln > 0.0 or hull <= 0:
		return
	_invuln = 3.0
	hull -= 1
	hull_changed.emit(hull)
	bumped.emit(what)


func _physics_process(delta: float) -> void:
	_time += delta
	_invuln = maxf(_invuln - delta, 0.0)
	if active:
		_simulate(delta)
	_animate(delta)


func _simulate(delta: float) -> void:
	if is_flame_on():
		heat += HEAT_BURN * delta
		fuel = maxf(fuel - FUEL_PER_SEC * delta, 0.0)
	if venting:
		heat -= HEAT_VENT * delta
	heat = clampf(heat - HEAT_COOL * heat * delta, 0.0, 1.0)

	var target_vy := lerpf(VY_COLD, VY_HOT, heat) + extra_lift
	if venting:
		target_vy -= VENT_SINK
	var soft_top: float = world.CEILING - 20.0
	if position.y > soft_top:
		target_vy -= (position.y - soft_top) * 0.6
	vy = lerpf(vy, target_vy, 1.0 - exp(-1.3 * delta))

	var wind: Vector3 = world.wind_at(position)
	velocity = velocity.lerp(wind, 1.0 - exp(-1.5 * delta))
	velocity.y = vy
	position += velocity * delta

	_collide_mountains()
	if position.y <= GROUND_CLEARANCE:
		position.y = GROUND_CLEARANCE
		touched_down.emit(-vy)


func _collide_mountains() -> void:
	# Cliffs are walls, not ramps: the balloon is held against the face until it
	# has climbed over, with the wind still pressing it in.
	var foot := position.y - 2.0
	for c in world.cones:
		var to_me: Vector2 = Vector2(position.x, position.z) - c.pos
		var d: float = to_me.length()
		if d >= c.radius or foot >= c.height * (1.0 - d / c.radius):
			continue
		var out_dir: Vector2 = to_me / d if d > 0.01 else Vector2(-1.0, 0.0)
		var allowed: float = c.radius * (1.0 - foot / c.height)
		var p: Vector2 = c.pos + out_dir * allowed
		position.x = p.x
		position.z = p.y
		var into: float = Vector2(velocity.x, velocity.z).dot(-out_dir)
		if into > 0.0:
			velocity.x += out_dir.x * into
			velocity.z += out_dir.y * into
		damage("mountain")


func _animate(delta: float) -> void:
	_flame_amount = lerpf(_flame_amount, 1.0 if (active and is_flame_on()) else 0.0, 1.0 - exp(-12.0 * delta))
	var flicker := 0.85 + 0.15 * sin(_time * 47.0) * sin(_time * 31.0)
	_flame.scale = Vector3(1.0, 1.0, 1.0) * maxf(_flame_amount * flicker, 0.001)
	_flame.visible = _flame_amount > 0.02
	_flame_light.light_energy = _flame_amount * flicker * 5.0
	_envelope_mat.set_shader_parameter("glow", _flame_amount * flicker)

	# Cosmetic sway: lean into horizontal acceleration, plus a slow idle swing.
	var lag := Vector3.ZERO
	if active:
		lag = world.wind_at(position) - velocity
	var target_x := clampf(lag.z * 0.01, -0.06, 0.06) + sin(_time * 0.7) * 0.012
	var target_z := clampf(-lag.x * 0.01, -0.06, 0.06) + sin(_time * 0.9 + 1.3) * 0.012
	if _invuln > 2.4:
		target_z += sin(_time * 40.0) * 0.05
	visual.rotation.x = lerpf(visual.rotation.x, target_x, 1.0 - exp(-3.0 * delta))
	visual.rotation.z = lerpf(visual.rotation.z, target_z, 1.0 - exp(-3.0 * delta))


# --- Construction -------------------------------------------------------------

func _build_basket_shell() -> void:
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = preload("res://shaders/planks.gdshader")
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = BASKET_RADIUS
	floor_mesh.bottom_radius = BASKET_RADIUS * 0.94
	floor_mesh.height = 0.2
	_add_mesh(floor_mesh, floor_mat, Vector3(0.0, -0.1, 0.0))

	var wicker := StandardMaterial3D.new()
	wicker.albedo_color = Color(0.74, 0.40, 0.17)
	wicker.roughness = 0.9
	wicker.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wall := CylinderMesh.new()
	wall.top_radius = BASKET_RADIUS + 0.08
	wall.bottom_radius = BASKET_RADIUS * 0.96
	wall.height = WALL_HEIGHT
	wall.cap_top = false
	wall.cap_bottom = false
	wall.radial_segments = 40
	_add_mesh(wall, wicker, Vector3(0.0, WALL_HEIGHT * 0.5 - 0.05, 0.0))

	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.90, 0.55, 0.24)
	trim.roughness = 0.7
	for band in [[WALL_HEIGHT, 0.14, 0.1], [WALL_HEIGHT * 0.45, 0.07, 0.06], [0.0, 0.1, -0.06]]:
		var torus := TorusMesh.new()
		var r: float = BASKET_RADIUS + band[2]
		torus.inner_radius = r - band[1]
		torus.outer_radius = r + band[1]
		torus.rings = 48
		torus.ring_segments = 8
		_add_mesh(torus, trim, Vector3(0.0, band[0], 0.0))
	for i in 16:
		var a := TAU * i / 16.0
		var rib := BoxMesh.new()
		rib.size = Vector3(0.1, WALL_HEIGHT, 0.08)
		var mi := _add_mesh(rib, trim, Vector3(cos(a), 0.0, sin(a)) * (BASKET_RADIUS + 0.1) + Vector3(0.0, WALL_HEIGHT * 0.5, 0.0))
		mi.rotation.y = -a + PI * 0.5


func _build_envelope() -> void:
	_envelope_mat = ShaderMaterial.new()
	_envelope_mat.shader = preload("res://shaders/envelope.gdshader")
	var sphere := SphereMesh.new()
	sphere.radius = ENVELOPE_RADIUS
	sphere.height = ENVELOPE_RADIUS * 2.3
	sphere.radial_segments = 56
	sphere.rings = 24
	_add_mesh(sphere, _envelope_mat, Vector3(0.0, ENVELOPE_Y, 0.0))

	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.80, 0.66, 0.42)
	rope.roughness = 1.0
	# Load ring hugging the lower envelope, as in the moodboard.
	var ring := TorusMesh.new()
	ring.inner_radius = 4.72
	ring.outer_radius = 4.92
	ring.rings = 48
	ring.ring_segments = 8
	_add_mesh(ring, rope, Vector3(0.0, ENVELOPE_Y - 4.3, 0.0))
	for i in 6:
		# Offset so no rope hangs straight between camera and crew.
		var a := TAU * i / 6.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		_add_rod(dir * (BASKET_RADIUS + 0.1) + Vector3(0.0, WALL_HEIGHT, 0.0), dir * 4.8 + Vector3(0.0, ENVELOPE_Y - 4.3, 0.0), 0.045, rope)


func _build_flame() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.62, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = 3.0
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.34
	cone.height = 2.6
	var flame_mesh := MeshInstance3D.new()
	flame_mesh.mesh = cone
	flame_mesh.material_override = mat
	flame_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame_mesh.position = Vector3(0.0, 1.3, 0.0)
	# Pivot sits at the burner mouth so scaling grows the flame upwards.
	_flame = Node3D.new()
	_flame.position = Vector3(0.0, 1.55, 0.0)
	_flame.add_child(flame_mesh)
	visual.add_child(_flame)
	_flame_light = OmniLight3D.new()
	_flame_light.light_color = Color(1.0, 0.6, 0.25)
	_flame_light.omni_range = 9.0
	_flame_light.position = Vector3(0.0, 2.4, 0.0)
	_flame_light.light_energy = 0.0
	visual.add_child(_flame_light)


func _add_mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	visual.add_child(mi)
	return mi


func _add_rod(from: Vector3, to: Vector3, radius: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 6
	mesh.rings = 1
	var mi := _add_mesh(mesh, mat, (from + to) * 0.5)
	var up := (to - from).normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	mi.basis = Basis(side, up, side.cross(up))
