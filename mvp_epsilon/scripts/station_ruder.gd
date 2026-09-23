class_name StationRuder
extends Station
## Stoss-Ruder — discrete burst. The occupant presses "secondary" and the
## station emits the *intent*: which way the stick is pointing, in world XZ.
##
## The station deliberately does not decide the final impulse. H2_DESIGN §5.3
## says the shove is perpendicular to the local stream, and only the balloon
## knows the stream (it owns the Level). So the station reports intent and the
## balloon resolves it — see Balloon._on_nudge_requested. The cooldown lives
## there too, for the same reason.

signal nudge_requested(intent: Vector3)


func _ready() -> void:
	station_name = &"Stoss-Ruder"
	free_color = Color(0.30, 0.32, 0.40)
	occupied_color = Color(0.50, 0.80, 0.95)
	super()


func on_secondary(by: Player) -> void:
	# Ask the avatar for the stick in world XZ — the same camera-relative
	# mapping it walks by. Reading the raw stick here instead would silently
	# give it a second, camera-blind meaning.
	var intent := by.world_wish_dir()
	if intent.length() < 0.1:
		# No stick: shove away from the basket centre, i.e. the way the
		# occupant is leaning by standing here.
		intent = by.global_position - get_parent_node_3d().global_position
		intent.y = 0.0
	if intent.length() < 0.01:
		intent = Vector3.RIGHT
	nudge_requested.emit(intent.normalized())
