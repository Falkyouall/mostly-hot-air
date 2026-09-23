extends Camera3D
## M2-E6 follow camera (H1_DESIGN §9): 45° schräg-Draufsicht, target-oriented
## so the goal stays roughly ahead, with vertical damping that smooths short
## brenner-pulses but follows band changes calmly.

@export var follow: Node3D
@export var goal_position: Vector3 = Vector3(800.0, 0.0, 0.0)
## Camera position relative to the *target direction* (forward), not the balloon.
## y = height above the balloon. xz = back-offset along the goal direction.
@export var back_offset: float = 26.0
@export var height_offset: float = 20.0
@export var vertical_damp: float = 1.5

var _smoothed_y: float = 0.0


func _ready() -> void:
	snap_to_follow()


## Pre-warm the smoothed Y. Call after assigning follow at a non-default Y so
## the camera doesn't take a moment to find the target.
func snap_to_follow() -> void:
	if follow:
		_smoothed_y = follow.global_position.y


func _process(delta: float) -> void:
	if follow == null:
		return
	var pos := follow.global_position
	_smoothed_y = lerpf(_smoothed_y, pos.y, clampf(delta / vertical_damp, 0.0, 1.0))

	var forward := goal_position - pos
	forward.y = 0.0
	if forward.length() < 0.001:
		forward = Vector3.RIGHT
	forward = forward.normalized()

	# Sit behind and above the balloon along the forward axis to the goal.
	var cam_pos := Vector3(
		pos.x - forward.x * back_offset,
		_smoothed_y + height_offset,
		pos.z - forward.z * back_offset
	)
	global_position = cam_pos
	# Look slightly ahead of the balloon so the destination dominates frame.
	var look := Vector3(pos.x + forward.x * 4.0, _smoothed_y, pos.z + forward.z * 4.0)
	look_at(look, Vector3.UP)
