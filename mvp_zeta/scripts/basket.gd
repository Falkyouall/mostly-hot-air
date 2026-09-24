extends Node3D
# Everything inside the railing: station layout, item piles, the crew member,
# and the single-button interaction rules.
#
# The Pilotenstand is the column in the middle: burner and vent line hang from
# it, the Pinne on top steers the Außenbordmotor, the Gashebel on its side has
# three notches. Steering only happens within reach of the column — whoever is
# packing at the table is not correcting the course.
#
# The basket is a workshop, not a switchboard. A delivery has to be *made*:
#   Ware (pile) → Packtisch (hold to pack) → Fallschirm → railing
# The parachute goes on either way round: carry the parcel to the Haken, or
# take a Fallschirm from the Haken to a parcel lying on Packtisch/Ablage.
# The wind carries the balloon past the village whether the parcel is ready or
# not. Ablage slots let a calm stretch be used to pack ahead.
#
# Items are dictionaries: {kind: "ware"|"paket"|"schirm"|"sack"|"kanister", color, chute}.

signal thrown(item: Dictionary, local_pos: Vector3)
signal note(text: String)

const PlayerScript := preload("res://scripts/player.gd")
const Wares := preload("res://scripts/wares.gd")

const WALK_RADIUS := 2.67
const RIM_DIST := 2.05
const REACH := 0.75
const CANISTER_FUEL := 70.0
const PACK_TIME := 2.5
const SCOPE_RANGE := 280.0
const SCOPE_SPEED := 230.0
# Pinne turn rate at full deflection. The helm input is a target direction:
# hold it and the motor swings towards it; let go and it stays where it is.
const HELM_TURN_SPEED := deg_to_rad(90.0)

var balloon: Node3D
var enabled := false
var player: Node3D
var carried := {}  # empty = free hands
var stock := {"rot": 3, "blau": 3, "gelb": 3, "sack": 4, "kanister": 4}
var chutes := 6
var scope_active := false
var scope_offset := Vector2(140.0, 0.0)

var _stations: Array[Dictionary] = []
var _pile_nodes := {}
var _chute_nodes: Array[Node3D] = []
var _carried_node: Node3D
var _table := {}  # item on the Packtisch
var _table_node: Node3D
var _table_pos: Vector3
var _pack_progress := 0.0
var _pack_bar: MeshInstance3D
var _shelf: Array[Dictionary] = [{}, {}]
var _shelf_nodes: Array = [null, null]
var _shelf_spots: Array[Vector3] = []
var _prompt: Label3D
var _vent_handle: Node3D
var _vent_pull := 0.0
var _tiller: Node3D
var _gas_lever: Node3D


func _ready() -> void:
	_build_burner()
	_build_vent()
	_build_scope()
	_build_pile("rot", Vector3(2.35, 0.0, -0.55), 0.34)
	_build_pile("blau", Vector3(2.42, 0.0, 0.32), 0.34)
	_build_pile("gelb", Vector3(2.15, 0.0, 1.15), 0.34)
	_build_pile("kanister", Vector3(-2.2, 0.0, 0.9), 0.55)
	_build_pile("sack", Vector3(-1.75, 0.0, -1.7), 0.55)
	_build_table(Vector3(-1.0, 0.0, 1.0))
	_build_shelf(Vector3(1.0, 0.0, 1.0))
	_build_chute_rack(Vector3(1.45, 0.0, 2.15))

	player = PlayerScript.new()
	player.position = Vector3(0.0, 0.0, 1.9)
	add_child(player)

	_prompt = Label3D.new()
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.render_priority = 10
	_prompt.pixel_size = 0.0048
	_prompt.font_size = 52
	_prompt.outline_size = 14
	_prompt.outline_modulate = Color(0.12, 0.08, 0.06)
	add_child(_prompt)


func carrying(kind: String) -> bool:
	return carried.get("kind", "") == kind


func debug_give(item: Dictionary) -> void:
	_take(item)


func _physics_process(delta: float) -> void:
	balloon.burning = false
	balloon.venting = false
	var was_scoping := scope_active
	scope_active = false
	_prompt.text = ""
	var packing := false
	if enabled:
		packing = _interact(delta)
	if not packing and _table.get("kind", "") == "ware":
		_pack_progress = 0.0
	_pack_bar.visible = _pack_progress > 0.0
	_pack_bar.scale.x = maxf(_pack_progress / PACK_TIME, 0.01)
	player.locked = scope_active
	if scope_active and not was_scoping:
		scope_offset = Vector2(140.0, 0.0)
	player.step(delta, not carried.is_empty())
	_keep_inside()
	_prompt.position = player.position + Vector3(0.0, 1.75 if carried.is_empty() else 2.2, 0.0)
	_vent_pull = lerpf(_vent_pull, 1.0 if balloon.venting else 0.0, 1.0 - exp(-14.0 * delta))
	_vent_handle.position.y = 1.35 - _vent_pull * 0.3
	# Pinne points where the motor pushes; the lever's notch shows the throttle.
	var d: Vector2 = balloon.thrust_dir
	_tiller.rotation.y = lerp_angle(_tiller.rotation.y, atan2(-d.y, d.x), 1.0 - exp(-10.0 * delta))
	_gas_lever.rotation.x = lerpf(_gas_lever.rotation.x, (balloon.throttle - 1) * 0.55, 1.0 - exp(-12.0 * delta))


# Returns true while the Packtisch is being worked.
func _interact(delta: float) -> bool:
	var pressed := Input.is_action_just_pressed("interact")
	var held := Input.is_action_pressed("interact")
	if not carried.is_empty():
		_interact_carrying(pressed)
		return false
	var near := _stations_in_reach()
	if near.is_empty():
		return false
	# Nearest station that has something to offer; an empty table next to the
	# burner must not steal the button.
	var st := near[0]
	for candidate in near:
		if _offers_to_empty_hands(candidate):
			st = candidate
			break
	match st.kind:
		"pile":
			if stock[st.key] <= 0:
				_prompt.text = "leer"
			else:
				_prompt.text = "[E] %s nehmen" % item_name(_pile_item(st.key))
				if pressed:
					_take_from_pile(st.key)
		"table":
			return _work_table(delta, pressed, held)
		"shelf":
			var slot := _nearest_shelf_slot(true)
			if slot >= 0:
				_prompt.text = "[E] %s nehmen" % item_name(_shelf[slot])
				if pressed:
					_take_from_shelf(slot)
			else:
				_prompt.text = "Ablage (leer)"
		"chutes":
			if chutes <= 0:
				_prompt.text = "Keine Fallschirme mehr!"
			else:
				_prompt.text = "[E] Fallschirm nehmen (%d)" % chutes
				if pressed:
					chutes -= 1
					_chute_nodes[chutes].visible = false
					_take({"kind": "schirm", "color": "", "chute": false})
		"hold":
			_operate(st, pressed, held, delta)
	return false


func _offers_to_empty_hands(st: Dictionary) -> bool:
	match st.kind:
		"pile":
			return stock[st.key] > 0
		"table":
			return not _table.is_empty()
		"shelf":
			return _nearest_shelf_slot(true) >= 0
		"chutes":
			return chutes > 0
	return true


func _interact_carrying(pressed: bool) -> void:
	var kind: String = carried.kind
	var at_rim := Vector2(player.position.x, player.position.z).length() > RIM_DIST
	# Stations crowd each other, so ask every one in reach what it could do with
	# this item and take the most purposeful offer (parking it comes last).
	var offers: Array[String] = []
	for st in _stations_in_reach():
		offers.append(_carry_action(st))
	var action := ""
	for wanted in ["refuel", "to_table", "chute", "attach_table", "attach_shelf", "no_chutes", "put_back", "to_shelf"]:
		if offers.has(wanted):
			action = wanted
			break
	if action == "" and at_rim:
		action = "throw"
	match action:
		"refuel":
			_prompt.text = "[E] Tank auffüllen"
		"to_table":
			_prompt.text = "[E] auf den Packtisch"
		"chute":
			_prompt.text = "[E] Fallschirm anknoten"
		"attach_table", "attach_shelf":
			_prompt.text = "[E] Fallschirm ans Paket"
		"no_chutes":
			_prompt.text = "Keine Fallschirme mehr!"
		"to_shelf":
			_prompt.text = "[E] ablegen"
		"put_back":
			_prompt.text = "[E] zurücklegen"
		"throw":
			_prompt.text = "[E] %s abwerfen" % item_name(carried)
			if kind == "paket" and not carried.chute:
				_prompt.text += "\nohne Schirm: nur im Tiefflug!"
		_:
			if kind == "kanister":
				_prompt.text = "» zum Pilotenstand"
			elif kind == "ware":
				_prompt.text = "» zum Packtisch"
			elif kind == "schirm":
				_prompt.text = "» zu einem Paket\n(Packtisch / Ablage)"
			elif kind == "paket" and not carried.chute:
				_prompt.text = "» Fallschirm-Haken"
			else:
				_prompt.text = "» zur Reling"
	if not pressed:
		return
	match action:
		"refuel":
			balloon.refuel(CANISTER_FUEL)
			note.emit("Tank +%d" % int(CANISTER_FUEL))
			_clear_hands()
			Sfx.play("refuel")
		"to_table":
			_table = carried
			_table_node = _place_node(_table, _table_pos + Vector3(0.0, 0.78, 0.0))
			_pack_progress = 0.0
			_clear_hands()
			Sfx.play("pickup")
		"chute":
			chutes -= 1
			_chute_nodes[chutes].visible = false
			var upgraded := carried.duplicate()
			upgraded.chute = true
			_clear_hands()
			_take(upgraded)
		"attach_table":
			_table.chute = true
			_table_node.queue_free()
			_table_node = _place_node(_table, _table_pos + Vector3(0.0, 0.85, 0.0))
			_clear_hands()
			Sfx.play("refuel")
		"attach_shelf":
			var bare := _shelf_slot_needing_chute()
			_shelf[bare].chute = true
			_shelf_nodes[bare].queue_free()
			_shelf_nodes[bare] = _place_node(_shelf[bare], _shelf_spots[bare])
			_clear_hands()
			Sfx.play("refuel")
		"to_shelf":
			var slot := _nearest_shelf_slot(false)
			_shelf[slot] = carried
			_shelf_nodes[slot] = _place_node(carried, _shelf_spots[slot])
			_clear_hands()
			Sfx.play("pickup")
		"put_back":
			if kind == "schirm":
				_chute_nodes[chutes].visible = true
				chutes += 1
			else:
				var key := _pile_key(carried)
				_pile_nodes[key][stock[key]].visible = true
				stock[key] += 1
			_clear_hands()
			Sfx.play("pickup")
		"throw":
			var flat := Vector3(player.position.x, 0.0, player.position.z).normalized()
			thrown.emit(carried, flat * (balloon.BASKET_RADIUS + 0.7) + Vector3(0.0, 1.0, 0.0))
			_clear_hands()
			Sfx.play("throw")


func _carry_action(st: Dictionary) -> String:
	var kind: String = carried.kind
	match st.id:
		"pilotenstand":
			return "refuel" if kind == "kanister" else ""
		"packtisch":
			if kind == "ware" and _table.is_empty():
				return "to_table"
			if kind == "schirm" and _table.get("kind", "") == "paket" and not _table.chute:
				return "attach_table"
			return ""
		"schirme":
			if kind == "paket" and not carried.chute:
				return "chute" if chutes > 0 else "no_chutes"
			return "put_back" if kind == "schirm" else ""
		"ablage":
			if kind == "schirm":
				return "attach_shelf" if _shelf_slot_needing_chute() >= 0 else ""
			if (kind == "ware" or kind == "paket") and _nearest_shelf_slot(false) >= 0:
				return "to_shelf"
	if st.get("key", "") == _pile_key(carried):
		return "put_back"
	return ""


func _work_table(delta: float, pressed: bool, held: bool) -> bool:
	if _table.is_empty():
		_prompt.text = "Packtisch (Ware bringen)"
		return false
	if _table.kind == "paket":
		_prompt.text = "[E] %s nehmen" % item_name(_table)
		if pressed:
			_table_node.queue_free()
			var item := _table
			_table = {}
			_take(item)
		return false
	_prompt.text = "[E] halten: packen"
	if not held:
		return false
	player.face_towards(_table_pos, delta)
	_pack_progress += delta
	if _pack_progress >= PACK_TIME:
		_pack_progress = 0.0
		_table = {"kind": "paket", "color": _table.color, "chute": false}
		_table_node.queue_free()
		_table_node = _place_node(_table, _table_pos + Vector3(0.0, 0.85, 0.0))
		Sfx.play("refuel")
	return true


func _operate(st: Dictionary, pressed: bool, held: bool, delta: float) -> void:
	match st.id:
		"pilotenstand":
			_prompt.text = "[E] Gas: %s\nPfeile / R-Stick = Pinne · Leer / RT = Brenner · Umschalt / LT = Ventil" % balloon.THROTTLE_NAMES[balloon.throttle]
			if balloon.fuel <= 0.0:
				_prompt.text = "Tank leer! (Kanister, links)"
			if pressed:
				balloon.cycle_throttle()
				Sfx.play("lever")
			var helm := Input.get_vector("helm_left", "helm_right", "helm_up", "helm_down")
			if helm.length() > 0.3:
				var current: float = balloon.thrust_dir.angle()
				var diff := angle_difference(current, helm.angle())
				var step: float = HELM_TURN_SPEED * minf(helm.length(), 1.0) * delta
				balloon.thrust_dir = Vector2.from_angle(current + clampf(diff, -step, step))
				player.face_towards(player.position + Vector3(helm.x, 0.0, helm.y), delta)
			balloon.burning = Input.is_action_pressed("burn")
			balloon.venting = Input.is_action_pressed("vent")
			return
		"fernrohr":
			_prompt.text = "[E] halten: Fernrohr"
			scope_active = held
			if held:
				_prompt.text = ""
				var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
				scope_offset = (scope_offset + v * SCOPE_SPEED * delta).limit_length(SCOPE_RANGE)
	if held:
		player.face_towards(st.pos, delta)


# --- Hands, piles, slots -----------------------------------------------------------

static func item_name(item: Dictionary) -> String:
	match item.kind:
		"ware":
			return Wares.label(item.color)
		"paket":
			return "Paket %s" % Wares.label(item.color)
		"schirm":
			return "Fallschirm"
		"sack":
			return "Sandsack"
	return "Kanister"


func _pile_item(key: String) -> Dictionary:
	if Wares.INFO.has(key):
		return {"kind": "ware", "color": key, "chute": false}
	return {"kind": key, "color": "", "chute": false}


func _pile_key(item: Dictionary) -> String:
	return item.color if item.kind == "ware" else item.kind


func _take_from_pile(key: String) -> void:
	stock[key] -= 1
	_pile_nodes[key][stock[key]].visible = false
	_take(_pile_item(key))


func _take_from_shelf(slot: int) -> void:
	var item := _shelf[slot]
	_shelf[slot] = {}
	_shelf_nodes[slot].queue_free()
	_shelf_nodes[slot] = null
	_take(item)


func _take(item: Dictionary) -> void:
	carried = item
	_carried_node = make_item(item)
	player.carry_anchor.add_child(_carried_node)
	player.pop()
	Sfx.play("pickup")


func _clear_hands() -> void:
	carried = {}
	_carried_node.queue_free()
	_carried_node = null
	player.pop()


func _place_node(item: Dictionary, at: Vector3) -> Node3D:
	var node := make_item(item)
	node.position = at
	add_child(node)
	return node


func _shelf_slot_is_free(slot: int) -> bool:
	return _shelf[slot].is_empty()


func _shelf_slot_needing_chute() -> int:
	for i in _shelf.size():
		if _shelf[i].get("kind", "") == "paket" and not _shelf[i].chute:
			return i
	return -1


# Nearest shelf slot to the player that is filled (or free). -1 if none.
func _nearest_shelf_slot(filled: bool) -> int:
	var best := -1
	var best_d := INF
	for i in _shelf.size():
		if _shelf[i].is_empty() == filled:
			continue
		var d := player.position.distance_to(_shelf_spots[i])
		if d < best_d:
			best = i
			best_d = d
	return best


# Nearest first.
func _stations_in_reach() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for st in _stations:
		var d: float = player.position.distance_to(st.pos) - st.radius
		if d < REACH:
			found.append({"st": st, "d": d})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.d < b.d)
	var out: Array[Dictionary] = []
	for f in found:
		out.append(f.st)
	return out


func _keep_inside() -> void:
	var p: Vector3 = player.position
	p.y = 0.0
	for st in _stations:
		var away: Vector3 = p - st.pos
		var min_d: float = st.radius + PlayerScript.RADIUS
		if away.length() < min_d:
			p = st.pos + (away.normalized() if away.length() > 0.001 else Vector3.BACK) * min_d
	if p.length() > WALK_RADIUS:
		p = p.normalized() * WALK_RADIUS
	player.position = p


# --- Item meshes ----------------------------------------------------------------------

static func make_item(item: Dictionary) -> Node3D:
	var root := Node3D.new()
	match item.kind:
		"ware":
			var bundle := SphereMesh.new()
			bundle.radius = 0.24
			bundle.height = 0.36
			_attach(root, bundle, Wares.tint(item.color), Vector3.ZERO).scale = Vector3(1.15, 1.0, 0.9)
			var cord := CylinderMesh.new()
			cord.top_radius = 0.2
			cord.bottom_radius = 0.2
			cord.height = 0.05
			_attach(root, cord, Color(0.30, 0.22, 0.16), Vector3.ZERO).rotation.z = PI * 0.5
		"paket":
			var box := BoxMesh.new()
			box.size = Vector3(0.46, 0.4, 0.46)
			_attach(root, box, Color(0.72, 0.52, 0.30), Vector3.ZERO)
			var band := BoxMesh.new()
			band.size = Vector3(0.48, 0.42, 0.14)
			_attach(root, band, Wares.tint(item.color), Vector3.ZERO)
			var band2 := BoxMesh.new()
			band2.size = Vector3(0.14, 0.42, 0.48)
			_attach(root, band2, Wares.tint(item.color), Vector3.ZERO)
			if item.chute:
				_attach(root, _chute_pack_mesh(), Color(0.97, 0.95, 0.90), Vector3(0.0, 0.27, 0.0))
		"schirm":
			_attach(root, _chute_pack_mesh(), Color(0.97, 0.95, 0.90), Vector3.ZERO).scale = Vector3(1.4, 1.4, 1.4)
		"sack":
			var blob := SphereMesh.new()
			blob.radius = 0.3
			blob.height = 0.42
			_attach(root, blob, Color(0.84, 0.76, 0.58), Vector3.ZERO).scale = Vector3(1.2, 1.0, 0.95)
			var knot := SphereMesh.new()
			knot.radius = 0.08
			knot.height = 0.16
			_attach(root, knot, Color(0.70, 0.62, 0.45), Vector3(0.0, 0.2, 0.0))
		"kanister":
			var keg := CylinderMesh.new()
			keg.top_radius = 0.2
			keg.bottom_radius = 0.2
			keg.height = 0.48
			_attach(root, keg, Color(0.80, 0.36, 0.20), Vector3.ZERO)
			for y in [-0.14, 0.14]:
				var hoop := CylinderMesh.new()
				hoop.top_radius = 0.215
				hoop.bottom_radius = 0.215
				hoop.height = 0.06
				_attach(root, hoop, Color(0.36, 0.42, 0.52), Vector3(0.0, y, 0.0))
	return root


static func _chute_pack_mesh() -> Mesh:
	var pack := SphereMesh.new()
	pack.radius = 0.2
	pack.height = 0.2
	return pack


static func _attach(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


# --- Workshop stations -----------------------------------------------------------------

@warning_ignore("integer_division")
func _build_pile(key: String, at: Vector3, radius: float) -> void:
	_stations.append({"id": key, "kind": "pile", "key": key, "pos": at, "radius": radius})
	_pile_nodes[key] = []
	if Wares.INFO.has(key):
		# Open crate in the ware's colour, bundles stacked inside.
		var crate := BoxMesh.new()
		crate.size = Vector3(0.62, 0.3, 0.62)
		_attach(self, crate, Wares.tint(key).darkened(0.35), at + Vector3(0.0, 0.15, 0.0))
	for i in stock[key]:
		var node := make_item(_pile_item(key))
		match key:
			"sack":
				node.position = at + Vector3((i % 2) * 0.55 - 0.27, 0.18 + (i / 2) * 0.3, (i / 2) * 0.12 - 0.1)
				node.rotation.y = i * 0.8
			"kanister":
				node.position = at + Vector3((i % 2) * 0.45 - 0.22, 0.24, (i / 2) * 0.45 - 0.22)
			_:
				node.position = at + Vector3(0.0, 0.42 + i * 0.3, 0.0)
				node.rotation.y = i * 1.1
		add_child(node)
		_pile_nodes[key].append(node)


func _build_table(at: Vector3) -> void:
	_table_pos = at
	_stations.append({"id": "packtisch", "kind": "table", "pos": at, "radius": 0.45})
	var top := CylinderMesh.new()
	top.top_radius = 0.47
	top.bottom_radius = 0.47
	top.height = 0.08
	_attach(self, top, Color(0.62, 0.42, 0.24), at + Vector3(0.0, 0.56, 0.0))
	var leg := CylinderMesh.new()
	leg.top_radius = 0.2
	leg.bottom_radius = 0.3
	leg.height = 0.52
	_attach(self, leg, Color(0.42, 0.28, 0.17), at + Vector3(0.0, 0.26, 0.0))
	var bar := BoxMesh.new()
	bar.size = Vector3(0.8, 0.09, 0.09)
	_pack_bar = _attach(self, bar, Color(0.35, 0.9, 0.4), at + Vector3(0.0, 1.35, 0.0))
	var bar_mat: StandardMaterial3D = _pack_bar.material_override
	bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_mat.no_depth_test = true
	_pack_bar.visible = false


func _build_shelf(at: Vector3) -> void:
	_stations.append({"id": "ablage", "kind": "shelf", "pos": at, "radius": 0.42})
	var bench := BoxMesh.new()
	bench.size = Vector3(1.05, 0.4, 0.5)
	_attach(self, bench, Color(0.50, 0.34, 0.20), at + Vector3(0.0, 0.2, 0.0))
	_shelf_spots = [at + Vector3(-0.27, 0.62, 0.0), at + Vector3(0.27, 0.62, 0.0)]


@warning_ignore("integer_division")
func _build_chute_rack(at: Vector3) -> void:
	_stations.append({"id": "schirme", "kind": "chutes", "pos": at, "radius": 0.35})
	var post := CylinderMesh.new()
	post.top_radius = 0.05
	post.bottom_radius = 0.06
	post.height = 1.3
	_attach(self, post, Color(0.35, 0.25, 0.18), at + Vector3(0.0, 0.65, 0.0))
	var beam := BoxMesh.new()
	beam.size = Vector3(0.9, 0.07, 0.07)
	_attach(self, beam, Color(0.35, 0.25, 0.18), at + Vector3(0.0, 1.25, 0.0))
	for i in chutes:
		var pack := _attach(self, _chute_pack_mesh(), Color(0.97, 0.95, 0.90), at + Vector3((i % 3) * 0.3 - 0.3, 1.1 - (i / 3) * 0.3, 0.0))
		_chute_nodes.append(pack)


# --- Lever stations -----------------------------------------------------------------------

func _build_burner() -> void:
	_stations.append({"id": "pilotenstand", "kind": "hold", "pos": Vector3.ZERO, "radius": 0.5})
	_floor_mark(Vector3.ZERO, Color(0.85, 0.66, 0.30))
	var iron := Color(0.20, 0.19, 0.22)
	var brass := Color(0.85, 0.66, 0.30)
	var stove := CylinderMesh.new()
	stove.top_radius = 0.34
	stove.bottom_radius = 0.42
	stove.height = 1.0
	_attach(self, stove, iron, Vector3(0.0, 0.5, 0.0))
	var collar := CylinderMesh.new()
	collar.top_radius = 0.46
	collar.bottom_radius = 0.46
	collar.height = 0.1
	_attach(self, collar, Color(0.62, 0.45, 0.22), Vector3(0.0, 0.95, 0.0))
	var nozzle := CylinderMesh.new()
	nozzle.top_radius = 0.2
	nozzle.bottom_radius = 0.14
	nozzle.height = 0.55
	_attach(self, nozzle, iron, Vector3(0.0, 1.27, 0.0))
	var window := BoxMesh.new()
	window.size = Vector3(0.26, 0.2, 0.06)
	var glow := _attach(self, window, Color(1.0, 0.6, 0.2), Vector3(0.0, 0.45, 0.39))
	var glow_mat: StandardMaterial3D = glow.material_override
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.5, 0.15)
	glow_mat.emission_energy_multiplier = 2.0

	# Pinne: a brass arm on a pivot ring round the collar, arrowhead outward.
	_tiller = Node3D.new()
	_tiller.position = Vector3(0.0, 1.02, 0.0)
	add_child(_tiller)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.95, 0.06, 0.06)
	_attach(_tiller, arm, brass, Vector3(0.55, 0.0, 0.0))
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.11
	head.height = 0.3
	head.radial_segments = 8
	var head_mi := _attach(_tiller, head, brass, Vector3(1.12, 0.0, 0.0))
	head_mi.rotation.z = -PI * 0.5
	var knob := SphereMesh.new()
	knob.radius = 0.07
	knob.height = 0.14
	_attach(_tiller, knob, Color(0.42, 0.28, 0.17), Vector3(0.9, 0.0, 0.0))

	# Gashebel on the south face: three notches, the lever tilts through them.
	var plate := BoxMesh.new()
	plate.size = Vector3(0.3, 0.34, 0.05)
	_attach(self, plate, brass, Vector3(0.0, 0.62, 0.43))
	for i in 3:
		var notch := BoxMesh.new()
		notch.size = Vector3(0.05, 0.03, 0.06)
		_attach(self, notch, iron, Vector3(0.09, 0.51 + i * 0.11, 0.44))
	_gas_lever = Node3D.new()
	_gas_lever.position = Vector3(-0.06, 0.62, 0.47)
	add_child(_gas_lever)
	var stem := BoxMesh.new()
	stem.size = Vector3(0.04, 0.04, 0.3)
	_attach(_gas_lever, stem, iron, Vector3(0.0, 0.0, 0.15))
	var grip := SphereMesh.new()
	grip.radius = 0.06
	grip.height = 0.12
	_attach(_gas_lever, grip, Color(0.85, 0.2, 0.18), Vector3(0.0, 0.0, 0.3))


func _floor_mark(at: Vector3, color: Color) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.02
	_attach(self, disc, color, Vector3(at.x, 0.012, at.z) * Vector3(0.82, 1.0, 0.82))


# The red vent line comes down the envelope mouth and hangs beside the column,
# where the pilot can reach it without leaving the Pilotenstand.
func _build_vent() -> void:
	var at := Vector3(0.55, 0.0, -0.5)
	_vent_handle = Node3D.new()
	_vent_handle.position = at + Vector3(0.0, 1.35, 0.0)
	add_child(_vent_handle)
	var line := CylinderMesh.new()
	line.top_radius = 0.045
	line.bottom_radius = 0.045
	line.height = 8.0
	_attach(_vent_handle, line, Color(0.85, 0.2, 0.18), Vector3(0.0, 4.0, 0.0))
	var grip := TorusMesh.new()
	grip.inner_radius = 0.12
	grip.outer_radius = 0.22
	var grip_mi := _attach(_vent_handle, grip, Color(0.85, 0.2, 0.18), Vector3(0.0, -0.1, 0.0))
	grip_mi.rotation.x = PI * 0.5


func _build_scope() -> void:
	var at := Vector3(1.9, 0.0, -1.8)
	_stations.append({"id": "fernrohr", "kind": "hold", "pos": at, "radius": 0.3})
	_floor_mark(at, Color(0.30, 0.50, 0.36))
	var post := CylinderMesh.new()
	post.top_radius = 0.05
	post.bottom_radius = 0.07
	post.height = 1.15
	_attach(self, post, Color(0.35, 0.25, 0.18), at + Vector3(0.0, 0.57, 0.0))
	var pivot := Node3D.new()
	pivot.position = at + Vector3(0.0, 1.2, 0.0)
	pivot.rotation = Vector3(0.0, -PI * 0.25, 0.0)
	add_child(pivot)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.13
	tube.bottom_radius = 0.09
	tube.height = 1.1
	var tube_mi := _attach(pivot, tube, Color(0.80, 0.62, 0.28), Vector3(0.0, 0.0, -0.25))
	tube_mi.rotation.x = -PI * 0.5 - 0.35
	var wrap := CylinderMesh.new()
	wrap.top_radius = 0.125
	wrap.bottom_radius = 0.115
	wrap.height = 0.4
	var wrap_mi := _attach(pivot, wrap, Color(0.30, 0.50, 0.36), Vector3(0.0, 0.0, -0.25))
	wrap_mi.rotation.x = -PI * 0.5 - 0.35
