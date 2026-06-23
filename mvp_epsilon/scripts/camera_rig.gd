extends Camera3D
## M2-E5 — fixed 45° overhead camera framing the basket.
##
## Orientation is set with look_at() rather than a hand-authored basis so it
## stays correct by construction. M2-E6+ replaces this with the H1_DESIGN §9
## target-oriented follow camera (vertical damping, look-ahead).

@export var look_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	look_at(look_target)
