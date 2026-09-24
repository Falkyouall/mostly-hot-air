extends Node
## Autoload. Registers input actions in code so project.godot stays minimal
## and the bindings are readable in one place.
##
## M2-E5 uses one shared keyboard/gamepad binding (only one player spawns).
## Per-device bindings for 2–4 players arrive with the multiplayer build.

func _ready() -> void:
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("interact", [KEY_SPACE, KEY_E])
	_key("secondary", [KEY_F])
	_key("reset_run", [KEY_R])

	_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_button("interact", JOY_BUTTON_A)
	_joy_button("secondary", JOY_BUTTON_X)
	_joy_button("reset_run", JOY_BUTTON_BACK)


func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _key(action: StringName, keycodes: Array) -> void:
	_ensure(action)
	for code in keycodes:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		InputMap.action_add_event(action, ev)


func _joy_axis(action: StringName, axis: int, value: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	# New joypad events only match device 0; -1 means any pad. Chrome often
	# hands a controller index 1 or higher.
	ev.device = -1
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _joy_button(action: StringName, button: int) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.device = -1
	ev.button_index = button
	InputMap.action_add_event(action, ev)
