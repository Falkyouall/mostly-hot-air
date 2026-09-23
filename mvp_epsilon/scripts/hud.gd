extends CanvasLayer
## M2-E6 HUD — readable greybox. Brass / Jules-Verne treatment is M2-E8.5 polish.
## Shows wind direction at the balloon, fuel pool, hull damage, distance to goal,
## current speed, and the end-of-run banner.

const BRASS := Color(0.83, 0.66, 0.30)
const BRASS_DIM := Color(0.46, 0.36, 0.20)
const HULL_OK := Color(0.55, 0.80, 0.45)
const HULL_GONE := Color(0.30, 0.28, 0.26)
const BG := Color(0.08, 0.08, 0.10, 0.55)

@export var balloon: Balloon
@export var level: Level

@onready var _wind_arrow: TextureRect = $Panel/V/WindRow/WindArrow
@onready var _wind_label: Label = $Panel/V/WindRow/WindLabel
@onready var _fuel_bar: ProgressBar = $Panel/V/FuelBar
@onready var _fuel_label: Label = $Panel/V/FuelLabel
@onready var _hull_box: HBoxContainer = $Panel/V/HullBox
@onready var _ballast_label: Label = $Panel/V/BallastLabel
@onready var _distance_label: Label = $Panel/V/DistanceLabel
@onready var _speed_label: Label = $Panel/V/SpeedLabel
@onready var _banner: Label = $Banner


func _ready() -> void:
	_make_arrow_texture()
	if balloon:
		balloon.fuel_changed.connect(_on_fuel_changed)
		balloon.hull_changed.connect(_on_hull_changed)
		balloon.ballast_dropped.connect(_on_ballast)
		balloon.run_won.connect(_on_won)
		balloon.run_lost.connect(_on_lost)
		_on_fuel_changed(balloon.fuel, balloon.FUEL_MAX)
		_on_hull_changed(balloon.hull_hits)
		_on_ballast(balloon.ballast_remaining)


func _process(_delta: float) -> void:
	if balloon == null or level == null:
		return
	var wind := level.wind_at(balloon.global_position)
	var wind_xz := Vector2(wind.x, wind.z)
	if wind_xz.length() > 0.01:
		_wind_arrow.rotation = wind_xz.angle()
	_wind_label.text = "Wind  %.1f m/s" % wind_xz.length()

	var speed := Vector2(balloon.velocity.x, balloon.velocity.z).length()
	_speed_label.text = "Drift  %.1f m/s" % speed

	var d := level.goal_distance(balloon.global_position)
	_distance_label.text = "Goal  %.0f m" % d


# A tiny procedural arrow texture so this scene needs no image asset.
func _make_arrow_texture() -> void:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 48:
		for y in 48:
			var u := (float(x) - 24.0) / 24.0
			var v := (float(y) - 24.0) / 24.0
			# Triangle pointing along +x (right).
			var inside: bool = u > -0.6 and u < 0.9 and abs(v) < (0.7 - u * 0.5)
			if inside:
				img.set_pixel(x, y, BRASS)
	_wind_arrow.texture = ImageTexture.create_from_image(img)


func _on_fuel_changed(current: float, maximum: float) -> void:
	_fuel_bar.max_value = maximum
	_fuel_bar.value = current
	_fuel_label.text = "Brennstoff  %d / %d" % [int(current), int(maximum)]


func _on_hull_changed(hits_remaining: int) -> void:
	var children := _hull_box.get_children()
	for i in children.size():
		var pip := children[i] as ColorRect
		pip.color = HULL_OK if i < hits_remaining else HULL_GONE


func _on_ballast(remaining: int) -> void:
	_ballast_label.text = "Ballast  %d" % remaining


func _on_won() -> void:
	_show_banner("GELANDET — Drücke R für Neustart", Color(0.55, 0.80, 0.45))


func _on_lost(reason: StringName) -> void:
	var msg := "ABGESTÜRZT — Drücke R für Neustart"
	if reason == &"hull_destroyed":
		msg = "HÜLLE ZERSTÖRT — R für Neustart"
	_show_banner(msg, Color(0.92, 0.42, 0.35))


func _show_banner(msg: String, color: Color) -> void:
	_banner.text = msg
	_banner.modulate = color
	_banner.visible = true


func hide_banner() -> void:
	_banner.visible = false
