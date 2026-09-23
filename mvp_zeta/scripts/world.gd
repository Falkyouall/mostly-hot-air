extends Node3D
# The landscape below the basket plus everything gameplay asks about it:
# wind per altitude band, land/water, mountains, villages, the cloud deck.
# Axes: +X = east = direction of travel (screen right), -Z = north (screen up).

const Wares := preload("res://scripts/wares.gd")

const ROUTE_LEN := 2250.0
const BAND_LOW_TOP := 55.0
const BAND_MID_TOP := 105.0
const BAND_HIGH_TOP := 185.0
const CEILING := 220.0
# A village counts as passed once the balloon is this far east of it.
const PASS_DISTANCE := 130.0
const WIND_FLIPS: Array[float] = [945.0, 1700.0]
const CLOUD_Y_MIN := 120.0
const CLOUD_Y_MAX := 134.0
const VILLAGE_RADIUS := 30.0
const BULLSEYE_RADIUS := 10.0
const GOAL_RADIUS := 70.0

const MAP_MIN := Vector2(-500.0, -900.0)
const MAP_SIZE := Vector2(3400.0, 1500.0)
const MAP_CELL := 6.0

const VILLAGE_NAMES := ["Unterwölkchen", "Bad Böig", "Flautenbach", "Sankt Auftrieb", "Thermikon"]
const GOAL_NAME := "Hafen Luftikus"

const COL_RING_OPEN := Color(1.0, 0.86, 0.25)
const COL_RING_DONE := Color(0.35, 0.9, 0.4)

# Each village: {name, pos: Vector3, state: "open"|"done", ring_mat,
#   order: ware id it wants, known: has the crew seen its colours yet}
var villages: Array[Dictionary] = []
var goal_pos := Vector3(ROUTE_LEN, 0.0, 0.0)
# Each cone: {pos: Vector2, radius, height}
var cones: Array[Dictionary] = []
var wind_sign := 1.0

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _river_phase := 0.0
var _cloud_mat: ShaderMaterial


func build(seed_value: int) -> void:
	_rng.seed = seed_value
	_noise.seed = seed_value
	_noise.frequency = 0.0032
	_noise.fractal_octaves = 3
	_forest_noise.seed = seed_value + 99
	_forest_noise.frequency = 0.008
	_river_phase = _rng.randf_range(0.0, TAU)
	wind_sign = 1.0 if _rng.randf() < 0.5 else -1.0
	_place_villages()
	_place_mountains()
	_build_ground()
	_build_settlements()
	_build_trees()
	_build_mountains()
	_build_clouds()


# --- Queries -----------------------------------------------------------------

func wind_at(p: Vector3) -> Vector3:
	# Low and mid band push to opposite sides; which side flips along the route,
	# so the altimeter arrows have to be re-read now and then. Flips sit between
	# stops — inside a flip there is no sideways control at all.
	var s := wind_sign
	for flip_x in WIND_FLIPS:
		s *= clampf((flip_x - p.x) / 40.0, -1.0, 1.0)
	var low := Vector3(6.5, 0.0, 6.0 * s)
	var mid := Vector3(9.5, 0.0, -6.5 * s)
	var high := Vector3(17.0, 0.0, 1.5 * sin(p.x / 260.0))
	var t1 := smoothstep(BAND_LOW_TOP - 8.0, BAND_LOW_TOP + 8.0, p.y)
	# Rückströmung: the only way back to a village that slipped past. It sits
	# above every peak, far above the clouds, and peters out west of the start.
	var back := Vector3(-9.0 * clampf((p.x + 200.0) / 100.0, 0.0, 1.0), 0.0, 0.0)
	var t2 := smoothstep(BAND_MID_TOP - 8.0, BAND_MID_TOP + 8.0, p.y)
	var t3 := smoothstep(BAND_HIGH_TOP - 8.0, BAND_HIGH_TOP + 8.0, p.y)
	var w := low.lerp(mid, t1).lerp(high, t2).lerp(back, t3)
	if absf(p.z) > 240.0:
		w.z -= signf(p.z) * (absf(p.z) - 240.0) * 0.08
	return w


func land_height(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * 0.55 + 0.16
	var river_z := 190.0 * sin(x / 310.0 + _river_phase)
	h -= 0.5 * exp(-pow((z - river_z) / 38.0, 2.0))
	for v in villages:
		h = _flatten_towards(h, x, z, v.pos, 75.0)
	h = _flatten_towards(h, x, z, goal_pos, 130.0)
	return h


func is_water(x: float, z: float) -> bool:
	return land_height(x, z) < 0.0


func mountain_height(x: float, z: float) -> float:
	var best := 0.0
	for c in cones:
		var d := Vector2(x, z).distance_to(c.pos)
		if d < c.radius:
			best = maxf(best, c.height * (1.0 - d / c.radius))
	return best


# The stop worth pointing at: normally the first open village that can still
# be reached by drifting east; while riding the Rückströmung, the open village
# closest behind. Empty = only the harbour is left.
func target_village(balloon_x: float, going_back: bool) -> Dictionary:
	if going_back:
		for i in range(villages.size() - 1, -1, -1):
			var v := villages[i]
			if v.state == "open" and v.pos.x < balloon_x:
				return v
	for v in villages:
		if v.state == "open" and v.pos.x > balloon_x - PASS_DISTANCE:
			return v
	return {}


func delivered_count() -> int:
	var n := 0
	for v in villages:
		if v.state == "done":
			n += 1
	return n


func mark_delivered(v: Dictionary) -> void:
	v.state = "done"
	var mat: StandardMaterial3D = v.ring_mat
	mat.albedo_color = COL_RING_DONE


func set_cloud_focus(p: Vector3) -> void:
	_cloud_mat.set_shader_parameter("focus", p)


func set_cloud_hole(center: Vector2, shear: Vector2, radius: float) -> void:
	_cloud_mat.set_shader_parameter("hole_center", center)
	_cloud_mat.set_shader_parameter("hole_shear", shear)
	_cloud_mat.set_shader_parameter("hole_radius", radius)


# --- Layout ------------------------------------------------------------------

func _flatten_towards(h: float, x: float, z: float, p: Vector3, reach: float) -> float:
	if absf(x - p.x) > reach * 2.5 or absf(z - p.z) > reach * 2.5:
		return h
	var d := Vector2(x - p.x, z - p.z).length()
	return lerpf(h, 0.3, exp(-pow(d / reach, 2.0)))


func _place_villages() -> void:
	var xs := [360.0, 760.0, 1130.0, 1520.0, 1880.0]
	var z := 0.0
	# Two of each ware in the bag, so no order can outrun the stock on board.
	var bag: Array[String] = []
	for id in Wares.IDS:
		bag.append_array([id, id])
	for i in range(bag.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := bag[i]
		bag[i] = bag[j]
		bag[j] = swap
	for i in xs.size():
		var step := _rng.randf_range(60.0, 130.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		if absf(z + step) > 170.0:
			step = -step
		z += step
		villages.append({
			"name": VILLAGE_NAMES[i],
			"pos": Vector3(xs[i] + _rng.randf_range(-30.0, 30.0), 0.0, z),
			"state": "open",
			"order": bag[i],
			"known": false,
		})


func _place_mountains() -> void:
	# One massif between each pair of stops, pushed off the straight line by a
	# random amount: sometimes it merely looms, sometimes it forces a choice —
	# over the top (blind, above the clouds) or around (costs sideways room).
	var stops: Array[Vector3] = [Vector3.ZERO]
	for v in villages:
		stops.append(v.pos)
	stops.append(goal_pos)
	for i in range(1, stops.size() - 1):
		var mid: Vector3 = stops[i].lerp(stops[i + 1], 0.5)
		var center := Vector2(mid.x + _rng.randf_range(-25.0, 25.0), mid.z + _rng.randf_range(30.0, 110.0) * (1.0 if _rng.randf() < 0.5 else -1.0))
		var radius := _rng.randf_range(50.0, 72.0)
		var height := _rng.randf_range(125.0, 170.0)
		cones.append({"pos": center, "radius": radius, "height": height})
		for _k in _rng.randi_range(2, 3):
			var off := Vector2.from_angle(_rng.randf_range(0.0, TAU)) * radius * _rng.randf_range(0.5, 0.8)
			cones.append({
				"pos": center + off,
				"radius": radius * _rng.randf_range(0.45, 0.65),
				"height": height * _rng.randf_range(0.35, 0.6),
			})


# --- Meshes ------------------------------------------------------------------

func _build_ground() -> void:
	var w := int(MAP_SIZE.x / MAP_CELL)
	var h := int(MAP_SIZE.y / MAP_CELL)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for py in h:
		for px in w:
			var x := MAP_MIN.x + (px + 0.5) * MAP_CELL
			var z := MAP_MIN.y + (py + 0.5) * MAP_CELL
			var lh := clampf(land_height(x, z) * 0.5 + 0.5, 0.0, 1.0)
			var f := clampf(_forest_noise.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
			img.set_pixel(px, py, Color(lh, f, 0.0))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	mat.set_shader_parameter("map", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("world_min", MAP_MIN)
	mat.set_shader_parameter("world_size", MAP_SIZE)
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000.0, 6000.0)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(ROUTE_LEN * 0.5, 0.0, -200.0)
	add_child(mi)


func _build_settlements() -> void:
	var walls: Array = []  # [Transform3D, Color]
	var roofs: Array = []
	for v in villages:
		_scatter_houses(v.pos, 13.0, 50.0, _rng.randi_range(10, 14), walls, roofs)
		_add_target(v, VILLAGE_RADIUS, true)
	_scatter_houses(goal_pos, GOAL_RADIUS + 6.0, GOAL_RADIUS + 60.0, 34, walls, roofs)
	var goal := {"pos": goal_pos}
	_add_target(goal, GOAL_RADIUS, false)
	_add_multimesh(BoxMesh.new(), walls)
	_add_multimesh(PrismMesh.new(), roofs)


func _scatter_houses(center: Vector3, r_min: float, r_max: float, count: int, walls: Array, roofs: Array) -> void:
	var roof_cols := [Color(0.78, 0.30, 0.22), Color(0.85, 0.42, 0.24), Color(0.62, 0.26, 0.24), Color(0.80, 0.55, 0.30)]
	for i in count:
		var ang := _rng.randf_range(0.0, TAU)
		var p := center + Vector3(cos(ang), 0.0, sin(ang)) * _rng.randf_range(r_min, r_max)
		var size := Vector3(_rng.randf_range(4.0, 6.0), _rng.randf_range(3.0, 4.2), _rng.randf_range(5.0, 7.5))
		var yaw := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		var roof_h := size.x * 0.5
		walls.append([
			Transform3D(yaw * Basis.from_scale(size), p + Vector3(0.0, size.y * 0.5, 0.0)),
			Color(0.93, 0.87, 0.74).darkened(_rng.randf_range(0.0, 0.15)),
		])
		roofs.append([
			Transform3D(yaw * Basis.from_scale(Vector3(size.x * 1.2, roof_h, size.z * 1.1)), p + Vector3(0.0, size.y + roof_h * 0.5, 0.0)),
			roof_cols[_rng.randi() % roof_cols.size()],
		])


func _add_target(v: Dictionary, radius: float, with_flag: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COL_RING_OPEN if with_flag else Color(1.0, 1.0, 1.0)
	v["ring_mat"] = mat
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 3.0
	ring.outer_radius = radius
	ring.rings = 48
	ring.ring_segments = 6
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring
	ring_mi.material_override = mat
	ring_mi.scale = Vector3(1.0, 0.05, 1.0)
	ring_mi.position = v.pos + Vector3(0.0, 0.4, 0.0)
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_mi)
	if not with_flag:
		# Landing field: a big white H-less pad is enough.
		var pad := CylinderMesh.new()
		pad.top_radius = radius * 0.35
		pad.bottom_radius = radius * 0.35
		pad.height = 0.3
		var pad_mi := MeshInstance3D.new()
		pad_mi.mesh = pad
		pad_mi.material_override = mat
		pad_mi.position = v.pos + Vector3(0.0, 0.2, 0.0)
		add_child(pad_mi)
		return
	var bull := CylinderMesh.new()
	bull.top_radius = BULLSEYE_RADIUS
	bull.bottom_radius = BULLSEYE_RADIUS
	bull.height = 0.3
	# The order is painted where it reads best from above: the bullseye.
	var order_mat := StandardMaterial3D.new()
	order_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	order_mat.albedo_color = Wares.tint(v.order)
	var bull_mi := MeshInstance3D.new()
	bull_mi.mesh = bull
	bull_mi.material_override = order_mat
	bull_mi.position = v.pos + Vector3(0.0, 0.2, 0.0)
	add_child(bull_mi)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.5
	pole.bottom_radius = 0.5
	pole.height = 22.0
	var pole_mi := MeshInstance3D.new()
	pole_mi.mesh = pole
	pole_mi.position = v.pos + Vector3(0.0, 11.0, 0.0)
	add_child(pole_mi)
	var flag := BoxMesh.new()
	flag.size = Vector3(9.0, 5.0, 0.3)
	var flag_mi := MeshInstance3D.new()
	flag_mi.mesh = flag
	flag_mi.material_override = order_mat
	flag_mi.position = v.pos + Vector3(4.5, 19.0, 0.0)
	add_child(flag_mi)


func _build_trees() -> void:
	var trees: Array = []
	for i in 14000:
		var x := _rng.randf_range(-350.0, ROUTE_LEN + 450.0)
		var z := _rng.randf_range(-750.0, 480.0)
		var f := _forest_noise.get_noise_2d(x, z) * 0.5 + 0.5
		if _rng.randf() > smoothstep(0.45, 0.7, f) + 0.04:
			continue
		if land_height(x, z) < 0.07 or _near_target(x, z):
			continue
		var s := _rng.randf_range(0.8, 1.4)
		trees.append([
			Transform3D(Basis.from_scale(Vector3(4.5 * s, 6.0 * s, 4.5 * s)), Vector3(x, 3.0 * s, z)),
			Color(0.16, 0.38, 0.22).lerp(Color(0.30, 0.52, 0.25), _rng.randf()),
		])
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	_add_multimesh(cone, trees)


func _near_target(x: float, z: float) -> bool:
	for v in villages:
		if Vector2(x - v.pos.x, z - v.pos.z).length() < VILLAGE_RADIUS + 6.0:
			return true
	return Vector2(x - goal_pos.x, z - goal_pos.z).length() < GOAL_RADIUS + 6.0


func _build_mountains() -> void:
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.47, 0.41, 0.46)
	rock.roughness = 1.0
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.97, 0.95, 0.97)
	for c in cones:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = c.radius
		mesh.height = c.height
		mesh.radial_segments = 9
		mesh.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = rock
		mi.position = Vector3(c.pos.x, c.height * 0.5, c.pos.y)
		mi.rotation.y = _rng.randf_range(0.0, TAU)
		add_child(mi)
		if c.height > 100.0:
			var cap := CylinderMesh.new()
			cap.top_radius = 0.0
			cap.bottom_radius = c.radius * 0.27
			cap.height = c.height * 0.26
			cap.radial_segments = 9
			cap.rings = 1
			var cap_mi := MeshInstance3D.new()
			cap_mi.mesh = cap
			cap_mi.material_override = snow
			cap_mi.position = Vector3(c.pos.x, c.height * 0.875, c.pos.y)
			cap_mi.rotation.y = mi.rotation.y
			add_child(cap_mi)


func _build_clouds() -> void:
	var puffs: Array = []
	var x := -350.0
	while x < ROUTE_LEN + 500.0:
		var z := -800.0
		# Cloud cover thickens along the route — the difficulty ramp of GDD §2.2.
		var cover := lerpf(0.5, 0.82, clampf(x / ROUTE_LEN, 0.0, 1.0))
		while z < 520.0:
			if _rng.randf() < cover:
				var c := Vector3(x + _rng.randf_range(-35.0, 35.0), _rng.randf_range(CLOUD_Y_MIN, CLOUD_Y_MAX), z + _rng.randf_range(-35.0, 35.0))
				for _k in _rng.randi_range(5, 8):
					var r := _rng.randf_range(10.0, 21.0)
					var off := Vector3(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-4.0, 4.0), _rng.randf_range(-24.0, 24.0))
					puffs.append([Transform3D(Basis.from_scale(Vector3(r, r * 0.62, r)), c + off), Color.WHITE])
			z += 85.0
		x += 85.0
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 14
	sphere.rings = 7
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = preload("res://shaders/cloud.gdshader")
	var mmi := _add_multimesh(sphere, puffs)
	mmi.material_override = _cloud_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_multimesh(mesh: Mesh, items: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		# Instance colours skip the sRGB→linear conversion materials get.
		mm.set_instance_color(i, (items[i][1] as Color).srgb_to_linear())
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	# MultiMesh AABB is computed once; make sure nothing gets culled as a whole.
	mmi.extra_cull_margin = 16000.0
	add_child(mmi)
	return mmi
