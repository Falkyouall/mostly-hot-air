extends Node
# Scripted crew member: drives the real input actions through every station
# once and checks the effect. Catches broken interaction rules, not game feel.
#
#   godot --headless --path mvp_zeta -- --playtest --seed=3

var game: Node3D
var _steps: Array = []
var _index := 0
var _step_time := 0.0
var _failures := 0
var _memo := {}


func _ready() -> void:
	# Run before basket.gd so a press and its just_pressed check share a frame.
	process_physics_priority = -100
	var basket: Node3D = game.basket
	var balloon: Node3D = game.balloon
	_steps = [
		_walk(Vector2(0.0, 1.05)),
		_remember(func() -> void: _memo = {"heat": balloon.heat, "fuel": balloon.fuel}),
		_hold(1.5),
		_check("Brenner heizt und verbraucht", func() -> bool: return balloon.heat > _memo.heat and balloon.fuel < _memo.fuel),
		# The delivery chain: ware → Packtisch → Fallschirm → Ablage → railing.
		_walk(Vector2(0.9, -0.1)),
		_walk(Vector2(1.6, -0.4)),
		_tap(),
		_check("Medizin aufgenommen", func() -> bool: return basket.carrying("ware") and basket.carried.color == "rot" and basket.stock["rot"] == 2),
		_tap(),
		_check("Medizin zurückgelegt", func() -> bool: return basket.carried.is_empty() and basket.stock["rot"] == 3),
		_tap(),
		_walk(Vector2(0.9, -0.1)),
		_walk(Vector2(0.0, 1.05)),
		_walk(Vector2(-0.3, 1.45)),
		_tap(),
		_check("Ware liegt auf dem Packtisch", func() -> bool: return basket.carried.is_empty() and basket._table.get("kind", "") == "ware"),
		_hold(0.8),
		_check("Packen braucht Zeit", func() -> bool: return basket._table.kind == "ware"),
		_hold(3.0),
		_check("Paket gepackt", func() -> bool: return basket._table.kind == "paket" and basket._table.color == "rot"),
		_tap(),
		_check("Paket vom Tisch genommen", func() -> bool: return basket.carrying("paket") and not basket.carried.chute),
		# Way 1: carry the parcel to the Haken.
		_walk(Vector2(0.0, 1.9)),
		_walk(Vector2(0.7, 2.2)),
		_tap(),
		_check("Fallschirm angeknotet (Paket zum Haken)", func() -> bool: return basket.carried.chute and basket.chutes == 5),
		_walk(Vector2(0.35, 1.6)),
		_tap(),
		_check("Paket auf der Ablage", func() -> bool: return basket.carried.is_empty() and not basket._shelf_slot_is_free(0)),
		_tap(),
		_check("Paket von der Ablage", func() -> bool: return basket.carrying("paket") and basket.carried.chute),
		_walk(Vector2(0.0, 2.55)),
		_tap(),
		_check("Paket über Bord", func() -> bool: return basket.carried.is_empty() and balloon.extra_lift > 0.0),
		# Way 2: take a Fallschirm to a parcel lying on the Packtisch.
		_walk(Vector2(0.0, 1.05)),
		_walk(Vector2(0.9, -0.1)),
		_walk(Vector2(1.7, 0.25)),
		_tap(),
		_check("Briefe aufgenommen", func() -> bool: return basket.carrying("ware") and basket.carried.color == "blau"),
		_walk(Vector2(0.9, -0.1)),
		_walk(Vector2(0.0, 1.05)),
		_walk(Vector2(-0.3, 1.45)),
		_tap(),
		_hold(3.0),
		_check("Zweites Paket gepackt", func() -> bool: return basket._table.kind == "paket" and not basket._table.chute),
		_walk(Vector2(0.0, 1.9)),
		_walk(Vector2(0.7, 2.2)),
		_tap(),
		_check("Fallschirm vom Haken genommen", func() -> bool: return basket.carrying("schirm") and basket.chutes == 4),
		_tap(),
		_check("Fallschirm zurückgehängt", func() -> bool: return basket.carried.is_empty() and basket.chutes == 5),
		_tap(),
		_walk(Vector2(0.0, 1.9)),
		_walk(Vector2(-0.3, 1.45)),
		_tap(),
		_check("Fallschirm ans Paket auf dem Tisch", func() -> bool: return basket.carried.is_empty() and basket._table.chute and basket.chutes == 4),
		_tap(),
		_check("Fertiges Paket genommen", func() -> bool: return basket.carrying("paket") and basket.carried.chute),
		_walk(Vector2(0.35, 1.6)),
		_tap(),
		_walk(Vector2(0.0, 1.05)),
		_walk(Vector2(-0.9, -0.1)),
		_walk(Vector2(-1.55, 0.35)),
		_tap(),
		_check("Kanister aufgenommen", func() -> bool: return basket.carrying("kanister")),
		_remember(func() -> void: balloon.fuel = 10.0),
		_walk(Vector2(-0.8, 0.1)),
		_tap(),
		_check("Tank aufgefüllt", func() -> bool: return basket.carried.is_empty() and balloon.fuel > 70.0),
		_walk(Vector2(-0.9, -0.9)),
		_walk(Vector2(0.0, -2.15)),
		_remember(func() -> void: balloon.heat = 0.8),
		_hold(1.0),
		_check("Ventil kühlt", func() -> bool: return balloon.heat < 0.3),
		_walk(Vector2(1.35, -1.4)),
		_hold(0.5),
		_check("Fernrohr aktiv", func() -> bool: return basket.scope_active),
	]


func _physics_process(delta: float) -> void:
	if _index >= _steps.size():
		print("PLAYTEST %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
		get_tree().quit(1 if _failures > 0 else 0)
		set_physics_process(false)
		return
	_step_time += delta
	var step: Dictionary = _steps[_index]
	var done := false
	match step.kind:
		"walk":
			var p: Vector3 = game.basket.player.position
			var to := Vector2(step.to.x - p.x, step.to.y - p.z)
			done = to.length() < 0.08 or _step_time > 4.0
			_steer(Vector2.ZERO if done else to.normalized())
			if _step_time > 4.0:
				_fail("walk to %s timed out" % step.to)
		"tap":
			if _step_time <= delta * 1.5:
				Input.action_press("interact")
			else:
				Input.action_release("interact")
				done = _step_time > 0.2
		"hold":
			Input.action_press("interact")
			done = _step_time > step.time
			if done and not step.get("keep", false):
				Input.action_release("interact")
		"call":
			step.fn.call()
			done = true
		"check":
			# Runs while a preceding hold is still down; releases afterwards.
			if not step.fn.call():
				_fail(step.label)
			else:
				print("  ok   %s" % step.label)
			Input.action_release("interact")
			done = true
	if done:
		_index += 1
		_step_time = 0.0


func _steer(dir: Vector2) -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if dir.x < -0.05:
		Input.action_press("move_left", -dir.x)
	if dir.x > 0.05:
		Input.action_press("move_right", dir.x)
	if dir.y < -0.05:
		Input.action_press("move_up", -dir.y)
	if dir.y > 0.05:
		Input.action_press("move_down", dir.y)


func _fail(label: String) -> void:
	_failures += 1
	print("  FAIL %s" % label)


func _walk(to: Vector2) -> Dictionary:
	return {"kind": "walk", "to": to}


func _tap() -> Dictionary:
	return {"kind": "tap"}


func _hold(time: float) -> Dictionary:
	return {"kind": "hold", "time": time, "keep": true}


func _remember(fn: Callable) -> Dictionary:
	return {"kind": "call", "fn": fn}


func _check(label: String, fn: Callable) -> Dictionary:
	return {"kind": "check", "label": label, "fn": fn}
