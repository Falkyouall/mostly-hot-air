class_name Level
extends Node3D
## M2-E6 — world geometry and the wind field.
##
## Owns the stream-navigation maths ported from mvp_delta/index.html: a
## continuous 2D vector field (two superposed sine waves on each axis),
## attenuated with altitude, deflected around hand-placed mountains.
## Mountain collision uses the same footprint math as the visuals so what
## you see is what hits you.

# --- Wind field ---
# Weight-is-the-wheel makes basket COM the primary steering input, so the
# ambient wind is demoted to a gentle drift. Was: 14 / 10 / 5 / 4.4 / 18 / 14
# from mvp_delta; now scaled to ~1/5 so steering dominates and the world's
# pull is flavour rather than fight.
const BASE_EAST := 2.5
const WAVE_K1 := 0.0055
const WAVE_K2 := 0.011
const AMP_VZ_1 := 2.0
const AMP_VZ_2 := 1.0
const AMP_VX_MOD := 1.5
const ALT_FALLOFF := 500.0
const MOUNTAIN_SWIRL := 8.0
const MOUNTAIN_PUSH := 6.0

# --- Mountain layout (port of mvp_delta MOUNTAINS) ---
# x, z = world position; h = peak height; r = base radius; seed = silhouette noise.
const MOUNTAINS: Array[Dictionary] = [
	{"x":  280.0, "z":  -95.0, "h": 220.0, "r": 55.0, "seed": 1.3},
	{"x":  280.0, "z":   95.0, "h": 220.0, "r": 55.0, "seed": 2.7},
	{"x":  480.0, "z":    0.0, "h": 280.0, "r": 75.0, "seed": 4.1},
	{"x":  640.0, "z": -170.0, "h": 190.0, "r": 50.0, "seed": 5.9},
	{"x":  640.0, "z":  170.0, "h": 190.0, "r": 50.0, "seed": 7.2},
]

# --- Level layout ---
const START_POS := Vector3(0.0, 100.0, 0.0)
const GOAL_POS := Vector3(800.0, 0.0, 0.0)
const GOAL_RADIUS := 50.0

@onready var goal_marker: Node3D = $Goal


func _ready() -> void:
	_spawn_mountains()


func _spawn_mountains() -> void:
	var holder := $Mountains as Node3D
	for m in MOUNTAINS:
		var node := preload("res://scenes/mountain.tscn").instantiate()
		node.position = Vector3(m["x"], 0.0, m["z"])
		node.peak_height = m["h"]
		node.base_radius = m["r"]
		holder.add_child(node)


# Wind queried at any world position. Same shape as delta's windAt(x, y, z).
func wind_at(pos: Vector3) -> Vector3:
	var vx := BASE_EAST \
		+ cos(pos.z * WAVE_K1) * AMP_VX_MOD \
		+ cos(pos.z * WAVE_K2 + 0.8) * (AMP_VX_MOD * 0.6)
	var vz := sin(pos.x * WAVE_K1) * AMP_VZ_1 \
		+ sin(pos.x * WAVE_K2 + 1.2) * AMP_VZ_2

	# Altitude attenuation — wind weakens with height.
	var alt_att := maxf(0.0, 1.0 - pos.y / ALT_FALLOFF)
	vx *= alt_att
	vz *= alt_att

	# Mountain deflection: swirl + outward push, fading above each peak.
	for m in MOUNTAINS:
		var m_alt := maxf(0.0, 1.0 - pos.y / float(m["h"]))
		if m_alt <= 0.0:
			continue
		var dx := pos.x - float(m["x"])
		var dz := pos.z - float(m["z"])
		var r := sqrt(dx * dx + dz * dz)
		if r < 0.5:
			continue
		var eff_r := _mountain_r(m, atan2(dz, dx))
		var influence := eff_r * 2.8
		if r > influence:
			continue
		var ux := dx / r
		var uz := dz / r
		var prox := pow(1.0 - r / influence, 1.3)
		var weight := prox * m_alt
		# tangential swirl
		vx += -uz * MOUNTAIN_SWIRL * weight
		vz +=  ux * MOUNTAIN_SWIRL * weight
		# inner outward push so balloons get nudged out, not sucked in
		if r < eff_r * 1.5:
			var inner := 1.0 - r / (eff_r * 1.5)
			vx += ux * MOUNTAIN_PUSH * inner * m_alt
			vz += uz * MOUNTAIN_PUSH * inner * m_alt

	return Vector3(vx, 0.0, vz)


# Returns the hit mountain dict or {} if clear. Mirrors delta's mountainHit().
func mountain_hit(pos: Vector3) -> Dictionary:
	for m in MOUNTAINS:
		var dx := pos.x - float(m["x"])
		var dz := pos.z - float(m["z"])
		var r := sqrt(dx * dx + dz * dz)
		var eff_r := _mountain_r(m, atan2(dz, dx))
		if r > eff_r:
			continue
		var cone_top := float(m["h"]) * (1.0 - r / eff_r)
		if pos.y < cone_top:
			return m
	return {}


func goal_distance(pos: Vector3) -> float:
	var d := pos - GOAL_POS
	d.y = 0.0
	return d.length()


func is_in_goal(pos: Vector3) -> bool:
	return goal_distance(pos) <= GOAL_RADIUS


# Organic silhouette modifier — same in delta, used by visual + collision + wind.
static func _mountain_r(m: Dictionary, angle: float) -> float:
	var seed_v := float(m["seed"])
	var modulator := 1.0 \
		+ sin(angle * 2.0 + seed_v) * 0.17 \
		+ sin(angle * 3.5 + seed_v * 1.7) * 0.10 \
		+ sin(angle * 6.0 + seed_v * 2.3) * 0.06
	return float(m["r"]) * modulator
