extends Control
# Immediate-mode HUD: everything is drawn in _draw() from live game state.
# The altimeter is the steering wheel of this game — it shows which way each
# altitude band blows right here, where the clouds sit, and rock ahead.

const COL_PANEL := Color(0.10, 0.08, 0.12, 0.62)
const COL_TEXT := Color(1.0, 0.97, 0.90)
const COL_DIM := Color(1.0, 0.97, 0.90, 0.6)
const COL_LOW := Color(0.45, 0.75, 0.40)
const COL_MID := Color(0.35, 0.65, 0.85)
const COL_HIGH := Color(0.70, 0.55, 0.85)
const COL_BACK := Color(0.95, 0.60, 0.45)
const COL_WARN := Color(1.0, 0.35, 0.25)
const COL_GOLD := Color(1.0, 0.82, 0.25)

const Wares := preload("res://scripts/wares.gd")

var game: Node3D
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game.state == game.State.INTRO:
		_draw_intro()
		return
	_draw_altimeter()
	_draw_gauges()
	_draw_route()
	_draw_target_pointer()
	_draw_toast()
	if game.basket.scope_active:
		_text(Vector2(size.x * 0.5, size.y - 70.0), "FERNROHR — bewegen mit WASD / Stick", 22, COL_TEXT, true)
	if game.state == game.State.ENDED:
		_draw_result()


# --- Altimeter -----------------------------------------------------------------------

func _draw_altimeter() -> void:
	var w: Node3D = game.world
	var b: Node3D = game.balloon
	var top := 150.0
	var bottom := size.y - 230.0
	var x := 36.0
	var bar_w := 30.0
	var y_of := func(alt: float) -> float: return lerpf(bottom, top, clampf(alt / w.CEILING, 0.0, 1.0))

	draw_rect(Rect2(x - 12.0, top - 40.0, 200.0, bottom - top + 58.0), COL_PANEL)
	_text(Vector2(x - 2.0, top - 16.0), "HÖHE & WIND", 15, COL_DIM)

	# [from, to, colour, altitude of the wind icon (kept clear of the cloud label)]
	var bands := [
		[0.0, w.BAND_LOW_TOP, COL_LOW, w.BAND_LOW_TOP * 0.5],
		[w.BAND_LOW_TOP, w.BAND_MID_TOP, COL_MID, (w.BAND_LOW_TOP + w.BAND_MID_TOP) * 0.5],
		[w.BAND_MID_TOP, w.BAND_HIGH_TOP, COL_HIGH, w.BAND_HIGH_TOP - 22.0],
		[w.BAND_HIGH_TOP, w.CEILING, COL_BACK, (w.BAND_HIGH_TOP + w.CEILING) * 0.5],
	]
	for band in bands:
		var y0: float = y_of.call(band[1])
		var y1: float = y_of.call(band[0])
		var col: Color = band[2]
		draw_rect(Rect2(x, y0, bar_w, y1 - y0 - 2.0), col)
		var icon_alt: float = band[3]
		var wind: Vector3 = w.wind_at(Vector3(b.position.x, icon_alt, b.position.z))
		var in_band: bool = b.position.y >= band[0] and b.position.y < band[1]
		var c := Vector2(x + bar_w + 62.0, y_of.call(icon_alt))
		draw_circle(c, 26.0, Color(col, 0.35 if not in_band else 0.8))
		_arrow(c, Vector2(wind.x, wind.z).normalized(), 20.0, COL_TEXT, 4.0)
		_text(Vector2(c.x + 34.0, c.y + 6.0), "%d" % int(Vector2(wind.x, wind.z).length()), 17, COL_TEXT if in_band else COL_DIM)

	# Cloud deck.
	var cy0: float = y_of.call(w.CLOUD_Y_MAX + 10.0)
	var cy1: float = y_of.call(w.CLOUD_Y_MIN - 10.0)
	draw_rect(Rect2(x - 4.0, cy0, bar_w + 8.0, cy1 - cy0), Color(1.0, 1.0, 1.0, 0.55))
	_text(Vector2(x + bar_w + 12.0, (cy0 + cy1) * 0.5 + 5.0), "Wolkendecke", 14, COL_DIM)

	# Rock ahead: everything below the red line is mountain.
	if game.threat_height > 1.0:
		var ty: float = y_of.call(game.threat_height + 4.0)
		var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
		var danger: bool = b.position.y < game.threat_height + 6.0
		draw_rect(Rect2(x - 8.0, ty, bar_w + 16.0, bottom - ty), Color(COL_WARN, 0.35 if not danger else 0.55 * blink))
		draw_line(Vector2(x - 10.0, ty), Vector2(x + bar_w + 10.0, ty), COL_WARN, 3.0)
		if danger:
			_text(Vector2(x - 2.0, bottom + 40.0), "BERG VORAUS — STEIGEN!", 20, Color(COL_WARN, blink))

	# The balloon itself + climb/sink chevrons.
	var by: float = y_of.call(b.position.y)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 12.0, by - 9.0), Vector2(x + 4.0, by), Vector2(x - 12.0, by + 9.0)]), COL_TEXT)
	draw_line(Vector2(x, by), Vector2(x + bar_w, by), COL_TEXT, 3.0)
	var trend := clampi(int(round(b.vy / 3.0)), -3, 3)
	for i in absi(trend):
		var dy := -signf(trend) * (14.0 + i * 9.0)
		var tip := Vector2(x + bar_w * 0.5, by + dy - signf(trend) * 5.0)
		draw_polyline(PackedVector2Array([tip + Vector2(-8.0, signf(trend) * 7.0), tip, tip + Vector2(8.0, signf(trend) * 7.0)]), COL_TEXT, 3.0)
	_text(Vector2(x - 2.0, bottom + 16.0), "%d m" % int(b.position.y), 17, COL_TEXT)


# --- Tank, heat, hull, cargo -------------------------------------------------------------

func _draw_gauges() -> void:
	var b: Node3D = game.balloon
	var origin := Vector2(24.0, size.y - 150.0)
	draw_rect(Rect2(origin, Vector2(330.0, 130.0)), COL_PANEL)
	var bar := Rect2(origin + Vector2(84.0, 14.0), Vector2(230.0, 18.0))

	_text(origin + Vector2(12.0, 30.0), "TANK", 16, COL_DIM)
	var fuel_frac: float = b.fuel / b.TANK_MAX
	draw_rect(bar, Color(0, 0, 0, 0.5))
	var low_fuel := fuel_frac < 0.25
	var fuel_col := COL_WARN if low_fuel and fmod(Time.get_ticks_msec() * 0.004, 1.0) < 0.5 else Color(1.0, 0.62, 0.2)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fuel_frac, bar.size.y)), fuel_col)

	_text(origin + Vector2(12.0, 62.0), "HITZE", 16, COL_DIM)
	bar.position.y += 32.0
	draw_rect(bar, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * b.heat, bar.size.y)), Color(0.95, 0.35, 0.2).lerp(Color(1.0, 0.9, 0.4), b.heat))
	# Tick = heat that holds the current altitude.
	var eq_x: float = bar.position.x + bar.size.x * b.equilibrium_heat()
	draw_line(Vector2(eq_x, bar.position.y - 4.0), Vector2(eq_x, bar.end.y + 4.0), COL_TEXT, 2.0)

	_text(origin + Vector2(12.0, 98.0), "HÜLLE", 16, COL_DIM)
	for i in b.MAX_HULL:
		var c := origin + Vector2(98.0 + i * 30.0, 92.0)
		draw_circle(c, 10.0, COL_WARN if i < b.hull else Color(0, 0, 0, 0.5))

	var stock: Dictionary = game.basket.stock
	_text(origin + Vector2(12.0, 122.0), "Fallschirme %d  ·  Kanister %d  ·  Sandsäcke %d" % [game.basket.chutes, stock["kanister"], stock["sack"]], 15, COL_TEXT)


# --- Route strip ---------------------------------------------------------------------------

func _draw_route() -> void:
	var w: Node3D = game.world
	var left := size.x * 0.5 - 330.0
	var width := 660.0
	var y := 44.0
	draw_rect(Rect2(left - 30.0, 14.0, width + 60.0, 64.0), COL_PANEL)
	draw_line(Vector2(left, y), Vector2(left + width, y), COL_DIM, 3.0)
	var x_of := func(world_x: float) -> float: return left + width * clampf(world_x / w.ROUTE_LEN, 0.0, 1.0)
	for v in w.villages:
		var col := COL_GOLD
		if v.state == "done":
			col = Color(0.35, 0.9, 0.4)
		var vx: float = x_of.call(v.pos.x)
		draw_circle(Vector2(vx, y), 11.0, col)
		if v.state == "open":
			if v.known:
				draw_circle(Vector2(vx, y), 7.0, Wares.tint(v.order))
			else:
				_text(Vector2(vx, y + 6.0), "?", 16, Color(0.15, 0.10, 0.12), true)
		# Passed but still open: hollow — reachable only via the Rückströmung.
		if v.state == "open" and game.balloon.position.x > v.pos.x + w.PASS_DISTANCE:
			draw_arc(Vector2(vx, y), 14.0, 0.0, TAU, 24, COL_WARN, 2.5)
		if v.state == "done":
			_text(Vector2(vx, y + 6.0), "✓", 15, Color(0.1, 0.2, 0.1), true)
	var gx: float = x_of.call(w.goal_pos.x)
	draw_rect(Rect2(gx - 9.0, y - 9.0, 18.0, 18.0), COL_TEXT)
	var bx: float = x_of.call(game.balloon.position.x)
	draw_colored_polygon(PackedVector2Array([Vector2(bx - 8.0, y - 24.0), Vector2(bx + 8.0, y - 24.0), Vector2(bx, y - 10.0)]), COL_WARN)
	_text(Vector2(size.x * 0.5, 72.0), "Post %d/%d   ·   %d Punkte" % [w.delivered_count(), w.villages.size(), game.score], 15, COL_TEXT, true)


# --- Pointer to the next stop -----------------------------------------------------------------

func _draw_target_pointer() -> void:
	if game.state != game.State.FLYING or game.basket.scope_active or size.x < 400.0:
		return
	var cam: Camera3D = game.camera
	var target: Vector3 = game.target_position()
	var b: Vector3 = game.balloon.position
	var dist := Vector2(target.x - b.x, target.z - b.z).length()
	var label := "%s  %d m" % [game.target_name(), int(dist)]
	var margin := 70.0
	var screen := cam.unproject_position(target)
	var inside := Rect2(margin, margin + 60.0, size.x - margin * 2.0, size.y - margin * 2.0 - 60.0)
	if not cam.is_position_behind(target) and inside.has_point(screen):
		_text(screen + Vector2(0.0, -68.0), label, 20, COL_GOLD, true)
		_draw_order(screen + Vector2(0.0, -46.0))
		_arrow(screen + Vector2(0.0, -24.0), Vector2.DOWN, 12.0, COL_GOLD, 4.0)
		return
	# Off-screen: pin to the screen edge in the map direction (east = right, north = up).
	var dir := Vector2(target.x - b.x, target.z - b.z).normalized()
	var centre := size * 0.5
	var reach := minf((size.x * 0.5 - margin) / maxf(absf(dir.x), 0.001), (size.y * 0.5 - margin - 30.0) / maxf(absf(dir.y), 0.001))
	var p := centre + dir * reach
	# Pointing back west must not land on the altimeter or the gauges.
	p.x = maxf(p.x, 400.0 if p.y > size.y - 180.0 else 260.0)
	draw_circle(p, 26.0, COL_PANEL)
	_arrow(p, dir, 18.0, COL_GOLD, 5.0)
	var label_pos := p + Vector2(-dir.x * 40.0, 50.0 if dir.y < 0.5 else -40.0)
	label_pos.x = clampf(label_pos.x, 140.0, size.x - 140.0)
	_text(label_pos, label, 19, COL_GOLD, true)
	_draw_order(label_pos + Vector2(0.0, 22.0))


# Second line under the target label: what the village wants, if the crew has
# seen its colours yet.
func _draw_order(pos: Vector2) -> void:
	var v: Dictionary = game.target_village()
	if v.is_empty():
		return
	if not v.known:
		_text(pos, "Wunsch?  → Fernrohr", 16, COL_DIM, true)
		return
	var text := "will %s" % Wares.label(v.order)
	var half := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x * 0.5
	draw_circle(pos + Vector2(-half - 14.0, -6.0), 8.0, Wares.tint(v.order))
	_text(pos, text, 18, COL_TEXT, true)


# --- Overlays --------------------------------------------------------------------------------

func _draw_toast() -> void:
	if game.toast_age > 3.2:
		return
	var a := clampf(3.2 - game.toast_age, 0.0, 1.0)
	var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - game.toast_age * 5.0)
	_text(Vector2(size.x * 0.5, 140.0), game.toast_text, int(34 * pop), Color(COL_TEXT, a), true)


func _draw_intro() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.06, 0.12, 0.55))
	var cx := size.x * 0.5
	var y := size.y * 0.5 - 250.0
	_text(Vector2(cx, y), "WOLKENPOST", 84, COL_GOLD, true)
	_text(Vector2(cx, y + 44.0), "Mostly Hot Air · MVP Zeta", 22, COL_DIM, true)
	var lines := [
		"Du bist allein im Korb. Fünf Dörfer haben etwas bestellt — am Ende wartet der Hafen.",
		"",
		"FLIEGEN: Lenken geht nicht, nur Höhe. Jedes Band bläst woanders hin (Anzeige links).",
		"BRENNER (Mitte) halten = steigen · VENTIL (rote Leine, oben) halten = sinken · ganz oben weht es zurück.",
		"",
		"LIEFERN: Jedes Dorf will Medizin (rot), Briefe (blau) oder Saatgut (gelb) — zu sehen an Flagge und Zielpunkt,",
		"durch Wolken nur mit dem FERNROHR (rechts oben).  WARE (rechts) → PACKTISCH (E halten) → FALLSCHIRM",
		"vom Haken (unten rechts) ans Paket — oder Paket zum Haken → Reling, E. Ring am Boden = Landepunkt, grün = trifft.",
		"Fertige Pakete passen auf die ABLAGE. Ohne Fallschirm überlebt ein Paket nur den Tiefflug (unter 30 m).",
		"",
		"Tank leer? KANISTER (links) zum Brenner tragen.   SANDSACK über Bord = weniger Spritverbrauch, zäheres Sinken.",
		"",
		"WASD / Stick = laufen     E / Leertaste / (A) = benutzen     R = Neustart",
	]
	for i in lines.size():
		_text(Vector2(cx, y + 105.0 + i * 30.0), lines[i], 20, COL_TEXT, true)
	var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
	_text(Vector2(cx, y + 530.0), "E drücken zum Abheben", 34, Color(COL_GOLD, blink), true)


func _draw_result() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.06, 0.12, 0.6))
	var r: Dictionary = game.result
	var titles := {
		"landed": "Sanft gelandet in Hafen Luftikus!",
		"overshoot": "Am Hafen vorbeigetrieben …",
		"stranded": "Ohne Brennstoff gestrandet",
		"crash": "Hülle zerfetzt — Absturz!",
	}
	var cx := size.x * 0.5
	var y := size.y * 0.5 - 150.0
	_text(Vector2(cx, y), titles[r.outcome], 52, COL_WARN if r.outcome == "crash" else COL_GOLD, true)
	var stars := ""
	for i in 3:
		stars += "★ " if i < r.stars else "☆ "
	_text(Vector2(cx, y + 90.0), stars, 84, COL_GOLD, true)
	_text(Vector2(cx, y + 150.0), "Post zugestellt: %d / %d     Volltreffer: %d" % [r.delivered, game.world.villages.size(), r.bullseyes], 28, COL_TEXT, true)
	_text(Vector2(cx, y + 190.0), "%d Punkte" % r.score, 36, COL_TEXT, true)
	_text(Vector2(cx, y + 240.0), "★ 3 Zustellungen   ★★ 4 + Landung im Hafen   ★★★ alle 5 + Landung", 18, COL_DIM, true)
	_text(Vector2(cx, y + 300.0), "R = neue Fahrt (neue Karte, neuer Wind)", 26, COL_GOLD, true)


# --- Helpers -----------------------------------------------------------------------------------

func _text(pos: Vector2, text: String, font_size: int, color: Color, centered := false) -> void:
	var p := pos
	if centered:
		p.x -= _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(font_size / 6, 3), Color(0.08, 0.05, 0.08, color.a * 0.85))
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _arrow(center: Vector2, dir: Vector2, length: float, color: Color, width: float) -> void:
	var tip := center + dir * length
	var tail := center - dir * length
	var side := dir.orthogonal() * length * 0.55
	draw_line(tail, tip, color, width)
	draw_polyline(PackedVector2Array([tip - dir * length * 0.7 + side, tip, tip - dir * length * 0.7 - side]), color, width)
